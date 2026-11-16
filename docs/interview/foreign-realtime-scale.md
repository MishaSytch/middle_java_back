# Иностранные компании: Real-time, Scale, Security (Israel-специфика)

Раздел — тематический: real-time системы, масштабирование (10M+ users) и security, которые требуют в Israel-компаниях (Wix, Checkpoint, Mobileye, CyberArk, Payoneer). В US-компаниях scale похожий, в EU/UK — fintech-фокус, в Singapore — multi-country.

> Ключевое отличие от локальных: в Israel-компаниях **real-time** (low latency < 50ms), **scale** (10M+ users, 10K+ req/sec), **security** (zero trust, RBAC vs ABAC) — **обязательны** на middle.

### 1. Real-time systems: collaboration, gaming, analytics, notifications

**Real-time collaboration** (совместная работа в реальном времени):
- **CRDT** (Conflict-free Replicated Data Types) — **конфликт-фри** (конфликты разрешаются автоматически), **merge** (объединение изменений), **convergence** (все реплики сойдутся). **Use case**: **Google Docs**, **Figma**, **Notion**.
- **OT** (Operational Transformation) — **transform** (трансформация операций), **consistency** (состояние одинаковое у всех), **latency** (низкая, < 100ms). **Use case**: **Google Docs** (legacy), **Etherpad**.
- **CRDT vs OT**: **CRDT** (no server, peer-to-peer, convergence), **OT** (server, transform, latency). **Тренд**: **CRDT** (modern, no server).

**Real-time gaming** (игры в реальном времени):
- **WebSocket** (двусторонний, long-lived) — **full-duplex** (сервер и клиент обмениваются), **binary** (binary frames, efficient).
- **Low latency** (< 50ms) — **edge server** (близко к игрокам), **state sync** (синхронизация состояния, e.g. 20 Hz = 50ms).
- **Prediction** (предсказание) — **client-side** (клиент предсказывает, e.g. movement), **reconciliation** (сервер корректирует).
- **Rollback** (откат) — **rollback netcode** (если сервер сказал «нет», откатываем, e.g.格斗 games).

**Real-time analytics** (аналитика в реальном времени):
- **Stream processing** (Kafka Streams, Flink) — **real-time** (обработка потока, < 1 сек), **aggregations** (SUM, COUNT, AVG), **windowed** (по времени, e.g. 1 мин).
- **ClickHouse** (columnar, OLAP) — **fast** (10× faster), **dashboard** (metrics, latency, error rate), **alerting** (threshold, anomaly).
- **Use case**: **real-time dashboard** (latency < 5 сек), **fraud detection** (< 100ms), **recommendation** (< 1 сек).

**Real-time notifications** (уведомления в реальном времени):
- **WebSocket** (двусторонний) — **chat**, **collaboration**, **live dashboard**.
- **SSE** (Server-Sent Events, односторонний) — **notification**, **feed update**.
- **Push** (мобильные) — **FCM** (Android), **APNs** (iOS), **payload** (заголовок, тело, data).

**Вопросы**: «Как настроить real-time collaboration?» → **Ответ**: «**CRDT** (no server, peer-to-peer, convergence), **WebSocket** (long-lived, binary), **state sync** (20 Hz = 50ms), **merge** (конфликты автоматически). **Use case**: **Google Docs**, **Figma»».

**Пример ответа на интервью**: «В прошлой компании (Israel) мы реализовали **real-time systems**. **Collaboration**: **CRDT** (no server, peer-to-peer, convergence), **WebSocket** (long-lived, binary), **state sync** (20 Hz = 50ms). **Gaming**: **WebSocket** (full-duplex, binary), **low latency** (< 50ms, edge server), **prediction** (client-side), **rollback** (格斗 games). **Analytics**: **Kafka Streams** (real-time, < 1 сек), **ClickHouse** (columnar, 10× faster), **dashboard** (latency < 5 сек). **Notifications**: **WebSocket** (chat), **SSE** (feed), **push** (FCM, APNs). **Result**: **real-time collaboration** (50ms latency), **real-time gaming** (< 50ms), **real-time analytics** (< 5 сек)».

### 2. Scale: 10M+ users, 10K+ req/sec, multi-region

**Scale requirements** (требования к масштабу):
- **10M+ users** (10+ миллионов пользователей) — **DAU** (Daily Active Users), **MAU** (Monthly Active Users).
- **10K+ req/sec** (10+ тысяч запросов в секунду) — **throughput** (пропускная способность), **peak** (пик, e.g. 100K req/sec).
- **Multi-region** (US, EU, APAC) — **latency** (задержка, < 100ms), **compliance** (GDPR, data residency).

**Sharding** (шардирование):
- **Partition key** (ключ шардирования) — `user_id` (каждый шард = часть пользователей), `conversation_id` (каждый шард = часть диалогов).
- **Shard count** (число шардов) — **2^n** (4, 8, 16, 32), **consistent hashing** (минимизация ребалансинга).
- **Cross-shard queries** (запросы между шардами) — **avoid** (дорого), **denormalization** (дублирование), **federation** (объединение).

**Replication** (репликация):
- **Read replicas** (реплики для чтения) — **read-heavy** (99% read), **scaling** (read).
- **Synchronous vs asynchronous** — **sync** (strong consistency, high latency), **async** (eventual consistency, low latency).
- **Multi-region replication** — **active-active** (оба региона активны, eventual consistency), **active-passive** (один активный, один standby, strong consistency).

**CDN** (Content Delivery Network):
- **Edge locations** (200+ worldwide) — **cache** (кэш, ближе к пользователям), **latency** (< 50ms).
- **Static content** (статика: JS, CSS, images) — **cache** (TTL 1 день), **invalidation** (очистка кэша).
- **Dynamic content** (динамика: API, personalization) — **no cache** (или short TTL, e.g. 1 мин).

**Caching** (кэширование):
- **Redis** (in-memory, key-value) — **cache** (TTL 1 час), **session** (сессия пользователя), **rate limit** (ограничение частоты).
- **In-memory cache** (Caffeine, Guava) — **local** (в памяти приложения), **TTL** (1 мин), **eviction** (LRU, LFU).
- **CDN** (edge cache) — **static** (JS, CSS, images), **dynamic** (API, short TTL).

**Вопросы**: «Как масштабировать на 10M users?» → **Ответ**: «**Sharding** (по user_id, 16 шардов), **replication** (read replicas, 5), **CDN** (edge cache, static), **caching** (Redis, TTL 1 час), **load balancer** (NGINX, round-robin). **Result**: **10M users**, **10K req/sec», **latency < 100ms**».

**Пример ответа на интервью**: «В прошлой компании (Israel) мы масштабировали на **10M users**. **Sharding**: **по user_id** (16 шардов, consistent hashing), **cross-shard queries** (avoid, denormalization). **Replication**: **read replicas** (5, read-heavy 99%), **async** (eventual consistency). **CDN**: **edge cache** (static, TTL 1 день), **dynamic** (no cache). **Caching**: **Redis** (TTL 1 час), **in-memory** (Caffeine, TTL 1 мин). **Result**: **10M users**, **10K req/sec**, **latency < 100ms**, **zero downtime** (rolling update)».

### 3. Security: zero trust, RBAC vs ABAC, secret management

**Zero trust** (модель «не доверяй никому»):
- **Never trust, always verify** (никогда не доверяй, всегда проверяй) — каждый запрос аутентифицируется и авторизуется.
- **Micro-segmentation** (микросегментация) — сеть разделена на маленькие сегменты, **NetworkPolicy** (K8s) или **security groups** (AWS).
- **Least privilege** (минимальные привилегии) — каждый пользователь/сервис имеет только нужные права.
- **MFA** (Multi-Factor Authentication) — обязательный для prod.
- **Encryption everywhere** (шифрование везде) — **at rest** (AES-256), **in transit** (TLS 1.2+).

**RBAC vs ABAC** (Role-Based vs Attribute-Based Access Control):
- **RBAC** (Role-Based) — **роли** (developer, ops, compliance), **права** (read, write, delete), **привязка** (user → role → permissions). **Simple** (просто), **static** (не меняется).
- **ABAC** (Attribute-Based) — **атрибуты** (user.department, user.clearance, resource.sensitivity), **policy** (если user.clearance >= resource.sensitivity, то allow). **Flexible** (гибко), **dynamic** (меняется).
- **Trade-offs**: **RBAC** (просто, но негибко), **ABAC** (гибко, но сложно). **Гибрид**: **RBAC** (для людей) + **ABAC** (для ресурсов).

**Secret management** (управление секретами):
- **HashiCorp Vault** (on-prem, self-hosted) — **dynamic secrets** (генерация на лету, e.g. DB credentials), **lease** (TTL, e.g. 1 час), **audit log** (все операции).
- **AWS Secrets Manager** (managed, AWS) — **rotation** (регулярная смена, e.g. каждые 30 дней), **integration** (RDS, DynamoDB, Lambda), **cost** ($0.40/secret/month).
- **K8s Secrets** (base64, не encryption) — **base64** (не шифрование, только encoding), **etcd** (хранение, encryption at rest), **CSI** (CSI Secrets Store, внешние секреты).

**Вопросы**: «Как настроить zero trust?» → **Ответ**: «**Micro-segmentation** (NetworkPolicy, security groups), **least privilege** (RBAC, IAM), **MFA** (WebAuthn, YubiKey), **encryption** (AES-256 at rest, TLS 1.2+ in transit), **audit log** (все операции)».

**Пример ответа на интервью**: «В прошлой компании (Israel, CyberArk) мы реализовали **zero trust security**. **Micro-segmentation**: **NetworkPolicy** (K8s, default deny), **security groups** (AWS, ingress/egress). **RBAC vs ABAC**: **RBAC** (для людей: developer, ops, compliance), **ABAC** (для ресурсов: user.clearance >= resource.sensitivity). **Secret management**: **HashiCorp Vault** (dynamic secrets, lease 1 час), **AWS Secrets Manager** (rotation 30 дней). **MFA**: **WebAuthn** (YubiKey, biometric). **Encryption**: **AES-256** (at rest), **TLS 1.2+** (in transit). **Audit log**: **все операции** → CloudWatch Logs → SIEM. **Result**: **zero trust**, **zero breaches** за 2 года»».

### 4. Mobile: React Native vs Flutter vs native, mobile security

**React Native** (Meta, cross-platform):
- **JavaScript/TypeScript** (JS/TS), **native components** (iOS, Android), **bridge** (мост, JS ↔ native).
- **Advantages**: **cross-platform** (один код на 2 платформы), **ecosystem** (npm, huge), **hot reload** (быстрый dev cycle).
- **Disadvantages**: **performance** (bridge, latency), **native features** (не все native features доступны), **bundle size** (больше, чем native).
- **Use case**: **Wix**, **Payoneer** (cross-platform, не нужен high performance).

**Flutter** (Google, cross-platform):
- **Dart** (язык), **Skia** (rendering engine, custom), **hot reload** (быстрый dev cycle).
- **Advantages**: **performance** (native-like, no bridge), **consistency** (один rendering engine), **design** (Material Design, Cupertino).
- **Disadvantages**: **bundle size** (больше, чем native), **native features** (нужны plugins), **ecosystem** (меньше, чем npm).
- **Use case**: **Checkpoint** (cross-platform, нужен high performance).

**Native** (Swift/iOS, Kotlin/Android):
- **Swift** (iOS), **Kotlin** (Android), **platform-specific** (каждая платформа отдельно).
- **Advantages**: **performance** (native, fastest), **native features** (все features доступны), **bundle size** (меньше).
- **Disadvantages**: **cross-platform** (2 кодабазы), **maintenance** (2 команды, 2 release cycles).
- **Use case**: **Mobileye** (native, high performance, AR/VR).

**Mobile security** (безопасность мобильного приложения):
- **Code obfuscation** (обфускация кода) — **ProGuard** (Android), **Bitcode** (iOS), **DexGuard** (Android, commercial).
- **Secure storage** (безопасное хранилище) — **Keychain** (iOS), **Keystore** (Android), **encrypted** (AES-256).
- **Biometric auth** (биометрическая аутентификация) — **Touch ID/Face ID** (iOS), **Fingerprint** (Android), **WebAuthn** (cross-platform).
- **Root/jailbreak detection** (детект root/jailbreak) — **SafetyNet** (Android), **DeviceCheck** (iOS), **Tinker** (Android).

**Вопросы**: «React Native vs Flutter vs native — trade-offs?» → **Ответ**: «**React Native** (JS, bridge, cross-platform, ecosystem), **Flutter** (Dart, Skia, performance, consistency), **Native** (Swift/Kotlin, performance, native features). **Use case**: **Wix** (React Native, cross-platform), **Checkpoint** (Flutter, performance), **Mobileye** (Native, AR/VR)».

**Пример ответа на интервью**: «В прошлой компании (Israel) мы разработали **mobile app**. **React Native** (Wix, cross-platform, JS, bridge), **Flutter** (Checkpoint, performance, Dart, Skia), **Native** (Mobileye, AR/VR, Swift/Kotlin). **Security**: **code obfuscation** (ProGuard, Bitcode), **secure storage** (Keychain, Keystore, AES-256), **biometric auth** (Touch ID, Fingerprint, WebAuthn), **root/jailbreak detection** (SafetyNet, DeviceCheck). **Result**: **cross-platform** (React Native, Flutter), **native** (Mobileye, AR/VR), **secure** (obfuscation, secure storage, biometric)».

### 5. Data-intensive: warehouse, lake, ETL/ELT, real-time analytics

**Data warehouse** (хранилище данных):
- **Redshift** (AWS, columnar, MPP) — **10× faster** (чем vanilla PostgreSQL), **columnar storage** (колонное), **Spectrum** (querying Parquet в S3).
- **BigQuery** (GCP, serverless, columnar) — **petabyte-scale**, **no infrastructure** (serverless), **pricing** (pay per query).
- **Snowflake** (multi-cloud, columnar) — **separation** (storage, compute, cloud), **scale** (independently), **pricing** (pay per usage).

**Data lake** (озеро данных):
- **S3** (AWS, object storage) — **raw data** (сырые данные: logs, events, files), **Parquet** (columnar, compressed), **schema-on-read** (схема при чтении).
- **ADLS** (Azure Data Lake Storage, Azure) — **hierarchical** (иерархический), **security** (RBAC, encryption).
- **GCS** (Google Cloud Storage, GCP) — **unified** (один storage для всего), **tiered** (Standard, Nearline, Coldline, Archive).

**ETL/ELT** (Extract-Transform-Load / Extract-Load-Transform):
- **ETL** (Transform в middle) — **Extract** (из источников), **Transform** (преобразование, в staging), **Load** (в warehouse). **Use case**: **complex transform** (агрегации, дедупликация).
- **ELT** (Transform в warehouse) — **Extract** (из источников), **Load** (в warehouse, raw), **Transform** (в warehouse, SQL). **Use case**: **fast load** (raw data), **flexible** (transform в warehouse).
- **Airflow** (workflow orchestration) — **DAG** (Directed Acyclic Graph), **tasks** (ETL/ELT jobs), **scheduling** (cron), **monitoring** (alerts).
- **dbt** (data build tool) — **SQL** (transform, SQL-запросы), **tests** (проверка данных), **docs** (документация), **models** (модели данных).

**Real-time analytics** (аналитика в реальном времени):
- **ClickHouse** (columnar, OLAP) — **fast** (10× faster), **dashboard** (metrics, latency, error rate), **alerting** (threshold, anomaly).
- **Druid** (columnar, OLAP) — **real-time** (ingest, query), **rollups** (pre-aggregation), **ingestion** (Kafka, S3).

**Вопросы**: «Как настроить data warehouse?» → **Ответ**: «**Redshift** (AWS, columnar, MPP) или **BigQuery** (GCP, serverless), **S3** (data lake, raw data), **Airflow** (ETL/ELT orchestration), **dbt** (transform, SQL, tests). **Use case**: **Redshift** (AWS, complex), **BigQuery** (GCP, serverless)».

**Пример ответа на интервью**: «В прошлой компании (Israel) мы настроили **data-intensive** architecture. **Warehouse**: **Redshift** (AWS, columnar, MPP), **data lake**: **S3** (raw data, Parquet), **ETL/ELT**: **Airflow** (orchestration, DAG), **dbt** (transform, SQL, tests). **Real-time analytics**: **ClickHouse** (columnar, 10× faster), **Kafka** (stream, real-time). **Result**: **data warehouse** (Redshift, 10× faster), **data lake** (S3, raw data), **ETL/ELT** (Airflow, dbt), **real-time analytics** (ClickHouse, < 5 сек)».
