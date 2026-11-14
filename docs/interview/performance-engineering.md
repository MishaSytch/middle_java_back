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
- **HikariCP** (default Spring Boot): **быстрый**, **лёгкий** (10K+ connections/sec, соединений в секунду).
- **Параметры**: **maximumPoolSize** (10–50), **minimumIdle** (5–10), **connectionTimeout** (30 сек).
- **Проблема**: **мало connections** (соединений) → **очередь**, **много** → **давление** **на** **БД**.

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
- **Медленные запросы**: **EXPLAIN ANALYZE** + **индексы**.

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
- **Netty** **metrics**: **active** **connections** (активные соединения), **pending** (в очереди).
- **TCP** **connections** (соединения): **`ss -s`** (Linux), **`netstat`**.
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


### 9. GC tuning: как выбрать и настроить сборщик (G1, ZGC, Shenandoah)

**Выбор GC:**
- **G1** (Garbage-First, по умолчанию в Java 9+): **region-based** (heap разделён на regions, 1-32 MB), **mixed GC** (young + часть old), **pause target** (`-XX:MaxGCPauseMillis=200`). Подходит для большинства приложений (heap 4-64 GB).
- **ZGC** (Java 15+, production): **concurrent** (почти все фазы concurrently с приложением), **pause < 1 ms** (не зависит от размера heap), **colored pointers** (метки в старших битах указателя). Подходит для больших heap (64 GB+) и low-latency.
- **Shenandoah** (Red Hat, Java 11+): аналог ZGC (concurrent compaction, pause < 10 ms), но без colored pointers (uses forwarding pointers).

**Флаги (G1):**
```bash
-Xms4g -Xmx4g                    # фиксированный heap (без resize)
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200         # целевая pause
-XX:G1HeapRegionSize=16m         # размер region
-XX:InitiatingHeapOccupancyPercent=45  # когда начинать concurrent mark
-Xlog:gc*,gc+heap=debug:file=gc.log:time,uptime,level,tags
```

**Флаги (ZGC):**
```bash
-Xms4g -Xmx4g
-XX:+UseZGC
-XX:+ZGenerational               # Java 21: генерационный ZGC (быстрее)
-Xlog:gc*:file=gc.log
```

**Метрики для оценки:**
- **Pause time** (средняя, p99): G1 = 20-200 ms, ZGC = < 1 ms.
- **Throughput** (доля времени без GC): G1 = 95-99%, ZGC = 97-99%.
- **Heap usage** (после GC): если > 80% — нужно увеличить heap или оптимизировать объекты.
- **Allocation rate** (MB/sec): если очень высокий — ищите объекты, создаваемые в hot path.

**Когда что:**
- **G1**: heap 4-64 GB, pause до 200 ms допустимы (большинство server-приложений).
- **ZGC**: heap 64 GB+ или low-latency (trading, real-time), pause < 1 ms критична.
- **Shenandoah**: как ZGC, но если Red Hat JVM (OpenJDK без ZGC).

### 10. Thread pool sizing: как подобрать количество потоков

**Формула (Brewster's formula):**
```
optimal_threads = N_cpu × U_cpu × (1 + W/C)
```
- **N_cpu** — число ядер (Runtime.getRuntime().availableProcessors()).
- **U_cpu** — целевая утилизация CPU (0-1, обычно 0.5-0.8).
- **W** — время вычисления (CPU work).
- **C** — время ожидания (I/O wait).

**CPU-bound** (W >> C): потоки ≈ N_cpu × U_cpu. Больше потоков → context switching без выигрыша.
**I/O-bound** (C >> W): потоки = N_cpu × U_cpu × (1 + C/W). Может быть 10-100× N_cpu.

**Пример:**
```java
int cpus = Runtime.getRuntime().availableProcessors();
// I/O-bound: 80% времени в ожидании (C/W = 4)
int threads = (int) (cpus * 0.8 * (1 + 4));  // cpus * 4

ThreadPoolExecutor pool = new ThreadPoolExecutor(
    threads, threads, 0, TimeUnit.MILLISECONDS,
    new LinkedBlockingQueue<>(1000),
    new ThreadFactoryBuilder().setNameFormat("worker-%d").build(),
    new ThreadPoolExecutor.CallerRunsPolicy());
```

**Virtual Threads (Java 21):** для I/O-bound — `Executors.newVirtualThreadPerTaskExecutor()`. Не нужно подбирать размер — JVM управляет (миллионы VT на ограниченном числе carrier threads). **Но**: не используйте synchronized на hot path (pinning carrier thread).

**Мониторинг:**
- **Active threads** vs **pool size** (если всегда 100% — увеличить).
- **Queue size** (растёт — увеличить пул или оптимизировать задачу).
- **Context switches** (high — уменьшить потоки).
- **Rejected tasks** (если есть — увеличить пул или queue).

### 11. Оптимизация N+1 запросов: JOIN, fetch join, batch, EntityGraph

**Проблема:** 1 запрос на родитель + N запросов на детей = N+1. При N=100 → 101 запросов.

**Решения (Hibernate/JPA):**

**1. Fetch join (JOIN в SQL):**
```java
@Query("SELECT o FROM Order o JOIN FETCH o.items")
List<Order> findOrdersWithItems();
```
Один SQL: `SELECT o.*, i.* FROM orders o JOIN items i ON o.id = i.order_id`.

**2. EntityGraph (Java 35 / Hibernate):**
```java
@EntityGraph(attributePaths = {"items", "customer"})
Order findById(Long id);
```
Гибко: можно включить/отключить пути.

**3. Batch fetching (Hibernate):**
```java
@BatchSize(size = 50)
@OneToMany
private List<Item> items;
```
Hibernate делает 1 запрос на 50 родителей: `SELECT * FROM items WHERE order_id IN (?, ?, ...)`.

**4. DTO projection (без entities):**
```java
@Query("SELECT new com.dto.OrderDto(o.id, o.total, COUNT(i.id)) " +
       "FROM Order o LEFT JOIN o.items i GROUP BY o.id")
List<OrderDto> findOrderSummaries();
```
Без lazy-загрузок, только нужные поля.

**5. Batch (Spring Data JPA):**
```java
@Query("SELECT o FROM Order o WHERE o.id IN :ids")
List<Order> findByIds(@Param("ids") Collection<Long> ids);
```
Ручная batch-загрузка детей.

**Проверка:**
```bash
# Hibernate SQL log:
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
# или:
logging.level.org.hibernate.SQL=DEBUG
```
Считать: 100 заказов → 101 SELECT = N+1, 1 SELECT = fetch join.

### 12. Connection pooling (HikariCP): настройки и оптимизация

**HikariCP** (по умолчанию в Spring Boot) — fastest JDBC pool.

**Ключевые параметры:**
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10      # = CPU cores × 2 + disk spindles (Heckel's formula)
      minimum-idle: 10           # = maximum (фиксированный пул, без resize)
      connection-timeout: 3000   # 3 сек (ждать свободное соединение)
      idle-timeout: 600000       # 10 мин (закрывать idle соединения)
      max-lifetime: 1800000      # 30 мин (пересоздавать соединения, раньше чем DB timeout)
      validation-timeout: 5000   # 5 сек (проверка соединения)
```

**Heckel's formula** (размер пула):
```
pool_size = ((core_count × 2) + effective_spindle_count)
```
- 4 cores, 1 SSD → pool = 9.
- 8 cores, 2 SSD → pool = 18.
- Для cloud DB (RDS): обычно 10-20 (DB — bottleneck).

**Почему не больше:**
- Много соединений → DB contention (lock, memory).
- Каждый connection = memory в DB (2-10 MB).
- 100 connections × 10 MB = 1 GB DB memory.

**Мониторинг (HikariCP metrics):**
```java
HikariDataSource ds = ...;
// JMX: HikariPool-1
// Metrics: active, idle, waiting, timeout
// Prometheus:
hikaricp_connections_active
hikaricp_connections_idle
hikaricp_connections_waiting
hikaricp_connections_timeout_total
```
- **Active ≈ max** постоянно → увеличить пул или оптимизировать запросы.
- **Waiting > 0** → не хватает соединений.
- **Timeout** → пул исчерпан (увеличить или уменьшить load).

**Anti-patterns:**
- Пул на каждый сервис (да) vs общий пул (нет — contention).
- Держать соединение долго (не завершать транзакцию) → блокирует пул.
- `maximum-pool-size = 100` «на всякий случай» → DB падает.

### 13. Query optimization: EXPLAIN, indexes, covering index, partial index

**EXPLAIN (PostgreSQL):**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM orders WHERE user_id = 123 AND status = 'ACTIVE';
```
- **Seq Scan** (полный обход) — плохо, если таблица большая (> 100K строк).
- **Index Scan** / **Bitmap Index Scan** — хорошо.
- **Nested Loop** — если одна сторона маленькая (< 1000 строк).
- **Hash Join** — если обе стороны большие.
- **Seq Scan on Index** — если индекс не помогает (selectivity низкая).

**Индексы:**
- **B-tree** (по умолчанию): для `=`, `<`, `>`, `BETWEEN`, `IN`. Подходит для 90% случаев.
- **Composite index**: `CREATE INDEX idx ON orders(user_id, status);` — порядок колонок важен (leftmost prefix).
- **Covering index** (INCLUDE): `CREATE INDEX idx ON orders(user_id) INCLUDE (total, created_at);` — запрос удовлетворяется из индекса без обращения к таблице (index-only scan).
- **Partial index**: `CREATE INDEX idx ON orders(user_id) WHERE status = 'ACTIVE';` — меньше, быстрее, если фильтр частый.
- **GIN/GiST**: для full-text (GIN), геоданных (GiST), JSONB (GIN).

**Когда индекс не помогает:**
- **Selectivity** (< 10% или > 90% строк): planner выбирает seq scan.
- **Function on column**: `WHERE UPPER(email) = 'X'` — индекс на `email` не работает. Решение: expression index `CREATE INDEX ON orders(UPPER(email))`.
- **OR**: `WHERE a = 1 OR b = 2` — два отдельных индекса (bitmap OR).

**Оптимизация:**
```sql
-- До: Seq Scan (100K строк)
SELECT * FROM orders WHERE user_id = 123;

-- После: Index Scan
CREATE INDEX idx_orders_user ON orders(user_id);
-- EXPLAIN: Index Scan using idx_orders_user (cost=0.42..8.44)
```

**VACUUM / ANALYZE:**
- **VACUUM**: удаляет dead tuples (после UPDATE/DELETE), обновляет statistics.
- **ANALYZE**: обновляет statistics для planner.
- **Autovacuum**: автоматически (по умолчанию каждые 15 мин).
- **Мониторинг**: `pg_stat_user_tables` (n_dead_tup, last_autovacuum).

### 14. Serialization overhead: JSON vs Protobuf vs Avro, когда что

**Сравнение:**
| | JSON | Protobuf | Avro |
|---|---|---|---|
| **Size** | 100% (baseline) | 30-40% | 40-60% |
| **Parse time** | 100% | 3-10× faster | 5-10× faster |
| **Schema** | Нет (dynamic) | `.proto` (strong) | `.avsc` (strong) |
| **Human-readable** | Да | Нет (binary) | Нет (binary) |
| **Use case** | REST API, config | gRPC, high-throughput | Kafka, data pipelines |

**Когда что:**
- **JSON**: REST API (external), config files, logging. Простота > скорость.
- **Protobuf**: gRPC (internal microservices), high-throughput (1M+ msg/sec). Binary + schema = компактно + быстро.
- **Avro**: Kafka (data pipelines), schema evolution (добавление полей без breaking change).

**Оптимизация JSON (если нужно остаться на JSON):**
- **Compact**: без whitespace, без дублирующихся полей.
- **Field naming**: короткие имена (`id`, `ts` вместо `createdAt`).
- **Streaming**: Jackson `JsonGenerator` (не парсить весь JSON в объект).
- **Zero-copy**: `byte[]` вместо `String` (если не нужна обработка).
- **Compression**: gzip (10:1 для JSON, но CPU overhead).

**Пример (Jackson streaming):**
```java
// Вместо: ObjectMapper.readValue(json, Order.class)
// Streaming:
JsonParser parser = mapper.getFactory().createParser(json);
while (parser.nextToken() != null) {
    if (parser.getCurrentName().equals("id")) {
        long id = parser.getLongValue();  // только нужное поле
    }
}
```

### 15. String и StringBuilder: когда string concatenation становится bottleneck

**Проблема:**
```java
String result = "";
for (int i = 0; i < 1000; i++) {
    result += "item" + i;  // каждое += создаёт новый String (copy!)
}
// 1000 String objects, 1000 allocations, O(n²) time
```

**Решение:**
```java
StringBuilder sb = new StringBuilder(4000);  // предвыделить capacity
for (int i = 0; i < 1000; i++) {
    sb.append("item").append(i);
}
String result = sb.toString();  // 1 allocation
```

**Когда string concatenation ок:**
- **Мало итераций** (< 10): JIT оптимизирует (invokes StringBuilder).
- **Короткая строка** (< 100 chars): overhead allocation мал.
- **Rare path**: не hot code.

**Когда StringBuilder критичен:**
- **Hot loop** (1000+ итераций).
- **Длинные строки** (10K+ chars).
- **High throughput** (1M строк/sec).

**Другие оптимизации:**
- **`String.intern()`**: для повторяющихся строк (но careful — memory leak).
- **`String.valueOf()`** vs `"" + x`: аналогично, `String.valueOf` чище.
- **`String.format()`**: медленно (Locale, regex), избегайте в hot path.
- **`String.join()`, `String.join(",", list)`**: читабельно, internally StringBuilder.

**Bench (JMH):**
```java
@Benchmark
public String concat(Data d) {
    String s = "";
    for (int i = 0; i < d.n; i++) s += "x";
    return s;
}

@Benchmark
public String builder(Data d) {
    StringBuilder sb = new StringBuilder(d.n);
    for (int i = 0; i < d.n; i++) sb.append('x');
    return sb.toString();
}
// n=1000: concat = 50 µs, builder = 5 µs (10× faster)
```

### 16. Object allocation rate: как найти и устранить

**Проблема:** высокий allocation rate (100+ MB/sec) → GC-паузы, потеря throughput.

**Диагностика:**
```bash
# GC log (allocation rate):
-Xlog:gc*,gc+heap=debug:file=gc.log
# JFR (Java Flight Recorder):
java -XX:StartFlightRecording=duration=60s,filename=rec.jfr
# VisualVM / JMC: allocation profile (какой класс allocates)
# async-profiler:
./profiler.sh -e alloc -d 30 <pid>
```

**Типичные источники:**
1. **Autoboxing**: `Integer x = i;` → allocation. Решение: primitive, `IntStream`, Eclipse Collections (IntIntMap).
2. **Lambda capture**: lambda захватывает переменную → allocation. Решение: static method, или если capture final — ок.
3. **Stream intermediate**: `stream().map().filter().collect()` → allocation на каждый элемент. Решение: for loop (если hot).
4. **String creation**: `"" + x`, `String.format` → allocation. Решение: StringBuilder, StringPool.
5. **Collection growth**: `ArrayList.add` → resize (copy). Решение: `new ArrayList<>(expectedSize)`.

**Оптимизация:**
```java
// До: autoboxing
Map<Integer, Integer> map = new HashMap<>();
map.put(1, 2);  // Integer boxing

// После: primitive collections (Eclipse Collections)
IntIntMap map = IntIntMap.newHashMap();
map.put(1, 2);  // primitive, no boxing
```

```java
// До: stream (allocation per element)
List<Result> results = items.stream()
    .map(this::process)  // allocation per call
    .collect(Collectors.toList());

// После: for loop (no allocation)
List<Result> results = new ArrayList<>(items.size());
for (Item item : items) {
    results.add(process(item));
}
```

**Метрики:**
- **Allocation rate** (MB/sec): JFR, GC log.
- **Object count** (after GC): если растёт — memory leak.
- **GC frequency**: если GC каждые 10 сек — allocation слишком высокий.

### 17. CPU profiling: async-profiler, JFR, hot spots

**Инструменты:**
- **async-profiler** (рекомендуется): low overhead (< 1%), sampling (1000 Hz), flame graph.
- **JFR** (Java Flight Recorder): built-in, low overhead, continuous recording.
- **VisualVM**: simple, но high overhead (attach/detach).
- **Arthas**: online debugging, `profiler start/stop`.

**async-profiler:**
```bash
# CPU profile (30 сек):
./profiler.sh -e cpu -d 30 <pid>
# Результат: HTML flame graph

# Allocation profile:
./profiler.sh -e alloc -d 30 <pid>

# Lock contention:
./profiler.sh -e lock -d 30 <pid>

# Wall clock (включая I/O):
./profiler.sh -e wall -d 30 <pid>
```

**JFR:**
```bash
# Записать 60 сек:
java -XX:StartFlightRecording=duration=60s,filename=rec.jfr -jar app.jar

# Или online (jcmd):
jcmd <pid> JFR.start duration=60s filename=rec.jfr
jcmd <pid> JFR.dump filename=rec.jfr
```
Открыть: **JDK Mission Control** (JMC) → Timeline, CPU, Memory.

**Как читать flame graph:**
- **Широта** блока = доля CPU.
- **Высота** = глубина stack.
- **Hot spot** = широкий блок наверху (частый метод).
- **Red blocks** (async-profiler) = native code.

**Типичные hot spots:**
- **Serialization** (Jackson, Gson): 20-40% CPU в JSON-heavy приложениях.
- **Regex** (Pattern, Matcher): если complex pattern в hot loop.
- **String operations**: `split`, `replaceAll` (regex-based).
- **Lock contention** (synchronized, ReentrantLock): `e lock` profile.

**Оптимизация после profiling:**
1. Найти топ-5 горячих методов.
2. Для каждого: можно ли избежать (cache, batch, async)?
3. Bench (JMH) до/после.

### 18. Memory profiling: heap dump, leak detection

**Проблема:** memory leak (heap растёт, GC не помогает) → OOM.

**Диагностика:**
```bash
# Heap dump (live objects):
jmap -dump:live,format=b,file=heap.hprof <pid>

# Или OOM (автоматически):
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/dumps/

# Анализ: Eclipse MAT (Memory Analyzer Tool)
# - Leak Suspects Report
# - Dominator Tree (какой объект занимает больше всего)
# - GC Root Paths (почему объект не собран)
```

**Типичные утечки:**
1. **ThreadLocal не очищен**: в thread pool — значение живёт до смерти потока.
   ```java
   // Fix:
   try {
       context.set(value);
       // work
   } finally {
       context.remove();
   }
   ```
2. **Collection растёт без bound**: `static List cache = new ArrayList<>();` → добавить limit (Caffeine, LRU).
3. **Listener не deregistered**: `eventBus.addListener(l);` без `removeListener(l)`.
4. **Inner class → outer**: анонимный класс держит reference на outer → если inner живёт долго → outer тоже.
5. **Cached result** (static Map): `static Map<Key, Result> cache` → TTL, size limit.

**Мониторинг:**
- **Heap usage** (Prometheus): `jvm_memory_used_bytes{area="heap"}`.
- **GC frequency**: если GC чаще 1/мин — проблема.
- **Old gen usage**: если old gen > 80% после full GC — leak.

**Профилактика:**
- **Unit tests** (memory): создать N объектов, проверить heap (JOL, Instrumentation).
- **Integration tests**: load test (1 час), проверить heap trend.
- **CI**: heap dump в CI (если OOM на load test).

### 19. I/O optimization: NIO, async I/O, virtual threads

**Blocking I/O (традиционно):**
```java
// Каждый поток блокируется на read
Socket socket = new Socket(host, port);
InputStream in = socket.getInputStream();
byte[] buf = new byte[8192];
int n = in.read(buf);  // поток заблокирован
```
**Проблема**: 1000 соединений = 1000 потоков (каждый ~1 MB stack) = 1 GB memory.

**NIO (Non-Blocking I/O, Java 1.4+):**
```java
// Selector (1 поток на 1000 каналов)
Selector selector = Selector.open();
SocketChannel channel = SocketChannel.open();
channel.configureBlocking(false);
channel.register(selector, SelectionKey.OP_READ);

while (true) {
    selector.select();  // блокируется, пока есть события
    for (SelectionKey key : selector.selectedKeys()) {
        if (key.isReadable()) {
            read(key.channel());
        }
    }
}
```
**Плюс**: 1 поток на 1000 каналов. **Минус**: complex code, "callback hell".

**Async I/O (Java 7+, AIO):**
```java
// CompletableFuture
AsynchronousFileChannel channel = AsynchronousFileChannel.open(path);
Future<ByteBuffer> future = channel.read(buf, 0);
ByteBuffer result = future.get();
```
**Плюс**: callback/Future, меньше кода. **Минус**: limited API (file, socket).

**Virtual Threads (Java 21):**
```java
// Blocking code, но JVM размонтирует на I/O
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 100_000; i++) {
        executor.submit(() -> {
            byte[] data = httpClient.send(request);  // blocking, но VT размонтируется
            process(data);
        });
    }
}
```
**Плюс**: простой blocking code, миллионы потоков. **Минус**: не для CPU-bound (нет выигрыша), `synchronized` pinning.

**Когда что:**
- **CPU-bound**: platform threads (fixed pool = N_cpu).
- **I/O-bound**: Virtual Threads (Java 21+) — просто, масштабируется.
- **Legacy (Java 8-17)**: NIO (Netty, Vert.x) или reactive (WebFlux).

**Оптимизация:**
- **Batch I/O**: 1000 запросов → 1 batch (JDBC: `addBatch`, `executeBatch`).
- **Async I/O**: не блокировать main thread (CompletableFuture, reactive).
- **Compression**: gzip (10:1, но CPU overhead).
- **Connection reuse**: HTTP keep-alive, JDBC connection pool.

### 20. Latency optimization: p99, tail latency, how to reduce

**Метрики:**
- **p50** (медиана): 50% запросов быстрее.
- **p95**: 95% запросов быстрее.
- **p99**: 99% запросов быстрее (важно для SLA).
- **p99.9**: 99.9% (для high-availability).

**Почему p99 > p50:**
- **GC pause** (200 ms раз в минуту) → 1.67% запросов медленнее.
- **Lock contention** (редко, но долго).
- **Cold cache** (первый запрос — DB, не cache).
- **Context switching** (если много потоков).
- **Network jitter** (packet loss, retransmit).

**Как снизить p99:**
1. **GC**: ZGC (pause < 1 ms) вместо G1 (200 ms).
2. **Lock contention**: async-profiler (`e lock`), найти hot lock → уменьшить critical section, или lock-free (Atomic).
3. **Cold cache**: **warmup** (startup: preload hot keys в Caffeine), **TTL jitter** (чтобы не все expired одновременно).
4. **Batch**: 100 запросов → 1 batch (JDBC, HTTP).
5. **Connection pool**: HikariCP (fast), проверить `waiting` (если > 0 — увеличить пул).
6. **Async**: не блокировать request thread (CompletableFuture, reactive).

**Мониторинг:**
```java
// Micrometer (Prometheus):
Timer timer = Timer.builder("http.request")
    .publishPercentileHistogram()  // p50, p95, p99, p99.9
    .register(meterRegistry);
timer.record(() -> handleRequest());
```
```promql
# Grafana:
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

**Follow-up:**
- «А как воспроизвести p99 проблему?» → **load test** (Gatling: 1000 users, 10 мин), замерить p99.
- «А как оптимизировать tail?» → **hedged requests** (послать 2 запроса, взять первый ответ) — если p99.9 критичен.

### 21. Как оптимизировать медленный endpoint (case study: 10 сек → 100 ms)

**Шаг 1: Диагностика (5 мин)**
- **Metrics**: latency p50/p99, error rate (Grafana).
- **Tracing**: OpenTelemetry (какой span долгий: app, DB, network?).
- **Logs**: stack trace, slow query log.

**Шаг 2: Профилирование (10 мин)**
- **async-profiler** (`e cpu -d 30`): flame graph → hot spots.
- **JFR**: allocation, GC, lock contention.
- **EXPLAIN**: медленные запросы (DB).

**Шаг 3: Оптимизация (20 мин)**
- **N+1** → fetch join (1 запрос вместо 1000).
- **Missing index** → `CREATE INDEX`.
- **Unnecessary serialization** → DTO (только нужные поля).
- **Synchronous I/O** → async (CompletableFuture) или Virtual Threads.
- **No cache** → Caffeine (local) + Redis (distributed).

**Шаг 4: Верификация (5 мин)**
- **Bench** (JMH или Gatling): latency до/после.
- **Load test** (1000 users): p99, error rate.

**Пример:**
```java
// До: 10 сек (N+1 + no index)
public OrderDto getOrder(Long id) {
    Order order = orderRepo.findById(id).get();  // 1 запрос
    List<Item> items = itemRepo.findByOrderId(id);  // N запросов (N+1)
    return new OrderDto(order, items);
}

// После: 100 ms (fetch join + index)
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
Order findByIdWithItems(@Param("id") Long id);

CREATE INDEX idx_items_order ON items(order_id);
```

**Результат:**
- **Before**: p50 = 10 сек, p99 = 15 сек (N+1: 1000 запросов × 10 ms).
- **After**: p50 = 80 ms, p99 = 150 ms (1 запрос + cache).

### 22. Throughput optimization: batching, parallelism, backpressure

**Throughput** (операций/сек) vs **Latency** (мс на операцию) — trade-off.

**Batching:**
```java
// До: 1 запрос на операцию (1000 операций = 1000 запросов)
for (Order o : orders) {
    orderRepo.save(o);  // 1 SQL per save
}

// После: batch (1000 операций = 10 запросов по 100)
orderRepo.saveAll(orders);  // JDBC batch
// или:
for (int i = 0; i < orders.size(); i += 100) {
    orderRepo.saveAll(orders.subList(i, Math.min(i + 100, orders.size())));
}
```
**JDBC batch**: `rewriteBatchedStatements=true` (MySQL), `batch_size` (PostgreSQL).

**Parallelism:**
```java
// До: sequential (1000 × 10 ms = 10 сек)
for (User u : users) {
    enrich(u);  // 10 ms each
}

// После: parallel (100 threads × 10 ms = 100 ms)
try (var executor = Executors.newFixedThreadPool(100)) {
    List<CompletableFuture<Void>> futures = users.stream()
        .map(u -> CompletableFuture.runAsync(() -> enrich(u), executor))
        .toList();
    CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
}
```
**Внимание**: I/O-bound → 100 threads ок, CPU-bound → N_cpu threads (больше = context switching).

**Backpressure:**
- **Проблема**: producer быстрее consumer → queue растёт → OOM.
- **Решения**:
  - **Bounded queue** (LinkedBlockingQueue(1000)) → producer блокируется, если queue full.
  - **Drop policy** (DiscardPolicy) → бросить старые (если некритично).
  - **Throttling** (rate limit producer): 1000 msg/sec, не 10K.
  - **Reactive** (WebFlux): `onBackpressureBuffer`, `onBackpressureDrop`.

**Метрики:**
- **Queue size** (растёт — consumer не успевает).
- **Throughput** (ops/sec — должен быть стабильным).
- **Rejection count** (если есть — увеличить consumer или drop).

### 23. APM tools: Datadog, New Relic, Dynatrace — что дают

**APM** (Application Performance Monitoring) — end-to-end мониторинг (tracing, metrics, logging).

**Компоненты:**
- **Tracing** (distributed): `trace_id` через все сервисы (OpenTelemetry → Jaeger / Datadog / New Relic).
- **Metrics** (Prometheus): latency, error rate, throughput (Grafana).
- **Logging** (structured): JSON logs → Loki / Datadog.
- **Profiling** (continuous): async-profiler, JFR (hot spots in production).

**Datadog / New Relic / Dynatrace:**
- **Auto-instrumentation**: agent (Java agent) автоматически трекает HTTP, DB, messaging.
- **Real User Monitoring (RUM)**: browser/mobile → latency, errors.
- **Synthetic monitoring**: synthetic requests (каждые 1 мин) → uptime, latency.
- **Cost**: дорого (per host, per GB). Для small team — **Grafana Stack** (Prometheus + Loki + Grafana, open-source).

**Что смотреть:**
- **Service map** (зависимости между сервисами).
- **Error rate** (5xx, exceptions).
- **Latency p99** (per endpoint).
- **Database queries** (slow queries, N+1).
- **Dependency health** (external APIs: payment, email).

**Free/open-source альтернативы:**
- **Grafana Stack**: Prometheus (metrics) + Loki (logs) + Grafana (dashboards).
- **Jaeger**: distributed tracing.
- **Tempo** (Grafana): tracing (dешевле, чем Jaeger).
- **OpenTelemetry**: instrumentation (vendor-neutral).

### 24. Performance regression testing: как не сломать производительность

**Проблема:** новый код → медленнее (регрессия), но только заметили в production.

**Решение:**
1. **Load test в CI**:
   - **Gatling** / **k6**: 1000 users, 5 мин.
   - **Assert**: p99 < 500 ms, error rate < 1%.
   - **Fail build** при регрессии.
2. **Baseline**:
   - Сохранить metrics (p50, p99, throughput) для main branch.
   - Сравнить PR с baseline (если p99 > 10% хуже — alert).
3. **JMH в CI**:
   - Critical methods (serialization, parsing): JMH bench в CI.
   - **Assert**: throughput > baseline × 0.9 (10% tolerance).

**Пример (Gatling + CI):**
```scala
// Gatling (Scala):
class ApiPerfTest extends Simulation {
    val scn = scenario("API")
        .exec(http("Get orders")
            .get("/api/orders")
            .check(status.is(200)))
        .repeat(100) { exec(http("Get order").get("/api/orders/${orderId}")) }

    setUp(scn.inject(users(100).during(5.minutes)))
        .assertion(httpCheck.always().percent(99).time.eloquent.lt(500))
        .protocols(httpc)
}
```
```yaml
# GitHub Actions:
- name: Load test
  run: |
    gatling -r target/gatling/results
    python check_perf.py  # assert p99 < 500 ms
```

**Метрики для assertion:**
- **p99 latency** < 500 ms (SLA).
- **Error rate** < 1%.
- **Throughput** > 1000 req/sec.
- **GC pause p99** < 100 ms.

**Follow-up:**
- «А как нагрузить production (без риска)?» → **canary** (10% traffic) + **monitoring** (auto-rollback при 5xx > 1%).
- «А как воспроизвести production load в staging?» → **traffic replay** (Gore, tcpcopy) — записать production traffic, воспроизвести в staging.

### 25. Как оптимизировать startup time (JVM + Spring Boot)

**Проблема:** Spring Boot app: 30 сек startup. Для Kubernetes (health check) и scale — критично.

**Диагностика:**
```bash
# Spring Boot:
java -jar app.jar --logging.level.org.springframework=DEBUG
# или:
-Dspring.boot.diagnostics.enabled=true
```
**Стартапы:**
- **Bean creation** (DI): 1000 beans × 10 ms = 10 сек.
- **Class loading**: 5000 classes × 1 ms = 5 сек.
- **DB connection**: 5 сек (network).
- **Caching**: warmup (Redis, Elasticsearch).

**Оптимизация:**
1. **GraalVM Native Image** (AOT):
   - **Startup**: 100 ms (vs 30 сек JVM).
   - **Memory**: 50 MB (vs 500 MB JVM).
   - **Downside**: build time (10 мин), not all libraries supported.
   - **Spring Boot 3**: `@BuildProperty("spring.aot.processed", "true")`.
2. **CDS (Class Data Sharing)**:
   - Pre-load classes (shared archive).
   - `java -XX:ArchiveClassesAtExit=app.jsa -jar app.jar` (1-й запуск).
   - `java -XX:SharedArchiveFile=app.jsa -jar app.jar` (2-й запуск, быстрее).
3. **Lazy initialization**:
   - `spring.main.lazy-initialization=true` — все beans лениво (first use).
   - **Downside**: first request медленнее.
4. **Reduced beans**:
   - Удалить неиспользуемые beans (`@ConditionalOnProperty`, `@Profile`).
   - **AOT processing** (Spring Boot 3): анализ графа зависимостей, unused beans не создаются.
5. **DB connection pool**:
   - `HikariCP`: `initializationFailTimeout=1` (не ждать DB при startup).
   - **Lazy**: `spring.datasource.hikari.initialization-fail-timeout=1`.

**Метрики:**
- **Startup time** (Prometheus: `jvm_start_time_seconds`).
- **Bean creation time** (Spring Boot diagnostics).
- **First request latency** (если lazy init — first request медленнее).

**Follow-up:**
- «А как GraalVM Native Image с Spring Boot 3?» → `@NativeImage` + `native-maven-plugin` + `build-native` profile.
- «А как CDS в Kubernetes?» → InitContainer (создать archive) → main container (use archive).

### 26. Zero-copy и off-heap memory: когда и как

**Zero-copy**: передача данных без копирования (kernel → user space → kernel).

**Примеры:**
- **File I/O** (Java NIO): `FileChannel.transferTo()` — данные не копируются в user space.
  ```java
  FileChannel in = FileChannel.open(Path.of("input.dat"));
  SocketChannel out = SocketChannel.open(address);
  in.transferTo(0, in.size(), out);  // zero-copy
  ```
- **Kafka**: `sendfile` (Linux) — данные из page cache напрямую в socket (без user space).
- **Netty**: `FileRegion` — zero-copy file transfer.

**Off-heap memory**: данные вне JVM heap (не собираются GC).

**Когда off-heap:**
- **Большой буфер** (> 100 MB): GC pause (copy, mark) → off-heap (нет GC).
- **Low-latency**: GC pause критичен (trading, real-time).
- **Examples**: Netty `PooledByteBufAllocator` (off-heap), Chronicle Queue, AGPL.

**Пример (Netty off-heap):**
```java
ByteBufAllocator alloc = PooledByteBufAllocator.DEFAULT;
ByteBuf buf = alloc.directBuffer(10 * 1024 * 1024);  // 10 MB off-heap
buf.writeBytes(data);
// Нет GC pressure (вне heap)
```

**Trade-offs:**
- **Zero-copy**: быстрее (нет копирования), но complex (NIO, kernel features).
- **Off-heap**: нет GC, но **memory leak** (нет GC для cleanup), complex (manual memory management).

**Когда не использовать:**
- **Small data** (< 10 MB): overhead zero-copy/off-heap > выигрыш.
- **CPU-bound**: zero-copy не помогает (CPU bottleneck).
- **Simple app**: JVM heap + G1/ZGC достаточно.

### 27. Как профилировать распределённое приложение (distributed tracing)

**Проблема**: 10 микросервисов, request = A → B → C → D. Latency 500 ms, но где bottleneck?

**Решение: distributed tracing** (OpenTelemetry):
- **Trace**: один request (A → B → C → D) = один `trace_id`.
- **Span**: один операция в сервисе (A: `handleRequest`, B: `process`, ...).
- **Context propagation**: `trace_id` + `span_id` передаются через headers (HTTP, gRPC, Kafka).

**Instrumentation (OpenTelemetry):**
```java
// Auto-instrumentation (Java agent):
java -javaagent:opentelemetry-javaagent.jar -jar app.jar

// Manual (если agent не подходит):
Tracer tracer = GlobalOpenTelemetry.getTracer("my-service");
Span span = tracer.spanBuilder("processOrder").startSpan();
try (Scope scope = span.makeCurrent()) {
    orderService.process(order);
    span.setAttribute("order.id", order.getId());
} catch (Exception e) {
    span.recordException(e);
    throw e;
} finally {
    span.end();
}
```

**Storage / Visualization:**
- **Jaeger**: open-source, distributed tracing.
- **Grafana Tempo**: integrated with Grafana, дешевле.
- **Datadog / New Relic**: commercial, APM + tracing.

**Как читать trace:**
- **Waterfall**: каждый span = строка, ширина = время.
- **Bottleneck**: самый широкий span (долгий метод).
- **Parallel spans**: если spans параллельны (fan-out) — суммировать время.
- **Error**: span с exception (красный).

**Метрики:**
- **Trace duration** (p50, p99): total time.
- **Span duration** (per service): где bottleneck.
- **Error rate** (per service): какой сервис падает.
- **Throughput** (traces/sec): load.

**Follow-up:**
- «А как sampling?» → **head-based** (10% traces) или **tail-based** (all errors + 1% random).
- «А как correlation с logs?» → `trace_id` в MDC (logs) → search logs by `trace_id`.

### 28. Как оптимизировать serialization (Jackson, Gson, Protobuf)

**Проблема**: JSON serialization = 20-40% CPU в API-heavy приложениях.

**Оптимизация Jackson:**
```java
// 1. Streaming (не парсить весь JSON):
JsonParser parser = mapper.getFactory().createParser(json);
long id = 0;
while (parser.nextToken() != null) {
    if (parser.getCurrentName().equals("id")) {
        id = parser.getLongValue();  // только нужное поле
    }
}

// 2. DTO (только нужные поля):
public record OrderDto(Long id, String status, long total) {}
// Вместо Order entity (50 полей)

// 3. Object reuse (mapper, generator):
private static final ObjectMapper MAPPER = new ObjectMapper();
// Не создавать new ObjectMapper() per request

// 4. Compact: без pretty print:
mapper.writeValueAsString(obj);  // compact (по умолчанию)
// mapper.writerWithDefaultPrettyPrinter().writeValueAsString(obj);  // pretty (медленно)
```

**Gson vs Jackson:**
- **Gson**: проще (reflection), но медленнее (no streaming, no DTO projection).
- **Jackson**: быстрее (streaming, DTO), но complex (configuration).

**Protobuf (gRPC):**
```java
// .proto:
message Order {
    int64 id = 1;
    string status = 2;
    int64 total = 3;
}

// Java:
Order order = Order.newBuilder()
    .setId(123)
    .setStatus("ACTIVE")
    .setTotal(1000)
    .build();
byte[] data = order.toByteArray();  // 10× компактнее JSON
```
**Плюс**: binary (компактно), schema (типизация), 3-10× быстрее parsing.

**Avro (Kafka):**
```java
// .avsc:
{"type": "record", "name": "Order", "fields": [
    {"name": "id", "type": "long"},
    {"name": "status", "type": "string"}
]}
```
**Плюс**: schema evolution (добавление полей без breaking change).

**Bench (JMH):**
```java
@Benchmark
public int jacksonSerialize(Data d) {
    return mapper.writeValueAsBytes(d.order).length;
}

@Benchmark
public int protobufSerialize(Data d) {
    return d.orderPb.toByteArray().length;
}
// JSON: 500 bytes, 10 µs
// Protobuf: 50 bytes, 1 µs (10×)
```

**Follow-up:**
- «А как compression?» → gzip (10:1 для JSON, но CPU overhead). Для 1 KB+ — ок, для 100 bytes — нет.
- «А как zero-copy?» → Netty `ByteBuf` (не копировать в String).
