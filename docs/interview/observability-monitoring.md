# Observability & Monitoring

### 1. Что такое observability и в чём её отличие от мониторинга

**Observability (наблюдаемость)** — это свойство системы, позволяющее понять её **внутреннее состояние** на основе **внешних наблюдений** (логи, метрики, трассировки). Термин пришёл из теории управления: система наблюдаема, если по её выходам можно однозначно определить состояние.

**Мониторинг** — измерение **заранее известных** метрик и алерты по порогам. Это «знаем, что сломалось».
**Observability** — возможность **исследовать** неизвестное: «почему запрос стал медленнее на 40%, даже если все пороги в норме».

**Ключевое отличие**:
| | Мониторинг | Observability |
|---|---|---|
| Вопрос | «Что сломалось?» | «Почему?» |
| Метрики | Заранее определены | Любые (включая ad-hoc) |
| Алерты | Пороговые | По SLO/SLI (симвомные) |
| Данные | Агрегированные | Сырые + агрегированные |
| Инструменты | Zabbix, Nagios | OpenTelemetry, Jaeger, Prometheus, ELK |

**Три столпа observability**:
1. **Метрики (Metrics)** — численные измерения во времени (CPU, задержки, ошибки, throughput).
2. **Логи (Logs)** — дискретные события с метаданными (timestamp, level, trace id, message).
3. **Трассировки (Traces)** — путь запроса через сервисы (spans с parent-child связями).

**Почему это важно**:
- **Мониторинг** отвечает на «что» (аптайм, CPU > 90%).
- **Observability** отвечает на «почему» (почему p99 задержки выросл на 200 мс — из-за N+1 запроса в БД, из-за GC pause, из-за блокировки в пуле потоков).
- В **микросервисной** архитектуре без observability **невозможно** диагностировать проблемы (100+ сервисов, распределённые вызовы).

**Пример**:
- Мониторинг: «API вернул 500 на 2% запросов» (алерт по порогу).
- Observability: «Из 2% ошибок 90% — timeout в вызове к сервису X, p95 задержки X = 2 c (раньше 200 мс), trace id `abc123` показывает, что 1.8 с ушло на запрос к БД, a query plan показывает full table scan» → **причина**: пропал индекс после миграции.

**Вывод**: мониторинг — это **часть** observability. Observability — более широкая концепция, включающая мониторинг + **возможность исследовать** неизвестное.


### 2. Что такое OpenTelemetry: SDK, Collector, контекст и пропагация

**OpenTelemetry (OTel)** — **стандарт** (CNCF) для **телеметрии**: единый API и SDK для сбора **метрик**, **логов** и **трассировок** из любого приложения. Заменяет проприетарные решения (Jaeger client, Zipkin, Datadog SDK).

**Архитектура**:
```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    App["Application<br/>Java / Go / Python"] --> SDK["OTel SDK"]
    SDK -->|"Exporter"| Collector["OTel Collector"]
    Collector -->|"OTLP"| Backend1["Jaeger / Tempo"]
    Collector -->|"OTLP"| Backend2["Prometheus"]
    Collector -->|"OTLP"| Backend3["ELK / Loki"]
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n5 fill:#fbeaf3,stroke:#cf9fc2,stroke-width:2px,color:#1f2937
    class App n0
    class SDK n1
    class Collector n2
    class Backend1 n3
    class Backend2 n4
    class Backend3 n5
```

**Компоненты**:

1. **OTel SDK** — библиотека в приложении, создаёт **spans**, **метрики**, **логи** и **экспортирует** их.
   - **TracerProvider** — создаёт `Tracer`, который создаёт `Span`.
   - **MeterProvider** — создаёт `Meter`, который создаёт **метрики** (Counter, Histogram, Gauge).
   - **LoggerProvider** — создаёт `Logger` (OpenTelemetry Logging API).
   - **Context** — несёт **активный span**, **trace id**, **span id**, **baggage** (metadata).

2. **OTel Collector** — **агент/демон**, который **собирает** телеметрию из SDK (по **OTLP** — OpenTelemetry Protocol) и **экспортирует** в бэкенды (Jaeger, Prometheus, ELK). Может работать как **daemonset** (на каждом узле) или **deployment** (центральное).
   - **Receiver** — принимает данные (OTLP, Prometheus scrape, Jaeger, Zipkin).
   - **Processor** — трансформирует (batch, attrs, tail sampling).
   - **Exporter** — отправляет в бэкенд (OTLP, Prometheus, Elastic).

3. **Пропагация (Propagation)** — передача **trace context** между сервисами.
   - **W3C Trace Context** — стандарт: заголовки `traceparent` и `tracestate`.
     - `traceparent: 00-<trace-id>-<span-id>-<flags>` (32 hex + 16 hex + 2 hex).
     - `tracestate` — vendor-specific metadata (например, `sampling decision`).
   - **B3** (Zipkin) — альтернативный формат (`X-B3-TraceId`, `X-B3-SpanId`).
   - **Jaeger** — legacy формат.
   - OTel **поддерживает все** форматы (multi-propagator).

**Пример (Java)**:
```java
// 1. Инициализация SDK (Spring Boot 3: open-telemetry dependency)
GlobalOpenTelemetry otel = GlobalOpenTelemetry.get();
Tracer tracer = otel.getTracer("my-service");

// 2. Создание span
Span span = tracer.spanBuilder("processOrder").startSpan();
try (Scope scope = span.makeCurrent()) {
    // бизнес-логика
    orderService.process(order);
} finally {
    span.end();
}

// 3. Пропагация в HTTP-запросе (WebClient / RestTemplate)
HttpClient httpClient = HttpClient.newBuilder()
    .builder()
    .propagator(W3CTraceContextPropagator.getInstance())
    .build();
// OTel auto-instrumentation добавит traceparent в заголовки
```

**Auto-instrumentation**:
- **Java**: `opentelemetry-javaagent.jar` — **bytecode injection** (no code changes).
- **Go**: `otelhttp` middleware.
- **Python**: `opentelemetry-instrumentation-*` пакеты.

**Зачем нужен Collector**:
- **Отделяет** приложение от бэкенда (можно менять бэкенд без перекомпиляции).
- **Batching** — объединяет запросы в батчи (меньше сетевых вызовов).
- **Sampling** — **tail sampling** (отбрасывает «неинтересные» трассировки после сбора).
- **Filtering** — отбрасывает лишние атрибуты.
- **Routing** — разные бэкенды для разных типов телеметрии.

**Вывод**: OpenTelemetry — **единый стандарт** для телеметрии. Используй **SDK** в приложении, **Collector** на уровне инфраструктуры, **W3C Trace Context** для пропагации. Это **future-proof** (можно менять бэкенд без изменения кода).


### 3. Как устроен Prometheus: pull-модель, PromQL, recording rules, alerting rules

**Prometheus** — **система мониторинга** (CNCF), де-факто стандарт в Kubernetes. **Pull-модель**: Prometheus **сам** опрашивает (scrape) целевые сервисы по HTTP-эндпоинту `/metrics`.

**Архитектура**:
```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    P["Prometheus Server"] -->|"scrape /metrics"| T1["Target 1"]
    P -->|"scrape /metrics"| T2["Target 2"]
    P -->|"scrape /metrics"| T3["Target 3"]
    P --> TS["Time Series DB"]
    P --> Alert["Alertmanager"]
    Alert -->|"webhook"| Channel["Slack / Email / PagerDuty"]
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n4 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n5 fill:#fbeaf3,stroke:#cf9fc2,stroke-width:2px,color:#1f2937
    class P n0
    class T1 n1
    class T2 n1
    class T3 n1
    class TS n2
    class Alert n3
    class Channel n4
```

**Ключевые концепции**:

1. **Time series** — последовательность значений во времени. Каждая метрика — это **вектор** time series (с метками).
   - Пример: `http_requests_total{method="GET", status="200"}` — отдельная series.
   - **Метки (labels)** — ключ-значение, идентифицируют series. **Не** создавать метки с высоким кардинальностью (user_id, request_id) — **взорвёт** БД.

2. **Pull-модель**:
   - Prometheus **сам** опрашивает цели (не цели пушат).
   - **Преимущества**: не нужно открывать исходящие порты, легко обнаруживать новые цели (service discovery), централизованное управление.
   - **Недостатки**: задержка до `scrape_interval` (обычно 15–30 c), не подходит для **event-driven** (используй **Pushgateway** для batch jobs).

3. **Service Discovery**:
   - **Kubernetes**: автоматическое обнаружение Pod'ов через API.
   - **Consul**, **Etc.** — другие источники.
   - **Статический** — `scrape_configs` в `prometheus.yaml`.

4. **PromQL** — **язык запросов** к Prometheus.
   - **Селекторы**: `metric_name{label="value"}` — выбирает series.
   - **Инстанс-селектор**: `metric_name` (все series), `metric_name{job="api"}` (фильтр).
   - **Операторы**: арифметические (+, -, *, /), сравнения (>, <, ==, !=), агрегации (`sum`, `avg`, `max`, `min`, `count`, `topk`, `bottomk`).
   - **Функции времени**: `rate()` (ср. скорость за интервал), `increase()` (прирост), `irate()` (мгновенная скорость), `delta()`, `deriv()`, `predict_linear()`.
   - **Подсказки**: `by` / `without` — группировка по меткам.

**Примеры PromQL**:
```promql
# 1. request rate (запросы/сек) за 5 минут
sum(rate(http_requests_total[5m]))

# 2. error rate (доля ошибок)
sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))

# 3. p95 latency
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# 4. top 5 endpoints по request rate
topk(5, sum(rate(http_requests_total[5m])) by (endpoint))

# 5. CPU usage (ядра)
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)
```

**Recording Rules** — **предвычисленные** выражения, хранящиеся в БД. Используются для:
- **Ускорения** сложных запросов (предвычислить `sum(rate(...))` раз в 30 c).
- **Алертов** (алерт по recording rule, а не по raw-запросу).
- **Экономии** ресурсов (меньше вычислений при запросе).

```yaml
# prometheus.rules
groups:
  - name: api
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: sum(rate(http_requests_total[5m])) by (job)
      - record: job:http_errors:rate5m
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
```

**Alerting Rules** — **условия**, по которым Prometheus **отправляет** алерт в **Alertmanager**.

```yaml
groups:
  - name: api
    rules:
      - alert: HighErrorRate
        expr: >
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.job }}"
          description: "Error rate is {{ $value | humanize }} (threshold 5%)"

      - alert: HighLatency
        expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "p95 latency > 1s on {{ $labels.job }}"
```

**Alertmanager** — **роутер** алертов:
- **Группировка** (group by job, severity).
- **Ингибирование** (critical ингибирует warning).
- **Silencing** (временное отключение на период работ).
- **Роутинг** (разные каналы для разных severity).

**Хранение**:
- **TSDB** (Time Series Database) — встроенная, оптимизированная для time series.
- **Retention** — по умолчанию 15 дней (настраивается `--storage.tsdb.retention.time`).
- **Long-term**: **Thanos**, **Cortex**, **Mimir** (горизонтальное масштабирование, long-term storage в S3).

**Вывод**: Prometheus — **pull-модель** + **PromQL** + **recording/alerting rules** + **Alertmanager**. Де-факто стандарт в Kubernetes. Для **long-term** и **горизонтального масштабирования** — Thanos/Cortex/Mimir.


### 4. Как устроена distributed tracing: Jaeger/Tempo, trace propagation, sampling

**Distributed tracing** — техника, при которой **каждый запрос** получает **уникальный trace id**, который **передаётся** между всеми сервисами. Это позволяет **собрать полный путь** запроса через распределённую систему, увидеть **время на каждом участке**, выявить **узкие места** и **источник ошибок**.

**Ключевые концепции**:

1. **Trace** — полный путь запроса (от клиента до последнего сервиса).
2. **Span** — **отдельный участок** trace (например, «HTTP-запрос к сервису X», «вызов к БД»). Каждый span имеет:
   - **trace id** (общий для всего trace).
   - **span id** (уникальный для span).
   - **parent span id** (ссылка на родительский span).
   - **name** (например, `GET /users`).
   - **start time**, **duration**.
   - **attributes** (метаданные: http.status, db.statement).
   - **events** (например, «exception thrown»).
3. **Trace propagation** — передача **trace context** между сервисами.
   - **W3C Trace Context**: заголовки `traceparent` и `tracestate`.
   - **B3** (Zipkin): `X-B3-TraceId`, `X-B3-SpanId`.
   - **Jaeger**: legacy формат.
   - **OTel** поддерживает **все** форматы (multi-propagator).

**Бэкенды**:
- **Jaeger** — CNCF, **высокоуровневый**, **query API**, **UI**. Использует **Cassandra** или **Elasticsearch** как storage.
- **Grafana Tempo** — **S3-based**, **горизонтально масштабируемый**, **интеграция с Grafana**.
- **Zipkin** — legacy, **проще**, **Elasticsearch** storage.
- **LightStep**, **Honeycomb** — коммерческие.

**Sampling** — **отбор** трассировок (не все трассировки interesting):
- **Head-based** — решение **на входе** (client): «записать 10% запросов».
  - **Преимущество**: мало данных, легко реализовать.
  - **Недостаток**: если **редкий** запрос (например, error) **не** отобран — **не видно**.
- **Tail-based** — решение **на выходе** (Collector): «записать все запросы, где есть error или p99 latency > 1 c».
  - **Преимущество**: **все** «интересные» трассировки (errors, slow) сохраняются.
  - **Недостаток**: нужно хранить **все** трассировки **временно** (до решения), выше нагрузка на Collector.

**Пример (OTel + Jaeger)**:
```java
// Service A
Span span = tracer.spanBuilder("processOrder").startSpan();
try (Scope scope = span.makeCurrent()) {
    orderService.process(order);
    // WebClient auto-instrumentation добавит traceparent в заголовки
    userService.getUser(order.getUserId());
} finally {
    span.end();
}

// Service B (получает traceparent из заголовков)
// OTel auto-instrumentation создаёт child span с тем же trace id
```

**UI и запросы**:
- **Jaeger UI** — поиск по **trace id**, **operation**, **tags**.
- **Grafana Tempo** — **Grafana Explore** (traces + metrics + logs **коррелированы**).
- **Корреляция**: **trace id** в **логах** (MDC) и **метриках** (label) → **переход** из метрики в trace в log.

**Вывод**: distributed tracing — **стандарт** для микросервисов. Используй **OpenTelemetry** для **сбора**, **W3C Trace Context** для **пропагации**, **Jaeger/Tempo** для **хранения/запросов**. **Tail-based sampling** — для **production** (сохраняет errors/slow).


### 5. Что такое Micrometer: registry, custom meters, таймеры, distribution summary

**Micrometer** — **vendor-neutral** библиотека для **сбора метрик** в Java (аналог Dropwizard Metrics, но **универсальная**). Интегрирована в **Spring Boot 2+** (auto-config). Экспортирует метрики в **любую** **registry**: Prometheus, Datadog, StatsD, JMX, Influx.

**Ключевые концепции**:

1. **Meter** — **метрика** (Counter, Gauge, Timer, DistributionSummary).
   - **Counter** — **монотонно возрастающее** значение (например, `http_requests_total`).
   - **Gauge** — **мгновенное** значение (например, `heap_memory_used`).
   - **Timer** — **время** выполнения (например, `http_request_duration_seconds`).
   - **DistributionSummary** — **распределение** значений (например, `response_size_bytes`).

2. **Registry** — **бэкенд** хранения метрик (Prometheus, Datadog, JMX, Influx).
   - **CompositeRegistry** — **одновременно** экспортирует в **несколько** registry.

3. **Custom meters** — **свои** метрики через **Micrometer API**.

**Примеры**:

```java
// 1. Counter
Counter counter = Counter.builder("orders.created")
    .description("Total orders created")
    .tag("channel", "web")
    .register(meterRegistry);
counter.increment(); // +1

// 2. Gauge
Gauge.builder("heap.memory.used", () -> Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory())
    .register(meterRegistry);

// 3. Timer
Timer timer = Timer.builder("order.processing")
    .description("Time to process an order")
    .tag("type", "standard")
    .register(meterRegistry);
timer.record(() -> orderService.process(order)); // measure + execute

// 4. DistributionSummary
DistributionSummary summary = DistributionSummary.builder("response.size")
    .description("Response size in bytes")
    .register(meterRegistry);
summary.record(responseBytes);

// 5. Custom (functional)
Gauge.builder("active.connections", connectionPool, ConnectionPool::getActiveConnections)
    .register(meterRegistry);
```

**Spring Boot integration**:
```java
// Auto-configured (Spring Boot 2+)
@Autowired
MeterRegistry meterRegistry;

// В controller'е
@GetMapping("/orders")
public Mono<List<Order>> getOrders() {
    return Timer.builder("orders.get")
        .register(meterRegistry)
        .record(Mono.defer(() -> orderService.findAll()));
}

// Observation API (Spring Boot 3)
@Observed(name = "order.processing", contextualName = "Process Order")
public Order processOrder(OrderDto dto) {
    // ...
}
```

**Distribution Summary** — **распределение** значений:
- **Percentiles** (p50, p90, p95, p99) — **предвычисленные** (не как в Prometheus, где `histogram_quantile` вычисляется **на лету**).
- **Count**, **sum**, **max**.
- **Настройка percentiles**: `DistributionSummary.builder(...).serviceLevelObjectives(0.5, 0.9, 0.95, 0.99)`.

```java
DistributionSummary summary = DistributionSummary.builder("response.size")
    .serviceLevelObjectives(0.5, 0.9, 0.95, 0.99) // p50, p90, p95, p99
    .register(meterRegistry);
```

**Observation API (Spring Boot 3)**:
- **`@Observed`** — **annotation** для **автоматического** создания **span'а** + **метрики**.
- **`Observation`** — **API** для **ручного** создания.
- **Интеграция** с **Micrometer** + **OpenTelemetry**.

```java
@Observed(name = "order.processing", contextualName = "Process Order")
public Order processOrder(OrderDto dto) {
    // Micrometer auto-creates:
    // - Timer "order.processing"
    // - Span "order.processing" (if OTel enabled)
}
```

**Вывод**: Micrometer — **стандарт** для **сбора метрик** в Java. Используй **Counter/Gauge/Timer/DistributionSummary**, **Spring Boot auto-config**, **Observation API** для **tracing + metrics**. Экспорт в **Prometheus** (де-факто) или **Datadog/StatsD**.


### 6. Что такое RED-методология и USE-методология

**RED** и **USE** — **две** **методологии** для **мониторинга** **микросервисов**.

**RED (Rate, Errors, Duration)** — для **user-facing** сервисов (API, front-end):
- **Rate** — **количество** запросов в единицу времени (requests/sec).
- **Errors** — **доля** ошибок (5xx, 4xx, timeout).
- **Duration** — **время** запросов (p50, p95, p99).

```promql
# Rate
sum(rate(http_requests_total[5m])) by (job)

# Errors
sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
  /
sum(rate(http_requests_total[5m])) by (job)

# Duration (p95)
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (job, le))
```

**Зачем RED**:
- **Простота**: 3 метрики, **быстро** настроить.
- **User-centric**: **видит** то, что **видит** пользователь (скорость, ошибки).
- **Алерты**: **error rate > 5%**, **p95 > 1 s** → **критичный** алерт.

**USE (Utilization, Saturation, Errors)** — для **ресурсов** (CPU, memory, disk, network, thread pool, connection pool):
- **Utilization** — **доля** времени, когда ресурс **занят** (например, CPU usage 70%).
- **Saturation** — **насыщение** (например, queue length, pending requests, OOM).
- **Errors** — **ошибки** (например, disk I/O errors, connection refused).

```promql
# CPU utilization
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Memory saturation
container_memory_working_set_bytes / container_spec_memory_limit_bytes

# Disk I/O errors
rate(node_disk_io_errors[5m])

# Thread pool saturation
tomcat_threads_busy / tomcat_threads_current
```

**Зачем USE**:
- **Resource-centric**: **видит** **узкие места** (CPU, memory, disk).
- **Proactive**: **насыщение** → **предсказывает** **деградацию** **до** **ошибок**.
- **Алерты**: **CPU > 80%** (utilization), **queue length > 100** (saturation).

**Сравнение**:
| | RED | USE |
|---|---|---|
| Для | **User-facing** API | **Ресурсы** (CPU, memory, disk) |
| Вопрос | «Что видит пользователь?» | «Какой ресурс в узком месте?» |
| Метрики | Rate, Errors, Duration | Utilization, Saturation, Errors |
| Алерты | Error rate, p95 latency | CPU > 80%, queue length |
| Пример | API, front-end | Kubernetes pod, JVM, БД |

**Практика**:
- **RED** для **каждого** **user-facing** сервиса (API, BFF, front-end).
- **USE** для **каждого** **ресурса** (CPU, memory, disk, network, thread pool, connection pool, Kafka consumer lag).
- **Вместе**: **RED** отвечает «что сломалось для пользователя», **USE** — «почему» (ресурс в узком месте).

**Вывод**: **RED** — для **пользователя**, **USE** — для **ресурсов**. Используй **обе** для **полной** картины. **RED** — **symptom**, **USE** — **cause**.


### 7. Как агрегировать логи: ELK/Loki, structured logging, MDC

**Log aggregation** — **централизация** **логов** из **всех** сервисов в **одной** системе. Без этого **невозможно** **диагностировать** проблемы в **микросервисах** (логи разбросаны по 100+ серверам/подам).

**Стек 1: ELK (Elasticsearch, Logstash, Kibana)**
- **Elasticsearch** — **поисковый** **движок** (full-text search, JSON indexing).
- **Logstash** — **pipeline** для **сбора** и **трансформации** (input → filter → output).
- **Kibana** — **UI** для **поиска** и **визуализации**.
- **Преимущества**: **мощный** поиск, **аналитика**, **ML**.
- **Недостатки**: **тяжёлый** (RAM, CPU), **дорогой** (лицензия), **сложный** в **администрировании**.

**Стек 2: Loki (Grafana)**
- **Loki** — **log aggregation** **система**, **оптимизированная** для **логов** (не индексирует **текст**, а **метки**).
- **Пromtail/Alloy** — **agent** для **сбора** логов (tail file, systemd journal).
- **Grafana** — **UI**.
- **Преимущества**: **лёгкий** (меньше RAM/CPU), **дешёвый**, **простой**, **интеграция** с **Prometheus** (одна **экосистема**).
- **Недостатки**: **меньше** **возможностей** **поиска** (только **метки** + **full-text** на **малом** объёме).

**Выбор**:
- **ELK** — **крупные** компании, **сложная** **аналитика**, **ML**.
- **Loki** — **Kubernetes**-native, **Prometheus**-экосистема, **экономия** ресурсов.

**Structured Logging** — **логи** в **структурированном** формате (JSON), а не **plain text**.
```json
{"timestamp":"2026-01-15T10:30:00Z","level":"ERROR","service":"order-api","trace_id":"abc123","span_id":"def456","message":"Failed to process order","order_id":123,"error":"timeout"}
```
**Преимущества**:
- **Поиск** по **любому** **полю** (не только **текст**).
- **Корреляция** с **traces** (trace_id, span_id).
- **Агрегация** (например, **count** по **level**).
- **Индексация** (Loki **индексирует** **метки**, Elasticsearch **всё**).

**MDC (Mapped Diagnostic Context)** — **ThreadLocal**-based **контекст** для **логов** (SLF4J/Logback).
```java
// Spring Boot: MDC auto-populated (trace_id, span_id)
log.info("Processing order {}", orderId);
// Вывод: "Processing order 123" + MDC (trace_id, span_id)

// Rучное
MDC.put("userId", "user123");
log.info("User action");
MDC.remove("userId");
```

**В Reactor**: **MDC не работает** (ThreadLocal теряется между переключениями потоков). Используй **`Context`** (см. Q704) + **logback-reactive** или **OTel**.

**Пример (Logback + JSON)**:
```xml
<!-- logback-spring.xml -->
<configuration>
    <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <customFields>{"service":"${APP_NAME}"}</customFields>
        </encoder>
    </appender>
    <root level="INFO">
        <appender-ref ref="JSON"/>
    </root>
</configuration>
```

**Вывод**: **Loki** — **Kubernetes**-native, **лёгкий**, **Prometheus**-экосистема. **ELK** — **мощный**, **сложный**. **Structured logging** (JSON) + **MDC** (или **Context** в Reactor) — **обязательны** для **корреляции** с **traces** и **поиска**.


### 8. Что такое SLO, SLI, SLA и error budgets

**SLI (Service Level Indicator)** — **метрика** **качества** сервиса (например, **доля** **успешных** запросов, **p95** latency, **uptime**).

**SLO (Service Level Objective)** — **цель** по **SLI** (например, **99.9%** **успешных** запросов за **месяц**, **p95** latency < **500 ms**).

**SLA (Service Level Agreement)** — **контракт** с **клиентом** (например, **99.9%** **uptime**, **штраф** за **нарушение**). **SLA** — **публичный**, **SLO** — **внутренний**.

**Error Budget** — **допустимый** **объём** **ошибок** за **период** = **100%** − **SLO**.
- Пример: SLO = **99.9%** → error budget = **0.1%** = **43.8 min** downtime за **месяц**.
- **Зачем**: **баланс** между **надёжностью** и **скоростью** **релизов**. Если **error budget** **исчерпан** → **заморозка** **релизов** (только **bugfix**). Если **остаток** **большой** → **можно** **рискнуть** с **релизами**.

**Примеры SLI/SLO**:

| SLI | SLO | Период | Error Budget |
|---|---|---|---|
| **Uptime** (доля успешных запросов) | 99.9% | Месяц | 43.8 min |
| **p95 latency** | < 500 ms | Месяц | 5% запросов > 500 ms |
| **Error rate** | < 0.1% | Час | 0.1% ошибок |
| **Availability** | 99.95% | Квартал | 6.2 hours |

**Как вычислить**:
```promql
# Uptime SLI (доля успешных запросов)
1 - (
  sum(rate(http_requests_total{status=~"5.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
)

# p95 latency SLI
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[30d])) by (le)) < 0.5
```

**Alerting по SLO**:
- **Бурст-алерт**: **error rate > 1%** в **последние** **5 min** (быстрая реакция).
- **Симвомный алерт**: **error budget burn rate** > **14.4x** (потрачено **14.4x** быстрее **нужного** → **исчерпается** за **день** вместо **месяца**).

```yaml
# Burn rate alert
- alert: ErrorBudgetBurn
  expr: >
    sum(rate(http_requests_total{status=~"5.."}[5m]))
    /
    sum(rate(http_requests_total[5m])) > 0.01  # 1% error rate
  for: 5m
  labels:
    severity: critical
```

**Вывод**: **SLI** — **метрика**, **SLO** — **цель**, **SLA** — **контракт**, **error budget** — **допустимый объём ошибок**. **Alerting** по **SLO** (burn rate) — **symptom-based** (не **cause-based**). **Error budget** — **баланс** между **надёжностью** и **скоростью** **релизов**.


### 9. Как стратегии алертинга: symptoms vs causes, alert fatigue

**Alert fatigue** — **усталость** от **алиртов**: **слишком** **много** **шумных** **алиртов** → **команда** **игнорирует** **все**. **Результат**: **реальные** **проблемы** **пропадают** в **шуме**.

**Две стратегии**:

**1. Symptoms (симптомные)** — алерты по **то, что видит пользователь**:
- **Error rate** > **5%** (пользователь видит **ошибки**).
- **p95 latency** > **1 s** (пользователь видит **медленность**).
- **Uptime** < **99.9%** (пользователь видит **доступность**).
- **Корреляция** с **SLO** (error budget burn rate).

**Преимущества**:
- **Мало** **алиртов** (только **важные**).
- **Понятны** **команде** (то, что **видит** пользователь).
- **Не** **зависят** от **внутренней** **архитектуры** (можно **менять** **код** без **изменения** **алиртов**).

**2. Causes (причинные)** — алерты по **внутренним** **метрикам**:
- **CPU** > **80%**.
- **Memory** > **90%**.
- **Disk** **I/O** **errors**.
- **Kafka** **consumer** **lag** > **1000**.

**Преимущества**:
- **Proactive** (видит **проблему** **до** **того**, как **пользователь** **увидит**).
- **Диагностика** (помогает **найти** **причину**).

**Недостатки**:
- **Много** **алиртов** (шум).
- **Ложные** **положительные** (CPU **высокий**, но **пользователь** **не** **страдает**).
- **Зависят** от **архитектуры** (при **изменении** **кода** нужно **менять** **алирты**).

**Практика (best practice)**:
- **Page** (кричать) — **только** **symptoms** (error rate, p95 latency, uptime).
- **Ticket** (тихо) — **causes** (CPU, memory, disk) — **для** **диагностики**.
- **Ингибирование**: если **symptom** **сработал** → **ингибировать** **causes** (не **кричать** **по** **CPU**, если **уже** **кричим** **по** **error rate**).
- **Группировка**: **group by** **job**, **severity** (не **по** **каждому** **поду**).

**Alertmanager configuration**:
```yaml
route:
  group_by: ['job', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers:
        - severity = "critical"
      receiver: page-oncall
    - matchers:
        - severity = "warning"
      receiver: ticket
inhibit_rules:
  - source_matchers:
      - severity = "critical"
    target_matchers:
      - severity = "warning"
    equal: ['job', 'instance']
```

**Вывод**: **Page** — **symptoms** (то, что **видит** пользователь). **Ticket** — **causes** (внутренние **метрики**). **Ингибирование** + **группировка** — **борьба** с **alert fatigue**. **SLO-based** **alerting** (burn rate) — **лучший** **подход** (symptom + **quantified**).


### 10. Что такое Micrometer Observation API и @Observed

**Observation API** (Micrometer 1.10+, Spring Boot 3) — **унифицированный** **API** для **создания** **span'а** + **метрики** **одновременно**. Заменяет **отдельные** **вызовы** **Tracer** + **MeterRegistry**.

**Зачем нужен**:
- **Раньше**: **Tracer.spanBuilder(...)** для **tracing** + **Timer.builder(...)** для **metrics** — **два** **вызова**, **два** **контекста**.
- **С Observation**: **один** **вызов** → **span** + **Timer** + **low-high** **metric** (например, **error** **count**).

**API**:
```java
// 1. Annotation @Observed
@Observed(name = "order.processing", contextualName = "Process Order")
public Order processOrder(OrderDto dto) {
    // Micrometer auto-creates:
    // - Span "order.processing" (if OTel enabled)
    // - Timer "order.processing"
    // - Counter "order.processing.errors" (if exception)
}

// 2. Manual (Observation.create)
Observation observation = Observation.createNotStarted("order.processing", tracer)
    .contextualName("Process Order")
    .lowCardinalityKeyValue("type", dto.getType())
    .start();
try (Observation.Scope scope = observation.openScope()) {
    // business logic
    return orderService.process(dto);
} catch (Exception e) {
    observation.error(e);
    throw e;
} finally {
    observation.stop();
}

// 3. With Reactor (Mono/Flux)
Mono<Order> result = Mono.fromCallable(() -> orderService.process(dto))
    .observe(Observation.createNotStarted("order.processing", tracer));
```

**Low vs High cardinality**:
- **Low cardinality** (например, `type`, `endpoint`) — **мало** **уникальных** **значений** → **можно** **использовать** как **label** в **метриках**.
- **High cardinality** (например, `user_id`, `request_id`) — **много** **уникальных** **значений** → **только** в **span'ах** (не в **метриках**, иначе **взорвёт** **БД**).

```java
.observation
    .lowCardinalityKeyValue("endpoint", "/orders")  // label in metrics
    .highCardinalityKeyValue("user_id", "123")      // only in span
```

**Интеграция с Spring**:
- **Spring Web**: **auto-observation** для **HTTP** requests (GET/POST → span + Timer).
- **Spring Data**: **auto-observation** для **JPA** queries.
- **Spring Kafka**: **auto-observation** для **producer/consumer**.
- **Custom**: **@Observed** или **Observation.createNotStarted**.

**Вывод**: **Observation API** — **унифицированный** **API** для **tracing** + **metrics**. **@Observed** — **annotation** для **авто-создания**. **Low/high cardinality** — **важно** для **метрик** (не **взорвать** **БД**). **Spring Boot 3** — **auto-observation** для **HTTP**, **JPA**, **Kafka**.


### 11. Как настроить correlation between logs, metrics, and traces

**Correlation** — **связь** **логов**, **метрик** и **трассировок** по **общим** **идентификаторам** (**trace id**, **span id**, **request id**). Без correlation **невозможно** **перейти** из **метрики** в **trace** в **log**.

**Ключевые идентификаторы**:
- **Trace id** — **общий** для **всего** trace.
- **Span id** — **уникальный** для **span**.
- **Request id** — **уникальный** для **HTTP request** (может **совпадать** с **trace id** или **быть** **отдельным**).

**Как настроить**:

1. **Logs**: **trace id** и **span id** в **каждом** **лог** (MDC / Context).
```java
// Spring Boot: MDC auto-populated (trace_id, span_id)
log.info("Processing order {}", orderId);
// Вывод (JSON):
// {"timestamp":"...","level":"INFO","trace_id":"abc123","span_id":"def456","message":"Processing order 123"}
```

2. **Metrics**: **trace id** как **label** (не рекомендуется из-за **high cardinality**). Лучше **aggregated** metrics (без trace id) + **link** через **endpoint**/**operation**.
```java
// НЕ: Counter.builder("requests").tag("trace_id", traceId) — high cardinality
// ДА: Counter.builder("requests").tag("endpoint", "/orders").tag("status", "200")
```

3. **Traces**: **span** с **атрибутами** (endpoint, status, user_id).

**Grafana**: **Explore** → **traces** + **metrics** + **logs** **коррелированы** (по **trace id**).

**Пример (Grafana)**:
1. **Dashboard**: **p95 latency** **вырос** (metric).
2. **Klick** на **metric** → **traces** (по **endpoint**/**time**).
3. **Klick** на **trace** → **spans** (по **trace id**).
4. **Klick** на **span** → **logs** (по **trace id** + **span id**).

**В Reactor**: **MDC не работает** (ThreadLocal теряется). Используй **`Context`** + **logback-reactive** или **OTel** (auto-populated).

**Вывод**: **Correlation** — **trace id** в **logs** (MDC/Context) + **aggregated** metrics (без trace id) + **traces** (spans). **Grafana Explore** — **переход** из **metrics** в **traces** в **logs** по **trace id**. **Rучная** correlation (high cardinality) — **антипаттерн**.


### 12. Как построить observability-стек для Java-микросервисов (референс-архитектура)

**Референс-архитектура** observability для **Java-микросервисов** в **Kubernetes**:

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TB
    subgraph Services["Java Microservices"]
        S1["Service A<br/>OTel SDK + Micrometer"]
        S2["Service B<br/>OTel SDK + Micrometer"]
        S3["Service C<br/>OTel SDK + Micrometer"]
    end

    subgraph Collection["Collection Layer"]
        OC["OTel Collector<br/>DaemonSet"]
        Prom["Prometheus<br/>Deployment"]
    end

    subgraph Storage["Storage / Backend"]
        Tempo["Grafana Tempo<br/>S3"]
        ES["Elasticsearch / Loki<br/>Logs"]
        TSDB["Prometheus TSDB / Thanos"]
    end

    subgraph Visualization["Visualization / Alerting"]
        Grafana["Grafana<br/>Dashboards + Explore"]
        AM["Alertmanager"]
    end

    S1 -->|"OTLP"| OC
    S2 -->|"OTLP"| OC
    S3 -->|"OTLP"| OC
    S1 -->|"/metrics"| Prom
    S2 -->|"/metrics"| Prom
    S3 -->|"/metrics"| Prom

    OC -->|"traces"| Tempo
    OC -->|"logs"| ES
    Prom --> TSDB

    Tempo --> Grafana
    ES --> Grafana
    TSDB --> Grafana
    Prom --> AM
    AM -->|"page/ticket"| OnCall["On-Call / Tickets"]
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n5 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n6 fill:#fbeaf3,stroke:#cf9fc2,stroke-width:2px,color:#1f2937
    classDef n7 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class S1 n0
    class S2 n0
    class S3 n0
    class OC n1
    class Prom n1
    class Tempo n2
    class ES n2
    class TSDB n2
    class Grafana n3
    class AM n4
    class OnCall n5
    class Services n7
    class Collection n7
    class Storage n7
    class Visualization n7
```

**Компоненты**:

1. **OTel SDK** (в каждом сервисе):
   - **Java agent** (`opentelemetry-javaagent.jar`) — **auto-instrumentation** (HTTP, JPA, Kafka).
   - **Micrometer** — **метрики** (Timer, Counter, Gauge).
   - **Observation API** — **unified** (tracing + metrics).

2. **OTel Collector** (DaemonSet):
   - **Receiver**: OTLP (gRPC).
   - **Processor**: batch, attrs, tail sampling.
   - **Exporter**: OTLP → Tempo (traces), OTLP → Loki/ES (logs).

3. **Prometheus** (Deployment):
   - **Scrape** `/metrics` с **каждого** сервиса.
   - **Recording rules** (предвычисленные запросы).
   - **Alerting rules** (SLO-based).
   - **Thanos/Cortex** — **long-term** storage (S3).

4. **Grafana Tempo** (traces):
   - **S3**-based, **горизонтально масштабируемый**.
   - **Grafana Explore** — **traces** + **metrics** + **logs**.

5. **Loki** (logs):
   - **Alloy/Promtail** — **сбор** логов (file tail).
   - **Grafana** — **UI**.
   - **Structured logging** (JSON) + **MDC** (trace_id, span_id).

6. **Grafana**:
   - **Dashboards**: RED (Rate, Errors, Duration) + USE (Utilization, Saturation, Errors).
   - **Explore**: **traces** + **metrics** + **logs** (correlation).
   - **Alerting**: **SLO-based** (burn rate).

7. **Alertmanager**:
   - **Группировка**, **ингибирование**, **silencing**.
   - **Роутинг**: **page** (critical) / **ticket** (warning).

**Best practices**:
- **Auto-instrumentation** (OTel Java agent) — **не** **ручная** instrumentация.
- **Structured logging** (JSON) + **MDC** (trace_id, span_id) — **обязательно**.
- **SLO-based alerting** (burn rate) — **symptom-based** (не **cause-based**).
- **Tail sampling** (OTel Collector) — **сохранять** **errors**/**slow** traces.
- **Low/high cardinality** (Micrometer) — **не** **взорвать** **БД**.
- **Grafana Explore** — **correlation** (metrics → traces → logs).

**Вывод**: **OTel SDK** (auto-instrumentation) + **Micrometer** (metrics) + **OTel Collector** (batching, sampling) + **Prometheus** (metrics) + **Tempo** (traces) + **Loki** (logs) + **Grafana** (visualization) + **Alertmanager** (alerting). **SLO-based** **alerting** + **correlation** — **ключ** к **production-ready** observability.



### 13. Какие бывают типы метрик: Counter, Gauge, Timer, Histogram — когда какой

**Типы метрик**:
| Тип | Пример | Семантика | Use case |
|-----|--------|-----------|----------|
| **Counter** | `requests_total` | монотонно растёт (reset только на 0 после restart) | количество событий |
| **Gauge** | `heap_used_bytes` | текущее значение (может расти и падать) | уровень ресурса |
| **Timer** | `request_duration` | duration + count | время операции |
| **Histogram** | `response_size` | distribution (buckets) | распределение значений |

**Counter** (Micrometer):
```java
Counter.builder("orders_created")
  .description("Созданные заказы")
  .tag("status", "success")
  .register(meterRegistry)
  .increment();
```

**Gauge**:
```java
Gauge.builder("db_pool_active", dataSource, DataSource::getActiveConnections)
  .description("Активные connection'ы в пуле")
  .register(meterRegistry);
```

**Timer**:
```java
Timer.builder("order_service.create")
  .tag("endpoint", "POST /orders")
  .register(meterRegistry)
  .record(() -> orderService.create(order));
```

**Histogram**:
```java
DistributionSummary.builder("response_size_bytes")
  .serviceLevelObjectives(1024, 10240, 102400, 1024000)  // buckets
  .register(meterRegistry)
  .record(responseBody.length());
```

**Prometheus mapping**:
- Counter → `counter` (с `total` суффиксом)
- Gauge → `gauge`
- Timer → `histogram` + `summary` (quantiles)
- Histogram → `histogram`

**Правило**:
- **Counter** — количество событий (requests, errors, orders)
- **Gauge** — текущее состояние (heap, connections, queue size)
- **Timer** — время (duration of request)
- **Histogram** — распределение (response size, cache hit size)

**Вывод**: **Counter** (количество), **Gauge** (уровень), **Timer** (время), **Histogram** (распределение). **Counter** — монотонно, **Gauge** — текущее, **Timer** = **Histogram** + count, **Histogram** — buckets для quantiles.

### 14. Что такое cardinality и почему высокая cardinality — проблема

**Cardinality** = количество уникальных **time series** (комбинация metric + labels).

**Пример**:
```
http_requests_total{method="GET", path="/users/{id}", status="200"}
```
Если `{id}` — 100000 уникальных пользователей → 100000 time series (высокая cardinality).

**Проблемы высокой cardinality**:
1. **Память Prometheus**: каждая time series — ~1-2 KB (labels) + samples. 1 млн series → GB.
2. **Slow query**: `sum by (path)` — 1 млн series → секунды.
3. **TTL**: Prometheus хранит 15 дней по умолчанию → 1 млн series × 15 дней = тяжёлая БД.
4. **WAL bloat**: write-ahead log растёт.

**Примеры низкой vs высокой cardinality**:
| Низкая | Высокая |
|--------|---------|
| `http_requests_total{method="GET"}` (1) | `http_requests_total{user_id="user_12345"}` (100000) |
| `db_pool_active{db="postgres"}` (1) | `cache_size_bytes{key="user_12345"}` (100000) |
| `order_created_total{status="success"}` (1) | `order_created_total{order_id="order_12345"}` (1000000) |

**Как снизить cardinality**:
1. **Route template** вместо **path**:
   ```java
   // ПЛОХО (высокая cardinality):
   .tag("path", request.getRequestURI())  // /users/12345 → 100000 series
   
   // ХОРОШО (низкая cardinality):
   .tag("route", request.getHandler().toString())  // UserController.getUser → 100 series
   ```

2. **Не метить user_id, order_id** — только **status, method, endpoint**:
   ```java
   Timer.builder("orders.create")
     .tag("status", "success")       // OK (2-3 values)
     // .tag("user_id", userId)      // НЕ (100000 values)
     .register(meterRegistry);
   ```

3. **Aggregate**: если нужна детализация — в **logs** (Loki), не в **metrics** (Prometheus).

4. **Micrometer**: **low cardinality** tags только; **high cardinality** → **logs** + **MDC**.

**Monitring cardinality**:
```promql
# Количество time series:
count(http_requests_total)

# Рост:
rate(count(http_requests_total)[1h])

# Top-10 metrics по cardinality:
topk(10, count by (__name__)({}))
```

**Alert**:
```yaml
- alert: HighCardinality
  expr: count(http_requests_total) > 50000
  for: 5m
  labels:
    severity: warning
```

**Вывод**: **cardinality** = количество уникальных **time series**. **Высокая cardinality** → **память**, **slow query**, **WAL bloat**. **Решение**: **route template** вместо **path**, **не метить** **user_id**/**order_id**, **high cardinality** → **logs** (Loki), не **metrics**.

### 15. Как устроен Prometheus: TSDB, chunks, compaction, retention

**Prometheus** — **pull-based** TSDB (time-series database).

**Архитектура**:
1. **Scrape** (pull): Prometheus **забирает** метрики с **/metrics** эндпоинтов.
2. **In-memory**: **Head** (последние 2 часа).
3. **On-disk**: **chunks** (2-минутные блоки) + **index**.
4. **Compaction**: merging chunks в более крупные.
5. **Retention**: удаление старых (по умолчанию 15 дней).

**TSDB структура**:
```
tsdb/
  head/            # in-memory (последние 2 ч)
  0123456789/      # chunk 1 (2 мин)
  0123456790/      # chunk 2 (2 мин)
  0123456800/      # chunk 3 (2 мин)
  index/           # inverted index (labels → series)
  wal/             # write-ahead log
```

**Chunk**:
- **2 минуты** данных (128 samples по 15-сек интервалу).
- **XOR encoding** (Gorilla): 1.5 бит на sample.
- **Compressed** (zstd, lz4).

**Index**:
- **Inverted index**: `label=value → series_ids`.
- **Postings**: для быстрых запросов.
- **Compression**: dictionary + postings.

**Compaction**:
- Merging **12 chunks** (24 ч) → **1 large chunk**.
- **Background**: не блокирует scrape.
- **Result**: менее файлов, быстрее read.

**Retention**:
```yaml
storage:
  tsdb:
    retention.time: 15d      # 15 дней
    retention.size: 50GB     # или 50 GB (whichever first)
    max-block-time: 48h      # max block duration
```

**WAL** (write-ahead log):
- **Crash safety**: если Prometheus упадёт, WAL восстанавливает head.
- **Truncate**: после compaction (24 ч).

**Query flow**:
1. **Parse PromQL**.
2. **Inverted index** → найти series.
3. **Read chunks** (head + on-disk).
4. **Decode** (Gorilla) → samples.
5. **Aggregate** (sum, rate, etc).

**Performance tuning**:
- **--storage.tsdb.retention.time** — retention.
- **--web.enable-remote-write-receiver** — remote write (для Thanos).
- **--storage.tsdb.max-block-time** — compaction period.
- **--storage.tsdb.wal-compression** — WAL compression.

**Вывод**: **Prometheus** — **TSDB** (2-минутные **chunks**, **Gorilla encoding**, **inverted index**, **compaction**). **Head** (in-memory, 2 ч) + **on-disk** (chunks) + **WAL** (crash safety). **Retention** (15 дней по умолчанию). **Query**: **index** → **chunks** → **decode** → **aggregate**.

### 16. Как устроена Jaeger vs Tempo vs Grafana Cloud

**Jaeger** (CNCF, graduate):
- **Traces**: **spans** (запрос) + **trace** (цепочка spans).
- **Storage**: **Cassandra**, **Elasticsearch**, **Kafka**, **Badger** (embedded).
- **Sampling**: **head-based** (client) + **tail-based** (collector).
- **UI**: **Jaeger UI** (поиск по trace, search).
- **Scalability**: **Cassandra** — горизонтально; **Badger** — single node.
- **Features**: **tags**, **logs**, **process** (service), **span** (operation).

**Tempo** (Grafana Labs):
- **Storage**: **S3**, **GCS**, **Blob**, **local disk**.
- **Model**: **blocks** (похоже на Prometheus TSDB).
- **Query**: **TraceQL** (новый query language, 2023).
- **Tail sampling**: в **OTel Collector** (не в Tempo).
- **UI**: **Grafana Explore** (integrated).
- **Scalability**: **S3** — горизонтально (объектное хранилище).
- **Cost**: **S3** — дёшево (penny per GB), retention — месяцы.

**Grafana Cloud** (managed):
- **Prometheus** (managed): **Loki** (logs) + **Tempo** (traces) + **Grafana**.
- **All-in-one**: **1 UI** (Grafana Explore).
- **Correlation**: metrics ↔ traces ↔ logs.
- **Cost**: **per GB** (ingested) — дорого при high volume.
- **Limitations**: **no self-hosting**, **vendor lock-in**.

**Сравнение**:
| Фича | Jaeger | Tempo | Grafana Cloud |
|------|--------|-------|---------------|
| Storage | Cassandra/ES/Badger | S3/GCS/local | managed |
| Scalability | high (Cassandra) | high (S3) | high |
| Cost | self-hosted | cheap (S3) | expensive |
| Tail sampling | collector | collector | collector |
| UI | Jaeger UI | Grafana Explore | Grafana |
| Correlation | limited | metrics+logs+traces | metrics+logs+traces |
| Query | trace ID | TraceQL | TraceQL + PromQL + LogQL |
| Self-hosted | yes | yes | no |

**Выбор**:
- **On-premises**, **high volume**: **Jaeger** (Cassandra) или **Tempo** (S3).
- **Cloud**, **correlation**: **Grafana Cloud** (managed).
- **Low cost**, **retention**: **Tempo** (S3).

**Вывод**: **Jaeger** (Cassandra/ES, self-hosted), **Tempo** (S3, TraceQL, low cost), **Grafana Cloud** (managed, all-in-one). **Выбор**: **on-premises** → **Jaeger/Tempo**, **cloud** → **Grafana Cloud**, **low cost** → **Tempo** (S3).

### 17. Что такое structured logging и как настроить MDC в Java

**Structured logging** = логи в **structured format** (JSON) с **fields** (не просто строка).

**Пример**:
```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "logger": "com.example.OrderService",
  "thread": "http-nio-8080-exec-1",
  "message": "Заказ создан",
  "traceId": "a1b2c3d4e5f6",
  "spanId": "1234567890",
  "orderId": "order_12345",
  "userId": "user_42",
  "duration_ms": 125
}
```

**Почему structured**:
1. **Поиск**: `orderId = "order_12345"` (не regex по строке).
2. **Aggregation**: `avg(duration_ms) by status`.
3. **Correlation**: **traceId** + **spanId** → **distributed tracing**.
4. **Filtering**: по **field** (не по **message**).

**MDC** (Mapped Diagnostic Context):
- **ThreadLocal**-based map: key → value.
- **Log4j2/Logback** — используют MDC в layout.
- **Spring Boot** — **`MDC.put`** в filter.

**Настройка (Logback + JSON)**:
```xml
<dependency>
  <groupId>net.logstash.logback</groupId>
  <artifactId>logstash-logback-encoder</artifactId>
  <version>7.4</version>
</dependency>
```
```xml
<appender name="JSON" class="net.logstash.logback.LogstashEncoder">
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"app":"orders-service"}</customFields>
  </encoder>
</appender>
```

**MDC + Spring Boot**:
```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class TraceFilter extends OncePerRequestFilter {
  @Override
  protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain chain) throws Exception {
    String traceId = request.getHeader("X-Trace-Id");
    if (traceId == null) {
      traceId = UUID.randomUUID().toString();
    }
    MDC.put("traceId", traceId);
    MDC.put("requestId", request.getRequestURI());
    try {
      chain.doFilter(request, response);
    } finally {
      MDC.clear();
    }
  }
}
```

**Correlation с OTel**:
```java
@Aspect
@Component
public class TraceAspect {
  @Around("execution(* com.example..*.*(..))")
  public Object trace(ProceedingJoinPoint pjp) throws Throwable {
    Span span = Span.current();
    MDC.put("traceId", span.getSpanContext().getTraceId());
    MDC.put("spanId", span.getSpanContext().getSpanId());
    try {
      return pjp.proceed();
    } finally {
      MDC.remove("traceId");
      MDC.remove("spanId");
    }
  }
}
```

**Thread-safety**: **MDC** — **ThreadLocal** → не передаётся между потоками (в **CompletableFuture**/**ExecutorService**).

**Решение**:
- **Micrometer** **Context Propagation**:
  ```java
  ContextRegistry.getInstance().registerThreadLocalAccessor(
    "mdc",
    () -> MDC.getCopyOfContextMap(),
    ctx -> MDC.setContextMap(ctx),
    MDC::clear
  );
  ```
- **TTL** (TransmittableThreadLocal, Alibaba) — для **ExecutorService**.

**Вывод**: **structured logging** = **JSON** логи с **fields** (не строка). **MDC** — **ThreadLocal** map для **traceId**/**spanId**/**userId**. **LogstashEncoder** (Logback) — JSON layout. **Correlation** с OTel через **MDC**. **Thread-safety**: **Context Propagation** (Micrometer) / **TTL** (Alibaba).

### 18. Как настроить distributed tracing: OTel SDK, propagation, context

**Distributed tracing** = отслеживание **request** через **микросервисы** (1 **trace** = 1 request, **N spans** = N операций).

**OTel SDK (Java)**:
```xml
<dependency>
  <groupId>io.opentelemetry</groupId>
  <artifactId>opentelemetry-sdk</artifactId>
  <version>1.24.0</version>
</dependency>
<dependency>
  <groupId>io.opentelemetry</groupId>
  <artifactId>opentelemetry-sdk-trace</artifactId>
</dependency>
```

**Initialization**:
```java
OpenTelemetrySdk sdk = OpenTelemetrySdk.builder()
  .setTracerProvider(
    SdkTracerProvider.builder()
      .addSpanProcessor(BatchSpanProcessor.builder(
        OtlpGrpcSpanExporter.builder()
          .setEndpoint("http://otel-collector:4317")
          .build()).build())
      .setSampler(Sampler.parentBasedRootSampler(
        Sampler.traceIdRatioBased(0.1)  // 10% traces
      ))
      .build()
  )
  .buildAndRegisterGlobal();
```

**Propagation** (context между services):
- **W3C TraceContext** (стандарт): `traceparent: 00-<trace_id>-<span_id>-<flags>`.
- **B3** (Zipkin): `X-B3-TraceId`, `X-B3-SpanId`, `X-B3-Sampled`.
- **OTel propagator**: **`TraceContextPropagator`**.

```java
OpenTelemetry otel = OpenTelemetrySdk.builder()
  .setPropagators(ContextPropagators.create(
    W3CTraceContextPropagator.getInstance()
  ))
  .build();
```

**Manual instrumentation**:
```java
Tracer tracer = GlobalOpenTelemetry.getTracer("my-app");
Span span = tracer.spanBuilder("order.create")
  .setAttribute("order.id", orderId)
  .setAttribute("order.status", "success")
  .startSpan();
try (Span span = tracer.spanBuilder("order.create")
      .setAttribute("order.id", orderId)
      .startSpan()) {
  orderService.create(order);
}
```

**Auto-instrumentation** (OTel Java agent):
```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.traces.exporter=otlp \
     -Dotel.metrics.exporter=otlp \
     -Dotel.logs.exporter=otlp \
     -Dotel.service.name=orders-service \
     -Dotel.traces.sampler=parentbased_traceidratio:0.1 \
     -jar app.jar
```
- **Spring Boot**, **Servlet**, **JDBC**, **gRPC**, **Kafka** — **auto-instrumented**.

**OTel Collector**:
- **Receive** (OTLP gRPC/HTTP) → **process** (sampling, filtering) → **export** (Jaeger/Tempo).
- **Batching**: 5000 spans или 5 сек (whichever first).
- **Tail sampling**: **errors**/**slow** traces — 100%, **normal** — 10%.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    send_batch_size: 5000
    timeout: 5s
  tailsampling:
    decision_wait: 1s
    policies:
      - name: errors
        type: status_code
        status_code: {codes: [ERROR]}
      - name: slow
        type: probabilistic
        probabilistic: {sample_ratio: 0.1}

exporters:
  otlp/tempo:
    endpoint: tempo:4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, tailsampling]
      exporters: [otlp/tempo]
```

**Correlation**: **MDC** (logs) + **trace_id**/**span_id** в **Prometheus labels** (через **Micrometer**/**OTel bridge**).

**Вывод**: **OTel SDK** (Tracer, Span, Sampler) + **Propagation** (W3C TraceContext) + **OTel Java agent** (auto-instrumentation) + **OTel Collector** (batching, tail sampling) + **Tempo** (storage). **Correlation**: **MDC** (logs) + **trace_id** (metrics).

### 19. Что такое SLO-based alerting и burn rate

**SLO** (Service Level Objective) = **целевой уровень** (например: **99.9%** uptime).

**SLI** (Service Level Indicator) = **метрика**, по которой считается SLO (например: % **successful requests**).

**SLA** (Service Level Agreement) = **контракт** с клиентом (если не SLA — **penalty**).

**Error budget** = **1 - SLO** (например: **1 - 99.9% = 0.1%**).
- **0.1% × 30 дней × 86400 сек = 259 сек** (допустимый downtime за месяц).

**Burn rate** = **скорость** расходования error budget:
- **Burn rate 1** = расход по плану (100% error budget за 30 дней).
- **Burn rate 2** = 2× быстрее (error budget за 15 дней).
- **Burn rate 10** = 10× быстрее (error budget за 3 дня).
- **Burn rate 100** = очень быстро (error budget за несколько часов).

**SLO-based alerting** (Google SRE):
- **Multi-window, multi-burn-rate**: 2 окна (1 час + 6 часов) + 2 burn rates (5× + 1×).
- **Page** (critical): **burn rate 5×** за **1 час** → **page** (телефон).
- **Ticket** (warning): **burn rate 1×** за **6 часов** → **ticket** (Slack).

**Пример (Prometheus)**:
```promql
# SLI: fraction of successful requests (200-299):
sum(rate(http_requests_total{status=~"2.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# SLO: 99.9% (error budget 0.1%):
# Burn rate 5× (1h window, 5× faster than 0.1%):
(
  1 - (
    sum(rate(http_requests_total{status=~"2.."}[1h]))
    /
    sum(rate(http_requests_total[1h]))
  )
) > (5 * 0.001)  # 5× 0.1% = 0.5%

# Burn rate 1× (6h window, 1× faster than 0.1%):
(
  1 - (
    sum(rate(http_requests_total{status=~"2.."}[6h]))
    /
    sum(rate(http_requests_total[6h]))
  )
) > (1 * 0.001)  # 1× 0.1% = 0.1%
```

**Alertmanager**:
```yaml
- alert: HighErrorRatePage
  expr: (1 - (sum(rate(http_requests_total{status=~"2.."}[1h])) / sum(rate(http_requests_total[1h])))) > 0.005
  for: 5m
  labels:
    severity: page
  annotations:
    summary: "SLO burn rate 5× — page on-call"

- alert: HighErrorRateTicket
  expr: (1 - (sum(rate(http_requests_total{status=~"2.."}[6h])) / sum(rate(http_requests_total[6h])))) > 0.001
  for: 30m
  labels:
    severity: ticket
  annotations:
    summary: "SLO burn rate 1× — ticket"
```

**Почему SLO-based**:
- **Не alert** на **cause** (например: "CPU high") — **alert** на **symptom** (например: "error rate high").
- **Один alert** на SLO (не 10 alerts на 10 causes).
- **Alert fatigue** ↓ (меньше alerts, но все **meaningful**).

**Вывод**: **SLO** (99.9%) + **SLI** (success rate) + **error budget** (0.1%). **Burn rate** = скорость расходования budget. **Multi-window**: 1h (page) + 6h (ticket). **SLO-based alerting** — **symptom-based** (не cause-based), **меньше alerts**, **меньше alert fatigue**.

### 20. Как построить dashboard в Grafana: RED, USE, SLO

**Grafana dashboard** = визуализация **metrics** (Prometheus) + **traces** (Tempo) + **logs** (Loki).

**RED** (Rate, Errors, Duration) — для **services**:
```
┌──────────────────────────────────────┐
│  Rate (req/s)     │  Errors (%/s)    │
├──────────────────────────────────────┤
│  Duration (p50/p95/p99)              │
└──────────────────────────────────────┘
```
- **Rate**: `sum(rate(http_requests_total[1m])) by (status)`.
- **Errors**: `sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m]))`.
- **Duration**: `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))`.

**USE** (Utilization, Saturation, Errors) — для **resources**:
- **CPU**: utilization (CPU used %), saturation (load average), errors (throttled).
- **Memory**: utilization (heap used %), saturation (GC pause), errors (OOM).
- **Disk**: utilization (disk used %), saturation (IOPS), errors (I/O errors).
- **Network**: utilization (bandwidth used %), saturation (queue), errors (retransmits).

**SLO panel**:
- **SLI**: success rate (line chart).
- **Error budget**: remaining budget (gauge).
- **Burn rate**: current burn rate (bar chart).
- **SLO status**: 99.9% achieved? (gauge, green/red).

**Пример dashboard**:
```
Row 1: SLO Overview
  - SLI (success rate)
  - Error budget remaining
  - Burn rate

Row 2: RED
  - Rate (stacked area: 2xx, 4xx, 5xx)
  - Errors (line)
  - Duration (p50, p95, p99)

Row 3: Resources (USE)
  - CPU (utilization, saturation)
  - Memory (heap, GC)
  - Disk (I/O)

Row 4: Traces
  - Top 10 slow traces (Tempo)
  - Error traces (Tempo)

Row 5: Logs
  - Recent errors (Loki)
```

**Grafana JSON** (фрагмент):
```json
{
  "title": "Rate (req/s)",
  "type": "timeseries",
  "targets": [
    {
      "expr": "sum(rate(http_requests_total[1m])) by (status)",
      "legendFormat": "{{status}}"
    }
  ]
}
```

**Переменные**:
- **Service**: `{{service}}` (dropdown).
- **Environment**: `{{env}}` (prod/staging).
- **Time range**: 1h, 6h, 24h.

**Correlation**:
- **Click** на **metric** → **traces** (Tempo, по **trace_id**).
- **Click** на **trace** → **logs** (Loki, по **trace_id**).

**Вывод**: **Grafana dashboard** = **SLO** (SLI, error budget, burn rate) + **RED** (rate, errors, duration) + **USE** (utilization, saturation, errors) + **traces** (Tempo) + **logs** (Loki). **Correlation**: **metrics** → **traces** → **logs** (по **trace_id**). **Переменные**: **service**, **env**, **time range**.

