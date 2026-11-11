# Глава 1. Java-фундамент, без которого Spring — магия

> **Уровень:** zero → junior
> **Время:** 3–5 часов с практикой
> **Треки:** материал одинаков для Boot 4.x и 3.5.x, различия по версиям Java отмечены явно
> **Цель:** перестать воспринимать Spring как «магию аннотаций». После этой главы вы понимаете, *какими средствами языка* Spring делает всё, что делает.

## 1.1. Почему глава про Java стоит в книге про Spring

90 % вопросов «почему не работает `@Transactional`», «почему бин `null`», «почему `List<Handler>` пустой», «почему `final`-класс не проксируется» — это вопросы про Java, а не про Spring. Spring — это библиотека, которая активно использует:

| Механизм Java | Что на нём построено в Spring |
|---|---|
| Аннотации + рефлексия | `@Component`, `@Autowired`, сканирование, `@ConfigurationProperties` |
| Мета-аннотации | `@RestController`, `@SpringBootApplication`, ваши собственные «стерильные» аннотации |
| Динамические прокси (JDK) | `@Transactional`, `@Async`, `@Cacheable`, HTTP-интерфейсы, Spring Data репозитории |
| Генерация байткода (CGLIB) | проксирование классов без интерфейсов, `@Configuration`-классы |
| Дженерики + `Type`-рефлексия | инъекция `List<T>`, `Optional<T>`, `ResolvableType`, конвертеры |
| `ThreadLocal` | `TransactionSynchronizationManager`, `SecurityContextHolder`, `RequestContextHolder` |
| ClassLoader | сканирование classpath, uber-jar, DevTools restart, AOT/native |
| Лямбды/функциональные интерфейсы | `BeanRegistrar`, `RestClient` DSL, `RowMapper`, `TransactionCallback` |

Если вы понимаете эти восемь пунктов, внутренности Spring читаются как обычный код.

## 1.2. Версии Java: что выбрать в 2026

| Версия | Статус на ноябрь 2026 | Роль в книге |
|---|---|---|
| Java 17 | LTS 2021, ещё живёт в проде | **минимальный baseline** и Spring Boot 3.5, и Spring Boot 4.x |
| Java 21 | LTS 2023, самый массовый прод | «безопасный выбор»: виртуальные потоки, pattern matching, records |
| Java 25 | **LTS 2025 — рекомендуется** Spring Framework 7 | основной целевой JDK книги |
| Java 26/27 | не-LTS, вышли в 2026 | не для прода; следующий LTS — Java 29 (осень 2027) |

**Практическое правило:** компилируйте под тот минимум, который реально стоит в проде (`--release 17/21`), а запускайте на 25. Spring Framework 7.0 официально сохраняет baseline JDK 17 и рекомендует JDK 25; Spring Boot 4.x требует Java 17+.

Ключевые фичи по версиям, которые мы будем использовать:

```text
17: records, sealed, switch pattern matching (preview), text blocks (15), instanceof pattern (16)
21: virtual threads (final), record patterns + switch patterns (final), sequenced collections
25: compact source files & instance main (final), module imports, flexible constructor bodies,
    scoped values (final), stable values (preview), улучшенные виртуальные потоки (без pinning на synchronized)
```

> **Java 25, коротко о «compact source files»**: с Java 25 допустим файл без класса и `public static void main`:
> ```java
> void main() {
>     IO.println("Привет, Spring");
> }
> ```
> Это удобно для учебных сниппетов, но в Spring-проектах мы всегда пишем обычные классы: фреймворку нужны типы, аннотации и конструкторы.

## 1.3. Records: главный инструмент DTO

```java
public record CreateTaskRequest(
        String title,
        String description,
        LocalDate dueDate,
        Priority priority
) {}
```

Что даёт компилятор: `private final` поля, канонический конструктор, геттеры **без префикса `get`** (`title()`), `equals`/`hashCode` по всем компонентам, `toString`. Класс `final`, наследоваться нельзя, расширять другие классы нельзя, интерфейсы — можно.

**Компактный конструктор** — место для нормализации и инвариантов:

```java
public record Money(BigDecimal amount, Currency currency) {
    public Money {                                  // compact constructor: без параметров
        Objects.requireNonNull(amount, "amount");
        Objects.requireNonNull(currency, "currency");
        if (amount.scale() > currency.getDefaultFractionDigits()) {
            throw new IllegalArgumentException("Слишком много знаков после запятой");
        }
        amount = amount.setScale(currency.getDefaultFractionDigits(), RoundingMode.HALF_UP);
    }
    public Money plus(Money other) {
        if (!currency.equals(other.currency)) throw new IllegalArgumentException("Разные валюты");
        return new Money(amount.add(other.amount), currency);
    }
}
```

Где records идеальны в Spring:
* DTO запросов/ответов (`@RequestBody CreateTaskRequest`), в том числе с Bean Validation;
* `@ConfigurationProperties` с constructor binding;
* проекции Spring Data (`record TaskSummary(Long id, String title) {}`);
* ключи кэша, значения событий, «результаты» операций.

Где records **нельзя**:
* **JPA-сущности** — Hibernate требует non-final класс, no-arg конструктор и мутабельность для dirty checking;
* классы, которые вы собираетесь проксировать CGLIB (`@Configuration`, `@Transactional`-сервисы).

> **Грабли Jackson:** record десериализуется через канонический конструктор, поэтому `@JsonProperty` на компонентах работает, а «сеттеров» нет. Для значений по умолчанию используйте компактный конструктор, а не «поле = значение».

## 1.4. Sealed-иерархии + pattern matching: доменные ошибки без исключений

```java
public sealed interface TaskResult permits Created, Rejected, NotFound {}
public record Created(TaskId id) implements TaskResult {}
public record Rejected(String reason) implements TaskResult {}
public record NotFound(TaskId id) implements TaskResult {}
```

```java
String message = switch (result) {                 // exhaustiveness проверяет компилятор
    case Created(TaskId id)   -> "Создана задача " + id.value();
    case Rejected(var reason) -> "Отклонена: " + reason;
    case NotFound(TaskId id)  -> "Не найдена: " + id.value();
};                                                  // default не нужен — все permits покрыты
```

Зачем это в Spring-проекте: `sealed` + `switch` даёт **проверяемую компилятором** обработку всех исходов бизнес-операции. Никаких «забыли ветку — получили 500 в проде». В главе 28 мы построим на этом слой ошибок без «исключений как flow control».

## 1.5. Дженерики: почему Spring умеет `List<Handler>`

Дженерики в Java **стираются** (type erasure): в байткоде `List<String>` — просто `List`. Но есть исключение: **сигнатуры полей, методов, супертипов и аннотаций сохраняют дженерик-информацию** в атрибуте `Signature`. Именно её читает Spring.

```java
@Component
class HandlerRegistry {
    // Spring увидит элемент типа PaymentHandler через Field.getGenericType()
    private final List<PaymentHandler> handlers;
    HandlerRegistry(List<PaymentHandler> handlers) { this.handlers = handlers; }
}
```

Внутри Spring это делает `ResolvableType`:

```java
ResolvableType type = ResolvableType.forField(field);          // List<PaymentHandler>
ResolvableType element = type.getGeneric(0);                   // PaymentHandler
Class<?> resolved = element.resolve();                         // class PaymentHandler
```

Поэтому работают `Optional<Repo>`, `ObjectProvider<Bean>`, `Map<String, Handler>`, `ApplicationEventPublisher` для `ApplicationEvent<MyPayload>`.

**Инвариантность и PECS** — минимум, который надо помнить:

```java
List<Integer> ints = List.of(1, 2, 3);
// List<Number> nums = ints;            // НЕ компилируется: List<Integer> не подтип List<Number>
List<? extends Number> read = ints;     // producer: можно читать Number
List<? super Integer> write = new ArrayList<Number>();  // consumer: можно писать Integer
```

Правило **PECS**: *Producer — Extends, Consumer — Super*. В Spring API вы это увидите постоянно: `Class<? extends Annotation>`, `List<? extends HttpMessageConverter<?>>`, `Supplier<? extends T>`.

Ещё три вещи, которые часто спрашивают на собеседовании:
1. **Нельзя** `new T()`, `new T[]`, `T.class` — стирается. Обход: передать `Class<T>` (так делает `RestClient`, `JdbcTemplate`).
2. **Нельзя** перегрузить метод по `List<String>`/`List<Integer>` — одинаковая стёртая сигнатура.
3. Мостовые методы (bridge methods) — компилятор генерирует их при ковариантном возврате; Spring при поиске аннотаций использует `BridgeMethodResolver`, чтобы не потерять метаданные.

## 1.6. Аннотации и мета-аннотации: как работает `@RestController`

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)     // без RUNTIME Spring ничего не увидит
public @interface Audited {
    String value() default "";
}
```

`@RestController` — это просто:

```java
@Target(TYPE) @Retention(RUNTIME) @Documented
@Controller
@ResponseBody
public @interface RestController { @AliasFor(annotation = Controller.class) String value() default ""; }
```

Spring ищет аннотации **рекурсивно по мета-аннотациям** (`MergedAnnotations`, `AnnotatedElementUtils`), а `@AliasFor` связывает атрибуты. Отсюда — возможность делать свои «стерильные» аннотации:

```java
@Target(TYPE) @Retention(RUNTIME)
@Service
@Transactional(readOnly = true)
public @interface DomainService {
    @AliasFor(annotation = Transactional.class, attribute = "readOnly") boolean readOnly() default true;
}

@DomainService                          // = @Service + @Transactional(readOnly = true)
public class TaskService { /* ... */ }
```

> **Важно:** `@Inherited` работает только для наследования классов и **не** работает для интерфейсов. Spring учитывает аннотации на интерфейсах сам, «сырая» Java-рефлексия — нет. Это частая причина «почему моя аннотация не видна».

## 1.7. Рефлексия: как контейнер создаёт ваш класс

```java
Constructor<?> ctor = TaskService.class.getDeclaredConstructor(TaskRepository.class);
ctor.setAccessible(true);
Object bean = ctor.newInstance(repository);

Method m = TaskService.class.getDeclaredMethod("complete", Long.class);
m.setAccessible(true);
m.invoke(bean, 42L);
```

Что важно знать:
* Рефлексия **медленнее** прямого вызова в разы, поэтому Spring кэширует `Method`/`Constructor` и генерирует байткод там, где может; `Method.invoke` для горячих путей заменяется на `LambdaMetafactory`/CGLIB `FastClass`.
* `setAccessible(true)` в модульной Java (JPMS) может бросить `InaccessibleObjectException`. Spring Boot-приложения обычно живут в unnamed module (classpath), поэтому проблем нет; в модульных приложениях нужны `opens`.
* **GraalVM native image**: рефлексия должна быть зарегистрирована заранее (`RuntimeHints`). Именно поэтому Boot делает AOT-обработку — см. главу 26.

С Java 17+ для новых библиотек предпочтительнее `MethodHandle`/`LambdaMetafactory`, но Spring исторически на рефлексии + CGLIB, и это надо понимать при чтении стектрейсов.

## 1.8. Прокси своими руками: 40 строк, которые объясняют AOP

Напишем мини-`@Transactional`. Это лучший способ навсегда понять главу 8.

```java
interface Tx { void begin(); void commit(); void rollback(); }

@SuppressWarnings("unchecked")
static <T> T withTransaction(T target, Class<T> iface, Tx tx) {
    return (T) Proxy.newProxyInstance(
        iface.getClassLoader(),
        new Class<?>[]{iface},
        (proxy, method, args) -> {
            tx.begin();
            try {
                Object result = method.invoke(target, args);   // вызов реального метода
                tx.commit();
                return result;
            } catch (InvocationTargetException e) {
                tx.rollback();
                throw e.getCause();                            // разворачиваем обёртку!
            }
        });
}
```

Три вывода, которые объясняют половину «граблей» Spring:
1. **Прокси — отдельный объект.** Он оборачивает целевой. Контейнер отдаёт вам прокси, а не ваш класс.
2. **Внутри целевого объекта `this` — не прокси.** Поэтому вызов `this.otherTransactionalMethod()` **не** открывает новую транзакцию (self-invocation).
3. **JDK-прокси требует интерфейс.** Нет интерфейса → нужен CGLIB (подкласс). Отсюда ограничения: `final`-класс не проксируется, `final`/`private`/`static` методы не перехватываются.

CGLIB-версия (упрощённо, Spring использует встроенный форк CGLIB):

```java
Enhancer enhancer = new Enhancer();
enhancer.setSuperclass(TaskService.class);
enhancer.setCallback((MethodInterceptor) (obj, method, args, proxy) -> {
    // ... до
    Object r = proxy.invokeSuper(obj, args);   // важно: invokeSuper, а не method.invoke(obj)
    // ... после
    return r;
});
TaskService proxy = (TaskService) enhancer.create();
```

> **Практический вывод для кода:** делайте сервисы non-final, публичные методы non-final, не полагаясь на self-invocation. Spring Framework 7 добавил аннотацию `@Proxyable`, чтобы явно управлять типом прокси для конкретного бина (см. главу 8).

## 1.9. ClassLoader и classpath: почему «класс есть, а Spring его не видит»

* Загрузчики образуют иерархию: bootstrap → platform → application. Класс идентифицируется парой **(имя, загрузчик)**. Один и тот же класс из двух загрузчиков — два разных типа, отсюда `ClassCastException: X cannot be cast to X`.
* Spring сканирует classpath через `PathMatchingResourcePatternResolver` (`classpath*:com/app/**/*.class`) и читает **байткод**, а не загружает классы: `MetadataReader` (ASM, а с Java 24+ — новый `ClassFileMetadataReader` на Class-File API). Поэтому `@ComponentScan` не инициализирует классы и не запускает статические блоки.
* Boot uber-jar использует собственный `LaunchedClassLoader` (вложенные jar-ы читаются без распаковки). DevTools использует **два** загрузчика: base (библиотеки) и restart (ваш код) — поэтому перезапуск быстрый.
* В native-image динамическая загрузка классов почти невозможна → AOT.

Мини-эксперимент, который стоит сделать руками:

```java
System.out.println(getClass().getClassLoader());
System.out.println(TaskService.class.getProtectionDomain().getCodeSource().getLocation());
```

## 1.10. Лямбды, стримы, Optional: рабочий стиль сервисного слоя

```java
Map<Priority, List<TaskView>> byPriority = tasks.stream()
        .filter(t -> !t.archived())
        .collect(Collectors.groupingBy(TaskView::priority,
                 Collectors.mapping(TaskView::from, Collectors.toList())));
```

Правила, которые мы будем соблюдать в книге:
* Стрим — для преобразования коллекций, **не** для побочных эффектов и не для «красивых» циклов с БД внутри.
* `Optional` — **тип возврата**, а не поле сущности и не параметр метода. `Optional` в поле JPA-сущности — антипаттерн.
* Никаких `optional.get()` без проверки; `orElseThrow(() -> new TaskNotFoundException(id))`.
* `orElse(expensive())` вычисляет аргумент всегда → используйте `orElseGet(() -> expensive())`.
* Не бросайте checked-исключения из лямбд — оборачивайте или используйте «результат-типы» из §1.4.
* `parallelStream()` в веб-приложении почти всегда вреден: общий `ForkJoinPool.commonPool`, потеря `ThreadLocal`-контекста (транзакции, security, MDC).

## 1.11. Исключения: почему Spring всё оборачивает

```text
Throwable
├── Error (OutOfMemoryError, StackOverflowError) — не ловим
└── Exception
    ├── RuntimeException (unchecked) ← вся иерархия Spring
    │   ├── DataAccessException (SQLException транслируется сюда)
    │   ├── TransactionException
    │   └── BeansException
    └── остальные (checked): IOException, SQLException, InterruptedException
```

Философия Spring: **инфраструктурные ошибки — unchecked**. `SQLException` (checked, привязан к вендору) превращается в `DataAccessException` (unchecked, вендоронезависимый: `DuplicateKeyException`, `DataIntegrityViolationException`, `OptimisticLockingFailureException`). Делает это `PersistenceExceptionTranslator` / `SQLErrorCodeSQLExceptionTranslator`.

Практика:
```java
try {
    return repository.save(task);
} catch (DataIntegrityViolationException e) {          // а не SQLException с кодом 23505
    throw new TaskAlreadyExistsException(task.slug());
}
```

И два обязательных приёма:
```java
try (var in = Files.newInputStream(path)) { /* ... */ }   // try-with-resources

catch (InterruptedException e) {
    Thread.currentThread().interrupt();                   // ВСЕГДА восстанавливаем флаг
    throw new IllegalStateException("Прервано", e);
}
```

## 1.12. equals/hashCode: тема, которая ломает JPA

Контракт: `equals` рефлексивен, симметричен, транзитивен, согласован; равные объекты ⇒ равные хэшкоды. Для сущностей это конфликтует с генерируемым `id`:

```java
@Entity
public class Task {
    @Id @GeneratedValue Long id;

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Task other)) return false;      // instanceof, не getClass():
        return id != null && id.equals(other.id);          // прокси Hibernate — подкласс!
    }
    @Override public int hashCode() {
        return Task.class.hashCode();                      // константа: стабильно до/после persist
    }
}
```

Почему так: до `persist` `id == null`, после — не null; если хэш зависит от `id`, объект «теряется» в `HashSet` при.flush. Подробный разбор — глава 14.

## 1.13. Многопоточность и `ThreadLocal`: фундамент транзакций и Security

Минимум JMM:
* Без синхронизации потоки могут видеть устаревшие значения. `volatile` даёт видимость и запрет переупорядочивания, но **не** атомарность (`i++`).
* `happens-before`: разблокировка монитора → последующая блокировка; запись `volatile` → чтение; `Thread.start()` → всё в потоке; всё в потоке → `join()`.
* Иммутабельные объекты (`final` поля, корректная публикация) потокобезопасны без синхронизации. Отсюда любовь Spring к иммутабельным конфигурациям и records.

**`ThreadLocal` — ключ к Spring:**

```java
// Упрощённая суть TransactionSynchronizationManager
private static final ThreadLocal<Map<Object, Object>> resources = new NamedThreadLocal<>("tx-resources");
```

Так `@Transactional` «прячет» соединение и `EntityManager` в поток: любой код в том же потоке берёт тот же ресурс. То же — `SecurityContextHolder` и `RequestContextHolder`.

Следствия, которые надо запомнить намертво:
1. **Сменили поток — потеряли контекст.** `@Async`, `parallelStream`, `CompletableFuture.supplyAsync`, реактивный pipeline → транзакция/пользователь/MDC не переносятся автоматически.
2. Пулы потоков **переиспользуют** потоки → забытый `ThreadLocal` = утечка памяти и «пользователь из чужого запроса». Spring всегда чистит за собой; ваш код — обязан тоже (`try/finally { remove(); }`).
3. Виртуальные потоки (Java 21+) не любят `ThreadLocal`-кэши «на поток» (их миллионы) — используйте `ScopedValue` (final в Java 25).

**Виртуальные потоки в двух абзацах.** Это дешёвые потоки, планируемые JVM поверх платформенных. Блокирующий вызов (JDBC, HTTP) «отмонтирует» виртуальный поток от носителя, освобождая OS-поток. Итог: классический «поток на запрос» Spring MVC масштабируется до десятков тысяч одновременных запросов **без переписывания на реактивщину**. В Boot достаточно `spring.threads.virtual.enabled=true`. Подводные камни: пулы соединений всё равно ограничены; `synchronized` вокруг блокирующего вызова до Java 24 «пиннил» носитель (в Java 24+ исправлено); `ThreadLocal`-кэши и `ThreadMXBean`-метрики ведут себя иначе. Подробно — глава 24.

```java
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {   // preview-эволюция API, см. JDK docs
    var user  = scope.fork(() -> users.load(id));
    var stats = scope.fork(() -> stats.load(id));
    scope.join().throwIfFailed();
    return new Profile(user.get(), stats.get());
}
```

## 1.14. Память и GC: что реально важно Spring-разработчику

```text
Heap: Young (Eden + Survivor) → Old      | Metaspace: классы, метаданные
Stack (на поток): кадры методов          | Code cache: JIT-код
Direct/Native: Netty, NIO буферы         | GC: G1 (по умолчанию), ZGC/Shenandoah (низкие паузы)
```

Что нужно знать на уровне middle:
* Spring-приложение живёт долго → большая часть бинов «доживает» до Old. Это нормально; проблема — **утечки** (статические `Map`, `ThreadLocal`, кэши без ограничения, `EntityManager` в поле).
* Типовые флаги прода: `-XX:MaxRAMPercentage=75 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError`.
* В контейнере JVM видит лимиты cgroup; `MaxRAMPercentage` важнее `-Xmx` в k8s.
* Диагностика: `jcmd <pid> GC.heap_info`, `jcmd <pid> Thread.print`, JFR (`-XX:StartFlightRecording=duration=60s,filename=app.jfr`), `async-profiler`.

## 1.15. Практика (сделайте руками до главы 2)

1. Напишите `record Money` с компактным конструктором и тестом на нормализацию scale.
2. Сделайте `sealed interface PaymentResult` и `switch` без `default`; удалите одну ветку — посмотрите на ошибку компилятора.
3. Реализуйте `withTransaction(...)` из §1.8 и вызовите метод интерфейса: убедитесь, что «до/после» печатаются.
4. Создайте `@DomainService` из §1.6 и проверьте `AnnotatedElementUtils.findMergedAnnotation(TaskService.class, Service.class) != null` (уже в Spring-проекте).
5. Напишите класс с `ThreadLocal<String>`, запустите задачу в `Executors.newFixedThreadPool(1)` дважды без `remove()` — увидьте «протечку» значения.

## 1.16. Чек-лист готовности

- [ ] Понимаю, почему `final`-класс/метод ломает прокси, и что такое self-invocation.
- [ ] Могу объяснить, откуда Spring знает дженерик-тип `List<Handler>` при стирании типов.
- [ ] Знаю, где records применимы, а где категорически нет (JPA, `@Configuration`).
- [ ] Помню, что `@Transactional`/Security/MDC живут в `ThreadLocal`, и что бывает при смене потока.
- [ ] Отличаю checked от unchecked и знаю, зачем Spring транслирует `SQLException`.
- [ ] Умею снять thread dump и heap info через `jcmd`.

## 1.17. Вопросы для самопроверки

1. Почему `@Retention(RUNTIME)` обязателен для Spring-аннотаций?
2. Что произойдёт, если положить JPA-сущность в `HashSet` до `persist`, а потом сделать `flush`?
3. Почему `method.invoke` в JDK-прокси требует разворачивания `InvocationTargetException`?
4. Чем `orElse` отличается от `orElseGet` и когда это критично?
5. Почему `parallelStream()` внутри `@Transactional`-метода — почти всегда баг?
6. Как Spring читает аннотации, не загружая классы?

---

**Дальше:** [Глава 2. Окружение и первый проект →](02-okruzhenie-i-pervyj-proekt.md)