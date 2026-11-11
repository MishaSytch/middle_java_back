# CompletableFuture: пособие с примерами и задачами

**Уровень:** с нуля до уверенного middle. **Язык:** Java. **Базовая версия:** Java 17 (фичи более новых версий помечены `9+`, `12+`, `21+`).

Все примеры и решения прогнаны на OpenJDK 17.0.21. Вывод программ приведён реальный (имена потоков и миллисекунды у вас будут другими). Фрагменты про Java 21 помечены отдельно и на 17 не запускались.

> **Главная мысль пособия.** `CompletableFuture` — это не «поток» и не «способ сделать параллельно». Это **коробка, в которой однажды появится результат (или ошибка), плюс список тех, кого надо позвать, когда это случится**. Как только вы держите в голове эту модель, 90 % вопросов («в каком потоке выполнится колбэк?», «почему не работает `exceptionally`?», «почему всё последовательно?») отвечаются сами.

---

## Оглавление

| # | Раздел | Что внутри |
|---|--------|-----------|
| 0 | [Как работать с пособием](#s0) | песочница, план на 3 вечера |
| 1 | [Зачем нужен CompletableFuture](#s1) | боль блокирующего кода, `Future` vs `CompletableFuture` |
| 2 | [Быстрый старт за 5 минут](#s2) | первый пайплайн построчно |
| 3 | [Создание](#s3) | 8 способов создать future |
| 4 | [Как забрать результат](#s4) | `join`/`get`/`getNow`, таймауты, прерывания |
| 5 | [Цепочки и комбинаторы](#s5) | `thenApply`, `thenCompose`, `thenCombine`, `either` |
| 6 | [Ошибки](#s6) | обёртки, `exceptionally`, `handle`, `whenComplete` |
| 7 | [Потоки и пулы](#s7) | commonPool, свой executor, deadlock, MDC |
| 8 | [Таймауты и отмена](#s8) | `orTimeout`, `completeOnTimeout`, правда про `cancel` |
| 9 | [Много future: allOf / anyOf](#s9) | сбор результатов, частичный успех, first-success |
| 10 | [Боевые паттерны](#s10) | агрегатор, retry, дедупликация, лимиты, тесты |
| 11 | [14 ловушек](#s11) | «плохо → хорошо» |
| 12 | [Шпаргалка и чек-лист ревью](#s12) | таблицы всех методов |
| 13 | [Задачи: 25 штук](#s13) | блоки A–E, от разминки до code review |
| 14 | [Контрольные вопросы](#s14) | 12 вопросов на понимание |
| 15 | [Решения и ответы](#s15) | ко всем задачам |
| 16 | [Что дальше](#s16) | Java 21, реактивщина, литература |

---

<a id="s0"></a>
## 0. Как работать с пособием

**План на три вечера:**
1. Разделы 1–6 + блок задач A и B. Цель — свободно писать цепочки и не путать `thenApply`/`thenCompose`.
2. Разделы 7–9 + блок C. Цель — понимать, где выполняется код, и не терять исключения.
3. Раздел 10 + блок D и E. Цель — собрать агрегатор с таймаутами, ретраями и лимитами и уметь его тестировать.

**Правило:** каждый пример запускайте сами. Асинхронный код невозможно «понять глазами» — интуиция врёт именно там, где всё выглядит очевидно.

### Песочница

Все примеры ниже используют одни и те же вспомогательные методы. Создайте класс и кладите примеры внутрь него как методы (или в `main`).

```java
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.function.*;
import java.util.stream.*;

public class Sandbox {

    /** Пул для «внешних вызовов». Daemon — чтобы JVM не висела после main. */
    static final ExecutorService IO = Executors.newFixedThreadPool(8, r -> {
        Thread t = new Thread(r);
        t.setName("io-" + t.getId());
        t.setDaemon(true);
        return t;
    });

    static void log(String msg) {
        System.out.printf("[%s] %s%n", Thread.currentThread().getName(), msg);
    }

    /** Имитация сетевого вызова. */
    static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();          // всегда восстанавливаем флаг
            throw new CompletionException(e);
        }
    }

    /** Снимает обёртки CompletionException / ExecutionException. */
    static Throwable unwrap(Throwable t) {
        Throwable cur = t;
        while ((cur instanceof CompletionException || cur instanceof ExecutionException)
                && cur.getCause() != null) {
            cur = cur.getCause();
        }
        return cur;
    }

    static <T> T timed(String label, Supplier<T> body) {
        long start = System.currentTimeMillis();
        T value = body.get();
        log(label + " = " + value + " за " + (System.currentTimeMillis() - start) + " мс");
        return value;
    }
}
```

Компилируйте с UTF-8, если в коде русские комментарии: `javac -encoding UTF-8 Sandbox.java`.

**Про замеры в пособии.** Все приведённые цифры получены на OpenJDK 17.0.21, 2 vCPU. Там, где важно поведение `commonPool`, запуск был с явным `-Djava.util.concurrent.ForkJoinPool.common.parallelism=N` — эта настройка меняет и число воркеров, и то, какой поток выполнит колбэк. Ваши миллисекунды будут другими; важны порядок величин и соотношения (в 4 раза быстрее / в 2 раза медленнее), а не точные числа.

---

<a id="s1"></a>
## 1. Зачем нужен CompletableFuture

### 1.1. Боль

Карточка товара в интернет-магазине собирается из четырёх источников, каждый отвечает 200 мс:

```java
Product product = productService.find(id);   // 200 мс
Price price     = priceService.price(id);    // 200 мс
int stock       = stockService.stock(id);    // 200 мс
double rating   = reviewService.rating(id);  // 200 мс
return new Card(product, price, stock, rating);
```

Пользователь ждёт **800 мс**, хотя данные независимы и могли бы прилететь за **200 мс**. Процессор при этом не занят — все четыре потока просто спят в ожидании сокета. Классическая ситуация, где асинхронность даёт выигрыш «в 4 раза» без единой оптимизации алгоритма.

### 1.2. Почему не хватит `Future`

`Future` появился в Java 5 и умеет ровно одно: «спроси результат, заблокируйся». Чтобы объединить два `Future`, придётся писать цикл с `get()` руками; колбэков нет, вручную завершить нельзя, ошибку можно получить только поймав `ExecutionException`.

| Возможность | `Future` (Java 5) | `CompletableFuture` (Java 8) |
|---|---|---|
| Забрать результат | `get()` — блокировка | `get()`/`join()` **и** колбэки |
| Колбэк «когда готово» | — | `thenApply`, `thenAccept`, `whenComplete`, … |
| Цепочка преобразований | — | `thenApply` / `thenCompose` |
| Объединить два результата | вручную | `thenCombine`, `thenAcceptBoth` |
| Дождаться всех / первого | вручную | `allOf` / `anyOf` |
| Завершить самому (из колбэка, из кэша) | — | `complete`, `completeExceptionally` |
| Обработать ошибку без `try/catch` | — | `exceptionally`, `handle` |
| Таймаут без блокировки потока | — | `orTimeout`, `completeOnTimeout` `9+` |
| `cancel(true)` прерывает работу | да (`FutureTask`) | **нет**, только помечает future отменённой |

### 1.3. Модель в голове

`CompletableFuture<T>` реализует два интерфейса:
* `Future<T>` — «результат когда-нибудь будет, можно спросить/отменить»;
* `CompletionStage<T>` — «на результат можно подписаться и построить конвейер».

Внутри — ссылка на результат (`null`, пока не готово) и стек подписчиков. Как только результат появляется, все подписчики запускаются: **в том потоке, который завершил future, или в пуле — это зависит от метода** (раздел 7).

Три состояния: **не завершена** → **завершена успешно** / **завершена с ошибкой**. Отмена — это частный случай ошибки (`CancellationException`). Переход происходит **ровно один раз**: второй `complete(...)` вернёт `false` и будет проигнорирован (проверено).

---

<a id="s2"></a>
## 2. Быстрый старт за 5 минут

```java
public static void main(String[] args) {
    CompletableFuture<String> future = CompletableFuture
            .supplyAsync(() -> {                       // 1. запустить в пуле IO
                log("читаю товар");
                sleep(200);
                return "Товар-42";
            }, IO)
            .thenApply(title -> {                      // 2. преобразовать результат
                log("строю DTO");
                return title.toUpperCase();
            })
            .thenApply(title -> "Карточка: " + title); // 3. ещё одно преобразование

    log("main свободен, занимаюсь другими делами");
    String card = future.join();                       // 4. дождаться на границе мира
    log(card);
}
```

Реальный вывод:

```
[main] main свободен, занимаюсь другими делами
[io-12] читаю товар
[io-12] строю DTO
[main] Карточка: ТОВАР-42
```

Построчно:
1. `supplyAsync(supplier, executor)` — «выполни это в пуле и верни future результата». Вызов **возвращается сразу**, тело ещё не выполнено.
2. `thenApply(fn)` — «когда результат будет, прогони его через функцию». Обратите внимание: `thenApply` выполнился **в том же потоке `io-12`**, а не в `main` и не в новом потоке.
3. Цепочка возвращает **новый** future. Исходный не мутирует.
4. `join()` — блокировка до готовности. Здесь она уместна: `main` — граница программы. Внутри бизнес-логики `join` почти всегда признак ошибки дизайна.

> ⚠️ **Первые грабли.** `supplyAsync` без второго аргумента уходит в `ForkJoinPool.commonPool()` — общий на всю JVM пул с числом потоков `ядра − 1`. Для блокирующих сетевых вызовов он не предназначен (раздел 7). В этом пособии **везде передаём свой executor**.

---

<a id="s3"></a>
## 3. Создание future

```java
// 1. Уже готовое значение (заглушки, кэш, тесты)
CompletableFuture<String> a = CompletableFuture.completedFuture("готово");

// 2. Задача со результатом
CompletableFuture<String> b = CompletableFuture.supplyAsync(() -> load(), IO);

// 3. Задача без результата — CompletableFuture<Void>
CompletableFuture<Void> c = CompletableFuture.runAsync(() -> sendMetric(), IO);

// 4. Пустая коробка: завершу сам, когда придёт колбэк/событие
CompletableFuture<String> d = new CompletableFuture<>();
d.complete("значение");                    // true
d.complete("другое");                      // false — значение уже зафиксировано
d.completeExceptionally(new IOException());// false — поздно

// 5. Уже упавшая future (9+)
CompletableFuture<String> e = CompletableFuture.failedFuture(new IOException("нет сети"));

// 6. Завершить эту future значением из supplier, посчитанным в пуле (9+)
CompletableFuture<String> f = new CompletableFuture<String>().completeAsync(() -> load(), IO);

// 7. Отложенный старт (9+): выполнится через 200 мс
CompletableFuture<String> g = CompletableFuture.supplyAsync(
        () -> load(), CompletableFuture.delayedExecutor(200, TimeUnit.MILLISECONDS, IO));

// 8. Только интерфейс CompletionStage, без методов Future (9+) — «нельзя отменить/дождаться»
CompletionStage<String> h = CompletableFuture.completedStage("read-only");
```

| Способ | Когда применять |
|---|---|
| `completedFuture(v)` | результат уже известен: кэш, дефолт, заглушка в тесте |
| `supplyAsync(s, ex)` | есть блокирующий/долгий вызов, нужен результат |
| `runAsync(r, ex)` | нужен только сайд-эффект (`Void`) |
| `new CompletableFuture<>()` | мост из callback/listener-API, ручное управление, retry, лимитеры |
| `failedFuture(t)` `9+` | быстро вернуть ошибку в едином асинхронном контракте |
| `completeAsync` `9+` | нужно вручную решить, когда завершить, но значение посчитать в пуле |
| `delayedExecutor` `9+` | отложенный запуск, backoff между ретраями, polling |
| `completedStage` / `minimalCompletionStage` `9+` | отдать наружу только «подписку», спрятав `complete`/`cancel` |

**Важный приём — единый контракт.** Если метод возвращает `CompletableFuture`, он не должен бросать исключение синхронно: вызывающий обязан обрабатывать два разных канала ошибок. Плохо и хорошо:

```java
// ПЛОХО: ошибка валидации летит синхронно, сетевая — асинхронно
CompletableFuture<User> find(long id) {
    if (id <= 0) throw new IllegalArgumentException("id");   // вызывающий не ждёт этого
    return supplyAsync(() -> api.user(id), IO);
}

// ХОРОШО: все ошибки внутри future
CompletableFuture<User> find(long id) {
    if (id <= 0) return CompletableFuture.failedFuture(new IllegalArgumentException("id"));
    return supplyAsync(() -> api.user(id), IO);
}
```

---

<a id="s4"></a>
## 4. Как забрать результат

```java
String v1 = cf.join();                       // блокирует; CompletionException (unchecked)
String v2 = cf.get();                        // блокирует; ExecutionException + InterruptedException (checked)
String v3 = cf.get(200, TimeUnit.MILLISECONDS); // + TimeoutException
String v4 = cf.getNow("default");            // не блокирует: дефолт, если ещё не готово
boolean done = cf.isDone();                  // готово ЛЮБЫМ способом, включая ошибку/отмену
boolean bad  = cf.isCompletedExceptionally();
boolean canc = cf.isCancelled();
```

| | `join()` | `get()` |
|---|---|---|
| Ошибка результата | `CompletionException` (unchecked) | `ExecutionException` (checked) |
| Прерывание потока | **не реагирует**, ждёт дальше | бросает `InterruptedException` |
| Отменённая future | `CancellationException` | `CancellationException` |
| Где применять | внутри цепочек, в стримах, в лямбдах | когда нужен таймаут или реакция на interrupt |

Три факта, которые регулярно становятся сюрпризом (все проверены):

```java
// 1. getNow на УПАВШЕЙ future бросает исключение, а не возвращает дефолт
CompletableFuture<String> failed = CompletableFuture.failedFuture(new IllegalStateException("bad"));
failed.getNow("default");   // CompletionException! дефолт только для «ещё не готово»

// 2. join() игнорирует interrupt. Поток, застрявший в join, нельзя разбудить
//    ни interrupt(), ни executor.shutdownNow(). Отсюда — вечные висяки при deadlock.

// 3. get(timeout) НЕ отменяет работу. Таймаут истёк — задача продолжает бежать.
CompletableFuture<String> slow = CompletableFuture.supplyAsync(() -> { sleep(300); return "поздно"; }, IO);
try { slow.get(50, TimeUnit.MILLISECONDS); } catch (TimeoutException e) { /* работа идёт дальше */ }
```

Корректная обработка `get()` на границе сервиса:

```java
try {
    return cf.get(200, TimeUnit.MILLISECONDS);
} catch (TimeoutException e) {
    return fallback;                                  // деградация
} catch (ExecutionException e) {
    throw new ServiceException(unwrap(e));            // разворачиваем обёртку
} catch (InterruptedException e) {
    Thread.currentThread().interrupt();               // ОБЯЗАТЕЛЬНО восстановить флаг
    throw new ServiceException("прервано", e);
}
```

> ✅ **Правило границ.** `join`/`get` живут на границах: `main`, контроллер, тест, адаптер к синхронному API. Внутри асинхронного пайплайна результат передаётся через `thenApply`/`thenCompose`, а не достаётся блокировкой.

---

<a id="s5"></a>
## 5. Цепочки и комбинаторы

### 5.1. Три базовых продолжения

| Метод | Лямбда | Возвращает | Смысл |
|---|---|---|---|
| `thenApply` | `T -> U` | `CF<U>` | **map**: преобразовать значение |
| `thenAccept` | `T -> void` | `CF<Void>` | **peek**: потребить значение |
| `thenRun` | `() -> void` | `CF<Void>` | сделать что-то после, значение не нужно |

У каждого есть две асинхронные версии: `thenApplyAsync(fn)` (в пул по умолчанию) и `thenApplyAsync(fn, executor)` (в ваш пул). **Только `*Async`-версии принимают `Executor`** — `thenApply(fn, executor)` не скомпилируется.

### 5.2. Кто выполняет колбэк (проверено)

```java
CompletableFuture.supplyAsync(() -> { log("supplyAsync"); return "A"; }, IO)
    .thenApply(s      -> { log("thenApply");                return s + "B"; })
    .thenApplyAsync(s -> { log("thenApplyAsync (common)");  return s + "C"; })
    .thenApplyAsync(s -> { log("thenApplyAsync (IO)");      return s + "D"; }, IO)
    .thenAccept(s -> log("итог " + s))
    .join();

CompletableFuture.completedFuture("X")
    .thenApply(s -> { log("thenApply на уже готовой future"); return s; });
```

```
[io-12] supplyAsync
[io-12] thenApply
[ForkJoinPool.commonPool-worker-1] thenApplyAsync (common)
[io-14] thenApplyAsync (IO)
[io-14] итог ABCD
[main] thenApply на уже готовой future
```

*(Вывод получен с `-Djava.util.concurrent.ForkJoinPool.common.parallelism=3`. На машине с двумя ядрами параллельность commonPool равна 1, и вместо `commonPool-worker-1` вы увидите отдельный поток `Thread-N` — см. §7.1.)*

**Три правила, которые надо знать наизусть:**
1. `thenXxx` (без `Async`) выполняется в потоке, который **завершил** предыдущую стадию.
2. Если предыдущая стадия **уже завершена** на момент подписки — в потоке, который **вызвал** `thenXxx` (в примере — `main`).
3. `thenXxxAsync` всегда уходит в executor: явный или `commonPool`.

**Четвёртое правило, о котором почти никто не знает (проверено экспериментом).** `join()` и `get()` внутри себя вызывают `postComplete()` — то есть «помогают» разобрать очередь подписчиков. Поэтому не-Async колбэк иногда выполняется **в потоке, вызвавшем `join`**, а не в том, который завершил future: это гонка. Замер: 300 прогонов «подписка → завершение из другого потока → join» дали 297 выполнений в потоке-завершителе и **3 в `main`**; в варианте без `join` (ожидание на `CountDownLatch`) — 300 из 300 в завершителе.

Практический вывод: **никогда не полагайтесь на конкретный поток** для не-Async колбэка. Он может оказаться на потоке Netty/HTTP-клиента, на потоке, завершившем стадию, или на вашем потоке из `join`. Если поток важен (тяжёлый расчёт, блокирующий вызов, контекст) — только `thenApplyAsync(fn, свойПул)`.

### 5.3. `thenCompose` — когда следующий шаг тоже асинхронный

Классическая ошибка: `thenApply` с функцией, которая сама возвращает future.

```java
// ПЛОХО: получили матрёшку
CompletableFuture<CompletableFuture<List<Order>>> nested =
        api.user(id).thenApply(user -> api.orders(user.id()));   // CF<CF<...>>
List<Order> orders = nested.join().join();                       // двойной join — запах

// ХОРОШО: thenCompose = flatMap
CompletableFuture<List<Order>> flat =
        api.user(id).thenCompose(user -> api.orders(user.id()));
```

**Правило выбора:** функция возвращает обычное значение → `thenApply`; возвращает `CompletableFuture` → `thenCompose`.

`thenCompose` выстраивает **последовательность**: второй вызов стартует только после первого. Замер (оба вызова по 200 мс):

```java
timed("последовательно", () -> api.user(1).thenCompose(u -> api.orders(u.id())).join());
// [main] последовательно = ... за 409 мс
```

### 5.4. `thenCombine` — два независимых вызова параллельно

```java
CompletableFuture<User> user = api.user(1);      // стартовал СЕЙЧАС
CompletableFuture<Promo> promo = api.promo(1);   // стартовал СЕЙЧАС
CompletableFuture<Page> page = user.thenCombine(promo, (u, p) -> new Page(u, p));
// [main] параллельно = ... за 205 мс
```

Аргументы вычисляются до вызова метода, поэтому `promo` уже бежит, пока `user` не готов. Родственники:

| Метод | Что делает | Результат |
|---|---|---|
| `thenCombine(other, (a,b) -> c)` | объединить два значения | `CF<C>` |
| `thenAcceptBoth(other, (a,b) -> {})` | потребить оба | `CF<Void>` |
| `runAfterBoth(other, () -> {})` | просто дождаться обоих | `CF<Void>` |
| `applyToEither(other, a -> c)` | взять **первый пришедший** результат | `CF<C>` |
| `acceptEither(other, a -> {})` | потребить первый | `CF<Void>` |
| `runAfterEither(other, () -> {})` | отреагировать на первый | `CF<Void>` |

Если любой из участников `thenCombine` упал — итог упал (проверено), второй результат никого не интересует, но его работа не отменяется.

### 5.5. Дерево решений

```
Следующий шаг зависит от результата?
├── нет  → два независимых вызова: thenCombine / allOf
└── да   → функция возвращает future?
           ├── да  → thenCompose
           └── нет → thenApply (значение) / thenAccept (сайд-эффект) / thenRun (ничего не нужно)
Нужен первый из нескольких? → anyOf (первый ЛЮБОЙ) или firstSuccessful (первый УСПЕШНЫЙ, §10.4)
Нужны все?                  → allOf + сбор через join (§9)
```

---

<a id="s6"></a>
## 6. Ошибки

### 6.1. Как исключение travels по цепочке

Исключение из любого звена «проваливается» вниз, **пропуская** все `thenApply`/`thenAccept`/`thenCompose`, пока не встретит `exceptionally`/`handle`/`whenComplete`.

```java
CompletableFuture.supplyAsync(() -> { throw new IllegalStateException("бум"); }, IO)
    .thenApply(s -> s + "!")        // пропущен
    .thenApply(s -> s + "?")        // пропущен
    .exceptionally(ex -> "дефолт")  // сработал
    .thenAccept(v -> log(v));       // дефолт
```

Исключение, брошенное **внутри** `supplyAsync`, не вылетает в вызывающий поток: оно фиксируется в future. Значит `try/catch` вокруг `supplyAsync(...)` бесполезен — ловить надо в цепочке или на `join`.

### 6.2. Обёртки: главная бытовая боль

`CompletableFuture` оборачивает исключения в `CompletionException` (при `join`/колбэках) и `ExecutionException` (при `get`). Что именно увидит ваш обработчик — **зависит от того, где произошла ошибка**. Измерено на JDK 17:

| Сценарий | Что получает `exceptionally`/`handle`/`whenComplete` |
|---|---|
| `supplyAsync` бросил `IllegalStateException` | `CompletionException` → `IllegalStateException` |
| `failedFuture(new IOException())`, обработчик сразу за ней | **сам `IOException`**, без обёртки |
| та же future, но между ней и обработчиком есть `thenApply` | `CompletionException` → `IOException` |
| `cf.completeExceptionally(new IOException())`, обработчик сразу | **сам `IOException`** |
| `join()` упавшей future | `CompletionException` → исходное |
| `get()` упавшей future | `ExecutionException` → исходное |
| отменённая future: `join()` | `CancellationException` |
| отменённая future: `join()` у **потомка** (`thenApply`) | `CompletionException` → `CancellationException` |

Вывод: **никогда не пишите `catch (CompletionException e)` в надежде на конкретный тип**. Разворачивайте:

```java
static Throwable unwrap(Throwable t) {
    Throwable cur = t;
    while ((cur instanceof CompletionException || cur instanceof ExecutionException)
            && cur.getCause() != null) cur = cur.getCause();
    return cur;
}

// применение
.exceptionally(ex -> {
    Throwable cause = unwrap(ex);
    if (cause instanceof TimeoutException) return cachedValue;
    if (cause instanceof NotFoundException) return null;
    throw new CompletionException(cause);   // остальные — дальше
})
```

### 6.3. Три обработчика: чем отличаются

| Метод | Когда вызывается | Может изменить результат? | Что летит дальше |
|---|---|---|---|
| `exceptionally(ex -> T)` | только при ошибке | **да**, вернуть запасное значение | ваш результат либо ваша новая ошибка |
| `handle((v, ex) -> U)` | всегда | **да**, оба канала | новый результат/ошибка |
| `whenComplete((v, ex) -> {})` | всегда | **нет** | **исходный** результат/ошибка |

```java
// exceptionally — «запасной аэродром», тип результата сохраняется
api.rating(id).exceptionally(ex -> 0.0);

// handle — превратить и успех, и ошибку в общий тип
api.rating(id).handle((value, ex) -> ex == null ? Result.ok(value) : Result.err(unwrap(ex)));

// whenComplete — только наблюдение (лог, метрика, освобождение ресурса)
api.rating(id).whenComplete((value, ex) -> {
    if (ex != null) log.warn("рейтинг недоступен", unwrap(ex));
});
```

Тонкости, проверенные экспериментом:

```java
// 1. whenComplete НЕ лечит ошибку. Классический баг:
cf.whenComplete((v, ex) -> log("ошибка " + ex))  // дальше ошибка летит как летела
  .thenAccept(v -> log("сюда не попадём"));

// 2. Если колбэк whenComplete сам бросил исключение, а источник уже упал —
//    выживает ИСХОДНОЕ исключение, новое теряется.
// 3. Если источник успешен, а whenComplete бросил — потомок упадёт с новым исключением.
// 4. Исключение, брошенное внутри exceptionally/handle, заменяет исходное.
// 5. exceptionally на успешной future не вызывается вообще.
```

### 6.4. Асинхронный fallback: `exceptionallyCompose` `12+`

```java
// нужно сходить в резервный сервис — он тоже асинхронный
api.primaryPrice(id)
   .exceptionallyCompose(ex -> api.backupPrice(id))     // 12+
   .exceptionally(ex -> Price.DEFAULT);                 // последний рубеж

// на Java 8–11 то же самое через handle + thenCompose:
api.primaryPrice(id)
   .handle((price, ex) -> ex == null ? CompletableFuture.completedFuture(price) : api.backupPrice(id))
   .thenCompose(Function.identity());
```

### 6.5. Checked-исключения в лямбдах

`Supplier`/`Function` не объявляют `throws`, поэтому checked-исключение приходится оборачивать:

```java
CompletableFuture.supplyAsync(() -> {
    try {
        return objectMapper.readValue(json, Product.class);   // throws JsonProcessingException
    } catch (JsonProcessingException e) {
        throw new CompletionException(e);                     // сохранили причину
    }
}, IO);
```

Не глотайте (`catch (Exception e) { return null; }`) — `null` вернётся как валидный результат и упадёт `NPE` через три звена, где уже никто не поймёт, что случилось.

> ✅ **Правило одного логирования.** Логируйте ошибку один раз — на границе, где принимаете решение (деградация/проброс). `whenComplete` с логом на каждой стадии превращает один сбой в десять строк стектрейса.
---

<a id="s7"></a>
## 7. Потоки и пулы: где на самом деле выполняется ваш код

### 7.1. Что такое `commonPool` и почему он вам не подходит

`ForkJoinPool.commonPool()` — общий пул на всю JVM:
* размер по умолчанию `Runtime.availableProcessors() − 1`;
* потоки **daemon** — при завершении `main` работа может быть брошена на середине;
* если параллельность получилась `≤ 1` (одно ядро, контейнер с лимитом CPU), `CompletableFuture` вообще **создаёт новый поток на каждую задачу** — это легко не заметить и получить тысячи потоков;
* им же пользуются `parallelStream()`, другие библиотеки, ваш фреймворк.

Эксперимент (запуск с `-Djava.util.concurrent.ForkJoinPool.common.parallelism=2`): забиваем `commonPool` двумя блокирующими делами и просим выполнить дешёвую задачу:

```java
for (int i = 0; i < 2; i++) CompletableFuture.runAsync(() -> sleep(600));  // забили пул
sleep(50);
long start = System.currentTimeMillis();
CompletableFuture.supplyAsync(() -> "дешёвая задача").join();
log("ждала " + (System.currentTimeMillis() - start) + " мс");
// [main] ждала 551 мс
```

Дешёвая задача ждала полсекунды, потому что все воркеры спали в `Thread.sleep`. В продакшене это выглядит как «под нагрузкой необъяснимо тормозит всё приложение», включая `parallelStream` в соседнем модуле.

> ✅ **Правило.** Блокирующий IO (HTTP, JDBC, файлы) — **только в свой выделенный пул**. `commonPool` — для коротких CPU-задач без блокировок.

### 7.2. Свой executor: минимальный продакшен-вариант

```java
static ExecutorService ioPool(String name, int threads, int queueCapacity) {
    AtomicInteger counter = new AtomicInteger();
    return new ThreadPoolExecutor(
            threads, threads,
            60, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(queueCapacity),                 // очередь ОГРАНИЧЕНА
            r -> {
                Thread t = new Thread(r, name + "-" + counter.incrementAndGet());
                t.setDaemon(false);                                  // для бизнес-задач лучше не daemon
                return t;
            },
            new ThreadPoolExecutor.AbortPolicy());                   // лучше явный отказ, чем тихая потеря
}
```

Что здесь важно и почему:
* **Имя потока** (`billing-io-3`) — без него разбор инцидента по логам невозможен.
* **Ограниченная очередь**: `Executors.newFixedThreadPool` использует неограниченную `LinkedBlockingQueue` — при перегрузе вы получите `OutOfMemoryError` вместо честного отказа.
* **Политика отказа**: `AbortPolicy` бросит `RejectedExecutionException` **синхронно из `supplyAsync`** — ещё один повод оборачивать создание future в `try/catch` на границе. `CallerRunsPolicy` даёт естественный backpressure, но выполняет блокирующий вызов на потоке вызывающего (для HTTP-сервера это часто хуже).
* **`shutdown()`** при остановке приложения. Пул, созданный внутри метода на каждый запрос, — утечка потоков (ловушка № 9).

**Сколько потоков?**
* CPU-bound: `ядра` или `ядра + 1`. Больше — только лишние переключения контекста.
* IO-bound: `ядра × (1 + время_ожидания / время_счёта)`. При 200 мс ожидания и 1 мс счёта на 4 ядрах формула даёт ~800 — на практике ставят поменьше и ограничивают сверху возможностями downstream-сервиса (нет смысла в 800 потоках, если у сервиса лимит 50 RPS). Реальный ориентир: начните с `2 × ядра … 50`, измерьте, скорректируйте.
* **Отдельный пул на каждый downstream** (bulkhead): медленный сервис рекомендаций не должен съедать потоки, нужные для оплаты.

### 7.3. Deadlock, который сложно диагностировать

```java
ExecutorService single = Executors.newFixedThreadPool(1);

CompletableFuture<String> outer = CompletableFuture.supplyAsync(() -> {
    CompletableFuture<String> inner = CompletableFuture.supplyAsync(() -> "inner", single);
    return inner.join();          // ждём задачу, которой нужен ЕДИНСТВЕННЫЙ занятый поток
}, single);

outer.get(400, TimeUnit.MILLISECONDS);   // TimeoutException — стадия не завершится никогда
```

Проверено: не завершится. Хуже того — `join()` **не реагирует на interrupt**, поэтому `single.shutdownNow()` не разбудит поток, и JVM не остановится. Симптомы в бою: тред-дамп с воркерами в `CompletableFuture.waitingGet`, растущая очередь, «сервис завис после деплоя».

Правила: **никогда не `join`/`get` внутри стадии на том же пуле**; вместо вложенного `join` — `thenCompose`; для вложенных задач — отдельный пул.

### 7.4. ThreadLocal, MDC, SecurityContext не переезжают в другой поток

```java
MDC.put("traceId", "req-42");
CompletableFuture.runAsync(() -> log.info("..."), IO);   // traceId потерян
```

Решение — декоратор executor, который снимает контекст в вызывающем потоке и восстанавливает в рабочем (проверено на `ThreadLocal`):

```java
static Executor contextAware(Executor delegate) {
    Map<String, String> captured = MDC.getCopyOfContextMap();   // снимок ЗДЕСЬ, в вызывающем потоке
    return task -> delegate.execute(() -> {
        Map<String, String> previous = MDC.getCopyOfContextMap();
        if (captured != null) MDC.setContextMap(captured); else MDC.clear();
        try {
            task.run();
        } finally {
            if (previous != null) MDC.setContextMap(previous); else MDC.clear();
        }
    });
}

// использовать КАЖДЫЙ раз, когда передаёте executor:
CompletableFuture.supplyAsync(() -> load(), contextAware(IO))
                 .thenApplyAsync(this::map, contextAware(IO));
```

Осторожно: снимок делается в момент вызова `contextAware(...)`, а не в момент выполнения задачи — для длинных цепочек создавайте обёртку один раз рядом со стартом запроса. `SecurityContextHolder`, транзакции Spring и `RequestScope` через границу потока тоже не переносятся — транзакцию нельзя «продолжить» в другом потоке.

### 7.5. Куда девать тяжёлый колбэк

| Ситуация | Решение |
|---|---|
| Колбэк — чистая функция на микросекунды | `thenApply` (не плодим переключения) |
| Колбэк парсит 10 МБ JSON / считает | `thenApplyAsync(fn, cpuPool)` |
| Колбэк делает блокирующий вызов | вынести в отдельную стадию `thenComposeAsync(x -> supplyAsync(..., ioPool), ioPool)` |
| Future завершает поток HTTP-клиента (Netty) | **обязательно** `*Async` со своим пулом: иначе блокируете event loop |

---

<a id="s8"></a>
## 8. Таймауты и отмена

### 8.1. `orTimeout` и `completeOnTimeout` `9+`

```java
CompletableFuture<Price> price = api.price(id)
        .orTimeout(500, TimeUnit.MILLISECONDS);          // упадёт TimeoutException

CompletableFuture<Double> rating = api.rating(id)
        .completeOnTimeout(0.0, 300, TimeUnit.MILLISECONDS);  // вернёт дефолт
```

Четыре факта, которые надо помнить (все проверены):
1. Оба метода **мутируют ту же самую future и возвращают `this`**, а не копию. `api.rating(id).completeOnTimeout(...)` меняет future, которую вам вернул клиент, — если она где-то расшарена, дефолт увидят все.
2. Они **не останавливают работу**. Задача доработает и потратит ресурсы; результат просто будет проигнорирован.
3. `orTimeout` даёт `TimeoutException`, обёрнутый в `CompletionException` при `join`.
4. `get(50, MS)` ведёт себя иначе: он не меняет future, а лишь ограничивает **ваше** ожидание. Future остаётся живой, и позже её можно использовать.

Разница на практике:

```java
// «Мне нужен ответ ИЛИ дефолт через 300 мс» — completeOnTimeout
// «Мне нужен ответ ИЛИ ошибка через 500 мс» — orTimeout
// «Я подожду 200 мс, а future пусть живёт (например, она в кэше)» — get(200, MS)
```

### 8.2. Таймаут на Java 8 (и когда нужен свой)

```java
static final ScheduledExecutorService TIMER = Executors.newScheduledThreadPool(1, r -> {
    Thread t = new Thread(r, "cf-timeout"); t.setDaemon(true); return t;
});

static <T> CompletableFuture<T> withTimeout(CompletableFuture<T> source, long ms) {
    CompletableFuture<T> result = new CompletableFuture<>();       // отдельная future!
    ScheduledFuture<?> alarm = TIMER.schedule(
            () -> result.completeExceptionally(new TimeoutException("timeout " + ms + " ms")),
            ms, TimeUnit.MILLISECONDS);
    source.whenComplete((value, ex) -> {
        alarm.cancel(false);                                       // не течём таймерами
        if (ex != null) result.completeExceptionally(ex); else result.complete(value);
    });
    return result;
}
```

Этот вариант полезен и на новых JDK, когда нельзя мутировать исходную future (она в кэше и её ждут другие).

### 8.3. Правда про `cancel`

```java
AtomicBoolean interrupted = new AtomicBoolean(false);
CompletableFuture<String> task = CompletableFuture.supplyAsync(() -> {
    try { Thread.sleep(400); } catch (InterruptedException e) { interrupted.set(true); }
    return "готово";
}, IO);
sleep(50);
task.cancel(true);      // true — «прервать, если выполняется»? НЕТ.
sleep(500);
log("прервана ли задача: " + interrupted.get());   // false — проверено
```

* `cancel(mayInterruptIfRunning)` у `CompletableFuture` **игнорирует аргумент**. Это просто `completeExceptionally(new CancellationException())`. Работа продолжается, поток не прерывается. В javadoc это написано прямым текстом — и это регулярно спрашивают на собеседованиях.
* Отменённая future: `isCancelled() == true`, `join()` бросает `CancellationException`.
* **Потомки** (`thenApply` и др.) получают `CompletionException(CancellationException)`, и их `isCancelled()` — `false`. Не проверяйте отмену по потомку.

Как сделать настоящую отмену — протащить её в клиент:

```java
static CompletableFuture<Response> call(Request request) {
    CompletableFuture<Response> cf = new CompletableFuture<>();
    Call http = httpClient.newCall(request);            // пример: OkHttp
    cf.whenComplete((v, ex) -> { if (cf.isCancelled()) http.cancel(); });
    http.enqueue(new Callback() {
        public void onResponse(Call c, Response r) { cf.complete(r); }
        public void onFailure(Call c, IOException e) { cf.completeExceptionally(e); }
    });
    return cf;
}
```

> ✅ **Правило.** Таймаут ставьте **в клиенте** (connect/read timeout) — он реально освобождает сокет и поток. `orTimeout` — страховка сверху, чтобы ваш пайплайн не завис, если клиент чего-то не учёл.

---

<a id="s9"></a>
## 9. Много future: `allOf` и `anyOf`

### 9.1. `allOf` — дождаться всех

```java
CompletableFuture<Void> all = CompletableFuture.allOf(f1, f2, f3);
```

Что важно (проверено):
* Возвращает `CompletableFuture<Void>` — **результатов внутри нет**, их собирают отдельно.
* Ждёт **все** future, даже если одна упала через 50 мс, а остальные работают 400 мс: `allOf` завершился через 402 мс. Раннего выхода нет.
* Если упала хотя бы одна — итог упавший. **Какое именно исключение вы получите — деталь реализации** (зависит от порядка аргументов, а не от времени падения). В эксперименте `allOf(f_late, f_early)` дал `late-fail`, а `allOf(f_early, f_late)` — `early-fail`. Никогда не стройте логику на «первом» исключении.
* `allOf()` без аргументов — уже завершённая future.
* `allOf` **не ограничивает параллелизм**: 1000 future — это 1000 одновременных запросов к downstream (§10.6).

### 9.2. Правильный сбор результатов: `sequence`

```java
static <T> CompletableFuture<List<T>> sequence(List<CompletableFuture<T>> futures) {
    return CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
            .thenApply(ignored -> futures.stream()
                    .map(CompletableFuture::join)     // безопасно: все уже завершены
                    .collect(Collectors.toList()));
}
```

Порядок сохраняется (он берётся из списка, а не из порядка завершения), `join` не блокирует, ошибка любой future корректно проваливается в итог. Это самый полезный утилитный метод в теме — выучите наизусть.

### 9.3. Частичный успех: не ронять всё из-за одного источника

```java
record Result<T>(T value, String error) {
    static <T> Result<T> ok(T v) { return new Result<>(v, null); }
    static <T> Result<T> err(String e) { return new Result<>(null, e); }
}

List<CompletableFuture<Result<Product>>> stages = ids.stream()
        .map(id -> api.product(id)
                .<Result<Product>>thenApply(Result::ok)                 // явный тип-параметр обязателен
                .exceptionally(ex -> Result.err(unwrap(ex).getMessage())))
        .collect(Collectors.toList());

List<Result<Product>> results = sequence(stages).join();
// [OK(Product[1]), ERR(product unavailable), OK(Product[3])]
```

Ключ: `exceptionally` ставится **на каждую** future до `allOf`. Тогда `allOf` не падает и вы получаете полную картину: что удалось, что нет. Это стандарт для агрегаторов и батч-эндпоинтов.

### 9.4. `anyOf` — первый завершившийся (не первый успешный!)

```java
CompletableFuture<Object> any = CompletableFuture.anyOf(mirror1, mirror2);
```

* Тип — `Object` (общий предок), придётся кастовать.
* Завершается **первым любым** исходом, включая ошибку: если самое быстрое зеркало падает за 30 мс, `anyOf` упадёт, хотя через 120 мс пришёл бы успешный ответ (проверено).
* Подходит для «гонки» однотипных запросов, где ошибка тоже приемлема, и для «первый сигнал» (данные или таймаут).

Для «первый **успешный**» нужен свой комбинатор — §10.4.

---

<a id="s10"></a>
## 10. Боевые паттерны (набор уверенного middle)

Домен для всех примеров — карточка товара. Клиент выглядит так (мок с задержкой 150 мс):

```java
record Product(long id, String title) {}
record Price(long id, double amount, String currency) {}
record Card(Product product, Price price, int stock, double rating, List<String> recs) {}

interface ShopApi {
    CompletableFuture<Product> product(long id);
    CompletableFuture<Price> price(long id);
    CompletableFuture<Integer> stock(long id);
    CompletableFuture<Double> rating(long id);        // некритичный
    CompletableFuture<List<String>> recs(long id);    // некритичный
}
```

### 10.1. Агрегатор: fan-out / fan-in с деградацией

```java
static CompletableFuture<Card> card(ShopApi api, long id) {
    CompletableFuture<Product> product = api.product(id);          // критичный
    CompletableFuture<Price>   price   = api.price(id);            // критичный
    CompletableFuture<Integer> stock   = api.stock(id);            // критичный

    CompletableFuture<Double> rating = api.rating(id)              // некритичный
            .completeOnTimeout(0.0, 300, TimeUnit.MILLISECONDS)
            .exceptionally(ex -> 0.0);

    CompletableFuture<List<String>> recs = api.recs(id)            // некритичный
            .completeOnTimeout(List.<String>of(), 300, TimeUnit.MILLISECONDS)
            .exceptionally(ex -> List.of());

    return CompletableFuture.allOf(product, price, stock, rating, recs)
            .thenApply(ignored -> new Card(product.join(), price.join(), stock.join(),
                                           rating.join(), recs.join()))
            .orTimeout(2, TimeUnit.SECONDS);                       // общий бюджет
}
```

Измеренное поведение (5 источников по 150 мс):

| Сценарий | Результат |
|---|---|
| всё живо | карточка за **165 мс** (вместо 750 мс последовательно) |
| упал `price` (критичный) | вся future падает с `IllegalStateException: price unavailable` |
| упали `rating` и `recs` | карточка собрана: `rating=0.0, recs=[]` |

Три принципа, которые здесь зашиты:
1. **Разделяйте критичные и некритичные источники.** Для некритичных — таймаут + дефолт, для критичных — честная ошибка.
2. **Таймаут на источник + общий бюджет.** Иначе 5 источников по 300 мс «легально» съедят 1.5 с.
3. **Никаких `join` до `allOf`.** `join` внутри `thenApply` после `allOf` безопасен: всё уже готово.

### 10.2. Retry с экспоненциальным backoff

```java
static <T> CompletableFuture<T> retry(Supplier<CompletableFuture<T>> action,
                                      int maxAttempts,
                                      long baseDelayMs,
                                      Predicate<Throwable> retryable) {
    CompletableFuture<T> result = new CompletableFuture<>();
    attempt(action, maxAttempts, baseDelayMs, retryable, 1, result);
    return result;
}

private static <T> void attempt(Supplier<CompletableFuture<T>> action, int max, long base,
                                Predicate<Throwable> retryable, int n, CompletableFuture<T> result) {
    CompletableFuture<T> call;
    try {
        call = action.get();                                   // Supplier, а не готовая future!
    } catch (Throwable t) {
        call = CompletableFuture.failedFuture(t);              // синхронный отказ тоже обрабатываем
    }
    call.whenComplete((value, error) -> {
        if (error == null) { result.complete(value); return; }
        Throwable cause = unwrap(error);
        if (n >= max || !retryable.test(cause)) { result.completeExceptionally(cause); return; }
        long delay = base * (1L << (n - 1));                   // 100, 200, 400, ...
        CompletableFuture.delayedExecutor(delay, TimeUnit.MILLISECONDS)
                .execute(() -> attempt(action, max, base, retryable, n + 1, result));
    });
}

// использование
retry(() -> api.price(id), 3, 100, ex -> ex instanceof IOException).join();
```

Замеры: `retry` c третьей попытки → `ok on attempt 3`; при постоянно падающем вызове — 3 попытки за 183 мс (10+50 + 10+100 + 10 мс) и последнее исключение наверх.

Почему именно так:
* **`Supplier`, а не `CompletableFuture`.** Уже созданная future завершена один раз навсегда — «повторить» её невозможно. Каждая попытка обязана создавать новый вызов.
* **Никакого `Thread.sleep` для backoff** — `delayedExecutor` `9+` не занимает поток.
* **Рекурсия через executor**, а не прямой вызов — иначе на длинных сериях получите `StackOverflowError`.
* **Предикат `retryable`**: ретраить нужно только временные сбои (сеть, 503, таймаут). 400/401/404 ретраить бессмысленно и вредно.
* Ретраи допустимы для **идемпотентных** операций либо при наличии idempotency-key. В бою добавьте jitter (`delay/2 + random(delay/2)`) и общий бюджет времени, иначе ретраи усилят аварию downstream.

### 10.3. Fallback-цепочка

```java
api.priceFromService(id)
   .exceptionallyCompose(ex -> api.priceFromCache(id))      // 12+
   .exceptionallyCompose(ex -> api.priceFromBackup(id))
   .completeOnTimeout(Price.DEFAULT, 700, TimeUnit.MILLISECONDS)
   .exceptionally(ex -> { metrics.inc("price.degraded"); return Price.DEFAULT; });
```

Порядок важен: сначала конкретные попытки, в конце — общий дефолт и метрика деградации.

### 10.4. Первый успешный (`anyOf` так не умеет)

```java
static <T> CompletableFuture<T> firstSuccessful(List<CompletableFuture<T>> futures) {
    CompletableFuture<T> result = new CompletableFuture<>();
    if (futures.isEmpty()) {
        result.completeExceptionally(new NoSuchElementException("нет источников"));
        return result;
    }
    AtomicInteger failuresLeft = new AtomicInteger(futures.size());
    for (CompletableFuture<T> f : futures) {
        f.whenComplete((value, error) -> {
            if (error == null) result.complete(value);                     // первый успех побеждает
            else if (failuresLeft.decrementAndGet() == 0)
                result.completeExceptionally(unwrap(error));               // упали все
        });
    }
    return result;
}
```

Проверено: быстрое зеркало падает за 20 мс, второе отвечает за 120 мс → результат `m2`; когда упали все — ошибка наверх. Побеждающая `complete` игнорирует поздние ответы (переход состояния один раз).

Что стоит доработать в бою: отменять проигравших (иначе платите за лишние запросы) и добавлять общий таймаут.

### 10.5. Дедупликация одинаковых запросов (in-flight кэш)

20 одновременных запросов одного товара должны дать **один** поход в сервис:

```java
static class AsyncCache<K, V> {
    private final ConcurrentHashMap<K, CompletableFuture<V>> map = new ConcurrentHashMap<>();
    private final Function<K, CompletableFuture<V>> loader;

    AsyncCache(Function<K, CompletableFuture<V>> loader) { this.loader = loader; }

    CompletableFuture<V> get(K key) {
        CompletableFuture<V> f = map.computeIfAbsent(key, loader);   // атомарно: один loader на ключ
        f.whenComplete((v, ex) -> { if (ex != null) map.remove(key, f); });  // ошибки не кэшируем
        return f;
    }
}
```

Проверено: 20 параллельных `get(42)` → **1 вызов** downstream. Наивный вариант `if (!map.containsKey(k)) map.put(k, load(k))` в том же тесте дал **2 вызова** — гонка.

Тонкости:
* Кэшируется **future, а не значение** — именно это склеивает одновременные запросы.
* `loader` обязан быть быстрым и неблокирующим (он выполняется под внутренней блокировкой мапы) и не должен трогать эту же мапу.
* `map.remove(key, f)` — двухаргументный, чтобы не удалить чужую более свежую future.
* Это защита от «стада», а не TTL-кэш. Для TTL храните пару «future + время» и инвалидируйте отдельно.

### 10.6. Ограничение параллелизма

`allOf` на 1000 элементов = 1000 одновременных запросов. Downstream умрёт, вы получите 503 и ретраи, которые добьют его. Четыре рабочих способа (все измерены на 12 задачах по 100 мс с лимитом 3):

| Способ | Макс. одновременно | Время | Когда выбирать |
|---|---|---|---|
| A. Выделенный пул на N потоков | 3 | ~400 мс | вызов **блокирующий** (JDBC, старый HTTP-клиент) |
| B. Семафор, permit берёт подающий поток | 3 | 411 мс | быстрый fan-out из одного потока, 5 строк кода |
| C. Чанки по N | 3 | 404 мс | простая пакетная обработка |
| D. N воркеров над очередью | 3 | 404 мс | большие батчи, нужна максимальная утилизация |

**A. Блокирующий вызов — просто ограничьте пул:**

```java
ExecutorService limited = Executors.newFixedThreadPool(3);   // в бою — с именем и ограниченной очередью
List<CompletableFuture<Product>> stages = ids.stream()
        .map(id -> CompletableFuture.supplyAsync(() -> blockingClient.product(id), limited))
        .collect(Collectors.toList());
```

**B. Семафор (для уже асинхронного клиента):**

```java
static <T, R> CompletableFuture<List<R>> semaphoreMap(List<T> items, int limit,
                                                      Function<T, CompletableFuture<R>> action) {
    Semaphore sem = new Semaphore(limit);
    List<CompletableFuture<R>> stages = new ArrayList<>();
    for (T item : items) {
        sem.acquireUninterruptibly();                    // блокируется ПОДАЮЩИЙ поток, не рабочий
        CompletableFuture<R> f;
        try {
            f = action.apply(item);
        } catch (Throwable t) {
            sem.release();                               // не забываем permit при синхронном отказе
            throw t;
        }
        stages.add(f.whenComplete((v, ex) -> sem.release()));   // освобождаем и при ошибке тоже
    }
    return sequence(stages);
}
```

Проверено: после серии падений все permit на месте (`availablePermits() == 2`).

> ⚠️ Не делайте `supplyAsync(() -> { sem.acquire(); ... })` — так permit ждут **рабочие** потоки пула, и вы блокируете именно то, что хотели сэкономить.

**C. Чанки** — просто, но каждый чанк ждёт самого медленного:

```java
static <T, R> CompletableFuture<List<R>> chunkMap(List<T> items, int size,
                                                  Function<T, CompletableFuture<R>> action) {
    CompletableFuture<List<R>> acc = CompletableFuture.completedFuture(new ArrayList<>());
    for (int i = 0; i < items.size(); i += size) {
        List<T> chunk = items.subList(i, Math.min(i + size, items.size()));
        acc = acc.thenCompose(done -> sequence(chunk.stream().map(action).collect(Collectors.toList()))
                .thenApply(rs -> { done.addAll(rs); return done; }));
    }
    return acc;
}
```

**D. N воркеров** — точный лимит без блокировок, «конвейер»: каждый воркер, закончив элемент, берёт следующий.

```java
static <T, R> CompletableFuture<List<R>> workerMap(List<T> items, int limit,
                                                   Function<T, CompletableFuture<R>> action,
                                                   Executor scheduler) {
    int n = items.size();
    List<CompletableFuture<R>> results = new ArrayList<>(n);
    for (int i = 0; i < n; i++) results.add(new CompletableFuture<>());   // слоты = порядок сохранён
    AtomicInteger cursor = new AtomicInteger();
    Runnable[] worker = new Runnable[1];
    worker[0] = () -> {
        int i = cursor.getAndIncrement();
        if (i >= n) return;
        CompletableFuture<R> slot = results.get(i);
        CompletableFuture<R> call;
        try { call = action.apply(items.get(i)); }
        catch (Throwable t) { call = CompletableFuture.failedFuture(t); }
        call.whenComplete((v, ex) -> {
            if (ex != null) slot.completeExceptionally(ex); else slot.complete(v);
            scheduler.execute(worker[0]);        // трамплин: следующий элемент — новой задачей
        });
    };
    for (int w = 0; w < Math.min(limit, n); w++) scheduler.execute(worker[0]);
    return sequence(results);
}
```

Проверено: 12 задач, лимит 3 → максимум 3 в работе, порядок сохранён; 20 000 мгновенных future — без переполнения стека. **Трамплин `scheduler.execute(...)` обязателен**: если вызывать `worker[0].run()` напрямую, а future завершаются синхронно (`completedFuture`), получится рекурсия глубиной в размер списка. В эксперименте с `Runnable::run` в качестве scheduler это привело к зависанию — часть слотов никогда не завершилась.

### 10.7. Мост из callback-API

```java
static CompletableFuture<Response> call(Request request) {
    CompletableFuture<Response> cf = new CompletableFuture<>();
    client.executeAsync(request, new Callback() {
        @Override public void onSuccess(Response r) { cf.complete(r); }
        @Override public void onFailure(Throwable t) { cf.completeExceptionally(t); }
    });
    return cf;
}
```

Правила моста: **ровно один** `complete`/`completeExceptionally` на всех путях (включая исключения при подписке), таймаут сверху, отмена — пробросить в клиент (§8.3). Если клиент бросает исключение синхронно при подписке — оберните в `try/catch` и завершите future ошибкой, иначе вызывающий получит исключение мимо асинхронного контракта.

### 10.8. Polling: ждать состояния, не занимая поток

```java
static CompletableFuture<Void> pollUntil(Supplier<CompletableFuture<Boolean>> check,
                                         Duration interval, Duration timeout) {
    CompletableFuture<Void> result = new CompletableFuture<>();
    long deadline = System.nanoTime() + timeout.toNanos();
    Runnable[] tick = new Runnable[1];
    tick[0] = () -> {
        if (result.isDone()) return;
        if (System.nanoTime() > deadline) {
            result.completeExceptionally(new TimeoutException("poll timeout"));
            return;
        }
        check.get().whenComplete((ready, err) -> {
            if (result.isDone()) return;
            if (err != null) { result.completeExceptionally(err); return; }
            if (Boolean.TRUE.equals(ready)) { result.complete(null); return; }
            CompletableFuture.delayedExecutor(interval.toMillis(), TimeUnit.MILLISECONDS).execute(tick[0]);
        });
    };
    tick[0].run();
    return result;
}
```

Проверено: условие стало истинным на 3-й проверке → успех; вечно ложное условие → `TimeoutException` ровно по дедлайну. Ни один поток не спит между проверками.

### 10.9. Как тестировать асинхронный код детерминированно

Три приёма, которые убирают `Thread.sleep` и флаки-тесты.

**1) Прямой executor — всё выполняется в потоке теста:**

```java
Executor direct = Runnable::run;
String value = CompletableFuture.supplyAsync(() -> "stub", direct)
        .thenApplyAsync(s -> s + "-mapped", direct)     // помните: Executor есть только у *Async
        .join();
assertEquals("stub-mapped", value);
```

**2) Ручные «шлюзы» — вы сами решаете, когда придёт ответ:**

```java
CompletableFuture<Product> gate = new CompletableFuture<>();   // stub api возвращает gate
when(api.product(42)).thenReturn(gate);

CompletableFuture<Card> card = service.card(42);
assertFalse(card.isDone());          // ещё ничего не завершено
gate.complete(new Product(42, "x")); // «ответ пришёл»
assertEquals(42, card.join().product().id());
```

Проверено: до `complete` конвейер стоит и колбэки не выполнялись; после — выполнились ровно один раз, в потоке теста.

**3) Проверка ошибок и таймаутов:**

```java
CompletableFuture<Card> failed = service.card(42);
gate.completeExceptionally(new IllegalStateException("price down"));

CompletionException ex = assertThrows(CompletionException.class, failed::join);
assertInstanceOf(IllegalStateException.class, unwrap(ex));

// таймаут тестируется на НИКОГДА не завершающейся future — тест длится миллисекунды
CompletableFuture<String> never = new CompletableFuture<>();
assertThrows(CompletionException.class,
        () -> never.orTimeout(10, TimeUnit.MILLISECONDS).join());
```

Чек-лист теста агрегатора: успех всех источников; падение критичного; падение/таймаут некритичного → дефолт; порядок результатов в батче; лимит параллелизма (счётчик `AtomicInteger` max-in-flight); число вызовов downstream при дедупликации.

Если совсем без шлюзов — используйте Awaitility (`await().atMost(1, SECONDS).until(...)`), но **не** `Thread.sleep(500)`: это медленно и нестабильно на CI.

---

<a id="s11"></a>
## 11. Четырнадцать ловушек

| # | Ловушка | Почему плохо | Как надо |
|---|---|---|---|
| 1 | `supplyAsync` без executor для IO | `commonPool` на `ядра−1`, общий с `parallelStream`, daemon | свой именованный пул |
| 2 | `.map(x -> supplyAsync(...)).map(CF::join)` в одном стриме | ленивый стрим → строго последовательно (замер: 804 мс вместо 202) | сначала `.collect(toList())`, потом второй стрим с `join` |
| 3 | `thenApply` с функцией, возвращающей future | `CF<CF<T>>`, двойной `join` | `thenCompose` |
| 4 | `join`/`get` внутри стадии на том же пуле | deadlock; `join` не прерывается, `shutdownNow` не спасает | `thenCompose`, отдельный пул |
| 5 | `whenComplete` как «обработка ошибки» | не меняет исход, ошибка летит дальше | `exceptionally` / `handle` |
| 6 | `exceptionally(ex -> null)` | маскирует сбой, `NPE` через три звена | дефолт по типу ошибки или проброс |
| 7 | `catch (CompletionException e)` с расчётом на тип | обёртки зависят от места падения (§6.2) | `unwrap` + `instanceof` по причине |
| 8 | `try/catch` вокруг `supplyAsync` | исключение уходит в future, а не в вызывающий поток | обработка в цепочке |
| 9 | `Executors.newFixedThreadPool(...)` внутри метода на каждый запрос | утечка потоков, JVM не останавливается | один пул на компонент, `shutdown` на остановке |
| 10 | `cancel(true)` «останавливает задачу» | не прерывает; работа продолжается | отмена в клиенте + таймауты |
| 11 | `orTimeout` «останавливает работу» | только завершает future; ресурсы тратятся | таймауты в клиенте |
| 12 | `allOf` «вернёт результаты» / «упадёт сразу» | `Void`, ждёт всех, исключение — деталь реализации | `sequence` + `exceptionally` на каждую |
| 13 | `anyOf` как «первый успешный» | первый **любой**, в том числе ошибка | `firstSuccessful` (§10.4) |
| 14 | MDC/транзакция/SecurityContext «сами переедут» | `ThreadLocal` привязан к потоку | декоратор executor, явная передача контекста |

Бонус-ловушка № 15: `CompletableFuture` без единого обработчика ошибок. Если никто не вызвал `join`, `exceptionally`, `handle` или `whenComplete`, исключение **исчезает молча** — ни в логах, ни в метриках. У любого «fire-and-forget» пайплайна должен быть терминальный `.whenComplete((v, ex) -> { if (ex != null) log.error(...); })`.

---

<a id="s12"></a>
## 12. Шпаргалка

### 12.1. Все методы по группам

| Группа | Методы |
|---|---|
| Создание | `completedFuture`, `supplyAsync`, `runAsync`, `new CompletableFuture<>()`, `failedFuture` `9+`, `completedStage` `9+`, `completeAsync` `9+`, `delayedExecutor` `9+` |
| Завершение вручную | `complete`, `completeExceptionally`, `cancel`, `obtrudeValue`/`obtrudeException` (не используйте) |
| Состояние | `isDone`, `isCompletedExceptionally`, `isCancelled`, `getNumberOfDependents` |
| Получение | `join`, `get`, `get(timeout)`, `getNow`, `resultNow` `19+`, `exceptionNow` `19+` |
| Продолжения | `thenApply(Async)`, `thenAccept(Async)`, `thenRun(Async)` |
| Последовательно | `thenCompose(Async)` |
| Два вместе | `thenCombine(Async)`, `thenAcceptBoth(Async)`, `runAfterBoth(Async)` |
| Первый из двух | `applyToEither(Async)`, `acceptEither(Async)`, `runAfterEither(Async)` |
| Ошибки | `exceptionally`, `exceptionallyCompose` `12+`, `exceptionallyAsync` `12+`, `handle(Async)`, `whenComplete(Async)` |
| Таймауты | `orTimeout` `9+`, `completeOnTimeout` `9+` |
| Много future | `allOf`, `anyOf` |
| Прочее | `copy` `9+`, `minimalCompletionStage` `9+`, `newIncompleteFuture` `9+`, `defaultExecutor` `9+` |

### 12.2. Типы в одну строку

```java
thenApply:      CF<T> × (T -> U)                 → CF<U>
thenCompose:    CF<T> × (T -> CF<U>)             → CF<U>
thenCombine:    CF<T> × CF<U> × (T,U -> V)       → CF<V>
exceptionally:  CF<T> × (Throwable -> T)         → CF<T>
handle:         CF<T> × (T,Throwable -> U)       → CF<U>
whenComplete:   CF<T> × (T,Throwable -> void)    → CF<T>
allOf:          CF<?>...                         → CF<Void>
anyOf:          CF<?>...                         → CF<Object>
```

### 12.3. Чек-лист ревью асинхронного кода

- [ ] У каждого `*Async` указан **свой** executor (или есть обоснование для `commonPool`).
- [ ] Пулы именованы, ограничены, создаются один раз и закрываются при остановке.
- [ ] Нет `join`/`get` внутри стадий; `join` только на границах.
- [ ] Нет `Thread.sleep` для задержек/ретраев — `delayedExecutor`.
- [ ] Все ошибки где-то обработаны; нет `exceptionally(ex -> null)` и пустых `catch`.
- [ ] Типы ошибок разбираются через `unwrap`, а не по обёртке.
- [ ] Есть таймаут на каждый внешний вызов **и** общий бюджет операции.
- [ ] Некритичные источники деградируют, критичные — честно падают.
- [ ] Параллелизм ограничен, если элементов может быть много.
- [ ] Ретраи только для идемпотентных операций и временных ошибок, с backoff и лимитом.
- [ ] Контекст (traceId/MDC) переносится явно.
- [ ] Тесты детерминированы: прямой executor или ручные шлюзы, без `sleep`.

---

<a id="s13"></a>
## 13. Задачи

25 задач: A — основы, B — композиция, C — ошибки и таймауты, D — боевые паттерны, E — code review. Сложность: ★ разминка, ★★ уверенный junior+, ★★★ middle.

Решения — в [разделе 15](#s15). Сначала попробуйте сами: даже 15 минут борьбы с задачей дают больше, чем прочитанное решение.

### Стенд для задач

Мок внешнего сервиса: задержка настраивается, любой метод можно «сломать», счётчик вызовов позволяет проверять дедупликацию и ретраи.

```java
class Api {
    private final Executor io;
    private final long delayMs;
    final Set<String> broken = ConcurrentHashMap.newKeySet();
    final AtomicInteger calls = new AtomicInteger();
    final AtomicInteger flakyAttempts = new AtomicInteger();

    Api(Executor io, long delayMs) { this.io = io; this.delayMs = delayMs; }

    private <T> CompletableFuture<T> call(String name, Supplier<T> body) {
        return CompletableFuture.supplyAsync(() -> {
            calls.incrementAndGet();
            sleep(delayMs);
            if (broken.contains(name)) throw new IllegalStateException(name + " unavailable");
            return body.get();
        }, io);
    }

    CompletableFuture<Product> product(long id) { return call("product", () -> new Product(id, "Товар-" + id)); }
    CompletableFuture<Price> price(long id)     { return call("price", () -> new Price(id, 99.9 * id, "RUB")); }
    CompletableFuture<Integer> stock(long id)   { return call("stock", () -> (int) (id * 7)); }
    CompletableFuture<Double> rating(long id)   { return call("rating", () -> 4.5); }
    CompletableFuture<List<String>> recs(long id) { return call("recs", () -> List.of("r1", "r2")); }

    CompletableFuture<String> mirror(String name, long ms) {
        return CompletableFuture.supplyAsync(() -> {
            sleep(ms);
            if (broken.contains(name)) throw new IllegalStateException(name + " down");
            return name;
        }, io);
    }

    /** Падает первые две попытки, потом успешен. */
    CompletableFuture<String> flaky() {
        return CompletableFuture.supplyAsync(() -> {
            int n = flakyAttempts.incrementAndGet();
            if (n < 3) throw new IllegalStateException("attempt " + n + " failed");
            return "ok on attempt " + n;
        }, io);
    }
}
```

---

### Блок A. Основы

**A1 ★ Конвейер.** `supplyAsync` возвращает `"  hello  "` через 100 мс. Постройте цепочку: обрезать пробелы → в верхний регистр → добавить `"!"` → напечатать результат вместе с именем потока. В `main` не должно быть промежуточных `join`.
*Проверь себя:* результат `HELLO!`; все колбэки выполнились в одном io-потоке; `main` дошёл до финального `join` раньше, чем началась работа.

**A2 ★★ Предскажи потоки.** Не запуская код, напишите на бумаге, какой поток выполнит каждую из шести строк. Потом запустите и сравните.

```java
CompletableFuture<String> ready = CompletableFuture.completedFuture("R");
ready.thenApply(s -> { log("1"); return s; });                       // ?

CompletableFuture<String> f = CompletableFuture.supplyAsync(() -> { log("2"); sleep(100); return "A"; }, IO);
f.thenApply(s -> { log("3"); return s; });                           // ?
f.thenApplyAsync(s -> { log("4"); return s; });                      // ?
f.thenApplyAsync(s -> { log("5"); return s; }, IO);                  // ?
f.join();
ready.thenApply(s -> { log("6"); return s; });                       // ?
```

*Проверь себя:* объясните каждый ответ одним из трёх правил из §5.2.

**A3 ★★ Мост из listener-API.** Дано:

```java
interface Listener { void onSuccess(String value); void onError(Throwable t); }
interface Subscription { void cancel(); }
static Subscription subscribe(String request, Listener listener) { /* ... */ }
```

Сделайте `CompletableFuture<String> fromCallback(String request)`. Требования: успех и ошибка попадают в future; повторный вызов `onSuccess` не меняет результат; при отмене future вызывается `subscription.cancel()`; синхронное исключение из `subscribe` не вылетает наружу.
*Проверь себя:* `complete` второй раз возвращает `false`; после `cf.cancel(true)` флаг отмены у подписки выставлен.

**A4 ★★ Синхронная граница.** Напишите `String awaitOr(CompletableFuture<String> cf, long timeoutMs, String fallback)`:
* успели — вернуть значение;
* таймаут — вернуть `fallback` (и не отменять future);
* ошибка результата — бросить `ServiceException` с **развёрнутой** причиной;
* поток прервали — восстановить флаг прерывания и бросить `ServiceException`.

*Проверь себя:* три теста (успех / никогда не завершающаяся future / упавшая future) проходят; `Thread.currentThread().isInterrupted()` после перехвата — `true`.

**A5 ★ Кэш «если готово».** Напишите `String cachedOr(CompletableFuture<String> cached, String fallback)`: готово успешно → значение; ещё не готово → `fallback`; упало → `fallback` **без исключения**.
*Подвох:* наивно написанный вариант падает на третьем сценарии. Объясните, почему.

---

### Блок B. Композиция

**B1 ★ Убери матрёшку.** Дан код:

```java
CompletableFuture<CompletableFuture<List<String>>> nested =
        api.product(id).thenApply(p -> api.recs(p.id()));
List<String> recs = nested.join().join();
```

Перепишите так, чтобы тип был `CompletableFuture<List<String>>`. Объясните, почему общее время — сумма задержек, а не максимум.

**B2 ★★ Параллельно за 200 мс.** `api.product(id)` и `api.price(id)` работают по 200 мс. Соберите `CompletableFuture<String>` вида `"Товар-1 / 99.9 RUB"` за ~200 мс. Замерьте оба варианта — через `thenCompose` и через `thenCombine` — и объясните разницу в 2 раза.

**B3 ★★ `sequence`.** Реализуйте `static <T> CompletableFuture<List<T>> sequence(List<CompletableFuture<T>> futures)`.
*Проверь себя:* пустой список → уже завершённая future с пустым списком; порядок результата совпадает с порядком входа, даже если первая future самая медленная; ошибка любой future → ошибка итога; ни одного блокирующего `join` до готовности всех.

**B4 ★★★ Батч с лимитом.** 50 id, задержка 100 мс на вызов, одновременно — не больше 5. Требования: порядок результатов сохранён; максимум 5 «в полёте» (проверяется счётчиком); пул не забит блокирующими ожиданиями; при ошибке одного элемента итог падает. Вторая часть: соберите **частичные** результаты (`OK`/`ERR`), не роняя весь батч.
*Проверь себя:* общее время ≈ 50/5 × 100 мс = 1 с; `maxInFlight == 5`.

**B5 ★★★ Первый успешный.** Три зеркала: `m1` падает через 20 мс, `m2` отвечает через 120 мс, `m3` — через 300 мс. Нужен результат `m2` и общий таймаут 500 мс. Объясните, почему `anyOf` здесь не годится, и реализуйте `firstSuccessful`.
*Дополнительно:* отмените проигравшие future после победы.

---

### Блок C. Ошибки и таймауты

**C1 ★ Почини обработку.** Что вернёт этот код и почему обработчик «не работает»? Исправьте двумя способами.

```java
CompletableFuture<String> result = api.recs(1)
        .thenApply(list -> list.get(0))
        .whenComplete((v, ex) -> { if (ex != null) log("упало: " + ex); })
        .thenApply(s -> "первая рекомендация: " + s);
```

**C2 ★★ Разбор исключений.** Цепочка из четырёх звеньев, второе падает. Напишите обработчик, который: `NotFoundException` → дефолтное значение; `TimeoutException` → значение из кэша; остальное → пробросить дальше с сохранением причины. Проверьте на двух источниках ошибки: `supplyAsync(() -> { throw ...; })` и `cf.completeExceptionally(...)`. Объясните, почему обработчик видит разные типы обёрток.

**C3 ★★ Таймауты.** Соберите: рейтинг — дефолт `0.0` через 300 мс; цена — ошибка через 500 мс. Докажите счётчиком, что работа **не остановилась** после таймаута. Объясните разницу между `completeOnTimeout`, `orTimeout` и `get(timeout)` и когда нужен каждый.

**C4 ★★★ Retry.** Реализуйте `retry(Supplier<CompletableFuture<T>> action, int maxAttempts, long baseDelayMs, Predicate<Throwable> retryable)` c экспоненциальным backoff (100 → 200 → 400), без `Thread.sleep`. Требования: `api.flaky()` успешен с третьей попытки; `IllegalArgumentException` не ретраится; после исчерпания попыток наверх уходит **последнее** исключение, развёрнутое; синхронное исключение из `action.get()` тоже обрабатывается.
*Проверь себя:* `calls == 3` в обоих сценариях; суммарная задержка ≈ 300 мс + время вызовов.

**C5 ★★ Отмена.** Докажите экспериментом, что `cancel(true)` не прерывает уже запущенную задачу. Затем сделайте отмену, которая действительно останавливает работу (через `Subscription` из A3). Ответьте: что вернёт `isCancelled()` у потомка `cf.thenApply(...)` и какое исключение поймает `join()` у потомка?

---

### Блок D. Боевые паттерны

**D1 ★★★ Агрегатор карточки.** Соберите `CompletableFuture<Card> card(Api api, long id)` из пяти источников (§10.1): `product`, `price`, `stock` — критичные; `rating`, `recs` — некритичные (таймаут 300 мс + дефолт). Общий бюджет — 2 с.
*Проверь себя (4 сценария):* всё живо → ~150 мс при задержке 150 мс; `broken.add("price")` → ошибка; `broken.add("rating"); broken.add("recs")` → карточка с дефолтами; задержка 3 с у критичного источника → `TimeoutException` через 2 с.

**D2 ★★★ In-flight кэш.** Реализуйте `AsyncCache<K, V>` c дедупликацией. Требования: 20 одновременных `get(42)` → ровно **один** вызов `api.product`; упавшая загрузка не остаётся в кэше; успешная — остаётся; `loader` не вызывается под блокирующей работой.
*Дополнительно:* объясните, почему наивный `containsKey` + `put` даёт дубли (в эксперименте — 2 вызова вместо 1), и добавьте TTL.

**D3 ★★★ Лимитер без блокировок.** Реализуйте `workerMap(items, limit, action, scheduler)` (§10.6 D). Требования: максимум `limit` в полёте; порядок сохранён; работает на 20 000 мгновенных `completedFuture` без `StackOverflowError`; ошибка элемента попадает в его слот и не ломает остальных.
*Проверь себя:* объясните, зачем нужен `scheduler.execute(...)` вместо прямого `run()`.

**D4 ★★ Polling.** Реализуйте `pollUntil(check, interval, timeout)` на `delayedExecutor`. Требования: успех на третьей проверке; вечная ложь → `TimeoutException` по дедлайну; ни один поток не спит между проверками; ошибка проверки уходит наверх немедленно.

**D5 ★★★ Детерминированные тесты.** Покройте агрегатор из D1 тремя тестами **без `Thread.sleep`**: успех, падение критичного источника, таймаут некритичного. Используйте ручной шлюз (`new CompletableFuture<>()`) и/или прямой executor. Четвёртый тест: батч из B4 не превышает лимит параллелизма.

---

### Блок E. Code review: найди баг

Для каждого фрагмента: (1) что не так, (2) к чему приведёт в бою, (3) как исправить.

**E1 ★★**
```java
List<Product> products = ids.stream()
        .map(id -> CompletableFuture.supplyAsync(() -> client.product(id), IO))
        .map(CompletableFuture::join)
        .collect(Collectors.toList());
```

**E2 ★★★**
```java
CompletableFuture<String> load(long id) {
    return CompletableFuture.supplyAsync(() -> {
        CompletableFuture<String> price = CompletableFuture.supplyAsync(() -> client.price(id), IO);
        return client.title(id) + " / " + price.join();
    }, IO);
}
// IO = Executors.newFixedThreadPool(2)
```

**E3 ★★**
```java
CompletableFuture<Price> price(long id) {
    return client.priceAsync(id)
            .whenComplete((p, ex) -> { if (ex != null) log.error("цена упала", ex); })
            .exceptionally(ex -> null)
            .thenApply(p -> p.withDiscount(0.1));
}
```

**E4 ★★**
```java
public CompletableFuture<Card> card(long id) {
    ExecutorService pool = Executors.newFixedThreadPool(4);
    CompletableFuture<Product> p = CompletableFuture.supplyAsync(() -> client.product(id), pool);
    CompletableFuture<Price> pr = CompletableFuture.supplyAsync(() -> client.price(id), pool);
    return p.thenCombine(pr, Card::of);
}
```

**E5 ★★★**
```java
class PriceCache {
    private final Map<Long, CompletableFuture<Price>> map = new ConcurrentHashMap<>();

    CompletableFuture<Price> get(long id) {
        if (!map.containsKey(id)) {
            map.put(id, client.priceAsync(id));
        }
        return map.get(id);
    }
}
```

---

<a id="s14"></a>
## 14. Контрольные вопросы

1. Почему `CompletableFuture` — это не поток? Что именно хранится внутри?
2. В каком потоке выполнится `thenApply`, если предыдущая стадия уже завершена? А если нет?
3. Чем `thenCompose` отличается от `thenApply` и как выбрать?
4. Почему `allOf` не возвращает результаты и как их правильно собрать?
5. `allOf` из трёх future: одна упала через 10 мс, две другие работают секунду. Когда завершится `allOf`?
6. Чем `anyOf` отличается от «первого успешного»?
7. Что увидит `exceptionally`, если ошибка брошена в `supplyAsync`? А если future создана через `failedFuture`?
8. Почему `whenComplete` не подходит для восстановления после ошибки?
9. Что делает `cancel(true)` у `CompletableFuture` и чего он **не** делает?
10. `orTimeout` vs `completeOnTimeout` vs `get(timeout)` — три разных поведения. Какие?
11. Почему блокирующий IO в `commonPool` — плохая идея? Назовите два конкретных последствия.
12. Как протестировать асинхронный агрегатор без `Thread.sleep`?

---

<a id="s15"></a>
## 15. Решения и ответы

### Блок A

**A1.**
```java
CompletableFuture<String> pipeline = CompletableFuture
        .supplyAsync(() -> { sleep(100); return "  hello  "; }, IO)
        .thenApply(String::trim)
        .thenApply(String::toUpperCase)
        .thenApply(s -> s + "!");

log("main свободен");                       // напечатается ДО работы
pipeline.thenAccept(s -> log("результат: " + s)).join();
```
Все колбэки выполнятся в одном io-потоке (правило 1 из §5.2). `join` вызван у последней стадии — только он и блокирует `main`.

**A2.** Реальный вывод одного из прогонов:
```
[main]  1
[io-12] 2
[main]  3      ← сюрприз!
[main]  6
[Thread-2] 4
[io-13] 5
```
Разбор:
* **1** — `main`: future уже завершена на момент подписки (правило 2).
* **2** — io-поток: тело `supplyAsync` (правило 3, явный executor).
* **3** — «обычно io, но может и `main`». Здесь сработало правило 4: `main` стоял в `join()`, увидел завершение и помог разобрать очередь подписчиков раньше, чем это сделал io-поток. Гонка, а не баг.
* **4** — поток `commonPool`. На машине с 2 ядрами параллельность commonPool = 1, поэтому вместо `ForkJoinPool.commonPool-worker-N` создан отдельный поток `Thread-2` (§7.1).
* **5** — io-поток из явного executor (правило 3), причём **другой** io-поток, не тот, что выполнял тело.
* **6** — `main` (правило 2).

Вывод, который надо усвоить: у не-Async колбэка нет «своего» потока. Если поток важен — `*Async` + executor.

**A3.**
```java
static CompletableFuture<String> fromCallback(String request) {
    CompletableFuture<String> cf = new CompletableFuture<>();
    Subscription subscription;
    try {
        subscription = subscribe(request, new Listener() {
            @Override public void onSuccess(String value) { cf.complete(value); }
            @Override public void onError(Throwable t)    { cf.completeExceptionally(t); }
        });
    } catch (Throwable t) {
        cf.completeExceptionally(t);            // синхронный сбой — тоже в future
        return cf;
    }
    final Subscription s = subscription;
    cf.whenComplete((v, ex) -> { if (cf.isCancelled()) s.cancel(); });
    return cf;
}
```
Повторный `onSuccess` безопасен: второй `complete` вернёт `false` (проверено: значение осталось `value-1`). Если future отменят до подписки на `whenComplete`, колбэк выполнится сразу и отмена всё равно доедет до клиента.

**A4.**
```java
static class ServiceException extends RuntimeException {
    ServiceException(Throwable cause) { super(cause); }
    ServiceException(String msg, Throwable cause) { super(msg, cause); }
}

static String awaitOr(CompletableFuture<String> cf, long timeoutMs, String fallback) {
    try {
        return cf.get(timeoutMs, TimeUnit.MILLISECONDS);
    } catch (TimeoutException e) {
        log("таймаут " + timeoutMs + " мс — деградация");
        return fallback;                       // future НЕ отменяем
    } catch (ExecutionException e) {
        throw new ServiceException(unwrap(e));
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();    // без этого вы «съедите» прерывание
        throw new ServiceException("прервано", e);
    }
}
```
Проверено: успех → `V`; никогда не завершающаяся future → `FB`; упавшая → `ServiceException` с причиной `NotFoundException`; interrupt → `isInterrupted() == true`.

**A5.**
```java
static String cachedOr(CompletableFuture<String> cached, String fallback) {
    if (!cached.isDone()) return fallback;
    try {
        return cached.getNow(fallback);
    } catch (CompletionException | CancellationException e) {
        log("кэш упал: " + unwrap(e));
        return fallback;
    }
}
```
Подвох: `getNow` возвращает дефолт **только для незавершённой** future; на упавшей он бросает `CompletionException`, а на отменённой — `CancellationException`.Важно: `CancellationException` **не наследуется** от `CompletionException` (это `IllegalStateException`), поэтому ловить надо оба типа.

### Блок B

**B1.**
```java
CompletableFuture<List<String>> recs = api.product(id).thenCompose(p -> api.recs(p.id()));
```
`thenApply` оборачивает результат в ещё одну future (`CF<CF<T>>`), `thenCompose` «расплющивает» её. Время = сумма (замер: **405 мс** при двух вызовах по 200 мс), потому что второй запрос зависит от результата первого и стартует только после него. Это не недостаток `thenCompose` — это природа зависимости.

**B2.**
```java
String page = api.product(1)
        .thenCombine(api.price(1), (p, pr) -> p.title() + " / " + pr.amount() + " " + pr.currency())
        .join();
// thenCombine: Товар-1 / 99.9 RUB за 213 мс   (thenCompose дал 405 мс)
```
Оба вызова стартуют в момент вычисления аргументов, то есть одновременно. `thenCombine` только ждёт оба результата.

**B3.**
```java
static <T> CompletableFuture<List<T>> sequence(List<CompletableFuture<T>> futures) {
    return CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
            .thenApply(ignored -> futures.stream()
                    .map(CompletableFuture::join)
                    .collect(Collectors.toList()));
}
```
* Пустой список: `allOf()` уже завершён → `thenApply` выполнится сразу в вызывающем потоке, результат — пустой список.
* Порядок: берём из исходного списка, а не из порядка завершения.
* Ошибка: `allOf` упадёт, `thenApply` пропустится, ошибка доедет до итога.
* `join` внутри `thenApply` не блокирует: `allOf` гарантирует готовность всех.

**B4.** Каркас с семафором (полные варианты — §10.6):
```java
Semaphore sem = new Semaphore(5);
List<CompletableFuture<Product>> stages = new ArrayList<>();
for (long id : ids) {
    sem.acquireUninterruptibly();                              // permit берёт подающий поток
    stages.add(api.product(id).whenComplete((v, ex) -> sem.release()));
}
List<Product> products = sequence(stages).join();              // порядок сохранён
```
Проверка лимита — счётчик в моке:
```java
AtomicInteger inFlight = new AtomicInteger(), max = new AtomicInteger();
// внутри вызова: max.accumulateAndGet(inFlight.incrementAndGet(), Math::max); ... inFlight.decrementAndGet();
assertEquals(5, max.get());
```
Частичные результаты (батч не падает целиком):
```java
stages.add(api.product(id)
        .<Result<Product>>thenApply(Result::ok)
        .exceptionally(ex -> Result.err(unwrap(ex).getMessage()))
        .whenComplete((r, ex) -> sem.release()));               // release — в самом конце
```
Замер на 12 элементах с лимитом 3 и задержкой 100 мс: максимум 3 в полёте, ~400 мс, порядок сохранён.

**B5.**
```java
CompletableFuture<String> best = firstSuccessful(List.of(
        api.mirror("m1", 20),      // падает
        api.mirror("m2", 120),
        api.mirror("m3", 300)))
    .orTimeout(500, TimeUnit.MILLISECONDS);
// результат: m2
```
Реализация `firstSuccessful` — §10.4. `anyOf` не годится: он завершается **первым любым** исходом, и падение `m1` за 20 мс уронило бы всю гонку (проверено). Отмена проигравших:
```java
best.whenComplete((v, ex) -> futures.forEach(f -> f.cancel(true)));
```
Честная оговорка: это отменит только future — реальный запрос продолжится, пока вы не пробросите отмену в клиент (§8.3).

### Блок C

**C1.** Код **не** восстанавливается: `whenComplete` лишь наблюдает, ошибка летит дальше, `thenApply` пропускается, итоговая future — упавшая. На `join()` вы получите `CompletionException(IllegalStateException: recs unavailable)` (проверено). Два исправления:
```java
// 1) запасное значение того же типа
.exceptionally(ex -> "нет рекомендаций")
.thenApply(s -> "первая: " + s)          // → «первая: нет рекомендаций»

// 2) обработать оба канала сразу
.handle((v, ex) -> ex == null ? "первая: " + v : "нет рекомендаций")   // → «нет рекомендаций»
```

**C2.**
```java
.exceptionally(ex -> {
    Throwable cause = unwrap(ex);
    if (cause instanceof NotFoundException) return DEFAULT;
    if (cause instanceof TimeoutException)    return cache.get(id);
    throw new CompletionException(cause);     // остальное — наверх, причина сохранена
})
```
Проверено на четырёх сценариях: `NotFoundException` из `supplyAsync` → `DEFAULT`; `TimeoutException` → `CACHED`; `completeExceptionally(new NotFoundException(...))` → `DEFAULT`; `IllegalStateException` → проброс. Обёртки разные (§6.2): ошибка из `supplyAsync` приходит в `CompletionException`, а «ручная» — как есть; `unwrap` делает обработчик одинаковым для обоих случаев.

**C3.**
```java
AtomicInteger finished = new AtomicInteger();

CompletableFuture<Double> rating = CompletableFuture
        .supplyAsync(() -> { sleep(600); finished.incrementAndGet(); return 4.5; }, IO)
        .completeOnTimeout(0.0, 300, TimeUnit.MILLISECONDS);
log("rating = " + rating.join());                 // 0.0 через 300 мс
sleep(500);
log("работа всё равно закончилась: " + finished.get());   // 1 — доказательство

CompletableFuture<Price> price = api.price(id).orTimeout(500, TimeUnit.MILLISECONDS);
// join() → CompletionException(TimeoutException)
```

| | Что происходит с future | Что происходит с работой |
|---|---|---|
| `completeOnTimeout(v, t)` | завершается **значением** `v` | продолжается |
| `orTimeout(t)` | завершается **ошибкой** `TimeoutException` | продолжается |
| `get(t)` | **не меняется**, остаётся живой | продолжается |

**C4.** Реализация — §10.2 (`retry` + `attempt`). Использование:
```java
retry(api::flaky, 3, 100, ex -> !(ex instanceof IllegalArgumentException)).join();
// ok on attempt 3, calls == 3, задержка ≈ 100 + 200 мс
```
Ключевые моменты: `Supplier` вместо готовой future (иначе повторять нечего); `delayedExecutor` вместо `sleep`; рекурсия через executor; `unwrap` перед предикатом; последнее исключение уходит наверх развёрнутым; синхронный сбой `action.get()` превращается в `failedFuture`.

**C5.**
```java
AtomicBoolean interrupted = new AtomicBoolean();
CompletableFuture<String> task = CompletableFuture.supplyAsync(() -> {
    try { Thread.sleep(400); } catch (InterruptedException e) { interrupted.set(true); }
    return "готово";
}, IO);
sleep(50);
task.cancel(true);
sleep(500);
log("прервана: " + interrupted.get());     // false — работа доработала
```
Настоящая отмена — проброс в клиента: `cf.whenComplete((v, ex) -> { if (cf.isCancelled()) subscription.cancel(); })` (см. A3).
Ответы: у потомка `cf.thenApply(...)` `isCancelled()` — **`false`**, а `join()` бросит **`CompletionException` с причиной `CancellationException`**; у самой отменённой future `join()` бросает `CancellationException` напрямую.

### Блок D

**D1.** Базовый вариант — §10.1. Для тестируемости вынесите таймауты в параметры:
```java
static CompletableFuture<Card> card(Api api, long id, long sideTimeoutMs, long budgetMs) {
    CompletableFuture<Product> product = api.product(id);
    CompletableFuture<Price>   price   = api.price(id);
    CompletableFuture<Integer> stock   = api.stock(id);
    CompletableFuture<Double> rating = api.rating(id)
            .completeOnTimeout(0.0, sideTimeoutMs, TimeUnit.MILLISECONDS).exceptionally(ex -> 0.0);
    CompletableFuture<List<String>> recs = api.recs(id)
            .completeOnTimeout(List.<String>of(), sideTimeoutMs, TimeUnit.MILLISECONDS).exceptionally(ex -> List.of());

    return CompletableFuture.allOf(product, price, stock, rating, recs)
            .thenApply(v -> new Card(product.join(), price.join(), stock.join(), rating.join(), recs.join()))
            .orTimeout(budgetMs, TimeUnit.MILLISECONDS);
}
```
Проверенные сценарии: успех — 165 мс при пяти источниках по 150 мс; `broken.add("price")` — ошибка `price unavailable`; `broken.add("rating"); broken.add("recs")` — карточка с `0.0` и `[]`; «вечный» критичный источник — `TimeoutException` ровно по бюджету.

**D2.**
```java
static class AsyncCache<K, V> {
    private final ConcurrentHashMap<K, CompletableFuture<V>> map = new ConcurrentHashMap<>();
    private final Function<K, CompletableFuture<V>> loader;

    AsyncCache(Function<K, CompletableFuture<V>> loader) { this.loader = loader; }

    CompletableFuture<V> get(K key) {
        CompletableFuture<V> f = map.computeIfAbsent(key, loader);
        f.whenComplete((v, ex) -> { if (ex != null) map.remove(key, f); });
        return f;
    }
}
```
Проверено: 20 одновременных `get(42)` → `api.calls == 1`; после неудачной загрузки ключа в мапе нет; наивный `containsKey` + `put` дал 2 вызова.

Почему так:
* `computeIfAbsent` атомарен — второй поток видит уже созданную future и подписывается на неё, а не создаёт вторую загрузку;
* кэшируем **future**: она «склеивает» всех, кто пришёл, пока результат ещё в пути;
* `remove(key, f)` (двухаргументный) не удалит более свежую загрузку, если кто-то уже успел её положить;
* `loader` выполняется под внутренней блокировкой корзины мапы — если он блокирующий, вы задержите несвязанные ключи; он должен только **создать** future, а не ждать её.

TTL-вариант: храните `record Entry<V>(CompletableFuture<V> future, long expiresAt)` и в `get` проверяйте срок, заменяя запись через `map.compute(...)`; для «обновить, но пока отдать старое» — отдавайте старую future и параллельно запускайте обновление.

**D3.** Реализация — §10.6 D. Ответ на «зачем `scheduler.execute`»: без него воркер вызывает сам себя напрямую из `whenComplete`. Если future завершаются синхронно (`completedFuture`), вызовы вкладываются друг в друга на глубину списка → `StackOverflowError`; ошибка при этом «съедается» внутри колбэка, часть слотов никогда не завершается и `join` висит вечно (воспроизведено на 20 000 элементов). Трамплин превращает рекурсию в очередь задач. Проверено: с реальным executor 20 000 мгновенных future обрабатываются корректно и в порядке.

**D4.** Реализация — §10.8. Проверено: условие истинно на 3-й проверке → успех; вечная ложь → `TimeoutException` по дедлайну; ошибка проверки уходит наверх сразу. Между проверками нет ни одного спящего потока: `delayedExecutor` держит только задачу в таймере. `if (result.isDone()) return;` в двух местах защищает от гонки «таймаут и успешный ответ одновременно».

**D5.** Детерминированные тесты на ручных шлюзах (JUnit 5). `card(...)` — статический метод из D1 (подразумевается статический импорт). Стаб — наследник стенда, который отдаёт заготовленные future:
```java
class CardTest {
    private final CompletableFuture<Product> productGate = new CompletableFuture<>();
    private final CompletableFuture<Price>   priceGate   = new CompletableFuture<>();
    private final CompletableFuture<Integer> stockGate   = new CompletableFuture<>();
    private final CompletableFuture<Double>  ratingGate  = new CompletableFuture<>();
    private final CompletableFuture<List<String>> recsGate = new CompletableFuture<>();

    private final Api stub = new Api(Runnable::run, 0) {
        @Override CompletableFuture<Product> product(long id) { return productGate; }
        @Override CompletableFuture<Price> price(long id)     { return priceGate; }
        @Override CompletableFuture<Integer> stock(long id)   { return stockGate; }
        @Override CompletableFuture<Double> rating(long id)   { return ratingGate; }
        @Override CompletableFuture<List<String>> recs(long id) { return recsGate; }
    };

    @Test void собираетКарточкуКогдаВсеОтветили() {
        CompletableFuture<Card> card = card(stub, 42, 20, 500);
        assertFalse(card.isDone());                       // ничего не завершено — конвейер стоит
        productGate.complete(new Product(42, "x"));
        priceGate.complete(new Price(42, 10, "RUB"));
        stockGate.complete(3);
        ratingGate.complete(4.8);
        recsGate.complete(List.of("r"));
        assertEquals(4.8, card.join().rating());
    }

    @Test void падаетКогдаУпалКритичныйИсточник() {
        CompletableFuture<Card> card = card(stub, 42, 20, 500);
        priceGate.completeExceptionally(new IllegalStateException("price down"));
        CompletionException ex = assertThrows(CompletionException.class, card::join);
        assertInstanceOf(IllegalStateException.class, unwrap(ex));
    }

    @Test void деградируетКогдаНекритичныйМолчит() {
        productGate.complete(new Product(42, "x"));
        priceGate.complete(new Price(42, 10, "RUB"));
        stockGate.complete(3);
        // ratingGate и recsGate не завершаем никогда
        Card card = card(stub, 42, 20, 500).join();       // таймаут 20 мс — тест быстрый
        assertEquals(0.0, card.rating());
        assertTrue(card.recs().isEmpty());
    }

    @Test void соблюдаетОбщийБюджет() {
        // productGate не завершаем
        CompletableFuture<Card> card = card(stub, 42, 20, 30);
        CompletionException ex = assertThrows(CompletionException.class, card::join);
        assertInstanceOf(TimeoutException.class, unwrap(ex));
    }
}
```
Все четыре сценария проверены (третий длится ~20 мс, четвёртый ~30 мс). Тот же приём с Mockito: `when(api.price(42)).thenReturn(priceGate)`.

Тест лимита параллелизма — тоже без `sleep`: считаем **стартовавшие** вызовы.
```java
List<CompletableFuture<Integer>> gates = new ArrayList<>();
CompletableFuture<List<Integer>> all = workerMap(ids, 3, i -> {
    CompletableFuture<Integer> gate = new CompletableFuture<>();
    gates.add(gate);
    return gate;
}, Runnable::run);

assertEquals(3, gates.size());     // стартовало ровно limit
gates.get(0).complete(1);
assertEquals(4, gates.size());     // освободился слот — стартовал следующий
```
Проверено: 3 → 4 → 6 после трёх ответов, итоговый порядок `[1..10]`.

### Блок E

**E1.** Ленивый стрим: `map` с `join` выполняется поэлементно, поэтому вызовы идут **последовательно** (замер: 804 мс вместо 202 мс на четырёх задачах по 200 мс). Исправление — материализовать future до блокировок:
```java
List<CompletableFuture<Product>> futures = ids.stream()
        .map(id -> CompletableFuture.supplyAsync(() -> client.product(id), IO))
        .collect(Collectors.toList());                     // все стартовали
List<Product> products = futures.stream().map(CompletableFuture::join).collect(Collectors.toList());
// или просто: sequence(futures).join()
```

**E2.** Deadlock: внешняя задача занимает поток пула и внутри `join` ждёт внутреннюю, которой нужен тот же пул. На пуле из 2 потоков при двух одновременных запросах всё встаёт навсегда; `join` не прерывается, `shutdownNow` не поможет (§7.3). Исправление — композиция без блокировок:
```java
CompletableFuture<String> load(long id) {
    return client.titleAsync(id).thenCombine(client.priceAsync(id), (title, price) -> title + " / " + price);
}
// если title блокирующий:
CompletableFuture<String> load(long id) {
    return CompletableFuture.supplyAsync(() -> client.title(id), IO)
            .thenCombine(client.priceAsync(id), (title, price) -> title + " / " + price);
}
```

**E3.** Два бага: `whenComplete` не обрабатывает ошибку (только логирует), а `exceptionally(ex -> null)` превращает сбой в «валидный» `null` → `NPE` в `thenApply(p -> p.withDiscount(...))`, причём в стеке не будет ни слова про цену. Исправление:
```java
CompletableFuture<Price> price(long id) {
    return client.priceAsync(id)
            .exceptionally(ex -> {
                Throwable cause = unwrap(ex);
                if (cause instanceof TimeoutException) return Price.UNKNOWN;   // осмысленная деградация
                throw new CompletionException(cause);                          // остальное — наверх
            })
            .thenApply(p -> p.withDiscount(0.1));
}
```
Логирование — один раз на границе, где принимается решение; метрика деградации обязательна.

**E4.** Пул создаётся **на каждый запрос** и никогда не закрывается: 4 потока на запрос, при 1000 запросов — 4000 живых потоков, `OutOfMemoryError: unable to create native thread`, JVM не завершается. Плюс `Card::of` из двух аргументов не соберёт карточку из пяти источников — но главная проблема именно пул. Исправление — один разделяемый пул на компонент (инжектится, закрывается при остановке приложения):
```java
class CardService {
    private final Executor io;                       // один пул, имя, ограниченная очередь
    CardService(Executor io) { this.io = io; }

    CompletableFuture<Card> card(long id) {
        return CompletableFuture.supplyAsync(() -> client.product(id), io)
                .thenCombine(CompletableFuture.supplyAsync(() -> client.price(id), io), Card::of);
    }
}
```

**E5.** Три бага: (1) `containsKey` + `put` — гонка, одновременные запросы создают несколько загрузок (замер: 2 вместо 1); (2) `map.get(id)` может вернуть `null`, если другой поток ещё не положил запись → `NPE` у вызывающего; (3) упавшая future остаётся в кэше **навсегда** — один сбой отравляет ключ до перезапуска. Исправление — `AsyncCache` из D2: `computeIfAbsent` + удаление при ошибке (и TTL, если нужно).

### Ответы на контрольные вопросы

1. Внутри — ссылка на результат (или ошибку) и стек подписчиков; поток — лишь исполнитель. Future можно завершить из любого потока, включая тот, где пришёл колбэк; несколько future могут обслуживаться одним потоком.
2. Если стадия уже завершена — в потоке, вызвавшем `thenXxx`. Если нет — в потоке, завершившем стадию, **но** `join`/`get` тоже разбирают очередь подписчиков, поэтому возможен поток, вызвавший `join` (§5.2, правило 4).
3. `thenApply` — для функции `T -> U`; `thenCompose` — для `T -> CompletableFuture<U>` (flatMap), иначе получите `CF<CF<U>>`.
4. `allOf` возвращает `CF<Void>`: типы участников могут быть разными. Результаты собирают через `sequence`: `allOf(...).thenApply(v -> futures.stream().map(CF::join)...)`.
5. Через секунду — `allOf` ждёт **все** future, раннего выхода при ошибке нет (замер: 402 мс при падении на 50-й мс).
6. `anyOf` завершается первым **любым** исходом, включая исключение; «первый успешный» ждёт успеха и падает только если упали все.
7. Из `supplyAsync` — `CompletionException` с причиной; из `failedFuture` (без промежуточных стадий) — само исключение. Поэтому нужен `unwrap` (§6.2).
8. Он не меняет результат: возвращает future с тем же исходом. Для восстановления — `exceptionally`/`handle`.
9. Завершает future `CancellationException`; **не** прерывает поток и не останавливает работу, аргумент `mayInterruptIfRunning` игнорируется.
10. `completeOnTimeout` — завершить значением; `orTimeout` — завершить ошибкой (оба мутируют ту же future и возвращают `this`); `get(timeout)` — ограничить только ожидание, future остаётся живой. Ни один не останавливает работу.
11. Пул крошечный (`ядра − 1`) и общий: блокирующие задачи выедают воркеров, из-за чего ждут даже дешёвые задачи и `parallelStream` в других модулях (замер: 551 мс ожидания); потоки daemon — работа может быть брошена при завершении `main`; при параллельности ≤ 1 создаётся новый поток на каждую задачу.
12. Прямой executor (`Runnable::run`) и/или ручные шлюзы `new CompletableFuture<>()`, которые тест завершает сам; таймауты параметризовать и ставить маленькими; проверять `isDone()` до и после; ошибки — через `assertThrows(CompletionException.class, cf::join)` + `unwrap`.

---

<a id="s16"></a>
## 16. Что дальше

### 16.1. Java 21+: виртуальные потоки меняют экономику, но не композицию

```java
// Java 21+, на JDK 17 не запускается
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    CompletableFuture<Product> product = CompletableFuture.supplyAsync(() -> client.product(id), executor);
    CompletableFuture<Price> price     = CompletableFuture.supplyAsync(() -> client.price(id), executor);
    return product.thenCombine(price, Card::of).join();
}   // close() ждёт завершения задач
```

Что изменилось: блокирующий вызов больше не «съедает» дорогой поток ОС, поэтому пулы на 200 потоков ради IO не нужны — можно писать простой блокирующий код на виртуальных потоках. Что **не** изменилось: композиция результатов, таймауты, деградация, дедупликация, лимиты параллелизма (теперь их держат семафоры, а не размер пула) — всё это по-прежнему удобно выражать через `CompletableFuture`.

`StructuredTaskScope` (structured concurrency) — идейная альтернатива для «дерева задач» с автоматической отменой сиблингов при ошибке. API всё ещё в статусе preview: в JDK 25 это [JEP 525](https://openjdk.org/jeps/525) (шестой preview, конструкторы заменены статическими фабриками), в JDK 27 — [JEP 533](https://openjdk.org/jeps/533) (седьмой preview). В продакшен-код на LTS пока брать рано, но знать направление полезно.

### 16.2. Когда `CompletableFuture`, а когда другое

| Инструмент | Сильная сторона | Когда брать |
|---|---|---|
| `CompletableFuture` | композиция конечного числа асинхронных операций, ошибки, таймауты | запрос-ответ, агрегаторы, батчи — 90 % прикладных задач |
| Виртуальные потоки (21+) | простой блокирующий стиль без цены за поток | много IO-ожиданий, «поток на запрос» |
| Reactor / RxJava | потоки событий, backpressure, операторы над последовательностями | стриминг, SSE, реактивные драйверы, сложные пайплайны данных |
| `ExecutorService.invokeAll` | простой синхронный fan-out с таймаутом | небольшой батч в синхронном коде, где асинхронность не нужна наружу |
| Spring `@Async` | интеграция с DI, транзакциями, контекстом | «выстрелить и забыть» в Spring-приложении (возвращайте `CompletableFuture`, а не `void`) |

### 16.3. Что почитать

* **Javadoc `CompletableFuture`** — реально хороший текст, особенно про `cancel` и про то, кто выполняет колбэки.
* **Исходники JDK**: `AsyncSupply.run`, `uniApply`, `postComplete`, `UniExceptionally`, `andTree`. Час чтения снимает 90 % вопросов «почему так».
* **Aleksey Shipilëv** — доклады и статьи про `ForkJoinPool`, `commonPool` и JMH; «JDK-8160402» и родственные баги хорошо показывают эволюцию семантики.
* **Brian Goetz, «Java Concurrency in Practice»** — база про пулы, отмену, прерывания и публикацию объектов (главы 6–8).
* **JEP 444** (виртуальные потоки) и JEP 525/533 (structured concurrency) — куда движется платформа.

### 16.4. Проверка себя: что вы теперь умеете

- [ ] Объяснить, в каком потоке выполнится колбэк, и почему полагаться на это нельзя.
- [ ] Собрать агрегатор из 5 источников с деградацией некритичных и общим бюджетом.
- [ ] Написать `sequence`, `firstSuccessful`, `retry`, `AsyncCache`, лимитер — по памяти.
- [ ] Найти в чужом коде `join` внутри стадии, `exceptionally(ex -> null)` и пул на каждый запрос.
- [ ] Протестировать всё это без единого `Thread.sleep`.

Если все пять пунктов даются легко — вы уверенно закрываете тему на уровне middle. Дальше растёт не знание API, а вкус: где асинхронность действительно нужна, а где она лишь усложняет код.
