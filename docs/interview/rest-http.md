# REST / HTTP

### 1. Что такое REST

REST (Representational State Transfer — перенос репрезентации состояния) — это архитектурный стиль для построения распределённых систем, описанный Роем Филдингом в 2000 году. REST не является протоколом или стандартом, это набор архитектурных ограничений (constraints — правила, которые должны соблюдаться):

- **Client-Server** (клиент-сервер — разделение на две роли): разделение ответственности между клиентом (UI/логика представления) и сервером (хранение данных, бизнес-логика).
- **Stateless** (бессостоянный — без сохранения контекста между запросами): каждый запрос содержит всю информацию, необходимую для его обработки; сервер не хранит состояние (state — данные о текущем статусе) клиента между запросами.
- **Cacheable** (кэшируемый — результат может быть закэширован): ответы должны явно или неявно указывать, можно ли их кэшировать (cache — временное хранение для ускорения повторного доступа).
- **Uniform Interface** (единый интерфейс — стандартный способ взаимодействия): ресурсы идентифицируются URI (Uniform Resource Identifier — унифицированный идентификатор ресурса), манипуляция через представления (representation — сериализованная форма ресурса: JSON, XML), самоописываемые сообщения, HATEOAS (Hypermedia as the Engine of Application State — гипермедиа как движок состояния приложения).
- **Layered System** (слойная система — многоступенчатая архитектура): клиент не знает, общается ли он напрямую с сервером или через промежуточные слои (прокси, балансировщики, шлюзы).
- **Code on Demand** (код по запросу — сервер может отдать исполняемый код) (опционально): сервер может передавать клиенту исполняемый код (например, JavaScript).


### 2. Что означает Stateless в контексте REST

**Stateless** означает, что сервер **не хранит состояние клиента** между запросами. Каждый HTTP-запрос должен содержать **всю информацию**, необходимую серверу для его обработки: аутентификационные данные (токен, API-ключ), идентификаторы, параметры и т.д. Сервер не полагается на предыдущие запросы и не хранит сессии в памяти.

Преимущества: масштабируемость (любой экземпляр сервера может обработать любой запрос), простота восстановления после сбоев, отсутствие проблем с синхронизацией сессий между узлами.


### 3. Какие основные HTTP методы используются в REST

- **GET**: получение ресурса (чтение).
- **POST**: создание нового ресурса (или выполнение действия).
- **PUT**: полная замена ресурса или создание по известному URI.
- **PATCH**: частичное обновление ресурса.
- **DELETE**: удаление ресурса.
- **HEAD**: как GET, но без тела ответа (только заголовки).
- **OPTIONS**: получение информации о поддерживаемых методах/CORS-запросах.


### 4. В чём разница между PUT и PATCH

- **PUT** — **полная замена** ресурса. Клиент передаёт **полное представление** ресурса, и сервер заменяет им текущее состояние. Поля, не включённые в запрос, обычно **удаляются** (или сбрасываются к значениям по умолчанию). PUT идемпотентен.
- **PATCH** — **частичное обновление**. Клиент передаёт **только те поля**, которые нужно изменить. Остальные поля остаются нетронутыми. PATCH не обязан быть идемпотентным (хотя может быть, в зависимости от формата патча, например JSON Merge Patch идемпотентен, а JSON Patch с операциями `add`/`remove` — нет).


### 5. Что такое идемпотентность (idempotency)

**Идемпотентность** — это свойство операции, при котором **повторное выполнение** той же операции даёт **тот же результат**, что и однократное. Применительно к HTTP: сколько бы раз вы ни повторили запрос, состояние сервера будет таким же, как после первого успешного выполнения. Идемпотентность **не означает**, что ответ будет идентичным (например, `DELETE` при повторном вызове может вернуть `404` вместо `200`), но **состояние сервера** не изменится.


### 6. Какие HTTP методы идемпотентны

Идемпотентными являются:
- **GET** — только чтение, состояние не меняется.
- **HEAD** — как GET, только заголовки.
- **PUT** — полная замена ресурса; повторная замена тем же представлением даёт то же состояние.
- **DELETE** — удаление ресурса; повторное удаление не меняет состояние (ресурс уже удалён).
- **OPTIONS** — только метаданные.

**POST** и **PATCH** — **не идемпотентны** (POST всегда создаёт новый ресурс при повторном вызове; PATCH может содержать неидемпотентные операции).


### 7. Почему GET и DELETE идемпотентны

- **GET** идемпотентен, потому что это **операция чтения**: он не изменяет состояние сервера. Сколько бы раз вы ни вызвали `GET /users/1`, состояние ресурса останется прежним.
- **DELETE** идемпотентен, потому что **повторное удаление уже удалённого ресурса не меняет состояние** сервера. Первый вызов удаляет ресурс (состояние меняется), последующие вызовы либо возвращают ошибку (`404`), либо успех (`204`), но состояние остаётся «ресурс отсутствует». Главное — **состояние сервера** после N вызовов такое же, как после одного.


### 8. Является ли POST идемпотентным

**Нет**, POST по умолчанию **не идемпотентен**. Каждый вызов `POST /orders` создаёт **новый** заказ. Повторная отправка того же запроса (например, из-за сетевого сбоя) приведёт к созданию дубликата. Для защиты от дублирования используется **idempotency key** — уникальный ключ, передаваемый в заголовке (например, `Idempotency-Key`), по которому сервер распознаёт повторный запрос и возвращает результат первого выполнения.


### 9. Какие HTTP статус коды вы знаете

Статус-коды делятся на пять классов:

- **1xx (Informational)**: `100 Continue`, `101 Switching Protocols`.
- **2xx (Success)**: `200 OK`, `201 Created`, `202 Accepted`, `204 No Content`, `206 Partial Content`.
- **3xx (Redirection)**: `301 Moved Permanently`, `302 Found`, `304 Not Modified`, `307 Temporary Redirect`, `308 Permanent Redirect`.
- **4xx (Client Error)**: `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `405 Method Not Allowed`, `409 Conflict`, `410 Gone`, `422 Unprocessable Entity`, `429 Too Many Requests`.
- **5xx (Server Error)**: `500 Internal Server Error`, `502 Bad Gateway`, `503 Service Unavailable`, `504 Gateway Timeout`.


### 10. В чём разница между 401 и 403

- **`401 Unauthorized`** — клиент **не аутентифицирован**: не предоставил учётные данные или они недействительны (просроченный токен, неверный пароль). Ответ должен содержать заголовок `WWW-Authenticate`, указывающий, как аутентифицироваться. Семантически это «кто ты?».
- **`403 Forbidden`** — клиент **аутентифицирован**, но **не имеет прав** на доступ к ресурсу. Сервер знает, кто вы, но отказывает в доступе. Повторная аутентификация не поможет. Семантически это «я знаю, кто ты, но тебе нельзя».


### 11. Что такое RESTful API дизайн

**RESTful API дизайн** — это проектирование API в соответствии с принципами REST:
- **Ресурсы идентифицируются URI** (существительные, а не глаголы).
- **Единый интерфейс**: стандартные HTTP-методы для CRUD-операций.
- **Stateless**: каждый запрос самодостаточен.
- **Использование HTTP-статусов** для семантики ответов.
- **HATEOAS** (опционально): ответы содержат ссылки на связанные действия/ресурсы.
- **Кэшируемость**, **слоистость**, **клиент-серверное разделение**.
- **Корректное использование заголовков** (`Content-Type`, `Accept`, `ETag`, `Cache-Control`).

```
GET    /api/users            → 200 OK
GET    /api/users/1          → 200 OK
POST   /api/users            → 201 Created
PUT    /api/users/1          → 200 OK
PATCH  /api/users/1          → 200 OK
DELETE /api/users/1          → 204 No Content
```


### 12. Как правильно именовать REST endpoints

Основные правила:
- Использовать **существительные во множественном числе** для коллекций: `/users`, `/orders`, `/products`.
- **Иерархия** для вложенных ресурсов: `/users/1/orders` — заказы пользователя 1.
- **Идентификатор** как часть пути: `/users/1`.
- Использовать **kebab-case** (`/order-items`) или **camelCase** (`/orderItems`) — главное, придерживаться одного стиля.
- **Не использовать расширения** файлов (`.json`, `.xml`) — формат определяется заголовком `Accept`.
- **Не использовать глаголы** в пути для CRUD-операций — для этого есть HTTP-методы.
- **Фильтрация, сортировка, пагинация** — через query-параметры: `/users?age=30&sort=name&page=2&size=20`.


### 13. Стоит ли использовать глаголы в URL

**В большинстве случаев — нет**. Для CRUD-операций семантика уже заложена в HTTP-методы: `GET /users/1` (получить), `DELETE /users/1` (удалить), `PUT /users/1` (заменить). Использование глаголов (`/getUser?id=1`, `/deleteUser?id=1`) — это **RPC-стиль**, а не REST.

**Исключения**: для **действий**, которые не укладываются в CRUD (например, `/orders/1/cancel`, `/users/1/activate`, `/payments/1/refund`), глагол в пути допустим, так как это не манипуляция ресурсом, а команда. Альтернатива — смоделировать действие как ресурс (`POST /orders/1/cancellations`).


### 14. Что такое HATEOAS

**HATEOAS (Hypermedia as the Engine of Application State)** — один из принципов REST, согласно которому сервер в ответе возвращает **гиперссылки** на доступные действия и связанные ресурсы. Клиент не должен знать URL заранее — он «навигируется» по ссылкам, как в веб-браузере.

Пример ответа:
```json
{
  "id": 1,
  "name": "John",
  "links": {
    "self": "/users/1",
    "orders": "/users/1/orders",
    "deactivate": "/users/1/deactivate"
  }
}
```

Преимущества: слабая связанность клиента и сервера, возможность менять URL без поломки клиентов, самоописываемость API. На практике HATEOAS используется редко из-за сложности реализации и отсутствия строгих стандартов формата ссылок.


### 15. Как организовать версионирование REST API

Основные стратегии:
- **URI versioning**: `/api/v1/users` — самый распространённый и простой. Версия видна сразу, легко маршрутизировать. Минус — «загрязняет» URI и нарушает принцип «один ресурс — один URI».
- **Query parameter**: `/api/users?version=1` — проще менять версию, но легко забыть параметр.
- **Custom header**: `X-API-Version: 1` — URI остаётся чистым, но версия не видна в браузере и сложнее кэшировать.
- **Content Negotiation (Accept header)**: `Accept: application/vnd.myapp.v1+json` — самый «RESTful» подход, но сложнее в реализации и отладке.

На практике чаще всего выбирают **URI versioning** за простоту и наглядность. Важно: версия должна быть **явной** и **обратно совместимой** в рамках одной мажорной версии (добавление полей — ок, удаление/переименование — нет).


### 16. Что такое Content-Type header

**`Content-Type`** — заголовок HTTP-запроса или ответа, который указывает **тип и кодировку тела сообщения** (media type). Например:
- `Content-Type: application/json` — тело содержит JSON.
- `Content-Type: application/json; charset=utf-8` — JSON в кодировке UTF-8.
- `Content-Type: application/x-www-form-urlencoded` — данные формы.
- `Content-Type: multipart/form-data` — форма с файлами.

Сервер использует `Content-Type` запроса, чтобы понять, **как десериализовать** тело. Клиент использует `Content-Type` ответа, чтобы понять, **как интерпретировать** полученные данные. Если тип не указан, поведение зависит от реализации и может привести к ошибкам.


### 17. Что такое Accept header

**`Accept`** — заголовок HTTP-запроса, которым клиент сообщает серверу, **какие media types он готов принять** в ответе. Например:
- `Accept: application/json` — клиент хочет JSON.
- `Accept: application/xml, application/json;q=0.9` — предпочитает XML, но примет и JSON (q — вес/приоритет от 0 до 1).
- `Accept: */*` — принимает любой тип.

Сервер через **content negotiation** выбирает наиболее подходящий формат из поддерживаемых и указывает его в `Content-Type` ответа. Если сервер не может предоставить ни один из запрошенных типов, он должен вернуть `406 Not Acceptable`. `Accept` позволяет одному и тому же URI возвращать разные представления ресурса (JSON, XML, HTML) без изменения URL.





### 18. Что такое HTTP/2 и чем он отличается от HTTP/1.1

**HTTP/1.1**:
- **Text-based** (протокол на **тексте**).
- **Head-of-line blocking** (запрос **ждёт** **response** предыдущего).
- **1** **connection** = **1** **request** (или **pipelining** — **rarely** **used**).
- **Keep-alive** (keep **connection** **open**).

**HTTP/2**:
- **Binary-based** (протокол на **байтах**).
- **Multiplexing** (N **requests** на **1** **connection**).
- **No head-of-line blocking** (запрос **не** **ждёт** предыдущего).
- **Header compression** (HPACK).
- **Server push** (сервер **отправляет** **ресурсы** до **запроса**).

**Сравнение**:
| Фича | HTTP/1.1 | HTTP/2 |
|------|----------|--------|
| Encoding | **text** | **binary** |
| Multiplexing | **no** | **yes** (N **requests** на **1** **connection**) |
| Head-of-line blocking | **yes** | **no** |
| Header compression | **no** (manual) | **yes** (HPACK) |
| Server push | **no** | **yes** |
| Priority | **no** | **yes** (priority **hints**) |

**Multiplexing**:
```
HTTP/1.1:
  Request 1 → [wait response 1] → Request 2 → [wait response 2] → ...
  
HTTP/2:
  Request 1, Request 2, Request 3, ... (parallel) → [responses in any order]
```

**Header compression (HPACK)**:
- **Header table** (shared between **client** и **server**).
- **Delta encoding** (только **changes** в **header**).
- **HPACK** — **binary** **format** (не **text**).

**Server push**:
- **Сервер** **отправляет** **ресурсы** до **запроса** (например: **CSS**, **JS**).
- **Problem**: **client** **может** **не** **использовать** **pushed** **ресурсы** (waste).

**Вывод**: **HTTP/2** = **binary** (не **text**), **multiplexing** (N **requests** на **1** **connection**), **no head-of-line blocking**, **HPACK** (header compression), **server push**. **HTTP/1.1** = **text**, **1** **request** на **1** **connection**, **head-of-line blocking**.

### 19. Что такое HTTP/3 (QUIC) и когда он нужен

**HTTP/3** = **HTTP over QUIC** (не **TCP**).

**QUIC** (Quick UDP Internet Connections):
- **UDP-based** (не **TCP**).
- **0-RTT handshake** (no **handshake** **delay**).
- **Multiplexing** (на **transport level**).
- **Forward error correction** (не **retransmit** **lost** **packets**).
- **Connection migration** (смена **IP** без **break** **connection**).

**Сравнение**:
| Фича | HTTP/1.1 (TCP) | HTTP/2 (TCP) | HTTP/3 (QUIC) |
|------|----------------|--------------|---------------|
| Transport | **TCP** | **TCP** | **UDP** |
| Handshake | **1 RTT** (TCP) + **1 RTT** (TLS) = **2 RTT** | **1 RTT** (TCP) + **1 RTT** (TLS) = **2 RTT** | **0 RTT** (QUIC) + **0 RTT** (TLS) = **0 RTT** |
| Multiplexing | **no** | **yes** (application layer) | **yes** (transport layer) |
| Head-of-line blocking | **yes** | **no** (application) | **no** (transport) |
| Header compression | **no** | **yes** (HPACK) | **yes** (QPACK) |
| Connection migration | **no** | **no** | **yes** (UDP) |

**Когда нужен**:
1. **Mobile** (смена **Wi-Fi** ↔ **LTE** без **break** **connection**).
2. **High latency** (0-RTT **handshake**).
3. **Congested network** (forward error correction).
4. **Video streaming** (multiplexing на **transport**).

**Пример (cURL)**:
```bash
# HTTP/3:
curl --http3 https://example.com

# HTTP/2 (fallback):
curl --http2 https://example.com
```

**Вывод**: **HTTP/3** = **QUIC** (UDP-based). **0-RTT** (no **handshake** **delay**), **multiplexing** (transport layer), **forward error correction**, **connection migration** (смена **IP** без **break**). **Когда нужен**: **mobile** (смена **Wi-Fi** ↔ **LTE**), **high latency** (0-RTT), **congested network**, **video streaming**.

### 20. Как работать с HTTP headers: Set-Cookie, Authorization, CORS

**HTTP headers** = **metadata** **request**/**response**.

**Set-Cookie**:
```http
Set-Cookie: session_id=abc123; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=3600
```
- **session_id=abc123** — **cookie** **name**/**value**.
- **Path=/** — **cookie** **доступен** на **все** **paths**.
- **HttpOnly** — **cookie** **недоступен** для **JavaScript** (anti-XSS).
- **Secure** — **cookie** **только** через **HTTPS**.
- **SameSite=Strict** — **cookie** **не отправляется** на **cross-site** **requests** (anti-CSRF).
- **Max-Age=3600** — **cookie** **живёт** **3600** **сек** (1 час).

**Authorization**:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```
- **Bearer** — **scheme** (token в **header**).
- **eyJhbGci...** — **JWT** (JSON Web Token).
- **Basic** (legacy): **Authorization: Basic base64(user:pass)**.

**CORS** (Cross-Origin Resource Sharing):
- **Problem**: **browser** **блокирует** **cross-origin** **requests** (same-origin policy).
- **Solution**: **server** **отправляет** **CORS headers**.

**CORS headers**:
```http
Access-Control-Allow-Origin: https://api.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 3600
```
- **Access-Control-Allow-Origin** — **allowed** **origin** (или `*`).
- **Access-Control-Allow-Methods** — **allowed** **methods**.
- **Access-Control-Allow-Headers** — **allowed** **headers**.
- **Access-Control-Max-Age** — **cache** **CORS** **preflight** (3600 **сек**).

**CORS preflight** (OPTIONS):
```http
OPTIONS /api/orders HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization
```
- **Browser** **отправляет** **OPTIONS** **request** до **actual** **request**.
- **Server** **отвечает** **CORS headers** (**allow**/**deny**).
- **If allowed** → **browser** **отправляет** **actual** **request**.

**Spring Boot CORS**:
```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {
  @Override
  public void addCorsMappings(CorsRegistry registry) {
    registry.addMapping("/api/**")
      .allowedOrigins("https://app.example.com")
      .allowedMethods("GET", "POST", "PUT", "DELETE")
      .allowedHeaders("Content-Type", "Authorization")
      .allowCredentials(true)
      .maxAge(3600);
  }
}
```

**Вывод**: **Set-Cookie** (session, **HttpOnly**, **Secure**, **SameSite**, **Max-Age**). **Authorization** (**Bearer** **JWT**). **CORS** (**Access-Control-Allow-Origin**, **Methods**, **Headers**, **Max-Age**, **preflight** **OPTIONS**). **Spring Boot**: **WebMvcConfigurer** + **addCorsMappings**.

### 21. Что такое HTTP caching: Cache-Control, ETag, If-None-Match

**HTTP caching** = **client** **кэширует** **response** (не **повторяет** **request**).

**Cache-Control**:
```http
Cache-Control: max-age=3600, public, no-cache
```
- **max-age=3600** — **cache** **живёт** **3600** **сек** (1 час).
- **public** — **cache** **допустим** для **shared cache** (прокси).
- **private** — **cache** **только** для **client** (не **shared cache**).
- **no-cache** — **cache** **допустим**, но **нужно** **revalidate** (If-None-Match).
- **no-store** — **не** **кэшировать** (например: **sensitive data**).
- **must-revalidate** — **если** **cache** **expired** → **revalidate** (не **serve** **stale**).
- **stale-while-revalidate=600** — **serve** **stale** **response**, **revalidate** **background**.

**ETag** (Entity Tag):
```http
ETag: "abc123"
```
- **ETag** = **hash** **content** (например: **MD5**, **SHA**).
- **Client** **кэширует** **response** + **ETag**.
- **Next request**: **If-None-Match: "abc123"**.
- **Server**: **если** **ETag** **создаёт** → **304 Not Modified** (no **body**).
- **Если** **ETag** **не** **создаёт** → **200 OK** + **new** **body**.

**If-None-Match**:
```http
If-None-Match: "abc123"
```
- **Client** **отправляет** **ETag** **кэшированного** **response**.
- **Server**: **если** **ETag** **создаёт** → **304 Not Modified**.

**If-Modified-Since**:
```http
If-Modified-Since: Wed, 15 Jan 2025 10:30:00 GMT
```
- **Client** **отправляет** **last-modified** **date**.
- **Server**: **если** **content** **not modified** → **304 Not Modified**.

**Пример**:
```http
GET /api/products/123 HTTP/1.1
If-None-Match: "abc123"

HTTP/1.1 304 Not Modified
ETag: "abc123"
```

**Spring Boot caching**:
```java
@GetMapping("/api/products/{id}")
public ResponseEntity<Product> getProduct(@PathVariable Long id) {
    Product product = productRepo.findById(id).orElseThrow();

    // ETag на основе хэша содержимого
    String etag = "\"" + DigestUtils.md5DigestAsHex(product.toString().getBytes(StandardCharsets.UTF_8)) + "\"";

    return ResponseEntity.ok()
        .cacheControl(CacheControl.maxAge(3600).cachePublic())
        .eTag(etag)
        .body(product);
}

// Обработка If-None-Match (Spring делает это автоматически для ResponseEntity с ETag):
// Если клиент прислал If-None-Match с тем же ETag → Spring вернёт 304 Not Modified без тела.
```

> **Важно:** аннотаций `@CacheControl` и `@ETag` в Spring Boot **не существует**. Кэширование настраивается через `ResponseEntity` (`.cacheControl()`, `.eTag()`) или через `WebMvcConfigurer.addInterceptors()` для глобальной настройки.

**Вывод**: **HTTP caching** = **client** **кэширует** **response**. **Cache-Control** (**max-age**, **public**, **private**, **no-cache**, **no-store**, **must-revalidate**, **stale-while-revalidate**). **ETag** + **If-None-Match** (**304 Not Modified**). **If-Modified-Since** (**last-modified** **date**). **Spring Boot**: **ResponseEntity.cacheControl()** + **ResponseEntity.eTag()** (аннотаций @CacheControl/@ETag нет).

### 22. Как работать с WebSocket и SSE (Server-Sent Events)

**WebSocket** = **full-duplex** **connection** (client ↔ server).
**SSE** (Server-Sent Events) = **server-push** (server → client).

**Сравнение**:
| Фича | WebSocket | SSE |
|------|-----------|-----|
| Direction | **full-duplex** (client ↔ server) | **server-push** (server → client) |
| Protocol | **WS** (upgrade от **HTTP**) | **HTTP** (long-polling) |
| Data format | **binary** или **text** | **text** (UTF-8) |
| Reconnection | **manual** (client) | **auto** (browser) |
| Bandwidth | **low** (binary) | **high** (text) |
| Use case | **real-time** (chat, gaming) | **notifications**, **live updates** |

**WebSocket (Java)**:
```java
// Spring Boot:
@ServerEndpoint("/ws")
public class WsEndpoint {
  @OnMessage
  public void onMessage(String message, Session session) {
    session.getAsyncRemote().sendText("echo: " + message);
  }
}

// Client:
WebSocket ws = new WebSocket("ws://localhost:8080/ws");
ws.onopen = () => ws.send("hello");
ws.onmessage = (e) => console.log(e.data);
```

**SSE (Java)**:
```java
// Spring Boot:
@GetMapping(value = "/events", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public SseEmitter events() {
  SseEmitter emitter = new SseEmitter();
  // Push events:
  new Thread(() -> {
    for (int i = 0; i < 100; i++) {
      emitter.send(SseEmitter.event().data("event-" + i));
      Thread.sleep(1000);
    }
    emitter.complete();
  }).start();
  return emitter;
}

// Client:
EventSource es = new EventSource("http://localhost:8080/events");
es.onmessage = (e) => console.log(e.data);
es.onerror = () => console.error("SSE error");
```

**Когда использовать**:
- **WebSocket**: **real-time** (chat, gaming, collaborative editing).
- **SSE**: **notifications**, **live updates** (например: **stock price**, **feed**).

**Вывод**: **WebSocket** = **full-duplex** (client ↔ server), **binary**/**text**, **manual reconnection**, **real-time** (chat, gaming). **SSE** = **server-push** (server → client), **text** (UTF-8), **auto reconnection**, **notifications**, **live updates**. **Выбор**: **real-time** → **WebSocket**, **notifications** → **SSE**.

### 23. Как правильно проектировать REST API: pagination, filtering, sorting

**Pagination**:
```http
GET /api/products?page=1&size=20&sort=price,desc
```
- **page=1** — **номер** **страницы** (1-based).
- **size=20** — **размер** **страницы** (20 **items**).
- **sort=price,desc** — **sort** по **price** **descending**.

**Filtering**:
```http
GET /api/products?category=electronics&minPrice=100&maxPrice=1000
```
- **category=electronics** — **filter** по **category**.
- **minPrice=100** — **min** **price**.
- **maxPrice=1000** — **max** **price**.

**Spring Boot**:
```java
@GetMapping("/api/products")
public Page<Product> getProducts(
  @RequestParam(defaultValue = "1") int page,
  @RequestParam(defaultValue = "20") int size,
  @RequestParam(defaultValue = "price,desc") String sort,
  @RequestParam(required = false) String category,
  @RequestParam(required = false) Integer minPrice,
  @RequestParam(required = false) Integer maxPrice) {
  Pageable pageable = PageRequest.of(page - 1, size,
    Sort.by(sort.split(",")[0]).descending(sort.contains("desc")));
  return productRepo.findByCategoryAndPriceBetween(category, minPrice, maxPrice, pageable);
}
```

**Response**:
```json
{
  "content": [...],
  "page": 1,
  "size": 20,
  "totalElements": 1000,
  "totalPages": 50,
  "last": false
}
```

**Вывод**: **Pagination** (**page**, **size**, **sort**). **Filtering** (**category**, **minPrice**, **maxPrice**). **Spring Boot**: **@RequestParam**, **Pageable**, **PageRequest**. **Response**: **content**, **page**, **size**, **totalElements**, **totalPages**, **last**.

### 24. Что такое API gateway и когда он нужен

**API gateway** = **single entry point** для **all** **APIs** (reverse proxy).

**Когда нужен**:
1. **Multiple microservices** (например: **10** **services** → **1** **gateway**).
2. **Cross-cutting concerns** (**auth**, **rate limiting**, **logging**).
3. **Protocol translation** (например: **REST** → **gRPC**).
4. **Caching** (**response** **cache** на **gateway**).

**Пример (Spring Cloud Gateway)**:
```java
// application.yml:
spring:
  cloud:
    gateway:
      routes:
        - id: orders-service
          uri: lb://orders-service
          predicates:
            - Path=/api/orders/**
          filters:
            - StripPrefix=1
            - name: RateLimiter
              args:
                replenishRate: 10
                requestedTokens: 2

# /api/orders/123 → orders-service /123
```

**Filters**:
- **StripPrefix** (убрать **prefix** из **path**).
- **RateLimiter** (**rate limiting**).
- **Auth** (**auth** **filter**).
- **Logging** (**logging** **filter**).

**Вывод**: **API gateway** = **single entry point** для **all** **APIs**. **Когда нужен**: **multiple microservices**, **cross-cutting concerns** (**auth**, **rate limiting**, **logging**), **protocol translation**, **caching**. **Spring Cloud Gateway**: **routes**, **predicates**, **filters** (**StripPrefix**, **RateLimiter**, **Auth**, **Logging**).

### 25. Как работает HTTP/2 multiplexing и stream priority

**HTTP/2 multiplexing** = **N** **streams** на **1** **connection**.

**Stream**:
- **1** **request** = **1** **stream**.
- **Stream** имеет **ID** (непарный **ID** для **client**, **чётный** для **server**).
- **Stream** имеет **priority** (**weight**, **dependency**).

**Priority**:
```
Stream 1 (weight=16, no dependency)
Stream 2 (weight=8, depends on Stream 1)
Stream 3 (weight=4, depends on Stream 2)
```
- **Weight** (1-256) — **относительный** **weight** **stream**.
- **Dependency** — **какой** **stream** **ждёт** **этот** **stream**.

**Multiplexing flow**:
```
Client:
  Stream 1 (GET /api/orders) → [wait]
  Stream 2 (GET /api/products) → [wait]
  Stream 3 (GET /api/users) → [wait]

Server:
  Stream 1 (response) → [send]
  Stream 3 (response) → [send]  (higher priority)
  Stream 2 (response) → [send]  (lower priority)
```

**Head-of-line blocking**:
- **HTTP/1.1**: **1** **connection** = **1** **request** → **head-of-line blocking**.
- **HTTP/2**: **N** **streams** на **1** **connection** → **no head-of-line blocking** (application layer).
- **HTTP/3** (QUIC): **no head-of-line blocking** (transport layer, UDP).

**Вывод**: **HTTP/2 multiplexing** = **N** **streams** на **1** **connection** (не **1** **request** на **1** **connection**). **Stream** имеет **ID**, **weight** (1-256), **dependency**. **No head-of-line blocking** (application layer). **HTTP/3** (QUIC): **no head-of-line blocking** (transport layer, UDP).


### 26. gRPC vs REST: когда что использовать

**REST** (HTTP/1.1 + JSON):
- **Плюсы**: читаемость, browser support, кэширование, простота отладки (curl, browser).
- **Минусы**: verbosity JSON, нет streaming из коробки, overhead на сериализацию.
- **Когда использовать**: публичные API, интеграции с внешними клиентами, browser-based приложения.

**gRPC** (HTTP/2 + Protobuf):
- **Плюсы**: бинарный протокол (быстрее JSON в 3–10 раз), HTTP/2 multiplexing, встроенный streaming, code generation из `.proto`, строгие контракты.
- **Минусы**: не читается человеком, нет нативного browser support, сложнее отладка.
- **Когда использовать**: internal service-to-service в микросервисах, high-load системы, streaming данных.

**Сравнение:**

| Критерий | REST | gRPC |
|----------|------|------|
| Протокол | HTTP/1.1 (или 2) | HTTP/2 (обязательно) |
| Формат | JSON (text) | Protobuf (binary) |
| Производительность | Средняя | Высокая (×3–10) |
| Streaming | Нет (только SSE/WebSocket) | Да (4 типа) |
| Browser support | Да | Нет (нужен gRPC-Web + proxy) |
| Кэширование | Да (HTTP cache) | Ограничено |
| Schema | OpenAPI (опционально) | `.proto` (обязательно) |
| Отладка | Просто (curl, browser) | Сложнее (grpcurl, gRPC-Web UI) |

**Типы streaming в gRPC:**

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
flowchart LR
    subgraph "1. Unary"
        C1["Client"] -->|"request"| S1["Server"]
        S1 -->|"response"| C1
    end
    subgraph "2. Server streaming"
        C2["Client"] -->|"request"| S2["Server"]
        S2 -->|"stream of responses"| C2
    end
    subgraph "3. Client streaming"
        C3["Client"] -->|"stream of requests"| S3["Server"]
        S3 -->|"single response"| C3
    end
    subgraph "4. Bidirectional"
        C4["Client"] -->|"stream of requests"| S4["Server"]
        S4 -->|"stream of responses"| C4
    end

    classDef client fill:#e0f2fe,stroke:#0284c7,stroke-width:2px
    classDef server fill:#f0fdf4,stroke:#16a34a,stroke-width:2px
    class C1,C2,C3,C4 client
    class S1,S2,S3,S4 server
```

1. **Unary**: обычный request-response.
2. **Server streaming**: клиент шлёт 1 запрос, сервер стримит ответы.
3. **Client streaming**: клиент стримит запросы, сервер отвечает 1 раз.
4. **Bidirectional streaming**: оба стримят одновременно (chat, real-time data).

**Пример `.proto`:**
```protobuf
syntax = "proto3";

service OrderService {
  rpc GetOrder (OrderRequest) returns (OrderResponse);           // Unary
  rpc StreamOrders (StreamRequest) returns (stream OrderResponse); // Server streaming
  rpc StreamUpdates (stream UpdateRequest) returns (AckResponse);  // Client streaming
  rpc RealtimeData (stream Query) returns (stream Data);          // Bidirectional
}

message OrderRequest { int64 order_id = 1; }
message OrderResponse { int64 order_id = 1; string status = 2; double total = 3; }
```

**Trade-offs:**
- gRPC для internal API → максимальная производительность, но нужна инфраструктура (Envoy для browser).
- REST для public API → максимальная совместимость, но ниже производительность.
- **Гибрид (рекомендация)**: gRPC для internal communication между микросервисами + REST API Gateway для внешних клиентов.

**Follow-up:**
- «Как gRPC работает через браузер?» → gRPC-Web + Envoy proxy (транслирует gRPC-Web → gRPC).
- «Почему gRPC не подходит для публичных API?» → Нет browser support, нет кэширования, сложно для third-party интеграций.
- «Когда REST лучше gRPC даже для internal communication?» → Когда нужна простота, отладка, или команда не знакома с gRPC.


### 27. GraphQL vs REST: когда использовать

**Проблема REST — over/under-fetching:**
- `GET /users/1` возвращает **все** поля пользователя, даже если UI нужен только `name`.
- Для отображения профиля нужны данные из 3 сервисов → 3 отдельных запроса (или N+1).

**GraphQL решает:**
- Клиент запрашивает **ровно те поля**, которые нужны.
- **Single endpoint** (`POST /graphql`) вместо множества REST-эндпоинтов.
- **Schema-first**: `.graphql` файл описывает типы, resolvers маппят на данные.

```graphql
# Schema
type User { id: ID!, name: String, email: String, orders: [Order!]! }
type Order { id: ID!, total: Float, status: String }

# Query (клиент выбирает только нужное)
query {
  user(id: 1) {
    name
    orders {
      total
    }
  }
}
```

**Сравнение:**

| Критерий | REST | GraphQL |
|----------|------|---------|
| Endpoints | Множество (`/users`, `/orders`) | Один (`/graphql`) |
| Fetching | Over/under | Только нужное |
| Кэширование | HTTP cache (GET) | Сложнее (POST, один endpoint) |
| Документация | OpenAPI | Schema (автогенерация) |
| Интроспекция | Нет | Да (built-in) |
| Поддержка браузером | Да | Да |
| Подходящий сценарий | CRUD API, публичный API | Сложные UI, разные клиенты |

**Проблемы GraphQL:**
- **N+1 на сервере**: один запрос может вызвать N резолверов → Dataloaders для батчинга.
- **Кэширование сложнее**: POST-запросы не кэшируются браузером/CDN.
- **Сложные запросы**: клиент может отправить запрос с глубоким вложенным уровнем → нужны лимиты (`query depth`, `max complexity`).
- **Инструменты**: нужен schema registry, code generation, introspection.

**Когда GraphQL оправдан:**
- Разные клиенты (Web, Mobile, IoT) с разными потребностями в данных.
- Сложные UI с агрегацией данных из нескольких сервисов.
- Нужна интроспекция и автогенерация документации.

**Когда overkill:**
- Простой CRUD API с фиксированным набором полей.
- Публичный API с множеством внешних потребителей (кэширование важно).
- Команда не готова к сложностям (N+1, глубина запросов).


### 28. Rate Limiting: паттерны и реализация

**Зачем:** защита от DDoS, защита платных API от злоупотребления, гарантия стабильности.

**Алгоритмы:**

| Алгоритм | Как работает | Плюс | Минус |
|----------|-------------|------|-------|
| **Fixed Window** | Счётчик запросов за фиксированный период (минуту). Сброс в начале окна. | Простой | Burst на границе окон (2×limit за 2 минуты) |
| **Sliding Window** | Считает запросы за скользящий период (последние 60 сек). | Нет burst на границе | Дороже (нужна история) |
| **Token Bucket** | Кад (bucket) на N токенов, пополняется со скоростью R/sec. Запрос = 1 токен. | Гибко, допускает burst до N | Более сложная логика |
| **Leaky Bucket** | Кад переливается со постоянной скоростью R/sec. Избыток отбрасывается. | Сглаживает traffic | Не допускает burst |

**Token Bucket (самый популярный):**

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
flowchart TD
    REQ["Incoming request"] --> CHECK{"Tokens > 0?"}
    CHECK -->|"yes"| DECR["Decrement tokens"]
    DECR --> OK["200 OK"]
    CHECK -->|"no"| REJECT["429 Too Many Requests"]

    REPLEN["Refill: +rate/sec<br/>up to capacity"] -.->|"background"| CHECK

    classDef req fill:#e0f2fe,stroke:#0284c7,stroke-width:2px
    classDef decision fill:#faf5ff,stroke:#9333ea,stroke-width:2px
    classDef action fill:#e0f2fe,stroke:#0284c7,stroke-width:2px
    classDef ok fill:#f0fdf4,stroke:#16a34a,stroke-width:2px
    classDef err fill:#fef2f2,stroke:#dc2626,stroke-width:2px
    classDef refill fill:#fff7ed,stroke:#ea580c,stroke-width:2px
    class REQ req
    class CHECK decision
    class DECR action
    class OK ok
    class REJECT err
    class REPLEN refill
```

**HTTP-заголовки (рекомендация RFC 6585 + IETF draft):**
```http
# Response 200:
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 1700000000

# Response 429:
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
```

**Где хранить счётчики:**
- **In-memory** (Caffeine, ConcurrentHashMap): простой, но не масштабируется на несколько инстансов.
- **Redis**: `INCR` + `EXPIRE` или Lua-скрипт для атомарной проверки. Рекомендуется для distributed rate limiting.

**Spring Boot реализация:**
- **Bucket4j**: `@RateLimiter` + Redis backend.
- **Resilience4j**: `RateLimiter` (in-memory или через кастомный backend).
- **Spring Cloud Gateway**: `RateLimiter` filter (Redis-based).

**Follow-up:**
- «Как реализовать distributed rate limiting?» → Redis + Lua-скрипт (атомарная проверка и инкремент).
- «Почему Token Bucket лучше Fixed Window?» → Нет burst на границе, допускает контролируемый burst до capacity.


### 29. Idempotency Key: как защитить POST от дублирования

**Проблема:** `POST /payments` отправлен, сеть потеряла ответ. Клиент повторяет запрос → **два платежа**.

**Решение — Idempotency Key:**
1. Клиент генерирует уникальный UUID для операции.
2. Передаёт в заголовке `Idempotency-Key: <uuid>`.
3. Сервер проверяет Redis/БД: есть ли уже результат для этого ключа?
   - **Да** → возвращает кэшированный ответ (не выполняет операцию повторно).
   - **Нет** → выполняет операцию, сохраняет результат по ключу, возвращает.
4. TTL ключа: обычно **24 часа** (после этого операция считается "забытой").

```java
@RestController
public class PaymentController {

    @PostMapping("/payments")
    public ResponseEntity<PaymentResponse> pay(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody PaymentRequest request) {

        // 1. Проверяем кэш
        Optional<PaymentResponse> cached = redis.get(idempotencyKey);
        if (cached.isPresent()) {
            return ResponseEntity.ok(cached.get()); // Повторный запрос
        }

        // 2. Выполняем операцию
        PaymentResponse response = paymentService.process(request);

        // 3. Кэшируем результат (TTL 24h)
        redis.setex(idempotencyKey, 86400, response);

        return ResponseEntity.status(201).body(response);
    }
}
```

**Пример из Stripe API:**
```http
POST /v1/charges
Idempotency-Key: a3f8c2e1-7b4d-4e9a-8c6f-1d2e3f4a5b6c
Content-Type: application/json

{ "amount": 5000, "currency": "usd", "source": "tok_visa" }
```
Stripe хранит idempotency key 24 часа. Повторный запрос с тем же ключом вернёт тот же `charge` объект.

**Когда нужен:**
- `POST`/`DELETE` с побочными эффектами (платежи, создание заказов, отправка писем).
- Retries в distributed systems (Kafka consumer, message queue).
- **Не нужен** для `GET` (идемпотентен по определению) и `PUT` (полная замена).

**Важно:**
- Ключ должен быть **уникальным на операцию**, а не на запрос. Повторная та же логическая операция → тот же ключ.
- Хранить результат **до** commit транзакции (иначе race condition).
- Использовать **Redis** (быстро, TTL) или **БД** (надёжно, но медленнее).


### 30. Webhook vs Callback vs Polling: как получать уведомления

**Сравнение:**

| Метод | Направление | Нужен публичный endpoint | Latency | Надёжность |
|-------|-------------|--------------------------|---------|------------|
| **Polling** | Клиент → Сервер (периодический запрос) | Нет | Высокая (зависит от интервала) | Высокая (просто) |
| **Callback** | Сервер → Клиент (по URL из запроса) | Да | Низкая | Средняя (нужны retry) |
| **Webhook** | Сервер → Клиент (зарегистрированный URL + подпись) | Да | Низкая | Высокая (подпись + retry) |

**Polling:**
```
Client: GET /api/orders/123/status (каждые 30 сек)
Server: 200 { "status": "processing" }
... (повторяется до завершения)
```
- **Плюс**: простой, нет публичного endpoint.
- **Минус**: неэффективно (лишние запросы), высокая задержка.

**Callback:**
```
Client: POST /api/jobs { "url": "https://client.com/done", "data": ... }
Server: (выполняет задачу) → POST https://client.com/done { "result": ... }
```
- **Плюс**: push-модель, низкая задержка.
- **Минус**: клиент должен иметь публичный endpoint, нет стандарта подписи.

**Webhook (стандартизированный callback):**
```
1. Клиент регистрирует webhook:
   POST /webhooks { "url": "https://client.com/webhook", "events": ["payment.succeeded"] }

2. Сервер при событии:
   POST https://client.com/webhook
   X-Stripe-Signature: t=1700000000,v1=5257a86aaa...
   Content-Type: application/json
   { "id": "evt_1", "type": "payment.succeeded", "data": {...} }

3. Клиент верифицирует подпись (HMAC-SHA256):
   signature = HMAC_SHA256(webhook_secret, timestamp + "." + payload)
```

**Безопасность webhook:**
- **HMAC-подпись**: сервер подписывает payload секретами, клиент проверяет.
- **Timestamp**: защита от replay-атак (отклонять если `|now - timestamp| > 5 мин`).
- **Retry-политика**: exponential backoff (1 мин, 5 мин, 30 мин, 2 часа, 12 часов).
- **Идемпотентность**: клиент должен обрабатывать повторные webhook-вызовы (однако тот же event ID).

**Когда что использовать:**
- **Polling**: внутренние системы, нет публичного endpoint, low frequency.
- **Callback**: простые интеграции, оба стороны в одном домене.
- **Webhook**: внешние интеграции (Stripe, GitHub, payment gateways), нужна верификация.


### 31. Circuit Breaker: паттерн отказоустойчивости

**Проблема:** внешний сервис падает. Каждый запрос ждёт timeout (5 сек) → поток блокируется → cascade failure.

**Решение — Circuit Breaker:**
- **Closed** (норма): запросы проходят. Считаем ошибки.
- **Open** (срабатывает): после N ошибок подряд → **отказываем сразу** (fail fast), не ждём timeout.
- **Half-Open** (проверка): после timeout-периода пропускаем 1 запрос. Если успех → Closed. Если ошибка → Open снова.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
stateDiagram-v2
    [*] --> Closed
    Closed --> Open: N errors in window
    Open --> HalfOpen: timeout (e.g. 30s)
    HalfOpen --> Closed: test request succeeds
    HalfOpen --> Open: test request fails
    classDef s0 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef s1 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef s2 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    state "Closed" as Closed
    state "Open" as Open
    state "Half-Open" as HalfOpen
    class Closed s0
    class Open s1
    class HalfOpen s2
```

**Spring Boot (Resilience4j):**
```java
@RestController
public class OrderController {

    @CircuitBreaker(name = "inventoryService", fallbackMethod = "fallbackInventory")
    public Inventory checkInventory(@PathVariable Long productId) {
        return inventoryClient.check(productId); // Вызов внешнего сервиса
    }

    // Fallback: вызывается при open circuit или исключении
    private Inventory fallbackInventory(Long productId, Throwable t) {
        return Inventory.unknown(); // Кэшированные данные или дефолт
    }
}
```

```yaml
# application.yml
resilience4j:
  circuitbreaker:
    instances:
      inventoryService:
        failureRateThreshold: 50        # 50% ошибок → open
        slidingWindowType: COUNT_BASED
        slidingWindowSize: 10           # окно из 10 запросов
        waitDurationInOpenState: 30s    # 30 сек в open state
        permittedNumberOfCallsInHalfOpenState: 3
```

**Когда использовать:**
- Вызовы внешних API (payment gateways, email, SMS).
- Вызовы других микросервисов.
- БД-операции (если БД может деградировать).

**Trade-offs:**
- **Плюс**: fail fast (миллисекунды вместо секунд), защита от cascade failure.
- **Минус**: сложность, нужно правильно настроить пороги (слишком чувствительный → false positive).

**Связь с другими паттерни:**
- **Timeout**: circuit breaker часто комбинируется с timeout (Resilience4j `@TimeLimiter`).
- **Retry**: retry **внутри** circuit breaker (не наоборот — иначе retry-шторм).
- **Bulkhead**: ограничение числа concurrent-вызовов (отдельный паттерн).


### 32. OpenAPI / Swagger: документирование REST API

**OpenAPI 3.0** — стандарт де-факто для описания REST API (YAML/JSON).

**Что описывает:**
- Endpoints (path, method, params, request body, responses).
- Схемы (сущности, DTO, enum).
- Security schemes (OAuth2, API key, Bearer).
- Серверы (base URL, environment).

**Пример (YAML):**
```yaml
openapi: 3.0.3
info:
  title: Order API
  version: 1.0.0
servers:
  - url: https://api.example.com/v1
paths:
  /orders:
    get:
      operationId: listOrders
      parameters:
        - name: page
          in: query
          schema: { type: integer, default: 1 }
        - name: size
          in: query
          schema: { type: integer, default: 20 }
      responses:
        '200':
          description: List of orders
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OrderList'
    post:
      operationId: createOrder
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
      responses:
        '201':
          description: Created
          headers:
            Location:
              schema: { type: string, format: uri }
components:
  schemas:
    CreateOrderRequest:
      type: object
      required: [customerId, items]
      properties:
        customerId: { type: string, format: uuid }
        items:
          type: array
          items:
            $ref: '#/components/schemas/OrderItem'
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
security:
  - bearerAuth: []
```

**Springdoc-openapi (автогенерация из Spring Boot кода):**
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.5.0</version>
</dependency>
```
```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
```
- Swagger UI доступен по `/swagger-ui.html`.
- OpenAPI JSON — по `/api-docs`.
- Автогенерация из `@RestController` + `@Operation`, `@Schema` аннотаций.

**Code-first vs Design-first:**
- **Code-first**: пишем Java-код → springdoc генерирует OpenAPI. Быстро, но documentation лags behind.
- **Design-first**: пишем OpenAPI YAML → генерируем клиент/сервер код. Лучший для команды, где API меняется редко.

**Когда нужен:**
- Публичный API (внешние потребители).
- Большая команда (несколько сервисов).
- Нужна автогенерация клиентского кода.


### 33. BFF (Backend for Frontend) паттерн

**Проблема микросервисов:** один UI (Web/Mobile) нуждается в данных из 5–10 микросервисов. Каждый запрос UI → 5+ HTTP-вызовов к разным сервисам → N+1 на клиенте.

**Решение — BFF:**
- Отдельный слой API, который **агрегирует** данные из нескольких микросервисов и отдаёт **один ответ** под конкретный UI.
- Разные BFF для разных клиентов: Web BFF, Mobile BFF, IoT BFF.

```
Web Client → Web BFF → [Order Service, User Service, Payment Service, Inventory Service]
Mobile Client → Mobile BFF → [Order Service, User Service, Notification Service]
```

**Когда использовать:**
- Разные клиенты с разными потребностями (Web показывает 10 полей, Mobile — 3).
- Агрегация данных из 3+ микросервисов в один ответ.
- Оптимизация payload под конкретный клиент (Mobile → меньше данных).

**Когда не нужен:**
- Один клиент, один сервис (overkill).
- Простой CRUD API.

**Trade-offs:**
- **Плюс**: меньше запросов с клиента, оптимизация payload, изоляция клиентов.
- **Минус**: ещё один слой (latency), дублирование логики между BFF, сложнее deployment.


### 34. API Security: чек-лист безопасности

| # | Тема | Рекомендация |
|---|------|--------------|
| 1 | **HTTPS** | Всегда TLS 1.2+. HSTS header (`Strict-Transport-Security`). |
| 2 | **Аутентификация** | OAuth2 / JWT для user-to-service. API key для machine-to-machine. |
| 3 | **Авторизация** | RBAC/ABAC. Не полагаться только на аутентификацию. |
| 4 | **Input validation** | `@Valid` + Bean Validation (`@Size`, `@Pattern`, `@NotNull`). Whitelist, не blacklist. |
| 5 | **SQL Injection** | Parameterized queries (JPA, PreparedStatement). Никогда не конкатенация SQL. |
| 6 | **XSS** | `Content-Security-Policy` header. Escape HTML в ответах. |
| 7 | **Rate limiting** | Защита от brute force и DDoS (см. Q28). |
| 8 | **CORS** | Не использовать `*` с `credentials: true`. Whitelist origin. |
| 9 | **Секреты** | Не логировать токены, API keys, пароли. Env vars / secrets manager. |
| 10 | **Ошибки** | Не раскрывать stack trace в production. ProblemDetail (RFC 7807). |
| 11 | **CORS + Preflight** | Кэшировать preflight (`Access-Control-Max-Age`). |
| 12 | **Webhook** | HMAC-подпись + timestamp verification (см. Q30). |

**Пример ProblemDetail (RFC 7807):**
```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation failed",
  "status": 422,
  "detail": "Field 'email' is invalid",
  "errors": {
    "email": "Must be a valid email address"
  }
}
```


### 35. API Contract Testing: Pact и другие подходы

**Проблема:** микросервис A вызывает B. B меняет API (переименовал поле) → A ломается. Обнаруживается только в integration test (дорого) или в production.

**Решение — Contract Testing:**
- **Consumer-driven contract**: потребитель (A) описывает, что он ожидает от провайдера (B). Провайдер проверяет, что его API соответствует контракту.
- **OpenAPI-based**: провайдер публикует OpenAPI spec, потребитель генерирует mock из неё и проверяет совместимость.

**Pact (consumer-driven):**
```
1. Consumer (A) пишет тест с mock-сервером:
   - Ожидает: GET /orders/123 → 200 { "id": 123, "status": "shipped" }
   - Pact-файл: { "consumer": "A", "provider": "B", "interactions": [...] }

2. Provider (B) запускает verification:
   - Проверяет свой API против pact-файла.
   - Если несовместимость → CI падает **до** deployment.
```

**Когда использовать:**
- Микросервисы (10+ сервисов, часто меняются).
- Публичный API с внешними потребителями.
- CI/CD pipeline с автоматической проверкой совместимости.

**Trade-offs:**
- **Плюс**: раннее обнаружение breaking changes, независимость consumer/provider.
- **Минус**: сложность настройки (Pact Broker), overhead на тестирование.


### 36. Common Pitfalls: частые ошибки в REST API

| # | Ошибка | Последствие | Решение |
|---|--------|-------------|---------|
| 1 | `GET` с побочными эффектами | Нарушение идемпотентности, кэширование GET с мутациями | Использовать `POST`/`PUT`/`DELETE` для мутаций |
| 2 | Отсутствие `Retry-After` в `429` | Клиент не знает, когда повторять | Всегда добавлять `Retry-After: <seconds>` |
| 3 | `Access-Control-Allow-Origin: *` + `credentials: true` | Браузер **запрещает** (CORS spec) | Указывать конкретный origin или не использовать credentials |
| 4 | Чувствительные данные в URL (query params) | Логируются в proxy, browser history, referer header | Переносить в body (POST) или header |
| 5 | Отсутствие idempotency для `POST`/`DELETE` | Дубликаты при retry | `Idempotency-Key` header + Redis (см. Q29) |
| 6 | Версионирование через `Accept` header | Сложно кэшировать, debug, test | URI versioning (`/api/v1/`) |
| 7 | `PUT` с частичным payload | Поля, не переданные, сбрасываются | Использовать `PATCH` для частичного обновления |
| 8 | `404` для защищённых ресурсов | Раскрытие существования ресурса | `403` для аутентифицированных без права, `404` для анонимных |
| 9 | Нет rate limiting на публичных API | DDoS, brute force | Rate limiter на gateway (см. Q28) |
| 10 | Stack trace в production error | Раскрытие информации о внутреннем состоянии | ProblemDetail (RFC 7807), generic message |

> 🔗 Про OAuth2 flows — см. `spring-security.md`.
> 🔗 Про ProblemDetail (RFC 7807) — см. `spring-boot.md`.
> 🔗 Про Circuit Breaker / Resilience4j — см. `spring-boot.md`.

