# Иностранные компании: Финтех и Payments (idempotency, Saga, event-driven, real-time)

Раздел — тематический: архитектура payments и event-driven систем, которую требуют в UK/EU финтехе (Revolut, Wise, Monzo, Starling, Deliveroo, Stripe, PayPal). В US-компаниях payments менее строгий (нет PSD2, DORA), в Israel — fintech (Payoneer), в Singapore — e-wallet (GrabPay, SeaMoney, ShopeePay).

> Ключевое отличие от локальных: в EU/UK-финтехе payments — **financial-grade** (consistency > availability, idempotency обязательна, event-driven с Kafka + outbox). Middle-разработчик должен **понимать** trade-offs (CAP, consistency vs availability) и **реализовывать** (idempotency key, Saga pattern, CQRS).

### 1. Payments architecture: idempotency, distributed transactions, fraud detection

**Idempotency** (идемпотентность) — **повторный запрос не создаёт дубль**. **Критично** для payments (если пользователь нажал «Оплатить» 2 раза, не должно быть 2 транзакций).

**Idempotency key** (ключ идемпотентности):
- **Client** генерирует **unique ID** (UUID v4) для каждого запроса.
- **Server** хранит `idempotency_key → result` в **Redis** (TTL 24 часа) или **PostgreSQL**.
- **Повторный запрос** с тем же `idempotency_key` → **return cached result** (не создаёт дубль).
- **Новый запрос** с новым `idempotency_key` → **process normally**.

```java
// example: idempotency в Java (Spring Boot)
@PostMapping("/payments")
public ResponseEntity<Payment> createPayment(
    @RequestHeader("Idempotency-Key") String idempotencyKey,
    @RequestBody PaymentRequest request) {
    
    // 1. Check if we've seen this idempotency key before
    Optional<Payment> cached = paymentCache.findByIdempotencyKey(idempotencyKey);
    if (cached.isPresent()) {
        return ResponseEntity.ok(cached.get());  // Return cached result
    }
    
    // 2. Process the payment
    Payment payment = paymentService.createPayment(request);
    
    // 3. Cache the result (TTL 24 hours)
    paymentCache.put(idempotencyKey, payment, Duration.ofHours(24));
    
    return ResponseEntity.status(HttpStatus.CREATED).body(payment);
}
```

**Вопросы**: «Как реализовать idempotency в payments?» → **Ответ**: «Client генерирует **UUID v4** (idempotency key), server хранит `idempotency_key → result` в **Redis** (TTL 24 часа). **Повторный запрос** с тем же key → **return cached result**. **Edge cases**: **timeout** (client не получил ответ, но payment создан — server должен ответить cached result), **retry** (client retry'ит, server idempotent)».

**Distributed transactions** (распределённые транзакции):
- **2PC** (Two-Phase Commit) — **prepare** (все участники говорят «готовы»), **commit** (координатор говорит «коммит»). **Проблемы**: **blocking** (если один участник упал, все заблокированы), **single point of failure** (координатор).
- **Saga pattern** — **sequence of local transactions** (каждый сервис делает свою транзакцию), **compensating transactions** (если что-то упало, откатываем предыдущие). **Advantages**: **no blocking**, **eventual consistency**. **Disadvantages**: **complexity** (нужно писать compensating transactions).
- **TCC** (Try-Confirm-Cancel) — **Try** (зарезервировать ресурсы), **Confirm** (подтвердить), **Cancel** (отменить). **Advantages**: **stronger consistency** (чем Saga). **Disadvantages**: **more complex** (3 фазы).

**Пример Saga (payment flow)**:
1. **Create order** (сервис Order: `INSERT INTO orders`)
2. **Reserve inventory** (сервис Inventory: `UPDATE inventory SET reserved = reserved + 1`)
3. **Charge payment** (сервис Payment: `CREATE payment`)
4. **Если payment failed** → **compensate**: **release inventory** (`UPDATE inventory SET reserved = reserved - 1`), **cancel order** (`UPDATE orders SET status = 'cancelled'`)

**Fraud detection** (предотвращение мошенничества):
- **Real-time** (в реальном времени) — **ML модель** (классификация: fraud vs legit, accuracy 95%+), **< 100ms** (latency).
- **Rules** (правила) — **velocity** (10 транзакций/мин), **geography** (страна не совпадает с картой), **amount** (сумма аномально высокая).
- **Device fingerprinting** (отпечаток устройства) — **unique ID** (браузер, ОС, экран), **anomaly detection** (новое устройство → подозрение).
- **Behavioral analysis** (анализ поведения) — **click pattern** (как пользователь кликает), **typing speed** (скорость набора), **mouse movement** (движение мыши).

**Chargebacks** (возвраты):
- **Dispute** (спор) — клиент спорит с транзакцией (не узнаёт, double charge).
- **Evidence** (доказательства) — merchant собирает доказательства (receipt, IP, device fingerprint).
- **Resolution** (разрешение) — банк решает (вернуть деньги merchant или клиенту).
- **Chargeback ratio** (доля возвратов) — **< 1%** (иначе банк отключает merchant).

**Multi-currency** (многовалютность):
- **FX rate** (курс обмена) — **real-time** (от провайдера: OANDA, CurrencyCloud), **spread** (наценка, 0.5–2%).
- **Currency conversion** (конвертация) — **rounding** (2 decimals), **precision** (BigDecimal, не double).
- **Reconciliation** (сверка) — **daily** (сверка балансов по валютам).

**Вопросы**: «Как использовать Saga pattern?» → **Ответ**: «**Sequence of local transactions** (каждый сервис делает свою транзакцию), **compensating transactions** (откат при ошибке). **Пример**: Order → Inventory → Payment. Если Payment failed → **release inventory** + **cancel order**. **Advantages**: **no blocking**, **eventual consistency**. **Disadvantages**: **complexity** (compensating transactions)».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы реализовали **payments architecture**. **Idempotency**: client генерирует **UUID v4**, server хранит `idempotency_key → result` в **Redis** (TTL 24 часа). **Distributed transactions**: **Saga pattern** (Order → Inventory → Payment, compensating transactions при ошибке). **Fraud detection**: **ML model** (accuracy 95%+, < 100ms), **rules** (velocity, geography, amount), **device fingerprinting** (unique ID). **Chargebacks**: **dispute** (клиент спорит), **evidence** (merchant собирает доказательства), **resolution** (банк решает), **ratio** (< 1%). **Multi-currency**: **FX rate** (real-time, OANDA), **spread** (0.5–2%), **precision** (BigDecimal). **Result**: **zero double-charges** (idempotency), **fraud rate < 0.1%** (ML model), **chargeback ratio < 0.5%** (evidence)».

### 2. Event-driven architecture: Kafka, event sourcing, CQRS, outbox pattern

**Kafka** (Apache Kafka) — **distributed event streaming platform**. **Core concepts**:
- **Topics** (темы) — логические каналы (e.g. `payments`, `orders`, `users`).
- **Partitions** (парты) — темы разделены на парты (параллелизм, масштабирование).
- **Producers** (продюсеры) — пишут сообщения в Kafka.
- **Consumers** (потребители) — читают сообщения из Kafka.
- **Consumer groups** (группы потребителей) — несколько consumers делят парты (load balancing).
- **Offset** (смещение) — позиция в парте (какое сообщение прочитано).
- **Replication** (репликация) — каждая парта реплицируется на 3 брокера (HA).
- **Retention** (хранение) — сообщения хранятся 7 дней (по умолчанию), потом удаляются.

**Event sourcing** (хранение событий, не состояния):
- **Events** (события) — immutable (нельзя изменить), append-only (только добавление).
- **State** (состояние) — вычисляется из событий (fold/reduce).
- **Advantages**: **full audit trail** (вся история), **replay** (можно пересчитать состояние), **temporal queries** (как было состояние в момент X).
- **Disadvantages**: **complexity** (сложно query'ить), **storage** (события накапливаются).

```java
// example: event sourcing в Java
public record PaymentCreated(String paymentId, BigDecimal amount, Currency currency, Instant createdAt) implements Event {}
public record PaymentApproved(String paymentId, String approverId, Instant approvedAt) implements Event {}
public record PaymentCompleted(String paymentId, Instant completedAt) implements Event {}

public class Payment {
    private final String paymentId;
    private BigDecimal amount;
    private Currency currency;
    private PaymentStatus status;
    
    public void apply(Event event) {
        if (event instanceof PaymentCreated e) {
            this.amount = e.amount();
            this.currency = e.currency();
            this.status = PaymentStatus.CREATED;
        } else if (event instanceof PaymentApproved e) {
            this.status = PaymentStatus.APPROVED;
        } else if (event instanceof PaymentCompleted e) {
            this.status = PaymentStatus.COMPLETED;
        }
    }
}
```

**CQRS** (Command Query Responsibility Segregation):
- **Commands** (команды) — изменяют состояние (e.g. `CreatePayment`, `ApprovePayment`).
- **Queries** (запросы) — читают состояние (e.g. `GetPayment`, `ListPayments`).
- **Separate models** (отдельные модели) — **write model** (для commands) и **read model** (для queries, optimized для чтения).
- **Advantages**: **scalability** (write и read можно масштабировать отдельно), **optimization** (read model optimized для конкретных queries).
- **Disadvantages**: **complexity** (2 модели, sync), **eventual consistency** (read может lag behind write).

**Outbox pattern** (запись события в БД + async доставка в Kafka):
- **Problem**: если запись в БД и отправка в Kafka — **2 операции**, если вторая упала → **data inconsistency** (БД записал, Kafka не получил).
- **Solution**: **outbox table** (таблица в БД, `outbox(id, event, payload, created_at, published_at)`).
- **Flow**: 1. Записать событие в **outbox table** (в той же транзакции, что и бизнес-данные). 2. **Async worker** (poller) читает outbox, отправляет в Kafka. 3. **Mark as published** (`published_at = now()`).
- **Advantages**: **atomicity** (запись в БД и outbox — одна транзакция), **reliability** (если Kafka down, событие в outbox, worker переотправит).
- **Disadvantages**: **latency** (async, не real-time), **polling** (worker poll'ит outbox, e.g. каждые 1 сек).

```sql
-- example: outbox table
CREATE TABLE outbox (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    published_at TIMESTAMP
);

-- example: transaction с outbox
BEGIN;
INSERT INTO payments (id, amount, status) VALUES (1, 100.00, 'created');
INSERT INTO outbox (event_type, payload) VALUES ('payment.created', '{"paymentId": 1, "amount": 100.00}');
COMMIT;
```

**Kafka vs RabbitMQ** (trade-offs):
- **Kafka**: **event streaming** (log, append-only), **replay** (можно перечитать), **high throughput** (1M+ msg/sec), **persistence** (7 дней), **order** (внутри парты). **Use case**: **event sourcing**, **CQRS**, **real-time analytics**.
- **RabbitMQ**: **message queue** (FIFO, routing), **flexible routing** (exchange, binding), **ack** (подтверждение), **DLQ** (dead letter queue), **no persistence** (по умолчанию). **Use case**: **task queue**, **RPC**, **notification**.

**Вопросы**: «Как реализовать event sourcing?» → **Ответ**: «**Events** (immutable, append-only), **state** (вычисляется из событий). **Пример**: `PaymentCreated`, `PaymentApproved`, `PaymentCompleted`. **Query**: **fold** (reduce) событий в состояние. **Advantages**: **full audit trail**, **replay**, **temporal queries**. **Disadvantages**: **complexity**, **storage**».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы использовали **Kafka** для **event-driven architecture**. **Event sourcing**: **events** (immutable, append-only), **state** (вычисляется из событий). **CQRS**: **write model** (для commands, PostgreSQL), **read model** (для queries, Elasticsearch, optimized для чтения). **Outbox pattern**: **outbox table** (в БД), **async worker** (poll'ит outbox, отправляет в Kafka). **Kafka vs RabbitMQ**: **Kafka** (event streaming, replay, high throughput), **RabbitMQ** (message queue, flexible routing, ack). **Result**: **eventual consistency** (CQRS), **full audit trail** (event sourcing), **reliability** (outbox pattern, zero message loss)».

### 3. Real-time processing: stream processing, real-time analytics, notifications

**Stream processing** (обработка потоков):
- **Kafka Streams** (embedded, Java/Scala) — **stateful** (state store), **joins** (stream-stream, stream-table), **aggregations** (windowed, e.g. 1 мин), **KTable** (материализованная таблица).
- **Apache Flink** (distributed, Java/Scala/Python) — **stateful**, **exactly-once** (semantic), **CEP** (Complex Event Processing), **event time** (processing с учётом времени события), **watermarks** (обработка late events).
- **Use cases**: **real-time analytics** (metrics, dashboards), **fraud detection** (anomaly detection, < 100ms), **recommendation** (real-time, < 1 сек).

**Real-time analytics** (аналитика в реальном времени):
- **ClickHouse** (columnar, OLAP) — **fast** (10× faster than PostgreSQL), **compression** (10×), **aggregations** (SUM, COUNT, AVG), **materialized views** (pre-computed).
- **Druid** (columnar, OLAP) — **real-time** (ingest, query), **rollups** (pre-aggregation), **ingestion** (Kafka, S3).
- **Use cases**: **dashboard** (metrics, latency, error rate), **reporting** (daily, weekly, monthly), **alerting** (threshold, anomaly).

**Real-time notifications** (уведомления в реальном времени):
- **WebSocket** (двусторонний, long-lived) — **full-duplex** (сервер и клиент обмениваются сообщениями), **persistent** (соединение остаётся открытым), **binary** (binary frames). **Use case**: **chat**, **collaboration**, **live dashboard**.
- **SSE** (Server-Sent Events, односторонний) — **server → client** (только сервер шлёт), **text** (text frames), **auto-reconnect** (браузер автоматически reconnect'ит). **Use case**: **notification**, **feed update**.
- **Push notification** (мобильные) — **FCM** (Firebase Cloud Messaging, Android), **APNs** (Apple Push Notification service, iOS), **payload** (заголовок, тело, data). **Use case**: **app notification** (user не в приложении).

**Вопросы**: «Как настроить real-time fraud detection?» → **Ответ**: «**Kafka Streams** (stream processing), **ML model** (accuracy 95%+, < 100ms), **rules** (velocity, geography, amount), **device fingerprinting** (unique ID). **Flow**: event (Kafka) → **ML model** (fraud vs legit) → **decision** (block/allow) → **log** (audit)».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы реализовали **real-time processing**. **Stream processing**: **Kafka Streams** (stateful, aggregations, < 100ms), **Apache Flink** (exactly-once, CEP, event time). **Real-time analytics**: **ClickHouse** (columnar, 10× faster, dashboard, alerting). **Real-time notifications**: **WebSocket** (chat, collaboration), **SSE** (feed update), **push** (FCM, APNs). **Result**: **real-time fraud detection** (< 100ms), **real-time dashboard** (ClickHouse, latency < 5 сек), **real-time notifications** (WebSocket, push)».

### 4. Scalability и high availability: sharding, replication, multi-AZ, multi-region

**Horizontal scaling** (горизонтальное масштабирование):
- **Add more nodes** (добавить ноды) — **stateless** (без состояния, e.g. web server), **load balancer** (распределение трафика).
- **Sharding** (шардирование) — **разбиение данных** на несколько нод (e.g. по `user_id`, `conversation_id`).
- **Replication** (репликация) — **копирование данных** на несколько нод (HA, read scaling).

**Sharding** (шардирование):
- **Partition key** (ключ шардирования) — `user_id` (каждый шард = часть пользователей), `conversation_id` (каждый шард = часть диалогов).
- **Shard count** (число шардов) — **2^n** (4, 8, 16, 32 — легко добавить), **consistent hashing** (минимизация ребалансинга).
- **Cross-shard queries** (запросы между шардами) — **avoid** (дорого), **denormalization** (дублирование данных), **federation** (объединение результатов).

**Replication** (репликация):
- **Synchronous** (синхронная) — **write** (запись) блокируется, пока не подтверждена всеми репликами. **Consistency**: **strong** (все реплики одинаковые). **Latency**: **высокая** (ожидание подтверждения).
- **Asynchronous** (асинхронная) — **write** (запись) сразу, **replication** (репликация) async. **Consistency**: **eventual** (реплики могут lag behind). **Latency**: **низкая** (не ждём подтверждения).
- **Read replicas** (реплики для чтения) — **read** (чтение) с реплик, **write** (запись) на мастер. **Scaling**: **read-heavy** (99% read).

**Multi-AZ** (Availability Zone, 3+ зоны):
- **AZ** (Availability Zone) — **физический центр данных** (отдельная сеть, электричество, cooling).
- **3 AZ** (минимум) — **HA** (High Availability), **RTO < 1 мин** (failover).
- **RDS Multi-AZ** — **master** (write) + **standby** (read-only, auto-failover).

**Multi-region** (2+ региона):
- **Active-Active** (оба региона активны) — **read/write** (чтение/запись) в обоих регионах. **Consistency**: **eventual** (конфликты Possible). **Latency**: **низкая** (близко к пользователю).
- **Active-Passive** (один активный, один standby) — **read/write** (чтение/запись) в одном регионе, **standby** (в другом, failover). **Consistency**: **strong** (один источник). **Latency**: **высокая** (для standby).
- **RPO** (Recovery Point Objective) — **сколько данных потерять** (e.g. RPO < 1 мин = потерять < 1 мин данных).
- **RTO** (Recovery Time Objective) — **сколько времени на восстановление** (e.g. RTO < 4 часа = восстановить за 4 часа).

**Вопросы**: «Как масштабировать на 10×?» → **Ответ**: «**Horizontal scaling** (добавить ноды), **sharding** (по user_id, 16 шардов), **replication** (read replicas, 5), **caching** (Redis, TTL 1 час), **load balancer** (NGINX, round-robin). **Result**: **10× scale** (1M req/sec), **zero downtime** (rolling update)».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы настроили **scalability** и **HA**. **Sharding**: **по user_id** (16 шардов, consistent hashing), **cross-shard queries** (avoid, denormalization). **Replication**: **asynchronous** (eventual consistency), **read replicas** (5, read-heavy 99%). **Multi-AZ**: **3 AZ** (HA, RTO < 1 мин), **RDS Multi-AZ** (master + standby). **Multi-region**: **active-passive** (London primary, Frankfurt standby), **RPO < 1 мин**, **RTO < 4 часа**. **Result**: **1M req/sec** (10× scale), **zero downtime** (rolling update), **RTO < 1 мин** (Multi-AZ failover)».
