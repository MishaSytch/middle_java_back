# Глава 18. Spring MVC изнутри: `DispatcherServlet`, конвертеры, ошибки, async

> **Уровень:** junior → middle+ (ключевая глава книги)
> **Время:** 5–6 часов
> **Цель:** знать весь путь HTTP-запроса, уметь расширять MVC в правильных точках, строить единый контракт ошибок и не бояться `HttpMessageNotReadableException`.

## 18.1. Модель выполнения

```text
Клиент → Tomcat 11 (Servlet 6.1) → Filter chain → DispatcherServlet → Handler → ответ
```
* Классика: **поток на запрос**. Пул Tomcat (`server.tomcat.threads.max=200`) ограничивает параллелизм.
* **[Boot 3.2+/4.x]** `spring.threads.virtual.enabled=true` → **виртуальный поток на запрос**. Блокирующий JDBC больше не «съедает» OS-поток; параллелизм ограничен уже не потоками, а пулом соединений и БД.
* Reactive (WebFlux) — другая модель; в этой книге мы строим imperative-стек (он покрывает 95 % продуктов и с виртуальными потоками масштабируется отлично).

```yaml
server:
  port: 8080
  shutdown: graceful
  tomcat:
    threads: { max: 200, min-spare: 20 }
    max-connections: 8192
    accept-count: 100
    connection-timeout: 5s
    max-http-form-post-size: 2MB
  compression: { enabled: true, mime-types: application/json, min-response-size: 1024 }
  error:
    include-message: never          # не отдавать внутренние сообщения наружу
    include-stacktrace: never
spring:
  threads.virtual.enabled: true
  lifecycle.timeout-per-shutdown-phase: 30s
```

## 18.2. ⚙️ `DispatcherServlet#doDispatch`: девять шагов

```text
1. checkMultipart(request)                       // разбор multipart
2. getHandler(request)                           // HandlerMapping → HandlerExecutionChain (handler + interceptors)
      RequestMappingHandlerMapping: PathPattern-матчинг, учёт params/headers/consumes/produces, API version [7.0]
3. getHandlerAdapter(handler)                    // RequestMappingHandlerAdapter для @RequestMapping
4. interceptor.preHandle(...)                    // HandlerInterceptor: до контроллера
5. ha.handle(...) → invokeHandlerMethod
      ├─ ServletInvocableHandlerMethod
      ├─ HandlerMethodArgumentResolverComposite  // 26+ резолверов: @PathVariable, @RequestParam,
      │                                          // @RequestBody (через HttpMessageConverter), Model, Principal...
      ├─ вызов вашего метода
      └─ HandlerMethodReturnValueHandlerComposite // @ResponseBody → converter, ResponseEntity, String→view,
                                                 // ModelAndView, Callable/DeferredResult → async
6. interceptor.postHandle(...)
7. processDispatchResult → ViewResolver + render (для REST не используется)
8. interceptor.afterCompletion(...)
9. при исключении → HandlerExceptionResolverComposite
      ├─ ExceptionHandlerExceptionResolver   (@ExceptionHandler / @RestControllerAdvice)
      ├─ ResponseStatusExceptionResolver     (@ResponseStatus, ResponseStatusException)
      └─ DefaultHandlerExceptionResolver     (стандартные Spring-исключения → 400/405/415...)
```

**Зачем это знать:** любой «странный» статус (400 вместо 422, 415, 406) объясняется на шаге 5 или 9. Например, `HttpMessageNotReadableException` (невалидный JSON) → `DefaultHandlerExceptionResolver` → **400**, и ваш `@ExceptionHandler(Exception.class)` его не увидит, если вы наследуете `ResponseEntityExceptionHandler` (он уже обработал).

## 18.3. Filter vs Interceptor vs AOP: где что делать

| | Уровень | Видит | Типичное применение |
|---|---|---|---|
| `Filter` (Servlet) | до `DispatcherServlet` | сырой request/response, тело (обёртки) | correlation id, security, сжатие, rate limit, логирование доступа |
| `HandlerInterceptor` | внутри MVC | `HandlerMethod`, модель | авторизация по аннотациям, аудит, метрики по контроллеру |
| AOP (`@Around`) | вокруг бина | аргументы/результат метода | бизнес-аспекты, кэш, retry |

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
class AccessLogFilter extends OncePerRequestFilter {
    @Override protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        long t0 = System.nanoTime();
        try { chain.doFilter(req, res); }
        finally {
            log.info("{} {} → {} ({} мс)", req.getMethod(), req.getRequestURI(), res.getStatus(),
                     (System.nanoTime()-t0)/1_000_000);
        }
    }
}

@Component
class TimingInterceptor implements HandlerInterceptor {
    @Override public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        if (handler instanceof HandlerMethod hm) req.setAttribute("handler", hm.getMethod().getName());
        return true;
    }
}

@Configuration
class WebConfig implements WebMvcConfigurer {
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new TimingInterceptor()).addPathPatterns("/api/**");
    }
}
```
🪤 `OncePerRequestFilter` — чтобы не выполняться дважды при `FORWARD`/`ERROR` dispatch. Обычный `Filter` может отработать повторно.

## 18.4. Контроллер: полный набор приёмов

```java
@RestController
@RequestMapping("/api/tasks")
@Validated
@RequiredArgsConstructor
class TaskController {
    private final TaskService service;

    @GetMapping("/{id}")
    TaskView get(@PathVariable @Positive Long id) { return service.find(id); }

    @GetMapping
    Page<TaskView> list(@RequestParam(required = false) Status status,
                        @RequestParam(defaultValue = "0") @Min(0) int page,
                        @RequestParam(defaultValue = "20") @Max(100) int size,
                        @SortDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return service.list(status, pageable);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    ResponseEntity<TaskView> create(@Valid @RequestBody CreateTaskRequest req, UriComponentsBuilder uri) {
        var created = service.create(req);
        return ResponseEntity.created(uri.path("/api/tasks/{id}").build(created.id())).body(created);
    }

    @PatchMapping("/{id}")
    TaskView patch(@PathVariable Long id, @Valid @RequestBody PatchTaskRequest req) { return service.patch(id, req); }

    @DeleteMapping("/{id}")
    @ResponseStatus(NO_CONTENT)
    void delete(@PathVariable Long id) { service.delete(id); }

    @GetMapping(value = "/export", produces = "text/csv")
    ResponseEntity<StreamingResponseBody> export() { ... }
}
```

Ключевые различия:
* `@RequestBody` → `HttpMessageConverter` (JSON), валидация `@Valid`.
* `@ModelAttribute` → data binding из query/form, **не** JSON.
* `@RequestParam` — простой параметр; `@PathVariable` — часть пути; `@MatrixVariable` — `;k=v` (нужно включить).
* `@RequestHeader`, `@CookieValue`, `Principal`/`Authentication`, `HttpServletRequest` — тоже резолвятся.
* Валидация параметров метода (`@Positive Long id`) требует `@Validated` **на классе** и работает через `MethodValidationPostProcessor`; ошибка → `ConstraintViolationException` (не `MethodArgumentNotValidException`!). Это разные обработчики.

🪤 **[Framework 6.1+]** Для контроллеров встроенная method-validation может конфликтовать с `@Validated`-прокси; в 7.x рекомендуется полагаться на встроенную валидацию аргументов контроллера и не дублировать. Практический совет: валидируйте DTO через `@Valid @RequestBody`, а простые параметры — вручную или через `@Validated` + обработчик `ConstraintViolationException`.

## 18.5. JSON: Jackson 3 **[4.x]** vs Jackson 2 **[3.5]**

| | 3.5 (Jackson 2) | 4.x (Jackson 3) |
|---|---|---|
| Пакеты | `com.fasterxml.jackson.databind` | **`tools.jackson.databind`** (аннотации остались `com.fasterxml.jackson.annotation`) |
| Бин | `ObjectMapper` | **`JsonMapper`** (+ `XmlMapper` для XML) |
| Кастомайзер | `Jackson2ObjectMapperBuilderCustomizer` | **`JsonMapperBuilderCustomizer`** |
| Свой сериализатор | `@JsonComponent` | **`@JacksonComponent`** |
| Mixin | `@JsonMixin` | **`@JacksonMixin`** |
| Свойства | `spring.jackson.*` | `spring.jackson.*`, JSON-специфичные — `spring.jackson.json.read/write.*` |
| Модули | «well-known» | **все** найденные в classpath (`spring.jackson.find-and-add-modules=false` чтобы выключить) |
| Совместимость | — | `spring.jackson.use-jackson2-defaults=true`, модуль `spring-boot-jackson2` (deprecated) |

```java
// [4.x] кастомизация
@Bean
JsonMapperBuilderCustomizer jsonCustomizer() {
    return builder -> builder
        .disable(DateTimeFeature.WRITE_DATES_AS_TIMESTAMPS)
        .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)   // строгий контракт
        .changeDefaultPropertyInclusion(incl -> incl.withValueInclusion(JsonInclude.Include.NON_NULL));
}

// Полная замена (в 4.x нужно объявить именно JsonMapper, не ObjectMapper!)
@Bean
JsonMapper jsonMapper() {
    return JsonMapper.builder()
        .addModule(new JavaTimeModule())
        .serializationInclusion(JsonInclude.Include.NON_NULL)
        .build();
}
```

```java
// [4.x] свой сериализатор для值-объекта
@JacksonComponent
public class MoneySerializer extends ValueSerializer<Money> {
    @Override public void serialize(Money value, JsonGenerator gen, SerializationContext ctxt) throws JacksonException {
        gen.writeString(value.amount().toPlainString() + " " + value.currency().getCurrencyCode());
    }
}
```

**Правила JSON-контракта:**
* DTO — records, никаких сущностей.
* Даты — ISO-8601 в UTC (`Instant`), не timestamp-числа.
* Деньги — строка или объект `{amount, currency}`, никогда `double`.
* `null` vs отсутствие поля — решите и зафиксируйте (`NON_NULL` глобально).
* `FAIL_ON_UNKNOWN_PROPERTIES` — включайте для внутренних API (ловит опечатки), выключайте для публичных (обратная совместимость).
* **Никогда** не включайте `enableDefaultTyping` для недоверенного JSON — это RCE-вектор.

## 18.6. Единый контракт ошибок: `ProblemDetail` (RFC 9457)

```yaml
spring.mvc.problemdetails.enabled: true    # стандартные ошибки Spring → application/problem+json
```

```java
@RestControllerAdvice
class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(TaskNotFoundException.class)
    ProblemDetail notFound(TaskNotFoundException ex) {
        var pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        pd.setTitle("Задача не найдена");
        pd.setType(URI.create("https://api.taskflow.dev/errors/task-not-found"));
        pd.setProperty("taskId", ex.id());
        pd.setProperty("traceId", MDC.get("traceId"));
        return pd;
    }

    @ExceptionHandler(BusinessRuleViolation.class)
    ProblemDetail conflict(BusinessRuleViolation ex) {
        var pd = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
        pd.setProperty("code", ex.code());
        return pd;
    }

    // Валидация тела: собираем поля
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        var pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Ошибка валидации");
        pd.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> Map.of("field", fe.getField(),
                                  "message", Objects.requireNonNullElse(fe.getDefaultMessage(), "некорректно"),
                                  "rejected", Objects.requireNonNullElse(fe.getRejectedValue(), "null")))
                .toList());
        return ResponseEntity.badRequest().body(pd);
    }

    @ExceptionHandler(Exception.class)
    ProblemDetail unexpected(Exception ex) {
        log.error("Непредвиденная ошибка", ex);                 // логируем ОДИН раз, здесь
        var pd = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Внутренняя ошибка");
        pd.setProperty("traceId", MDC.get("traceId"));          // наружу — без деталей
        return pd;
    }
}
```

Пример ответа:
```json
{
  "type": "https://api.taskflow.dev/errors/task-not-found",
  "title": "Задача не найдена",
  "status": 404,
  "detail": "Задача 42 не существует",
  "instance": "/api/tasks/42",
  "taskId": 42,
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

🎯 Правила: наружу — стабильный `type`/`code` и `traceId`, **никогда** стектрейсы и SQL. Внутрь — полный лог. Один обработчик на весь проект (не по одному в каждом контроллере).

**Альтернатива без исключений** — `ErrorResponseException` / sealed-результаты (главы 1, 28):
```java
throw new ErrorResponseException(HttpStatus.NOT_FOUND, ProblemDetail.forStatus(404), null);
```

## 18.7. Асинхронные и стриминговые ответы

```java
@GetMapping("/slow") Callable<TaskView> slow() { return () -> service.slow(); }         // отдельный поток MVC

@GetMapping("/deferred") DeferredResult<TaskView> deferred() {
    var result = new DeferredResult<TaskView>(5_000L, ResponseEntity.status(504).build());
    service.async().whenComplete((v, e) -> { if (e != null) result.setErrorResult(e); else result.setResult(v); });
    return result;
}

@GetMapping(value="/events", produces=MediaType.TEXT_EVENT_STREAM_VALUE)
SseEmitter events() {
    var emitter = new SseEmitter(0L);                  // без таймаута
    service.subscribe(e -> { try { emitter.send(e); } catch (IOException ex) { emitter.completeWithError(ex); } });
    emitter.onCompletion(() -> service.unsubscribe(...));
    return emitter;
}

@GetMapping("/export") StreamingResponseBody export() {
    return out -> service.writeCsv(out);               // пишем прямо в поток, не буферизуем
}
```

Что важно:
* Async **освобождает поток контейнера**, но задача выполняется в `applicationTaskExecutor` — настройте его (`spring.task.execution.*`) или используйте виртуальные потоки.
* Security/transaction/MDC контекст **не переносится** автоматически → `TaskDecorator` (глава 11) и `DelegatingSecurityContextAsyncTaskExecutor`.
* `spring.mvc.async.request-timeout` — общий таймаут; для SSE ставьте `0` и обрабатывайте разрыв соединения.
* С виртуальными потоками надобность в `Callable`/`DeferredResult` для «просто блокирующего кода» почти исчезает — они нужны для событийной модели (SSE, long-polling).

## 18.8. CORS, статика, кастомизация MVC

```java
@Configuration
class WebConfig implements WebMvcConfigurer {
    @Override public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("https://app.taskflow.dev")
                .allowedMethods("GET","POST","PATCH","DELETE")
                .allowedHeaders("*").exposedHeaders("X-Request-Id")
                .allowCredentials(true).maxAge(3600);
    }
    @Override public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/assets/**")
                .addResourceLocations("classpath:/static/assets/")
                .setCacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic());
    }
    @Override public void addFormatters(FormatterRegistry registry) { registry.addConverter(new TenantIdConverter()); }
}
```
🪤 CORS + Spring Security: если Security включён, CORS нужно настраивать **и там** (`http.cors(...)`), иначе preflight `OPTIONS` будет отбит фильтром безопасности до MVC. `allowedOrigins("*")` + `allowCredentials(true)` — невалидная комбинация (браузер запретит), используйте `allowedOriginPatterns`.

**[Framework 7]** CORS preflight больше не отклоняется при пустой конфигурации — поведение изменилось, проверяйте тестами.

## 18.9. Версионирование API **[4.x]** — теперь встроено

```yaml
spring:
  mvc:
    apiversion:
      use:
        header: X-API-Version        # или media-type-parameter / query-parameter / path-segment
      supported: 1.0, 1.1, 2.0
      default: 1.0
      deprecation:
        sunset:
          "1.0": 2027-01-01
```
```java
@GetMapping(value = "/{id}", version = "1.0")
TaskV1 getV1(@PathVariable Long id) { ... }

@GetMapping(value = "/{id}", version = "1.1+")     // 1.1 и выше
TaskV2 getV2(@PathVariable Long id) { ... }
```
Настраиваемые бины: `ApiVersionResolver`, `ApiVersionParser`, `ApiVersionDeprecationHandler` (добавляет `Deprecation`/`Sunset` заголовки). Поддержка есть в `RestClient`, `WebClient`, HTTP-интерфейсах, MockMvc и `WebTestClient`.

**[3.5]** версионирование делается вручную: префикс пути `/api/v1`, кастомный `RequestCondition` или отдельные контроллеры. Практические стратегии и их trade-off — глава 19.

## 18.10. 🪤 Топ-12 граблей MVC

1. Возврат сущности вместо DTO (LazyInit, рекурсия, утечка полей).
2Ы. `@Valid` без `@RequestBody`/`@ModelAttribute` — не сработает как ожидаете.
3. `@Validated` на классе + `@Positive` параметр → `ConstraintViolationException`, а не `MethodArgumentNotValidException` (нужен отдельный обработчик).
4. `ResponseEntityExceptionHandler` уже обработал стандартные ошибки — ваш `@ExceptionHandler(Exception.class)` их не увидит.
5. `include-message: always` в проде → утечка внутренностей.
6. Двойное логирование ошибок (в сервисе и в advice).
7. CORS настроен только в MVC при включённом Security.
8. `Filter` без `OncePerRequestFilter` → двойное выполнение.
9. Async без переноса контекста → «пользователь пропал».
10. Отсутствие таймаутов async/SSE → висящие соединения.
11. Пользовательский `sort`/`fields` без whitelist.
12. `@RequestMapping` без `produces`/`consumes` при content negotiation → неожиданные 406/415.

## 18.11. 🧪 Практика

1. Соберите `GlobalExceptionHandler` с `ProblemDetail` и покройте тестами: 404, 400 (валидация), 409, 500.
2. Сделайте `AccessLogFilter` + `TimingInterceptor`, объясните, почему порядок именно такой.
3. **[4.x]** Настройте `JsonMapper` через кастомайзер и проверьте формат дат.
4. Реализуйте SSE-эндпоинт и корректную обработку отключения клиента.
5. **[4.x]** Включите версионирование через заголовок и сделайте два метода одной ручки.
6. Поставьте breakpoint в `DispatcherServlet#doDispatch` и пройдите весь путь запроса отладчиком.

## 18.12. Вопросы (middle+)

1) Перечислите шаги `doDispatch`. 2) Чем `HandlerMapping` отличается от `HandlerAdapter`? 3) Где в цепочке возникает 400 при битом JSON? 4) Filter vs Interceptor — три отличия. 5) Как работает `@RequestBody` (какие компоненты)? 6) Что изменилось в Jackson при переходе на Boot 4? 7) Зачем `ProblemDetail` и какой у него content-type? 8) Что освобождает `DeferredResult` и что не переносится автоматически? 9) Как настроить CORS при включённом Security? 10) Как работает встроенное версионирование в Framework 7?

---

**Назад:** [Глава 17](../03-data/17-keshirovanie.md) · **Дальше:** [Глава 19. Проектирование REST API →](19-rest-api-proektirovanie.md)