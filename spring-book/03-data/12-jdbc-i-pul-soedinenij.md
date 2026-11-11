# Глава 12. JDBC, `DataSource` и пул соединений

> **Уровень:** junior → middle+
> **Время:** 3–4 часа
> **Цель:** уметь работать с БД без ORM (это нужно чаще, чем думают), правильно настроить HikariCP и понимать, откуда берутся «connection is not available» и утечки.

## 12.1. Когда JDBC, а когда JPA

| Задача | Инструмент |
|---|---|
| CRUD по доменной модели, связи, кэш первого уровня | JPA/Hibernate |
| Отчёты, агрегации, оконные функции, CTE | `JdbcClient`/`JdbcTemplate` |
| Массовые вставки/обновления (100k+ строк) | JDBC batch / `COPY` |
| Легаси-схема без нормальных ключей | JDBC |
| Полный контроль над SQL и планом запроса | JDBC / jOOQ |
| Быстрый прототип | Spring Data JDBC/JPA |

**Смешивать можно и нужно**: JPA для домена, JDBC для отчётов — в одном приложении, на одном `DataSource`, в одной транзакции (при `JpaTransactionManager` JDBC-код видит то же соединение).

## 12.2. `DataSource` и HikariCP

Boot автоматически поднимает HikariCP (в Boot 4 — HikariCP 7).

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/taskflow
    username: taskflow
    password: ${DB_PASSWORD}
    driver-class-name: org.postgresql.Driver
    hikari:
      pool-name: taskflow-pool
      maximum-pool-size: 20
      minimum-idle: 20                 # = maximum для стабильной latency
      connection-timeout: 3000         # сколько ждём соединение из пула, мс
      validation-timeout: 1000
      idle-timeout: 600000             # 10 мин (не применяется при minIdle == maxPoolSize)
      max-lifetime: 1200000            # 20 мин, должно быть < таймаута БД/файрвола
      keepalive-time: 120000           # пинг простаивающих соединений
      leak-detection-threshold: 20000  # логировать «подозрительно долгое» удержание
      auto-commit: false               # явные транзакции; для JPA Boot ставит сам
      connection-init-sql: "SET TIME ZONE 'UTC'"
      data-source-properties:
        reWriteBatchedInserts: true    # PostgreSQL: склейка INSERT в мульти-VALUES
        prepareThreshold: 5
```

### 🎯 Как считать размер пула (главный вопрос про пулы)

Формула Литтла: `пул ≈ TPS × среднее_время_занятости_соединения(сек)`.
Пример: 500 запросов/с, каждый держит соединение 20 мс → 500 × 0.02 = **10 соединений**. Плюс запас 20–50 % → 12–15.

Контринтуитивный факт: **большой пул вреден**. БД имеет ограниченное число ядер и дисков; 200 соединений на 8-ядерной БД дают переключение контекста, блокировки и рост latency. Классическая рекомендация HikariCP: `connections = (core_count * 2) + effective_spindle_count` — как отправная точка.

Ещё правила:
* `max-lifetime` **меньше** любого таймаута на пути (БД `idle_in_transaction_session_timeout`, PgBouncer, NAT/файрвол), иначе получите «connection reset» на живом, казалось бы, соединении.
* `connection-timeout` должен быть **меньше** таймаута HTTP-клиента, иначе клиент отвалится раньше, чем вы отдадите 503.
* `minimum-idle = maximum-pool-size` для сервисов с постоянной нагрузкой (нет «пилы» на создание соединений).
* Несколько пулов (основной + отчётный) изолируют тяжёлые запросы от OLTP.

### Метрики пула (обязательны в проде)
```text
hikaricp.connections.active     — занятые
hikaricp.connections.idle       — свободные
hikaricp.connections.pending    — очередь ожидающих  ← главный алерт
hikaricp.connections.acquire    — время получения
hikaricp.connections.usage      — время удержания
hikaricp.connections.timeout    — отказы
```
Алерт: `pending > 0` устойчиво + `acquire p99 > 100 мс` = пул исчерпан. Причина обычно не «мало соединений», а **долгие транзакции** или **утечка**.

## 12.3. `JdbcTemplate`: базовый инструментарий

```java
@Repository
@RequiredArgsConstructor
class JdbcTaskRepository {
    private final JdbcTemplate jdbc;

    Optional<TaskRow> findById(long id) {
        return jdbc.query("SELECT id, title, status FROM tasks WHERE id = ?",
                          new TaskRowMapper(), id)
                   .stream().findFirst();
    }

    List<TaskRow> findByStatus(Status status, int limit) {
        return jdbc.query("""
                SELECT id, title, status FROM tasks
                WHERE status = ? ORDER BY created_at DESC LIMIT ?
                """, new TaskRowMapper(), status.name(), limit);
    }

    int updateStatus(long id, Status status) {
        return jdbc.update("UPDATE tasks SET status = ?, updated_at = now() WHERE id = ?", status.name(), id);
    }

    long count() {
        return jdbc.queryForObject("SELECT count(*) FROM tasks", Long.class);
    }
}

class TaskRowMapper implements RowMapper<TaskRow> {
    @Override public TaskRow mapRow(ResultSet rs, int rowNum) throws SQLException {
        return new TaskRow(rs.getLong("id"), rs.getString("title"), Status.valueOf(rs.getString("status")));
    }
}
```

Три коллбэка и когда какой:

| Коллбэк | Для чего |
|---|---|
| `RowMapper<T>` | одна строка → один объект (99 % случаев) |
| `ResultSetExtractor<T>` | весь `ResultSet` → один объект (агрегация, иерархии, «шапка+строки») |
| `RowCallbackHandler` | обработка «на месте» без накопления (стриминг миллиона строк) |

```java
// ResultSetExtractor: заказ + позиции одним запросом (борьба с N+1 руками)
Map<Long, OrderView> orders = jdbc.query("""
        SELECT o.id, o.total, i.id AS item_id, i.name
        FROM orders o LEFT JOIN order_items i ON i.order_id = o.id
        WHERE o.created_at > ?
        """, rs -> {
    Map<Long, OrderView> result = new LinkedHashMap<>();
    while (rs.next()) {
        var order = result.computeIfAbsent(rs.getLong("id"),
                id -> new OrderView(id, new ArrayList<>()));
        long itemId = rs.getLong("item_id");
        if (!rs.wasNull()) order.items().add(new ItemView(itemId, rs.getString("name")));
    }
    return result;
}, since);
```

Вставка с генерируемым ключом:
```java
var keyHolder = new GeneratedKeyHolder();
jdbc.update(con -> {
    PreparedStatement ps = con.prepareStatement(
        "INSERT INTO tasks(title, status) VALUES (?, ?)", new String[]{"id"});
    ps.setString(1, title); ps.setString(2, "NEW");
    return ps;
}, keyHolder);
long id = keyHolder.getKey().longValue();
```

Batch:
```java
jdbc.batchUpdate("INSERT INTO tasks(title, status) VALUES (?, ?)",
        tasks, 500,                                   // размер батча
        (ps, task) -> { ps.setString(1, task.title()); ps.setString(2, task.status()); });
```
🎯 Без `reWriteBatchedInserts=true` (PG) батч — это просто N round-trip-ов в одном вызове. С ним — один мульти-VALUES INSERT, разница в разы. В MySQL аналог — `rewriteBatchedStatements=true`.

Стриминг больших выборок (не грузим всё в память):
```java
jdbc.setFetchSize(1000);     // для PG работает только при autoCommit=false!
jdbc.query("SELECT * FROM events", rs -> { export(rs.getString("payload")); });
```

## 12.4. `NamedParameterJdbcTemplate` и `JdbcClient`

```java
// Именованные параметры — читаемо и безопасно
var params = new MapSqlParameterSource("status", "NEW").addValue("limit", 50);
namedJdbc.query("SELECT * FROM tasks WHERE status = :status LIMIT :limit", params, mapper);
```

**`JdbcClient`** — fluent-фасад (Spring 6.1+, в 7.0 расширен настройками statement):
```java
@Repository
@RequiredArgsConstructor
class TaskQueries {
    private final JdbcClient client;

    List<TaskSummary> search(String q, Status status, int limit) {
        return client.sql("""
                SELECT id, title, status FROM tasks
                WHERE (:q IS NULL OR title ILIKE :q) AND status = :status
                ORDER BY created_at DESC
                """)
                .param("q", q == null ? null : "%" + q + "%")
                .param("status", status.name())
                .fetchSize(200)                  // [7.0] настройки уровня statement
                .queryTimeout(5)                 // [7.0]
                .query(TaskSummary.class);       // маппинг в record по именам колонок!
    }

    Optional<TaskSummary> byId(long id) {
        return client.sql("SELECT id, title, status FROM tasks WHERE id = :id")
                .param("id", id).query(TaskSummary.class).optional();
    }

    int deactivate(long id) {
        return client.sql("UPDATE tasks SET status = 'ARCHIVED' WHERE id = :id").param("id", id).update();
    }
}
```
🎯 `query(SomeRecord.class)` маппит по именам компонентов — это делает `JdbcClient` почти «мини-ORM» и лучшей заменой `JdbcTemplate` для нового кода.

## 12.5. Трансляция исключений

```text
SQLException (vendor code) → SQLExceptionTranslator → DataAccessException
   23505 (PG unique_violation)  → DuplicateKeyException
   23503 (FK)                   → DataIntegrityViolationException
   40001 (serialization)        → ConcurrencyFailureException / CannotAcquireLockException
   08xxx (connection)           → DataAccessResourceFailureException
```
Зачем: бизнес-код не зависит от вендора и не обязан ловить checked `SQLException`.

```java
try { repo.insert(task); }
catch (DuplicateKeyException e) { throw new TaskAlreadyExistsException(task.slug()); }
```

**[4.x]** свойство `spring.dao.exceptiontranslation.enabled` переименовано в `spring.persistence.exceptiontranslation.enabled`.

## 12.6. Несколько `DataSource` и роутинг

```java
@Configuration
class DataSourcesConfig {
    @Bean @Primary @ConfigurationProperties("app.ds.primary")
    DataSourceProperties primaryProps() { return new DataSourceProperties(); }

    @Bean @Primary
    DataSource primary(@Qualifier("primaryProps") DataSourceProperties p) {
        return p.initializeDataSourceBuilder().type(HikariDataSource.class).build();
    }

    @Bean @ConfigurationProperties("app.ds.reports")
    DataSourceProperties reportProps() { return new DataSourceProperties(); }

    @Bean DataSource reports(@Qualifier("reportsProps") DataSourceProperties p) {
        return p.initializeDataSourceBuilder().type(HikariDataSource.class).build();
    }

    @Bean JdbcClient reportClient(@Qualifier("reports") DataSource ds) { return JdbcClient.create(ds); }
}
```
🪤 При двух `DataSource` **обязательно** помечайте один `@Primary`, иначе автоконфигурация JPA/транзакций сломается. И помните: транзакция привязана к **одному** менеджеру/источнику; «одна транзакция на две БД» без XA не работает (и XA вам не нужен — см. главу 13, outbox/saga).

Read/write splitting через `AbstractRoutingDataSource`:
```java
class ReadWriteRouting extends AbstractRoutingDataSource {
    @Override protected Object determineCurrentLookupKey() {
        return TransactionSynchronizationManager.isCurrentTransactionReadOnly() ? "replica" : "primary";
    }
}
```
🪤 Работает только если решение принимается **до** получения соединения, то есть на входе в транзакцию. `readOnly=true` внутри уже открытой транзакции не переключит источник. Плюс лаг репликации: после записи читать с реплики может быть нельзя.

## 12.7. Тестирование JDBC-слоя

```java
@JdbcTest                                       // только JDBC-инфраструктура + откат транзакций
@AutoConfigureTestDatabase(replace = NONE)      // используем реальную БД из Testcontainers
@Testcontainers
class TaskQueriesTest {
    @Container @ServiceConnection
    static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:18-alpine");

    @Autowired JdbcClient client;
    @Autowired TaskQueries queries;

    @Test void findsByStatus() { /* ... */ }
}
```
🎯 **Никогда не тестируйте SQL на H2, если прод на PostgreSQL.** Диалекты, `ILIKE`, оконные функции, JSONB, поведение `LIMIT`/`NULLS` — всё разное. Testcontainers — стандарт индустрии (глава 23).

## 12.8. 🪤 Топ-10 граблей JDBC/пула

1. Утечка соединения: взяли `Connection` вручную и не закрыли → пул исчерпан через час. Всегда try-with-resources или шаблон Spring.
2. Долгая транзакция с внешним HTTP-вызовом внутри → соединение занято на секунды → `pending` растёт.
3ate. `max-lifetime` больше таймаута БД/прокси → случайные `connection reset`.
4. Огромный пул «чтобы точно хватило» → деградация БД.
5. `fetchSize` без `autoCommit=false` в PG → драйвер всё равно тянет всё в память.
6. Batch без `reWriteBatchedInserts` → «батч не ускорил».
7. `queryForObject` при 0 строк → `EmptyResultDataAccessException` (не `null`!). Используйте `.query(...).stream().findFirst()`.
8. Конкатенация параметров в SQL → SQL-инъекция. Только `?`/`:name`.
9. `IN (?)` со списком → не работает; нужен `NamedParameterJdbcTemplate` с `List` или генерация плейсхолдеров.
10. Два `DataSource` без `@Primary` → контекст не поднимается.

## 12.9. 🧪 Практика

1. Реализуйте репозиторий на `JdbcClient` с маппингом в record.
2. Сделайте отчёт «заказ + позиции» одним запросом через `ResultSetExtractor`.
3. Вставьте 100 000 строк батчем с `reWriteBatchedInserts` и без — сравните время.
4. Настройте `leak-detection-threshold: 2000`, специально «забудьте» закрыть соединение и найдите предупреждение в логах.
5. Выведите метрики Hikari в `/actuator/metrics` и объясните каждый показатель.
6. Сымитируйте исчерпание пула: `maximum-pool-size: 2`, 10 параллельных запросов со `pg_sleep(2)`.

## 12.10. Чек-лист и вопросы

- [ ] Размер пула обоснован формулой, а не «на глаз».
- [ ] `max-lifetime` меньше внешних таймаутов; есть `keepalive`.
- [ ] Метрики пула в мониторинге, алерт на `pending`.
- [ ] Никаких внешних вызовов внутри транзакции.
- [ ] SQL-тесты идут на том же движке, что прод.

**Вопросы:** 1) Как посчитать размер пула? 2) Почему большой пул вреден? 3) Что делает `leak-detection-threshold`? 4) Чем `RowMapper` отличается от `ResultSetExtractor`? 5) Почему `fetchSize` не работает при `autoCommit=true` в PG? 6) Что вернёт `queryForObject`, если строк нет? 7) Как одна транзакция объединяет JPA и JDBC?

---

**Назад:** [Глава 11](../02-boot/11-logirovanie.md) · **Дальше:** [Глава 13. Транзакции →](13-tranzakcii.md)