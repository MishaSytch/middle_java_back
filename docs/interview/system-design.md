# System Design

### 1. Design case studies: URL shortener, rate limiter, news feed, chat system

**URL Shortener** (TinyURL, Bitly):
- **API**: `POST /shorten {url}` → `{shortUrl: "abc123"}`, `GET /r/abc123` → redirect.
- **Схема**: `short_codes (code PK, url, created_at, clicks)`.
- **Генерация кода**: **Base62** (a-z, A-Z, 0-9) из **auto-increment** или **snowflake**. **Коллизии**: **retry** (редко при 6+ символах).
- **Кэширование**: **Redis** `code → url` (TTL = 30 дней). **Cache-aside**.
- **Масштабирование**: **read-heavy** (99% GET) → **replica** + **CDN** для redirect. **Write** → **один** мастер.
- **Follow-up**: **analytics** (clicks, geo, referrer) → **Kafka** → **ClickHouse** (OLAP).

**Rate Limiter** (API protection):
- **Подход**: **Token Bucket** или **Sliding Window**.
- **Хранение**: **Redis** (`INCR` + `EXPIRE` для fixed window, **sorted set** для sliding window).
- **Распределённый**: **Redis** (все ноды **проверяют** **один** счётчик).
- **Правила**: **per-user** (100 req/min), **per-IP** (1000 req/min), **per-endpoint** (10 req/s для **дорогих**).
- **Ответ**: **429 Too Many Requests** + `Retry-After` header.
- **В Spring**: **Bucket4j** + **Redis** (distributed).

**News Feed** (Twitter, Facebook):
- **Проблема**: **fan-out** (у **пользователя** **1M** фоловеров → **1M** записей в **feed'ы**).
- **Подход**: **Hybrid fan-out**:
  - **Low-follower** (< 10K): **write-time fan-out** (запись в **feed** каждого **фоловера** при **постинге**).
  - **High-follower** (> 10K): **read-time fan-out** (при **запросе** feed'а **объединить** посты **всех** **high-follower** в **real-time**).
- **Хранение**: **PostgreSQL** (feed'ы), **Redis** (кэш последнего), **Elasticsearch** (поиск).
- **Масштабирование**: **sharding** по **user_id** (каждый **shard** = **часть** пользователей).
- **Follow-up**: **recommendation** (ML) → **batch** (ночью) + **real-time** (Kafka).

**Chat System** (WhatsApp, Telegram):
- **Real-time**: **WebSocket** (или **SSE** для **one-way**).
- **Масштабирование**: **stateful** (соединения **привязаны** к **ноде**) → **sticky sessions** (load balancer) или **message broker** (Kafka/NATS) для **рассылки**.
- **Доставка**: **at-least-once** (retry) + **ack** от **клиента**. **Idempotency** по **message_id**.
- **История**: **PostgreSQL** (sharding по **conversation_id**), **S3** (media).
- **Offline**: **message queue** на **сервере** (Kafka) → **доставить** при **онлайне**.
- **Follow-up**: **group chat** (fan-out на **N** участников), **read receipts**, **typing indicators**.

**Общие принципы**:
- **Сначала** **оцени** **нагрузку** (QPS, **размер** данных, **рост**).
- **Выбери** **архитектуру** (monolith vs microservices) под **нагрузку** (не **заранее**).
- **Кэширование** на **каждом** уровне (CDN → Redis → БД).
- **Асинхронность** для **не-критичных** операций (email, notifications).
- **Sharding** когда **одна** БД **не** тянет.

### 2. Scalability patterns: horizontal scaling, sharding, consistent hashing

**Horizontal Scaling** (масштабирование вширь):
- **Добавить** **ноды** (серверы, поды) вместо **апгрейда** **одной** (vertical).
- **Stateless** сервисы: **любые** запросы на **любую** ноду (load balancer **round-robin**).
- **Stateful** (сессии, соединения): **sticky sessions** или **externalized state** (Redis).

**Sharding** (горизонтальное партиционирование БД):
- **Разделить** данные на **N** **шардов** (каждый **шард** = **отдельная** БД).
- **Shard key**: **user_id**, **order_id**, **tenant_id** (каждый **шард** = **часть** пользователей).
- **Рассмотрение**: **hash** (униформно), **range** (диапазоны), **geographic** (регионы).

```sql
-- Sharding по user_id:
-- Shard 0: users 0-9999
-- Shard 1: users 10000-19999
-- ...
-- Router: user_id % N_shards → shard_id
```

**Проблемы sharding**:
- **Cross-shard query**: запрос **пересекает** **шарды** → **медленно** (N запросов + **объединение**).
- **Rebalancing**: **добавить** **шард** → **перенести** данные (downtime или **dual-write**).
- **Hot spot**: **один** shard **нагружен** (например, **VIP** user с **1M** постов) → **sub-sharding**.

**Consistent Hashing**:
- **Проблема**: **обычный** hash (`key % N`) → при **добавлении** **ноды** **перераспределяется** **весь** ключ (N-1/N данных).
- **Решение**: **кольцо** (hash space 0-2^32), **ноды** на **кольце**, **ключ** → **следующая** **нода** по **кольцу**.
- **Добавление** **ноды**: **перераспределяется** **только** **часть** ключей (1/N).
- **Replicas**: **каждый** ключ на **K** **нодах** (следующие по **кольцу**).
- **Пример**: **Cassandra**, **DynamoDB**, **Memcached**.

```
Кольцо (0 → 2^32 → 0):
  Node A (hash=100)
  Node B (hash=500)
  Node C (hash=900)
  
Ключ hash=300 → Node B (следующая по кольцу от 300)
Ключ hash=1000 → Node A (обход кольца)
```

**Когда что**:
- **Stateless API**: **horizontal scaling** (load balancer + N нод).
- **БД**: **sharding** (по user_id/tenant_id) + **replicas** для **чтения**.
- **Кэш/хранилище**: **consistent hashing** (Cassandra, Memcached).

### 3. Availability: SLA/SLO, multi-region, disaster recovery

**SLA (Service Level Agreement)** — **контракт** (99.9% uptime = **43.8 мин** downtime/мес).
**SLO (Service Level Objective)** — **внутренняя** цель (99.95% = **21.9 мин**/мес).
**Error Budget** = **100% − SLO**.

**Multi-Region Deployment**:
- **Active-Active**: **оба** региона **принимают** трафик (load balancer **глобальный**, **DNS** **анфрэндинг**). **Синхронизация** данных **в** **real-time** (bidirectional replication).
- **Active-Passive**: **один** регион **активен**, **второй** **горячий** **бэкап** (standby). **Failover** при **отказе** (5–30 мин).
- **Active-Active** **лучше** (нет **downtime** при **failover**), но **сложнее** (конфликты **репликации**, **latency** между **регионами**).

**Disaster Recovery (DR)**:
- **RTO (Recovery Time Objective)**: **сколько** **времени** до **восстановления** (например, **15 мин**).
- **RPO (Recovery Point Objective)**: **сколько** **данных** можно **потерять** (например, **1 мин** = **last** **commit** **1 мин** назад).
- **Уровни**:
  - **Level 1**: **бэкапы** (RTO = **часы**, RPO = **часы**).
  - **Level 2**: **hot standby** (RTO = **15 мин**, RPO = **1 мин**).
  - **Level 3**: **active-active multi-region** (RTO = **0**, RPO = **0**).

**Синхронизация данных между регионами**:
- **Синхронная** (strong consistency): **медленно** (latency между регионами **50–200 мс**), **надёжно**.
- **Асинхронная** (eventual consistency): **быстро**, **но** **конфликты** (нужны **CRDT** или **last-write-wins**).

**Best practice**:
- **Active-Passive** для **большинства** (дешевле, проще).
- **Active-Active** для **критичных** (финансы, healthcare).
- **RTO/RPO** **определяются** **бизнесом** (не **техникой**).

### 4. Trade-offs: latency vs throughput, PACELC, CAP

**Latency vs Throughput**:
- **Latency**: **время** **отвечания** **одного** запроса (p50, p95, p99).
- **Throughput**: **сколько** запросов в **секунду** (QPS, RPS).
- **Trade-off**: **быстрый** ответ (low latency) → **меньше** **параллельных** запросов (low throughput). **И наоборот**.
- **Пример**: **синхронная** **валидация** (low latency, low throughput) vs **асинхронная** **очередь** (high throughput, high latency).

**PACELC Theorem**:
- **CAP**: **Consistency** vs **Availability** при **Partition**.
- **PACELC**: **P**artition → **A**vailability or **C**onsistency; **E**lse (no partition) → **L**atency or **C**onsistency.
- **То есть**: даже **без** **partition** есть **trade-off** между **latency** и **consistency**.

| Система | Partition | Else (no partition) |
|---|---|---|
| **PostgreSQL** (synchronous replication) | **C** (consistency) | **C** (consistency, но **высокая** latency) |
| **Cassandra** | **A** (availability) | **L** (latency, eventual consistency) |
| **etcd** (Raft) | **C** (consistency, **unavailable** при **partition** majority) | **C** (consistency) |
| **Kafka** | **A** (availability, **данные** **на** **одной** **реплике**) | **L** (latency, **async** replication) |

**CAP Theorem** (практика):
- **C (Consistency)**: **все** реплики **одинаковы** **всегда** (strong consistency).
- **A (Availability)**: **каждый** запрос **получает** **ответ** (даже **устаревший**).
- **P (Partition)**: **сеть** **разделена** (неизбежно в **распределённых** системах).
- **При P**: **нельзя** **иметь** **и C, и A**. **Выбрать** **одно**.

**Когда что**:
- **C**: **финансы** (баланс **должен** быть **точным**), **инвентарь** (нельзя **продать** **больше** **чем** **есть**).
- **A**: **social feed** (пользователь **должен** **видеть** **что-то**, даже **устаревшее**), **catalog** (товары **доступны** всегда).
- **PACELC Else=L**: **больше** **через** **async** (Kafka, Cassandra).
- **PACELC Else=C**: **меньше** **через** **sync** (PostgreSQL, etcd).

### 5. Load balancing: round-robin, least connections, consistent hashing

**Round-Robin**:
- **По** **очереди**: **request 1** → **Node A**, **request 2** → **Node B**, **request 3** → **Node C**, **request 4** → **Node A**, ...
- **Плюс**: **просто**, **униформно** (если **ноды** **одинаковые**).
- **Минус**: **не** учитывает **нагрузку** (быстрая **нода** **получает** **столько** **же**, сколько **медленная**).

**Least Connections**:
- **Выбрать** ноду с **меньшим** **числом** **активных** **соединений**.
- **Плюс**: **учитывает** **нагрузку** (быстрая **нода** **берёт** **больше**).
- **Минус**: **нужно** **знать** **состояние** **нод** (health check, metrics).

**Consistent Hashing**:
- **Ключ** (например, **user_id**) → **нода** по **кольцу** (см. Q2).
- **Плюс**: **минимум** **перераспределения** при **добавлении** **ноды**.
- **Минус**: **hot spot** (если **ключ** **не** **униформный**).

**Weighted Round-Robin**:
- **Ноды** с **разной** **мощностью** (CPU, RAM) → **разный** **вес**.
- **Node A** (вес 2): **2** запроса, **Node B** (вес 1): **1** запрос.

**В Kubernetes**:
- **Service** (ClusterIP): **round-robin** по **подам**.
- **Ingress** (Nginx, Traefik): **round-robin**, **least connections**, **IP hash**.
- **Service Mesh** (Istio): **round-robin**, **least connections**, **ring hash**, **random**.

**Health Check**:
- **Active**: **load balancer** **опрашивает** **ноду** (HTTP GET /health).
- **Passive**: **load balancer** **следит** за **ошибками** (5xx, timeout).
- **При** **отказе**: **нода** **исключается** из **пула** (до **восстановления**).

### 6. Caching strategies: cache-aside, write-through, write-behind, cache stampede

**Cache-Aside** (manual caching):
1. **Чтение**: **проверить** кэш → **нет** → **чтение** из **БД** → **запись** в **кэш** → **вернуть**.
2. **Запись**: **запись** в **БД** → **удаление** из **кэша** (не **обновление** — **race condition**).

```java
// Read:
User user = cache.get("user:" + id);
if (user == null) {
    user = db.findById(id);
    cache.put("user:" + id, user, Duration.ofMinutes(30));
}
return user;

// Write:
db.update(user);
cache.delete("user:" + id); // не put, а delete!
```

**Write-Through**:
- **Запись**: **одновременно** в **кэш** и **БД** (через **каш-менеджер**).
- **Плюс**: **чтение** **всегда** **актуально** (кэш **всегда** **синхронизирован**).
- **Минус**: **медленная** **запись** (два **записи**).

**Write-Behind** (write-back):
- **Запись**: **только** в **кэш** (БД **обновляется** **асинхронно**, **позднее**).
- **Плюс**: **быстрая** **запись** (только **кэш**).
- **Минус**: **потеря** **данных** при **отказе** **кэша** (до **flush** в **БД**).

**Cache Stampede** (thundering herd):
- **Проблема**: **ключ** **истёк** → **N** **запросов** **одновременно** **к** **БД** (все **видят** **cache miss**).
- **Решение**:
  - **Lock** (single-flight): **один** запрос **идёт** в **БД**, **остальные** **ждут**.
  - **TTL jitter**: **случайный** **TTL** (30 мин ± 5 мин) → **ключи** **истекают** **не** **одновременно**.
  - **Soft TTL**: **ключ** **актуален** **30 мин**, **но** **обновляется** **асинхронно** при **чтении** (не **блокирует**).

```java
// Single-flight (one request to DB, others wait):
User user = cache.get("user:" + id);
if (user == null) {
    user = singleFlight.execute("user:" + id, () -> {
        User dbUser = db.findById(id);
        cache.put("user:" + id, dbUser, Duration.ofMinutes(30));
        return dbUser;
    });
}
return user;
```

**Сравнение**:
| | Cache-Aside | Write-Through | Write-Behind |
|---|---|---|---|
| **Чтение** | Кэш → БД | Кэш (всегда актуально) | Кэш |
| **Запись** | БД → delete кэш | Кэш + БД (sync) | Кэш (async → БД) |
| **Сложность** | Низкая | Средняя | Высокая |
| **Консистентность** | Eventual (до delete) | Strong | Eventual (до flush) |
| **Потеря данных** | Нет | Нет | Да (при отказе кэша) |

**Best practice**:
- **Cache-Aside** для **большинства** (просто, достаточно).
- **Write-Through** для **критичных** (финансы, инвентарь).
- **Write-Behind** для **высокой** **нагрузки** (social feed, analytics).
- **Single-flight** + **TTL jitter** против **stampede**.

### 7. Message queues: Kafka vs RabbitMQ vs Pulsar

**Kafka**:
- **Log-based** (append-only log), **partition** по **теме**.
- **Throughput**: **очень** **высокий** (1M+ msg/s).
- **Retention**: **данные** **хранятся** (7 дней по умолчанию) → **replay**.
- **Use case**: **event streaming**, **log aggregation**, **CDC** (Change Data Capture).
- **Минус**: **latency** **высокая** (batching), **не** **подходит** для **real-time** **RPC**.

**RabbitMQ**:
- **Queue-based** (message → consumer, **удаление** после **ack**).
- **Throughput**: **средний** (100K msg/s).
- **Routing**: **exchange** (direct, topic, fanout, headers) → **гибкая** **маршрутизация**.
- **Use case**: **task queues**, **RPC**, **real-time** **notifications**.
- **Минус**: **нет** **replay** (message **удалён** после **ack**), **меньше** **throughput**.

**Pulsar**:
- **Log-based** (как Kafka) + **queue-based** (как RabbitMQ).
- **Throughput**: **высокий** (сравнимо с Kafka).
- **Storage**: **разделено** (bookkeeper) → **масштабируемость**.
- **Use case**: **Kafka + RabbitMQ** в **одном** (event streaming + task queues).
- **Минус**: **молодой** (меньше **экосистема**), **сложнее** **оперировать**.

**Сравнение**:
| | Kafka | RabbitMQ | Pulsar |
|---|---|---|---|
| **Модель** | Log (partition) | Queue (exchange) | Log + Queue |
| **Throughput** | 1M+ msg/s | 100K msg/s | 500K+ msg/s |
| **Latency** | Высокая (batching) | Низкая | Низкая |
| **Replay** | Да (retention) | Нет | Да |
| **Routing** | Topic (partition) | Exchange (гибкий) | Topic (гибкий) |
| **Use case** | Event streaming, CDC | Task queues, RPC | Hybrid |
| **Экосистема** | Огромная | Огромная | Растёт |

**Когда что**:
- **Kafka**: **event streaming**, **log aggregation**, **CDC**, **большие** **объёмы**.
- **RabbitMQ**: **task queues**, **RPC**, **real-time** **notifications**, **гибкая** **маршрутизация**.
- **Pulsar**: **нужно** **и Kafka, и RabbitMQ** (hybrid), **масштабируемость** **storage**.

### 8. Database selection: OLTP vs OLAP, NewSQL

**OLTP (Online Transaction Processing)**:
- **Много** **коротких** **транзакций** (INSERT, UPDATE, DELETE).
- **Нормализация** (3NF), **индексы**, **ACID**.
- **Пример**: **PostgreSQL**, **MySQL**, **Oracle**.
- **Use case**: **CRM**, **e-commerce**, **banking**.

**OLAP (Online Analytical Processing)**:
- **Мало** **сложных** **запросов** (SELECT с JOIN, GROUP BY, агрегация).
- **Денормализация** (star schema, snowflake schema), **columnar storage**.
- **Пример**: **ClickHouse**, **Redshift**, **Snowflake**, **BigQuery**.
- **Use case**: **analytics**, **reporting**, **BI**.

**НовSQL (NewSQL)**:
- **Гибрид**: **ACID** (как OLTP) + **горизонтальное** **масштабирование** (как NoSQL).
- **Пример**: **CockroachDB**, **Spanner**, **YugabyteDB**, **TiDB**.
- **Use case**: **финансы** (ACID + масштаб), **IoT** (масштаб + ACID).

**NoSQL**:
- **Document** (MongoDB): **гибкая** **схема**, **JSON**.
- **Key-Value** (Redis, DynamoDB): **быстро**, **просто**.
- **Columnar** (Cassandra, HBase): **много** **колонок**, **мало** **строк**.
- **Graph** (Neo4j): **связи** **между** **объектами**.

**Сравнение**:
| | OLTP | OLAP | NewSQL | NoSQL |
|---|---|---|---|---|
| **Транзакции** | ACID | Нет (или слабый) | ACID | Зависит |
| **Масштабирование** | Вертикальное | Вертикальное | Горизонтальное | Горизонтальное |
| **Схема** | Фиксированная | Денормализованная | Фиксированная | Гибкая |
| **Запросы** | Простые (PK) | Сложные (JOIN, GROUP BY) | Простые + SQL | Зависит |
| **Пример** | PostgreSQL | ClickHouse | CockroachDB | MongoDB |

**Когда что**:
- **OLTP**: **транзакции** (заказы, платежи, инвентарь).
- **OLAP**: **аналитика** (reporting, BI, ML).
- **NewSQL**: **нужно** **и ACID, и масштаб** (финансы, IoT).
- **NoSQL**: **гибкая** **схема** (контент, каталог), **высокая** **нагрузка** (кэш, сессии).

**Гибрид**:
- **OLTP** (PostgreSQL) для **транзакций** + **OLAP** (ClickHouse) для **аналитики**.
- **CDC** (Change Data Capture): **PostgreSQL** → **Kafka** → **ClickHouse** (асинхронная синхронизация).

### 9. Rate limiting: token bucket, sliding window, distributed

**Fixed Window**:
- **Счётчик** **за** **окно** (например, **1 мин**).
- **Проблема**: **burst** на **границе** (50 запросов в **последнюю** **секунду** + 50 в **первую** **секунду** **следующего** окна = **100** **за** **2 мин**, хотя **лимит** **100/мин**).

**Sliding Window Log**:
- **Хранить** **timestamps** **всех** запросов.
- **Подсчёт**: **сколько** **запросов** **в** **последние** **N** секунд.
- **Плюс**: **точно** (нет **burst** на **границе**).
- **Минус**: **много** **памяти** (N timestamps per user).

**Sliding Window Counter**:
- **Гибрид**: **фиксированное** **окно** + **взвешенное** **предыдущее** **окно**.
- **Пример**: **лимит** 100/мин. **Сейчас**: **60** запросов в **текущем** окне, **40** в **предыдущем**. **Взвешенно**: **40 × (остаток_предыдущего_окна / 60s)** + **60** = **40 × 0.5 + 60 = 80**. **Осталось**: **20**.
- **Плюс**: **мало** **памяти** (2 счётчика), **точнее** чем **fixed**.

**Token Bucket**:
- **Bucket** **ёмкостью** **N** **токенов**.
- **Токены** **добавляются** **со** **скоростью** **R** (например, **100/мин** = **1.67/с**).
- **Запрос**: **снять** **1** токен. **Нет** **токенов** → **отклонить** (429).
- **Плюс**: **разрешает** **burst** (до **N** **токенов**), **ограничивает** **среднюю** **скорость**.
- **Минус**: **burst** **может** **перегрузить** **систему** (если **N** **большой**).

```java
// Token Bucket (Bucket4j):
Bucket bucket = Bucket.builder()
    .addLimit(Bandwidth.classic(100, Period.ofMinutes(1)))  // 100 req/min
    .build();
if (bucket.tryConsume(1)) {
    // процесс
} else {
    // 429 Too Many Requests
}
```

**Distributed Rate Limiting**:
- **Redis**: **все** **ноды** **проверяют** **один** **счётчик** (INCR + EXPIRE для fixed window).
- **Lua script**: **атомарная** **проверка** + **инкремент** (без **race condition**).

```lua
-- Redis Lua (sliding window):
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])

-- Удалить старые записи
redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
local count = redis.call('ZCARD', key)
if count < limit then
    redis.call('ZADD', key, now, now .. math.random())
    redis.call('PEXPIRE', key, window)
    return 1 -- allowed
else
    return 0 -- denied
end
```

**В Kubernetes**:
- **Istio**: **rate limiting** на **уровне** **service mesh** (Envoy filter).
- **API Gateway** (Kong, APISIX): **rate limiting** plugin (Redis-based).
- **Приложение**: **Bucket4j** + **Redis** (distributed).

### 10. Как провести design interview: структура ответа, что оценивают

**Структура ответа (30–45 мин)**:

**1. Уточнение требований (5 мин)**:
- **Функциональные**: **что** **должно** **уметь** (CRUD, поиск, real-time).
- **Нефункциональные**: **QPS**, **latency**, **volume**, **availability**, **consistency**.
- **Ограничения**: **бюджет**, **команда**, **deadlines**.
- **Пример**: "Сколько пользователей? Ожидаемый QPS? Какой latency? Нужна ли strong consistency?"

**2. Высокоуровневая архитектура (5–10 мин)**:
- **Схема**: **клиент** → **CDN** → **load balancer** → **API** → **БД**/**кэш**/**очередь**.
- **Компоненты**: **какие** **сервисы**, **какие** **БД**, **какие** **кэши**.
- **Не** **углубляться** в **детали** (это **следующий** **шаг**).

**3. Data Model (5 мин)**:
- **Таблицы** / **коллекции** / **ключи**.
- **Связи** (JOIN, foreign keys).
- **Индексы** (какие **колонки** **индексировать**).

**4. API Design (5 мин)**:
- **Эндпоинты** (REST, GraphQL, gRPC).
- **Формат** **данных** (JSON, Protobuf).
- **Постраничивание**, **фильтрация**, **сортировка**.

**5. Масштабирование (5–10 мин)**:
- **Горизонтальное** (stateless + load balancer).
- **Кэширование** (Redis, CDN).
- **Sharding** (если **нужно**).
- **Асинхронность** (Kafka, queues).

**6. Bottlenecks и trade-offs (5 мин)**:
- **Где** **узкое** **место**? (БД, сеть, CPU).
- **Какие** **trade-offs**? (latency vs consistency, cost vs performance).
- **Как** **мониторить**? (metrics, alerts).

**7. Follow-up (остаток времени)**:
- "А если **нагрузка** **вырастет** в **10 раз**?"
- "А если **БД** **упала**?"
- "А если **нужна** **strong consistency**?"
- "А как **безопасность**?"

**Что оценивают**:
- **Умение** **уточнять** **требования** (не **угадывать**).
- **Логика** **архитектурных** **решений** (не **заученные** **схемы**).
- **Понимание** **trade-offs** (не **идеального** **решения**).
- **Знание** **инструментов** (Kafka, Redis, PostgreSQL) и **когда** **что** **использовать**.
- **Коммуникация** (ясно, **по** **существу**, **без** **воды**).

**Типовые ошибки**:
- **Начинать** **рисовать** **схему** **без** **уточнения** **требований**.
- **Забывать** **нефункциональные** **требования** (QPS, latency, availability).
- **Выбирать** **микросервисы** **по** **моде** (а **не** **по** **нагрузке**).
- **Не** **говорить** **про** **bottlenecks** и **trade-offs**.
- **Заученная** **схема** (не **адаптируется** к **конкретным** **требованиям**).
