# Глава 8. AOP и прокси: как Spring «оборачивает» ваш код

> **Уровень:** junior → middle+
> **Время:** 4–5 часов
> **Цель:** писать свои аспекты, понимать, почему `@Transactional` «не работает», читать стектрейсы с `CglibAopProxy` и объяснять порядок интерсепторов.

## 8.1. Зачем AOP

Есть логика, которая **размазана по всему приложению** и не относится к бизнес-смыслу: транзакции, логирование, метрики, аудит, кэш, retry, проверка прав, мультитенантность. Это cross-cutting concerns. Без AOP вы пишете одно и то же в 200 методах; с AOP — один аспект.

Spring сам построен на AOP:

| Фича | Что перехватывает |
|---|---|
| `@Transactional` | `TransactionInterceptor` |
| `@Cacheable`/`@CacheEvict` | `CacheInterceptor` |
| `@Async` | `AsyncExecutionInterceptor` |
| `@PreAuthorize` | `AuthorizationManagerBeforeMethodInterceptor` |
| `@Retryable`, `@ConcurrencyLimit` **[4.x]** | интерсепторы core-resilience |
| `@Timed`, `@Counted`, `@Observed` | Micrometer-аспекты |
| Spring Data репозитории | прокси с `QueryExecutorMethodInterceptor` |

## 8.2. Терминология (её спрашивают дословно)

* **Join point** — точка выполнения. В Spring AOP это **всегда вызов метода** (не поле, не конструктор).
* **Pointcut** — предикат, выбирающий join point-ы.
* **Advice** — код, выполняемый в выбранной точке (before/after/around).
* **Aspect** — класс, содержащий pointcut-ы и advice-ы.
* **Target** — целевой объект; **Proxy** — обёртка; **Weaving** — процесс связывания.
* **Introduction** — добавление интерфейса бину (`@DeclareParents`).

## 8.3. Spring AOP vs AspectJ

| | Spring AOP | AspectJ (CTW/LTW) |
|---|---|---|
| Механизм | прокси во время выполнения | изменение байткода (compile/load-time weaving) |
| Join points | вызовы public-методов бинов | + поля, конструкторы, private, static, любые классы |
| Self-invocation | **не перехватывается** | перехватывается |
| Требования | бин в контейнере | аспект-компилятор/агент |
| Сложность | низкая | выше (агент, конфигурация сборки) |
| Скорость | оверхед прокси на вызов | почти нет оверхеда |
| Когда | 95 % задач | нужен перехват внутри класса/не-бинов |

Spring использует **аннотации AspectJ** (`@Aspect`, `@Around`) и его синтаксис pointcut-ов, но **не** его weaving. Это гибрид, который часто путают.

## 8.4. Подключение

**[4.x]**
```xml
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-aspectj</artifactId></dependency>
```
**[3.5]**
```xml
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-aop</artifactId></dependency>
```

🪤 **[4.x] Важный нюанс модуляризации:** стартер переименован, чтобы показать — он нужен для **AspectJ-аннотаций**. Проксирование (`@Transactional`, `@Async`, `@Cacheable`) работает и **без** него: `spring-aop` входит в базовые стартеры. Добавляйте `starter-aspectj`, только если реально пишете `@Aspect` (или используете библиотеку с аспектами, например Micrometer `@Timed`).

Boot включает AOP автоматически (`AopAutoConfiguration`), дефолт — **CGLIB** (`spring.aop.proxy-target-class=true`). Ручное включение:
```java
@Configuration
@EnableAspectJAutoProxy(proxyTargetClass = true, exposeProxy = false)
class AopConfig {}
```

## 8.5. Первый аспект: аннотация + замер времени

```java
@Target(ElementType.METHOD) @Retention(RetentionPolicy.RUNTIME)
public @interface LogExecution { String value() default ""; }
```

```java
@Aspect
@Component
@RequiredArgsConstructor
public class ExecutionLoggingAspect {
    private static final Logger log = LoggerFactory.getLogger("EXEC");

    @Around("@annotation(logExecution)")
    public Object measure(ProceedingJoinPoint pjp, LogExecution logExecution) throws Throwable {
        String label = logExecution.value().isEmpty()
                ? pjp.getSignature().toShortString() : logExecution.value();
        long t0 = System.nanoTime();
        try {
            Object result = pjp.proceed();                    // ← вызов целевого метода
            log.info("{} ok за {} мс", label, (System.nanoTime()-t0)/1_000_000);
            return result;
        } catch (Throwable ex) {
            log.warn("{} упал за {} мс: {}", label, (System.nanoTime()-t0)/1_000_000, ex.toString());
            throw ex;                                          // ← ВСЕГДА пробрасываем
        }
    }
}
```

```java
@Service
class TaskService {
    @LogExecution("создание задачи")
    public TaskId create(CreateTaskRequest req) { ... }
}
```

Три обязательных правила `@Around`:
1. Возвращайте результат `proceed()` (иначе метод «вернёт null»).
2. Пробрасывайте исключение (иначе сломаете rollback-правила транзакций).
3. Сигнатура: `Object method(ProceedingJoinPoint pjp) throws Throwable`.

## 8.6. Pointcut-выражения: полный рабочий набор

| Designator | Что выбирает | Пример |
|---|---|---|
| `execution` | сигнатуры методов (основной) | `execution(* dev.book..service.*.*(..))` |
| `within` | все методы внутри типов/пакетов | `within(dev.book.taskflow..*)` |
| `@annotation` | метод помечен аннотацией | `@annotation(org.springframework.transaction.annotation.Transactional)` |
| `@within` | тип помечен аннотацией | `@within(dev.book.ApplicationService)` |
| `@target` | рантайм-класс цели помечен | `@target(javax.annotation.ManagedBean)` |
| `this` | **прокси** является типом | `this(dev.book.api.TaskApi)` |
| `target` | **целевой объект** является типом | `target(dev.book.task.TaskService)` |
| `args` | типы аргументов (+ биндинг) | `args(id,..) && args(Long)` |
| `@args` | аннотации на типах аргументов | `@args(dev.book.Validated)` |
| `bean` | имя бина (Spring-специфичный) | `bean(*Service)` |

Разбор `execution`:
```text
execution(modifiers? ret-type declaring-type?.name(params) throws?)
execution(public * dev.book..*Service.find*(Long, ..))
          │      │  │            │        │      └─ первый аргумент Long, далее любые
          │      │  │            │        └─ имя метода начинается с find
          │      │  │            └─ любой класс, оканчивающийся на Service
          │      │  └─ любой подпакет dev.book
          │      └─ любой возвращаемый тип
          └─ только public
```

Композиция и именованные pointcut-ы:
```java
@Aspect @Component
public class ArchitecturePointcuts {
    @Pointcut("within(dev.book.taskflow..*)")            public void inApp() {}
    @Pointcut("execution(public * *(..))")               public void publicMethod() {}
    @Pointcut("@annotation(dev.book.LogExecution)")      public void logged() {}
    @Pointcut("inApp() && publicMethod() && !logged()")  public void needsLogging() {}
}

@Around("dev.book.aop.ArchitecturePointcuts.needsLogging()")
public Object log(ProceedingJoinPoint pjp) throws Throwable { ... }
```

Биндинг аргументов и аннотаций:
```java
@Before("execution(* dev.book..*Service.*(id,..)) && args(id,..)")
public void checkId(Long id) { Assert.isTrue(id > 0, "id должен быть положительным"); }

@Around("@annotation(audited)")
public Object audit(ProceedingJoinPoint pjp, Audited audited) throws Throwable { ... }
```

🪤 `this` vs `target`: при JDK-прокси `this` — прокси (реализует интерфейс, но **не** является подклассом целевого класса), поэтому `target(...)` для класса и `this(...)` для интерфейса. При CGLIB两者 совпадают. Это любимый вопрос на собеседовании.

## 8.7. Типы advice и порядок

```java
@Before("pc()")                 void before(JoinPoint jp) {}
@AfterReturning(pointcut="pc()", returning="result") void ok(JoinPoint jp, Object result) {}
@AfterThrowing(pointcut="pc()", throwing="ex")       void fail(JoinPoint jp, Exception ex) {}
@After("pc()")                  void finallyAlways(JoinPoint jp) {}   // finally-семантика
@Around("pc()")                 Object around(ProceedingJoinPoint pjp) throws Throwable { return pjp.proceed(); }
```

**Порядок между аспектами** — `@Order` / `Ordered` (меньше значение = выше приоритет = «внешнее» кольцо):
```java
@Aspect @Component @Order(100) class SecurityAspect {}     // войдёт первым, выйдет последним
@Aspect @Component @Order(200) class TransactionAspect {}
@Aspect @Component @Order(300) class LoggingAspect {}
```
```text
Security.before → Tx.before → Logging.before → METHOD → Logging.after → Tx.after → Security.after
```

**Порядок advice внутри одного аспекта** (Spring 5.2.7+, зафиксировано в документации): `@Around` → `@Before` → `@After` → `@AfterReturning` → `@AfterThrowing`. Если нужен строгий контроль — разносите по разным аспектам с `@Order` или объединяйте в один `@Around`.

🎯 **Важнейший практический кейс:** `@Transactional` имеет приоритет `Ordered.LOWEST_PRECEDENCE` по умолчанию. Значит ваш `@Order(100)`-аспект выполнится **вне** транзакции. Если аспект должен видеть данные внутри транзакции (например, аудит с чтением БД) — дайте ему `@Order(Ordered.LOWEST_PRECEDENCE)` или больше, либо явно задайте порядок транзакций: `@EnableTransactionManagement(order = 200)`.

## 8.8. ⚙️ Под капотом: как рождается прокси

```text
AnnotationAwareAspectJAutoProxyCreator (это SmartInstantiationAwareBeanPostProcessor)
  └─ postProcessAfterInitialization(bean, name)
      └─ wrapIfNecessary(bean, name, cacheKey)
          ├─ getAdvicesAndAdvisorsForBean: найти ВСЕ подходящие Advisor-ы
          │    ├─ BeanFactoryAspectJAdvisorsBuilder: распарсить @Aspect-бины → Advisor на каждый advice
          │    ├─ MethodMatcher.matches(method, targetClass) для каждого метода (статический матчинг)
          │    └─ отсортировать по @Order
          ├─ если Advisor-ов нет → вернуть исходный объект (прокси не нужен!)
          └─ createProxy → ProxyFactory
               ├─ есть интерфейсы и proxyTargetClass=false → JdkDynamicAopProxy
               └─ иначе → ObjenesisCglibAopProxy (подкласс, создаётся через Objenesis без вызова конструктора)
```

Вызов метода:
```text
proxy.method()
 └─ JdkDynamicAopProxy#invoke / CglibAopProxy$DynamicAdvisedInterceptor#intercept
     ├─ получить цепочку интерсепторов (кэшируется по методу)
     ├─ добавить ExposeInvocationInterceptor (для AopContext.currentInvocation())
     └─ new ReflectiveMethodInvocation(...).proceed()
          └─ рекурсивно: interceptor[0].invoke(this) → interceptor[1] ... → invokeJoinpoint() (reflection)
```

Отсюда важные следствия:
* **Прокси создаётся только если есть хотя бы один подходящий Advisor.** «Почему мой бин не проксируется?» — потому что pointcut не совпал.
* Цепочка — это **рекурсия**, а не цикл: поэтому `@Around` обязан вызвать `proceed()`.
* Матчинг кэшируется → оверхед на вызов невелик (десятки наносекунд + рефлексия), но не нулевой.
* Objenesis создаёт CGLIB-прокси **без вызова конструктора** → поля прокси не инициализированы; работать должен только перехват. Поэтому нельзя полагаться на состояние прокси-объекта.

Программное проксирование (полезно в тестах и библиотеках):
```java
ProxyFactory pf = new ProxyFactory(target);
pf.addAdvice((MethodInterceptor) inv -> { long t = System.nanoTime(); try { return inv.proceed(); }
                                          finally { log.info("{} ns", System.nanoTime()-t); } });
pf.setProxyTargetClass(true);
TaskService proxy = (TaskService) pf.getProxy();
```

## 8.9. Self-invocation: главная грабля AOP

```java
@Service
class TaskService {
    public void bulk(List<CreateTaskRequest> reqs) {
        reqs.forEach(this::create);        // ❌ @Transactional на create НЕ сработает
    }
    @Transactional public TaskId create(CreateTaskRequest req) { ... }
}
```
Причина: `this` — целевой объект, а не прокси. Вызов не проходит через цепочку интерсепторов.

Четыре решения (в порядке предпочтения):
1. **Рефакторинг:** вынести `create` в другой бин (`TaskCreator`) — чище всего и лучше для дизайна.
2. **Само-инъекция через прокси:**
   ```java
   @Service
   class TaskService {
       private final ObjectProvider<TaskService> self;
       void bulk(List<CreateTaskRequest> reqs) { reqs.forEach(r -> self.getObject().create(r)); }
   }
   ```
3. **`AopContext.currentProxy()`** — требует `exposeProxy = true`, «грязно» и связывает код с Spring:
   ```java
   ((TaskService) AopContext.currentProxy()).create(req);
   ```
4. **AspectJ weaving** — если таких мест много и рефакторинг невозможен.

🪤 Тот же механизм объясняет: `@Transactional` на `private`/`final`/`static` методе не работает; `@Async` внутри того же класса не работает; `@Cacheable` при внутреннем вызове не кэширует.

## 8.10. Управление типом прокси: `@Proxyable` **[4.x]**

Framework 7 унифицировал дефолт (CGLIB для всех proxy-процессоров, включая `@Async`) и добавил точечный контроль:

```java
@Service
@Proxyable(Proxyable.Kind.INTERFACES)      // для этого бина — JDK-прокси по интерфейсам
class TaskServiceImpl implements TaskService { ... }

@Bean
@Proxyable(interfaces = TaskService.class) // конкретные интерфейсы прокси
TaskServiceImpl taskService() { ... }
```

Глобальный дефолт — бин `ProxyConfig` с именем `AutoProxyUtils.DEFAULT_PROXY_CONFIG_BEAN_NAME`. **[3.5]** — только `spring.aop.proxy-target-class` и `@EnableAspectJAutoProxy`.

Практическое правило: **не полагайтесь на тип прокси**. Инжектите интерфейс, а если инжектите класс — помните, что это CGLIB-подкласс, и `getClass()` вернёт `TaskService$$SpringCGLIB$$0`. Для получения реального класса: `AopUtils.getTargetClass(bean)`, для разворачивания: `AopProxyUtils.getSingletonTarget(bean)`.

## 8.11. Практические аспекты, которые реально нужны

**Метрики без Micrometer-аннотаций:**
```java
@Around("@within(org.springframework.web.bind.annotation.RestController)")
public Object meter(ProceedingJoinPoint pjp) throws Throwable {
    Timer.Sample s = Timer.start(registry);
    try { return pjp.proceed(); }
    finally { s.stop(registry.timer("app.controller", "method", pjp.getSignature().toShortString())); }
}
```

**Аудит с SpEL-ключом:**
```java
@Around("@annotation(audited)")
public Object audit(ProceedingJoinPoint pjp, Audited audited) throws Throwable {
    var ctx = new SimpleEvaluationContext.Builder(/* read-only */).build();   // безопасный контекст
    // ... вычислить ключ из аргументов, записать «до», выполнить, записать «после»
    return pjp.proceed();
}
```

**Resilience штатными средствами [4.x]:**
```java
@Configuration @EnableResilientMethods class ResilienceConfig {}

@Service
class PaymentsGateway {
    @Retryable(includes = IOException.class, maxAttempts = 4, delay = 200, multiplier = 2, maxDelay = 2000)
    @ConcurrencyLimit(20)
    public Receipt charge(Order order) throws IOException { ... }
}
```
**[3.5]** то же через Spring Retry: `@EnableRetry`, `@Retryable(retryFor = IOException.class, backoff = @Backoff(...))`, `@Recover`. В Boot 4 dependency management для Spring Retry **удалён** — переходите на core.

🪤 Аспект **не заменяет** идемпотентность: retry платежа без idempotency-key = двойное списание. Retry — только для идемпотентных операций или с ключом идемпотентности (глава 19).

## 8.12. 🪤 Топ-12 граблей AOP

1. Self-invocation (см. 8.9).
2. `final` класс/метод → CGLIB не может перехватить (Kotlin: классы final по умолчанию → плагин `kotlin-spring`/`allopen`).
3. `private`/`static`/`package-private` методы — не перехватываются.
4. Аспект на бине, созданным через `new` — не работает вообще.
5. Забыли `return pjp.proceed()` → метод возвращает `null`.
6. Проглотили исключение → транзакция не откатилась.
7. Порядок с `@Transactional` (аспект вне транзакции).
8. `@Async` + `@Transactional` на одном методе: транзакция откроется в другом потоке — поведение не то, что ожидалось.
9. Двойное проксирование (аспект + `@Transactional` + `@Async`) → неожиданный порядок и «прокси прокси».
10. `instanceof`/`getClass()` на прокси → неверные выводы.
11. Аспект на репозитории Spring Data: интерфейс уже проксируется — легко получить конфликт типов; матчите по `target`, не по `this`.
12. Pointcut слишком широкий (`execution(* *(..))`) → приложение тормозит и логи тонут.

## 8.13. Тестирование аспектов

```java
@Test
void aspectMeasuresExecution() {
    TaskService target = new TaskService(fakeRepo);
    ProxyFactory pf = new ProxyFactory(target);
    AspectJProxyFactory factory = new AspectJProxyFactory(target);
    factory.addAspect(new ExecutionLoggingAspect());
    TaskService proxy = factory.getProxy();
    proxy.create(request);
    // проверяем лог/метрику
}
```
Плюс интеграционный тест: поднять контекст с аспектом и убедиться, что `AopUtils.isAopProxy(bean)` и что advice реально сработал. 🎯 На middle+ просят объяснить, **как проверить, что бин проксируется** — вот эти два API.

## 8.14. Когда всё-таки AspectJ

Нужен перехват: внутри класса (self-invocation), конструкторов, полей, `private`, классов вне контейнера (например, JPA-сущностей), статических методов. Тогда:
* **CTW** — компиляция аспектов на этапе сборки (плагин `aspectj-maven-plugin`), лучший вариант по скорости;
* **LTW** — `-javaagent:aspectjweaver.jar` + `@EnableLoadTimeWeaving`.

Цена: усложнение сборки, конфликты с AOT/native, «невидимая» магия для новых разработчиков. Используйте осознанно и документируйте.

## 8.15. 🧪 Практика

1. Сделайте `@LogExecution` и примените к трём методам; проверьте, что при internal-вызове лога нет.
2. Напишите два аспекта с `@Order(100)` и `@Order(200)`, распечатайте порядок «вход/выход».
3. Добавьте `@Transactional` и определите, где оказался ваш аспект относительно транзакции; измените `@EnableTransactionManagement(order=...)`.
4. Сделайте аспект, который «глотает» исключение, и покажите тестом, что транзакция закоммитилась. Потом исправьте.
5. **[4.x]** Замените Spring Retry на `@Retryable` из core и `@ConcurrencyLimit`.

## 8.16. Чек-лист и вопросы

- [ ] Понимаю разницу Spring AOP и AspectJ и когда нужен второй.
- [ ] Знаю, где в жизненном цикле создаётся прокси и почему это важно.
- [ ] Умею написать pointcut с биндингом аргументов и аннотации.
- [ ] Помню про self-invocation и четыре способа обхода.
- [ ] Управляю порядком аспектов относительно транзакций.

**Вопросы:** 1) Что такое `Advisor` и чем отличается от `Advice`? 2) Почему `this` и `target` дают разный результат при JDK-прокси? 3) На каком шаге `refresh()` появляются прокси? 4) Почему CGLIB-прокси создаётся через Objenesis и что это значит? 5) Как проверить, что метод реально перехвачен? 6) Почему `@Around` обязан пробрасывать исключения? 7) Что делает `exposeProxy=true` и чем это плохо?

---

**Назад:** [Глава 7](07-resursy-spel-sobytiya.md) · **Дальше:** [Глава 9. Автоконфигурация и свои стартеры →](../02-boot/09-avtokonfiguraciya-i-startery.md)