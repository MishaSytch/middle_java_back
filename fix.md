# План правки interview.md — только теория

## Часть A. Усиление существующих блоков до 10/10

### 1. Базы данных / SQL / PostgreSQL
Добавить вопросы:
- LATERAL JOIN: семантика, отличие от обычного JOIN, сценарии применения
- CTE: `MATERIALIZED` vs `NOT MATERIALIZED`, рекурсивные CTE
- Специализированные индексы: GiST, GIN, BRIN — когда какой применять
- Partial indexes и expression indexes
- `CREATE INDEX CONCURRENTLY` — как работает, почему без блокировок
- Partitioning: range/list/hash, partition pruning, `UPDATE`/`DELETE` на партициях
- Репликация: streaming vs logical, failover, synchronous_commit
- Bloat: причины, диагностика (`pg_stat_user_tables`), `VACUUM FULL` vs `REINDEX`
- JSONB: операторы `@>`, `?`, `jsonb_path_query`, GIN-индексы для JSONB
- `pg_stat_statements` — диагностика медленных запросов
- Connection pooling: PgBouncer, режимы `session`/`transaction`/`statement`

### 2. Паттерны проектирования
Добавить вопросы:
- CQRS: суть, разделение write/read моделей, trade-offs
- Event Sourcing: event store, projections, snapshots, compaction
- Outbox Pattern: гарантированная публикация событий, polling publisher vs CDC
- Saga: оркестрация vs хореография, compensating transactions
- DDD tactical patterns: Aggregate, Entity, Value Object, Domain Event, Domain Service
- Anti-Corruption Layer: назначение, отличие от Adapter
- Strangler Fig: стратегия миграции монолита
- Bulkhead pattern: изоляция ресурсов
- Circuit Breaker: состояния, метрики, конфигурация
- Specifcation pattern: композиция бизнес-правил
- Identity Map: связь с Unit of Work

### 3. Память и Garbage Collection
Добавить вопросы:
- JFR (Java Flight Recorder): события, recording, анализ в production
- async-profiler: CPU/allocation/lock profiling, flame graphs
- Memory leak patterns: ThreadLocal в пуле потоков, listeners, classloader leaks, unclosed resources
- Pinning виртуальных потоков: причины, диагностика, `ScopedValues`
- Off-heap memory: DirectByteBuffer, `Unsafe`, Foreign Function & Memory API (Java 22+)
- Native Memory Tracking: `-XX:NativeMemoryTracking=summary`
- GC tuning: `-XX:+UseStringDeduplication`, `-XX:MaxGCPauseMillis`, `-XX:G1HeapRegionSize`
- ZGC Generational mode (Java 21)
- Safe publication и `final` семантика в JMM

### 5. Spring / Spring Boot
Добавить вопросы:
- BeanFactory vs ApplicationContext — различия
- `BeanDefinitionRegistryPostProcessor` и `BeanFactoryPostProcessor`
- Environment abstraction, PropertySource, `@PropertySource`
- AOP глубже: pointcut expressions, `@Around` vs `@Before`/`@After`, порядок аспектов (`@Order`)
- JDK proxy vs CGLIB — когда какой выбирается
- Spring Boot 3 AOT processing и GraalVM Native Image
- `@ImportRuntimeHints` и reflection hints
- `@ConditionalOnProperty`, `@ConditionalOnMissingBean`, custom conditions
- Spring Modulith: модульная архитектура, verification
- Observation API, Micrometer, `@Observed`
- Virtual threads интеграция в Spring Boot 3.2+

### 9. Многопоточность
Добавить вопросы:
- Virtual Threads pinning: `synchronized`, native calls, thread-local buffers
- Carrier threads и планировщик виртуальных потоков
- Structured Concurrency: `StructuredTaskScope`, `ScopedValues` (Java 21+)
- `StampedLock` vs `ReentrantReadWriteLock` — различия, optimistic read
- Lock-free структуры: `ConcurrentLinkedQueue`, `ConcurrentSkipListMap`
- Java Memory Model: happens-before правила детально, `final` и safe publication
- `volatile` семантика: visibility + ordering, но не atomicity
- `Flow.Publisher` (Java 9+ Reactive Streams)
- ForkJoinPool work-stealing алгоритм детально

### 14. Docker / Kubernetes
Добавить вопросы:
- Multi-stage build оптимизация, distroless images, layer caching strategies
- QoS-классы подов: Guaranteed/Burstable/BestEffort, влияние на eviction
- Resource management: `requests` vs `limits`, OOMKilled
- CNI (Calico, Cilium) — основы
- NetworkPolicy — изоляция трафика между подами
- Service Mesh: Istio/Linkerd — назначение, sidecar-паттерн, mTLS
- PV/PVC, StorageClass, StatefulSet с persistent volumes
- Pod Security Standards, RBAC, ServiceAccount, Secrets management
- HPA на кастомных метриках, PDB (PodDisruptionBudget)
- Graceful shutdown: preStop hooks, `terminationGracePeriodSeconds`
- GitOps: ArgoCD, Flux — принципы, отличие от CI/CD
- Helm vs Kustomize — trade-offs

### 17. Микросервисы
Добавить вопросы:
- DDD стратегически: Bounded Contexts, Context Mapping (Partnership/Shared Kernel/Customer-Supplier)
- Distributed locks: Redis/ZooKeeper/etcd, алгоритмы, fencing tokens
- API Composition pattern
- Materialized views для CQRS
- Eventual consistency vs causal consistency, CRDT
- SLO/SLI/SLA: определения, error budgets
- OpenTelemetry: traces, metrics, logs correlation
- Idempotency keys: реализация, хранение
- Saga state machine vs choreography — trade-offs
- Multi-tenancy: schema-per-tenant, row-level security, discriminator

### 21. Тестирование
Добавить вопросы:
- JMH-бенчмарки: `@Benchmark`, `@State`, warmup, dead code elimination
- Contract testing: Pact, Spring Cloud Contract — принципы
- Mutation testing: PIT (Pitest), mutation score
- Property-based testing: jqwik
- Performance testing: Gatling, k6
- Awaitsility для async-тестов
- Diff coverage в CI
- Testcontainers модульные fixtures

### 25. Spring Security
Добавить вопросы:
- OAuth2 flows детально: Authorization Code + PKCE, Client Credentials, Device Code
- Refresh Token Rotation
- Token Introspection vs JWT self-contained
- JWT: JWS vs JWE, key rotation, JWKS endpoint
- Token revocation strategies: blacklist vs short TTL + refresh
- Method Security: `@PreAuthorize` с SpEL, custom `PermissionEvaluator`, `@PostFilter`
- CSRF глубже: SameSite cookies, `CsrfTokenRequestHandler`, BREACH-защита
- Security Headers: CSP, X-Frame-Options, HSTS, Permissions-Policy
- mTLS в Spring Boot: настройка, certificate validation
- OWASP Top 10: применение к Spring-приложениям
- Session fixation, session hijacking — защита
- Password storage: Argon2, SCrypt, rehash on login
- Security events и аудит

### 28. CI/CD
Добавить вопросы:
- Security in CI: SAST (SonarQube, Semgrep), DAST (OWASP ZAP), SCA (Snyk, Dependabot)
- Container scanning: Trivy, Grype
- Reusable workflows, composite actions в GitHub Actions
- OIDC для cloud (AWS/GCP) — без long-lived credentials
- Argo Rollouts: canary/analysis, автоматический откат
- Feature flags: LaunchDarkly, Unleash, интеграция с CI/CD
- Preview environments per PR, ephemeral environments
- Supply chain security: SBOM (CycloneDX, SPDX), Sigstore/cosign, reproducible builds

### 29. Linux
Добавить вопросы:
- `sysctl` tuning: TCP-стек, file descriptors, `somaxconn`
- `ulimit` — soft vs hard limits
- `strace`, `ltrace` — диагностика Java-приложений
- `perf`, `bpftrace`, eBPF basics
- Containers internals: namespaces, cgroups, overlayfs
- Systemd deep dive: timers, path units, socket activation, `systemd-analyze`
- `tcpdump`, `iptables`/`nftables` продвинуто
- OOM score: как ядро выбирает жертву

---

## Часть B. Новые блоки (полностью отсутствуют в файле)

### 30. Реактивное программирование (WebFlux + Reactor)
- Project Reactor: `Mono`, `Flux`, backpressure стратегии
- Schedulers: `parallel`, `boundedElastic`, `single`, `immediate`
- `Context` в Reactor: передача данных через цепочку
- Spring WebFlux: `@RestController` reactive, `WebClient`, `RouterFunction`
- R2DBC: реактивный доступ к БД, отличие от JDBC
- Virtual Threads vs Reactive — когда что выбирать (актуальный холивар 2026)
- RSocket: реактивный RPC, протокол
- Backpressure: `onBackpressureBuffer/Drop/Latest`, стратегии
- Error handling в реактивных цепочках: `onErrorResume`, `onErrorReturn`, `retryWhen`
- Testing реактивного кода: `StepVerifier`

### 31. Observability & Monitoring
- Три столпа observability: traces, metrics, logs
- OpenTelemetry: SDK, Collector, контекст и пропагация
- Prometheus: Pull-модель, PromQL, recording rules, alerting rules
- Distributed tracing: Jaeger/Tempo, trace propagation (W3C Trace Context), sampling
- Micrometer: registry, custom meters, таймеры, distribution summary
- RED-методология (Rate, Errors, Duration) и USE-методология (Utilization, Saturation, Errors)
- Log aggregation: ELK/Loki, structured logging, MDC
- SLO/SLI/SLA: определения, error budgets
- Alerting стратегии: symptoms vs causes, alert fatigue

### 32. Production Debugging
- JFR: recording, events, analysis в production
- async-profiler: CPU, allocation, lock profiling, flame graphs
- Arthas: production Java diagnostic tool
- Heap dump analysis: Eclipse MAT, OQL, Dominator Tree, Path to GC Roots
- Thread dump analysis: deadlocks, pinning, blocked threads
- `jcmd`, `jmap`, `jstack` — практическое применение
- Low-level: `strace` для Java, `perf` для JIT-компиляции
- Production-ready logging: structured logs, correlation IDs, log levels strategy

### 33. System Design
- Design case studies: URL shortener, rate limiter, news feed, chat system
- Scalability patterns: horizontal scaling, sharding strategies, consistent hashing
- Availability: SLA/SLO/SLI, error budgets, multi-region deployment
- Trade-offs: latency vs throughput, consistency vs availability (PACELC theorem)
- CAP-теорема и её практические следствия
- Load balancing algorithms: round-robin, least connections, consistent hashing
- Caching strategies: cache-aside, write-through, write-behind, cache stampede
- Message queues: выбор между Kafka, RabbitMQ, Pulsar
- Database selection: OLTP vs OLAP, NewSQL
- Rate limiting: token bucket, sliding window, distributed rate limiting

### 34. Cloud-Native Java
- GraalVM Native Image: AOT-компиляция, ограничения, Spring Boot 3 support
- Quarkus vs Spring Boot: trade-offs, dev mode, extension model
- Micronaut: особенности, compile-time DI
- Serverless Java: AWS Lambda, cold start optimization, SnapStart
- FinOps: cost optimization, right-sizing, spot instances
- 12-Factor App методология
- Cloud providers: AWS/Azure/GCP — базовые сервисы для Java-разработчика
- Infrastructure as Code: Terraform basics для Java-разработчика

### 35. Database Migrations
- Flyway: migrations, callbacks, multi-module, versioning strategy
- Liquibase: changelog formats (XML/YAML/SQL/JSON), diff generation
- Zero-downtime migrations: expand-contract pattern
- Backwards-compatible schema changes
- Schema versioning для микросервисов
- Rollback strategies и их ограничения
- Migration testing
- Feature toggles для миграций данных

### 36. Performance Engineering
- JMH: microbenchmarking, `@Benchmark`, `@State`, `@Measurement`, `@Fork`
- Типичные ошибки бенчмаркинга: JIT warmup, dead code elimination, constant folding
- Load testing: Gatling, k6, JMeter — когда что
- Profiling workflow: identify → measure → optimize → verify
- JVM tuning: ergonomics, adaptive sizing, GC selection
- Database performance: query optimization, connection pooling, indexing strategies
- Network performance: compression, batching, connection reuse
- Memory optimization: object pooling, primitive collections, off-heap

### 37. API Design & Documentation
- OpenAPI 3.1: спецификация, генерация кода, validation
- AsyncAPI для event-driven API
- gRPC + Protobuf: контракт, code generation, streaming
- GraphQL vs REST vs gRPC — trade-offs
- API versioning strategies: URI, header, consumer-driven
- HATEOAS: принципы, реализация в Spring
- API gateway patterns: routing, rate limiting, transformation
- Contract testing: Pact, Spring Cloud Contract
- API evolution: backwards compatibility, deprecation strategies

### 38. AI/LLM Integration (актуально для 2026)
- Spring AI: интеграция с OpenAI, Anthropic, Ollama
- Vector databases: pgvector, Milvus, Weaviate
- RAG (Retrieval-Augmented Generation) pattern
- Function calling / tool use с LLM
- Streaming responses: SSE, WebFlux для LLM streams
- Embeddings и семантический поиск
- Prompt engineering для Java-разработчиков
- Guardrails и safety в AI-приложениях

### 39. Kotlin Interop (для Java-разработчика)
- Kotlin для Java-разработчиков: null-safety, data classes, extension functions
- Interop: вызов Java из Kotlin и наоборот
- `@JvmOverloads`, `@JvmStatic`, `@JvmField`
- Kotlin coroutines vs Java Virtual Threads
- Kotlin + Spring: `kotlin-spring` plugin, coroutine support
- Sealed classes в Kotlin vs Java
- Когда выбирать Kotlin vs Java в 2026

### 40. Supply Chain Security
- SBOM (Software Bill of Materials): CycloneDX, SPDX
- Sigstore/cosign: signing container images
- Reproducible builds: проверка идентичности сборок
- Dependency verification: Gradle verification metadata, Maven locked modes
- Vulnerability scanning: Snyk, Dependabot, OWASP Dependency-Check
- CVE management: prioritization, patching strategy
- Build provenance и SLSA framework

### 41. Legacy Modernization
- Monolith to microservices: Strangler Fig, Branch by Abstraction
- Database migration: от shared DB к database-per-service
- Big Ball of Mud refactoring: strategies
- Anti-Corruption Layer при интеграции с legacy
- Incremental migration vs big-bang rewrite
- Characterization tests для legacy-кода
- Domain extraction из монолита

---

## Часть C. Приоритизация правок

**Критично (закрывает 40%+ вакансий Middle+/Senior):**
1. Блок 30 — Реактивное программирование
2. Блок 31 — Observability & Monitoring
3. Блок 32 — Production Debugging
4. Расширение блока 25 — Spring Security
5. Расширение блока 17 — Микросервисы (DDD, distributed patterns)

**Важно (сильный Middle/Senior differentiator):**
6. Блок 33 — System Design
7. Блок 34 — Cloud-Native Java
8. Блок 35 — Database Migrations
9. Блок 36 — Performance Engineering
10. Расширение блока 14 — Docker/Kubernetes

**Актуально для 2026 (конкурентное преимущество):**
11. Блок 38 — AI/LLM Integration
12. Блок 37 — API Design & Documentation
13. Блок 39 — Kotlin Interop
14. Блок 40 — Supply Chain Security

**Опционально (бонусные баллы):**
15. Блок 41 — Legacy Modernization

---

## Оценка результата

После внесения всех правок:
- **Общий объём файла**: ~2.5x от текущего
- **Количество вопросов**: ~900-1000 (с текущих ~700)
- **Покрытие рынка 2026**: 95%+
- **Ожидаемая оценка подготовки**: 9.5-10/10
- **Целевая позиция**: Middle+ / Senior Java Developer