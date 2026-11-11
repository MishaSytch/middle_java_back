# Глава 9. Автоконфигурация Boot изнутри и свой стартер

> **Уровень:** junior → middle+
> **Время:** 4–5 часов
> **Цель:** понимать, откуда берутся все бины «сами», уметь объяснить модуляризацию Boot 4 и написать собственный production-grade стартер.

## 9.1. Что такое Boot на самом деле

Boot = **три вещи**:
1. **Стартеры** — согласованные наборы зависимостей (BOM + «пакеты фич»).
2. **Автоконфигурация** — условные `@Configuration`, которые создают бины «если пользователь не сделал сам».
3. **Production-ready обвязка** — actuator, метрики, health, упаковка, buildpacks, graceful shutdown.

Никакой генерации кода, никакого «своего контейнера». Всё — обычные Spring-бины.

```java
@SpringBootApplication
// = @SpringBootConfiguration (@Configuration)
// + @EnableAutoConfiguration
// + @ComponentScan(с excludeFilter для TypeExcludeFilter и AutoConfigurationExcludeFilter)
public class TaskflowApplication { }
```

Точечная настройка:
```java
@SpringBootApplication(exclude = {SecurityAutoConfiguration.class})
// или
@SpringBootConfiguration @EnableAutoConfiguration @ComponentScan("dev.book")
```
```yaml
spring.autoconfigure.exclude: org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration
```

## 9.2. ⚙️ `SpringApplication.run()`: полный путь

```text
1. new SpringApplication(...)
   ├─ определить тип приложения (SERVLET / REACTIVE / NONE) по classpath
   ├─ загрузить BootstrapRegistryInitializer, ApplicationContextInitializer, ApplicationListener из spring.factories
   └─ вычислить mainApplicationClass
2. run(args)
   ├─ BootstrapContext (Boot 3+/4: org.springframework.boot.bootstrap)
   ├─ SpringApplicationRunListeners.starting()          → ApplicationStartingEvent
   ├─ prepareEnvironment(): ConfigDataEnvironmentPostProcessor читает application.yml/профили/импорты
   │                                                     → ApplicationEnvironmentPreparedEvent
   ├─ printBanner()
   ├─ createApplicationContext()                        → AnnotationConfigServletWebServerApplicationContext
   ├─ prepareContext(): initializers, регистрация main-класса как BeanDefinition
   │                                                     → ApplicationContextInitializedEvent, ApplicationPreparedEvent
   ├─ refreshContext() → ★ AbstractApplicationContext.refresh() (глава 5)
   │      └─ onRefresh(): создание Tomcat/Jetty/Netty
   ├─ afterRefresh()
   ├─ listeners.started()                               → ApplicationStartedEvent, AvailabilityChangeEvent(LivenessState.CORRECT)
   ├─ callRunners(): ApplicationRunner / CommandLineRunner (в порядке @Order)
   └─ listeners.ready()                                 → ApplicationReadyEvent, AvailabilityChangeEvent(ReadinessState.ACCEPTING_TRAFFIC)
```

Что из этого нужно practically:
* **`EnvironmentPostProcessor`** — точка расширения, где можно добавить property source **до** создания контекста (например, расшифровать секреты). **[4.x]** интерфейс переехал в `org.springframework.boot` (старый `org.springframework.boot.env` — deprecated).
* **`ApplicationContextInitializer`** — доступ к контексту до `refresh()`.
* **`ApplicationRunner` vs `CommandLineRunner`** — первый получает разобранные аргументы (`--key=value`), второй — сырой массив.
* Ошибка в runner-е **роняет приложение**. Для «мягкой» инициализации ловите исключения сами.

## 9.3. ⚙️ Как работает `AutoConfigurationImportSelector`

```text
@EnableAutoConfiguration
 └─ @Import(AutoConfigurationImportSelector.class)   ← DeferredImportSelector!
     ├─ getCandidateConfigurations():
     │    читает ВСЕ файлы META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
     │    из всех jar-ов (по одной строке — имя класса автоконфигурации)
     ├─ удаляет дубликаты, применяет exclusions (аннотация + свойство + AutoConfigurationImportFilter)
     ├─ фильтрует по условиям (@ConditionalOnClass и др. — быстрый отсев через AutoConfigurationImportFilter)
     ├─ сортирует: сначала по алфавиту, затем @AutoConfigureOrder, затем @AutoConfigureBefore/After
     └─ возвращает список → ConfigurationClassPostProcessor регистрирует их как конфигурации
```

Ключевые следствия:
* Автоконфигурации обрабатываются **после** пользовательских → `@ConditionalOnMissingBean` видит ваши бины и «отступает». Это и есть механизм переопределения.
* Порядок между автоконфигурациями задаётся аннотациями, **не** алфавитом пакетов.
* `@AutoConfiguration(before = ..., after = ...)` — современная замена `@Configuration` + `@AutoConfigureBefore`.

Пример реальной автоконфигурации (упрощённо):
```java
@AutoConfiguration(after = DataSourceAutoConfiguration.class)
@ConditionalOnClass({DataSource.class, EmbeddedDatabaseType.class})
@ConditionalOnMissingBean(DataSource.class)
@EnableConfigurationProperties(DataSourceProperties.class)
public class DataSourceAutoConfiguration {
    @Bean
    @ConditionalOnMissingBean
    DataSource dataSource(DataSourceProperties props) { ... }
}
```

## 9.4. Модуляризация Boot 4 **[4.x]** — самое заметное изменение

До 4.0 всё жило в двух больших jar-ах: `spring-boot` и `spring-boot-autoconfigure`. В 4.0 — **модули по технологиям**:

```text
Модуль:   spring-boot-<technology>            пакет: org.springframework.boot.<technology>
Стартер:  spring-boot-starter-<technology>
Тест-модуль: spring-boot-<technology>-test    пакет: org.springframework.boot.<technology>.test
Тест-стартер: spring-boot-starter-<technology>-test
```

### Таблица: что чем стало (главное)

| Технология | Было (3.5) | Стало (4.x) | Тестовый стартер (4.x) |
|---|---|---|---|
| Web MVC | `starter-web` | **`starter-webmvc`** (старое имя — deprecated алиас) | `starter-webmvc-test` |
| WebFlux | `starter-webflux` | `starter-webflux` | `starter-webflux-test` |
| RestClient/RestTemplate | входило в web | **`starter-restclient`** | `starter-restclient-test` |
| WebClient | входило в webflux | **`starter-webclient`** | `starter-webclient-test` |
| AOP/AspectJ | `starter-aop` | **`starter-aspectj`** | `starter-aspectj-test` |
| Jackson | входило в web | **`starter-jackson`** | `starter-jackson-test` |
| Flyway | `org.flywaydb:flyway-core` | **`starter-flyway`** | `starter-flyway-test` |
| Liquibase | `org.liquibase:liquibase-core` | **`starter-liquibase`** | `starter-liquibase-test` |
| Security | `starter-security` | `starter-security` | **`starter-security-test`** |
| OAuth2 Resource Server | `starter-oauth2-resource-server` | **`starter-security-oauth2-resource-server`** | `...-test` |
| Kafka | `spring-kafka` | **`starter-kafka`** | `starter-kafka-test` |
| Validation | `starter-validation` | `starter-validation` | `starter-validation-test` |
| Batch | `starter-batch` (с JDBC) | `starter-batch` (**in-memory!**) / `starter-batch-jdbc` | соответствующие |
| Метрики | входило в actuator | **`starter-micrometer-metrics`** | `...-test` |
| OTel | вручную | **`starter-opentelemetry`** | `...-test` |
| Базовый | `starter` | `starter` (+ **`starter-classic`**) | `starter-test` (+ `starter-test-classic`) |

**«Classic» стартеры** — мост для миграции: `spring-boot-starter-classic` и `spring-boot-starter-test-classic` дают все модули сразу (как в 3.x), но без транзитивных сторонних зависимостей. Стратегия: сначала переехать на classic, починить импорты, затем убрать classic и добавить точные стартеры.

🪤 **Три ловушки модуляризации:**
1. Технологии без стартера в 3.x (Flyway, Liquibase, Kafka) теперь **требуют** стартер — иначе автоконфигурации просто нет в classpath.
2. `@WithMockUser`/`@WithUserDetails` не работают без `spring-boot-starter-security-test`.
3. Пакеты изменились: `org.springframework.boot.autoconfigure.web.servlet.*` → `org.springframework.boot.webmvc.autoconfigure.*` и т. п. IDE починит импорты, но `spring.factories`/reflection-строки — нет.

## 9.5. Как читать condition report

```bash
java -jar app.jar --debug
```
```text
Positive matches:
-----------------
   DataSourceAutoConfiguration matched:
      - @ConditionalOnClass found required class 'javax.sql.DataSource' (OnClassCondition)
      - @ConditionalOnMissingBean (types: javax.sql.DataSource) did not find any beans (OnBeanCondition)

Negative matches:
-----------------
   MongoAutoConfiguration:
      Did not match:
         - @ConditionalOnClass did not find required class 'com.mongodb.client.MongoClient' (OnClassCondition)

Exclusions:
-----------
    org.springframework.boot.security.autoconfigure.SecurityAutoConfiguration
```

Алгоритм разбирательства «почему нет бина X»:
1. Есть ли модуль/стартер в classpath? (`dependency:tree`)
2. Найдите автоконфигурацию в report: Positive/Negative/Exclusions/Unconditional.
3. Если Negative — читайте, какое условие не прошло.
4. Если Positive, но бина нет — значит `@ConditionalOnMissingBean` увидел **ваш** бин (или бин другой автоконфигурации).
5. `/actuator/conditions`, `/actuator/beans` — то же в рантайме.

## 9.6. Свой стартер: полный production-пример

Задача: стартер `feature-flags`, который даёт бин `FeatureFlags`, читающий флаги из свойств, с метриками и health-индикатором.

### Структура (два модуля — канонический подход)

```text
feature-flags/
├── feature-flags-spring-boot-autoconfigure/    # код + автоконфигурация
│   ├── pom.xml
│   └── src/main/java/dev/book/flags/autoconfigure/
│       ├── FeatureFlagsProperties.java
│       ├── FeatureFlags.java
│       └── FeatureFlagsAutoConfiguration.java
│   └── src/main/resources/META-INF/
│       ├── spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
│       └── additional-spring-configuration-metadata.json
└── feature-flags-spring-boot-starter/          # только pom с зависимостями
    └── pom.xml
```

### Код

```java
@ConfigurationProperties(prefix = "app.flags")
@Validated
public record FeatureFlagsProperties(
        @DefaultValue("false") boolean enabled,
        Map<String, Boolean> flags
) {}
```

```java
public class FeatureFlags {
    private final Map<String, Boolean> flags;
    public FeatureFlags(Map<String, Boolean> flags) { this.flags = Map.copyOf(flags); }
    public boolean isEnabled(String name) { return flags.getOrDefault(name, false); }
}
```

```java
@AutoConfiguration                                        // [4.x]; в 3.5: @Configuration(proxyBeanMethods=false)
@ConditionalOnClass(FeatureFlags.class)
@ConditionalOnProperty(prefix = "app.flags", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(FeatureFlagsProperties.class)
public class FeatureFlagsAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean                              // ← пользователь может подменить
    public FeatureFlags featureFlags(FeatureFlagsProperties props) {
        return new FeatureFlags(props.flags() == null ? Map.of() : props.flags());
    }

    @Bean
    @ConditionalOnClass(name = "io.micrometer.core.instrument.MeterRegistry")
    @ConditionalOnBean(MeterRegistry.class)
    public FeatureFlagsMetrics featureFlagsMetrics(FeatureFlags flags, MeterRegistry registry) {
        return new FeatureFlagsMetrics(flags, registry);
    }
}
```

`META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`:
```text
dev.book.flags.autoconfigure.FeatureFlagsAutoConfiguration
```

`additional-spring-configuration-metadata.json` (подсказки в IDE):
```json
{
  "properties": [
    { "name": "app.flags.enabled", "type": "java.lang.Boolean", "defaultValue": true,
      "description": "Включает подсистему фиче-флагов." }
  ],
  "hints": [
    { "name": "app.flags.flags.keys", "values": [
      {"value": "new-checkout", "description": "Новый чекаут"},
      {"value": "beta-search",  "description": "Бета-поиск"} ] }
  ]
}
```

### pom автоконфигурации (ключевое)

```xml
<dependencies>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-autoconfigure</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-configuration-processor</artifactId><optional>true</optional></dependency>
  <dependency><groupId>io.micrometer</groupId><artifactId>micrometer-core</artifactId><optional>true</optional></dependency>
</dependencies>
```
> Все «необязательные» интеграции — `optional`/`provided`. Стартер — это место, где они становятся обязательными.
> **[4.x]** не пытайтесь поддерживать Boot 3 и Boot 4 в одном артефакте — официальная рекомендация: разные артефакты/ветки.

### pom стартера

```xml
<artifactId>feature-flags-spring-boot-starter</artifactId>
<dependencies>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter</artifactId></dependency>
  <dependency><groupId>dev.book</groupId><artifactId>feature-flags-spring-boot-autoconfigure</artifactId><version>${project.version}</version></dependency>
</dependencies>
```

Gradle-эквивалент: `java-library` + `api`/`implementation` + `annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")`.

### Тест автоконфигурации — `ApplicationContextRunner`

```java
class FeatureFlagsAutoConfigurationTest {
    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(FeatureFlagsAutoConfiguration.class));

    @Test void createsBeanByDefault() {
        runner.run(ctx -> assertThat(ctx).hasSingleBean(FeatureFlags.class));
    }
    @Test void backsOffWhenUserDefinesBean() {
        runner.withUserConfiguration(Custom.class)
              .run(ctx -> assertThat(ctx).getBean(FeatureFlags.class).isSameAs(Custom.INSTANCE));
    }
    @Test void disabledByProperty() {
        runner.withPropertyValues("app.flags.enabled=false")
              .run(ctx -> assertThat(ctx).doesNotHaveBean(FeatureFlags.class));
    }
    @Configuration static class Custom {
        static final FeatureFlags INSTANCE = new FeatureFlags(Map.of());
        @Bean FeatureFlags featureFlags() { return INSTANCE; }
    }
}
```

🎯 Это **обязательный** тест для стартера: он проверяет главное свойство автоконфигурации — «отступать», когда пользователь определил свой бин. Есть также `WebApplicationContextRunner`, `ReactiveApplicationContextRunner`.

## 9.7. Как правильно кастомизировать чужую автоконфигурацию

Порядок предпочтения:
1. **Свойства** (`application.yml`) — 90 % случаев.
2. **`*Customizer`-бины** — точки расширения, которые Boot специально оставил:
   ```java
   @Bean JsonMapperBuilderCustomizer jacksonCustomizer() {           // [4.x]
       return builder -> builder.disable(DateTimeFeature.WRITE_DATES_AS_TIMESTAMPS);
   }
   @Bean RestClientCustomizer restClientCustomizer() { return b -> b.requestInterceptor(new CorrelationIdInterceptor()); }
   @Bean TomcatConnectorCustomizer tomcat() { return c -> c.setProperty("relaxedQueryChars", "[]"); }
   ```
3. **Свой бин того же типа** — автоконфигурация отступит (`@ConditionalOnMissingBean`).
4. **`BeanPostProcessor`** — хирургическое вмешательство, когда нет ни свойств, ни кастомайзера.
5. **`exclude` автоконфигурации + своя конфигурация** — крайний случай, документируйте причину.

🪤 Никогда не «переопределяйте» автоконфигурацию копипастой её исходников: при апгрейде вы разойдётесь с фреймворком.

## 9.8. Dev-experience: что даёт Boot помимо автоконфига

| Возможность | Как включить |
|---|---|
| Restart/LiveReload | `spring-boot-devtools` (LiveReload в 4.x выключен по умолчанию) |
| Docker Compose на dev-старте | `spring-boot-docker-compose` + `compose.yaml` в корне |
| Testcontainers на dev-старте | `spring-boot-testcontainers` + `@ServiceConnection`-бины в `@TestConfiguration`, запуск `test`-main |
| Buildpacks (образ без Dockerfile) | `mvn spring-boot:build-image` / `gradle bootBuildImage` |
| Слои jar для кэша Docker | включено по умолчанию; `java -Djarmode=tools -jar app.jar extract --layers` **[4.x]** |
| CDS/AOT | `java -XX:ArchiveClassesAtExit=app.jsa`, AOT-режим плагина |
| Проверка конфигурации | `spring-boot-properties-migrator` (временно, при миграции) |

## 9.9. AOT: почему автоконфигурация «запекается»

При AOT-обработке (`spring-boot:process-aot`) Boot **выполняет условия на этапе сборки** и генерирует Java-код инициализаторов + `RuntimeHints` (reflection/resources/proxies). Следствия:
* Профили и условия фиксируются на момент сборки → нельзя «включить другую автоконфигурацию» в рантайме.
* Стартеры с рефлексией обязаны поставлять `RuntimeHintsRegistrar`.
* Это фундамент и для GraalVM native, и для быстрого старта на JVM (глава 26).

## 9.10. 🧪 Практика

1. Найдите в своём проекте 5 автоконфигураций, которые «matched», и объясните каждое условие.
2. Исключите `SecurityAutoConfiguration` двумя способами (аннотация и свойство).
3. Напишите стартер из §9.6 целиком, опубликуйте в `mavenLocal()`, подключите в учебный проект.
4. Проверьте IDE-подсказки по `app.flags.*` (metadata работает).
5. Напишите три теста `ApplicationContextRunner`, включая back-off.
6. **[4.x]** Переведите проект на точные стартеры, убрав `starter-classic`.

## 9.11. Чек-лист и вопросы

- [ ] Могу разложить `@SpringBootApplication` на три аннотации и объяснить каждую.
- [ ] Знаю, почему автоконфигурация — `DeferredImportSelector`.
- [ ] Умею по condition report объяснить отсутствие бина.
- [ ] Помню таблицу переименований стартеров 4.x и тестовые стартеры.
- [ ] Мой стартер имеет `@ConditionalOnMissingBean`, metadata и тесты back-off.

**Вопросы:** 1) Как Boot узнаёт список автоконфигураций? 2) Почему пользовательский бин «побеждает»? 3) Чем `@AutoConfiguration` отличается от `@Configuration`? 4) Что такое classic-стартеры и зачем они? 5) Как правильно добавить свой `ObjectMapper`/`JsonMapper`? 6) Что фиксируется при AOT и какие ограничения это накладывает?

---

**Назад:** [Глава 8](../01-core/08-aop.md) · **Дальше:** [Глава 10. Конфигурация и профили →](10-konfiguraciya-i-profili.md)