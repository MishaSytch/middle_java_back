# Глава 4. IoC и DI: контейнер, бины, инъекция, скоупы

> **Уровень:** zero → middle
> **Время:** 4–6 часов
> **Цель:** свободно собирать приложение из бинов, понимать, *какой* объект вам приехал (прокси или нет), и осознанно выбирать скоуп и способ инъекции.

## 4.1. Проблема, которую решает DI

Наивный код:

```java
class TaskService {
    private final TaskRepository repo = new JdbcTaskRepository(new HikariDataSource(/* ... */));
    private final MailSender mail = new SmtpMailSender("smtp.corp.local", 25);
}
```

Что здесь плохо:
1. `TaskService` **знает конкретные реализации** и способ их создания → замена реализации = правка класса.
2. **Невозможно протестировать** без реальной БД и SMTP.
3. Жизненный цикл (пулы, закрытие ресурсов) размазан по коду.
4. Конфигурация зашита в код → разные среды требуют перекомпиляции.

Инверсия управления (IoC) переворачивает зависимость: не сервис создаёт зависимости, а **внешний контейнер** создаёт сервис и передаёт зависимости. DI (Dependency Injection) — конкретный приём реализации IoC.

```java
@Service
class TaskService {
    private final TaskRepository repo;
    private final MailSender mail;
    TaskService(TaskRepository repo, MailSender mail) {   // контейнер передаст реализации
        this.repo = repo; this.mail = mail;
    }
}
```

> **🎯 Middle+:** DI — не про аннотации. Это про то, что **граф объектов приложения собирается в одном месте**, а бизнес-код зависит от абстракций. Аннотации — лишь способ описать этот граф.

## 4.2. Контейнер: `BeanFactory` vs `ApplicationContext`

* `BeanFactory` — минимальный контракт: получить бин, проверить наличие, узнать тип/скоуп. Ленивая инициализация.
* `ApplicationContext` — «enterprise»-надстройка: события, `MessageSource`, `ResourceLoader`, `Environment`, автоматическая регистрация `BeanPostProcessor`/`BeanFactoryPostProcessor`, **eager**-создание синглтонов при старте.

Иерархия, которую полезно знать:

```text
BeanFactory
 └── ListableBeanFactory ──┐
     AutowireCapableBeanFactory
                           ▼
              DefaultListableBeanFactory   ← рабочая лошадка (реестр BeanDefinition + синглтонов)
ApplicationContext = BeanFactory + Environment + события + ресурсы
 ├── AnnotationConfigApplicationContext
 ├── GenericApplicationContext
 └── (Boot) AnnotationConfigServletWebServerApplicationContext / ReactiveWebServerApplicationContext
```

**Практически:** вы всегда работаете с `ApplicationContext`, а внутри него — `DefaultListableBeanFactory`. Понимание этого разделения объясняет, почему `BeanFactoryPostProcessor` может менять определения бинов **до** их создания (глава 5).

Минимальный контейнер без Boot (полезно для понимания):

```java
var ctx = new AnnotationConfigApplicationContext();
ctx.register(AppConfig.class);
ctx.refresh();                       // ← здесь происходит вся магия
var service = ctx.getBean(TaskService.class);
ctx.close();
```

## 4.3. Как объявить бин: пять способов

```java
// 1. Стерильные аннотации + сканирование
@Component class Foo {}
@Service   class TaskService {}       // семантика: бизнес-логика
@Repository class JdbcTaskRepo {}     // + трансляция исключений в DataAccessException
@Controller / @RestController         // web-слой
@Configuration class AppConfig {}     // источник @Bean

// 2. @Bean в @Configuration — для чужих классов и сложной сборки
@Configuration(proxyBeanMethods = false)
class ClientsConfig {
    @Bean
    RestClient paymentsClient(RestClient.Builder builder) {
        return builder.baseUrl("https://pay.local").defaultHeader("X-App", "taskflow").build();
    }
}

// 3. @Import — явный импорт конфигурации
@Import({ClientsConfig.class, MetricsConfig.class})

// 4. FactoryBean — когда создание сложное (см. 5.9)

// 5. Программно: BeanRegistrar (Framework 7) / BeanDefinitionRegistry (см. главу 6)
```

**Когда `@Component`, а когда `@Bean`?**

| Ситуация | Выбор |
|---|---|
| Ваш класс, простая сборка | `@Component`/`@Service` |
| Класс из библиотеки | `@Bean` |
| Нужно выбрать реализацию по условию/конфигу | `@Bean` + `@ConditionalOn*` |
| Несколько бинов одного типа с разной настройкой | `@Bean` (методы с разными именами) |
| Нужен билдер, таймауты, retry-обвязка | `@Bean` |

🪤 **Грабли:** `@Component` на классе, который вы **ещё и** объявляете через `@Bean`, даёт **два** бина. Классический источник `NoUniqueBeanDefinitionException`.

## 4.4. Виды инъекции и почему конструктор — правильный

```java
// ✅ Конструктор: обязательные зависимости, final-поля, impossibility of partially-constructed object
@Service
class TaskService {
    private final TaskRepository repo;
    private final Clock clock;
    TaskService(TaskRepository repo, Clock clock) { this.repo = repo; this.clock = clock; }
}

// ⚠️ Сеттер: для опциональных/перенастраиваемых зависимостей
@Autowired void setAuditSink(AuditSink sink) { this.sink = sink; }

// ❌ Поле: скрывает зависимости, ломает тестируемость без контейнера, поощряет «божественные» классы
@Autowired private TaskRepository repo;
```

Почему конструктор:
* зависимость нельзя забыть → объект всегда валиден;
* поля `final` → иммутабельность и потокобезопасность;
* юнит-тест создаёт объект обычным `new TaskService(mockRepo, fixedClock)`;
* **циклические зависимости падают на старте**, а не «работают как-то» — это фича, а не баг.

С Spring 4.3 `@Autowired` на единственном конструкторе **не нужен**. Если конструкторов несколько — пометьте нужный.

**Lombok-вариант**, который вы увидите в 90 % проектов:
```java
@Service
@RequiredArgsConstructor      // генерирует конструктор по final-полям
public class TaskService {
    private final TaskRepository repo;
}
```
Работает, но помните: аннотации Lombok не видны в исходниках — при отладке DI смотрите сгенерированный конструктор.

### 4.4.1. Опциональные зависимости

```java
TaskService(TaskRepository repo, Optional<AuditSink> audit) { ... }
TaskService(TaskRepository repo, ObjectProvider<AuditSink> auditProvider) {
    AuditSink sink = auditProvider.getIfAvailable(() -> AuditSink.NOOP);
}
TaskService(TaskRepository repo, @Nullable AuditSink sink) { ... }   // org.jspecify.annotations.Nullable [4.x]
```

`ObjectProvider` — самый гибкий вариант: ленивость (`getIfAvailable`), множественность (`orderedStream()`), отсутствие ошибки при отсутствии бина. **Он же — лекарство от части циклов** и от «слишком ранней» инициализации.

### 4.4.2. Коллекции и порядок

```java
@Service
class NotificationDispatcher {
    private final List<NotificationChannel> channels;      // все бины типа, отсортированные @Order
    private final Map<String, NotificationChannel> byName; // ключ = имя бина

    NotificationDispatcher(List<NotificationChannel> channels, Map<String, NotificationChannel> byName) { ... }
}

@Component @Order(10) class EmailChannel implements NotificationChannel {}
@Component @Order(20) class SmsChannel   implements NotificationChannel {}
```

Нюансы:
* `@Order`/`Ordered` управляет порядком **в коллекции**, но **не** выбирает бин при одиночной инъекции (для этого `@Primary`).
* Пустая коллекция: Spring по умолчанию считает зависимость неудовлетворённой → используйте `ObjectProvider<List<T>>` или `@Autowired(required=false)`.
* `List<T>` в порядке `@Order` — базовый паттерн «цепочка обработчиков» (strategy/chain of responsibility). В главе 19 так устроены `HandlerMethodArgumentResolver` и конвертеры.

### 4.4.3. Выбор среди нескольких: `@Primary`, `@Qualifier`, кастомные квалификаторы

```java
@Bean @Primary RestClient defaultClient() { ... }
@Bean("payments") RestClient paymentsClient() { ... }

@Service
class BillingService {
    BillingService(@Qualifier("payments") RestClient client) { ... }
}
```

Своя аннотация-квалификатор (лучше строки — типобезопасно и переживает рефакторинг):

```java
@Qualifier @Retention(RUNTIME) @Target({FIELD, METHOD, PARAMETER, TYPE})
public @interface Payments {}

@Bean @Payments RestClient paymentsClient() { ... }
// инъекция:
BillingService(@Payments RestClient client) { ... }
```

**Дженерики как квалификаторы:** `Handler<TaskCreated>` и `Handler<TaskDeleted>` — разные типы для контейнера. Это позволяет вообще обойтись без строк и `@Primary`.

🎯 **Порядок разрешения зависимости** (упрощённо, `DefaultListableBeanFactory#doResolveDependency`):
1. `@Qualifier`/кастомный квалификатор → фильтр кандидатов;
2. `@Primary`;
3. `@Priority` (`jakarta.annotation.Priority`, меньшее значение — выше);
4. совпадение имени параметра/поля с именем бина (fallback);
5. иначе `NoUniqueBeanDefinitionException`.

## 4.5. Скоупы

| Скоуп | Сколько экземпляров | Когда применять |
|---|---|---|
| `singleton` (по умолчанию) | один на контекст | 99 % бинов: сервисы, репозитории, клиенты |
| `prototype` | новый на каждое обращение | состояния-на-операцию, «билдеры» |
| `request` | один на HTTP-запрос | контекст запроса, аудит |
| `session` | один на HTTP-сессию | корзина, пользовательские настройки |
| `application` | один на `ServletContext` | редко (не путать с singleton) |
| `websocket` | один на WS-сессию | WS-состояние |
| свой | по вашей логике | tenant-scope, job-scope |

```java
@Component
@Scope(value = WebApplicationContext.SCOPE_REQUEST, proxyMode = ScopedProxyMode.TARGET_CLASS)
class RequestContext { /* ... */ }
```

**Зачем `proxyMode`:** синглтон создаётся один раз — если в него инжектить request-бин напрямую, он «залипнет» на первом запросе. Scoped proxy подставляет прокси, который на каждом вызове достаёт актуальный экземпляр из текущего запроса.

🪤 **Три главные грабли скоупов:**
1. `prototype` в синглтоне **не** даёт новый экземпляр на каждый вызов метода — инъекция происходит один раз. Решения: `ObjectProvider<T>`, `@Lookup`, scoped proxy.
2. Для `prototype` Spring **не вызывает destroy** — контейнер не отслеживает жизненный цикл после выдачи. Ресурсы закрываете вы.
3. Request/session-скоуп вне запроса (например, в `@Scheduled` или `@Async`) → `BeanCreationException: Scope 'request' is not active`.

```java
@Service
@RequiredArgsConstructor
class ReportService {
    private final ObjectProvider<ReportBuilder> builders;   // ✅ каждый вызов — новый
    void run() { ReportBuilder b = builders.getObject(); }
}
```

Глобальная ленивость (иногда ускоряет старт, но прячет ошибки конфигурации до первого обращения):
```yaml
spring.main.lazy-initialization: true
```
`@Lazy` на поле/параметре инжектит ленивый прокси; `@Lazy` на `@Bean`/`@Component` откладывает создание.

## 4.6. Жизненный цикл бина: практическая сторона

```java
@Component
class WarmupCache implements InitializingBean, DisposableBean {

    @PostConstruct void init() { /* после инъекции всех зависимостей */ }
    @Override public void afterPropertiesSet() { /* то же, но интерфейс Spring */ }

    @PreDestroy void shutdown() { /* перед закрытием контекста */ }
    @Override public void destroy() { /* то же */ }
}
```

Порядок: `@PostConstruct` → `InitializingBean.afterPropertiesSet()` → `initMethod`. Обратно при уничтожении: `@PreDestroy` → `DisposableBean.destroy()` → `destroyMethod`.

**Что где делать:**

| Задача | Правильное место |
|---|---|
| Проверить/нормализовать конфигурацию | конструктор или `@PostConstruct` |
| Прогреть кэш, открыть соединение | `@PostConstruct` / `SmartInitializingSingleton` |
| Действие «когда всё готово» (в т.ч. web-сервер) | `ApplicationRunner`/`CommandLineRunner` или `@EventListener(ApplicationReadyEvent.class)` |
| Корректно остановить пул/консьюмер | `@PreDestroy` / `SmartLifecycle.stop()` |

🪤 Не делайте тяжёлую работу в конструкторе: часть инфраструктуры (прокси, AOP, транзакции) ещё не готова, а исключение в конструкторе даёт невнятный стектрейс.

🪤 `@PostConstruct` **не вызывается** для бина, созданного через `new` в вашем коде, и для prototype-бинов, полученных вручную.

**[4.x]/[3.5]** аннотации — `jakarta.annotation.PostConstruct`/`PreDestroy` (не `javax.*`: поддержка `javax.annotation` **удалена** в Framework 7).

## 4.7. Циклические зависимости

```java
@Service class A { A(B b) {} }
@Service class B { B(A a) {} }      // ❌ BeanCurrentlyInCreationException
```

Boot по умолчанию **запрещает** циклы (`spring.main.allow-circular-references=false`). Это правильно: цикл — почти всегда признак неверного разделения ответственности.

Как лечить (в порядке предпочтения):
1. **Выделить третью сущность**, содержащую общую логику (чаще всего это и есть настоящее решение).
2. **События** (`ApplicationEventPublisher`) вместо прямого вызова — разворачивает зависимость.
3. `ObjectProvider<B>` — откладывает разрешение до первого использования.
4. `@Lazy` на одном из параметров — инжектит прокси.
5. Сеттерная инъекция — работает, но маскирует дизайн-проблему.
6. `allow-circular-references=true` — **последнее средство**, техдолг с комментарием и тикетом.

🎯 Почему сеттерный цикл разрешим, а конструкторный — нет, и почему `@Async`-бин в цикле может всё сломать — разбираем в главе 5 (три уровня кэша синглтонов).

## 4.8. Профили и условия (кратко)

```java
@Bean @Profile("local")  DataSource h2() { ... }
@Bean @Profile("!local") DataSource pg() { ... }
@Bean @ConditionalOnProperty(name = "app.audit.enabled", havingValue = "true")
AuditSink auditSink() { ... }
```

Полный разбор условий и их порядка — глава 9; профили и конфигурация — глава 10. Здесь важно запомнить: **профиль — это условие на этапе определения бина**, а не «переключатель во время работы».

## 4.9. Null-safety: JSpecify **[4.x]**

```java
import org.jspecify.annotations.Nullable;

@Service
class TaskService {
    private final @Nullable AuditSink audit;      // может отсутствовать
    TaskService(@Nullable AuditSink audit) { this.audit = audit; }
}
```

Framework 7 и Boot 4 размечены JSpecify; IDE и Kotlin теперь видят nullability дженериков и массивов. Практический эффект: Kotlin-код, который раньше компилировался с «platform types», может начать требовать `?.` или `!!`. Это не регресс — это найденные потенциальные NPE. **[3.5]** используются `org.springframework.lang.Nullable/NonNull` (в 7 они deprecated).

## 4.10. 🧪 Практика: рефакторинг в DI

Возьмите класс с `new` внутри (например, сервис, создающий `HttpClient` и `ObjectMapper`) и:
1. Вынесите обе зависимости в `@Bean`-методы конфигурации.
2. Переведите сервис на конструкторную инъекцию с `final`-полями.
3. Напишите юнит-тест **без** Spring: подставьте фейки.
4. Добавьте второй `NotificationChannel` и убедитесь, что `List<NotificationChannel>` приходит в порядке `@Order`.
5. Сделайте намеренный цикл A↔B, получите ошибку, исправьте через событие.
6. Сделайте request-scoped бин и убедитесь, что без `proxyMode` он «залипает».

## 4.11. 🪤 Топ-10 граблей DI

1. Класс вне пакета сканирования → бин не найден.
2. `@Component` + `@Bean` для одного класса → два бина.
3. Полевая инъекция → NPE в юнит-тестах и скрытые зависимости.
4. `prototype` в синглтоне → «не создаётся новый».
5. `@Order` вместо `@Primary` при одиночной инъекции.
6. Тяжёлая логика в конструкторе.
7. `static`-метод `@Bean` (нужен для `BeanFactoryPostProcessor`, но лишает CGLIB-семантики — см. главу 6).
8. Ожидание `@PreDestroy` для prototype.
9. Request-скоуп в `@Async`/`@Scheduled`.
10. `@Autowired` поле в классе, который создаётся через `new` (частая ошибка в `Filter`, `Converter`, `Validator`, созданных вручную).

## 4.12. Чек-лист и вопросы

- [ ] Все зависимости — через конструктор, поля `final`.
- [ ] Я знаю, какой бин приедет при нескольких кандидатах, и почему.
- [ ] Я осознанно выбираю скоуп и понимаю роль `proxyMode`.
- [ ] Циклов нет; если есть — есть тикет и план устранения.
- [ ] Тяжёлая инициализация — в правильном хуке.

**Вопросы:**
1. Чем `ApplicationContext` отличается от `BeanFactory` (три отличия)?
2. Почему конструкторная инъекция лучше полевой (четыре аргумента)?
3. Что делает `@Primary`, а что `@Order`?
4. Как получить новый prototype-экземпляр на каждый вызов метода синглтона?
5. Почему `@PostConstruct` не подходит для «приложение полностью готово»?
6. Как ведёт себя `Optional<T>` при отсутствии бина, а как `ObjectProvider<T>`?

---

**Назад:** [Глава 3](../00-fundament/03-ekosistema-versii-bom.md) · **Дальше:** [Глава 5. Контейнер изнутри →](05-kontejner-vnutri.md)