# Глава 16. Миграции схемы: Flyway, Liquibase и обновления без простоя

> **Уровень:** junior → middle+
> **Время:** 3 часа
> **Цель:** сделать схему БД версионированным артефактом кода и научиться катить изменения так, чтобы старая и новая версии приложения работали одновременно.

## 16.1. Почему `ddl-auto` — не вариант

```yaml
spring.jpa.hibernate.ddl-auto: none        # прод: none или validate
```

| Значение | Что делает | Где допустимо |
|---|---|---|
| `none` | ничего | **прод** (схема управляется миграциями) |
| `validate` | проверяет соответствие маппинга схеме | прод/CI — полезно |
| `update` | «дописывает» схему | ❌ никогда в проде: не удаляет, не меняет типы, непредсказуем |
| `create` / `create-drop` | пересоздаёт | локальные эксперименты, тесты |

Причины: схема — это состояние, которое нельзя «пересоздать» на проде; нужен аудит изменений, ревью, повторяемость и возможность откатa приложения.

## 16.2. Flyway: базовая механика

```text
src/main/resources/db/migration/
├── V1__create_users.sql
├── V2__create_tasks.sql
├── V3__add_tasks_priority.sql
├── V4__backfill_priority.sql
└── R__tasks_search_view.sql        # repeatable: применяется при изменении checksum
```

Правила имён: `V<версия>__<описание>.sql` (два подчёркивания!), версия — числа с точками/подчёркиваниями (`V1_1__...`). Repeatable — `R__...`, выполняются после всех versioned, при изменении содержимого.

Flyway создаёт таблицу `flyway_schema_history`: версия, описание, checksum, время, success. При старте:
1. сравнивает применённые миграции с найденными;
2. `validate` — падает при расхождении checksum/пропущенных версиях;
3. применяет новые по порядку, каждая — в своей транзакции (если БД поддерживает транзакционный DDL — PostgreSQL да, MySQL нет).

### Подключение

**[4.x]**
```xml
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-flyway</artifactId></dependency>
<dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
```
**[3.5]**
```xml
<dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId></dependency>
<dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
```
```kotlin
implementation("org.springframework.boot:spring-boot-starter-flyway")   // 4.x
implementation("org.flywaydb:flyway-core")                             // 3.5
```

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true        # для существующей БД, созданной вручную
    baseline-version: 1
    validate-on-migrate: true
    out-of-order: false              # true — опасно, но нужно при параллельных ветках
    clean-disabled: true             # ОБЯЗАТЕЛЬНО: clean удаляет всё
    placeholders:
      appSchema: public
    default-schema: public
```

🎯 **Порядок с JPA:** Boot гарантирует, что Flyway отработает **до** создания `EntityManagerFactory` (через `FlywayMigrationInitializer` + `@DependsOn`-механизм). Поэтому `ddl-auto: validate` видит уже обновлённую схему.

### Пример набора миграций

```sql
-- V1__create_users.sql
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL,
    name        VARCHAR(200) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_email UNIQUE (email)
);

-- V2__create_tasks.sql
CREATE SEQUENCE task_seq START 1 INCREMENT 50;         -- согласовано с allocationSize=50!
CREATE TABLE tasks (
    id          BIGINT PRIMARY KEY DEFAULT nextval('task_seq'),
    title       VARCHAR(200) NOT NULL,
    slug        VARCHAR(120) NOT NULL,
    status      VARCHAR(20)  NOT NULL,
    owner_id    BIGINT       NOT NULL REFERENCES users(id),
    due_date    DATE,
    version     BIGINT       NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_tasks_slug UNIQUE (slug)
);
CREATE INDEX ix_tasks_owner_status ON tasks(owner_id, status);

-- R__tasks_search_view.sql
CREATE OR REPLACE VIEW tasks_open AS
SELECT id, title, owner_id, due_date FROM tasks WHERE status <> 'DONE';
```

### Java-based миграции (когда SQL не хватает)

```java
public class V5__HashLegacyPasswords extends BaseJavaMigration {
    @Override public void migrate(Context ctx) throws Exception {
        try (var st = ctx.getConnection().createStatement()) {
            // постраничная обработка, чтобы не залочить таблицу целиком
        }
    }
}
```

### Полезные команды и сценарии

```bash
./mvnw flyway:info -Dflyway.url=... -Dflyway.user=...
./mvnw flyway:migrate
./mvnw flyway:validate
./mvnw flyway:repair          # починить checksum после «легальной» правки (осторожно!)
```

🪤 **Никогда не редактируйте применённую миграцию.**Checksum изменится → `validate` упадёт на всех средах. Правка допустима только если миграция ещё нигде не применена (ваша локальная ветка).

## 16.3. Liquibase: когда нужен

```yaml
spring:
  liquibase:
    change-log: classpath:db/changelog/db.changelog-master.yaml
    contexts: prod
    labels: v1.4
```
```yaml
databaseChangeLog:
  - changeSet:
      id: 2026-11-01-tasks-priority
      author: ann
      preConditions:
        - onFail: MARK_RAN
        - not: { columnExists: { tableName: tasks, columnName: priority } }
      changes:
        - addColumn:
            tableName: tasks
            columns:
              - column: { name: priority, type: varchar(20), defaultValue: NORMAL }
      rollback:
        - dropColumn: { tableName: tasks, columnName: priority }
```

| | Flyway | Liquibase |
|---|---|---|
| Формат | SQL (+Java) | XML/YAML/JSON/SQL |
| Порог входа | низкий | выше |
| Rollback | вручную / Teams (undo) | встроенные rollback-блоки |
| Абстракция от БД | нет (SQL под конкретную БД) | да (генерирует диалект) |
| Preconditions | нет | да |
| Когда | одна СУБД, SQL-команда | несколько СУБД, нужен rollback/условия |

🎯 На практике для монолита на PostgreSQL чаще выбирают **Flyway**: проще, прозрачнее, «SQL — это правда».

## 16.4. 🎯 Обновления без простоя: expand / contract

Главная проблема rolling update: **старая и новая версии приложения работают одновременно** с одной схемой. Значит каждое изменение должно быть совместимо «в обе стороны».

**Правило: никогда не делайте breaking change в одном релизе.** Разбивайте на этапы:

### Пример: переименование колонки `name` → `full_name`

| Релиз | Миграция | Код |
|---|---|---|
| 1 (expand) | `ADD COLUMN full_name` (nullable) | пишем в **обе** колонки, читаем старую |
| 2 (backfill) | `UPDATE ... SET full_name = name WHERE full_name IS NULL` батчами | пишем в обе, читаем старую |
| 3 (switch) | — (схему не меняем) | читаем новую, пишем в обе |
| 4 (contract) | `DROP COLUMN name` (после того, как все инстансы на релизе 3+) | только новая |

### Пример: добавление NOT NULL колонки
```sql
-- ❌ одним шагом: ALTER TABLE tasks ADD COLUMN priority VARCHAR(20) NOT NULL;
--    → старая версия приложения делает INSERT без priority → падение

-- ✅ по шагам:
ALTER TABLE tasks ADD COLUMN priority VARCHAR(20);                       -- релиз 1
UPDATE tasks SET priority = 'NORMAL' WHERE priority IS NULL;             -- батчами, релиз 2
ALTER TABLE tasks ALTER COLUMN priority SET DEFAULT 'NORMAL';            -- релиз 3
ALTER TABLE tasks ALTER COLUMN priority SET NOT NULL;                    -- релиз 4 (PG 12+: быстро, если есть CHECK)
```

### Технические приёмы для PostgreSQL
```sql
-- индекс без блокировки записи (НЕЛЬЗЯ внутри транзакции!)
CREATE INDEX CONCURRENTLY ix_tasks_created_at ON tasks(created_at);
```
Для этого Flyway-миграция должна быть non-transactional: в Flyway это делается через `executeInTransaction=false` в скрипте-конфиге (`V7__index.sql.conf`) или через отдельный `Callback`.

```sql
-- constraint без долгого лока: добавить NOT VALID, потом VALIDATE
ALTER TABLE tasks ADD CONSTRAINT ck_status CHECK (status IN ('NEW','DONE')) NOT VALID;
ALTER TABLE tasks VALIDATE CONSTRAINT ck_status;     -- берёт слабую блокировку
```
```sql
-- короткий lock_timeout, чтобы не встать в очередь и не заблокировать всех
SET lock_timeout = '3s';
SET statement_timeout = '60s';
```

**Backfill батчами** — никогда `UPDATE` всей таблицы одной транзакцией: раздувание WAL, долгие локи, лаг репликации. Делайте по 5–10к строк с паузами, лучше — отдельным джобом, а не миграцией.

## 16.5. Миграции и несколько инстансов

* Flyway/Liquibase берут **advisory lock** в БД → при одновременном старте 10 подов миграции применит один, остальные подождут. Это безопасно.
* Но: если миграция длится 10 минут, поды будут «висеть» на старте и k8s может их убить по liveness-пробе. Решения:
  * миграции — **отдельным Job/init-контейнером** в k8s, а в приложении `spring.flyway.enabled=false`;
  * увеличенный `startupProbe.failureThreshold`;
  * миграции быстрые, backfill — отдельно.

🎯 Это очень «взрослый» вопрос на собеседовании: «как вы катите миграции в k8s при 10 репликах?»

## 16.6. Миграции в тестах

```java
@SpringBootTest
@Testcontainers
class MigrationTest {
    @Container @ServiceConnection static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:18");

    @Test void schemaIsValidAgainstMapping() { /* ddl-auto=validate + контекст поднялся = успех */ }
}
```
Полезные практики:
* отдельный тест «пустая БД → все миграции → validate маппинга»;
* тест «БД версии N-1 → миграции → данные сохранились» (на дампе);
* `@ServiceConnection` избавляет от ручного `@DynamicPropertySource`;
* **никогда** не используйте `flyway.clean` в тестах против общей БД.

## 16.7. 🪤 Топ-10 граблей миграций

1. Отредактировали применённую миграцию → checksum mismatch на всех средах.
2. `INCREMENT 1` в последовательности при `allocationSize=50` в Hibernate.
3. `NOT NULL` без дефолта в одном релизе с кодом → падающие INSERT-ы старых подов.
4. `CREATE INDEX` (без CONCURRENTLY) на большой таблице → блокировка записи на минуты.
5. `UPDATE` миллионов строк в одной транзакции → лаг реплик, распухание WAL.
6. Миграция внутри приложения при 10 репликах + короткий liveness → рестарт-петля.
7. `clean-disabled: false` в prod-конфиге → катастрофа по недосмотру.
8. DDL + DML в одной миграции на MySQL → неявный коммит, «половинчатое» состояние.
9. Разные `locations` в разных средах → расхождение схем.
10. Миграция зависит от данных, которых нет на новой среде (например, «обновить существующие строки» без учёта пустой БД).

## 16.8. Чек-лист code review миграции

- [ ] Имя по конвенции, версия больше всех существующих.
- [ ] Изменение обратно совместимо с предыдущей версией кода.
- [ ] Нет долгих блокировок; индексы — `CONCURRENTLY`; constraint-ы — `NOT VALID` + `VALIDATE`.
- [ ] Backfill вынесен в отдельный шаг/джоб, батчами.
- [ ] Есть `lock_timeout`/`statement_timeout` для DDL.
- [ ] Указаны индексы под новые запросы (и проверен план).
- [ ] Нет удаления колонок/таблиц в том же релизе, где код перестал их использовать.
- [ ] Миграция протестирована на копии прод-объёма данных.

## 16.9. 🧪 Практика

1. Соберите набор миграций для `users`/`tasks` c нуля, поднимите приложение с `ddl-auto: validate`.
2. Сломайте checksum специально, получите ошибку, починьте `repair` (и объясните, почему в проде так делать нельзя).
3. Реализуйте expand/contract переименование колонки в 4 шага и проверьте, что «старый» и «новый» код работают одновременно.
4. Создайте индекс `CONCURRENTLY` в non-transactional миграции.
5. Запустите 5 инстансов приложения одновременно и убедитесь, что миграция применилась один раз.

## 16.10. Вопросы

1) Почему `ddl-auto: update` опасен? 2) Что хранит `flyway_schema_history`? 3) Чем repeatable-миграция отличается от versioned? 4) Как добавить NOT NULL колонку без простоя? 5) Почему `CREATE INDEX CONCURRENTLY` нельзя в транзакции? 6) Как катить миграции при 10 репликах в k8s? 7) Когда Liquibase предпочтительнее Flyway?

---

**Назад:** [Глава 15](15-spring-data-jpa.md) · **Дальше:** [Глава 17. Кэширование →](17-keshirovanie.md)