# CompletableFuture и асинхронность

> Что проверяют: thenApply/thenCompose/thenCombine — какую операцию когда брать, обработку ошибок в цепочке, свой пул под блокирующий IO.

<a id="r17-t1"></a>
**1. [Потоки] Цепочка зависимых вызовов: пользователь → карта → заказ**
```java
ExecutorService ioPool = Executors.newFixedThreadPool(50);   // свой пул под блокирующие вызовы

CompletableFuture<Order> order = CompletableFuture
    .supplyAsync(() -> api.fetchUser(userId), ioPool)   // User
    .thenApply(User::primaryCard)                       // Card        — синхронное преобразование
    .thenCompose(card -> CompletableFuture.supplyAsync( // Order       — ЗАВИСИМЫЙ асинхронный вызов
        () -> api.fetchOrder(card.orderId()), ioPool));
```
Ключевой вопрос: `thenApply` — преобразование готового значения; `thenCompose` — когда следующий шаг сам асинхронный (аналог flatMap). `thenApply` с CF внутри даст CF<CF<T>>.

<a id="r17-t2"></a>
**2. [Потоки] Два независимых вызова — объединить результат**
```java
CompletableFuture<Price> price = CompletableFuture.supplyAsync(() -> api.price(id), ioPool);
CompletableFuture<Double> rate  = CompletableFuture.supplyAsync(() -> api.rate(cur), ioPool);

CompletableFuture<Price> adjusted = price.thenCombine(rate, Price::multiply);   // оба готовы — объединяем
```
thenCombine запускает задачи параллельно, не последовательно. Фоллоу-ап: «а если второй нужен и для логики, и для результата» — thenCombine с BiFunction уже это даёт; последовательно — только тогда, когда есть реальная зависимость.

<a id="r17-t3"></a>
**3. [Потоки] Обработка ошибок: exceptionally / handle / whenComplete**
```java
CompletableFuture<Result> safe = CompletableFuture
    .supplyAsync(() -> risky(), ioPool)
    .handle((res, err) -> {            // вызывается ВСЕГДА; может подменить результат
        if (err != null) {
            log.warn("fallback", err);
            return Result.fallback();
        }
        return res;
    });

// exceptionally — только при ошибке, успех проходит насквозь
// whenComplete — «наблюдатель»: получает (res, err), но НЕ меняет результат (логирование, метрики)
```
Уметь расставить: fallback → exceptionally/handle; сайд-эффект → whenComplete; исключение «внутри» thenApply летит дальше по цепочке до обработчика.

<a id="r17-t4"></a>
**4. [Потоки|hard] Дождаться N параллельных запросов с таймаутом каждого**
```java
List<CompletableFuture<Stat>> futures = ids.stream()
    .map(id -> fetchStat(id)
        .orTimeout(2, TimeUnit.SECONDS)              // Java 9+: по истечении — TimeoutException
        .exceptionally(e -> Stat.empty()))           // сбой одного не рушит весь список
    .collect(Collectors.toList());

CompletableFuture<List<Stat>> all = CompletableFuture
    .allOf(futures.toArray(CompletableFuture[]::new))   // CompletableFuture<Void> — дождаться всех
    .thenApply(v -> futures.stream()
        .map(CompletableFuture::join)                  // здесь уже всё готово — не бросит
        .collect(Collectors.toList()));
```
Почему join, а не get: checked-исключение не нужно — все ошибки уже обработаны exceptionally. `completeOnTimeout(value, timeout, unit)` — таймаут с дефолтным значением вместо исключения (Java 9+).

<a id="r17-t5"></a>
**5. [Баг-хантинг] supplyAsync с блокирующим IO на общем пуле**
```java
// ПЛОХО: commonPool рассчитан на CPU-задачи, размер = ядра - 1
CompletableFuture.supplyAsync(() -> httpClient.call(url))    // блокирует воркер общего пула
// 10 таких задач на 8 ядрах → весь параллелизм приложения (и parallelStream!) замерзает:
// ForkJoinPool.commonPool() занят блокирующими вызовами и голодает

// ПРАВИЛЬНО: свой пул под блокирующие вызовы
ExecutorService ioPool = Executors.newFixedThreadPool(50);
CompletableFuture.supplyAsync(() -> httpClient.call(url), ioPool);
```
Правило: CPU-задачи — commonPool (или ForkJoinPool), блокирующий IO — выделенный FixedThreadPool примерно по числу одновременных внешних вызовов. Пул обязан останавливаться при завершении приложения — регистрируем остановку в shutdown-хуке.

<a id="r17-t6"></a>
**6. [Потоки|hard] Ретрай с бэкоффом на CompletableFuture**
```java
static <T> CompletableFuture<T> retry(int attempts, Supplier<CompletableFuture<T>> op) {
    return op.get().handle((res, err) -> {
        if (err == null) return CompletableFuture.completedFuture(res);
        if (attempts <= 1) return CompletableFuture.<T>failedFuture(err);   // Java 9+
        return retry(attempts - 1, op);                                     // хвостовая композиция
    }).thenCompose(cf -> cf);   // разворачиваем CF<CF<T>> в CF<T>
}
```
handle возвращает CF<CF<T>>, поэтому thenCompose flattens. Фоллоу-апы: пауза между попытками — `CompletableFuture.delayedExecutor(delay, unit)` (Java 9+); ретраить только retryable-ошибки; максимальная глубина. Библиотеки: resilience4j-retry.

---

<a id="razdel-18"></a>
