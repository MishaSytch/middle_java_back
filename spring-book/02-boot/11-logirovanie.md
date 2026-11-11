# Глава 11. Логирование: от `System.out` до структурированных логов с корреляцией

> **Уровень:** junior → middle+
> **Время:** 2.5–3 часа
> **Цель:** настроить логирование так, чтобы инцидент разбирался за минуты: правильный формат, корреляция запросов, безопасные данные, нулевые накладные расходы на «выключенных» уровнях.

## 11.1. Фасад и реализация

```text
Ваш код → SLF4J API (org.slf4j.Logger)
              ↓
          Logback (по умолчанию в Boot) | Log4j2 | JUL
```

* Пишите **всегда** через SLF4J (`LoggerFactory.getLogger`). Никогда — напрямую Logback/Log4j API в бизнес-коде.
* **[4.x]** `spring-jcl` удалён: Spring перешёл на Apache Commons Logging 1.3. Для вас это прозрачно — мосты настроены Boot.
* Смена реализации:
```xml
<dependency>
  <groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc</artifactId>
  <exclusions><exclusion>
    <groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-logging</artifactId>
  </exclusion></exclusions>
</dependency>
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-log4j2</artifactId></dependency>
```
Gradle:
```kotlin
configurations.all { exclude(group = "org.springframework.boot", module = "spring-boot-starter-logging") }
implementation("org.springframework.boot:spring-boot-starter-log4j2")
```

🪤 Никогда не держите два биндинга SLF4J в classpath — получите `SLF4J: Class path contains multiple SLF4J bindings` и непредсказуемый вывод.

## 11.2. Уровни: как выбирать

| Уровень | Смысл | Пример |
|---|---|---|
| `ERROR` | что-то сломалось, требует реакции человека | не удалось списать деньги после всех retry |
| `WARN` | аномалия, система справилась сама | retry удался, деградация к fallback |
| `INFO` | значимые бизнес-события и границы | задача создана, заказ оплачен, приложение стартовало |
| `DEBUG` | детали для разработчика | параметры запроса к БД, промежуточные решения |
| `TRACE` | всё подряд | тела запросов/ответов, пошаговый алгоритм |

Правила:
* `INFO` в проде — это **бизнес-события**, а не «вошли в метод».
* Одна ошибка — **один** лог. Не «log and rethrow» на каждом уровне (иначе 5 стектрейсов на один сбой).
* Ошибка логируется **на границе**, где принимается решение (обработчик исключений, консьюмер, контроллер-адвайс).

```java
private static final Logger log = LoggerFactory.getLogger(TaskService.class);

log.info("Задача создана id={} owner={} priority={}", task.id(), task.owner(), task.priority());  // ✅ параметризация
log.debug("Найдено {} кандидатов", candidates.size());
if (log.isTraceEnabled()) log.trace("payload={}", expensiveSerialize(payload));                  // ✅ защита дорогой операции
log.error("Не удалось отправить письмо taskId={}", id, ex);                                      // ✅ исключение последним аргументом
```

🪤 `log.info("id=" + id)` — конкатенация выполняется **всегда**, даже если уровень выключен. Параметризация `{}` — нет.

## 11.3. Настройка через свойства (без XML)

```yaml
logging:
  level:
    root: INFO
    dev.book.taskflow: DEBUG
    org.hibernate.SQL: DEBUG                      # SQL-запросы
    org.hibernate.orm.jdbc.bind: TRACE            # значения параметров (Hibernate 6+/7)
    org.springframework.web: INFO
    com.zaxxer.hikari: INFO
  file:
    name: logs/app.log                            # писать в файл (в контейнере обычно не нужно)
  logback:
    rollingpolicy:
      max-file-size: 50MB
      max-history: 14
      total-size-cap: 2GB
  pattern:
    level: "%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]"
  console:
    enabled: true                                 # [4.x] новое свойство
  structured:
    format:
      console: ecs                                # см. §11.5
```

**[4.x]** Дефолтная кодировка файлов логов — UTF-8 (гармонизировано с Log4j2); для консоли используется `Console#charset()`, если доступен.

Быстрая диагностика в рантайме через Actuator:
```bash
curl -X POST localhost:8080/actuator/loggers/dev.book.taskflow \
  -H 'Content-Type: application/json' -d '{"configuredLevel":"DEBUG"}'
curl localhost:8080/actuator/loggers/dev.book.taskflow
```
🎯 Это must-have на проде: включаете DEBUG для одного пакета на 5 минут, находите проблему, выключаете. Без рестарта.

## 11.4. `logback-spring.xml`: когда свойств не хватает

Используйте **`logback-spring.xml`** (не `logback.xml`) — тогда доступны расширения Boot.

```xml
<configuration>
  <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
  <springProperty scope="context" name="appName" source="spring.application.name" defaultValue="app"/>

  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder><pattern>${CONSOLE_LOG_PATTERN}</pattern></encoder>
  </appender>

  <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>logs/${appName}.log</file>
    <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
      <fileNamePattern>logs/${appName}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
      <maxFileSize>50MB</maxFileSize><maxHistory>14</maxHistory><totalSizeCap>2GB</totalSizeCap>
    </rollingPolicy>
    <encoder><pattern>${FILE_LOG_PATTERN}</pattern></encoder>
  </appender>

  <appender name="ASYNC" class="ch.qos.logback.classic.AsyncAppender">
    <queueSize>8192</queueSize>
    <discardingThreshold>0</discardingThreshold>       <!-- не выбрасывать WARN/INFO при заполнении -->
    <neverBlock>true</neverBlock>                      <!-- лучше потерять лог, чем заблокировать запрос -->
    <appender-ref ref="FILE"/>
  </appender>

  <springProfile name="local">
    <root level="INFO"><appender-ref ref="CONSOLE"/></root>
    <logger name="dev.book" level="DEBUG"/>
  </springProfile>

  <springProfile name="prod">
    <root level="INFO"><appender-ref ref="ASYNC"/></root>
  </springProfile>
</configuration>
```

🪤 **AsyncAppender и MDC:** MDC копируется в поток аппендера, но `neverBlock=true` означает потерю логов под нагрузкой. Это осознанный trade-off: latency важнее полноты. Для аудита используйте отдельный синхронный аппендер.

## 11.5. Структурированные логи — стандарт для прода

Человекочитаемый текст плохо ищется. Машиночитаемый JSON — хорошо. Boot умеет это **из коробки**:

```yaml
logging:
  structured:
    format:
      console: ecs        # Elastic Common Schema
      # file: logstash    # или gelf
    ecs:
      service:
        name: taskflow
        version: 1.4.2
```

Поддерживаемые форматы: `ecs`, `gelf`, `logstash`. Свой формат — бин `StructuredLogFormatter`:

```java
@Bean
StructuredLogFormatter<ILoggingEvent> customFormatter() {
    return event -> """
        {"ts":"%s","level":"%s","msg":"%s","trace":"%s"}"""
        .formatted(event.getInstant(), event.getLevel(), escape(event.getFormattedMessage()),
                   event.getMDCPropertyMap().get("traceId"));
}
```

Дополнительные поля:
```java
log.atInfo().addKeyValue("taskId", id).addKeyValue("owner", owner).log("Задача создана");
```
```yaml
logging.structured.json.add.app.name: ${spring.application.name}
```

Преимущества: фильтры по `taskId`, агрегации по `owner`, корреляция с трейсами, дешёвый поиск в Loki/ELK/OpenSearch.

## 11.6. Корреляция: MDC, traceId и передача между потоками

**MDC (Mapped Diagnostic Context)** — `ThreadLocal`-карта, которую логгер добавляет к каждой записи.

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter extends OncePerRequestFilter {
    public static final String HEADER = "X-Request-Id";
    @Override protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String id = Optional.ofNullable(req.getHeader(HEADER)).orElseGet(() -> UUID.randomUUID().toString());
        MDC.put("requestId", id);
        res.setHeader(HEADER, id);
        try { chain.doFilter(req, res); }
        finally { MDC.remove("requestId"); }      // ← ОБЯЗАТЕЛЬНО: пул потоков переиспользуется
    }
}
```

Передача в `@Async`/пулы — `TaskDecorator`:
```java
@Bean
TaskDecorator mdcTaskDecorator() {
    return runnable -> {
        Map<String, String> context = MDC.getCopyOfContextMap();
        return () -> {
            if (context != null) MDC.setContextMap(context);
            try { runnable.run(); } finally { MDC.clear(); }
        };
    };
}
```
```yaml
spring.task.execution.thread-name-prefix: app-
```
**[4.x]** поддерживается **несколько** `TaskDecorator`-бинов: Boot собирает `CompositeTaskDecorator` в порядке `@Order`. **[3.5]** — только один.

Передача наружу (чтобы соседний сервис логировал тот же id):
```java
@Bean
RestClient restClient(RestClient.Builder builder) {
    return builder.requestInterceptor((request, body, execution) -> {
        String id = MDC.get("requestId");
        if (id != null) request.getHeaders().add(CorrelationIdFilter.HEADER, id);
        return execution.execute(request, body);
    }).build();
}
```

🎯 **Лучший вариант — не изобретать**: подключите Micrometer Tracing (глава 25), и `traceId`/`spanId` будут автоматически в MDC, в HTTP-заголовках (W3C `traceparent`) и в логах. Свой `requestId` тогда нужен только как бизнес-идентификатор.

## 11.7. Что нельзя логировать

* Пароли, токены, ключи, полные номера карт, CVV, персональные данные (152-ФЗ/GDPR).
* Полные тела запросов на INFO в проде (объём + PII).
* Секреты в URL (query-параметры с токенами).

Маскирование:
```java
public final class Masking {
    public static String card(String pan) { return pan == null ? null : "******" + pan.substring(pan.length()-4); }
    public static String email(String e) { return e == null ? null : e.replaceAll("(^.).*(@.*$)", "$1***$2"); }
}
```
Плюс: санитизация в actuator (`show-values: never`), запрет логирования заголовка `Authorization` на уровне фильтра, ревью логов на code review.

## 11.8. Логи в контейнере

* Пишите **в stdout/stderr**, не в файлы. Ротацию и сбор делает платформа.
* Никаких `RollingFileAppender` в k8s — иначе диск ноды закончится.
* Формат — JSON (`logging.structured.format.console: ecs`).
* Сбор: Loki/Promtail, Fluent Bit → Elasticsearch/OpenSearch, CloudWatch.
* Стектрейсы: JSON-формат корректно экранирует многострочность (в текстовом формате нужны правила multiline в сборщике).

## 11.9. Диагностика производительности логирования

| Проблема | Симптом | Решение |
|---|---|---|
| Синхронный файловый аппендер | latency растёт под нагрузкой | `AsyncAppender`, stdout |
| Конкатенация строк | CPU тратится на выключенных уровнях | параметризация `{}` |
| Логирование в цикле | миллионы строк, забитый диск | агрегировать, sampling |
| `TRACE` на `org.hibernate` в проде | логи растут гигабайтами | только по инциденту через actuator |
| Дорогая сериализация в аргументе | тормозит даже при DEBUG off | `isTraceEnabled()` |

## 11.10. 🧪 Практика

1. Настройте `logging.pattern.level` с `traceId` и убедитесь, что при отсутствии трейса вывод не ломается (`%X{traceId:-}`).
2. Включите структурированный вывод `ecs` и найдите в JSON поля `service.name`, `log.level`.
3. Сделайте `CorrelationIdFilter` + `TaskDecorator`, вызовите `@Async`-метод и проверьте, что `requestId` тот же.
4. Через actuator поднимите уровень своего пакета до DEBUG и верните обратно.
5. Намеренно залогируйте пароль — затем исправьте и добавьте маскирование.

## 11.11. Чек-лист и вопросы

- [ ] Логи через SLF4J, параметризованные, без конкатенации.
- [ ] В проде — JSON в stdout, уровень INFO, ERROR только для реальных сбоев.
- [ ] Есть корреляция запросов (свой id или traceId) и она переживает `@Async`.
- [ ] MDC всегда чистится в `finally`.
- [ ] Секреты и PII не попадают в логи; actuator санитизирован.
- [ ] Уровни меняются в рантайме через actuator.

**Вопросы:** 1) Почему `logback-spring.xml`, а не `logback.xml`? 2) Что делает `discardingThreshold=0`? 3) Почему MDC «протекает» между запросами? 4) Как передать контекст в `@Async`? 5) Чем ECS-формат лучше текстового? 6) Где правильно логировать исключение — в сервисе или в `@RestControllerAdvice`?

---

**Назад:** [Глава 10](10-konfiguraciya-i-profili.md) · **Дальше:** [Глава 12. JDBC и пул соединений →](../03-data/12-jdbc-i-pul-soedinenij.md)