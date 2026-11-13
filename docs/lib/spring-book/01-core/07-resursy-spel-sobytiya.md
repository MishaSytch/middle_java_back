# Глава 7. Ресурсы, Environment, конверсия, SpEL и события

> **Уровень:** junior → middle+
> **Время:** 3–4 часа
> **Цель:** уверенно работать с внешним миром (файлы, classpath, свойства), писать безопасный SpEL и строить событийную развязку внутри приложения — без «магии», с пониманием механики.

## 7.1. Абстракция `Resource`

```java
@Component
@RequiredArgsConstructor
class TemplateLoader implements ResourceLoaderAware {
    private ResourceLoader loader;
    @Override public void setResourceLoader(ResourceLoader rl) { this.loader = rl; }

    String load() throws IOException {
        Resource r = loader.getResource("classpath:templates/report.html");
        return r.getContentAsString(StandardCharsets.UTF_8);
    }
}
```

| Префикс | Значение |
|---|---|
| `classpath:` | ресурс относительно classpath (первый найденный) |
| `classpath*:` | **все** совпадения во всех jar-ах (нужно для сканирования) |
| `file:` | файловая система |
| `https:` | URL |
| без префикса | зависит от типа контекста |

```java
@Value("classpath:sql/report.sql") Resource sql;          // инъекция ресурса
Resource[] all = new PathMatchingResourcePatternResolver()
        .getResources("classpath*:META-INF/spring/*.imports");
```

🪤 **Грабли ресурсов:**
* `resource.getFile()` **падает** внутри jar (`FileNotFoundException`). Всегда `getInputStream()`.
* `InputStreamResource` можно прочитать **один раз**; для повторного использования — `ByteArrayResource`.
* `classpath:` vs `classpath*:` — первый найдёт только один файл; при сканировании нескольких модулей нужен второй.
* В native-image ресурсы нужно регистрировать (`RuntimeHints`), glob-синтаксис в Framework 7 изменился: `/files/**/*.ext` вместо `/files/*.ext` для рекурсии.

## 7.2. `Environment` и `PropertySource`

```java
@Autowired Environment env;
String url = env.getProperty("app.payments.url");
int timeout = env.getProperty("app.payments.timeout", Integer.class, 5000);
boolean dev = env.acceptsProfiles(Profiles.of("local", "dev"));
```

⚙️ Внутри — `MutablePropertySources`: **упорядоченный список** источников; поиск идёт сверху вниз до первого совпадения. Посмотреть порядок:

```java
((ConfigurableEnvironment) env).getPropertySources()
    .forEach(ps -> System.out.println(ps.getName()));
```

Типичный порядок в Boot (сверху — сильнее):
```text
configurationProperties (обёртка)
commandLineArgs
SPRING_APPLICATION_JSON
servletConfigInitParams / servletContextInitParams
systemProperties (JVM -D)
systemEnvironment (OS)
random.*
application-{profile}.yml (вне jar)
application-{profile}.yml (в jar)
application.yml (вне jar)
application.yml (в jar)
@PropertySource
defaultProperties
```
Полный разбор приоритетов и практики — глава 10. Здесь важно: **`@Value` и `Environment` читают один и тот же `Environment`**, а плейсхолдеры `${...}` разрешает `PropertySourcesPlaceholderConfigurer` (BFPP).

## 7.3. `@Value`: когда уместен и когда нет

```java
@Value("${app.payments.url}")                       String url;               // обязательное
@Value("${app.payments.timeout:5000}")              int timeout;              // с дефолтом
@Value("${app.tags:a,b,c}")                         List<String> tags;        // конверсия строки
@Value("#{systemProperties['user.timezone']}")      String tz;                // SpEL
@Value("#{${app.matrix}}")                          Map<String,String> matrix;// SpEL + placeholder
@Value("classpath:certs/server.crt")                Resource cert;
```

**Правило:** `@Value` — для 1–2 простых значений. Для группы настроек — `@ConfigurationProperties` (типобезопасно, валидируемо, документируется, поддерживает IDE-подсказки). Сравнение — глава 10.

🪤 `@Value` в `static`-поле не работает. `@Value` в объекте, созданном через `new`, — тоже. В record-компонентах `@Value` работает только при создании бина контейнером (обычно это `@ConfigurationProperties`).

## 7.4. Конверсия типов: `ConversionService`

Spring умеет превращать строки в `Duration`, `DataSize`, `List`, `Enum`, `Path`, ваши типы:

```yaml
app:
  cache-ttl: 30s          # Duration
  max-upload: 10MB        # DataSize
  modes: READ,WRITE       # List<Mode> или Set<Mode>
```

Свой конвертер:
```java
@Component
@ConfigurationPropertiesBinding      // чтобы работал именно при биндинге свойств
class TenantIdConverter implements Converter<String, TenantId> {
    @Override public TenantId convert(String source) { return TenantId.of(source); }
}
```

Для web-слоя (параметры запроса) работает `Formatter`/`Converter`, зарегистрированный в `WebMvcConfigurer#addFormatters` — это **другой** реестр, чем `ConversionService` биндинга. 🎯 Частый вопрос: «почему конвертер работает в `@RequestParam`, но не в `@ConfigurationProperties`?» — потому что нужны разные регистрации (`@ConfigurationPropertiesBinding` vs `addFormatters`).

## 7.5. SpEL глубоко

SpEL (Spring Expression Language) — язык выражений, который используется в `@Value`, `@PreAuthorize`, `@Cacheable(key=...)`, `@EventListener(condition=...)`, `@ConditionalOnExpression`, Spring Security, Spring Data (`@Query` с `#{}`), Thymeleaf.

### Синтаксис — рабочая шпаргалка

```java
ExpressionParser parser = new SpelExpressionParser();
EvaluationContext ctx = new StandardEvaluationContext(bean);

parser.parseExpression("name").getValue(ctx);                       // свойство
parser.parseExpression("address?.city").getValue(ctx);              // null-safe навигация
parser.parseExpression("items.?[price > 100]").getValue(ctx);       // selection: фильтр
parser.parseExpression("items.^[price > 100]").getValue(ctx);       // first
parser.parseExpression("items.$[price > 100]").getValue(ctx);       // last
parser.parseExpression("items.![name]").getValue(ctx);              // projection: map
parser.parseExpression("name ?: 'unknown'").getValue(ctx);          // Elvis
parser.parseExpression("T(java.time.LocalDate).now()").getValue();  // тип
parser.parseExpression("@taskService.count()").getValue(beanCtx);   // бин по имени
parser.parseExpression("#root.title + ' / ' + #id").getValue(ctx);  // переменные
parser.parseExpression("new java.util.Date()").getValue();          // конструктор
parser.parseExpression("{1,2,3}.![#this * 2]").getValue();          // inline-список
parser.parseExpression("{a:1,b:2}['a']").getValue();                // inline-map
```

Шаблонизация:
```java
parser.parseExpression("Привет, #{name}!", new TemplateParserContext()).getValue(ctx, String.class);
```

### SpEL в аннотациях — реальные примеры

```java
@Cacheable(cacheNames = "tasks", key = "#id + ':' + #root.methodName")
Task find(Long id) { ... }

@Cacheable(cacheNames = "tasks", key = "#req.slug()", condition = "#req.priority() != null")
TaskView create(CreateTaskRequest req) { ... }

@PreAuthorize("hasRole('ADMIN') or #ownerId == authentication.name")
void delete(Long ownerId) { ... }

@EventListener(condition = "#event.payload.important")
void on(TaskCreated event) { ... }

@Retryable(includes = IOException.class, maxAttempts = 3, delay = 100)   // [4.x] core retry
void call() throws IOException { ... }
```

### ⚙️ Безопасность SpEL — обязательно к прочтению

`StandardEvaluationContext` даёт доступ к `T(...)`, конструкторам, бинам → **выполнение произвольного кода**. Если выражение приходит извне (пользовательский ввод, БД, конфиг от клиента) — это RCE.

Правила:
1. Для недоверенных выражений — **`SimpleEvaluationContext`** (нет `T()`, нет конструкторов, нет bean-резолвера, только свойства/коллекции).
2. Framework 7: **лимит операций 10 000** по умолчанию (`spring.expression.maxOperations`) — защита от DoS через «тяжёлые» выражения; с 7.0.9 `SimpleEvaluationContext` не компилирует выражения (можно включить `withCompilationSupported()` осознанно).
3. Никогда не собирайте выражение конкатенацией с пользовательским вводом. Передавайте значения **переменными** (`#var`), а не текстом.

```java
var safe = SimpleEvaluationContext.forReadOnlyDataBinding().withRootObject(dto).build();
parser.parseExpression("title").getValue(safe, String.class);
```

### Производительность
* Парсинг дорогой → **кэшируйте `Expression`** (Spring делает это внутри аннотаций).
* Компиляция SpEL (`SpelCompilerMode.IMMEDIATE`) ускоряет повторные вычисления, но опасна для меняющихся типов и запрещена по умолчанию в `SimpleEvaluationContext`.

## 7.6. События: развязка внутри приложения

### Публикация и подписка

```java
public record TaskCreated(TaskId id, String owner, Instant at) {}     // POJO, не обязательно ApplicationEvent

@Service
@RequiredArgsConstructor
class TaskService {
    private final ApplicationEventPublisher events;

    @Transactional
    public TaskId create(CreateTaskRequest req) {
        Task t = repository.save(Task.of(req));
        events.publishEvent(new TaskCreated(t.id(), t.owner(), Instant.now()));
        return t.id();
    }
}

@Component
class NotificationListener {
    @EventListener
    @Order(10)
    void on(TaskCreated e) { /* ... */ }

    @EventListener(condition = "#e.owner != 'system'")
    void audit(TaskCreated e) { /* ... */ }

    @Async                                        // в другом потоке — осторожно с контекстом!
    @EventListener
    void slow(TaskCreated e) { /* ... */ }
}
```

⚙️ `ApplicationEventMulticaster` (`SimpleApplicationEventMulticaster`) синхронно вызывает слушателей в том же потоке; тип события определяется через `ResolvableType` (поэтому работают `ApplicationEvent<T>` и дженерик-слушатели). Ошибка в слушателе по умолчанию **пробрасывается** в публикующего → откатит его транзакцию. Хотите изоляции — задайте `ErrorHandler` мультикастеру или используйте `@Async`.

### Возврат значения как новое событие

```java
@EventListener
public NotificationQueued on(TaskCreated e) { return new NotificationQueued(e.id()); }
```

### `@TransactionalEventListener` — самый важный практический инструмент

```java
@Component
class MailOnCommit {
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void send(TaskCreated e) { mail.send(e.owner()); }     // только если транзакция ЗАКОММИТИЛАСЬ
}
```

| Фаза | Когда вызывается |
|---|---|
| `BEFORE_COMMIT` | перед коммитом (можно ещё откатить) |
| `AFTER_COMMIT` (по умолчанию) | после успешного коммита |
| `AFTER_ROLLBACK` | после откатa |
| `AFTER_COMPLETION` | после любого завершения |

🪤 **Три грабли `@TransactionalEventListener`:**
1. **Нет транзакции → слушатель не вызовется вообще.** Для «работать и без транзакции» — `fallbackExecution = true`.
2. В `AFTER_COMMIT` транзакция уже завершена: запись в БД внутри слушателя **не** будет в той же транзакции. Нужна новая — `@Transactional(propagation = REQUIRES_NEW)`.
3. Слушатель выполняется в том же потоке → долгое действие блокирует ответ пользователю. Комбинируйте с `@Async` (и не забудьте про потерю контекста).

🎯 **Продакшн-паттерн:** событие «после коммита» + `@Async` + гарантированная доставка. Проблема: между коммитом и обработкой процесс может умереть → событие потеряно. Решение — **transactional outbox**: писать событие в таблицу в той же транзакции и обрабатывать отдельным воркером. В Spring это готовый `Spring Modulith Event Publication Registry` (или своя таблица + `@Scheduled`). Это ровно тот ответ, который ждут на middle+ собеседовании.

### Порядок и асинхронность

```java
@Bean(name = "applicationEventMulticaster")
ApplicationEventMulticaster multicaster(@Qualifier("applicationTaskExecutor") Executor executor) {
    var m = new SimpleApplicationEventMulticaster();
    m.setTaskExecutor(executor);                          // все события асинхронно (осторожно!)
    m.setErrorHandler(t -> log.error("Ошибка слушателя", t));
    return m;
}
```

## 7.7. 🧪 Практика

1. Загрузите SQL из `classpath:sql/` через `Resource`, работая из uber-jar (проверьте, что `getFile()` падает, а `getInputStream()` — нет).
2. Распечатайте порядок `PropertySource` и найдите, откуда реально приехало значение `server.port`.
3. Напишите `Converter<String, TenantId>` и используйте его в `@ConfigurationProperties` и в `@RequestParam` (две регистрации).
4. Сделайте событие `TaskCreated`, слушатель `@TransactionalEventListener(AFTER_COMMIT)` и тест, который откатывает транзакцию — убедитесь, что письма нет.
5. Попробуйте `SimpleEvaluationContext` с выражением `T(java.lang.Runtime).getRuntime()` — получите отказ и объясните почему.

## 7.8. Чек-лист и вопросы

- [ ] Читаю ресурсы через `getInputStream()`, знаю про `classpath*:`.
- [ ] Понимаю порядок property sources и умею его распечатать.
- [ ] Группы настроек — в `@ConfigurationProperties`, не в горсти `@Value`.
- [ ] Знаю, чем опасен `StandardEvaluationContext`, и что изменилось в Framework 7.
- [ ] Использую `AFTER_COMMIT` для внешних эффектов и понимаю риск потери события.

**Вопросы:** 1) Почему `resource.getFile()` ломается в jar? 2) Кто разрешает `${...}` и на каком этапе? 3) Чем `SimpleEvaluationContext` безопаснее? 4) Что будет, если слушатель бросит исключение? 5) Почему `@TransactionalEventListener` молчит без транзакции? 6) Как гарантировать доставку доменного события после коммита?

---

**Назад:** [Глава 6](06-java-config-i-usloviya.md) · **Дальше:** [Глава 8. AOP и прокси →](08-aop.md)