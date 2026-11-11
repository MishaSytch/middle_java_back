# Глава 20. HTTP-клиенты: `RestClient`, HTTP-интерфейсы, таймауты и устойчивость

> **Уровень:** junior → middle+
> **Время:** 3 часа
> **Цель:** ходить во внешние сервисы так, чтобы падение соседа не уронило вас: правильные таймауты, пулы, retry, circuit breaker и наблюдаемость.

## 20.1. Ландшафт клиентов (и что выбирать в 2026)

| Клиент | Модель | Статус | Когда |
|---|---|---|---|
| `RestClient` | синхронный, fluent | **рекомендуется** | imperative-стек (наш случай) |
| HTTP-интерфейсы (`@HttpExchange`) | декларативный | **рекомендуется** | много клиентов, «интерфейс вместо кода» |
| `WebClient` | реактивный | актуален | WebFlux, стриминг, много параллельных вызовов |
| `RestTemplate` | синхронный, старый | **deprecated в документации 7.0**, `@Deprecated` в 7.1 | legacy-код |
| OpenFeign (Spring Cloud) | декларативный | актуален | Cloud-стек |

🎯 Официальная позиция Spring: `RestTemplate` «feature complete» и не развивается; новый код — `RestClient` или HTTP-интерфейсы. В Boot 4 они вынесены в отдельный стартер **`spring-boot-starter-restclient`**.

## 20.2. `RestClient`: полный рабочий пример

```java
@Configuration(proxyBeanMethods = false)
class ClientsConfig {

    @Bean
    RestClient paymentsClient(RestClient.Builder builder, PaymentProperties props) {
        return builder
            .baseUrl(props.url())
            .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
            .defaultHeader("X-App", "taskflow")
            .requestFactory(ClientHttpRequestFactoryBuilder.httpComponents()   // Apache HttpClient 5: пул
                    .build(ClientHttpRequestFactorySettings.defaults()
                            .withConnectTimeout(Duration.ofSeconds(2))
                            .withReadTimeout(Duration.ofSeconds(5))))
            .requestInterceptor((request, body, execution) -> {
                var id = MDC.get("requestId");
                if (id != null) request.getHeaders().add("X-Request-Id", id);
                return execution.execute(request, body);
            })
            .build();
    }
}
```

```java
@Service
@RequiredArgsConstructor
class PaymentsGateway {
    private final RestClient paymentsClient;

    public Receipt charge(ChargeRequest req) {
        return paymentsClient.post()
                .uri("/v1/charges")
                .header("Idempotency-Key", req.idempotencyKey())
                .contentType(MediaType.APPLICATION_JSON)
                .body(req)
                .retrieve()
                .onStatus(HttpStatusCode::is4xxClientError, (request, response) -> {
                    var problem = response.bodyTo(ProblemDetail.class);
                    throw new PaymentRejectedException(problem == null ? "отклонено" : problem.getDetail());
                })
                .onStatus(HttpStatusCode::is5xxServerError, (request, response) -> {
                    throw new PaymentUnavailableException("Шлюз недоступен: " + response.getStatusCode());
                })
                .body(Receipt.class);
    }

    public Optional<Receipt> find(String id) {
        return paymentsClient.get().uri("/v1/charges/{id}", id)
                .exchange((request, response) -> response.getStatusCode().value() == 404
                        ? Optional.empty()
                        : Optional.ofNullable(response.bodyTo(Receipt.class)));
    }

    public List<Receipt> list(String owner) {
        return paymentsClient.get()
                .uri(b -> b.path("/v1/charges").queryParam("owner", owner).build())
                .retrieve()
                .body(new ParameterizedTypeReference<List<Receipt>>() {});
    }
}
```

Ключевые моменты:
* `retrieve()` — «обычный» путь с автоматическим броском на 4xx/5xx; `exchange()` — полный контроль (не забудьте закрыть/прочитать ответ).
* `ParameterizedTypeReference` — для дженериков (`List<T>`), иначе erasure.
* **Таймауты обязательны.** Без них один зависший сосед исчерпает пул потоков/соединений и уронит ваш сервис.
* `ClientHttpRequestFactoryBuilder` **[Boot 3.4+/4.x]** — единый способ выбрать движок: `jdk()`, `httpComponents()`, `jetty()`, `reactor()`, `simple()`.
* **[4.x]** при `spring.threads.virtual.enabled=true` авто-конфигурируемый JDK `HttpClient` использует виртуальные потоки.

### Пул соединений
```java
@Bean
ClientHttpRequestFactory requestFactory() {
    var cm = PoolingHttpClientConnectionManagerBuilder.create()
            .setMaxConnTotal(200)
            .setMaxConnPerRoute(50)                       // ← дефолт 5! главная причина «тормозит под нагрузкой»
            .setDefaultConnectionConfig(ConnectionConfig.custom()
                    .setConnectTimeout(Timeout.ofSeconds(2))
                    .setSocketTimeout(Timeout.ofSeconds(5))
                    .setValidateAfterInactivity(TimeValue.ofSeconds(10))
                    .build())
            .build();
    var client = HttpClients.custom()
            .setConnectionManager(cm)
            .evictIdleConnections(TimeValue.ofMinutes(1))
            .build();
    return new HttpComponentsClientHttpRequestFactory(client);
}
```
🎯 `maxConnPerRoute` по умолчанию в Apache HttpClient — **5**. Это классическая причина «сервис ходит в соседа только 5 запросами параллельно».

## 20.3. HTTP-интерфейсы: декларативные клиенты

```java
@HttpExchange(url = "/v1/charges", accept = "application/json", contentType = "application/json")
public interface PaymentsApi {
    @PostExchange
    Receipt charge(@RequestBody ChargeRequest req, @RequestHeader("Idempotency-Key") String key);

    @GetExchange("/{id}")
    Receipt get(@PathVariable String id);

    @GetExchange
    List<Receipt> list(@RequestParam String owner);

    @DeleteExchange("/{id}")
    void cancel(@PathVariable String id);
}
```

**[4.x / Framework 7]** групповая регистрация — не нужно руками создавать каждый прокси:
```java
@Configuration(proxyBeanMethods = false)
@ImportHttpServices(group = "payments", types = {PaymentsApi.class, RefundsApi.class})
@ImportHttpServices(group = "crm",      types = {CrmApi.class})
class HttpServicesConfig extends AbstractHttpServiceRegistrar {

    @Bean
    RestClientHttpServiceGroupConfigurer groupConfigurer(PaymentProperties props) {
        return groups -> groups
            .filterByName("payments")
            .forEachClient((group, builder) -> builder
                .baseUrl(props.url())
                .defaultHeader("X-App", "taskflow")
                .requestFactory(paymentsRequestFactory()));
    }
}
```
Boot 4 добавляет автоконфигурацию и свойства для HTTP-клиентов (`spring.http.client.*`, групповые настройки базовых URL).

**[3.5]** регистрация вручную:
```java
@Bean
PaymentsApi paymentsApi(RestClient paymentsClient) {
    var adapter = RestClientAdapter.create(paymentsClient);
    var factory = HttpServiceProxyFactory.builderFor(adapter).build();
    return factory.createClient(PaymentsApi.class);
}
```

Плюсы интерфейсов: контракт в одном месте, тестируемость (легко подменить моком), меньше boilerplate, поддержка `InputStream`/`OutputStream` **[7.0]**, версионирование API на клиенте.

## 20.4. Устойчивость: таймауты → retry → circuit breaker → bulkhead

```text
Таймаут (connect + read)  — обязательный минимум
   ↓
Retry с backoff + jitter  — только идемпотентные операции / с Idempotency-Key
   ↓
Circuit Breaker           — не долбить лежащего соседа
   ↓
Bulkhead / ConcurrencyLimit — изоляция ресурсов
   ↓
Fallback                  — деградация вместо ошибки
```

**[4.x] штатными средствами Framework 7:**
```java
@Configuration @EnableResilientMethods class ResilienceConfig {}

@Service
class PaymentsGateway {
    @Retryable(includes = {IOException.class, PaymentUnavailableException.class},
               maxAttempts = 3, delay = 200, multiplier = 2, maxDelay = 2000)
    @ConcurrencyLimit(20)
    public Receipt charge(ChargeRequest req) { ... }
}
```
**[3.5]** Spring Retry:
```java
@EnableRetry
@Retryable(retryFor = IOException.class, maxAttempts = 3, backoff = @Backoff(delay = 200, multiplier = 2))
public Receipt charge(...) { ... }
@Recover Receipt fallback(IOException e, ChargeRequest req) { ... }
```
Circuit breaker — Resilience4j (`resilience4j-spring-boot3`):
```java
@CircuitBreaker(name = "payments", fallbackMethod = "fallback")
@TimeLimiter(name = "payments")
public Receipt charge(...) { ... }
```
```yaml
resilience4j.circuitbreaker.instances.payments:
  slidingWindowSize: 50
  failureRateThreshold: 50
  waitDurationInOpenState: 10s
  permittedNumberOfCallsInHalfOpenState: 5
```

🪤 **Правила retry, которые нарушают чаще всего:**
1. Retry **только** для идемпотентных операций (GET, PUT, DELETE) или с идемпотентным ключом. Retry POST без ключа = двойное списание.
2. Retry **не** на 4xx (кроме 408/429) — это ошибка запроса, повтор не поможет.
3. Экспоненциальный backoff **+ jitter**, иначе синхронный «залп» от всех инстансов.
4. Ограниченный бюджет повторов (retry budget), иначе retry усиливает аварию (retry storm).
5. Retry снаружи транзакции (глава 13).
6. Общий дедлайн запроса: суммарное время попыток < таймаута клиента, который вас вызвал.

## 20.5. Наблюдаемость клиентских вызовов

Boot автоматически инструментирует `RestClient`/`RestTemplate`/`WebClient`, если в контексте есть `ObservationRegistry`:
```text
http.client.requests{method,uri,status,outcome,clientName}   — метрики + трейс-спан
```
* W3C `traceparent` пропагируется автоматически (Micrometer Tracing) → сквозной трейс между сервисами.
* `uri` тег должен быть **шаблоном** (`/v1/charges/{id}`), а не конкретным id — иначе взрыв кардинальности метрик. `RestClient` делает это правильно, если вы используете `uri("...{id}", id)`.
* Логируйте исходящие вызовы на DEBUG с временем и статусом, но **не** тела с секретами.

## 20.6. Тестирование клиентов

**Без сети — `MockRestServiceServer`:**
```java
@SpringBootTest
class PaymentsGatewayTest {
    @Autowired RestClient.Builder builder;
    private MockRestServiceServer server;
    private PaymentsGateway gateway;

    @BeforeEach void setup() {
        var b = builder.baseUrl("http://payments");
        server = MockRestServiceServer.bindTo(b).build();
        gateway = new PaymentsGateway(b.build());
    }

    @Test void parsesReceipt() {
        server.expect(requestTo("http://payments/v1/charges"))
              .andExpect(method(HttpMethod.POST))
              .andRespond(withSuccess("""
                  {"id":"ch_1","status":"OK"}
                  """, MediaType.APPLICATION_JSON));
        assertThat(gateway.charge(req).id()).isEqualTo("ch_1");
        server.verify();
    }
}
```

**С «настоящим» сервером — WireMock** (проверка таймаутов, retry, 5xx):
```java
stubFor(post("/v1/charges").willReturn(aResponse().withFixedDelay(6000).withStatus(200)));
// ожидаем таймаут и корректную ошибку
```

**[4.x] `RestTestClient`** — для тестирования **своего** API (замена `TestRestTemplate`), см. главу 23.

🎯 Обязательные тесты для каждого внешнего клиента: успех, 4xx, 5xx, таймаут, невалидный JSON. Без них вы узнаете о поведении в проде.

## 20.7. WebClient: когда всё-таки он

Нужен, если: реактивный стек, стриминг (`Flux<T>`, SSE), тысячи параллельных вызовов с малым числом потоков, `WebFlux`-сервер. В imperative-приложении с виртуальными потоками `RestClient` проще и достаточно.

```java
WebClient client = WebClient.builder().baseUrl("https://api").build();
Mono<Receipt> mono = client.post().uri("/charges").bodyValue(req).retrieve().bodyToMono(Receipt.class);
Flux<Receipt> stream = client.get().uri("/charges/stream").retrieve().bodyToFlux(Receipt.class);
```
🪤 `.block()` внутри реактивного pipeline — запрещён (deadlock). В imperative-коде — допустим, но тогда зачем WebClient?

## 20.8. 🪤 Топ-10 граблей HTTP-клиентов

1. Нет таймаутов → каскадный отказ.
2. `maxConnPerRoute=5` по умолчанию → «тормозит под нагрузкой».
3. Retry неидемпотентного POST.
4. Retry на 4xx.
5. Backoff без jitter → синхронные залпы.
6. `uri` с конкретными id в метриках → кардинальность.
7. Секреты в логах запросов.
8. `exchange()` без чтения/закрытия ответа → утечка соединений.
9. Игнорирование DNS-кэша JVM (`networkaddress.cache.ttl`) при переключении IP.
10. Один клиент на все соседи с общим пулом → один медленный сосед блокирует остальных (нужен bulkhead).

## 20.9. 🧪 Практика

1. Соберите `RestClient` с таймаутами, пулом и correlation-interceptor.
2. Опишите тот же клиент как HTTP-интерфейс и сравните объём кода.
3. Добавьте `@Retryable` + `@ConcurrencyLimit` **[4.x]** / Spring Retry **[3.5]**.
4. Напишите 5 тестов: успех, 400, 500, таймаут, битый JSON.
5. Проверьте в `/actuator/metrics/http.client.requests`, что тег `uri` — шаблон.
6. Смоделируйте «медленного соседа» (WireMock delay) и убедитесь, что ваш сервис остаётся живым.

## 20.10. Вопросы

1) Почему `RestTemplate` не рекомендуется? 2) Чем `retrieve()` отличается от `exchange()`? 3) Какие таймауты нужно задать и почему оба? 4) Когда retry опасен? 5) Что делает circuit breaker и какие у него состояния? 6) Зачем jitter? 7) Как избежать взрыва кардинальности метрик? 8) Как протестировать таймаут без реального сервиса?

---

**Назад:** [Глава 19](19-rest-api-proektirovanie.md) · **Дальше:** [Глава 21. Spring Security: основы →](21-security-osnovy.md)