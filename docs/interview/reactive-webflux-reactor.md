# Реактивное программирование (WebFlux + Reactor)

### 1. Что такое Project Reactor и зачем он нужен

**Project Reactor** — это реализация спецификации **Reactive Streams** (`Publisher`, `Subscriber`, `Subscription`, `Processor`) для Java, которая даёт два типа операторов:
- **`Mono<T>`** — поток с **0 или 1** элементом (аналог `Optional`/`Future` с backpressure).
- **`Flux<T>`** — поток с **0, 1 или N** элементами.

Зачем он нужен:
- **Backpressure (обратное давление)**: подписчик может сообщить издателю, сколько элементов он готов принять (`request(n)`). Издатель не «заливает» медленного потребителя — это защищает от переполнения буферов и `OutOfMemoryError` в высоконагруженных системах.
- **Ленивое исполнение (lazy)**: ни один оператор не выполняется при построении цепочки — всё запускается только при **подписке** (`subscribe()`).
- **Отказоустойчивость**: ошибки передаются по цепочке через сигнал `onError` и обрабатываются операторами (`onErrorResume`, `retry` и т.д.) — нет «потерянных» исключений, как у `CompletableFuture`.
- **Масштабируемость на few thread'ах**: Reactor рассчитан на 4–8 event-loop потоков (`Schedulers.parallel()`) вместо thread pool на сотни потоков — актуально до прихода виртуальных потоков.
- **Интеграция**: официальный реактивный стек Spring Boot 3 (WebFlux, R2DBC, WebClient).

```java
Mono.just("hello")
    .map(String::toUpperCase)
    .subscribe(System.out::println); // "HELLO" — исполнение начинается здесь
```

**Когда НЕ нужен**: синхронный код с `ExecutorService`/`CompletableFuture` проще читается; с виртуальными потоками (Java 21) «синхронный» код уже масштабируется, и Reactor нужен в основном ради **потоков событий** и **backpressure**, а не ради async.


### 2. Чем Flux отличается от Mono

| | `Mono<T>` | `Flux<T>` |
|---|---|---|
| Количество элементов | 0 или 1 | 0, 1 или N |
| Типичный сценарий | «запрос → ответ» (REST, JPA find) | «поток событий» (SSE, WebSocket, чанки, Kafka consumer) |
| Терминал | `subscribe`, `block`, `blockFirst` | `subscribe`, `blockFirst`, `collectList` |
| Операторы | ~150 | ~300 (все из Mono + агрегация по потоку) |

Ключевые различия в поведении:
- **`Flux#blockFirst()`** — блокируется до **первого** элемента (аналог `Mono#block`); `Flux#blockLast()` — до последнего.
- **Преобразование**: `Flux#next()` → `Mono` (первый элемент), `Flux#single()` → `Mono` (исключение, если элементов ≠ 1), `Mono#flux()` → `Flux` (тупое обёртывание).
- **Ошибки**: у обоих тип `onError(throwable)`; у `Flux` дополнительно можно обработать ошибку **после** доставки части элементов (partial failure), у `Mono` — только до.
- **Ресурсы**: `Mono` не требует подписки, чтобы «знать» об отсутствии элемента — `Mono.empty()` легитимно; у `Flux` пустой поток = сразу `onComplete`.

Правило выбора: **одна сущность или её отсутствие → Mono; коллекция/поток → Flux**.


### 3. Какие операторы у Flux есть: map, flatMap, merge, zip

**Превращающие (transform):**
- **`map(fn)`** — синхронное 1-в-1 преобразование каждого элемента.
- **`flatMap(fn)`** — 1-в-N: каждый элемент превращается во `Flux`/`Mono`, все подпотоки **сливаются параллельно**. Критично: без лимита `flatMap` на 10 000 элементов создаёт 10 000 параллельных подписок → OOM. Ограничивается параметром `flatMap(fn, maxConcurrency)`.
- **`concatMap(fn)`** — то же, но **последовательно**: следующий подпоток стартует только после завершения предыдущего (сохраняет порядок, нет всплеска).
- **`flatMapSequential(fn, maxConcurrency)`** — параллельное исполнение, **порядок выдачи** как у исходного (компромисс между flatMap и concatMap).
- **`mapNotOperator`** — нет; есть `map`, `handle`, `transform`.

**Слияние (combinators):**
- **`Flux.merge(a, b, c)`** — статический: подписывается на все потоки, элементы выдаются по мере готовности (интерлевинг), завершается когда все завершатся.
- **`Flux.concat(a, b)`** — статический: один за другим (a полностью завершится → b).
- **`a.zip(b)`** — поэлементная пара: `(a1, b1), (a2, b2), ...` — завершается при завершении **короткого**.
- **`a.zipWith(b)`** — то же с лямбдой: `(a, b) -> ...`.
- **`a.combineLatest(b)`** — при каждом новом элементе из любого потока выдаёт актуальные значения из обоих.

**Агрегация:**
- `collectList()`, `collect(() -> new ArrayList<>())`, `reduce`, `scan`, `buffer(5)`, `window(5)`, `groupBy`, `chunk().concatMap(...)`.

**Пример слияния с ограничением:**
```java
Flux.range(1, 10_000)
    .flatMap(i -> fetchRemote(i), 16) // не больше 16 параллельных запросов
    .collectList()
    .block();
```

**Почему flatMap — самый частый источник багов**: разработчик привык к «синхронному» мышлению и не понимает, что `fetchRemote` — это **асинхронная подписка**, а не вызов. Если `fetchRemote` внутри блокирует (`.block()` в реактивном коде) — это блокирует event-loop поток → deadlock/зависание. Правило: **никогда не блокируй внутри реактивной цепочки**.


### 4. Что такое backpressure и как он работает

**Backpressure (обратное давление)** — механизм, при котором **подписчик управляет темпом** издателя. Это ключевое отличие от «просто пуш» (callback'ов, listen-ер'ов).

**Протокол (Reactive Streams):**
1. Подписчик вызывает `Subscriber.onSubscribe(Subscription s)`.
2. Подписчик отправляет `s.request(n)` — «доставь мне n элементов».
3. Издатель доставляет **не больше** `n` элементов через `onNext`.
4. Подписчик вызывает `request(n)` снова, когда готов ещё.
5. Издатель завершается `onComplete` или ошибается `onError`.

**Стратегии Reactor (когда подписчик не успевает):**
- **`onBackpressureBuffer()`** — накапливает в памяти всё, что не принято (риск OOM).
- **`onBackpressureBuffer(n)`** — буфер на n элементов, дальше **`onError`** (BackpressureError).
- **`onBackpressureDrop()`** — отбрасывает новые элементы, пока подписчик не попросит больше.
- **`onBackpressureLatest()`** — хранит только **последний** элемент, старые отбрасываются (для «последнего состояния»: курс валют, позиция на карте).
- **`onBackpressureError()`** — сразу `onError(RejectedExecutionError)` при превышении.
- **`onBackpressureDrop(handler)`** — отбрасывает + вызывает callback на отброшенное (для метрик).

**Как включить**:
```java
Flux.range(1, 10_000)
    .onBackpressureBuffer(100)
    .subscribe(i -> Thread.sleep(10)); // подписчик медленный
```

**Когда это важно**:
- **WebSocket/SSE** — клиент может не успевать рисить; drop/latest корректно.
- **Kafka consumer → обработчик** — если обработчик медленнее, buffer накапливает (контролируется `maxInFlight`).
- **Сеть**: `WebClient` имеет встроенный backpressure на socket buffer.

**Частая ошибка**: `onBackpressureBuffer()` без лимита на высокоскоростном потоке → OOM. Всегда ставь **лимит** или `drop`.

**Важно**: backpressure работает **только в пределах одной цепочки Reactor**. На границах (JDBC, блокирующие I/O, Kafka listener) он обрывается — там нужно вручную ограничивать параллелизм (`flatMap(fn, n)`) или использовать реактивные драйверы (R2DBC).


### 5. Как устроены Schedulers в Reactor: parallel, single, boundedElastic, immediate

`Scheduler` — абстракция над «где выполнять код». Reactor предоставляет:

- **`Schedulers.parallel()`** — фиксированный пул **N процессоров** потоков (event-loop'ы). Для **CPU-bound** задач, быстрых преобразований. **Никогда не блокируй** — это убивает event-loop'ы для всех подписчиков.
- **`Schedulers.single()`** — один поток, FIFO, для **порядковых** операций (например, запись в логи, идиотные `delayElements`).
- **`Schedulers.boundedElastic()`** — **гибрид**: пул до **10 × N процессоров**, при исчерпании создаёт новые, но **каждый поток живёт не больше 60 сек** без нагрузки (иначе убивается и создаётся новый). Для **блокирующих** операций (JDBC, `Thread.sleep`, legacy синхронные API). Это **безопасный способ** выполнить блокирующую задачу в реактивном коде.
- **`Schedulers.immediate()`** — **deprecated в 3.x**, поведение ≈ `parallel`. Не использовать.
- **`Schedulers.newSingle()`, `newParallel()`, `newBoundedElastic()`** — свои инстансы (не разделяй с глобальными, если нужен изолированный пул).
- **`Schedulers.fromExecutor(ExecutorService)`** — обёртка над произвольным `Executor`.

**Как использовать**:
```java
// CPU-bound: map на параллельном пуле
Flux.range(1, 100)
    .parallel(4)
    .runOn(Schedulers.parallel())
    .map(i -> heavyCpu(i))
    .seq();

// Блокирующий I/O: на boundedElastic
Flux.just("id1", "id2")
    .flatMap(id -> Mono.fromCallable(() -> blockingJdbcCall(id))
        .subscribeOn(Schedulers.boundedElastic()));
```

**Типичная ошибка**: `subscribeOn` на **последнем** этапе цепочки не работает как ожидается — `subscribeOn` влияет на **весь** поток (начало), `publishOn` — только на **этапы после** него. Правило:
- `subscribeOn(scheduler)` — «начни подписку и всё, что до publishOn, на этом Scheduler'е».
- `publishOn(scheduler)` — «всё, что **после** этой точки, выполнится на другом Scheduler'е».

```java
Flux.just(1, 2, 3)
    .doOnNext(i -> log("before publishOn"))  // Scheduler A
    .publishOn(Schedulers.parallel())
    .doOnNext(i -> log("after publishOn"))   // Scheduler B
    .subscribeOn(Schedulers.boundedElastic()); // A — «до» publishOn
```

**Когда что**:
| Задача | Scheduler |
|---|---|
| Быстрые вычисления, map/flatMap | `parallel()` |
| Блокирующие вызовы (JDBC, sleep) | `boundedElastic()` |
| Последовательные операции | `single()` |
| «Не важно, где» (быстрые операции) | `immediate()` / без |

**Важно**: Reactor **не** использует виртуальные потоки по умолчанию — это **event-loop** модель. С Java 21 можно написать свой `Scheduler` на виртуальных потоках, но обычно достаточно `boundedElastic` (в 3.2+ он оптимизирован под виртуальные потоки).


### 6. Что такое Context в Reactor и зачем он нужен

`Context` — **unidirectional (односторонний) поток метаданных** от **подписчика** к **издателю**. Это «перевернутый» `ThreadLocal`: данные текут **вверх по цепочке** при подписке и доступны любому оператору в цепочке.

**Зачем нужен**:
- Передавать **metadata** (tenant id, trace id, user id, DB routing hint) через цепочку **без** явных параметров.
- **Трассировка**: OpenTelemetry использует `Context` для передачи trace span.
- **Multi-tenancy**: один реактивный поток обслуживает разные tenants — `Context` несёт tenant id.
- **Не путать с ThreadLocal**: в Reactor **несколько потоков** могут участвовать в одной цепочке; `ThreadLocal` теряется между переключениями. `Context` живёт **на подписке**, а не на потоке.

**API**:
```java
// Установка (в конце цепочки, от подписчика)
Flux.just(1, 2, 3)
    .doOnNext(i -> System.out.println(Context.current().get("tenantId")))
    .contextWrite(ctx -> ctx.put("tenantId", "acme"));

// Чтение в любом месте
Mono.just("data")
    .flatMap(data -> Mono.fromCallable(() -> db.query(data, Context.current().get("tenantId"))))
    .contextWrite(ctx -> ctx.put("tenantId", tenant));
```

**Важные свойства**:
- **Неизменяемость**: `Context` — immutable; `contextWrite` создаёт новый.
- **Односторонность**: от подписчика → к издателю. **Нельзя** передать данные обратно (вниз) через Context — для этого нужны **`Mono`/`Flux` как значения**.
- **Изоляция подписок**: каждая подписка имеет **свой** Context; две подписки на тот же `Flux` **не** разделяют Context.
- **Только в пределах цепочки**: если `Flux` создаётся вне цепочки и подписывается из другого места, Context из **этой** подписки **не** виден.

**Типичные сценарии**:
1. **OpenTelemetry trace context**: Spring WebFlux автоматически кладёт trace id в `Context`; любой `Mono.fromCallable()` внутри может взять его и передать в свой tracing.
2. **Tenant routing**: `db.query(..., Context.current().get(TENANT_KEY))`.
3. **Metrics/labels**: `Micrometer.observation(...)` использует Context.

**Частая ошибка**: `Context.current()` **внутри** `Mono.fromCallable()` **не** видит контекст подписки, если callable выполнен на **другом** Scheduler'е и **до** того, как подписка «подняла» контекст. Решение: передать контекст явным параметром или использовать `deferContextual`.

```java
// ❌ Не работает — Context.current() пустой внутри callable
Mono.fromCallable(() -> db.query(Context.current().get("tenant")))

// ✅ Правильно — deferContextual получает Context как параметр
Mono.deferContextual(ctx -> Mono.fromCallable(() -> db.query(ctx.get("tenant"))))
```

**Итого**: Context — **единственный** способ передать metadata через реактивную цепочку без явных аргументов. Используй для **tracing, tenancy, config**, а не для «передачи результата» (для этого есть сами `Mono`/`Flux`).


### 7. Что такое Spring WebFlux и чем он отличается от MVC

**Spring WebFlux** — реактивный фреймворк для web-приложений поверх **Reactive Streams** (Project Reactor). Альтернатива **Spring MVC** (синхронный, Servlet API).

**Ключевые отличия**:

| | Spring MVC | Spring WebFlux |
|---|---|---|
| Базовый API | Servlet API (блокирующий) | Reactive Streams (`Mono`/`Flux`) |
| Сетевой слой | Tomcat, Jetty (thread per connection) | **Netty** (event-loop) или **Reactor HTTP** |
| Модель потоков | 1 thread per request | 4–8 event-loop + `boundedElastic` для блокирующих |
| Ответ | `T` / `ResponseEntity<T>` | `Mono<T>` / `Flux<T>` / `ResponseEntity<Mono<T>>` |
| Streaming | SseEmitter (костыль) | `Flux<ServerSentEvent>` / `Flux<ByteBuffer>` (нормально) |
| Подключение | Servlet 3.1+ | Servlet 3.1+ **или** реактивный |
| Thread-local | Работает | **Не работает** (используй `Context`) |
| Подходящее для | CRUD, форм, синхронные API | SSE, WebSocket, streaming, высоконагруженные read-heavy |

**Controller в WebFlux**:
```java
@RestController
public class UsersController {

    @GetMapping("/users")
    Mono<List<User>> findAll(UserRepository repo) {
        return repo.findAll(); // Flux<User> → Mono<List<User>>
    }

    @GetMapping(value = "/users/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    Flux<ServerSentEvent<User>> stream() {
        return userEvents()
            .map(u -> ServerSentEvent.<User>builder(u).id(u.getId()).build());
    }
}
```

**WebClient** (заменяет `RestTemplate` в реактивном мире):
```java
WebClient client = WebClient.create("https://api.example.com");
Mono<User> user = client.get()
    .uri("/users/{id}", 42)
    .retrieve()
    .bodyToMono(User.class);
```

**Когда WebFlux, когда MVC**:
- **WebFlux**: SSE, WebSocket, streaming, очень много одновременных **долгих** соединений (чаты, live-дашборды), read-heavy API с малой CPU-нагрузкой.
- **MVC**: классические CRUD, формы, интеграция с legacy, проще отлаживать.
- **С виртуальными потоками (Java 21)**: **MVC на virtual threads** часто **лучший выбор** — ты получаешь масштабируемость без реактивного кода. WebFlux всё ещё выигрывает для **pотоков событий** (SSE/WebSocket), потому что там виртуальные потоки **не** заменяют streaming.

**Важно**: WebFlux **не** обязывает использовать Reactor — можно писать на **RxJava 3** (но Spring 6 перешёл на Reactor). В Spring Boot 3 WebFlux по умолчанию на **Reactor**.

**Типичная ошибка**: блокирующий вызов (JDBC, `Thread.sleep`) внутри WebFlux **на event-loop'е** → зависает всё приложение. Решение: `subscribeOn(Schedulers.boundedElastic())` или **R2DBC** для БД.


### 8. Что такое WebClient и как он работает

**WebClient** — **реактивный HTTP-клиент** Spring 5+, замена `RestTemplate` (который остаётся в MVC). Построен на **Reactor Netty** (или на Servlet client в реактивном режиме).

**Ключевые возможности**:
- **Реактивный**: возвращает `Mono`/`Flux`, не блокирует.
- **Streaming**: `Flux<ByteBuffer>` для chunked-ответов, `Flux<String>` для SSE.
- **DSL**: плавный builder — `get()`, `post()`, `uri()`, `header()`, `body()`, `retrieve()`, `exchange()`.
- **Error handling**: `.onStatus(...)` для кастомных кодов, `ClientException` для сетевых.
- **Filters**: глобальные `ExchangeFilterFunction` (аналог interceptors).
- **Retries, timeout, observability** — встроенные.

**Типичный сценарий**:
```java
WebClient client = WebClient.builder()
    .baseUrl("https://api.example.com")
    .defaultHeader("Authorization", "Bearer " + token)
    .filter(logRequest()) // свой ExchangeFilterFunction
    .build();

// GET
Mono<User> user = client.get()
    .uri("/users/{id}", 42)
    .retrieve()
    .bodyToMono(User.class);

// POST с JSON
Mono<User> created = client.post()
    .uri("/users")
    .bodyValue(newUser)
    .retrieve()
    .bodyToMono(User.class);

// SSE-поток
Flux<ServerSentEvent<String>> events = client.get()
    .uri("/events")
    .retrieve()
    .bodyToFlux(new ParameterizedTypeReference<ServerSentEvent<String>>() {});

// Streaming-ответ (chunked)
Flux<ByteBuffer> chunks = client.get()
    .uri("/files/big")
    .retrieve()
    .bodyToFlux(ByteBuffer.class);
```

**`retrieve()` vs `exchange()`**:
- **`retrieve()`** — «стандартный» путь: возвращает `ResponseSpec`, автоматически читает тело, бросает `WebClientResponseException` на 4xx/5xx (если не задан `onStatus`).
- **`exchange()`** — «низкоуровневый»: возвращает `Mono<ClientResponse>`, можно **вручную** читать тело, **не** бросает на 4xx (нужно обрабатывать самому). Для **custom error handling** и **streaming**.

**Timeouts и retries**:
```java
client.get().uri("/slow")
    .retrieve()
    .bodyToMono(String.class)
    .timeout(Duration.ofSeconds(5))
    .retryWhen(Retry.backoff(3, Duration.ofMillis(500)));
```

**Общие ошибки**:
- **Блокирующий вызов** внутри `bodyToMono`/`bodyToFlux` — зависает event-loop.
- **Незакрытый stream**: `Flux<ByteBuffer>` нужно **подписать** и **потребить**, иначе соединение висит.
- **Двойной `retrieve()`** — нельзя вызвать дважды (stream уже потреблён).
- **Thread-local**: не работает — используй `Context` (см. Q704).

**WebClient vs RestTemplate**:
| | WebClient | RestTemplate |
|---|---|---|
| API | `Mono`/`Flux` | Синхронный |
| Streaming | Нативно | Нет |
| Error handling | `onStatus`, `exchange` | `RestClientResponseException` |
| Filters | `ExchangeFilterFunction` | `ClientHttpRequestInterceptor` |
| Status | Актуальный | «Поддерживается, но не развивается» |

**Вывод**: в реактивном коде — **WebClient**; в синхронном (MVC) — **RestTemplate** (или `RestClient` из Spring 6, который проще и без реактивного API).


### 9. Что такое R2DBC и чем отличается от JDBC

**R2DBC (Reactive Relational Database Connectivity)** — реактивный драйверный слой для **реляционных БД** (PostgreSQL, MySQL, MariaDB, H2), реализует **Reactive Streams**. Замена **JDBC** в реактивном мире.

**Ключевые отличия**:

| | JDBC | R2DBC |
|---|---|---|
| API | Синхронный, блокирующий | Реактивный (`Mono`/`Flux`) |
| Подключения | 1 connection = 1 thread (pool) | 1 connection = **несколько** запросов параллельно |
| Результат | `ResultSet` (блокирующий iteration) | `Flux<Row>` (lazy, backpressure) |
| Thread model | Thread per query | Event-loop |
| Транзакции | `Connection` + `setAutoCommit` | `Mono<Void>` / `Connection` из `ConnectionFactory` |
| Поддержка БД | Все | PostgreSQL, MySQL, H2, MariaDB (развивается) |

**Пример (PostgreSQL)**:
```java
// ConnectionFactory — конфигурация (Spring Boot auto-config из application.yml)
ConnectionFactory cf = ConnectionFactoryOptions.builder()
    .option(DRIVER, "postgres")
    .option(HOST, "localhost")
    .option(PORT, 5432)
    .option(DATABASE, "test")
    .option(USER, "user")
    .option(PASSWORD, "pass")
    .build();

// Simple query
Flux<User> users = DatabaseClient.create(cf)
    .sql("SELECT id, name FROM users WHERE active = :active")
    .bind("active", true)
    .map((row, metadata) -> new User(row.get("id", Integer.class), row.get("name", String.class)))
    .all()
    .fetch()
    .many();

// Single row (Mono)
Mono<User> user = DatabaseClient.create(cf)
    .sql("SELECT id, name FROM users WHERE id = :id")
    .bind("id", 42)
    .map((row, metadata) -> new User(row.get("id", Integer.class), row.get("name", String.class)))
    .one()
    .fetch()
    .first();

// Транзакция
Mono<Void> tx = DatabaseClient.create(cf)
    .transactional(tx -> tx.sql("UPDATE users SET name = :name WHERE id = :id")
        .bind("name", "new").bind("id", 42)
        .update()
        .then());
```

**Почему R2DBC, а не «JDBC на boundedElastic»**:
- **JDBC + `boundedElastic`** работает, но **блокирует** поток из пула на время запроса → **лимит по connections** (pool size). При 1000 запросов/сек нужен пул из 100+ connections → **давление на БД**.
- **R2DBC** использует **несколько соединений**, но **каждое** обрабатывает **множество** запросов параллельно (non-blocking I/O на socket) → **меньше соединений**, **выше throughput**, **backpressure** на уровень SQL.

**Ограничения R2DBC**:
- **Не все фичи JDBC**: нет `Statement#setFetchSize` в том же виде, нет `CallableStatement` (stored procedures) — частично.
- **Менее зрелый**: драйверы моложе, больше багов, меньше документации.
- **Hibernate 6.4+** поддерживает R2DBC **реактивно**, но **не все** фичи JPA (например, `@LoadTimeWeaving` не работает).
- **Миграции**: Flyway/Liquibase — **только JDBC** (R2DBC их не заменяет; миграции обычно идут через отдельный JDBC-клиент).

**Когда R2DBC**:
- **Высоконагруженные read-heavy** API с **множеством** мелких запросов.
- **Streaming** (например, чтение миллионных строк без OOM — `Flux<Row>` с backpressure).
- **Реактивный стек** целиком (WebFlux + R2DBC + WebClient).

**Когда JDBC**:
- **CRUD** с **Hibernate/JPA** (Hibernate **реактивно** через R2DBC пока ограничен).
- **Транзакции** со сложной логикой (JDBC проще).
- **Миграции**, **администрирование**, **stored procedures**.

**Вывод**: R2DBC — **не** «лучше» JDBC, а **другая модель**. В реактивном стеке для **высокой нагрузки** — R2DBC; в синхронном или с JPA — JDBC.


### 10. Виртуальные потоки vs Реактивное программирование: когда что выбирать

**Ключевой вопрос 2024–2026**: «Если у нас виртуальные потоки (Java 21), зачем нам Reactor/WebFlux?»

**Короткий ответ**: **виртуальные потоки заменяют реактивность для 80% случаев** (async I/O, concurrent requests), но **не** заменяют **потоки событий** (SSE, WebSocket, streaming) и **backpressure**.

**Подробный разбор**:

| Задача | Virtual Threads | Reactor/WebFlux |
|---|---|---|
| Concurrent HTTP requests (1000 параллельных) | ✅ Просто: `for (...) { client.get(); }` | ✅ `Flux.fromArray(ids).flatMap(...)` |
| SSE / WebSocket streaming | ⚠️ Не заменяет (поток событий) | ✅ Нативно (`Flux<ServerSentEvent>`) |
| Backpressure | ❌ Нет (поток данных «заливает») | ✅ Встроенный |
| Thread-local (MDC, SecurityContext) | ✅ Работает | ❌ Не работает (нужен Context) |
| Блокирующие вызовы (JDBC) | ✅ Бесплатно | ⚠️ Нужен `boundedElastic` |
| Простота кода | ✅ «Синхронный» стиль | ⚠️ Цепочки, `Mono`/`Flux` |
| Отладка | ✅ Стандартные stack trace | ⚠️ Reactor debug tools |
| Потоки событий (Kafka consumer → UI) | ⚠️ Ограниченно | ✅ Нативно |

**Правила выбора**:

1. **CRUD + async I/O + concurrent requests** → **Virtual Threads + MVC + JDBC** (проще, быстрее пишется, легче отлаживать).
2. **SSE / WebSocket / streaming API** → **WebFlux + Reactor** (vиртуальные потоки не дают backpressure и «потока событий»).
3. **Высоконагруженный read-heavy с малой CPU** → **WebFlux + R2DBC** (меньше соединений, выше throughput).
4. **Legacy + блокирующие I/O** → **Virtual Threads** (просто оберни blocking-код в `Thread.startVirtualThread`).
5. **Сложные реактивные графы** (например, чат с множеством стримов, live-дашборды) → **Reactor**.

**Почему Reactor всё ещё нужен**:
- **Backpressure**: виртуальные потоки **не** управляют темпом — если потребитель медленнее, данные копятся в памяти. Reactor **управляет** (`request(n)`).
- **Потоки событий**: SSE/WebSocket — это **поток**, а не «одна задача». Виртуальный поток = **одна** задача; для **потока** нужен `Flux`.
- **Composability**: `Flux`/`Mono` — **чистые функции** (чистый функциональный стиль), легко тестировать (`StepVerifier`), нет side-effect'ов.
- **Наблюдаемость**: Reactor интегрирован с **Micrometer/OpenTelemetry** из коробки.

**Антипаттерн**: писать «реактивный» код **без** причины (например, CRUD с WebFlux, когда хватило бы MVC + virtual threads). Это усложняет код без пользы.

**Тренд 2026**: большинство новых Java-проектов выбирают **MVC + Virtual Threads + JDBC** для CRUD, **WebFlux** — только для **streaming** (SSE, WebSocket). Reactor не умирает, но **сужается** до ниши **pотоков событий**.


### 11. Что такое RSocket и зачем он нужен

**RSocket** — **бинарный протокол** для **реактивного RPC** поверх TCP, WebSocket или HTTP/2. Спроектирован для **реактивных потоков** с **backpressure** и **multiplexing** (несколько логических соединений на одном физическом).

**Основные сценарии**:
- **Remote procedure call** с реактивными потоками (аналог gRPC, но с потоками).
- **Server push**: сервер может **инициировать** новые потоки к клиенту (reverse request).
- **Fire-and-forget**: отправить сообщение без ожидания ответа.
- **Streaming**: request-response, request-stream, stream-stream.

**Сравнение с gRPC**:
| | RSocket | gRPC |
|---|---|---|
| Базовый протокол | TCP / WebSocket / HTTP/2 | HTTP/2 |
| Методы | 4 (request-response, request-stream, stream-stream, fire-and-forget) | 4 (unary, server-streaming, client-streaming, bidi-streaming) |
| Backpressure | ✅ Нативно (Reactive Streams) | ⚠️ Через flow control HTTP/2 |
| Multiplexing | ✅ На уровне протокола | ✅ Через HTTP/2 streams |
| Кодогенерация | Протокол буферизации (protobuf, JSON, custom) | Protobuf (обязательно) |
| Экосистема | Spring (RSocket), Java, C#, Swift | Все языки, огромное сообщество |
| Мaturity | Средний (Spring 5+, развивается) | Высокий (2016+, стабилен) |

**Когда RSocket, когда gRPC**:
- **RSocket**: **server push** (сервер инициирует), **real-time** приложения, **Spring ecosystem** (Spring RSocket), **мобильные** клиенты (Swift, Kotlin).
- **gRPC**: **microservices** с **строгом контрактом** (protobuf), **полиглот** (разные языки), **высокая нагрузка**, **статус-код** (unary).

**Пример (Spring RSocket)**:
```java
// Сервер
@Controller
public class ChatServer {
    @MessageMapping("/chat")
    Flux<String> chat(Flux<String> messages) {
        return messages.map(m -> "echo: " + m);
    }
}

// Клиент
RSocketRabbitMQ... // (Spring RSocket over RabbitMQ, TCP, или WebSocket)
```

**Важно**: RSocket **не** «лучше» gRPC — это **другая модель**. RSocket = **реактивный поток** + server push; gRPC = **строго контрактный RPC**. Выбор зависит от сценария.

**Статус 2026**: RSocket **развивается** (Spring 6, Reactor Netty), но **экосистема** gRPC **шире**. Для **microservices** чаще выбирают **gRPC** (или REST). RSocket — ниша **real-time** + **Spring**.


### 12. Как обрабатывать ошибки в реактивных цепочках: onErrorResume, onErrorReturn, retryWhen

Реактивные цепочки **не** имеют try-catch в привычном смысле. Ошибка — это **сигнал** `onError(throwable)`, который **пропагируется** вверх по цепочке. Обработка — через **операторы**.

**Базовые операторы**:

- **`onErrorResume(fn)`** — при ошибке **перехватывает** и возвращает **новую** цепочку (`Mono`/`Flux`).
```java
Mono.just("data")
    .flatMap(d -> fetchRemote(d))
    .onErrorResume(ConnectException.class, e -> {
        log.warn("Remote failed, using fallback", e);
        return Mono.just("fallback");
    });
```

- **`onErrorReturn(fallback)`** — при ошибке возвращает **константное** значение.
```java
Flux.just(1, 2, 3)
    .flatMap(i -> riskyCall(i))
    .onErrorReturn(-1); // при ошибке → -1
```

- **`onErrorComplete()`** — при ошибке завершает поток **без** элемента (как `onComplete`).
```java
Flux.just(1, 2, 3)
    .flatMap(i -> riskyCall(i))
    .onErrorComplete(); // ошибка → просто onComplete
```

- **`retry(n)`** — повторяет **всю** цепочку до n раз (с начала).
```java
Mono.fromCallable(() -> flakyApi())
    .retry(3); // 3 повторения
```

- **`retryWhen(fn)`** — **гибкий** retry: возвращает `Publisher` (обычно `Flux` из задержек).
```java
Mono.fromCallable(() -> flakyApi())
    .retryWhen(Retry.backoff(3, Duration.ofMillis(500))
        .maxBackoff(Duration.ofSeconds(2))
        .filter(throwable -> throwable instanceof IOException)
        .doBeforeRetry(signal -> log.warn("Retry #{}", signal.totalRetries())));
```

**Типичные паттерны**:

1. **Fallback** (fallback-значение при ошибке):
```java
public Mono<User> findUser(String id) {
    return cache.get(id)
        .flatMap(u -> Mono.justOrEmpty(u))
        .onErrorResume(Exception.class, e -> {
            log.error("Cache failed", e);
            return Mono.fromCallable(() -> db.findById(id))
                .subscribeOn(Schedulers.boundedElastic()); // fallback в БД
        });
}
```

2. **Retry с exponential backoff**:
```java
public Mono<String> callExternalApi() {
    return webClient.get().uri("/api")
        .retrieve()
        .bodyToMono(String.class)
        .timeout(Duration.ofSeconds(5))
        .retryWhen(Retry.backoff(3, Duration.ofMillis(500)));
}
```

3. **Error transformation** (преобразовать ошибку в domain exception):
```java
public Mono<Order> createOrder(OrderDto dto) {
    return validation.validate(dto)
        .flatMap(valid -> db.save(dto))
        .onErrorMap(ValidationException.class, e -> new DomainException("INVALID_ORDER", e));
}
```

4. **Circuit breaker** (через Resilience4j или Reactor'ы):
```java
CircuitBreaker cb = CircuitBreaker.ofDefault("api");
return Mono.fromCallable(() -> cb.executeSupplier(() -> callApi()))
    .subscribeOn(Schedulers.boundedElastic());
```

**Частые ошибки**:

- **`retry()` без фильтра** — повторяет **все** ошибки (включая `IllegalArgumentException`), что **неправильно**. Всегда фильтруй: `retryWhen(Retry.backoff(3, Duration.ofMillis(500)).filter(e -> e instanceof IOException))`.
- **`onErrorResume` на **всю** цепочку** — если ошибка в **самом начале** (например, валидация), fallback **не** должен маскировать её. Используй `onErrorResume` **только** там, где **ожидаешь** ошибку (например, remote call).
- **Блокирующий вызов в `onErrorResume`** — если fallback **блокирующий** (JDBC), обёрни в `Mono.fromCallable(...).subscribeOn(Schedulers.boundedElastic())`.
- **Потеря контекста** — при retry `Context` **сохраняется**, но **trace id** может «сломаться» (повторный span). Используй `Retry` + `deferContextual` для корректного tracing.

**Правило**: **ошибка — это данные**. Обработай **все** ошибки явно (не «просто пробрось»), используй **retry** только для **транзиентных** ошибок (сеть, timeout), **fallback** — для **ожидаемых** сбоев (cache miss).


### 13. Как тестировать реактивный код: StepVerifier

**StepVerifier** — фреймворк Reactor для **тестирования** `Mono`/`Flux`. Позволяет **проверить** последовательность событий (`onNext`, `onError`, `onComplete`) **без** подписки.

**Базовый API**:
```java
@Test
void testFlux() {
    Flux<Integer> flux = Flux.just(1, 2, 3);

    StepVerifier.create(flux)
        .expectNext(1)
        .expectNext(2)
        .expectNext(3)
        .verifyComplete(); // завершается onCompl
}

@Test
void testMonoError() {
    Mono<String> mono = Mono.error(new RuntimeException("fail"));

    StepVerifier.create(mono)
        .expectErrorMessage("fail")
        .verify();
}
```

**Ключевые методы**:
- **`expectNext(T)`** — ожидает **один** элемент.
- **`expectNextCount(n)`** — ожидает **n** элементов (не проверяя значения).
- **`expectNextMatches(predicate)`** — ожидает элемент, удовлетворяющий предикату.
- **`expectError()`** / **`expectError(Class)`** / **`expectErrorMessage(String)`** — ожидает ошибку.
- **`verifyComplete()`** — ожидает `onComplete`.
- **`verify()`** — ожидает **либо** `onComplete`, **либо** `onError`.
- **`expectNextThenComplete()`** — ожидает **один** элемент + `onComplete` (коротко).
- **`consumeWith(Consumer<Subscriber>)`** — кастомная проверка.

**Тестирование с задержками**:
```java
@Test
void testWithDelay() {
    Flux<Integer> flux = Flux.just(1)
        .delayElements(Duration.ofMillis(100));

    StepVerifier.create(flux)
        .expectSubscription()
        .expectNext(1)
        .expectNoEvent(Duration.ofMillis(50)) // пауза: события не должно быть 50мс
        .expectNext(2)
        .expectComplete()
        .verify(Duration.ofSeconds(2)); // общий timeout
}
```

**Тестирование с Context**:
```java
@Test
void testWithContext() {
    Flux<Integer> flux = Flux.deferContextual(ctx ->
        Flux.just(ctx.get("value")));

    StepVerifier.create(flux.contextWrite(ctx -> ctx.put("value", 42)))
        .expectNext(42)
        .verifyComplete();
}
```

**Типичные паттерны**:

1. **Тест Mono с fallback**:
```java
@Test
void testFallback() {
    Mono<String> result = Mono.error(new ConnectException())
        .onErrorResume(e -> Mono.just("fallback"));

    StepVerifier.create(result)
        .expectNext("fallback")
        .verifyComplete();
}
```

2. **Тест retry**:
```java
@Test
void testRetry() {
    AtomicInteger attempts = new AtomicInteger();
    Mono<String> result = Mono.fromCallable(() -> {
        if (attempts.incrementAndGet() < 3) throw new IOException();
        return "success";
    }).retry(3);

    StepVerifier.create(result)
        .expectNext("success")
        .verifyComplete();
    assertEquals(3, attempts.get());
}
```

3. **Тест backpressure**:
```java
@Test
void testBackpressureDrop() {
    Flux<Integer> flux = Flux.range(1, 100)
        .onBackpressureDrop();

    StepVerifier.create(flux)
        .expectNextCount(1) // только первый (остальные drop'нуты)
        .expectComplete()
        .verify();
}
```

**Важные нюансы**:
- **`verify()` vs `verifyComplete()`**: `verify()` — **либо** `onComplete`, **либо** `onError`; `verifyComplete()` — **только** `onComplete`.
- **Timeout**: всегда ставь **общий timeout** (`verify(Duration)`), иначе тест может **зависнуть** навсегда (особенно с `delayElements` или `timeout`).
- **Ленивость**: `StepVerifier.create(flux)` **не** подписывается до `verify()`. Если `flux` имеет **side-effect** при создании — он **не** выполнится до `verify()`.
- **Параллелизм**: `StepVerifier` **не** тестирует **конкурентность** (для этого нужен **Tck** или **JMH**).

**Интеграция с Spring**:
```java
@WebFluxTest
class UserControllerTest {
    @Autowired
    TestHttpClient client; // WebTestClient

    @Test
    void testFindUser() {
        client.get().uri("/users/42")
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.id").isEqualTo(42);
    }
}
```

**Вывод**: `StepVerifier` — **стандарт** для тестирования Reactor-кода. Используй **явные** ожидания (`expectNext`, `expectError`), **всегда** ставь timeout, тестируй **ошибки** отдельно от **успеха**.


