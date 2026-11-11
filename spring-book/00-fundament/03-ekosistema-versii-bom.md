# Глава 3. Экосистема Spring, версии, BOM и как не утонуть в новостях

> **Уровень:** zero → middle
> **Время:** 1.5–2 часа
> **Цель:** вы умеете сами определять, какие версии совместимы, что нового в актуальной линейке и где искать первоисточник. Это навык, который отличает middle от junior.

## 3.1. Карта экосистемы

```text
                        ┌──────────────────────────────┐
                        │   Spring Framework 7.x       │  ядро: IoC, AOP, TX, JDBC, Web, Test
                        └──────────────┬───────────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │   Spring Boot 4.x            │  автоконфигурация, стартеры, actuator,
                        │  (auto-config + opinionated) │  упаковка, метрики, dev-experience
                        └──────────────┬───────────────┘
       ┌───────────────┬───────────────┼────────────────┬───────────────┬──────────────┐
       ▼               ▼               ▼                ▼               ▼              ▼
  Spring Data     Spring Security   Spring Cloud    Spring Batch   Spring AI     Spring Modulith
  (JPA/JDBC/      (authn/authz,     (config,        (jobs, chunks) (LLM, RAG,    (модульный
   Redis/Mongo/    OAuth2, JWT)      discovery,                      tools)        монолит)
   Kafka...)                         gateway)
       │
   Spring for Apache Kafka, AMQP, Pulsar, Integration, GraphQL, Session, REST Docs, gRPC, Shell, Retry → core
```

Ключевая мысль: **Boot не заменяет Framework**. Boot — это слой *мнений* (opinions) и автоконфигурации над Framework и сторонними библиотеками. Всё, что вы делаете в Boot, — это ordinary Spring beans.

| Проект | Зачем нужен | Когда встречается |
|---|---|---|
| Spring Framework | IoC, AOP, транзакции, JDBC, MVC/WebFlux, TestContext | всегда |
| Spring Boot | автоконфиг, стартеры, actuator, jar/образы | всегда |
| Spring Data | репозитории, единая модель доступа к данным | почти всегда |
| Spring Security | аутентификация/авторизация, OAuth2/OIDC | почти всегда |
| Spring Cloud | распределённые системы: config server, gateway, circuit breakers | микросервисы |
| Spring Batch | пакетные задания, chunk-processing | отчётность, ETL |
| Spring for Apache Kafka | продюсеры/консьюмеры, retry topics, streams | событийная архитектура |
| Spring AI | LLM-клиенты, embeddings, vector stores, tool calling | AI-фичи |
| Spring Modulith | модульный монолит, проверка границ, event publication registry | «монолит, который не превращается в кашу» |
| Spring gRPC | gRPC-серверы/клиенты (в Boot **с 4.1**) | внутренний RPC |
| Micrometer | метрики/трейсинг-фасад (не Spring-проект, но «родной») | observability |

## 3.2. Матрица совместимости (состояние на ноябрь 2026)

| Spring Boot | Spring Framework | Spring Security | Spring Data | Java baseline | Статус |
|---|---|---|---|---|---|
| **4.1.x** (4.1.2) | 7.0.x | 7.0.x | 2025.1.x | 17 (реком. 25) | **актуальная рекомендуемая** |
| 4.0.x (4.0.9) | 7.0.x | 7.0.x | 2025.1.x | 17 | maintenance |
| 4.2.0 (RC2 на момент написания) | **7.1.x** | 7.1.x | 2026.0.x | 17+ | ожидается GA в ноябре 2026 |
| **3.5.x** | 6.2.x | 6.5.x | 2025.0.x | 17 (реком. 21) | последняя линейка 3.x; OSS-поддержка завершилась в 2026, далее коммерческая |
| 3.4.x и ниже | 6.1.x и ниже | 6.3/6.4 | 2024.x | 17 | вне OSS-поддержки |

Точные даты всегда сверяйте на <https://spring.io/projects/spring-boot#support>.

**Правило каденса:** новая minor/major версия Boot выходит **каждые 6 месяцев — в мае и ноябре** (четверг после третьего понедельника). Патчи — по мере необходимости. Minor поддерживается минимум 12 месяцев, major — минимум 3 года при условии использования поддерживаемой minor.

**Как это использовать practically:**
* Прод-сервис: держите **последнюю minor минус ноль или одна** (то есть 4.1.x, когда вышла 4.2 — можно ещё месяц-два на 4.1).
* Патчи — обновляйте **всегда и быстро** (это багфиксы и CVE, обратная совместимость сохраняется).
* Major — планируйте как проект на 1–3 спринта (глава 29 — полный чек-лист миграции 3.5 → 4.x).

## 3.3. Что принципиально нового в Spring Framework 7 / Boot 4

Это «карта изменений», по которой мы будем расставлять пометки **[4.x]** в книге. Всё перечисленное разобрано в соответствующих главах.

**Spring Framework 7.0:**
* **Jakarta EE 11 baseline**: Servlet 6.1 (Tomcat 11, Jetty 12.1), JPA 3.2 (Hibernate ORM 7.1/7.2), Bean Validation 3.1 (Hibernate Validator 9), WebSocket 2.2, Kotlin 2.2, JUnit 6, GraalVM 25.
* **JSpecify null-safety** вместо `org.springframework.lang.*`: аннотации `org.jspecify.annotations.Nullable/NonNull`, включая дженерики и массивы. Kotlin-проекты почувствуют это сильнее всего.
* **Resilience в ядре**: `org.springframework.core.retry.RetryTemplate`, `@Retryable`, `@ConcurrencyLimit`, включается `@EnableResilientMethods`. Spring Retry как отдельный проект больше не управляется Boot.
* **API versioning** в MVC и WebFlux — первоклассная поддержка (`spring.mvc.apiversion.*`).
* **HTTP-интерфейсы**: `@ImportHttpServices` + групповая конфигурация клиентов; `RestTemplate` объявлен deprecated в документации (в 7.1 — `@Deprecated`).
* **`BeanRegistrar`** — программная регистрация бинов (глава 6).
* **`@Proxyable`** — управление типом прокси per-bean; единый дефолт CGLIB для всех proxy-процессоров.
* **`RestTestClient`** — новый тестовый клиент (заменяет `TestRestTemplate` в новых проектах).
* **Jackson 3** (`tools.jackson`) по умолчанию, Jackson 2 — deprecated-путь.
* **`JmsClient`**, улучшенный `JdbcClient` (fetch size, max rows, query timeout).
* Удалено: `spring-jcl` (заменён Apache Commons Logging), `javax.annotation`/`javax.inject`, Undertow-специфика, `ListenableFuture`, OkHttp3, суффиксный паттерн-матчинг и trailing-slash matching.
* `HttpHeaders` больше **не** `MultiValueMap` — ломающее изменение API.
* Class-File API (JEP 484) вместо ASM на Java 24+; `PathPattern` умеет `/**/pages/index.html`.
* Безопасность SpEL: лимит операций (10 000 по умолчанию, с 7.0.8), `SimpleEvaluationContext` без компиляции по умолчанию (с 7.0.9).

**Spring Boot 4.0:**
* **Модуляризация**: вместо «толстых» jar-ов — `spring-boot-<technology>`, пакеты `org.springframework.boot.<technology>`, стартеры `spring-boot-starter-<technology>` и **тестовые стартеры** `spring-boot-starter-<technology>-test`.
* `spring-boot-starter-web` → **`spring-boot-starter-webmvc`**; `starter-aop` → **`starter-aspectj`**; oauth2-стартеры → `starter-security-oauth2-*`.
* Flyway/Liquibase и др. теперь требуют **свой стартер**.
* **Jackson 3** + `JsonMapper`/`XmlMapper` бины; `Jackson2ObjectMapperBuilderCustomizer` → `JsonMapperBuilderCustomizer`; `@JsonComponent` → `@JacksonComponent`; `@JsonMixin` → `@JacksonMixin`.
* **Тесты**: `@SpringBootTest` больше не даёт MockMvc/`TestRestTemplate`/`WebClient` «сам» — нужны `@AutoConfigureMockMvc` и др.; `@MockBean`/`@SpyBean` удалены (используйте `@MockitoBean`/`@MockitoSpyBean`); `MockitoTestExecutionListener` удалён.
* **Actuator**: liveness/readiness-группы включены по умолчанию; новый `spring-boot-starter-opentelemetry`; `management.tracing.enabled` → `management.tracing.export.enabled`.
* Hibernate 7.2, HikariCP 7, Flyway 11.11, Liquibase 5, Testcontainers 2.0, Micrometer 1.16, Reactor 2025.0, Kafka 4.1, Tomcat 11.
* `spring.dao.exceptiontranslation.enabled` → `spring.persistence.exceptiontranslation.enabled`; `@EntityScan` переехал в `org.springframework.boot.persistence.autoconfigure`.
* DevTools LiveReload выключен по умолчанию; uber-jar больше не включает `optional`-зависимости; classic loader и «fully executable» jar-скрипты удалены.
* Spring Authorization Server — **часть Spring Security 7**.

**Spring Boot 4.1 (июнь 2026):**
* **Spring gRPC** внутри Boot (серверы/клиенты, тестирование, Netty или Servlet/HTTP2).
* Jackson: общие `spring.jackson.read.*`/`write.*`, `spring.jackson.factory.*` (лимиты чтения/записи), `HandlerInstantiator` из бинов контекста, `JsonFactoryBuilderCustomizer` и др.
* `spring.config.import` с указанием кодировки; уточнены режимы `spring.data.jpa.repositories.bootstrap-mode`; jOOQ 3.20 (Java 21+); временный каталог Tomcat чистится при закрытии контекста.
* Всё, что было deprecated в 4.0, **удалено**.

> **Как читать этот список на практике:** если вы пришли из 3.x, вам нужны три вещи — таблица стартеров (глава 9), таблица свойств и тестовых аннотаций (глава 29) и Jackson-миграция (глава 18). Остальное — эволюция без боли.

## 3.4. BOM и dependency management: как это работает

**BOM (Bill of Materials)** — pom с `<dependencyManagement>`, который фиксирует версии сотен артефактов, протестированных вместе.

Maven, вариант «parent»:
```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>4.1.2</version>
</parent>
```

Maven, вариант «import» (когда есть корпоративный parent):
```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-dependencies</artifactId>
      <version>4.1.2</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

Gradle:
```kotlin
dependencies { implementation(platform("org.springframework.boot:spring-boot-dependencies:4.1.2")) }
```

**Переопределение версии** — только осознанно:
```xml
<properties>
  <postgresql.version>42.7.8</postgresql.version>   <!-- работает с parent-ом Boot -->
</properties>
```
```kotlin
extra["postgresql.version"] = "42.7.8"              // при io.spring.dependency-management
// или нативно:
dependencies { implementation("org.postgresql:postgresql:42.7.8") }
```

Диагностика:
```bash
./mvnw dependency:tree -Dincludes=org.springframework
./mvnw help:effective-pom
./gradlew dependencies --configuration runtimeClasspath
./gradlew dependencyInsight --dependency jackson-databind
```

**Три правила, которые спасают недели отладки:**
1. Никогда не смешивайте major-версии Spring-проектов между линейками (Framework 6.2 + Boot 4 = гарантированный `NoSuchMethodError`).
2. Не задавайте версии Spring-артефактов руками. Вообще. Только через BOM.
3. Сторонние библиотеки, которых нет в BOM (Spring Cloud, Testcontainers-экзотика, MapStruct), версионируйте сами и проверяйте совместимость по их матрицам.

## 3.5. Spring Cloud: отдельный поезд

Spring Cloud живёт в собственной нумерации release train и **привязан к minor Boot**:

| Spring Cloud | Совместим с Boot |
|---|---|
| 2025.0.x (Northfields) | 3.5.x |
| 2025.1.x (Northfields, продолжение) | 4.0.x |
| 2026.0.x (Paddington) | 4.1.x / 4.2.x |

Подключается как BOM:
```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.springframework.cloud</groupId>
      <artifactId>spring-cloud-dependencies</artifactId>
      <version>2026.0.0</version>
      <type>pom</type><scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```
Актуальную таблицу смотрите в Spring Cloud «Supported Versions». В этой книге Cloud — за рамками (мы строим глубокий монолит), но правило совместимости знать обязательно.

## 3.6. Где искать правду (и в каком порядке)

1. **Reference documentation** конкретной версии: `docs.spring.io/spring-boot/4.1/`, `docs.spring.io/spring-framework/reference/7.0/`. Всегда проверяйте версию в URL — «current» может указывать на snapshot.
2. **Release Notes** на wiki: `Spring-Boot-4.1-Release-Notes`, `Spring-Framework-7.0-Release-Notes`. Это первоисточник «что изменилось».
3. **Migration Guide** + **Configuration Changelog** — для переименованных свойств.
4. **Appendix: application properties** — полный список свойств с типами и дефолтами.
5. **Javadoc** — когда нужно понять контракт метода.
6. **Исходники на GitHub** — финальная инстанция. `Ctrl+Shift+F` по `spring-projects/spring-boot` отвечает на 90 % вопросов «а как оно на самом деле».
7. Блог spring.io — анонсы с объяснением мотивации (например, «Modularizing Spring Boot», «The state of HTTP clients in Spring», «Null-safe applications with Spring Boot 4»).

Инструменты, которые стоит поставить:
```bash
# Spring CLI: быстрый скелет и «что добавить для фичи»
spring init --dependencies=webmvc,data-jpa my-app
spring boot new my-app

# Проверка обновлений
./mvnw versions:display-property-updates
./gradlew dependencyUpdates           # плагин ben-manes

# Автоматические миграции кода
./mvnw org.openrewrite.maven:rewrite-maven-plugin:run \
  -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST \
  -Drewrite.activeRecipes=org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0
```
Плюс Renovate/Dependabot в репозитории — чтобы патчи приходили сами.

## 3.7. Как читать эту книгу: система пометок

| Пометка | Значение |
|---|---|
| **[4.x]** | только/иначе в Spring Boot 4.x + Framework 7 |
| **[3.5]** | только/иначе в Spring Boot 3.5.x + Framework 6.2 |
| **⚙️ Под капотом** | разбор внутренностей: классы, порядок вызовов, исходники |
| **🪤 Грабли** | типичная ошибка и её симптом |
| **🎯 Middle+** | то, что спрашивают на собеседовании уровня middle и выше |
| **🧪 Практика** | задание, которое надо сделать руками |

Основной трек изложения — **4.x**. Всё, что отличается в 3.5, идёт врезкой. Если вы работаете на 3.5 — читайте врезки как «ваш вариант по умолчанию», а пометки [4.x] — как «куда вы придёте после апгрейда».

## 3.8. Практика

1. Откройте `dependency:tree` своего проекта и найдите: версию Spring Framework, Hibernate, Jackson, HikariCP. Запишите их — это ваш реальный стек, а не то, что вы «думали, что поставили».
2. Найдите в Appendix документации свойство `spring.jpa.open-in-view`. Запомните его дефолт (`true`) — в главе 14 мы объясним, почему его выключают.
3. Откройте Release Notes 4.0 и найдите три изменения, которые затрагивают ваш текущий рабочий проект.
4. Настройте Renovate/Dependabot на учебный репозиторий.

## 3.9. Чек-лист

- [ ] Могу по памяти назвать соответствие Boot 4.1 ↔ Framework 7.0 ↔ Security 7.0 ↔ Data 2025.1.
- [ ] Знаю каденс релизов (май/ноябрь) и политику поддержки.
- [ ] Умею посмотреть effective-pom/dependency tree и переопределить версию через свойство.
- [ ] Понимаю, почему Spring Cloud версионируется отдельно.
- [ ] Знаю порядок источников: reference → release notes → migration guide → changelog → исходники.

---

**Назад:** [Глава 2](02-okruzhenie-i-pervyj-proekt.md) · **Дальше:** [Глава 4. IoC и DI →](../01-core/04-ioc-di.md)