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
@CacheControl(maxAge = 3600, cachePublic = true)
@ETag("product-{id}")
public Product getProduct(@PathVariable Long id) {
  return productRepo.findById(id);
}
```

**Вывод**: **HTTP caching** = **client** **кэширует** **response**. **Cache-Control** (**max-age**, **public**, **private**, **no-cache**, **no-store**, **must-revalidate**, **stale-while-revalidate**). **ETag** + **If-None-Match** (**304 Not Modified**). **If-Modified-Since** (**last-modified** **date**). **Spring Boot**: **@CacheControl**, **@ETag**.

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

