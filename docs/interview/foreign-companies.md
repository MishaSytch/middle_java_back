# Требования в иностранных компаниях (Middle/Middle+)

Раздел посвящён специфике собеседований в иностранных (глобальных) компаниях: US, EU, UK, Israel, Singapore и др. Вопросы разделены по странам/регионам, в скобках указана страна или группа стран.

> Ключевые отличия от локальных: **английский** (business level, не IELTS-формат, а живое интервью), **system design** (обязателен даже на middle), **coding** (2–3 задачи за 45–60 мин), **cultural fit / values** (отдельный раунд), **take-home** (в некоторых), **behavioural** (STAR-формат: Situation, Task, Action, Result).

## Общие ожидания для Middle/Middle+ в global-компаниях

### 1. [US] Что обязательно проверяют на Middle Java-интервью в US-компаниях

- **Раунды**: (1) **Recruiter screen** (20–30 мин, английский, мотивация, зарплата, visa status). (2) **Technical screen** (45–60 мин, 1 coding + лёгкий discussion). (3) **Hiring loop** (4–5 раундов по 45–60 мин: coding, system design, behavioural, team match). (4) **Final / Bar raiser** (один раунд, где bar raiser голосует «hire / no-hire» независимо от остальных).
- **Coding**: **2 задачи** на 60 мин (LeetCode Medium), **чистый код** (имена, типы, null-checks), **тестирование** своими словами или через unit tests, **edge cases** (пустые, null, overflow, Unicode).
- **System design**: **обязателен** на middle (в US-компаниях middle — это «самостоятельный разработчик с опытом 3–5 лет», который проектирует компоненты). Примеры: URL shortener, rate limiter, news feed, chat, file storage, API gateway.
- **Behavioural**: **STAR-формат** — Situation, Task, Action, Result. Вопросы: «Расскажи о конфликте с коллегой», «Пример, когда ты нарушил дедлайн», «Как ты влиял на архитектуру команды».
- **English**: **business level** (B2+). Интервьюер говорит на английском, ты отвечаешь на английском. Не требуется идеальный акцент, но **чёткость** и **терминология** (throughput, latency, idempotent, sharding).
- **Вопросы про visa**: «Do you require sponsorship now or in the future?» — **честный** ответ (H-1B, L-1, TN, O-1). Некоторые компании не спонсируют новичков, другие — спонсируют.
- **Compensation**: **base + bonus + RSU (stock)**. На middle в US: **$130–180K base** + **10–20% bonus** + **RSU $20–50K/year** (итого $180–300K). **Negotiation** — ожидаемо, Recruiter скажет range, ты отвечаешь своим range.
- **Bar raiser**: в Amazon — отдельная роль (Bar Raiser), голос «no-hire» блокирует оффер. В Google — **calibration** (сравнение с другими кандидатами того же уровня).
- **Culture fit / Values**: в Amazon — **Leadership Principles** (Own It, Bias for Action, Deliver Results, Dive Deep, Earn Trust, Insist on the Highest Standards, Think Big, Bias for Action, Have Backbone; Disagree and Commit, Frugality). В Google — **values** (focus on the user, move fast, be bold). Отдельный раунд, где interviewer спрашивает «Как ты проявил Leadership Principle X?».

### 2. [EU / UK] Особенности Middle Java-интервью в EU/UK-компаниях (Uber, Spotify, Revolut, Delivery Hero, Wise, Booking)

- **Раунды**: (1) **Recruiter call** (15–30 мин, английский, зарплата, location, remote policy). (2) **Technical interview** (45–60 мин, coding + discussion). (3) **System design** (45–60 мин, обязательный). (4) **Behavioural + culture** (30–45 мин, часто с Hiring Manager). (5) **Take-home** (в некоторых, 3–7 дней, реальный task).
- **Location / Remote**: EU-компании чаще **hybrid** (2–3 дня офис, 2–3 remote). **Wise**, **Revolut**, **Delivery Hero** — **remote-first** (можно жить в любой EU-стране, но часто требуют переезд в office city). **Spotify** — **hybrid** (office in Stockholm, London, Berlin). **Uber** — **hybrid** (office в Лондоне, Берлине, Милане).
- **Виза**: EU-компании **спонсируют** рабочую визу (EU Blue Card, UK Skilled Worker). **UK Skilled Worker** — требует **certified sponsor**, **salary threshold** (£26K+ для middle), **English B1** (IELTS 4.0). **EU Blue Card** — **высшее** + **оффер** (salary threshold зависит от страны, в Германии ~€45K).
- **Зарплата**: **London** middle Java: **£70–100K** + **bonus 10–20%** + **options** (в UK RSU). **Berlin** middle Java: **€60–85K** + **bonus**. **Stockholm** (Spotify): **SEK 550–750K/year** (~€50–70K). **Remote EU** (Wise, Revolut): **London-составляющая** (£70–110K), можно жить в любой EU.
- **Take-home**: в **Wise**, **Revolut**, **Delivery Hero** — **take-home** (3–7 дней), **реальный task** (например, «спроектируй REST API для payments» или «напиши service с тестами»). **Оценка**: код + дизайн + тесты + documentation. **Время**: не больше 20–30 часов (интервьюер спросит, сколько времени заняло).
- **System design**: **обязателен**, но **менее формализован** чем в US. Часто **whiteboard** (мелки или Miro), **рассуждение вслух** (thinking out loud), **trade-offs** (например, «Почему Kafka, а не RabbitMQ?»).
- **Behavioural**: **меньше формализован** чем в US, но **STAR** всё же используется. Вопросы: «Tell me about a time you disagreed with a teammate», «How do you handle ambiguity?».
- **Values**: в **Spotify** — **Squad model** (команды-«отряды», автономность, «Spotify model»). В **Wise** — **radical candor** (прямая обратная связь). В **Revolut** — **speed** (быстрые решения, минимум бюрократии).

### 3. [UK] Что специфично для London middle Java-интервью (Revolut, Wise, Monzo, Starling, Deliveroo, Booking)

- **Финтех**: **Revolut**, **Wise**, **Monzo**, **Starling** — **финтех**, **high load**, **strict security** (PCI-DSS, GDPR). Вопросы: «Как обработать idempotency в payments?», «Как хранить sensitive data?», «Как пройти PCI-DSS audit?».
- **System design**: **обязателен**, **financial-grade** (например, «Спроектируй payment gateway с 99.99% availability»). **Trade-offs**: **consistency vs availability** (CAP), **eventual consistency** (Kafka + outbox).
- **Coding**: **2 задачи** (LeetCode Medium), **Java** (часто требуют **Java 17+**, **records**, **sealed classes**, **text blocks**). **Test-driven** (напиши тесты к своей реализации).
- **Behavioural**: **Hiring Manager** (не Recruiter) ведёт последний раунд. Вопросы про **ambiguity**, **conflict**, **impact**. **STAR** обязателен.
- **Remote policy**: **hybrid** (2–3 дня офис в London, 2–3 remote). **Wise** — **remote-first** (можно жить в любой EU, но часто переезд в London для first 3–6 months). **Revolut** — **hybrid** (office в London, Canary Wharf).
- **Виза**: **UK Skilled Worker** (salary ≥ £26K, English B1, certified sponsor). **Processing**: 3–8 недель. **Cost**: **£719/year** (Immigration Health Surcharge) + **£1,000–2,000** (application). **Employer** часто **оплачивает** визу.
- **Зарплата**: **London** middle Java: **£70–100K** base + **10–20% bonus** + **options** (RSU, в UK «options» = право купить акции по фиксированной цене). **Take-home**: **£80–120K** total (base + bonus + options).
- **Culture**: **direct feedback** (прямая обратная связь, без «sandwich method»), **bias for action** (быстрые решения), **low hierarchy** (flat структура, инженер может спорить с Hiring Manager).

### 4. [Israel] Особенности Middle Java-интервью в Israel (Wix, Checkpoint, Mobileye, CyberArk, Payoneer)

- **Раунды**: (1) **Recruiter** (15–20 мин, английский). (2) **Technical** (60 мин, coding + CS fundamentals). (3) **System design** (45–60 мин). (4) **Behavioural + culture** (30–45 мин). (5) **Final with VP** (30 мин, для senior/middle+).
- **English**: **business level** (B2+), **терминология** (throughput, latency, idempotent). **Иврит** не требуется (компании работают на английском).
- **Coding**: **2 задачи** (LeetCode Medium), **CS fundamentals** (data structures, algorithms, complexity analysis). **Java** (часто **Java 11+**, **streams**, **CompletableFuture**).
- **System design**: **обязателен**, **scale** (10M+ users, 10K+ req/sec). Примеры: **URL shortener**, **rate limiter**, **file storage**, **API gateway**, **real-time chat**.
- **Culture**: **direct feedback** (очень прямая обратная связь, без «softening»), **low hierarchy** (flat структура, инженер может спорить с CTO), **bias for action** (быстрые решения). **Wix** — **flat**, **no titles** (все «engineers», нет senior/middle в названиях). **Checkpoint** — **military background** (много офицеров, «military-style» дисциплина, но flat иерархия).
- **Зарплата**: **Tel Aviv** middle Java: **$80–120K** base + **10–20% bonus** + **RSU/options** (в Wix, Checkpoint — **options**, в Mobileye — **RSU**). **Take-home**: **$100–150K** total.
- **Виза**: **Israel** — **B/1** (business visa, 90 дней) или **B/2** (work visa, 1–2 года). **No H-1B equivalent** (нет аналога H-1B, но есть **B/2** для работы). **Processing**: 2–4 недели. **Cost**: **$100–200** (application). **Employer** часто **оплачивает** визу и **flight**.
- **Relocation**: **Employer** часто **оплачивает** **переезд** (flight, housing, temporary apartment). **Wix**, **Checkpoint** — **relocation package** (flight + 1 month housing + $5–10K bonus).

### 5. [Singapore] Особенности Middle Java-интервью в Singapore (Grab, Sea, Shopee, NCS, Singtel)

- **Раунды**: (1) **Recruiter** (15–20 мин, английский, Chinese optional). (2) **Technical** (60 мин, coding). (3) **System design** (45–60 мин). (4) **Behavioural + culture** (30–45 мин). (5) **Final with Director** (30 мин).
- **English**: **business level** (B2+), **Chinese** (мандарин) **не требуется**, но **плюс** (особенно в **Grab**, **Sea**, **Shopee** — китайские founders).
- **Coding**: **2 задачи** (LeetCode Medium), **Java** (часто **Java 8+**, **streams**, **CompletableFuture**). **Test-driven** (напиши тесты).
- **System design**: **обязателен**, **scale** (10M+ users, SEA region: 10+ countries). Примеры: **payment gateway** (Grab, Sea), **ride-hailing** (Grab), **e-commerce** (Shopee), **real-time chat**.
- **Culture**: **Asian style** (более иерархичная, чем EU/US, но **flat** в tech-командах), **respect for seniors** (уважение к старшим), **indirect feedback** (обратная связь через «but…», «however…», не прямой критике). **Grab** — **bias for action** (быстрые решения, «move fast and break things»). **Sea** — **execution-focused** (акцент на исполнение, «get it done»).
- **Зарплата**: **Singapore** middle Java: **S$80–120K** base + **10–20% bonus** + **RSU** (в Grab, Sea — **RSU**, в NCS, Singtel — **bonus + options**). **Take-home**: **S$100–150K** total. **Note**: **Singapore** — **high tax** (15–22%), **no RSU tax** (RSU **exempt** от налога при продаже).
- **Виза**: **Employment Pass (EP)** — **salary ≥ S$4,500/month** (для middle), **degree** (высшее), **employer** должен быть **registered** в Singapore. **Processing**: 2–4 недели. **Cost**: **S$225** (application). **Employer** часто **оплачивает** визу. **Dependency Pass** (для spouse + kids) — **salary ≥ S$8,000/month**.
- **Relocation**: **Employer** часто **оплачивает** **flight** + **1 month housing** (temporary apartment). **Grab**, **Sea** — **relocation package** (flight + housing + **signing bonus** S$5–10K).

## Тематические требования (отдельные файлы)

Подробные вопросы и разбор по темам — в отдельных файлах:

### 6. [US] Облако и DevOps: AWS, GCP, Azure, Terraform, K8s

**→ [foreign-cloud-devops.md](foreign-cloud-devops.md)** — 6 вопросов с разбором: AWS-сервисы (EC2, S3, RDS, Lambda, DynamoDB, SQS, SNS, ECS, EKS, CloudFront, IAM, VPC, ELB, Route 53, CloudWatch, Kinesis, Aurora, Redshift, ElastiCache), multi-cloud (GCP, Azure), IaC (Terraform, CloudFormation, Pulumi, Ansible), CI/CD (GitHub Actions, GitLab CI, Jenkins, CircleCI, ArgoCD, Spinnaker), Kubernetes (Helm, Kustomize, HPA, VPA, NetworkPolicy, RBAC), Observability (Prometheus, Grafana, ELK, Jaeger, OpenTelemetry, Datadog).

### 7. [EU / UK] Compliance и security: GDPR, PCI-DSS, SOC 2, DORA, PSD2

**→ [foreign-compliance-security.md](foreign-compliance-security.md)** — 6 вопросов с разбором: GDPR (data subject rights, consent, data minimization, privacy by design, DPO, breach notification, cross-border transfer), PCI-DSS (12 requirements, CDE, PAN, encryption, tokenization), SOC 2 (Type I/II, trust services criteria, controls), DORA (ICT risk management, operational resilience, incident reporting, third-party risk, TLPT), PSD2 (SCA, open banking, transaction reporting, fraud prevention), security в архитектуре (zero trust, defense in depth, least privilege, RBAC vs ABAC, secret management, MFA, SSO).

### 8. [UK / EU] Финтех и payments: idempotency, Saga, event-driven, real-time

**→ [foreign-fintech-payments.md](foreign-fintech-payments.md)** — 4 вопроса с разбором: payments architecture (idempotency, distributed transactions, fraud detection, chargebacks, multi-currency), event-driven architecture (Kafka, event sourcing, CQRS, outbox pattern, Kafka vs RabbitMQ), real-time processing (stream processing, real-time analytics, notifications), scalability и HA (sharding, replication, multi-AZ, multi-region, RPO/RTO).

### 9. [Israel] Real-time, scale, security, mobile, data-intensive

**→ [foreign-realtime-scale.md](foreign-realtime-scale.md)** — 5 вопросов с разбором: real-time systems (collaboration, gaming, analytics, notifications), scale (10M+ users, 10K+ req/sec, sharding, replication, CDN, caching), security (zero trust, RBAC vs ABAC, secret management), mobile (React Native vs Flutter vs native, mobile security), data-intensive (warehouse, lake, ETL/ELT, real-time analytics).

### 10. [Singapore] SEA и multi-country: e-commerce, ride-hailing, logistics, fintech

**→ [foreign-sea-multicountry.md](foreign-sea-multicountry.md)** — 5 вопросов с разбором: multi-country (10+ стран SEA, local regulations, payment methods, localization), e-commerce (product catalog, search, recommendation, inventory, order management), ride-hailing (real-time matching, GPS tracking, dynamic pricing, routing, safety), logistics (route optimization, warehouse management, last-mile delivery, cold chain), fintech (e-wallet, P2P transfer, merchant payment, lending, insurance).

## System Design в иностранных компаниях

### 11. [US] Какие system design задачи чаще всего задают в US-компаниях на middle

- **URL Shortener** (TinyURL, Bitly) — **read-heavy** (99% GET), **Base62** code generation, **Redis** cache (code → url), **replica** + **CDN** для scale.
- **Rate Limiter** (API Gateway, Stripe) — **Token Bucket** или **Sliding Window**, **Redis** (INCR + EXPIRE), **per-user** (100 req/min), **per-IP** (1000 req/min), **429** + **Retry-After**.
- **News Feed** (Twitter, Facebook) — **fan-out** (write-time для low-follower, read-time для high-follower), **sharding** по user_id, **Redis** (кэш последних постов), **Elasticsearch** (поиск).
- **Chat System** (WhatsApp, Telegram) — **WebSocket** / **SSE** (real-time), **sticky sessions** (stateful), **at-least-once** + **idempotency** (message_id), **PostgreSQL** (шардирование по conversation_id), **S3** (медиа).
- **File Storage** (Dropbox, Google Drive) — **S3** (объектное хранилище), **sharding** по file_id, **CDN** (кэш), **versioning** (версии файлов), **compression** (сжатие), **deduplication** (дедупликация).
- **API Gateway** (Stripe, Shopify) — **rate limiting**, **auth** (JWT, OAuth2), **routing** (path → service), **caching** (Redis), **logging** (structured logs), **monitoring** (Prometheus + Grafana).
- **Payment Gateway** (Stripe, PayPal) — **idempotency** (idempotency key), **eventual consistency** (Kafka + outbox), **PCI-DSS** (secure storage), **fraud detection** (ML модель), **chargebacks** (возвраты).
- **Real-time Collaboration** (Google Docs, Figma) — **CRDT** (Conflict-free Replicated Data Types) или **OT** (Operational Transformation), **WebSocket** (long-lived connections), **Redis** (state), **PostgreSQL** (persist).
- **Search Engine** (Elasticsearch, Algolia) — **inverted index** (инвертированный индекс), **sharding** (по документу), **replication** (для HA), **analyzers** (токенизация, stemming), **query DSL** (JSON-запросы).
- **Recommendation System** (Netflix, Spotify) — **collaborative filtering** (похожие пользователи), **content-based** (по фичам), **hybrid** (комбинация), **batch** (пересчёт ночью) + **real-time** (Kafka → ML модель).

### 12. [EU / UK] System design в EU/UK-компаниях: особенности (Wise, Revolut, Spotify, Booking)

- **Financial-grade** (Wise, Revolut): **consistency** > **availability** (CAP: **CP** система), **eventual consistency** (Kafka + outbox), **idempotency** (idempotency key в API), **audit log** (каждая операция записывается).
- **Scale** (Booking, Spotify): **10M+ users**, **10K+ req/sec**, **multi-region** (EU, US, APAC). **Sharding** по user_id, **replication** (для HA), **CDN** (кэш static content).
- **Whiteboard** (Miro, мелки): **рассуждение вслух** (thinking out loud), **trade-offs** («Почему Kafka, а не RabbitMQ?»), **estimation** («Сколько будет req/sec?»). **Интервьюер** не ждёт **идеального** решения, ждёт **логичных** рассуждений.
- **Follow-up questions** (после основного решения): «А как масштабировать на 10×?», «А как добавить real-time?», «А как обработать failure?», «А как сделать audit log?».
- **Common mistakes**: (1) **Не оценивать load** (req/sec, data size). (2) **Не говорить trade-offs** (только «лучшее» решение). (3) **Забыть** про **caching** (Redis) и **CDN**. (4) **Не обработать** **failure** (retry, circuit breaker, fallback). (5) **Не упомянуть** **security** (auth, encryption, PCI-DSS).

## Coding в иностранных компаниях

### 13. [US] Какие coding задачи чаще всего задают в US-компаниях на middle

- **Arrays / Two Pointers**: «Two Sum», «3Sum», «Container With Most Water», «Trapping Rain Water».
- **Hashing / Frequencies**: «Valid Anagram», «Group Anagrams», «Top K Frequent Elements», «Subarray Sum Equals K».
- **Strings / Sliding Window**: «Longest Substring Without Repeating Characters», «Minimum Window Substring», «String to Integer (atoi)».
- **Sorting / Binary Search**: «Search in Rotated Sorted Array», «Median of Two Sorted Arrays», «Kth Largest Element».
- **Stacks / Queues**: «Valid Parentheses», «Min Stack», «Design Circular Queue», «Evaluate Reverse Polish Notation».
- **Linked Lists**: «Reverse Linked List», «Detect Cycle», «Merge K Sorted Lists», «LRU Cache».
- **Trees / BST**: «Invert Binary Tree», «Validate BST», «Lowest Common Ancestor», «Serialize/Deserialize Binary Tree».
- **Graphs / BFS/DFS**: «Number of Islands», «Course Schedule», «Word Ladder», «Clone Graph».
- **Heaps / Top-K**: «Kth Largest Element in an Array», «Top K Frequent Elements», «Merge K Sorted Lists».
- **Dynamic Programming**: «Climbing Stairs», «Coin Change», «Longest Increasing Subsequence», «Edit Distance».

### 14. [EU / UK] Coding в EU/UK-компаниях: Java 17+ (records, sealed classes, text blocks, pattern matching)

- **Java 17+**: **records** (immutable DTO, `record Point(int x, int y) {}`), **sealed classes** (`sealed interface Shape permits Circle, Square`), **text blocks** (multi-line string, `"""..."""`), **pattern matching for switch** (`case Integer i -> ...`), **var** (type inference, `var list = new ArrayList<String>()`).
- **Streams**: `list.stream().filter(...).map(...).collect(...)`, **parallel streams** (`parallelStream()`, для CPU-bound tasks), **Collectors** (`toMap`, `groupingBy`, `joining`).
- **CompletableFuture**: `CompletableFuture.supplyAsync(...)`, `thenApply`, `thenCompose`, `allOf`, `anyOf`, **exception handling** (`exceptionally`, `handle`).
- **Concurrency**: **ExecutorService** (`newFixedThreadPool`, `newCachedThreadPool`), **ThreadPoolExecutor** (core size, max size, queue), **synchronized**, **ReentrantLock**, **ConcurrentHashMap**, **AtomicInteger**, **volatile**.
- **Testing**: **JUnit 5** (`@Test`, `@BeforeEach`, `@ParameterizedTest`), **Mockito** (`mock`, `when().thenReturn()`, `verify()`), **AssertJ** (`assertThat(...).isEqualTo(...)`), **Testcontainers** (`@Testcontainers`, `@Container` для Postgres, Redis, Kafka).

## Behavioural в иностранных компаниях

### 15. [US] Behavioural interview в US-компаниях: STAR-формат (Amazon Leadership Principles, Google Values)

- **STAR-формат**: **S**ituation (контекст, «В прошлой компании…»), **T**ask (задача, «Мне нужно было…»), **A**ction (что ты сделал, «Я…»), **R**esult (результат, «В итоге…»). **Всегда** используй STAR для каждого вопроса.
- **Amazon Leadership Principles** (14): **Customer Obsession** (клиент — центр), **Ownership** (владелец, не «это не моя зона»), **Bias for Action** (быстрые решения), **Simplicity** (простота), **Hiring and Developing the Best** (найм и развитие), **Insist on the Highest Standards** (высокие стандарты), **Think Big** (большие цели), **Dive Deep** (углубление), **Have Backbone; Disagree and Commit** (иметь позицию, спорить, но принять решение), **Deliver Results** (результат), **Frugality** (фрукальность), **Earn Trust** (заработать доверие), **Strive to be Earth's Best Employer** (лучший работодатель). **Вопросы**: «Tell me about a time you demonstrated Customer Obsession», «How did you show Bias for Action?».
- **Google Values** (focus on the user, move fast, be bold): **Вопросы**: «Tell me about a time you focused on the user», «How did you move fast?», «Tell me about a bold decision you made».
- **Common questions**: (1) «Tell me about a time you disagreed with a teammate». (2) «How do you handle ambiguity?». (3) «Tell me about a time you failed». (4) «How do you prioritize?». (5) «Tell me about a time you influenced a decision».
- **Tips**: (1) **Конкретные примеры** (не общие слова). (2) **Числа** (результат в цифрах: «улучшили latency на 30%», «сэкономил $10K»). (3) **Не критикуй** прошлых коллег (говорь позитивно). (4) **Готовь 5–7 примеров** (конфликт, failure, success, ambiguity, leadership). (5) **Практикуй** вслух (запиши на диктофон, послушай, оцени время).

### 16. [EU / UK] Behavioural в EU/UK-компаниях: direct feedback, low hierarchy (Wise, Revolut, Spotify)

- **Direct feedback**: в EU/UK **прямая** обратная связь (без «sandwich method» — «хорошо, но…», «плохо»). **Вопросы**: «Tell me about a time you gave direct feedback to a teammate», «How do you handle receiving direct feedback?».
- **Low hierarchy**: **flat** структура, инженер может спорить с Hiring Manager. **Вопросы**: «Tell me about a time you disagreed with your manager», «How do you influence decisions in a flat organization?».
- **Ambiguity**: в EU/UK **ambiguity** — нормальная часть работы (не все задачи чётко сформулированы). **Вопросы**: «How do you handle ambiguity?», «Tell me about a time you had to make a decision without all the information».
- **Teamwork**: **collaboration** (сотрудничество) важнее **individual achievement** (личные достижения). **Вопросы**: «Tell me about a time you helped a teammate», «How do you balance individual work and team work?».
- **Common mistakes**: (1) **Too humble** (слишком скромный, «я просто делал свою работу»). (2) **Blame others** (винить других). (3) **No numbers** (без цифр в результате). (4) **Generic examples** (общие примеры, не конкретные). (5) **Too short** (слишком короткие ответы, < 2 минут).

## Visa / Relocation в иностранных компаниях

### 17. [US] US Work Visa: H-1B, L-1, O-1, TN, E-2 (что спрашивают на интервью)

- **H-1B**: **specialty occupation** (специальная профессия, requires bachelor's+), **cap** (65K+ slots/year, lottery), **processing** (4–8 недель, premium 15 дней за $2,500), **cost** ($1,000–3,000 employer + $460 employee), **validity** (3 years, extendable to 6), **portability** (можно сменить employer, H-1B follows you). **Вопросы**: «Do you have H-1B?», «Do you require sponsorship?», «Are you eligible for H-1B cap exemption?».
- **L-1**: **intracompany transfer** (переезд внутри компании, L-1A = manager, L-1B = specialized knowledge), **no cap**, **processing** (2–4 weeks), **cost** ($500–1,000 employer), **validity** (1 year, extendable to 7 for L-1A, 5 for L-1B). **Вопросы**: «Have you worked for the same company abroad?», «Are you transferring within the company?».
- **O-1**: **extraordinary ability** (выдающиеся способности, для тех, кто «в топе» в своей области), **no cap**, **processing** (2–4 weeks), **cost** ($500–1,000 employer), **validity** (3 years, extendable). **Criteria**: publications, awards, high salary, membership in exclusive organizations. **Вопросы**: «Have you published?», «Have you won awards?», «Are you in the top 10% of your field?».
- **TN**: **NAFTA/USMCA** (для граждан Canada, Mexico, только **specific occupations** — software engineer **не** входит в TN list, но **systems engineer** может), **processing** (1–2 weeks), **cost** ($100 employee), **validity** (3 years, extendable). **Вопросы**: «Are you a citizen of Canada or Mexico?», «Do you have a TN-eligible profession?».
- **E-2**: **treaty investor** (для граждан treaty countries, investment $100K+), **no cap**, **processing** (2–4 weeks), **cost** ($1,000–2,000 employer), **validity** (5 years, extendable). **Вопросы**: «Have you invested in a US business?».
- **Common questions**: (1) «Do you require visa sponsorship now or in the future?» — **честный** ответ. (2) «What visa do you have?», (3) «Are you eligible for H-1B cap exemption?», (4) «Do you have a master's degree? (cap-exempt if from US university)».

### 18. [EU / UK] EU Blue Card, UK Skilled Worker: требования и процесс (Revolut, Wise, Spotify)

- **EU Blue Card**: **высшее** (bachelor's+), **оффер** (salary threshold зависит от страны: Germany ~€45K, Netherlands ~€40K, France ~€38K), **processing** (2–8 weeks), **cost** (€100–300), **validity** (1–4 years, extendable). **Benefits**: **fast-track** (priority processing), **family reunification** (spouse + kids), **free access to labor market** (можно сменить employer). **Вопросы**: «Do you have a degree?», «What is your expected salary?», «Are you eligible for EU Blue Card?».
- **UK Skilled Worker**: **certified sponsor** (employer должен быть в UK Visas & Immigration list), **salary ≥ £26K** (для middle), **English B1** (IELTS 4.0, или degree в English-speaking country), **processing** (3–8 weeks), **cost** (£719/year IHS + £1,000–2,000 application), **validity** (up to 5 years, extendable). **Benefits**: **ILR** (Indefinite Leave to Remain) после 5 years, **family** (spouse + kids). **Вопросы**: «Do you have English B1?», «Do you have a certified sponsor?», «What is your expected salary?».
- **Relocation package**: **Employer** часто **оплачивает**: **flight** (round-trip), **housing** (1–3 months temporary apartment), **relocation bonus** (£5–10K), **visa cost** (application + IHS). **Wise**, **Revolut** — **generous** package. **Spotify** — **moderate** package.
- **Dependents**: **EU Blue Card** — **family reunification** (spouse + kids, no separate visa needed). **UK Skilled Worker** — **dependents** (spouse + kids, separate visa, £245–465 each, IHS £624/year each). **Вопросы**: «Do you have dependents?», «How many family members are relocating?».
- **Tax**: **EU** — **income tax** (15–45%, зависит от страны), **VAT** (20–25%). **UK** — **income tax** (20–45%), **NI** (National Insurance, 12%–2%). **Note**: **RSU/options** **exempt** от налога при продаже (в UK, EU). **Питание**: **tax-free** (обычно не облагается налогом).

## Зарплаты и компенсация в иностранных компаниях

### 19. [US] Compensation в US: base + bonus + RSU (как negotiating на middle)

- **Base**: **$130–180K** (middle), **$180–250K** (senior). **Bonus**: **10–20%** (middle), **20–30%** (senior). **RSU** (stock): **$20–50K/year** (middle), **$50–100K/year** (senior). **Total**: **$180–300K** (middle), **$250–400K** (senior).
- **Negotiation**: **Recruiter** скажет **range** (например, $150–170K base). **Ты** отвечаешь **своим range** (например, $170–190K base + $50K RSU). **Не называй** текущую зарплату (Recruiter может спросить, но ты можешь сказать «I'm open to discussing compensation based on the role and responsibilities»). **Лайфхак**: **спроси** про **RSU** и **bonus** (Recruiter часто говорит только base).
- **RSU (stock)**: **4-year vesting** (25% per year, 1-year cliff — первые 12 месяцев ничего, потом 25% сразу). **Tax**: **RSU** — **ordinary income** (облагается налогом при vesting), **options** — **capital gains** (облагается налогом при продаже). **409A** (оценка стоимости акций, для private companies). **Note**: **RSU** часто **exempt** от налога при продаже (но облагается при vesting).
- **Benefits**: **health insurance** ($100–300/month, employer pays 80–90%), **401(k)** (employer match 3–6%), **PTO** (15–25 days/year), **equity refresh** (каждые 1–2 года, новые RSU). **Note**: **health insurance** часто **exempt** от налога (pre-tax).
- **Common questions**: (1) «What is your current compensation?», (2) «What is your expected compensation?», (3) «Are you open to a lower base with higher RSU?», (4) «Do you have other offers?» (давление, чтобы ты быстрее согласился).

### 20. [EU / UK] Compensation в EU/UK: base + bonus + options (Wise, Revolut, Spotify, Booking)

- **London**: **£70–100K** base (middle), **£100–140K** (senior). **Bonus**: **10–20%** (middle), **20–30%** (senior). **Options** (UK «options» = право купить акции по фиксированной цене): **£20–50K/year** (middle), **£50–100K/year** (senior). **Total**: **£100–160K** (middle), **£150–250K** (senior).
- **Berlin**: **€60–85K** base (middle), **€85–120K** (senior). **Bonus**: **10–15%**. **Options**: **€15–40K/year** (middle). **Total**: **€80–130K** (middle).
- **Stockholm** (Spotify): **SEK 550–750K/year** (~€50–70K) base (middle). **Bonus**: **10–15%**. **Options**: **SEK 50–100K/year** (~€5–10K). **Total**: **SEK 650–900K/year** (~€60–80K).
- **Remote EU** (Wise, Revolut): **London-составляющая** (£70–110K base), можно жить в любой EU. **Note**: **Wise** платит **London salary**, но **tax** зависит от страны (если живёшь в Germany, платишь German tax).
- **Options (UK)**: **4-year vesting** (25% per year, 1-year cliff), **exercise price** (цена покупки, часто $0 или $0.01), **tax**: **options** — **capital gains** (облагается налогом при продаже). **Note**: **options** часто **exempt** от налога при продаже (но облагается при exercise).
- **Benefits**: **health insurance** (private, £100–300/month, employer pays), **pension** (employer contributes 3–10%), **PTO** (25–30 days/year), **flexible hours** (гибкий график). **Note**: **private health** часто **tax-free** (не облагается налогом).
- **Common questions**: (1) «What is your expected salary?», (2) «Are you open to a lower base with higher options?», (3) «Do you have other offers?», (4) «What is your notice period?» (обычно 1–3 months в UK, 2–6 weeks в EU).

## Take-home задачи в иностранных компаниях

### 21. [UK] Take-home в UK-компаниях (Wise, Revolut, Delivery Hero): что ожидать и как выполнять

- **Wise**: **take-home** (3–7 дней), **реальный task** (например, «спроектируй REST API для payments» или «напиши service с тестами»). **Оценка**: код + дизайн + тесты + documentation. **Время**: 20–30 часов. **Note**: **Wise** оценивает **clean code** (читаемость, имена, структура), **test coverage** (юнит-тесты), **documentation** (README, как запустить).
- **Revolut**: **take-home** (3–7 дней), **system design + coding** (например, «спроектируй и напиши service для rate limiter»). **Оценка**: код + design + tests + presentation (15–20 мин, интервьюер задаёт follow-up). **Время**: 20–30 часов. **Note**: **Revolut** оценивает **trade-offs** (почему выбрал Kafka, а не RabbitMQ), **edge cases** (как обработал failure), **presentation** (чёткость, confidence).
- **Delivery Hero**: **take-home** (3–5 дней), **coding + tests** (например, «напиши service для order processing»). **Оценка**: код + tests + README. **Время**: 15–20 часов. **Note**: **Delivery Hero** оценивает **clean code**, **test coverage**, **README** (как запустить).
- **Common mistakes**: (1) **Too much time** (> 30 часов, интервьюер спросит). (2) **No tests** (без юнит-тестов). (3) **No README** (без инструкции, как запустить). (4) **Over-engineering** (слишком сложное решение, «over-engineered»). (5) **No trade-offs** (не объяснил, почему выбрал этот подход).
- **Tips**: (1) **Планируй время** (20–30 часов, не больше). (2) **Пиши тесты** (юнит-тесты, coverage 80%+). (3) **Напиши README** (как запустить, что делает, как тестировать). (4) **Объясняй trade-offs** (почему выбрал Kafka, а не RabbitMQ). (5) **Не переусложняй** (простое решение лучше, чем сложное). (6) **Запуши на GitHub** (private repo, interviewer получает access).

## Культурные различия и советы

### 22. [US vs EU vs UK vs Israel vs Singapore] Культурные различия: как адаптироваться

- **US**: **direct feedback** (прямая обратная связь), **bias for action** (быстрые решения), **low hierarchy** (flat структура), **individual achievement** (личные достижения важны), **negotiation** (обязательно торговаться), **RSU** (stock — важная часть компенсации). **Совет**: **будь assertive** (уверенный), **говорь о достижениях** в цифрах, **торгуйся** за RSU.
- **EU**: **indirect feedback** (косвенная обратная связь, «but…», «however…»), **work-life balance** (важен баланс работы и жизни, 35–40 часов/неделю), **hierarchy** (более иерархичная, чем US, но **flat** в tech-командах), **teamwork** (сотрудничество важнее индивидуальных достижений), **PTO** (30–35 дней/год, можно использовать в любой момент). **Совет**: **не будь too aggressive** (не слишком агрессивный), **уважай work-life balance** (не работай по 60 часов), **сотрудничай** (помогай команде).
- **UK**: **direct feedback** (прямая обратная связь, но **polite** — «I think…», «Perhaps…»), **low hierarchy** (flat структура, инженер может спорить с Hiring Manager), **bias for action** (быстрые решения), **humor** (чутьё юмора важно, «dry humor»), **PTO** (25–30 дней/год). **Совет**: **будь polite** (вежливый), **используй humor** (чутьё юмора), **спорь** (но **respectfully** — с уважением).
- **Israel**: **very direct feedback** (очень прямая обратная связь, без «softening»), **low hierarchy** (flat структура, инженер может спорить с CTO), **bias for action** (быстрые решения), **military background** (много офицеров, «military-style» дисциплина, но flat иерархия), **no small talk** (мало «small talk», сразу к делу). **Совет**: **будь direct** (прямой), **не бойся спорить** (спорь, но **respectfully**), **не жди small talk** (иди сразу к делу).
- **Singapore**: **Asian style** (более иерархичная, чем EU/US, но **flat** в tech-командах), **respect for seniors** (уважение к старшим), **indirect feedback** (обратная связь через «but…», «however…», не прямой критике), **bias for action** (быстрые решения), **Chinese optional** (мандарин не требуется, но **плюс**). **Совет**: **уважай seniors** (уважай старших), **не будь too direct** (не слишком прямой), **используй «but…»** (мягкая обратная связь).
- **Common mistakes**: (1) **Too direct** в EU/UK/Singapore (слишком прямой, обидишь). (2) **Too indirect** в US/Israel (слишком косвенный, не поймут). (3) **Too aggressive** в EU/UK (слишком агрессивный, нарушишь work-life balance). (4) **Too passive** в US/Israel (слишком пассивный, не покажешь assertiveness). (5) **No humor** в UK (без чутья юмора, «dry humor» важен).
- **Tips**: (1) **Исследуй culture** компании (сайт, Glassdoor, Blind). (2) **Наблюдай** за командой (как дают feedback, как спорят, как работают). (3) **Адаптируйся** (меняй стиль под culture). (4) **Не копируй** (не копируй US-style в EU, или EU-style в US). (5) **Будь authentic** (будь собой, но адаптируй стиль).
