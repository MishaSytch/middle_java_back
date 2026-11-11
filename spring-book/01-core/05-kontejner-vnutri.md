# Глава 5. ⚙️ Контейнер изнутри: `refresh()`, BeanDefinition, пост-процессоры, кэши синглтонов

> **Уровень:** middle → middle+
> **Время:** 4–6 часов
> **Цель:** уметь прочитать любой стектрейс Spring, написать свой пост-процессор, объяснить порядок инициализации и понять, откуда берутся прокси. Это глава, после которой Spring перестаёт быть чёрным ящиком.

## 5.1. Две фазы жизни контейнера

```text
ФАЗА 1: собрать реестр определений (BeanDefinition)      ФАЗА 2: создать объекты
─────────────────────────────────────────────────      ─────────────────────────
сканирование, @Bean-методы, @Import, XML,               getBean → создание, инъекция,
программная регистрация → Map<String, BeanDefinition>   пост-обработка, кэш синглтонов
        ↑ здесь можно МЕНЯТЬ определения                        ↑ здесь можно МЕНЯТЬ объекты
     BeanFactoryPostProcessor                                BeanPostProcessor
```

Это разделение — **самая важная идея главы**. `BeanFactoryPostProcessor` работает с *метаданными* (класс ещё не загружен как объект), `BeanPostProcessor` — с *экземплярами*.

## 5.2. `AbstractApplicationContext#refresh()` — 12 шагов

Реальный метод (упрощённо, с комментариями):

```java
public void refresh() {
    synchronized (this.startupShutdownMonitor) {
        prepareRefresh();                            // 1. флаги, время старта, инициализация property sources
        ConfigurableListableBeanFactory bf = obtainFreshBeanFactory();  // 2. создать/получить BeanFactory
        prepareBeanFactory(bf);                      // 3. ClassLoader, SpEL-resolver, регистрация Aware-процессоров
        postProcessBeanFactory(bf);                  // 4. хук для подклассов (web-контексты регистрируют скоупы)
        invokeBeanFactoryPostProcessors(bf);         // 5. ★ ConfigurationClassPostProcessor: парсинг @Configuration,
                                                     //    @ComponentScan, @Import, @Bean → BeanDefinition
        registerBeanPostProcessors(bf);              // 6. ★ регистрация BeanPostProcessor-ов (в порядке Priority/Ordered)
        initMessageSource();                         // 7. i18n
        initApplicationEventMulticaster();           // 8. инфраструктура событий
        onRefresh();                                 // 9. ★ Boot: создание web-сервера (Tomcat) здесь
        registerListeners();                         // 10. регистрация ApplicationListener-ов
        finishBeanFactoryInitialization(bf);         // 11. ★★ создание ВСЕХ не-ленивых синглтонов
        finishRefresh();                             // 12. LifecycleProcessor.onRefresh(), ContextRefreshedEvent
    }
}
```

**Что из этого practically важно:**
* Ошибка «бин не найден» на шаге 5 — проблема *определений* (сканирование, условия, профили).
* Ошибка на шаге 11 — проблема *создания* (зависимости, циклы, конструктор бросил).
* Web-сервер поднимается на шаге 9, **до** создания большинства бинов; поэтому `ApplicationReadyEvent` — единственное надёжное «всё готово».
* `BeanFactoryPostProcessor`-ы **создаются раньше** обычных бинов → если ваш BFPP зависит от сервиса, вы «сломаете» порядок и получите предупреждение `is not eligible for getting processed by all BeanPostProcessors`.

## 5.3. `BeanDefinition`: что контейнер знает о бине

```java
BeanDefinition bd = beanFactory.getBeanDefinition("taskService");
bd.getBeanClassName();          // dev.book.taskflow.task.TaskService
bd.getScope();                  // singleton
bd.isLazyInit();
bd.getDependsOn();
bd.getInitMethodName(); bd.getDestroyMethodName();
bd.getConstructorArgumentValues();
bd.getPropertyValues();
bd.getFactoryMethodName();      // для @Bean — имя метода
bd.getRole();                   // APPLICATION / INFRASTRUCTURE / SUPPORT
```

Полезно: `AbstractBeanDefinition`, `AnnotatedGenericBeanDefinition`, `ScannedGenericBeanDefinition`, `ConfigurationClassBeanDefinition`.

Откуда берутся определения:
* `ClassPathBeanDefinitionScanner` — сканирует `classpath*:` через `MetadataReader` (**без загрузки классов**), фильтрует по `@Component` и include/exclude-фильтрам;
* `AnnotatedBeanDefinitionReader` — `register(Class)`;
* `ConfigurationClassPostProcessor` — парсит `@Configuration`, `@Bean`, `@Import`, `@ImportResource`, `@PropertySource`;
* `BeanDefinitionRegistryPostProcessor` — ваш программный код;
* Boot: `AutoConfigurationImportSelector` — читает `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`.

🎯 **Почему сканирование не грузит классы:** скорость и безопасность. Если бы Spring загружал все классы, любой `static {}` с обращением к БД выполнялся бы на старте, а native-image требовал бы рефлексию для всего.

## 5.4. `BeanFactoryPostProcessor` и `BeanDefinitionRegistryPostProcessor`

```java
// Меняет существующие определения
@Component
class TimeoutTuner implements BeanFactoryPostProcessor {
    @Override public void postProcessBeanFactory(ConfigurableListableBeanFactory bf) {
        for (String name : bf.getBeanNamesForType(RestClient.class)) {
            BeanDefinition bd = bf.getBeanDefinition(name);
            bd.setLazyInit(true);
        }
    }
}

// Регистрирует новые определения
@Component
class TenantRegistrar implements BeanDefinitionRegistryPostProcessor {
    @Override public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) {
        for (String tenant : List.of("acme", "globex")) {
            var bd = BeanDefinitionBuilder.genericBeanDefinition(TenantClient.class)
                    .addConstructorArgValue(tenant)
                    .getBeanDefinition();
            registry.registerBeanDefinition("client-" + tenant, bd);
        }
    }
}
```

Порядок вызова: сначала все `BeanDefinitionRegistryPostProcessor` (в порядке `PriorityOrdered` → `Ordered` → остальные), затем `postProcessBeanFactory` у них, затем обычные `BeanFactoryPostProcessor` в том же порядке.

🪤 **Классика:** `PropertySourcesPlaceholderConfigurer` — это BFPP. Если ваш BFPP/BPP инжектит бины, содержащие `${...}`, плейсхолдеры могут быть ещё не разрешены. Поэтому инфраструктурные `@Bean`-методы объявляют **`static`**:

```java
@Bean
static PropertySourcesPlaceholderConfigurer placeholderConfigurer() { return new PropertySourcesPlaceholderConfigurer(); }
```
`static` позволяет создать бин, **не инстанцируя** `@Configuration`-класс (иначе класс создастся слишком рано и не получит CGLIB-усиление/пост-обработку).

## 5.5. Жизненный цикл одного бина: полный порядок

```text
1.  resolveBeforeInstantiation  → InstantiationAwareBeanPostProcessor#postProcessBeforeInstantiation
                                  (может вернуть «подставной» объект — так работает AOP-таргетинг)
2.  createBeanInstance          → выбор конструктора (SmartInstantiationAwareBPP#determineCandidateConstructors),
                                  AutowiredAnnotationBeanPostProcessor находит @Autowired-конструктор,
                                 Supplier/factory-method/рефлексия
3.  applyMergedBeanDefinitionPostProcessors → сбор метаданных @Autowired/@Resource/@PostConstruct
4.  addSingletonFactory         → в кэш 3-го уровня кладётся ObjectFactory для «ранней ссылки» (циклы!)
5.  populateBean                → postProcessAfterInstantiation, инъекция полей/сеттеров (@Autowired, @Value)
6.  invokeAwareMethods          → BeanNameAware, BeanClassLoaderAware, BeanFactoryAware
7.  postProcessBeforeInitialization → ApplicationContextAwareProcessor (EnvironmentAware, ResourceLoaderAware,
                                      ApplicationEventPublisherAware, ApplicationContextAware),
                                      CommonAnnotationBeanPostProcessor → @PostConstruct
8.  afterPropertiesSet          → InitializingBean
9.  invokeCustomInitMethod      → @Bean(initMethod="...")
10. postProcessAfterInitialization → ★ AbstractAutoProxyCreator создаёт ПРОКСИ (AOP, @Transactional, @Async, @Cacheable)
11. бин готов, лежит в singletonObjects
...
12. @PreDestroy → DisposableBean.destroy() → @Bean(destroyMethod)
```

**Три вывода, которые стоят всей главы:**
1. **Прокси создаётся на шаге 10**, то есть *после* `@PostConstruct`. Значит внутри `@PostConstruct` `this` — **не прокси**, и `@Transactional`/`@Async` там не работают.
2. Инъекция полей (шаг 5) происходит **до** `@PostConstruct` (шаг 7) — поэтому в `@PostConstruct` зависимости доступны.
3. Aware-интерфейсы (шаг 6) вызываются до `@PostConstruct`, но `ApplicationContextAware` — через BPP на шаге 7 (порядок внутри шага важен при отладке).

## 5.6. `BeanPostProcessor`: практические примеры

```java
// 1. Валидация аннотации на этапе старта (fail-fast вместо сюрприза в рантайме)
@Component
class AuditedValidator implements BeanPostProcessor {
    @Override public Object postProcessAfterInitialization(Object bean, String name) {
        Class<?> target = AopUtils.getTargetClass(bean);          // важно: разворачиваем прокси
        if (AnnotatedElementUtils.hasAnnotation(target, Audited.class)
                && !Auditable.class.isAssignableFrom(target)) {
            throw new IllegalStateException("@Audited требует Auditable: " + target);
        }
        return bean;
    }
}

// 2. Замер времени создания бинов — отличная диагностика медленного старта
@Component
class BeanTimingProcessor implements InstantiationAwareBeanPostProcessor {
    private final Map<String, Long> start = new ConcurrentHashMap<>();
    @Override public Object postProcessBeforeInstantiation(Class<?> type, String name) {
        start.put(name, System.nanoTime()); return null;
    }
    @Override public Object postProcessAfterInitialization(Object bean, String name) {
        Long t = start.remove(name);
        if (t != null && (System.nanoTime() - t) > 100_000_000L) {
            System.out.printf("Медленный бин %s: %d мс%n", name, (System.nanoTime()-t)/1_000_000);
        }
        return bean;
    }
}
```

Разновидности BPP, которые надо знать:

| Интерфейс | Что добавляет |
|---|---|
| `BeanPostProcessor` | before/after initialization |
| `InstantiationAwareBeanPostProcessor` | до инстанцирования, после инстанцирования, до инъекции свойств |
| `SmartInstantiationAwareBeanPostProcessor` | выбор конструкторов, **ранняя ссылка** для циклов |
| `MergedBeanDefinitionPostProcessor` | доступ к «слитому» BeanDefinition + метаданные |
| `DestructionAwareBeanPostProcessor` | хук перед уничтожением (`@PreDestroy` реализован так) |

🪤 BPP **не применяется к самому себе** и к бинам, созданным раньше него. Отсюда предупреждение в логах: `Bean 'x' of type [...] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying)`. Если вы видите его для сервиса с `@Transactional` — транзакций у него **не будет**.

## 5.7. Три уровня кэша синглтонов и циклы

```java
// DefaultSingletonBeanRegistry
Map<String, Object> singletonObjects        = new ConcurrentHashMap<>(256); // 1: готовые
Map<String, Object> earlySingletonObjects   = new HashMap<>(16);            // 2: ранние ссылки (возможно прокси)
Map<String, ObjectFactory<?>> singletonFactories = new HashMap<>(16);       // 3: фабрики ранних ссылок
Set<String> singletonsCurrentlyInCreation   = ...;                          // «в процессе»
```

Алгоритм `getSingleton(name)`:
1. есть в `singletonObjects` → отдать;
2. бин «в процессе создания» → искать в `earlySingletonObjects`;
3. иначе взять фабрику из `singletonFactories`, вызвать `getEarlyBeanReference()`, положить результат в уровень 2, удалить фабрику.

Как разрешается цикл A↔B (сеттерная/полевая инъекция):
```text
create A → уровень 3: фабрика A → populate A → нужен B
   create B → populate B → нужен A → ранняя ссылка A (уровень 3→2)
   B готов → A завершает populate → A готов
```
Конструкторный цикл неразрешим: чтобы отдать раннюю ссылку A, нужен **уже созданный** экземпляр A, а он не создан — конструктор ещё не отработал.

🎯 **Почему `@Async` ломает даже сеттерный цикл:** `AsyncAnnotationBeanPostProcessor` создаёт прокси **не** через `getEarlyBeanReference`, а на шаге 10. В итоге B получил «сырой» A, а в контекст лёг прокси A → Spring бросает `BeanCurrentlyInCreationException` с сообщением о том, что бин был инжектирован в другой бин в «сыром» виде. Это не баг, а защита от неконсистентности.

## 5.8. Как выбирается конструктор и разрешается зависимость

```text
AbstractAutowireCapableBeanFactory#createBeanInstance
 ├─ Supplier? → вызвать
 ├─ factory-method (@Bean)? → вызвать метод конфигурации
 ├─ SmartInstantiationAwareBeanPostProcessor#determineCandidateConstructors
 │    └─ AutowiredAnnotationBeanPostProcessor: @Autowired-конструктор / единственный / primary (Kotlin)
 └─ иначе no-arg
```

Разрешение аргумента — `DependencyDescriptor` → `DefaultListableBeanFactory#resolveDependency`:
* `Optional`, `ObjectFactory`, `ObjectProvider` — особые ветки;
* `Map`/`Collection`/массив → `resolveMultipleBeans` (+ сортировка `@Order`);
* `@Value` → `StringValueResolver` + SpEL;
* иначе `findAutowireCandidates` → фильтр по квалификаторам → `determineAutowireCandidate` (`@Primary` → `@Priority` → имя).

Тип определяется **без создания бина** там, где возможно: `getTypeForFactoryMethod` анализирует возвращаемый тип `@Bean`-метода. Отсюда правило: **объявляйте `@Bean` с максимально конкретным типом возврата**, а не `Object`/интерфейсом «на всякий случай» — иначе контейнер не сможет сопоставить типы и начнёт создавать бины раньше времени.

## 5.9. `FactoryBean` vs `BeanFactory`

```java
@Component("cipher")
class CipherFactoryBean implements FactoryBean<Cipher> {
    @Override public Cipher getObject() throws Exception { return Cipher.getInstance("AES/GCM/NoPadding"); }
    @Override public Class<?> getObjectType() { return Cipher.class; }
    @Override public boolean isSingleton() { return false; }   // Cipher не потокобезопасен
}
```
* `getBean("cipher")` → объект **продукта** (`Cipher`);
* `getBean("&cipher")` → сама фабрика.

Так устроены `LocalContainerEntityManagerFactoryBean`, `SqlSessionFactoryBean`, `ProxyFactoryBean`, HTTP-интерфейсные клиенты. 🎯 Классический вопрос собеседования: «почему `EntityManagerFactory` объявлен как `FactoryBean`?» — потому что создание требует контейнерного bootstrap, а тип продукта нужно знать заранее для матчинга зависимостей.

## 5.10. События контекста и корректное завершение

| Событие | Когда | Типичное использование |
|---|---|---|
| `ContextRefreshedEvent` | контекст обновлён (бины созданы) | внутренняя инициализация |
| `ApplicationStartedEvent` | контекст готов, runner-ы ещё не вызваны | Boot-специфика |
| `ApplicationReadyEvent` | runner-ы отработали, приложение готово | «прогреть», зарегистрироваться в discovery |
| `ContextClosedEvent` | закрытие начинается | остановить консьюмеры |
| `AvailabilityChangeEvent` | изменение liveness/readiness | k8s-пробы |

```java
@EventListener(ApplicationReadyEvent.class)
void warmup() { /* ... */ }
```

Graceful shutdown (обязательно в проде):
```yaml
server.shutdown: graceful
spring.lifecycle.timeout-per-shutdown-phase: 30s
```
Порядок: снятие с readiness → отказ принимать новые запросы → завершение активных → остановка пулов/консьюмеров → `@PreDestroy`.

## 5.11. Диагностика: как смотреть внутрь

```java
@Component
@RequiredArgsConstructor
class ContainerInspector implements ApplicationRunner {
    private final ApplicationContext ctx;
    @Override public void run(ApplicationArguments args) {
        var bf = (ConfigurableListableBeanFactory) ctx.getAutowireCapableBeanFactory();
        System.out.println("Бинов: " + bf.getBeanDefinitionCount());
        for (String n : bf.getBeanNamesForType(TaskService.class)) {
            System.out.printf("%s → %s, proxy=%s%n", n, bf.getBeanDefinition(n).getBeanClassName(),
                              AopUtils.isAopProxy(ctx.getBean(n)));
        }
    }
}
```

Точки останова, которые стоит поставить один раз в жизни:
* `AbstractAutowireCapableBeanFactory#doCreateBean` — весь цикл бина;
* `DefaultListableBeanFactory#doResolveDependency` — почему выбран этот кандидат;
* `AbstractAutoProxyCreator#wrapIfNecessary` — почему (не) создан прокси;
* `ConfigurationClassPostProcessor#processConfigBeanDefinitions` — как разбираются ваши конфигурации.

Плюс Actuator: `/actuator/beans` (граф зависимостей), `/actuator/conditions` (почему автоконфиг включён), `/actuator/configprops`, `/actuator/env`.

## 5.12. 🧪 Практика

1. Напишите `BeanDefinitionRegistryPostProcessor`, регистрирующий по бину на каждый элемент списка из `application.yml`. Убедитесь, что они инжектятся как `List<T>`.
2. Напишите BPP, который логирует время создания бинов, и найдите три самых медленных в вашем проекте.
3. Сделайте A↔B с сеттерной инъекцией и `allow-circular-references=true`, поставьте breakpoint в `getSingleton` — увидите три уровня кэша вживую.
4. Добавьте `@Async` в один из них — получите ошибку и объясните её своими словами.
5. Создайте `@PostConstruct`, вызывающий `@Transactional`-метод того же бина; убедитесь, что транзакции нет; объясните через шаг 10 из §5.5.

## 5.13. 🎯 Вопросы уровня middle+

1. Перечислите шаги `refresh()` и скажите, на каком создаётся Tomcat.
2. Чем `BeanFactoryPostProcessor` отличается от `BeanPostProcessor`? Почему первый не должен зависеть от бизнес-бинов?
3. Почему `@Bean`-метод для BFPP объявляют `static`?
4. На каком шаге создаётся AOP-прокси и какое практическое следствие это даёт для `@PostConstruct`?
5. Как разрешается сеттерный цикл и почему конструкторный — нет?
6. Что делает `getEarlyBeanReference` и почему `@Async` конфликтует с циклами?
7. `getBean("&x")` — что вернётся?
8. Почему важно объявлять конкретный тип возврата `@Bean`-метода?
9. Что означает предупреждение «not eligible for auto-proxying»?
10. Где корректно остановить Kafka-консьюмер при выключении приложения?

---

**Назад:** [Глава 4](04-ioc-di.md) · **Дальше:** [Глава 6. Java-конфигурация, условия, программная регистрация →](06-java-config-i-usloviya.md)