# API Design & Documentation

### 1. OpenAPI 3.1: структура спецификации, основные возможности
OpenAPI Specification (OAS) — стандартизированный формат описания REST API. Версия 3.1 (вышла в 2021) основана на JSON Schema draft 2020-12, в отличие от 3.0, которая использовала модификацию JSON Schema draft-04.

Ключевые компоненты спецификации:
- `openapi: 3.1.0` — версия спецификации
- `info` — метаданные (title, version, description, contact)
- `servers` — список базовых URL (dev, staging, prod)
- `paths` — маршруты с операциями (get, post, put, patch, delete)
- `components` — переиспользуемые схемы (schemas, parameters, responses, securitySchemes)
- `security` — глобальные security requirements

В 3.1 появились: поддержка JSON Schema 2020-12 (anyOf, not, $ref с $defs), `webhooks` для event-driven, `content-type` в параметрах, несколько body через oneOf.

Практическое применение: спецификация является source of truth для генерации клиентского кода, серверных stubs, документации (Swagger UI, Redoc, Stoplight), mock-серверов и contract tests.

### 2. Генерация кода из OpenAPI: инструменты и стратегии
**Серверные stubs (Java):**
- `openapi-generator` (OpenAPITools) — генерирует Spring controllers, DTO, exception handlers, config. Поддерживает 50+ target languages.
- `springdoc-openapi` — reverse direction: генерирует спецификацию из Spring-кода (annotations + reflection).
- `swagger-codegen` (legacy) — заменён openapi-generator.

**Клиентский код:**
- `openapi-generator` с target `java`, `typescript-axios`, `kotlin`, `go` и др.
- В Spring Cloud: `spring-cloud-openfeign` + генерация Feign clients.

**Стратегии:**
1. **Design-first**: спецификация пишется первой (через Swagger Editor, Stoplight, Redocly), из неё генерируются и серверные, и клиентские артефакты. Подходит для публичных API, BFF.
2. **Code-first**: код пишется первым, спецификация генерируется из него (springdoc). Подходит для внутренних API.
3. **Гибрид**: спецификация вручную поддерживается как контракт, код проверяется через lint (spectral) и contract tests.

**CI/CD интеграция:** `openapi-generator-cli` в pipeline, diff спецификаций между версиями (oasdiff, oas-diff) для детекции breaking changes.

### 3. AsyncAPI: спецификация для event-driven API
AsyncAPI — «OpenAPI для асинхронных систем». Описывает каналы (канал = topic/queue), сообщения (message format), протоколы (Kafka, AMQP, MQTT, WebSocket, SSE).

Структура:
- `asyncapi: 3.0.0`
- `channels` — имена каналов (например, `order.created`)
- `operations` — publish/subscribe с привязкой к channel
- `message` — payload (JSON Schema), headers, correlation id
- `components` — переиспользуемые schemas, message traits, operation traits

Пример:
```yaml
channels:
  order.created:
    publish:
      operationId: publishOrderCreated
      message:
        $ref: '#/components/messages/OrderCreatedEvent'
components:
  messages:
    OrderCreatedEvent:
      payload:
        type: object
        properties:
          orderId: { type: string, format: uuid }
          totalAmount: { type: number }
```

Практическое применение: документация event contracts, генерация event consumers (Java, Node), mocking event-источников для разработки и тестирования, детекция breaking changes в event schemas.

### 4. gRPC + Protobuf: контракт, code generation, streaming
**Protocol Buffers (proto):**
```protobuf
syntax = "proto3";
package com.example.api;

service OrderService {
  rpc CreateOrder (CreateOrderRequest) returns (Order);
  rpc StreamOrders (StreamOrdersRequest) returns (stream Order);
  rpc GetOrder (GetOrderIdRequest) returns (Order);
}

message Order {
  string order_id = 1;
  int64 total_cents = 2;
  repeated LineItem items = 3;
  enum Status { PENDING = 0; PAID = 1; SHIPPED = 2; }
  Status status = 4;
}
```

**Code generation:**
- `protoc` + `protoc-gen-grpc-java` → Java interfaces + stubs
- В Maven: `protobuf-maven-plugin`, в Gradle: `com.google.protobuf` plugin
- Runtime: `grpc-netty-shaded` (server), `grpc-protobuf` (serialization)

**4 вида вызовов:**
1. Unary (request → response)
2. Server streaming (request → stream of responses)
3. Client streaming (stream of requests → response)
4. Bidirectional streaming (stream ↔ stream)

**gRPC vs REST:**
- gRPC: HTTP/2, binary serialization (protobuf), strong typing, codegen, multiplexing
- REST: HTTP/1.1 (или 2), JSON, human-readable, tooling, browser-native

**Ограничения gRPC:**
- Нет CORS из коробки (нужен gRPC-Web proxy)
- Браузеры не поддерживают напрямую
- Debugging сложнее (не human-readable)
- Нет нативного HATEOAS
- Versioning: package name или gRPC metadata

**Практика:** gRPC для internal service-to-service, REST для external/public API. Gateway (Envoy, Istio) конвертирует REST → gRPC.

### 5. GraphQL vs REST vs gRPC: trade-offs
**REST:**
- Преимущества: простой, кэшируемый (HTTP GET), широко поддерживаемый, human-readable, tooling
- Недостатки: over/under-fetching, N+1 при составных данных, versioning через URI
- Когда: публичные API, CRUD-heavy, когда клиенты разнообразны

**GraphQL:**
- Преимущества: точный запрос (нет over/under-fetching), single endpoint, schema-first, introspection
- Недостатки: кэширование сложнее (POST), N+1 резолвинг (нужен DataLoader), сложность безопасности (query depth/complexity limits), нет нативного пагинации
- Когда: BFF (Backend For Frontend), клиенты с разными потребностями в данных (mobile, web, IoT)
- Стек: Spring for GraphQL (`spring-graphql`), DGS Framework (Netflix)

**gRPC:**
- Преимущества: производительность (binary, HTTP/2), strong typing, streaming, codegen
- Недостатки: нет browser support, сложность debugging, limited tooling
- Когда: internal microservice communication, high-throughput, streaming

**Критерии выбора:**
| Критерий | REST | GraphQL | gRPC |
|----------|------|---------|------|
| Производительность | Средн. | Средн. | Высокая |
| Кэширование | Native | Сложно | Н/Д |
| Браузер | Да | Да | Нет (нужен proxy) |
| Streaming | SSE/WebSocket | Subscriptions | Native |
| Versioning | URI/Header | Schema | Package |
| Tooling | Отличное | Хорошее | Среднее |

### 6. HATEOAS: принципы и реализация в Spring
**HATEOAS** (Hypermedia as the Engine of Application State) — репрезентация ресурса содержит ссылки на связанные ресурсы и допустимые переходы. Клиент не хардкодит URL, а следует ссылкам в ответах.

**Spring HATEOAS:**
```java
@GetMapping("/orders/{id}")
public ResponseEntity<RepresentationModel<?>> getOrder(@PathVariable Long id) {
    Order order = orderService.findById(id);
    RepresentationModel<?> resource = RepresentationModel.of(order);
    resource.add(linkTo(methodOn(OrderController.class).getOrder(id)).withSelfRel());
    resource.add(linkTo(methodOn(OrderController.class).getItems(id)).withRel("items"));
    resource.add(linkTo(methodOn(PaymentController.class).createPayment(id)).withRel("pay"));
    return ResponseEntity.ok(resource);
}
```

Ответ:
```json
{
  "orderId": "123",
  "total": 99.99,
  "_links": {
    "self": { "href": "/api/orders/123" },
    "items": { "href": "/api/orders/123/items" },
    "pay": { "href": "/api/orders/123/payments" }
  }
}
```

**Принципы:**
- Self-link (`rel=self`)
- Named relationships (`rel=items`, `rel=pay`)
- Клиент stateless: навигация только через гиперссылки
- Алгоритмы: HAL (Hypertext Application Language) — JSON с `_links`

**Реальность 2026:** HATEOAS редко применяется в production. Причины: сложность, низкая привязка (link generation на каждый запрос), большинство клиентов знают URL. Применяется в публичных API с высокой степенью автономности (Twitter API v1.1 использовал частично). В Spring: `spring-hateoas` + `hal`. Для BFF и внутренних API — обычный REST.

### 7. API Gateway patterns: routing, rate limiting, transformation
**API Gateway** — единая точка входа для всех API запросов. Паттерны:

**Routing:**
- Path-based: `/orders/*` → order-service, `/users/*` → user-service
- Header-based: `X-Service: billing` → billing-service
- Method-based: `POST /search` → search-service
- Weighted routing (canary): 90% → v1, 10% → v2

**Rate Limiting:**
- Per consumer (API key / tenant)
- Per endpoint
- Algorithms: token bucket, sliding window, fixed window
- Response: `429 Too Many Requests` + `Retry-After` header

**Transformation:**
- JSON → gRPC (Envoy, Istio)
- Versioning: strip `/v1/` из path перед forward
- Enrichment: добавлять headers (auth token, tenant id)
- Aggregation: compose multiple backend calls в один ответ (BFF pattern)

**Дополнительные функции gateway:**
- Authentication/Authorization (JWT verification, OAuth2)
- Caching (response caching для GET)
- Request/response logging
- Circuit breaking (не forwarding в перегруженный сервис)
- SSL termination
- IP allowlisting

**Технологии:** Kong, APISIX, Envoy, AWS API Gateway, Azure API Management, Istio (Service Mesh как gateway), Spring Cloud Gateway (lightweight, в JVM).

**Spring Cloud Gateway:**
```java
@Bean
public RouteLocator customRoutes(RouteLocatorBuilder builder) {
    return builder.routes()
        .route("orders", r -> r.path("/api/orders/**")
            .filters(f -> f.rateLimit(conf))
            .uri("lb://order-service"))
        .build();
}
```

### 8. Contract Testing: Pact, Spring Cloud Contract
**Проблема:** в микросервисах producer и consumer — разные команды/деплои. Как гарантировать, что producer не сломает consumer?

**Pact (consumer-driven contract testing):**
1. Consumer пишет тест: «я ожидаю, что GET /orders/123 вернёт JSON с полями orderId, total»
2. Pact записывает consumer contract (JSON-файл)
3. Contract публикуется в Pact Broker
4. CI producer: запускает provider verification — проверяет, что реальные ответы удовлетворяют все consumer contracts
5. Если нет → CI producer падает

```java
// Consumer test (Pact 4.x, Java)
@Provider("order-service")
@Consumer("billing-service")
class BillingPactTest {
    @Pact(consumer = "billing-service")
    public PactInteraction getOrderPact() {
        return new PactInteractionBuilder("/orders/ORD-123")
            .givenExtensions(new ConsumerDefinedMatchingRules())
            .withRequestMethod(GET)
            .withResponseBody(jsonBody -> jsonBody
                .stringType("orderId", "ORD-123")
                .numberType("total", 99.99))
            .withStatusCode(200)
            .toPactInteraction();
    }
}
```

**Spring Cloud Contract (Verifiere):**
- Producer определяет contract (GROOVY DSL или YAML)
- Генерируется: stub для consumer, test для provider
- Интеграция с Spring Cloud Contract Stub Runner (consumer поднимает stubs provider'ов)

**Сравнение:**
| | Pact | Spring Cloud Contract |
|---|---|---|
| Direction | Consumer-driven | Provider-driven |
| DSL | Java/Kotlin/JS | Groovy/YAML |
| Broker | Pact Broker (отдельный) | Нет встроенного |
| Ecosystem | Многоплатформенный | Spring-only |

### 9. API versioning: стратегии и trade-offs
**URI versioning:** `/api/v1/orders`, `/api/v2/orders`
- Плюсы: видимое, легко кэшировать, простой routing
- Минусы: «version in URL» против REST purism, много URL, HATEOAS-несовместимо

**Header versioning:** `Accept: application/vnd.company.api.v1+json`
- Плюсы: чистый URI, один endpoint
- Минусы: скрытое, сложно debug, кэширование сложнее

**Query parameter:** `?version=1`
- Минусы: самый слабый вариант, не кэшируется отдельно

**Content negotiation (RFC-комплаентный):**
- `Accept: application/vnd.company.orders.v2+json`
- Корректный HTTP-способ, но complex

**Consumer-driven versioning (рекомендуемый подход 2026):**
- Не versioning через URI, а:
  - Additive changes (новые поля) — не breaking
  - Deprecation: `@Deprecated` header в ответах, sunset header (RFC 3298)
  - Breaking changes → новая major версия
- Практика: большинство pубличных API (Stripe, Twitter) — additive first, breaking только v2+

**Sunset (RFC 3298):**
```
HTTP/1.1 200 OK
Sunset: Sat, 01 Jan 2028 00:00:00 GMT
Deprecation: /api/deprecation-policy
```

**Стратегия для микросервисов:**
- Internal: без versioning (сервисы деплоятся вместе)
- External: URI v1/v2, additive changes, sunset для deprecated

### 10. API evolution: backwards compatibility, deprecation
**Правила backwards compatibility:**
- Добавление полей в response — OK (consumer игнорирует неизвестные)
- Добавление optional параметров — OK
- Удаление/переименование полей — BREAKING
- Изменение типа поля — BREAKING
- Изменение status codes — BREAKING
- Добавление required параметра — BREAKING

**Процесс deprecation:**
1. **Announce**: `Deprecation` header, документация
2. **Dual-run**: старая и новая версия работают параллельно
3. **Warn**: логирование, alerting на использование deprecated
4. **Sunset**: RFC 3298 `Sunset` header с датой
5. **Remove**: удаление deprecated endpoint

**Практические инструменты:**
- `oasdiff` — diff OpenAPI спецификаций, детекция breaking changes
- `spectral` — lint API specs, custom rules
- Pact Broker — проверка compatibility при каждом деплое
- API analytics — мониторинг использования deprecated endpoints

**Стратегия для mикросервисов:**
- Contract-first: изменения в спецификации проходят review
- CI: oasdiff между spec в main и PR — блокирует breaking changes
- Deprecation window: минимум 6-12 месяцев для публичных API

### 11. REST best practices: URL design, HTTP methods, status codes
**URL design:**
- Resource-oriented: `/orders`, `/orders/{id}`, `/orders/{id}/items`
- Plural nouns: `/orders` (не `/order`)
- No verbs in URL: `POST /orders` (не `POST /createOrder`)
- Nesting: максимум 2 уровня (`/orders/{id}/items`), глубже — flat (`/items?orderId=123`)
- Pagination: `/orders?page=2&size=20` или cursor-based `?cursor=xxx&limit=20`
- Filtering: `?status=PAID&minAmount=100`
- Sorting: `?sort=-createdAt` (minus = desc)

**HTTP methods:**
- `GET` — idempotent, safe, cacheable
- `POST` — creation (не idempotent), или non-CRUD operations
- `PUT` — idempotent, full replacement
- `PATCH` — partial update (JSON Patch RFC 6902, JSON Merge Patch RFC 7386)
- `DELETE` — idempotent
- `HEAD` — same as GET, no body
- `OPTIONS` — CORS, supported methods

**Status codes:**
- `200 OK` — success
- `201 Created` — resource created + `Location` header
- `202 Accepted` — async operation
- `204 No Content` — DELETE success, PATCH without body
- `400 Bad Request` — malformed request
- `401 Unauthorized` — not authenticated
- `403 Forbidden` — authenticated but no permission
- `404 Not Found`
- `409 Conflict` — resource conflict (duplicate)
- `422 Unprocessable Entity` — semantic error (valid format, wrong meaning)
- `429 Too Many Requests` — rate limit + `Retry-After`
- `500 Internal Server Error`
- `503 Service Unavailable` — maintenance, overload + `Retry-After`

**Headers:**
- `ETag` / `If-None-Match` — conditional GET, caching
- `Idempotency-Key` — idempotent POST
- `X-Request-Id` — correlation
- `Retry-After` — rate limiting, 503
- `Sunset` — deprecation

### 12. API documentation: инструменты и стратегии
**Инструменты:**
- **Swagger UI** — интерактивная документация из OpenAPI (try-it-out)
- **Redoc** — красивая статическая документация (3-column layout)
- **Stoplight Studio** — design-first, collaboration, lint, mocks
- **Scalar** — modern alternative to Swagger UI
- **GitBook / Confluence** — narrative documentation (tutorials, guides)

**Стратегии:**
1. **OpenAPI-first**: спецификация в репозитории, doc генерируется автоматически
   - CI: build → generate docs → publish (GitHub Pages, S3, internal portal)
2. **Code-first**: springdoc генерирует spec из кода, doc из spec
   - Минус: нет контроля качества спецификации
3. **Hybrid**: спецификация вручную (source of truth), код lint against spec

**Контент документации:**
- Getting started (auth, first request)
- API reference (endpoints, params, responses, examples)
- Error reference (все error codes с examples)
- Rate limits и quotas
- Changelog (что изменилось между версиями)
- SDK/CLI reference
- Examples (cURL, Java, Python, JS)
- FAQ

**CI/CD для документации:**
- `redocly build-docs openapi.yaml -o docs.html`
- `openapi-generator` для SDK
- Публикация: GitHub Pages, internal portal (ReadMe, Stoplight)
- Diff спецификаций между release-ветками

### 13. gRPC metadata, interceptors и error handling
**gRPC Metadata (аналог HTTP headers):**
```java
// Client: setting metadata
ManagedChannel channel = ...;
Metadata metadata = new Metadata();
metadata.put(Metadata.Key.of("X-Request-Id", Metadata.ASCII_STRING_MARSHALLER), "req-123");
metadata.put(Metadata.Key.of("X-Tenant-Id", Metadata.ASCII_STRING_MARSHALLER), "tenant-42");
OrderGrpc.OrderBlockingStub stub = OrderGrpc.newBlockingStub(channel)
    .withInterceptors((call, next) -> {
        Metadata newMeta = new Metadata();
        newMeta.merge(metadata);
        return next.newClientCall(call.getDescriptor(), call.getDefaultCallOptions().withMetadata(newMeta));
    });
```

**Interceptors (аналог Spring interceptors / AOP):**
- Client interceptor: auth, logging, retry
- Server interceptor: auth validation, tenant resolution, metrics

```java
ServerInterceptors.intercept(serverBuilder,
    new MetadataUtils.newCaptureServerInterceptor(),
    new ServerInterceptor() {
        @Override
        public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
                ServerCall<ReqT, RespT> call, Metadata headers,
                ServerCallHandler<ReqT, RespT> next) {
            // Extract auth token, validate, resolve tenant
            ServerCall<ReqT, RespT> newCall = new MeteredServerCall<>(call);
            return next.callHandler(newCall, headers);
        }
    }
).build();
```

**Error handling (gRPC status codes):**
- `Status.OK` — success
- `Status.CANCELLED` — client cancelled
- `Status.NOT_FOUND` — resource not found
- `Status.ALREADY_EXISTS` — duplicate
- `Status.PERMISSION_DENIED` — 403
- `Status.UNAUTHENTICATED` — 401
- `Status.DEADLINE_EXCEEDED` — timeout
- `Status.RESOURCE_EXHAUSTED` — 429
- `Status.INTERNAL` — 500
- `Status.UNAVAILABLE` — 503

**Error details (gRPC extension):**
```java
ErrorInfo errorInfo = ErrorInfo.newBuilder()
    .setReason("ORDER_NOT_FOUND")
    .setDomain("com.example.api")
    .setMessage("Order ORD-123 not found")
    .build();
Status status = Status.NOT_FOUND.withDescription("Order not found")
    .withCause(ExceptionWithErrorInfo.of(errorInfo));
```

### 14. REST error handling: problem details (RFC 9457)
**RFC 9457 (Problem Details for HTTP APIs)** — standard error format:

```json
{
  "type": "https://api.example.com/errors/order-not-found",
  "title": "Order Not Found",
  "status": 404,
  "detail": "Order with ID 'ORD-123' does not exist",
  "instance": "/api/orders/ORD-123",
  "errorCode": "ORDER_NOT_FOUND",
  "errors": [
    { "field": "orderDate", "message": "must be in past" }
  ]
}
```

**Content-Type:** `application/problem+json`

**Spring Boot 3 (RFC 9457 native):**
```java
// Default Spring Boot 3 behavior: ProblemDetail
@GetMapping("/orders/{id}")
public ResponseEntity<?> getOrder(@PathVariable String id) {
    return orderService.findById(id)
        .map(o -> ResponseEntity.ok(o))
        .orElseThrow(() -> {
            ProblemDetail pd = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND, "Order not found: " + id);
            pd.setType(URI.create("https://api.example.com/errors/order-not-found"));
            pd.setTitle("Order Not Found");
            pd.setProperty("errorCode", "ORDER_NOT_FOUND");
            return new ResponseStatusException(HttpStatus.NOT_FOUND, pd);
        });
}
```

**Custom error handler:**
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(OrderNotFoundException.class)
    public ProblemDetail handleNotFound(OrderNotFoundException e) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
        pd.setType(URI.create("https://api.example.com/errors/" + e.getErrorCode()));
        pd.setProperty("requestId", RequestContextHolder.getRequestId());
        return pd;
    }
}
```

**Добавляемые поля:** `errorCode` (machine-readable), `errors[]` (field-level validation), `requestId` (correlation).

### 15. API security: authentication, authorization, threat model
**Authentication patterns:**
1. **API Key** — header `X-API-Key: xxx`, simple, для service-to-service
2. **OAuth2 Client Credentials** — service-to-service, `client_id` + `client_secret` → `access_token`
3. **OAuth2 Authorization Code + PKCE** — user-facing (SPA, mobile)
4. **JWT Bearer** — stateless auth, token в `Authorization: Bearer <jwt>`
5. **mTLS** — mutual TLS для service-to-service (Istio, Linkerd)

**Authorization patterns:**
- **RBAC** (Role-Based Access Control) — роли: admin, operator, viewer
- **ABAC** (Attribute-Based) — правила: `tenant == request.tenant && role in [admin, operator]`
- **OWASP API Security Top 10 2023:**
  - API1: Broken Object Level Authorization (BOLA)
  - API2: Broken Authentication
  - API3: Broken User Privacy
  - API4: Unrestricted Resource Consumption
  - API5: Broken Function Level Authorization
  - API6: Unrestricted Access to Sensitive HTTP Methods
  - API7: SSRF
  - API8: Security Misconfiguration
  - API9: Unsafe Consumption of APIs
  - API10: Information Exposure

**Threat model для API:**
- **Injection**: SQL, NoSQL, LDAP, command injection через параметры
- **BOLA**: user A получает resource user B через перебор ID
  - Защита: ownership check, scope token
- **Rate limiting bypass**: distributed attack
- **Data exposure**: verbose error messages, verbose logging
- **Supply chain**: compromised dependency, unpatched CVE
- **Replay attacks**: idempotency keys, timestamp validation

**Практические меры:**
- JWT: short TTL (15min), refresh tokens, `aud` claim validation
- Input validation: allowlist, size limits, schema validation
- CORS: strict `Access-Control-Allow-Origin`
- HSTS, CSP, X-Content-Type-Options: nosniff
- API gateway: rate limiting, auth, IP allowlist
- Secrets: не в headers client-side, не в logs
