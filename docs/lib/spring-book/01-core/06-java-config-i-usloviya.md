# Глава 6. Java-конфигурация, условия и программная регистрация бинов

> **Уровень:** junior → middle+
> **Время:** 3–4 часа
> **Цель:** уметь писать конфигурации, которые ведут себя предсказуемо; понимать `proxyBeanMethods`, `@Import`-механику и условия; знать новый `BeanRegistrar` из Framework 7.

## 6.1. `@Configuration`: full vs lite

```java
@Configuration                              // FULL: класс проксируется CGLIB
class FullConfig {
    @Bean Foo foo() { return new Foo(bar()); }   // вызов bar() перехватывается → вернётся бин-синглтон
    @Bean Bar bar() { return new Bar(); }
}

@Configuration(proxyBeanMethods = false)    // LITE: обычный класс, вызовы методов — обычные вызовы
class LiteConfig {
    @Bean Foo foo(Bar bar) { return new Foo(bar); }   // ✅ зависимость через параметр
    @Bean Bar bar() { return new Bar(); }
}
```

**⚙️ Под капотом.** В full-режиме `ConfigurationClassEnhancer` создаёт CGLIB-подкласс, чей `BeanMethodInterceptor` перехватывает вызовы `@Bean`-методов и вместо выполнения тела обращается к `beanFactory.getBean(...)`. Так гарантируется singleton-семантика даже при прямом вызове метода.

**Практические следствия:**
* Full-режим требует non-final класс и non-final `@Bean`-методы, порождает лишний прокси и замедляет старт.
* В **lite**-режиме `bar()` внутри `foo()` создаст **новый объект**, а не бин. Это источник тонких багов.
* Все автоконфигурации Boot используют `proxyBeanMethods = false` — и вам рекомендуется то же. Зависимости объявляйте **параметрами метода**.
* Класс без `@Configuration`, но с `@Bean` (например, `@Component`) — тоже lite-режим.

| | full | lite |
|---|---|---|
| Прокси класса | да | нет |
| Вызов `@Bean`-метода из другого | вернёт бин | создаст новый объект |
| Скорость старта | медленнее | быстрее |
| Ограничения | non-final класс/методы | нет |
| Рекомендация | когда нужен inter-bean вызов | **по умолчанию** |

## 6.2. Анатомия `@Bean`

```java
@Bean(
    name = {"paymentsClient", "payClient"},   // имена (по умолчанию — имя метода)
    initMethod = "start",
    destroyMethod = "close",                  // по умолчанию "(inferred)": close/shutdown находятся автоматически
    autowireCandidate = false                 // исключить из инъекции по типу (например, «служебный» бин)
)
@Qualifier("payments")
@ConditionalOnProperty("app.payments.enabled")
RestClient paymentsClient(RestClient.Builder builder, PaymentProperties props) {
    return builder.baseUrl(props.url()).build();
}
```

Тонкости:
* **`destroyMethod` по умолчанию «inferred»** — Spring сам найдёт `close()`/`shutdown()`. Иногда это вредно (например, вы не хотите закрывать общий `ExecutorService`) → `destroyMethod = ""`.
* `static @Bean` — для инфраструктурных бинов (BFPP), чтобы не инстанцировать конфигурацию раньше времени.
* Тип возврата — **максимально конкретный** (см. 5.8).
* `@Bean` в `@Configuration` может быть `private`? Нет: full-режим требует видимости для CGLIB; в lite — можно, но лучше не надо.

## 6.3. `@ComponentScan`: точная настройка

```java
@SpringBootApplication          // уже включает @ComponentScan своего пакета
@ComponentScan(
    basePackages = "dev.book.taskflow",
    excludeFilters = @ComponentScan.Filter(type = FilterType.REGEX, pattern = ".*\\.legacy\\..*"),
    includeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, classes = DomainService.class),
    useDefaultFilters = false,
    nameGenerator = FullyQualifiedAnnotationBeanNameGenerator.class   // полезно при одинаковых именах в разных пакетах
)
class ScanConfig {}
```

🪤 Не добавляйте `@ComponentScan` без необходимости: он **переопределяет** дефолтное сканирование `@SpringBootApplication` и легко «теряет» половину приложения.

🪤 Одинаковые простые имена классов в разных пакетах (`UserService` в двух модулях) → `ConflictingBeanDefinitionException`. Лечение: `nameGenerator` или явные имена бинов.

## 6.4. `@Import` и три механизма расширения

```java
@Import(DataSourceConfig.class)                       // 1. обычный импорт конфигурации
@Import(TenantImportSelector.class)                   // 2. ImportSelector: вернуть имена классов
@Import(TenantRegistrar.class)                        // 3. ImportBeanDefinitionRegistrar: зарегистрировать определения
```

**`ImportSelector`** — «какие конфигурации подключить», решает по метаданным аннотации:
```java
class TenantImportSelector implements ImportSelector {
    @Override public String[] selectImports(AnnotationMetadata meta) {
        var attrs = meta.getAnnotationAttributes(EnableTenants.class.getName());
        return Boolean.TRUE.equals(attrs.get("audit"))
             ? new String[]{AuditConfig.class.getName(), TenantConfig.class.getName()}
             : new String[]{TenantConfig.class.getName()};
    }
}
```

**`DeferredImportSelector`** — то же, но выполняется **после** обработки всех остальных конфигураций. Именно на нём построена автоконфигурация Boot (`AutoConfigurationImportSelector`), потому что условия `@ConditionalOnMissingBean` должны видеть уже зарегистрированные пользовательские бины.

**`ImportBeanDefinitionRegistrar`** — полный контроль над реестром:
```java
class HttpClientsRegistrar implements ImportBeanDefinitionRegistrar {
    @Override public void registerBeanDefinitions(AnnotationMetadata meta, BeanDefinitionRegistry registry) {
        for (Class<?> iface : discoverInterfaces()) {
            var bd = BeanDefinitionBuilder.genericBeanDefinition(HttpServiceProxyFactoryBean.class)
                    .addPropertyValue("serviceInterface", iface)
                    .getBeanDefinition();
            registry.registerBeanDefinition(iface.getSimpleName(), bd);
        }
    }
}
```
Так работают `@EnableJpaRepositories`, `@EnableFeignClients`, `@ImportHttpServices`.

**Свой `@Enable`-маркер** — идиоматичный способ оформить фичу:
```java
@Target(TYPE) @Retention(RUNTIME)
@Import(TenantImportSelector.class)
public @interface EnableTenants { boolean audit() default true; }
```

## 6.5. `BeanRegistrar` — новинка Framework 7 **[4.x]**

Проблема, которую он решает: в `@Bean`-методе нельзя «по-честному» зарегистрировать несколько бинов, а `ImportBeanDefinitionRegistrar` требует работать с низкоуровневым `BeanDefinition`.

```java
@Configuration(proxyBeanMethods = false)
@Import(TenantClientsRegistrar.class)
class ClientsConfig {}

class TenantClientsRegistrar implements BeanRegistrar {
    @Override
    public void register(BeanRegistry registry, Environment env) {
        for (String tenant : env.getProperty("app.tenants", String[].class, new String[0])) {
            registry.registerBean("client-" + tenant, TenantClient.class,
                () -> new TenantClient(tenant),          // Supplier — ленивое создание
                spec -> spec.description("Клиент тенанта " + tenant));
        }
    }
}
```

Преимущества: типобезопасность, `Supplier` вместо рефлексии (дружелюбно к AOT/native), доступ к `Environment`, регистрация нескольких бинов в одном месте. **[3.5]** аналог — `ImportBeanDefinitionRegistrar` или `GenericApplicationContext#registerBean`.

🎯 На собеседовании: «чем `BeanRegistrar` лучше `@Bean`-метода с циклом?» — тем, что `@Bean` регистрирует ровно одно определение с фиксированным типом, а `BeanRegistrar` — произвольное число определений с корректными метаданными, без «утечки» типов и без нарушения контракта.

## 6.6. Условия: полный набор

| Аннотация | Срабатывает, когда |
|---|---|
| `@ConditionalOnClass` / `OnMissingClass` | класс есть/нет в classpath |
| `@ConditionalOnBean` / `OnMissingBean` | бин есть/нет в контексте (**порядок важен!**) |
| `@ConditionalOnProperty` | свойство равно значению (`matchIfMissing`, `havingValue`) |
| `@ConditionalOnResource` | ресурс существует |
| `@ConditionalOnWebApplication` / `NotWebApplication` | тип приложения (SERVLET/REACTIVE) |
| `@ConditionalOnExpression` | SpEL-выражение истинно |
| `@ConditionalOnJava` | версия JVM |
| `@ConditionalOnThreading` | включены виртуальные потоки |
| `@Profile` | активен профиль (это тоже условие — `ProfileCondition`) |
| `@Conditional(MyCondition.class)` | ваша логика |

```java
class OnKubernetesCondition implements Condition {
    @Override public boolean matches(ConditionContext ctx, AnnotatedTypeMetadata meta) {
        return ctx.getEnvironment().containsProperty("KUBERNETES_SERVICE_HOST");
    }
}

@Bean @Conditional(OnKubernetesCondition.class)
DiscoveryClient k8sDiscovery() { ... }
```

**⚙️ Две фазы условий:** `ConfigurationPhase.PARSE_CONFIGURATION` (можно решить, разбирая конфигурацию — например, `@ConditionalOnClass`) и `REGISTER_BEAN` (нужен реестр бинов — `@ConditionalOnBean`). Условия `OnBean/MissingBean` поэтому применимы почти только в автоконфигурациях, которые обрабатываются последними.

🪤 **Главная грабля условий:** `@ConditionalOnMissingBean` в **вашей** `@Configuration` работает непредсказуемо — обычная конфигурация обрабатывается до автоконфигураций, но порядок между вашими конфигурациями не гарантирован. Хотите «переопределить дефолт Boot» — просто объявите свой бин: автоконфигурация сама отступит.

Диагностика:
```bash
java -jar app.jar --debug     # CONDITIONS EVALUATION REPORT: Positive / Negative / Exclusions / Unconditional
```
```java
// программно
var report = ConditionEvaluationReport.get(beanFactory);
```
Или `/actuator/conditions`.

## 6.7. `@PropertySource`, `@DependsOn`, `@Role`, `@Description`

```java
@Configuration
@PropertySource("classpath:extra.properties")                  // НЕ поддерживает YAML из коробки
@PropertySource(value = "optional:classpath:local.properties") // optional: — не падать, если файла нет
class ExtraConfig {}

@Bean @DependsOn("flywayInitializer")                          // жёсткий порядок создания
SomeBean someBean() { ... }

@Bean @Role(BeanDefinition.ROLE_INFRASTRUCTURE)                 // «служебный», не мешает autowireCandidate-логике
@Description("Клиент платёжного шлюза")
RestClient payments() { ... }
```

🪤 `@PropertySource` имеет **низкий приоритет** и обрабатывается поздно; для профильных YAML используйте `spring.config.import` (глава 10).

## 6.8. Композиция аннотаций: делаем «свой Spring»

```java
@Target(TYPE) @Retention(RUNTIME) @Documented
@Service
@Transactional(readOnly = true)
@Validated
public @interface ApplicationService {
    @AliasFor(annotation = Transactional.class, attribute = "readOnly") boolean readOnly() default true;
}
```

Теперь `@ApplicationService` — самодокументирующая architectural-аннотация. В связке с ArchUnit (глава 23) это позволяет **проверять архитектуру тестами**: «все классы в `..application..` помечены `@ApplicationService`».

## 6.9. Конфигурации в тестах

```java
@SpringBootTest
class TaskServiceIT {

    @TestConfiguration                       // добавляется к основной конфигурации, не заменяет её
    static class Stubs {
        @Bean Clock fixedClock() { return Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC); }
    }
}
```

🪤 Вложенная `@Configuration` (без `@TestConfiguration`) **заменяет** основную конфигурацию теста. Это самая частая причина «почему в тесте пропали все бины».

Ещё приёмы: `@Import(Stubs.class)`, `@ContextConfiguration(classes = ...)`, `@MockitoBean` **[4.x]** / `@MockBean` **[3.5]**, профили `@ActiveProfiles("test")`.

## 6.10. Антипаттерны конфигураций

| Антипаттерн | Почему плохо | Как надо |
|---|---|---|
| `@Configuration` на 500 строк со всеми бинами | нечитаемость, конфликты | по конфигурации на модуль/технологию |
| Вызов `@Bean`-метода в lite-режиме | создаётся «дикий» объект | зависимость через параметр |
| `@ConditionalOnMissingBean` в пользовательской конфигурации | недетерминированный порядок | просто объявите свой бин |
| Бизнес-логика внутри `@Bean`-метода | не тестируется, не переиспользуется | вынесите в класс |
| `static` поля-состояние в конфигурации | утечки между тестами | бины + скоупы |
| `@Autowired` поле в `@Configuration` | цикл с обработкой конфигурации | параметры `@Bean`-методов |
| XML + Java вперемешку без причины | два источника правды | только Java (XML — legacy) |

## 6.11. 🧪 Практика

1. Переведите full-конфигурацию в lite и специально вызовите `@Bean`-метод напрямую — докажите тестом, что объектов стало два.
2. Сделайте `@EnableTenants(audit = true)` c `ImportSelector` и убедитесь, что бины появляются/исчезают.
3. **[4.x]** Перепишите ту же задачу на `BeanRegistrar`.
4. Напишите `Condition`, включающую бин только при наличии переменной окружения, и проверьте отчёт `--debug`.
5. Сломайте тест вложенной `@Configuration` и почините `@TestConfiguration`.

## 6.12. Чек-лист и вопросы

- [ ] По умолчанию `proxyBeanMethods = false`, зависимости — через параметры.
- [ ] Понимаю разницу `ImportSelector` / `DeferredImportSelector` / `ImportBeanDefinitionRegistrar` / `BeanRegistrar`.
- [ ] Знаю, почему `@ConditionalOnMissingBean` — инструмент автоконфигураций.
- [ ] Умею читать condition report и объяснять «почему бин не создался».

**Вопросы:** 1) Что делает CGLIB в full-режиме? 2) Почему автоконфигурация — `DeferredImportSelector`? 3) Чем `@Profile` отличается от `@ConditionalOnProperty`? 4) Зачем `static` у `@Bean` BFPP? 5) Как зарегистрировать N бинов из списка в конфиге (два способа)?

---

**Назад:** [Глава 5](05-kontejner-vnutri.md) · **Дальше:** [Глава 7. Ресурсы, Environment, SpEL и события →](07-resursy-spel-sobytiya.md)