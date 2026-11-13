# API Design & Documentation

### 1. OpenAPI 3.1: спецификация, генерация кода, validation

**OpenAPI 3.1** — **стандарт** для **описания** **REST API** (YAML/JSON). **Заменяет** **Swagger 2.0**.

**Структура**:
```yaml
openapi: 3.1.0
info:
  title: Order API
  version: 1.0.0
  description: API для управления заказами
servers:
  - url: https://api.example.com/v1
paths:
  /orders:
    get:
      summary: Получить список заказов
      operationId: listOrders
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [PENDING, SHIPPED, DELIVERED]
        - name: page
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: Список заказов
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OrderList'
        '400':
          $ref: '#/components/responses/BadRequest'
    post:
      summary: Создать заказ
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
      responses:
        '201':
          description: Заказ создан
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
components:
  schemas:
    Order:
      type: object
      required: [id, status, createdAt]
      properties:
        id:
          type: integer
          format: int64
        status:
          type: string
          enum: [PENDING, SHIPPED, DELIVERED]
        total:
          type: number
          format: decimal
        createdAt:
          type: string
          format: date-time
    OrderList:
      type: object
      properties:
        items:
          type: array
          items:
            $ref: '#/components/schemas/Order'
        total:
          type: integer
  responses:
    BadRequest:
      description: Неверный запрос
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

**OpenAPI 3.1 vs 3.0**:
- **JSON Schema 2020-12** (не **Draft 4**).
- **`$ref`** **может** **ссылаться** **на** **внешние** **файлы**.
- **`oneOf`**, **`anyOf`**, **`allOf`** **работают** **как** **в** **JSON Schema**.
- **`nullable`** **заменено** **на** **`type: [string, "null"]`**.

**Генерация кода**:
- **SpringDoc** (Spring Boot): **автоматическая** **генерация** **OpenAPI** **из** **кода** (`@RestController`, **Javadoc**).
- **OpenAPI Generator**: **генерация** **client/server** **кода** **из** **OpenAPI** **YAML**.

```xml
<!-- SpringDoc: -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```
```java
// Автоматическая генерация:
// http://localhost:8080/swagger-ui.html (UI)
// http://localhost:8080/v3/api-docs (YAML)
```

**Validation**:
- **`@Valid`** + **Bean Validation** (`@NotNull`, `@Size`, `@Pattern`) — **Spring** **валидирует** **запрос** **по** **OpenAPI**.
- **OpenAPI** **схема** **генерирует** **валидацию** **автоматически** (SpringDoc).

**Инструменты**:
- **Swagger UI**: **интерактивный** **UI** (тестирование **API**).
- **Redoc**: **красивая** **документация** (read-only).
- **Postman** / **Insomnia**: **импорт** **OpenAPI** → **коллекция** **запросов**.

### 2. AsyncAPI для event-driven API

**AsyncAPI** — **стандарт** для **описания** **event-driven API** (Kafka, RabbitMQ, MQTT, WebSocket).

**Зачем**: **OpenAPI** **описывает** **HTTP**, **AsyncAPI** **описывает** **сообщения** (events, **channels**, **payloads**).

**Структура**:
```yaml
asyncapi: 3.0.0
info:
  title: Order Events
  version: 1.0.0
channels:
  order.created:
    address: order-created  # Kafka topic
    publish:
      operationId: onOrderCreated
      traits:
        - $ref: '#/components/traits/Authenticated'
      message:
        $ref: '#/components/messages/OrderCreated'
  order.shipped:
    address: order-shipped
    publish:
      message:
        $ref: '#/components/messages/OrderShipped'
components:
  traits:
    Authenticated:
      security:
        - apiKey: []
  messages:
    OrderCreated:
      payload:
        type: object
        required: [orderId, userId, total]
        properties:
          orderId:
            type: string
            format: uuid
          userId:
            type: string
          total:
            type: number
          items:
            type: array
            items:
              type: object
              properties:
                productId:
                  type: string
                qty:
                  type: integer
    OrderShipped:
      payload:
        type: object
        properties:
          orderId:
            type: string
          tracking:
            type: string
          carrier:
            type: string
security:
  apiKey:
    type: apiKey
    in: header
    name: X-API-Key
```

**Когда AsyncAPI, когда OpenAPI**:
- **OpenAPI**: **HTTP API** (REST, GraphQL).
- **AsyncAPI**: **event-driven** (Kafka, RabbitMQ, WebSocket, MQTT).
- **Оба**: **event-driven HTTP** (Webhooks, SSE).

**Инструменты**:
- **AsyncAPI Studio**: **UI** для **AsyncAPI** (аналог Swagger UI).
- **AsyncAPI Generator**: **генерация** **producer/consumer** **кода**.
- **Spring for Apache Kafka**: **интеграция** **с** **AsyncAPI** (через **SpringDoc**).

### 3. gRPC + Protobuf: контракт, code generation, streaming

**gRPC** — **RPC** **фреймворк** от **Google**. **Protobuf** — **бинарный** **формат** **сериализации**.

**Контракт (Protobuf)**:
```protobuf
syntax = "proto3";
package order;

service OrderService {
    // Unary: 1 запрос → 1 ответ
    rpc CreateOrder (CreateOrderRequest) returns (Order);
    
    // Server streaming: 1 запрос → N ответов
    rpc StreamOrders (StreamOrdersRequest) returns (stream Order);
    
    // Client streaming: N запросов → 1 ответ
    rpc BatchCreateOrders (stream CreateOrderRequest) returns (BatchResult);
    
    // Bidirectional streaming: N запросов ↔ N ответов
    rpc WatchOrders (stream OrderFilter) returns (stream OrderEvent);
}

message CreateOrderRequest {
    string user_id = 1;
    repeated Item items = 2;
    string currency = 3;
}

message Item {
    string product_id = 1;
    int32 qty = 2;
}

message Order {
    string id = 1;
    string status = 2;
    double total = 3;
    repeated Item items = 4;
    string created_at = 5;
}

message StreamOrdersRequest {
    string user_id = 1;
    string status = 2;
}

message BatchResult {
    int32 created = 1;
    repeated string errors = 2;
}

message OrderFilter {
    string user_id = 1;
    string status = 2;
}

message OrderEvent {
    string order_id = 1;
    string type = 2;  // CREATED, SHIPPED, DELIVERED
    string payload = 3;
}
```

**Code Generation**:
```bash
# Генерация Java кода:
protoc --java_out=./src/main/java \
       --grpc-java_out=./src/main/java \
       --plugin=protoc-gen-grpc-java=$(which grpc-java-pluggable) \
       order.proto
```
- **Генерируется**: `OrderServiceGrpc` (stub + impl), **message** **классы**.
- **Client**: **асинхронный** (CompletableFuture, **Reactor**).
- **Server**: **Spring** **Boot** **интеграция** (**grpc-spring-boot-starter**).

**gRPC vs REST**:
| | gRPC | REST |
|---|---|---|
| **Формат** | Protobuf (бинарный) | JSON (текст) |
| **Скорость** | Быстрее (бинарный, HTTP/2) | Медленнее (JSON, HTTP/1.1) |
| **Streaming** | Нативно (4 типа) | SSE, WebSocket |
| **Браузер** | Нет (только через Envoy/gateway) | Да |
| **Документация** | Protobuf (контракт) | OpenAPI |
| **Use case** | Service-to-service | Client-to-server |

**Когда gRPC, когда REST**:
- **gRPC**: **service-to-service** (микросервисы), **высокая** **нагрузка**, **streaming**.
- **REST**: **client-to-server** (браузер, мобильное), **публичное** **API**.

**Проблемы**:
- **Браузер** **не** **поддерживает** **gRPC** (нужен **gateway** — Envoy, Kong).
- **Отладка** **сложнее** (бинарный **формат**).
- **Экосистема** **меньше** (vs REST).

### 4. GraphQL vs REST vs gRPC — trade-offs

**GraphQL**:
- **Один** **эндпоинт** (`/graphql`), **клиент** **запрашивает** **только** **нужные** **поля**.
- **Плюс**: **нет** **over-fetching** (REST: **все** **поля**), **нет** **under-fetching** (N запросов).
- **Минус**: **сложнее** **кэшировать**, **сложнее** **валидировать**, **N+1** **проблема** (нужен **DataLoader**).

```graphql
# GraphQL запрос:
query {
  order(id: "123") {
    id
    status
    items {
      productId
      qty
    }
    shipping {
      carrier
      tracking
    }
  }
}
# Ответ: только запрошенные поля (no over/under-fetching)
```

**REST**:
- **Множество** **эндпоинтов** (`GET /orders/123`, `GET /orders/123/items`, ...).
- **Плюс**: **просто**, **кэшируемо** (HTTP), **стандарт**.
- **Минус**: **over/under-fetching**, **N** **запросов** **для** **одного** **экрана**.

**gRPC**:
- **Контракт** (Protobuf), **4** **типа** **вызовов** (unary, streaming).
- **Плюс**: **быстро**, **типизировано**, **streaming**.
- **Минус**: **не** **для** **браузера**, **сложнее** **отлаживать**.

**Сравнение**:
| | GraphQL | REST | gRPC |
|---|---|---|---|
| **Эндпоинты** | 1 (/graphql) | N | N (RPC methods) |
| **Формат** | JSON | JSON | Protobuf |
| **Over/under-fetching** | Нет | Да | Нет (контракт) |
| **Кэширование** | Сложно | Легко (HTTP) | Нет |
| **Streaming** | Subscriptions (WS) | SSE, WS | Нативно |
| **Браузер** | Да | Да | Нет (gateway) |
| **Use case** | Mobile, BFF | Public API | Service-to-service |

**Когда что**:
- **GraphQL**: **mobile** (экономия **трафика**), **BFF** (составление **данных**).
- **REST**: **публичное** **API**, **простота**, **кэширование**.
- **gRPC**: **микросервисы**, **высокая** **нагрузка**, **streaming**.

### 5. API versioning strategies: URI, header, consumer-driven

**URI Versioning**:
- **`/v1/orders`**, **`/v2/orders`**.
- **Плюс**: **просто**, **видимо** (URL **показывает** **версию**).
- **Минус**: **N** **версий** = **N** **эндпоинтов** (поддержка **всех**).

**Header Versioning**:
- **`X-API-Version: 1`** (заголовок).
- **Плюс**: **чистый** **URL** (без **версии**).
- **Минус**: **не** **видимо** (URL **не** **показывает** **версию**), **сложнее** **кэшировать**.

**Consumer-Driven Contract (CDC)**:
- **Каждый** **consumer** **описывает** **какие** **поля** **ему** **нужны**.
- **Provider** **проверяет** **контракт** **при** **изменении** **API**.
- **Плюс**: **нет** **версий** (каждый **consumer** **получает** **то** **что** **нужно**).
- **Минус**: **сложнее** (нужен **CDC** **инструмент** — **Pact**, **Spring Cloud Contract**).

**Пример (Pact)**:
```java
// Consumer (Pact):
@Provider("order-service")
@Pact(provider = "order-service", consumer = "web-app")
public void pactForGetOrder(PactWriter writer) {
    writer.given("order 123 exists")
        .uponReceiving("GET /orders/123")
        .withPath("/orders/123")
        .willRespondWith()
        .status(200)
        .body(json -> json
            .stringType("id", "123")
            .stringType("status", "SHIPPED")
            .numberType("total", 999.0));
}

// Provider (валидация контракта):
@PactVerification("web-app")
@Provider("order-service")
@SpringBootTest
class OrderServicePactTest {
    // ...
}
```

**Best practice**:
- **URI versioning** для **публичных** **API** (просто, **видимо**).
- **CDC** для **внутренних** **микросервисов** (без **версий**, **контракт**).
- **Никогда** **не** **ломать** **старые** **версии** (deprecated → **alert** → **delete** через **12 мес**).

### 6. HATEOAS: принципы, реализация в Spring

**HATEOAS (Hypermedia as the Engine of Application State)** — **принцип** **REST**, **при** **котором** **клиент** **навигирует** **по** **API** **через** **ссылки** **в** **ответах** (не **hardcoded** **URL**).

**Принцип**:
- **Ответ** **содержит** **ссылки** **на** **доступные** **операции** (`_links`).
- **Клиент** **не** **знает** **URL** **заранее** — **берёт** **из** **ответа**.
- **Плюс**: **гибкость** (URL **можно** **менять** **без** **изменения** **клиента**).
- **Минус**: **больше** **данных** в **ответе**, **сложнее** **кэшировать**.

**Пример (HAL — Hypertext Application Language)**:
```json
{
  "_links": {
    "self": { "href": "/orders/123" },
    "items": { "href": "/orders/123/items" },
    "shipping": { "href": "/orders/123/shipping" },
    "cancel": { "href": "/orders/123", "method": "POST" }
  },
  "id": "123",
  "status": "SHIPPED",
  "total": 999.0
}
```

**В Spring (Spring HATEOAS)**:
```java
@GetMapping("/orders/{id}")
public ResponseEntity<OrderRepresentation> getOrder(@PathVariable Long id) {
    Order order = orderService.findById(id);
    
    OrderRepresentation rep = new OrderRepresentation(order);
    rep.add(linkTo(methodOn(OrderController.class).getOrder(id)).withSelfRel());
    rep.add(linkTo(methodOn(OrderController.class).getItems(id)).withRel("items"));
    rep.add(linkTo(methodOn(OrderController.class).getShipping(id)).withRel("shipping"));
    
    return ResponseEntity.ok(rep);
}
```

**Когда HATEOAS, когда нет**:
- **HATEOAS**: **публичное** **API** (клиенты **разные**, **URL** **меняется**).
- **Без HATEOAS**: **внутреннее** **API** (микросервисы, **URL** **стабильны**).

**Типовые проблемы**:
- **Клиенты** **игнорируют** **`_links`** (используют **hardcoded** **URL**).
- **Кэширование** **сложнее** (ссылки **в** **ответе**).
- **Больше** **данных** (over-fetching **ссылок**).

### 7. API gateway patterns: routing, rate limiting, transformation

**API Gateway** — **единая** **точка** **входа** **в** **микросервисы**. **Маршрутизирует** **запросы** **к** **нужным** **сервисам**.

**Задачи**:
- **Routing**: **`/orders/*`** → **order-service**, **`/users/*`** → **user-service**.
- **Auth**: **проверка** **токена** **однажды** (не **в** **каждом** **сервисе**).
- **Rate Limiting**: **ограничение** **запросов** **per** **user/IP**.
- **Transformation**: **JSON** → **Protobuf** (gRPC **за** **REST**).
- **Caching**: **кэширование** **ответов** (GET **запросы**).
- **Compression**: **gzip** **ответов**.
- **Logging/Metrics**: **логи** **и** **метрики** **на** **входе**.

**Пример (Kong / APISIX / Spring Cloud Gateway)**:
```yaml
# Kong:
services:
  - name: order-service
    url: http://order-service:8080
    routes:
      - strips_path: true
        paths:
          - /orders
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          policy: local
```

**Spring Cloud Gateway** (ReactNetty):
```java
@Configuration
public class GatewayConfig {
    @Bean
    public RouteLocator customRoutes(RouteLocatorBuilder builder) {
        return builder.routes()
            .route("orders", r -> r.path("/orders/**")
                .filters(f -> f
                    .rateLimit(c -> c
                        .rateLimitProcessor(myRateLimiter))
                    .stripPrefix(1))
                .uri("lb://order-service"))
            .route("users", r -> r.path("/users/**")
                .uri("lb://user-service"))
            .build();
    }
}
```

**Когда Gateway, когда Service Mesh**:
- **Gateway**: **единая** **точка** **входа** (REST → **микросервисы**).
- **Service Mesh** (Istio): **sidecar** **между** **сервисами** (mTLS, **routing**, **retry**).
- **Оба**: **Gateway** **для** **внешних** **клиентов**, **Mesh** **для** **внутренних** **сервисов**.

### 8. Contract testing: Pact, Spring Cloud Contract

**Contract Testing** — **проверка** **совместимости** **API** **между** **consumer** **и** **provider** **без** **интеграционного** **теста**.

**Pact**:
- **Consumer** **описывает** **контракт** (**какие** **запросы** **делает**, **какой** **ответ** **ожидает**).
- **Provider** **валидирует** **контракт** (**при** **изменении** **API**).
- **Pact Broker**: **хранилище** **контрактов** (consumer ↔ provider).

```java
// Consumer (Pact):
@Provider("order-service")
@Pact(provider = "order-service", consumer = "web-app")
void pactForGetOrder(PactWriter writer) {
    writer.given("order 123 exists")
        .uponReceiving("GET /orders/123")
        .withPath("/orders/123")
        .willRespondWith()
        .status(200)
        .header("Content-Type", "application/json")
        .body(json -> json
            .stringType("id", "123")
            .stringType("status", "SHIPPED")
            .numberType("total", 999.0));
}

// Provider (валидация):
@PactVerification("web-app")
@Provider("order-service")
ProviderState
class OrderServicePactTest {
    @PactVerification
    @Test
    void verifyPact() {
        // Pact Framework запускает consumer-запросы
        // и проверяет ответы provider
    }
    
    @PactVerification
    @State("order 123 exists")
    void setupOrder() {
        // Создаём order 123 в тестовой БД
    }
}
```

**Spring Cloud Contract**:
- **Verificator**: **генерация** **контрактов** **из** **Gherkin** **файлов**.
- **Stub**: **генерация** **stub** **сервера** **для** **consumer** **тестов**.
- **Client**: **валидация** **provider** **по** **контракту**.

```groovy
// Contract (Gherkin):
Gherkin {
    request {
        method 'GET'
        url '/orders/123'
    }
    response {
        status 200
        body '''
        {
            "id": "123",
            "status": "SHIPPED",
            "total": 999.0
        }
        '''
        contentType 'application/json'
    }
}
```

**Pact vs Spring Cloud Contract**:
| | Pact | Spring Cloud Contract |
|---|---|---|
| **Язык** | Java, Kotlin, Ruby, ... | Groovy (Gherkin) |
| **Broker** | Pact Broker (SaaS/self-hosted) | Spring Cloud Contract Verifier |
| **Экосистема** | Огромная | Spring |
| **Выбор** | Multi-language | Spring-only |

**Когда Contract Testing**:
- **Микросервисы** (consumer ↔ provider).
- **Публичное API** (consumer = **внешние** **клиенты**).
- **CI/CD** (**автоматическая** **валидация** **контракта** **при** **PR**).

### 9. API evolution: backwards compatibility, deprecation strategies

**Backwards Compatibility**:
- **Новый** **client** **работает** **со** **старым** **API**.
- **Старый** **client** **работает** **с** **новым** **API**.

**Правила**:
1. **Добавление** **поля** **в** **ответ** → **безопасно** (старый **client** **игнорирует**).
2. **Добавление** **эндпоинта** → **безопасно**.
3. **Удаление** **поля** **из** **ответа** → **НЕ** **безопасно** (старый **client** **ломается**).
4. **Изменение** **типа** **поля** → **НЕ** **безопасно**.
5. **Добавление** **обязательного** **параметра** **в** **запрос** → **НЕ** **безопасно** (старый **client** **не** **передаёт**).

**Deprecation Strategy**:
1. **Отметить** **deprecated** (`@Deprecated`, **OpenAPI** **`deprecated: true`**).
2. **Логировать** **использование** **deprecated** **эндпоинтов** (metrics, **alerts**).
3. **Уведомить** **клиентов** (changelog, **email**, **API** **docs**).
4. **Период** **deprecated** (6–12 мес).
5. **Удалить** **deprecated** **эндпоинт** (после **0** **использований**).

```java
@Deprecated(since = "1.0", forRemoval = true)
@GetMapping("/orders/legacy")
public OrderRepresentation getLegacyOrder(@RequestParam Long id) {
    log.warn("DEPRECATED: /orders/legacy used by {}", 
        RequestContextHolder.currentRequestAttributes());
    return getOrder(id);
}
```

**OpenAPI deprecation**:
```yaml
paths:
  /orders/legacy:
    get:
      deprecated: true
      description: "Устарело. Используйте /orders/{id}."
      # ...
```

**API Evolution Workflow**:
1. **Изменение** **API** (PR).
2. **Contract Testing** (Pact) → **валидация** **backwards compatibility**.
3. **Добавить** **deprecated** **маркер**.
4. **Monitor** **использование** (metrics).
5. **Удалить** **deprecated** **через** **6–12 мес**.

**Типовые ошибки**:
- **Удаление** **поля** **без** **deprecated** **периода** → **ломает** **клиентов**.
- **Изменение** **типа** **без** **versioning** → **ломает** **клиентов**.
- **Нет** **monitoring** **deprecated** **эндпоинтов** → **не** **знаешь** **когда** **удалять**.
- **Добавление** **обязательного** **параметра** **без** **default** → **ломает** **старых** **клиентов**.

**Best practice**:
- **Никогда** **не** **ломать** **backwards compatibility** **без** **versioning**.
- **Deprecated** **период** **минимум** **6 мес**.
- **Monitor** **использование** **deprecated** **эндпоинтов**.
- **Changelog** **для** **каждого** **изменения** **API**.
