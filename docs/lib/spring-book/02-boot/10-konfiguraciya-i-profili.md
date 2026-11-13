# Глава 10. Конфигурация, профили, `@ConfigurationProperties` и секреты

> **Уровень:** junior → middle+
> **Время:** 4 часа
> **Цель:** уметь собрать конфигурацию приложения для local/dev/stage/prod так, чтобы она была типобезопасной, документируемой, тестируемой и безопасной.

## 10.1. Полный порядок приоритетов (сверху — сильнее)

1. Devtools global settings (`~/.config/spring-boot`) — если devtools активен
2. `@TestPropertySource` / атрибуты `properties` в тестовых аннотациях
3. Аргументы командной строки (`--server.port=8081`)
4. `SPRING_APPLICATION_JSON`
5. `ServletConfig` / `ServletContext` init-параметры
6. JNDI (`java:comp/env`)
7. **System properties** (`-Dserver.port=8081`)
8. **Переменные окружения** (`SERVER_PORT=8081`)
9. `random.*` (`RandomValuePropertySource`)
10. Профильные файлы **вне** jar (`application-prod.yml` рядом с jar)
11. Профильные файлы **внутри** jar
12. `application.yml` **вне** jar
13. `application.yml` **внутри** jar
14. `@PropertySource` на `@Configuration`
15. `SpringApplication.setDefaultProperties`

🎯 Практический вывод: **в контейнере побеждают переменные окружения над всем, что в jar**. Поэтому образ можно собирать один раз и катить по средам без пересборки — это база 12-factor.

```bash
SERVER_PORT=8081 SPRING_PROFILES_ACTIVE=prod java -jar app.jar
SPRING_APPLICATION_JSON='{"app":{"flags":{"beta":true}}}' java -jar app.jar
java -Dserver.port=8081 -jar app.jar
java -jar app.jar --server.port=8081 --debug
```

## 10.2. YAML vs properties и многодокументность

```yaml
# application.yml
spring:
  application:
    name: taskflow
  threads:
    virtual:
      enabled: true          # Java 21+: виртуальные потоки для Tomcat/@Async
server:
  port: 8080
  shutdown: graceful
app:
  payments:
    url: https://pay.local
    timeout: 3s              # Duration
    max-body: 2MB            # DataSize
    retries: 3
---
spring:
  config:
    activate:
      on-profile: local
  jpa:
    show-sql: true
app:
  payments:
    url: http://localhost:9999
---
spring:
  config:
    activate:
      on-profile: prod
server:
  port: 8080
logging:
  structured:
    format:
      console: ecs
```

🪤 **YAML-грабли:**
* Табы запрещены (только пробелы).
* `on`, `yes`, `no`, `off` в YAML 1.1 — булевы; `country: NO` (Норвегия) станет `false`. Кавычьте строки.
* Список нельзя задать и через `-`, и через запятую в одном месте.
* `spring.profiles.active` **нельзя** указывать внутри профильного документа — ошибка на старте.
* Пустое значение = `null`, а не пустая строка. Для пустой строки — `""`.

## 10.3. Профили: правильно и по-взрослому

```yaml
spring:
  profiles:
    active: local                 # только для локальной разработки, в проде — через ENV
    default: local                # если ничего не задано
    group:
      prod: prod-db,prod-mq,metrics
      local: dev-tools,h2
    include: common               # всегда добавить
```

**Группы профилей** — недооценённая фича: вместо «включи 5 профилей» вы включаете один `prod`, а он разворачивается в набор. Это делает конфигурацию сред композиционной.

Активация:
```bash
SPRING_PROFILES_ACTIVE=prod
java -jar app.jar --spring.profiles.active=prod,metrics
```
```java
@ActiveProfiles("test")                        // в тестах
@SpringBootTest(properties = "spring.profiles.active=test")
```

Профильные бины:
```java
@Bean @Profile("local") MailSender consoleMail() { return new LoggingMailSender(); }
@Bean @Profile({"prod", "stage"}) MailSender smtpMail() { ... }
@Bean @Profile("!prod") DevToolsConfig devTools() { ... }
```

🪤 **Антипаттерн «профиль как фиче-флаг»**: `@Profile("new-checkout")` для бизнес-функции. Профили — про **среду**, флаги — про **поведение**. Смешивание приводит к взрыву комбинаций и невозможности тестировать.

## 10.4. Config Data: импорт, дополнительные локации, дерево

```yaml
spring:
  config:
    import:
      - optional:file:./config/local.yml           # optional: — не падать, если нет
      - optional:classpath:shared-defaults.yml
      - optional:configtree:/run/secrets/          # k8s secrets: файл = ключ
      # [4.1] можно указать кодировку импортируемого файла
    additional-location: file:./config/            # ДОБАВЛЯЕТ к стандартным локациям
```

Стандартные локации поиска (позже = сильнее): `classpath:/`, `classpath:/config/`, `file:./`, `file:./config/`, `file:./config/*/`.

**Config tree** — идеальный способ читать k8s secrets:
```bash
/run/secrets/db-username   → свойство db-username
/run/secrets/db-password   → свойство db-password
```
```yaml
spring:
  datasource:
    username: ${db-username}
    password: ${db-password}
```

`spring.config.location` **заменяет** стандартные локации (осторожно!), `additional-location` — добавляет. В 99 % случаев нужен второй.

## 10.5. `@ConfigurationProperties` — основной инструмент

### Record + constructor binding (рекомендуемый стиль)

```java
@Validated
@ConfigurationProperties(prefix = "app.payments")
public record PaymentProperties(
        @NotBlank String url,
        @DefaultValue("3s") @DurationMin(seconds = 1) Duration timeout,
        @DefaultValue("3") @Min(0) @Max(10) int retries,
        @DefaultValue("2MB") DataSize maxBody,
        @Valid Credentials credentials,
        @DefaultValue Map<String, String> headers
) {
    public record Credentials(@NotBlank String login, @NotBlank String secret) {}
}
```

Регистрация (два способа):
```java
@SpringBootApplication
@ConfigurationPropertiesScan            // сканирует @ConfigurationProperties в пакетах
class App {}

// или точечно:
@Configuration
@EnableConfigurationProperties(PaymentProperties.class)
class PaymentsConfig {}
```

Использование:
```java
@Service
@RequiredArgsConstructor
class PaymentsGateway {
    private final PaymentProperties props;    // типобезопасно, IDE подсказывает, валидируется на старте
}
```

### JavaBean-стиль (когда нужна мутабельность)
```java
@ConfigurationProperties(prefix = "app.cache")
public class CacheProperties {
    private Duration ttl = Duration.ofMinutes(5);
    private final Map<String, Duration> perCache = new LinkedHashMap<>();
    // getters/setters обязательны
}
```

### Правила relaxed binding

| В файле | В Java | Работает |
|---|---|---|
| `app.payment-gateway.max-retries` | `maxRetries` | ✅ kebab-case (рекомендуется) |
| `app.paymentGateway.maxRetries` | `maxRetries` | ✅ camelCase |
| `app.payment_gateway.max_retries` | `maxRetries` | ✅ underscore |
| `APP_PAYMENTGATEWAY_MAXRETRIES` | `maxRetries` | ✅ ENV-стиль |
| `app.PaymentGateway.MaxRetries` | — | ❌ |

Для `Map` ключи **сохраняются как есть** (кроме kebab-нормализации); если нужен ключ с точками/спецсимволами — `[my.key]`.

### Валидация на старте — обязательна
```java
@Validated @ConfigurationProperties(prefix = "app.payments")
public record PaymentProperties(@NotBlank String url, @Positive int retries) {}
```
Без `@Validated` аннотации Jakarta Validation **игнорируются**. При нарушении — приложение не стартует с понятным отчётом (`Binding to target ... failed`). Это гораздо лучше, чем NPE в рантайме.

Свой валидатор для сложных правил:
```java
@Component
class PaymentPropertiesValidator implements Validator {
    @Override public boolean supports(Class<?> c) { return PaymentProperties.class.isAssignableFrom(c); }
    @Override public void validate(Object target, Errors errors) {
        var p = (PaymentProperties) target;
        if (p.url().startsWith("http://") && p.credentials() != null)
            errors.rejectValue("url", "insecure", "Секреты нельзя передавать по HTTP");
    }
}
```
(имя бина должно быть `<prefix>-<fqcn>Validator` или зарегистрирован через `@Bean` с `ConfigurationPropertiesBinder`-соглашением; проще — `@AssertTrue`-метод в свойствах).

### Метаданные для IDE
```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-configuration-processor</artifactId>
  <optional>true</optional>
</dependency>
```
```kotlin
annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")
```
Генерирует `spring-configuration-metadata.json` → автодополнение, типы, описания в IDE. Javadoc на компонентах record попадает в описание.

**[4.x]** `@ConfigurationPropertiesSource` — позволяет подтягивать метаданные для типов из **другого модуля**.

### 🪤 Грабли `@ConfigurationProperties`
1. Record + `@DefaultValue` на `Map`/`List`: без дефолта приедет `null`, а не пустая коллекция.
2. Мутабельный JavaBean + `final` коллекция без сеттера — работает (биндер наполняет), но с record — нет.
3. Вложенный record требует, чтобы **все** его компоненты биндились; опечатка в ключе = `null` → валидация спасает.
4. `@ConfigurationProperties` на `@Bean`-методе — легально и полезно для чужих классов:
   ```java
   @Bean @ConfigurationProperties("app.hikari") HikariConfig hikariConfig() { return new HikariConfig(); }
   ```
5. Не путайте `@ConstructorBinding`: в Boot 3+ он нужен только при **нескольких** конструкторах (и переехал в `org.springframework.boot.context.properties.bind`).

## 10.6. `@Value` vs `@ConfigurationProperties`

| Критерий | `@Value` | `@ConfigurationProperties` |
|---|---|---|
| Типобезопасность | слабая | сильная |
| Валидация | нет | Jakarta Validation |
| Группировка | нет | да, иерархия |
| Relaxed binding | ограниченно | полный |
| IDE-подсказки | нет | да (metadata) |
| SpEL | да | нет (только биндинг) |
| Метаданные/документация | нет | да |
| Когда | 1–2 простых значения, SpEL | всё остальное |

## 10.7. Секреты: как надо и как нельзя

**Нельзя:** хранить пароли в `application.yml` в git; логировать конфигурацию целиком; отдавать `/actuator/env` без аутентификации.

**Надо:**
```yaml
spring:
  datasource:
    password: ${DB_PASSWORD}          # из ENV / secret-хранилища
```
* k8s Secret → config tree (`spring.config.import=configtree:/run/secrets/`);
* Vault / AWS Secrets Manager / GCP Secret Manager через соответствующие интеграции (Spring Cloud Vault и др.);
* шифрование значений (Jasypt `ENC(...)`) — компромисс, ключ всё равно нужен снаружи;
* маскирование в actuator: по умолчанию значения с ключами `password`, `secret`, `key`, `token` санитизируются; **[4.x]** `management.endpoint.env.show-values=never|always|when-authorized` (в 3.x — `show-values` тоже есть).

```yaml
management:
  endpoint:
    env:
      show-values: never
    configprops:
      show-values: never
```

🎯 На собеседовании: «как передать пароль в приложение в k8s?» — ожидаемый ответ: secret → volume → config tree (или external secret manager), **не** ENV в манифесте в открытом виде, и уж точно не в образе.

## 10.8. Тестирование конфигурации

```java
@SpringBootTest(properties = {"app.payments.url=http://localhost:1", "app.payments.retries=0"})
@ActiveProfiles("test")
class PaymentsIT { }

@TestPropertySource(properties = "app.flags.beta=true")
class FlagsTest { }

// Динамические свойства (Testcontainers и др.)
@DynamicPropertySource
static void props(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", postgres::getJdbcUrl);
}
```

Юнит-тест самих свойств без всего приложения:
```java
new ApplicationContextRunner()
    .withConfiguration(AutoConfigurations.of(FeatureFlagsAutoConfiguration.class))
    .withPropertyValues("app.flags.enabled=false")
    .run(ctx -> assertThat(ctx).doesNotHaveBean(FeatureFlags.class));
```

## 10.9. Практическая раскладка сред (шаблон, который стоит скопировать)

```text
src/main/resources/
├── application.yml            # общее: имя, jackson, actuator, дефолты
├── application-local.yml      # H2/Testcontainers, show-sql, DEBUG-логи, devtools
├── application-test.yml       # Testcontainers, фиксированный Clock, отключённые внешние вызовы
└── application-prod.yml       # структурированные логи, graceful shutdown, pool sizes, никакого show-sql
config/                        # вне jar: переопределения для конкретной инсталляции (не в git)
```

Правило: **в jar — только дефолты и то, что одинаково во всех средах**. Всё, что различается, — снаружи (ENV, config tree, mounted config).

## 10.10. 🧪 Практика

1. Сделайте `PaymentProperties` (record + валидация) и добейтесь падения на старте при пустом URL.
2. Проверьте relaxed binding: задайте `APP_PAYMENTS_MAX_RETRIES` в ENV и убедитесь, что значение применилось.
3. Настройте группы профилей `local`/`prod` и покажите, что `@Profile("prod-db")` активируется через группу.
4. Поднимите приложение с `configtree` из локальной папки «secrets».
5. Напишите тест, который проверяет биндинг через `ApplicationContextRunner`.
6. Убедитесь, что `/actuator/env` не показывает пароль.

## 10.11. Чек-лист и вопросы

- [ ] Все группы настроек — в `@ConfigurationProperties` с валидацией.
- [ ] Секреты приходят извне, не из git.
- [ ] Профили описывают среды, а не фичи; есть группы.
- [ ] Конфигурация для prod не «зашита» в образ.
- [ ] Есть metadata-процессор и IDE подсказывает свойства.

**Вопросы:** 1) Что сильнее: ENV или `application-prod.yml` в jar? 2) Чем `spring.config.location` отличается от `additional-location`? 3) Почему `@Validated` обязателен для валидации свойств? 4) Как задать `Map` с ключами, содержащими точки? 5) Что такое config tree и зачем он в k8s? 6) Почему `spring.profiles.active` нельзя указывать в профильном документе?

---

**Назад:** [Глава 9](09-avtokonfiguraciya-i-startery.md) · **Дальше:** [Глава 11. Логирование →](11-logirovanie.md)