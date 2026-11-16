# Иностранные компании: SEA и Multi-country (Singapore, e-commerce, ride-hailing)

Раздел — тематический: multi-country архитектура (10+ стран SEA), e-commerce, ride-hailing, logistics, fintech (e-wallet), которые требуют в Singapore-компаниях (Grab, Sea, Shopee, NCS, Singtel). В US-компаниях multi-country менее строгий, в EU/UK — fintech-фокус, в Israel — real-time.

> Ключевое отличие от локальных: в Singapore-компаниях **multi-country** (10+ стран SEA, local regulations, localization), **e-commerce** (search, recommendation, inventory), **ride-hailing** (real-time matching, dynamic pricing) — **обязательны** на middle.

### 1. Multi-country: 10+ стран, local regulations, payment methods, localization

**SEA countries** (Юго-Восточная Азия, 10+ стран):
- **Indonesia** (Indonesia, 270M people, Bahasa Indonesia, IDR), **Thailand** (Thai, THB), **Vietnam** (Vietnamese, VND), **Philippines** (Filipino, PHP), **Malaysia** (Malay, MYR), **Singapore** (English, SGD), **Myanmar** (Burmese, MMK), **Cambodia** (Khmer, KHR), **Laos** (Lao, LAK), **Brunei** (Malay, BND).

**Local regulations** (локальные регуляции):
- **PDPA** (Personal Data Protection Act, Singapore) — **GDPR-like** (аналог GDPR), **consent** (явное согласие), **data minimization** (минимизация), **breach notification** (72 часа).
- **PDPD** (Personal Data Protection Act, Indonesia) — **local** (локальный), **consent** (явное согласие), **data localization** (данные должны храниться в Indonesia).
- **PDPA** (Personal Data Protection Act, Thailand) — **GDPR-like**, **consent**, **data minimization**.
- **Data residency** (резидентность данных) — **local** (данные должны храниться в локальной стране), **cross-border transfer** (передача за рубеж, нужно согласие).

**Local payment methods** (локальные методы оплаты):
- **E-wallet** (электронный кошелёк) — **GrabPay** (Grab), **GoPay** (Gojek, Indonesia), **OVO** (Indonesia), **ShopeePay** (Shopee), **GCash** (Philippines), **TrueMoney** (Thailand).
- **Bank transfer** (банковский перевод) — **local** (локальные банки), **RTGS** (Real-Time Gross Settlement), **FAST** (FAST transfer).
- **Cash** (наличные) — **COD** (Cash on Delivery, при доставке), **cash payment** (оплата наличными).
- **Card** (карта) — **Visa**, **Mastercard**, **local** (локальные карты, e.g. **BCA** в Indonesia).

**Localization** (локализация):
- **Language** (язык) — **English** (основной), **Bahasa Indonesia** (Indonesia), **Thai** (Thailand), **Vietnamese** (Vietnam), **Filipino** (Philippines), **Malay** (Malaysia).
- **Currency** (валюта) — **local** (локальная валюта), **FX rate** (курс обмена, real-time).
- **Date format** (формат даты) — **DD/MM/YYYY** (SEA), **MM/DD/YYYY** (US).
- **Number format** (формат числа) — **1,234,567.89** (US), **1.234.567,89** (EU).

**Вопросы**: «Как настроить multi-country payments?» → **Ответ**: «**Local payment methods** (e-wallet: GrabPay, GoPay, OVO; bank transfer: RTGS, FAST; cash: COD), **FX rate** (real-time, OANDA), **currency conversion** (rounding 2 decimals, BigDecimal), **local regulations** (PDPA, PDPD, data residency)».

**Пример ответа на интервью**: «В прошлой компании (Singapore, Grab) мы настроили **multi-country** architecture. **10+ стран SEA**: **local regulations** (PDPA, PDPD, data residency), **local payment methods** (e-wallet: GrabPay, GoPay, OVO; bank transfer: RTGS, FAST; cash: COD), **localization** (language: English, Bahasa, Thai, Vietnamese; currency: SGD, IDR, THB, VND; date format: DD/MM/YYYY). **FX rate**: **real-time** (OANDA), **currency conversion** (rounding 2 decimals, BigDecimal). **Result**: **10+ стран**, **local payment methods**, **localization**, **zero compliance issues** (PDPA, PDPD)».

### 2. E-commerce: product catalog, search, recommendation, inventory, order management

**Product catalog** (каталог товаров):
- **SKU** (Stock Keeping Unit) — **unique ID** (уникальный идентификатор товара), **millions** (миллионы SKU).
- **Attributes** (атрибуты) — **name** (название), **description** (описание), **price** (цена), **images** (изображения), **categories** (категории), **tags** (теги).
- **Storage** (хранилище) — **PostgreSQL** (relational, structured), **Elasticsearch** (full-text search), **S3** (images, videos).

**Search** (поиск):
- **Elasticsearch** (full-text search, JSON) — **inverted index** (инвертированный индекс), **analyzers** (токенизация, stemming), **query DSL** (JSON-запросы).
- **Typo tolerance** (устойчивость к опечаткам) — **fuzzy search** (размытый поиск, e.g. `appl` → `apple`), **ngram** (n-граммы, для prefix search).
- **Autocomplete** (автодополнение) — **suggest** (предложения, e.g. `app` → `apple`, `application`).
- **Filtering** (фильтрация) — **facets** (категории, цена, бренд), **aggregations** (агрегации, e.g. count по категориям).

**Recommendation** (рекомендации):
- **Collaborative filtering** (коллаборативная фильтрация) — **похожие пользователи** (user A купил X, user B купил X → рекомендую B Y), **matrix factorization** (SVD, ALS).
- **Content-based** (на основе контента) — **по фичам** (товар X имеет фичи A, B, C → рекомендую Y с фичами A, B, C).
- **Hybrid** (гибрид) — **комбинация** (collaborative + content-based, weights).
- **Real-time** (в реальном времени) — **Kafka** (event stream), **ML model** (real-time, < 1 сек), **personalization** (персонализация, < 100ms).

**Inventory** (склад):
- **Real-time** (в реальном времени) — **stock** (остаток), **reserved** (зарезервировано), **available** (доступно).
- **Multi-warehouse** (несколько складов) — **location** (локация), **stock per location** (остаток по каждой локации).
- **Sync** (синхронизация) — **Kafka** (event stream), **conflict resolution** (разрешение конфликтов, e.g. last-write-wins).

**Order management** (управление заказами):
- **Order lifecycle** (жизненный цикл заказа) — **created** (создан) → **paid** (оплачен) → **shipped** (отправлен) → **delivered** (доставлен) → **completed** (завершён).
- **Cancellation** (отмена) — **before shipped** (до отправки, можно отменить), **after shipped** (после отправки, только возврат).
- **Returns** (возвраты) — **return request** (запрос на возврат), **refund** (возврат денег), **restock** (возврат на склад).

**Payment** (оплата):
- **Multi-method** (несколько методов) — **card** (Visa, Mastercard), **e-wallet** (GrabPay, GoPay), **bank transfer** (RTGS, FAST), **cash** (COD).
- **Fraud detection** (предотвращение мошенничества) — **ML model** (accuracy 95%+, < 100ms), **rules** (velocity, geography, amount).

**Вопросы**: «Как настроить product search?» → **Ответ**: «**Elasticsearch** (full-text search, inverted index), **analyzers** (токенизация, stemming), **typo tolerance** (fuzzy search, ngram), **autocomplete** (suggest), **filtering** (facets, aggregations). **Use case**: **millions SKU**, **real-time** (< 100ms)».

**Пример ответа на интервью**: «В прошлой компании (Singapore, Shopee) мы настроили **e-commerce**. **Product catalog**: **millions SKU**, **PostgreSQL** (relational), **Elasticsearch** (search), **S3** (images). **Search**: **Elasticsearch** (inverted index, analyzers, typo tolerance, autocomplete, filtering). **Recommendation**: **collaborative filtering** (похожие пользователи), **content-based** (по фичам), **hybrid** (комбинация), **real-time** (Kafka, ML model, < 1 сек). **Inventory**: **real-time** (stock, reserved, available), **multi-warehouse** (location, stock per location), **sync** (Kafka, conflict resolution). **Order management**: **lifecycle** (created → paid → shipped → delivered → completed), **cancellation** (before/after shipped), **returns** (return request, refund, restock). **Payment**: **multi-method** (card, e-wallet, bank transfer, cash), **fraud detection** (ML model, < 100ms). **Result**: **millions SKU**, **real-time search** (< 100ms), **real-time recommendation** (< 1 сек), **real-time inventory** (zero oversell)».

### 3. Ride-hailing: real-time matching, GPS tracking, dynamic pricing, routing, safety

**Real-time matching** (сопоставление в реальном времени):
- **Driver-rider matching** (сопоставление водителя и пассажира) — **< 1 сек** (latency), **geography** (география, e.g. 5 km radius).
- **Algorithm** (алгоритм) — **nearest neighbor** (ближайший сосед), **greedy** (жадный, лучший в момент), **optimization** (оптимизация, e.g. min total distance).
- **Data** (данные) — **driver location** (GPS, real-time), **rider location** (GPS, real-time), **driver availability** (доступен/занят).

**GPS tracking** (отслеживание по GPS):
- **Real-time** (в реальном времени) — **WebSocket** (long-lived, binary), **frequency** (частота, e.g. 1 Hz = 1 сек).
- **Storage** (хранилище) — **in-memory** (Caffeine, Redis, TTL 1 час), **time-series** (InfluxDB, TimescaleDB).
- **Privacy** (приватность) — **anonymization** (анонимизация, e.g. last 4 цифры телефона), **retention** (хранение, e.g. 30 дней).

**Dynamic pricing** (динамическое ценообразование):
- **Surge pricing** (повышенная цена) — **demand > supply** (спрос > предложение), **multiplier** (множитель, e.g. 1.5×, 2×).
- **ML model** (модель машинного обучения) — **prediction** (прогноз, e.g. demand, supply), **optimization** (оптимизация, e.g. max revenue).
- **Fairness** (справедливость) — **transparency** (прозрачность, e.g. «surge 2× due to high demand»), **cap** (лимит, e.g. max 3×).

**Routing** (маршрутизация):
- **Shortest path** (кратчайший путь) — **Dijkstra** (алгоритм Дейкстры), **A*** (A-star, heuristic).
- **Traffic-aware** (с учётом трафика) — **real-time traffic** (трафик в реальном времени), **ETA** (Estimated Time of Arrival, оценка времени).
- **Optimization** (оптимизация) — **min time** (минимум времени), **min distance** (минимум расстояния), **min cost** (минимум стоимости).

**Payment** (оплата):
- **Multi-method** (несколько методов) — **cash** (наличные), **e-wallet** (GrabPay, GoPay), **card** (Visa, Mastercard).
- **Fraud detection** (предотвращение мошенничества) — **ML model** (accuracy 95%+, < 100ms), **rules** (velocity, geography, amount).

**Safety** (безопасность):
- **SOS button** (кнопка SOS) — **emergency** (авария), **notification** (уведомление, e.g. police, contacts).
- **Trip sharing** (разделение поездки) — **real-time** (в реальном времени), **contacts** (контакты, e.g. family, friends).
- **Driver verification** (верификация водителя) — **KYC** (Know Your Customer, проверка документов), **background check** (проверка прошлого).

**Вопросы**: «Как настроить real-time matching?» → **Ответ**: «**< 1 сек** (latency), **geography** (5 km radius), **algorithm** (nearest neighbor, greedy, optimization), **data** (driver location, rider location, driver availability). **Use case**: **Grab**, **Uber»».

**Пример ответа на интервью**: «В прошлой компании (Singapore, Grab) мы настроили **ride-hailing**. **Real-time matching**: **< 1 сек** (latency), **geography** (5 km radius), **algorithm** (nearest neighbor, greedy, optimization). **GPS tracking**: **real-time** (WebSocket, 1 Hz), **storage** (Redis, TTL 1 час), **privacy** (anonymization, retention 30 дней). **Dynamic pricing**: **surge pricing** (demand > supply, multiplier 1.5×, 2×), **ML model** (prediction, optimization), **fairness** (transparency, cap 3×). **Routing**: **shortest path** (Dijkstra, A*), **traffic-aware** (real-time traffic, ETA), **optimization** (min time, min distance, min cost). **Payment**: **multi-method** (cash, e-wallet, card), **fraud detection** (ML model, < 100ms). **Safety**: **SOS button** (emergency, notification), **trip sharing** (real-time, contacts), **driver verification** (KYC, background check). **Result**: **< 1 сек** (matching), **real-time** (GPS, pricing, routing), **safe** (SOS, trip sharing, KYC)».

### 4. Logistics: route optimization, warehouse management, last-mile delivery, cold chain

**Route optimization** (оптимизация маршрута):
- **TSP** (Traveling Salesman Problem) — **NP-hard** (не имеет точного решения для больших N), **heuristic** (эвристика, e.g. nearest neighbor, 2-opt, 3-opt).
- **VRP** (Vehicle Routing Problem) — **multiple vehicles** (несколько машин), **capacity** (ёмкость), **time windows** (временные окна).
- **Real-time** (в реальном времени) — **traffic** (трафик), **ETA** (оценка времени), **re-routing** (перепланирование маршрута).

**Warehouse management** (управление складом):
- **WMS** (Warehouse Management System) — **inventory** (склад), **picking** (отбор), **packing** (упаковка), **shipping** (отправка).
- **Inventory tracking** (отслеживание склада) — **real-time** (в реальном времени), **SKU** (уникальный ID), **location** (локация на складе).
- **Optimization** (оптимизация) — **min time** (минимум времени), **min distance** (минимум расстояния), **min cost** (минимум стоимости).

**Last-mile delivery** (доставка последней мили):
- **Crowdsourcing** (краудсорсинг) — **drivers** (водители, e.g. Grab, Lalamove), **app** (приложение для водителей).
- **Route optimization** (оптимизация маршрута) — **multiple stops** (несколько остановок), **time windows** (временные окна), **capacity** (ёмкость).
- **Tracking** (отслеживание) — **real-time** (в реальном времени), **GPS** (GPS, 1 Hz), **ETA** (оценка времени).

**Cold chain** (холодовая цепь):
- **Temperature control** (контроль температуры) — **IoT sensors** (датчики IoT, e.g. temperature, humidity), **real-time** (в реальном времени, 1 Hz).
- **Alerts** (уведомления) — **threshold** (порог, e.g. > 8°C для vaccines), **notification** (уведомление, e.g. SMS, email).
- **Compliance** (комплаенс) — **2-8°C** (для vaccines, medicine), **regulations** (регуляции, e.g. WHO, local health authority).

**Вопросы**: «Как настроить route optimization?» → **Ответ**: «**TSP** (NP-hard, heuristic: nearest neighbor, 2-opt, 3-opt), **VRP** (multiple vehicles, capacity, time windows), **real-time** (traffic, ETA, re-routing). **Use case**: **last-mile delivery** (multiple stops, time windows)».

**Пример ответа на интервью**: «В прошлой компании (Singapore, Grab) мы настроили **logistics**. **Route optimization**: **TSP** (heuristic: nearest neighbor, 2-opt), **VRP** (multiple vehicles, capacity, time windows), **real-time** (traffic, ETA, re-routing). **Warehouse management**: **WMS** (inventory, picking, packing, shipping), **inventory tracking** (real-time, SKU, location), **optimization** (min time, min distance, min cost). **Last-mile delivery**: **crowdsourcing** (drivers, app), **route optimization** (multiple stops, time windows, capacity), **tracking** (real-time, GPS, ETA). **Cold chain**: **temperature control** (IoT sensors, 1 Hz), **alerts** (threshold, notification), **compliance** (2-8°C, regulations). **Result**: **optimized routes** (min time, min distance), **real-time** (inventory, delivery, temperature), **compliant** (cold chain, regulations)».

### 5. Fintech (e-wallet): GrabPay, SeaMoney, ShopeePay — e-wallet, P2P, lending, insurance

**E-wallet** (электронный кошелёк):
- **Balance** (баланс) — **top-up** (пополнение, e.g. card, bank transfer), **withdraw** (вывод, e.g. bank transfer), **spend** (расход, e.g. payment, bill).
- **Security** (безопасность) — **encryption** (AES-256 at rest, TLS 1.2+ in transit), **MFA** (Multi-Factor Authentication), **fraud detection** (ML model, < 100ms).
- **Compliance** (комплаенс) — **AML** (Anti-Money Laundering, предотвращение отмывания денег), **KYC** (Know Your Customer, проверка документов), **regulations** (регуляции, e.g. MAS в Singapore, OJK в Indonesia).

**P2P transfer** (переводы между пользователями):
- **Real-time** (в реальном времени) — **< 1 сек** (latency), **instant** (мгновенный).
- **Idempotency** (идемпотентность) — **idempotency key** (ключ идемпотентности, UUID v4), **no double charge** (нет двойного списания).
- **Fees** (комиссии) — **free** (бесплатно, e.g. P2P в одном e-wallet), **charged** (с комиссией, e.g. cross-border).

**Merchant payment** (оплата у мерчанта):
- **QR code** (QR-код) — **static** (статический, e.g. мерчант), **dynamic** (динамический, e.g. с суммой).
- **NFC** (Near Field Communication) — **tap-to-pay** (прикосновение, e.g. phone, card).
- **In-store** (в магазине) — **POS** (Point of Sale, терминал), **integration** (интеграция, e.g. GrabPay, GoPay).

**Lending** (кредитование):
- **ML scoring** (оценка ML-моделью) — **credit score** (кредитный рейтинг), **risk** (риск, e.g. default probability).
- **Approval** (одобрение) — **real-time** (в реальном времени, < 1 сек), **auto** (автоматически, без человека).
- **Repayment** (погашение) — **installments** (рассрочки, e.g. 3, 6, 12 месяцев), **auto-debit** (автоматическое списание).

**Insurance** (страхование):
- **Microinsurance** (микрострахование) — **cheap** (дёшево, e.g. $1/мес), **simple** (просто, e.g. health, accident).
- **Partnership** (партнёрство) — **insurance company** (страховая компания, e.g. Prudential, AIA), **integration** (интеграция, e.g. API).
- **Claim** (претензия) — **digital** (цифровой, e.g. app), **fast** (быстро, e.g. < 24 часа).

**Вопросы**: «Как настроить e-wallet?» → **Ответ**: «**Balance** (top-up, withdraw, spend), **security** (encryption, MFA, fraud detection), **compliance** (AML, KYC, regulations). **Use case**: **GrabPay**, **GoPay», **ShopeePay»».

**Пример ответа на интервью**: «В прошлой компании (Singapore, Grab) мы настроили **fintech** (e-wallet). **E-wallet**: **balance** (top-up, withdraw, spend), **security** (encryption, MFA, fraud detection), **compliance** (AML, KYC, regulations). **P2P transfer**: **real-time** (< 1 сек), **idempotency** (idempotency key, no double charge), **fees** (free, charged). **Merchant payment**: **QR code** (static, dynamic), **NFC** (tap-to-pay), **in-store** (POS, integration). **Lending**: **ML scoring** (credit score, risk), **approval** (real-time, auto), **repayment** (installments, auto-debit). **Insurance**: **microinsurance** (cheap, simple), **partnership** (insurance company, integration), **claim** (digital, fast). **Result**: **e-wallet** (secure, compliant), **P2P** (real-time, idempotent), **lending** (ML, auto), **insurance** (micro, digital)».
