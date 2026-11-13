# Performance Engineering

### 1. JMH: microbenchmarking, @Benchmark, @State, @Measurement, @Fork

**JMH (Java Microbenchmark Harness)** — **стандарт** для **микро-бенчмаркинга** в Java. **Учитывает** **JIT** (warmup, **оптимизация**), **измеряет** **точное** **время** **выполнения**.

**Почему JMH, а не `System.nanoTime()`**:
- **JIT** **оптимизирует** **код** при **повторном** **выполнении** (warmup).
- **Dead code elimination**: **неиспользуемый** **код** **удаляется** **JIT** (без JMH **результат** **неверен**).
- **Constant folding**: **константные** **вычисления** **вычислены** **заранее**.

**Аннотации**:
```java
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Benchmark)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 10, time = 1)
@Fork(3)  // 3 JVM-процесса
public class CollectionBenchmark {
    
    @State(Scope.Benchmark)
    public class Data {
        List<String> list = new ArrayList<>();
        Map<String, Integer> map = new HashMap<>();
        
        @Setup
        public void setup() {
            for (int i = 0; i < 100_000; i++) {
                list.add("item" + i);
                map.put("key" + i, i);
            }
        }
    }
    
    @Benchmark
    public int arrayListGet(Data data) {
        return data.list.size();
    }
    
    @Benchmark
    public Integer hashMapGet(Data data) {
        return data.map.get("key50000");
    }
}
```

**Параметры**:
- **`@BenchmarkMode`**: **AverageTime** (среднее время), **Throughput** (операций/сек), **SampleTime** (распределение).
- **`@State(Scope.Benchmark)`**: **состояние** на **весь** **бенчмарк** (все **итерации**).
- **`@State(Scope.Thread)`**: **состояние** на **каждый** **поток**.
- **`@Warmup(iterations, time)`**: **разогрев** (JIT **оптимизация**, **не** **считается** в **результат**).
- **`@Measurement(iterations, time)`**: **замер** (считается в **результат**).
- **`@Fork(n)`**: **n** **JVM-процессов** (каждый **с** **своим** **JIT**, **результат** **среднее**).

**Запуск**:
```bash
# Maven:
mvn clean package
java -jar target/benchmarks.jar

# С параметрами:
java -jar target/benchmarks.jar -f 3 -wi 5 -i 10 -w 1s -m 1s
```

**Типовые ошибки**:
- **Нет warmup** → **JIT** **не** **оптимизировал** → **завышенный** **результат**.
- **Нет `@State`** → **создание** **объектов** **в** **каждой** **итерации** → **не** **та** **нагрузка**.
- **Результат** **не** **используется** → **dead code elimination** → **0 нс**.
- **Один fork** → **случайность** **JIT** → **нужно** **3+ forks**.

### 2. Типичные ошибки бенчмаркинга: JIT warmup, DCE, constant folding

**1. JIT Warmup**:
- **JIT** **компилирует** **горячий** **код** после **10 000–50 000** **вызовов** (C1 → C2).
- **Без warmup**: **интерпретатор** **выполняет** → **медленно** (10–100x).
- **Решение**: **`@Warmup(iterations = 5, time = 1)`** (5 итераций по 1 сек).

**2. Dead Code Elimination (DCE)**:
- **JIT** **удаляет** **код**, **результат** **которого** **не** **используется**.
- **Пример**:
```java
@Benchmark
public void badBenchmark(List<String> list) {
    list.add("item");  // JIT: результат не используется → удалить
}
```
- **Решение**: **результат** **использовать** (вернуть, **записать** в **volatile**).
```java
private volatile String sink;

@Benchmark
public String goodBenchmark(List<String> list) {
    sink = list.get(0);
    return sink;  // JIT: результат используется → не удалить
}
```

**3. Constant Folding**:
- **JIT** **вычисляет** **константные** **выражения** **заранее**.
- **Пример**:
```java
@Benchmark
public int badMath() {
    return 2 + 2;  // JIT: 4 (вычислено при компиляции)
}
```
- **Решение**: **переменные** (не **константы**).
```java
@Benchmark
public int goodMath(int a, int b) {
    return a + b;  // JIT: нельзя вычислить заранее
}
```

**4. Loop Unrolling**:
- **JIT** **разворачивает** **циклы** (4 итерации **в** **1**).
- **Влияет** на **результат** (быстрее, **но** **больше** **памяти**).
- **Учитывать** при **анализе** **результата**.

**5. GC Noise**:
- **GC** **паузы** **искажают** **замер**.
- **Решение**: **`@Fork(3)`** (среднее по 3 JVM), **большие** **итерации** (сглаживание).

**6. Неправильный Scope**:
- **`@State(Scope.Benchmark)`**: **создание** **один** **раз** на **все** **итерации**.
- **`@State(Scope.Thread)`**: **создание** **на** **каждый** **поток**.
- **`@State(Scope.Group)`**: **создание** **на** **группу** **потоков**.
- **Ошибка**: **неверный** **scope** → **не** **та** **нагрузка**.

**7. Warmup per Fork**:
- **Каждый** **fork** (JVM) **имеет** **свой** **JIT** → **warmup** **для** **каждого**.
- **`@Warmup`** **применяется** **к** **каждому** **fork** (не **один** **раз**).

**Best practice**:
- **3+ forks**, **5+ warmup iterations**, **10+ measurement iterations**.
- **Результат** **использовать** (не **DCE**).
- **Переменные** (не **константы**).
- **Проверить** **результат** **на** **разных** **JVM** (OpenJDK, GraalVM).

### 3. Load testing: Gatling, k6, JMeter — когда что

**Gatling**:
- **Язык**: **Scala** (DSL).
- **Плюс**: **просто** **писать** **сценарии**, **хорошие** **отчёты**, **распределённый** **режим**.
- **Минус**: **Scala** (не **все** **знают**), **медленнее** **JMeter**.
- **Use case**: **API** **load testing** (REST, gRPC), **CI/CD**.

```scala
import io.gatling.core.Predef._
import io.gatling.http.Predef._

class OrderSimulation extends Simulation {
    val httpConf = http.baseURI("https://api.example.com")
    
    val scenario = scn("Create Order")
        .exec(http("POST /orders")
            .post("/orders")
            .header("Authorization", "Bearer ${token}")
            .jsonBody("""{"product": "laptop", "qty": 1}""")
            .check(status.is(201)))
        .pause(1 to 5 seconds)
    
    setUp(scenario.injectOpen(constantUsersPerSec(100) during (10 minutes))).protocols(httpConf)
}
```

**k6**:
- **Язык**: **JavaScript**.
- **Плюс**: **просто** (JS), **быстро**, **распределённый** (cloud), **GraphQL** **поддержка**.
- **Минус**: **меньше** **интеграций** (vs JMeter).
- **Use case**: **API** **load testing**, **CI/CD** (Graffana Cloud k6).

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: 100,  // 100 виртуальных пользователей
    duration: '10m',
};

export default function() {
    const res = http.post('https://api.example.com/orders', 
        JSON.stringify({product: 'laptop', qty: 1}),
        {headers: {'Authorization': 'Bearer token'}}
    );
    check(res, {'status is 201': (r) => r.status === 201});
    sleep(1 + Math.random() * 4);
}
```

**JMeter**:
- **Язык**: **GUI** (Java).
- **Плюс**: **GUI** (не **нужно** **писать** **код**), **огромная** **экосистема** **плагинов**, **распределённый**.
- **Минус**: **GUI** **медленный** (для **больших** **тестов**), **сложно** **версионировать** (XML).
- **Use case**: **компании** **без** **DevOps** (GUI), **legacy** (JMeter **файлы**).

**Сравнение**:
| | Gatling | k6 | JMeter |
|---|---|---|---|
| **Язык** | Scala | JavaScript | GUI (Java) |
| **Скорость** | Высокая | Высокая | Средняя |
| **CI/CD** | Хорошо | Отлично | Плохо (GUI) |
| **Распределённый** | Да | Да (cloud) | Да |
| **Отчёты** | HTML | HTML + Grafana | HTML |
| **Выбор** | Scala-команды | JS-команды | Legacy |

**Когда что**:
- **Gatling**: **Scala** **команда**, **API** **load testing**, **распределённый**.
- **k6**: **JS** **команда**, **CI/CD** (Grafana Cloud), **быстрый** **старт**.
- **JMeter**: **legacy**, **GUI** (не **нужно** **кодировать**), **огромные** **тесты** (10K+ VU).

### 4. Profiling workflow: identify → measure → optimize → verify

**Workflow** **оптимизации** **производительности**:

**1. Identify** (найти **проблему**):
- **Метрики**: **p95/p99** **latency** **вырос** (Grafana, Prometheus).
- **Алерты**: **SLO** **нарушено** (error rate > 5%, p95 > 1s).
- **Traces**: **медленный** **span** (Jaeger, Tempo).
- **Логи**: **WARN/ERROR** (timeout, slow query).

**2. Measure** (измерить):
- **JFR** (Java Flight Recorder): **CPU**, **GC**, **allocation**, **lock** (60 сек).
- **async-profiler**: **flame graph** (CPU, allocation, lock).
- **Thread dump**: **deadlock**, **BLOCKED** **потоки**.
- **DB**: **EXPLAIN ANALYZE** (план запроса), **pg_stat_statements** (топ медленных).

**3. Optimize** (оптимизировать):
- **CPU**: **оптимизировать** **алгоритм** (O(n²) → O(n log n)), **инлайн** **методы**, **предварительное** **вычисление**.
- **GC**: **уменьшить** **allocation** (object pooling, **периситивные** **коллекции**), **настроить** **GC** (G1, ZGC).
- **Lock**: **уменьшить** **критическую** **секцию**, **lock-free** **структуры** (ConcurrentHashMap).
- **DB**: **индексы**, **объединить** **запросы** (JOIN), **кэширование** (Redis).
- **Сеть**: **batching** (один запрос вместо N), **compression** (gzip).

**4. Verify** (проверить):
- **Повторить** **бенчмарк** (JMH, load test).
- **Сравнить** **метрики** (p95 **до** **и** **после**).
- **Проверить** **SLO** (error rate, p95).
- **Deploy** **в** **staging** → **load test** → **deploy** **в** **prod** (canary).

**Пример**:
```
1. Identify: p95 latency /orders вырос с 200ms до 2s
2. Measure: JFR → 80% CPU в OrderService.getTotal()
            async-profiler → flame graph: 70% в List.stream().reduce()
            DB: EXPLAIN → full table scan (нет индекса)
3. Optimize: 
   - Создать индекс: CREATE INDEX idx_orders_user_id ON orders(user_id);
   - Оптимизировать: List.stream().reduce() → for loop (меньше allocation)
4. Verify: p95 latency → 250ms (было 2s), SLO OK
```

**Типовые ошибки**:
- **Оптимизировать** **без** **измерения** (угадывание).
- **Микро-оптимизация** (не **узкое** **место**).
- **Не** **проверить** **в** **prod** (staging **не** **та** **нагрузка**).
- **Оптимизировать** **всё** **сразу** (нужно **по** **одному** **изменению**).

### 5. JVM tuning: ergonomics, adaptive sizing, GC selection

**Ergonomics** (автоматические **настройки** JVM):
- **Java 8+**: **JVM** **автоматически** **выбирает** **GC**, **размер** **heap**, **параметры**.
- **`-XX:+UseContainerSupport`** (Java 10+): **JVM** **видит** **container** **limits** (Docker, K8s).
- **`-XX:MaxRAMPercentage=75.0`**: **heap** = **75%** **памяти** **контейнера**.

**Adaptive Sizing**:
- **G1 GC**: **адаптивно** **меняет** **размер** **regions** (young/old) под **нагрузку**.
- **ZGC** (Java 15+): **адаптивно** **перемещает** **объекты** (sub-millisecond pauses).
- **Epsilon** (Java 14+): **не** **собирает** **мусор** (для **short-lived** **приложений**).

**GC Selection**:
| GC | Pauses | Throughput | Use case |
|---|---|---|---|
| **G1** (default Java 9+) | 10–100 мс | Средний | **Большинство** **приложений** |
| **ZGC** (Java 15+) | < 1 мс | Средний | **Низкий** **latency** (финансы, real-time) |
| **Shenandoah** | < 1 мс | Средний | **Низкий** **latency** (аналог ZGC) |
| **Parallel** | 100–1000 мс | Высокий | **Высокий** **throughput** (batch, offline) |
| **Serial** | 100–1000 мс | Низкий | **Один** **CPU**, **мало** **памяти** (CLI) |
| **Epsilon** | 0 | Нет GC | **Short-lived** (serverless, CLI) |

**Настройка**:
```bash
# G1 (default):
java -XX:+UseG1GC -Xmx4g -Xms4g -jar app.jar

# ZGC (low latency):
java -XX:+UseZGC -Xmx4g -jar app.jar

# Parallel (high throughput):
java -XX:+UseParallelGC -Xmx4g -jar app.jar

# Container-aware:
java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -jar app.jar
```

**Типовые проблемы**:
- **GC pause** > **500 мс** → **выбрать** **ZGC** или **увеличить** **heap**.
- **Много** **Young GC** → **много** **короткоживущих** **объектов** → **оптимизировать** **allocation**.
- **Full GC** **часто** → **Old Gen** **заполнен** (утечка) → **heap dump** + **MAT**.
- **Metaspace** **растёт** → **classloader** **leak** → **проверить** **динамические** **прокси**.

### 6. Database performance: query optimization, connection pooling, indexing

**Query Optimization**:
- **EXPLAIN ANALYZE**: **план** **запроса** (Seq Scan vs Index Scan, **время** **выполнения**).
- **Индексы**: **по** **колонкам** **в** **WHERE**, **JOIN**, **ORDER BY**.
- **N+1**: **N** **запросов** **вместо** **1** (JOIN, **fetch** **join**).
- **SELECT \***: **нужные** **колонки** (меньше **данных**).

```sql
-- До (N+1): 1 запрос на orders + N запросов на items
SELECT * FROM orders WHERE user_id = 1;
-- Для каждого order: SELECT * FROM items WHERE order_id = ?;

-- После (JOIN): 1 запрос
SELECT o.*, i.*
FROM orders o
JOIN items i ON o.id = i.order_id
WHERE o.user_id = 1;
```

**Connection Pooling**:
- **HikariCP** (default Spring Boot): **быстрый**, **лёгкий** (10K+ connections/sec).
- **Параметры**: **maximumPoolSize** (10–50), **minimumIdle** (5–10), **connectionTimeout** (30 сек).
- **Проблема**: **мало** **connections** → **очередь**, **много** → **давление** **на** **БД**.

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      max-lifetime: 1800000  # 30 мин
```

**Indexing Strategies**:
- **B-Tree** (default): **точечный** **поиск**, **диапазон**.
- **GIN**: **JSONB**, **full-text** **search**.
- **GiST**: **гео**, **range** **типы**.
- **BRIN**: **большие** **таблицы** (**последовательные** **данные**, **log**).
- **Partial**: **WHERE** **условие** (например, **active** **заказы**).

```sql
-- B-Tree (default):
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- GIN для JSONB:
CREATE INDEX idx_metadata ON orders USING GIN(metadata);

-- Partial:
CREATE INDEX idx_active_orders ON orders(user_id) WHERE status = 'ACTIVE';
```

**Мониторинг**:
- **pg_stat_statements**: **топ** **медленных** **запросов**.
- **pg_stat_user_tables**: **bloat**, **index** **usage**.
- **慢** **запросы**: **EXPLAIN ANALYZE** + **индексы**.

### 7. Network performance: compression, batching, connection reuse

**Compression**:
- **gzip/deflate**: **текстовые** **данные** (JSON, HTML) **сжимаются** на **70–90%**.
- **В Spring**: **`server.compression.enabled=true`** (Tomcat).
- **Когда**: **ответ** > **1 КБ** (иначе **compression** **медленнее**).

```yaml
server:
  compression:
    enabled: true
    min-response-size: 1024
    mime-types: application/json,text/html,text/plain
```

**Batching**:
- **Один** **запрос** **вместо** **N** (меньше **round-trips**).
- **Пример**: **загрузка** **100** **пользователей** → **один** **запрос** `WHERE id IN (1,2,...,100)` **вместо** **100** **запросов**.
- **Kafka**: **batch** **producer** (`batch.size`, `linger.ms`) → **меньше** **сетевых** **вызовов**.

```java
// До (N запросов):
for (Long id : ids) {
    repo.findById(id);  // N round-trips
}

// После (1 запрос):
List<User> users = repo.findAllById(ids);  // 1 round-trip
```

**Connection Reuse**:
- **HTTP Keep-Alive**: **соединение** **используется** **повторно** (без **TCP handshake**).
- **HTTP/2**: **multiplexing** (N **запросов** **на** **одном** **соединении**).
- **Connection Pooling** (HttpClient, WebClient): **пул** **соединений** (не **создавать** **новое** **на** **каждый** **запрос**).

```java
// WebClient (connection pooling):
HttpClient httpClient = HttpClient.create()
    .option(ChannelOption.SO_KEEPALIVE, true)
    .responseTimeout(Duration.ofSeconds(5));

WebClient client = WebClient.builder()
    .clientConnector(new ReactorClientHttpConnector(httpClient))
    .build();
```

**TCP Tuning** (Linux):
- **`net.core.somaxconn`**: **максимум** **соединений** **в** **backlog** (128 → 1024).
- **`net.ipv4.tcp_max_syn_backlog`**: **SYN** **backlog** (128 → 1024).
- **`net.ipv4.tcp_tw_reuse`**: **переиспользование** **TIME_WAIT** **соединений**.

**Мониторинг**:
- **Netty** **metrics**: **active** **connections**, **pending**.
- **TCP** **connections**: **`ss -s`** (Linux), **`netstat`**.
- **Latency**: **p95/p99** **network** **round-trip**.

### 8. Memory optimization: object pooling, primitive collections, off-heap

**Object Pooling**:
- **Переиспользование** **объектов** **вместо** **создания** **новых** (меньше **allocation**, **GC** **паузы**).
- **Когда**: **дорогие** **объекты** (DB **connection**, **Buffer**, **StringBuilder**).
- **Пример**: **Apache Commons Pool**, **HikariCP** (connection pool).

```java
// Connection pool (HikariCP):
HikariConfig config = new HikariConfig();
config.setMaximumPoolSize(20);
HikariDataSource ds = new HikariDataSource(config);

// Переиспользование:
try (Connection conn = ds.getConnection()) {
    // ...
}  // conn возвращается в pool
```

**Primitive Collections**:
- **`Map<String, Integer>`** → **`Int2ObjectOpenHashMap`** (Eclipse Collections) — **без** **autoboxing**.
- **`List<Long>`** → **`LongArrayList`** — **примитивы**, **без** **объектов**.
- **Плюс**: **меньше** **память** (8 байт на **long** vs 16+ на **Long** **объект**).
- **Минус**: **меньше** **API** (не **все** **методы** **Collections**).

```java
// До (autoboxing):
Map<String, Integer> map = new HashMap<>();
map.put("key", 42);  // Integer объект (16 байт)

// После (primitive):
IntObjectOpenHashMap<String> map = new IntObjectOpenHashMap<>();
map.put(42, "value");  // int (4 байта)
```

**Off-Heap Memory**:
- **DirectByteBuffer** (NIO): **память** **вне** **JVM heap** (не **собирается** **GC**).
- **Когда**: **крупные** **буферы** (file I/O, **network** **buffers**, **Kafka** **producer**).
- **Проблема**: **утечки** (не **собирается** **GC**, **нужно** **вручную** **освободить**).

```java
// DirectByteBuffer (off-heap):
ByteBuffer buffer = ByteBuffer.allocateDirect(1 << 20);  // 1 MB off-heap
// Не собирается GC, нужно вручную:
((Cleanable) buffer).cleaner().clean();
```

**Memory Optimization Checklist**:
- [ ] **Object pooling** для **дорогих** **объектов** (connections, buffers).
- [ ] **Primitive collections** (Eclipse Collections, Koloboke) **вместо** **autoboxing**.
- [ ] **Off-heap** **для** **крупных** **буферов** (NIO, Kafka).
- [ ] **String** **interning** **не** **использовать** (metaspace **растёт**).
- [ ] **String** **вместо** **StringBuilder** **для** **коротких** **строк** (JIT **оптимизирует**).
- [ ] **Monitor** **heap** (JFR, **Prometheus**).
