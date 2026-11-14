# Database Migrations

### 1. Flyway: migrations, callbacks, multi-module, versioning strategy

**Flyway** — инструмент **управления** **миграциями** **БД** (версионирование схемы, **apply** в **порядке**).

**Концепции**:
- **Migration**: **SQL** **файл** (или **Java** **класс** с **версией**), **применяется** **один** **раз**.
- **Версия**: **V1__init.sql**, **V2__add_orders.sql**, **V3__add_index.sql** (упорядоченные).
- **Repeatable**: **R1__update_view.sql** (перезапускается при **изменении** **чексума**).
- **Baseline**: **начальное** **состояние** **существующей** БД (без **миграций**).

**Структура**:
```
src/main/resources/db/migration/
├── V1__create_users.sql
├── V2__create_orders.sql
├── V3__add_index_orders_user_id.sql
├── V4__create_audit_log.sql
├── R1__update_user_view.sql
└── CHANGELOG.md
```

**Конфигурация (Spring Boot)**:
```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true  # для существующей БД
    validate-on-migrate: true  # проверка целостности
    out-of-order: false        # не применять миграции вперёд
```

**Команды**:
```bash
# Maven:
mvn flyway:migrate       # применить все миграции
mvn flyway:info          # показать статус
mvn flyway:baseline      # создать baseline
mvn flyway:validate      # проверить целостность
mvn flyway:repair        # исправить metadata
```

**Callbacks** (хуки):
```java
// Перед миграцией:
@BeforeMigration
public void before(MigrationInfo migration) {
    log.info("Applying migration: {}", migration.getDescription());
}

// После миграции:
@AfterMigration
public void after(MigrationInfo migration) {
    log.info("Applied migration: {}", migration.getDescription());
}

// При ошибке:
@OnError
public void onError(MigrationInfo migration, Exception e) {
    alertOps("Migration failed: " + migration.getVersion(), e);
}
```

**Multi-module** (модульная архитектура):
- **Каждый** модуль — **своя** БД (database-per-service).
- **Flyway** **конфигурация** на **каждый** модуль (отдельный `flyway.conf` или `application.yml`).
- **Порядок**: **сначала** **миграции** **БД**, **потом** **деплой** **кода**.

**Versioning strategy**:
- **V** (versioned): **применяется** **один** **раз**, **не** **изменяется** после **apply**.
- **R** (repeatable): **перезапускается** при **изменении** (view, trigger).
- **У** **каждой** **миграции** **уникальная** **версия** (V1, V2, V3, ...).
- **Нельзя** **удалять** **применённые** миграции (только **добавлять** **новые**).

**Типовые проблемы**:
- **Изменение** **применённой** **миграции** → **validate** **fails** (checksum mismatch).
- **Решение**: **новая** **миграция** (V4__fix_index.sql), **не** **правка** **старой**.
- **Out-of-order**: **V5** **применена**, **V4** **ещё** **нет** → **ошибка** (нужно **out-of-order=true** или **переупорядочить**).

### 2. Liquibase: changelog formats, diff generation

**Liquibase** — ещё один инструмент **миграций** (похож на Flyway, **другие** **форматы**).

**Форматы changelog**:
- **XML**: `<changeSet>` с **XML** **операциями** (createTable, addColumn).
- **YAML**: **аналогично** (YAML).
- **SQL**: **сырой** **SQL** (как Flyway).
- **JSON**: **аналогично**.

**Пример (XML)**:
```xml
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
    <changeSet id="1" author="dev">
        <createTable tableName="users">
            <column name="id" type="BIGINT" autoIncrement="true">
                <constraints primaryKey="true"/>
            </column>
            <column name="email" type="VARCHAR(255)">
                <constraints nullable="false" unique="true"/>
            </column>
        </createTable>
    </changeSet>
    
    <changeSet id="2" author="dev">
        <createIndex tableName="users" indexName="idx_users_email">
            <column name="email"/>
        </createIndex>
    </changeSet>
</databaseChangeLog>
```

**Пример (YAML)**:
```yaml
databaseChangeLog:
  - changeSet:
      id: 1
      author: dev
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: BIGINT
                  autoIncrement: true
                  constraints:
                    primaryKey: true
              - column:
                  name: email
                  type: VARCHAR(255)
                  constraints:
                    nullable: false
                    unique: true
```

**Diff generation**:
- **Liquibase** **может** **сгенерировать** **changelog** **из** **разницы** **между** **моделью** **и** **БД**.
- **`liquibase diff`** → **XML/YAML** **с** **изменениями**.
- **`liquibase diffChangelog`** → **сравнение** **двух** **БД**.

```bash
# Сгенерировать changelog из разницы:
liquibase diff --reference-url=jdbc:postgresql://ref-db \
               --url=jdbc:postgresql://current-db \
               --changeLogFile=changelog.xml
```

**Spring Boot integration**:
```yaml
spring:
  liquibase:
    enabled: true
    change-log: classpath:db/changelog/master.xml
```

**Liquibase vs Flyway**:
| | Flyway | Liquibase |
|---|---|---|
| **Формат** | SQL (основной) | XML, YAML, SQL, JSON |
| **Сложность** | Низкая (SQL) | Средняя (XML/YAML) |
| **Diff** | Нет | Да |
| **Rollback** | SQL (undo) | Встроенный (generateRollback) |
| **Экосистема** | Простая | Большие (enterprise) |
| **Выбор** | Простые миграции (SQL) | Сложные (XML, diff, rollback) |

**Когда что**:
- **Flyway**: **простые** **SQL** **миграции**, **маленькая** **команда**.
- **Liquibase**: **сложные** **миграции** (XML), **enterprise** (diff, rollback), **multiple** **форматы**.

### 3. Zero-downtime migrations: expand-contract pattern

**Zero-downtime** — **миграция** **БД** **без** **остановки** **приложения** (no downtime).

**Проблема**: **изменение** **схемы** (добавление **колонки**, **переименование**) **ломает** **старый** **код** (читает **старую** **схему**).

**Expand-Contract** (2 фазы):

**Фаза 1: Expand** (расширение):
- **Добавить** **новую** **колонку** (nullable, **с** **default**).
- **Записать** **данные** **и** в **старую**, **и** в **новую** **колонку** (dual-write).
- **Старый** **код** **читает** **старую** **колонку** (не **меняется**).

**Фаза 2: Migrate** (миграция данных):
- **Мигрировать** **данные** **из** **старой** **колонки** **в** **новую** (batch, **асинхронно**).
- **Проверить** **целостность** (count, sum).

**Фаза 3: Contract** (сужение):
- **Новый** **код** **читает** **только** **новую** **колонку**.
- **Удалить** **дual-write** (запись **только** в **новую**).
- **Удалить** **старую** **колонку** (отдельная **миграция**, **после** **деплоя** **нового** **кода**).

**Пример**:
```sql
-- Фаза 1: Expand
ALTER TABLE users ADD COLUMN phone_new VARCHAR(20);  -- nullable, default NULL
-- Код: dual-write (запись в phone И phone_new)

-- Фаза 2: Migrate (асинхронно, batch)
UPDATE users SET phone_new = phone WHERE phone_new IS NULL LIMIT 1000;
-- (повторять до 0 строк)

-- Фаза 3: Contract
-- Новый код: чтение только phone_new
ALTER TABLE users DROP COLUMN phone;  -- после деплоя нового кода
```

**Почему 3 фазы**:
- **Одна** **миграция** (DROP COLUMN) **ломает** **старый** **код** (читает **phone**).
- **3 фазы** **позволяют** **деплоить** **новый** **код** **до** **удаления** **старой** **колонки**.

**Типовые ошибки**:
- **DROP COLUMN** **в** **одной** **миграции** (без **expand**) → **дowntime**.
- **Забыть** **dual-write** → **данные** **в** **старой** **колонке** **не** **мигрированы**.
- **Удалить** **старую** **колонку** **до** **деплоя** **нового** **кода** → **500**.

### 4. Backwards-compatible schema changes

**Backwards-compatible** — **изменение** **схемы**, **которое** **не** **ломает** **старый** **код**.

**Правила**:
1. **Добавление** **колонки** (nullable, **с** **default**) → **безопасно** (старый **код** **не** **видит** **новую** **колонку**).
2. **Добавление** **индекса** → **безопасно** (не **меняет** **схему** **данных**).
3. **Переименование** **колонки** → **НЕ** **безопасно** (старый **код** **читает** **старое** **имя**).
4. **Удаление** **колонки** → **НЕ** **безопасно** (старый **код** **читает** **колонку**).
5. **Изменение** **типа** **колонки** → **НЕ** **безопасно** (старый **код** **ожидает** **старый** **тип**).

**Как **сделать** **backwards-compatible**:
- **Переименование**: **expand-contract** (добавить **новую** → мигрировать → удалить **старую**).
- **Удаление**: **expand-contract** (отметить **deprecated** → новый **код** **не** **читает** → удалить).
- **Изменение** **типа**: **expand-contract** (добавить **новую** **с** **новым** **типом** → мигрировать → удалить **старую**).

**Пример (изменение типа)**:
```sql
-- Было: price INT
-- Стало: price DECIMAL(10,2)

-- Expand:
ALTER TABLE orders ADD COLUMN price_decimal DECIMAL(10,2);
UPDATE orders SET price_decimal = price::DECIMAL(10,2);

-- Код: dual-write (запись в price И price_decimal)
-- Миграция: UPDATE orders SET price_decimal = price::DECIMAL(10,2) WHERE price_decimal IS NULL;

-- Contract:
-- Новый код: чтение только price_decimal
ALTER TABLE orders DROP COLUMN price;
```

**Инструменты**:
- **Flyway** / **Liquibase**: **миграции** **в** **порядке**.
- **pg_repack** (PostgreSQL): **реорганизация** **таблицы** **без** **блокировок**.
- **gh-ost** (GitHub): **online** **schema** **change** для **MySQL**.

### 5. Schema versioning для микросервисов

**Проблема**: **микросервисы** **делят** **БД** (database-per-service), **каждый** **сервис** **менеджит** **свою** **схему**.

**Подходы**:

**1. Centralized** (один **менеджер**):
- **Один** **сервис** (например, **schema-manager**) **применяет** **все** **миграции** **для** **всех** **БД**.
- **Плюс**: **один** **место** **для** **миграций**, **просто** **управлять**.
- **Минус**: **SPOF**, **сложно** **масштабировать**.

**2. Distributed** (каждый **сервис** **сам):
- **Каждый** **микросервис** **применяет** **свои** **миграции** **для** **своей** **БД**.
- **Плюс**: **автономность**, **масштабируемость**.
- **Минус**: **сложно** **управлять** (N **сервисов** = N **миграций**).

**3. Hybrid** (рекомендуется):
- **Каждый** **сервис** **применяет** **свои** **миграции** **при** **запуске** (Spring Boot **Flyway/Liquibase**).
- **CI/CD**: **сначала** **миграции** (отдельный **step**), **потом** **деплой** **кода**.
- **Один** **репозиторий** **для** **миграций** (common module).

**CI/CD pipeline**:
```yaml
# GitHub Actions:
- name: Run DB migrations
  run: mvn flyway:migrate
  
- name: Build
  run: mvn package
  
- name: Deploy
  run: kubectl apply -f k8s/
```

**Порядок**:
1. **Миграции** **БД** (expand) → **безопасно** (старый **код** **работает**).
2. **Деплой** **нового** **кода** (read **новую** **схему**).
3. **Миграции** **БД** (contract) → **удаление** **старой** **схемы** (после **деплоя**).

**Типовые проблемы**:
- **Два** **сервиса** **менеджат** **одну** **БД** → **конфликт** **миграций**.
- **Решение**: **database-per-service** (каждый **сервис** = **своя** БД).

### 6. Rollback strategies и их ограничения

**Rollback** — **откат** **миграции** **при** **ошибке**.

**Стратегии**:

**1. Forward fix** (рекомендуется):
- **Не** **откатывать**, а **исправлять** **вперёд** (новая **миграция**).
- **Плюс**: **просто**, **безопасно** (не **ломает** **metadata**).
- **Минус**: **данные** **из** **ошибочной** **миграции** **остаются** (нужно **очистить** **вручную**).

**2. Rollback script**:
- **Каждая** **миграция** **имеет** **undo** **скрипт** (Flyway: **`undo`** **файл**, Liquibase: **`generateRollback`**).
- **Плюс**: **быстро** **откатить**.
- **Минус**: **Undo** **не** **всегда** **возможно** (DROP **колонки** → **данные** **потеряны**).

**3. Snapshot + Restore**:
- **Создать** **snapshot** **БД** **до** **миграции**.
- **При** **ошибке**: **восстановить** **из** **snapshot**.
- **Плюс**: **полный** **откат**.
- **Минус**: **долго** (snapshot **больших** **БД** = **часы**), **не** **работает** **в** **prod** (downtime).

**Ограничения**:
- **DROP** **колонки/таблицы** → **данные** **потеряны** (undo **не** **возможно**).
- **ALTER** **типа** → **данные** **могут** **быть** **потеряны** (precision, scale).
- **Data migration** (UPDATE) → **undo** **не** **всегда** **возможно** (без **старых** **данных**).

**Best practice**:
- **Forward fix** **для** **большинства** **случаев** (новая **миграция**).
- **Rollback script** **для** **простых** **миграций** (ADD **колонки**, ADD **индекса**).
- **Snapshot + Restore** **только** **для** **dev/staging** (не **prod**).
- **Никогда** **не** **откатывать** **DROP** **в** **prod** (без **бэкапа**).

### 7. Migration testing

**Почему **нужно** **тестировать** **миграции**:
- **Ошибки** **в** **SQL** (синтаксис, **тип** **колонки**).
- **Проблемы** **с** **большими** **объёмами** **данных** (timeout, **locking**).
- **Нарушение** **целостности** (foreign key, **unique** **constraint**).

**Подходы**:

**1. Тестирование** **на** **dev/staging**:
- **Применить** **миграции** **на** **копии** **prod** **БД** (анонимизированной).
- **Проверить** **работу** **старого** **и** **нового** **кода**.

**2. Testcontainers**:
- **PostgreSQL** **в** **Docker** (Testcontainers).
- **Применить** **миграции** **на** **тестовой** **БД**.
- **Проверить** **схему** (таблицы, **индексы**, **constraints**).

```java
@Testcontainers
class MigrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Test
    void testMigrations() {
        Flyway flyway = Flyway.configure()
            .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
            .locations("classpath:db/migration")
            .load();
        flyway.migrate();
        
        // Проверить схему:
        // - Таблицы созданы
        // - Индексы созданы
        // - Данные целостны
    }
}
```

**3. Load testing**:
- **Применить** **миграции** **на** **БД** **с** **реальным** **объёмом** **данных** (10M+ строк).
- **Проверить** **время** **выполнения** (должно быть < 5 мин для prod).
- **Проверить** **locking** (не блокирует запись).

**4. CI/CD**:
- **Каждый** **PR** с **миграцией** → **автоматический** **тест** (Testcontainers).
- **Нельзя** **слить** **PR** без **успешного** **теста** **миграции**.

**Чек-лист**:
- [ ] **SQL** **синтаксис** (валиден).
- [ ] **Типы** **колонок** (правильные).
- [ ] **Индексы** (созданы).
- [ ] **Constraints** (foreign key, unique, not null).
- [ ] **Время** **выполнения** (< 5 мин для prod).
- [ ] **Locking** (не блокирует запись).
- [ ] **Старый** **код** **работает** (backwards-compatible).

### 8. Feature toggles для миграций данных

**Feature Toggle** — **переключатель** **функциональности** (ON/OFF) в **кодe**.

**Зачем** **в** **миграциях**:
- **Миграция** **данных** **долгая** (10M+ строк) → **нельзя** **делать** **в** **одном** **запуске**.
- **Нужно** **контролировать** **прогресс** (batch, **пауза**).
- **Нужно** **отключить** **миграцию** **при** **ошибке** (не **ломает** **приложение**).

**Пример**:
```java
@Service
public class DataMigrationService {
    
    @Value("${feature.data-migration.enabled}")
    private boolean migrationEnabled;
    
    @Scheduled(fixedDelay = 60000)  // каждые 60 сек
    public void migrate() {
        if (!migrationEnabled) return;
        
        int batchSize = 1000;
        int migrated;
        do {
            migrated = repo.migrateBatch(batchSize);
            log.info("Migrated {} rows", migrated);
        } while (migrated == batchSize);
    }
}
```

**Конфигурация**:
```yaml
# application.yml
feature:
  data-migration:
    enabled: false  # по умолчанию выключено
    batch-size: 1000
```

**Как использовать**:
1. **Деплой** **кода** **с** **миграцией** (toggle **OFF**).
2. **Включение** **toggle** (через **config** **service** или **env var**).
3. **Миграция** **выполняется** **фоновой** (batch, **не** **блокирует** **приложение**).
4. **Проверка** **прогресса** (logs, **metrics**).
5. **Выключение** **toggle** **после** **завершения**.

**Инструменты**:
- **Spring Cloud Config**: **удаление** **toggle** **через** **config** **server**.
- **Feature Flag** **сервис** (LaunchDarkly, Unleash, Flagsmith).
- **Environment variables** (Kubernetes ConfigMap).

**Best practice**:
- **По умолчанию** **OFF** (не **мигрирует** **до** **ручного** **включения**).
- **Batch** **обработка** (не **весь** **объём** **за** **один** **запуск**).
- **Метрики** (progress, **errors**, **duration**).
- **Мониторинг** (alerts при **ошибках**).
- **Выключение** **после** **завершения** (не **мигрирует** **бесконечно**).

### 9. Конфликты в multi-team migrations и как их решать

**Проблема**: несколько команд делают **migrations** одновременно → **конфликты** (версии, зависимости).

**Типичные конфликты**:
1. **Версионный**: две команды создали **V5** → **Flyway** не запускает второй.
2. **Зависимый**: команда A **меняет** таблицу, команда B **read** эту таблицу → **incompatibility**.
3. **Ordering**: команды A и B **меняют** одну таблицу в **разных** migrations → **race condition**.

**Решения**:
1. **Один owner** на **schema** (например: **DBA team** или **platform team**).
2. **Migrations в отдельном repo** (например: `schema-migrations`), **merge** через **PR**.
3. **Sequential versions**: **V1**, **V2**, **V3** — **без дублирования**.
4. **Migrations queue**: **CI** проверяет **конфликты** (например: `flyway:info` на **staging**).
5. **Feature toggle**: **new schema** в **toggle**, **old schema** — fallback.

**Пример**:
- **Team A**: `V5_add_column_orders.java` (добавляет **column**).
- **Team B**: `V5_add_column_users.java` (добавляет **column**).
- **Конфликт**: две **V5** → **Flyway** не запускает второй.
- **Решение**: **Team B** переименовывает в **V6**.

**Multi-module Spring Boot**:
- **Каждый модуль** имеет **Flyway** в **classpath**.
- **Flyway** запускает **migrations** от **всех модулей** (по **classpath scan**).
- **Conflict**: если два модуля имеют **V5** → **error**.
- **Решение**: **prefix** (например: `orders/V5_...`, `users/V6_...`).

**CI check**:
```yaml
- name: Flyway info
  run: mvn flyway:info -Dflyway.locations=classpath:db/migration
```

**Вывод**: **конфликты** в **multi-team** → **1 owner**, **отдельный repo**, **sequential versions**, **CI check**. **Multi-module**: **prefix** (например: `orders/V5`, `users/V6`). **Feature toggle** — **new/old schema** параллельно.

### 10. Migrations для distributed data (Kafka, event sourcing)

**Проблема**: **schema evolution** в **Kafka** / **event sourcing** → **consumers** читают **новые** **events** → **incompatibility**.

**Kafka Schema Registry**:
- **Schema**: **Avro**, **Protobuf**, **JSON Schema**.
- **Compatibility modes**:
  - **BACKWARD**: **new** schema может **читать** **old** data.
  - **FORWARD**: **old** schema может **читать** **new** data.
  - **FULL**: **BACKWARD** + **FORWARD**.
  - **NONE**: **без проверки** (опасно).
- **Registry**: **Avro/Protobuf** schema → **version** (1, 2, 3, ...).

**Пример (Avro)**:
```java
// V1: User { id: string, name: string }
// V2: User { id: string, name: string, email: string (new) }
// BACKWARD: V2 reader может читать V1 (email = null).
// FORWARD: V1 reader НЕ может читать V2 (не знает email).
```

**Event sourcing**:
- **Event**: immutable (не меняется после записи).
- **Event version**: **V1**, **V2**, **V3** (новые поля, **backward-compatible**).
- **Consumer**: **read** все версии (V1, V2, V3) → **project** в **current model**.
- **Migration**: **project** старые **events** (V1) → **new model** (V3).

**Пример**:
```java
// V1: OrderCreated { orderId, amount }
// V2: OrderCreated { orderId, amount, currency }  // new
// V3: OrderCreated { orderId, amount, currency, tax }  // new

// Consumer V3:
public OrderProjector handle(OrderCreatedV3 event) {
  return new Order(event.getOrderId(), event.getAmount(),
    event.getCurrency(), event.getTax());
}

// Consumer V2 (old):
public OrderProjector handle(OrderCreatedV2 event) {
  return new Order(event.getOrderId(), event.getAmount(),
    event.getCurrency(), null);  // tax = null
}
```

**Kafka consumer**:
- **Schema Registry** → **Avro/Protobuf** decoder.
- **Compatibility**: **BACKWARD** (default).
- **Upgrade**: **new** schema → **registry** → **consumers** обновляются **после**.

**Event migration**:
- **Replay**: **replay** все **events** (V1) → **new** **projector** (V3) → **new** **state**.
- **Time**: **1 день** (миллионы **events**).
- **Cutover**: **old** **projector** → **new** **projector** (после **replay**).

**Вывод**: **Kafka**: **Schema Registry** (**Avro/Protobuf**, **BACKWARD**). **Event sourcing**: **event version** (immutable, **backward-compatible**), **consumer** read **all** versions, **migration** = **replay** (все **events** → **new projector**). **Upgrade**: **new schema** → **registry** → **consumers**.

### 11. Data validation после migration

**Проблема**: **data migration** (например: **rename column**) → **data** могла **повредиться** (NULL, **type cast**).

**Data validation** = **check** **data** после **migration**:
1. **Count check**: **rows** до и после (должны **создавать**).
2. **Checksum**: **MD5/SHA** по **rows** (должны **создавать**).
3. **Spot check**: **N** **rows** вручную (например: **100**).
4. **Aggregate**: **SUM**, **AVG**, **MIN**, **MAX** (должны **создавать**).
5. **Referential integrity**: **FK** (должны **создавать**).

**Пример (PostgreSQL)**:
```sql
-- Before migration:
SELECT COUNT(*), SUM(amount) FROM orders;
-- Count: 1000000, Sum: 50000000

-- Migration:
ALTER TABLE orders RENAME COLUMN amount TO total;

-- After migration:
SELECT COUNT(*), SUM(total) FROM orders;
-- Count: 1000000, Sum: 50000000  (OK)
```

**Data validation (Flyway)**:
```java
// V5_validate_orders.java
public class V5_validate_orders extends BaseJavaMigration {
  @Override
  public void migrate(Context context) throws Exception {
    Connection conn = context.getConnection();
    Statement stmt = conn.createStatement();
    
    // Count check:
    ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM orders");
    rs.next();
    long count = rs.getLong(1);
    if (count != EXPECTED_COUNT) {
      throw new MigrationException("Count mismatch: " + count);
    }
    
    // Checksum:
    rs = stmt.executeQuery("SELECT MD5(CAST(AGGREGATE(*) AS TEXT)) FROM orders");
    rs.next();
    String checksum = rs.getString(1);
    if (!checksum.equals(EXPECTED_CHECKSUM)) {
      throw new MigrationException("Checksum mismatch: " + checksum);
    }
  }
}
```

**Automated**: **Deequ** (Spark), **Great Expectations** (Python), **dbt tests** (SQL).

**Вывод**: **data validation** после **migration** = **count check**, **checksum**, **spot check**, **aggregate**, **referential integrity**. **Automated**: **Deequ**, **Great Expectations**, **dbt tests**.

### 12. Как мигрировать данные между СУБД (PostgreSQL → MySQL)

**Проблема**: **миграция** **data** между **СУБД** (например: **PostgreSQL** → **MySQL**) → **schema** + **data** (миллионы **rows**).

**Подходы**:
1. **ETL** (Extract, Transform, Load): **script** (Python, **bpython**) → **copy** **data**.
2. **CDC** (Change Data Capture): **Debezium** (Kafka Connect) → **stream** **changes**.
3. **Replication**: **PostgreSQL** **logical replication** → **MySQL** (через **Debezium**).
4. **Migration tool**: **pgloader**, **mydumper**, **mysqldump**.

**Пример (ETL)**:
```python
# extract.py
import psycopg2, pymysql

src = psycopg2.connect("dbname=prod user=etl")
dst = pymysql.connect("host=mysql host=prod user=etl")

# Extract:
cur = src.cursor()
cur.execute("SELECT * FROM orders ORDER BY id")
rows = cur.fetchall()

# Transform:
transformed = [
  (r[0], r[1], r[2], r[3].isoformat())  # Date → ISO
  for r in rows
]

# Load:
dst_cur = dst.cursor()
dst_cur.executemany("INSERT INTO orders VALUES %s", transformed)
dst.commit()
```

**CDC (Debezium)**:
- **PostgreSQL** **WAL** → **Debezium** (Kafka Connect) → **Kafka** topic → **MySQL**.
- **Real-time**: **new** **rows** в **MySQL** в **real-time**.
- **Cutover**: **switch** **traffic** на **MySQL** (после **sync**).

**pgloader**:
```sql
LOAD FROM 'postgresql://prod/orders'
INTO 'mysql://prod/orders'
WITH method fast, cast id to bigint;
```

**Schema mapping**:
| PostgreSQL | MySQL |
|------------|-------|
| `SERIAL` | `AUTO_INCREMENT` |
| `TIMESTAMPTZ` | `DATETIME` (UTC) |
| `JSONB` | `JSON` |
| `ARRAY` | **не** **поддерживается** (JSON) |
| `UUID` | `CHAR(36)` |

**Вывод**: **ETL** (script), **CDC** (Debezium, **real-time**), **pgloader** (bulk). **Schema mapping**: **SERIAL** → **AUTO_INCREMENT**, **JSONB** → **JSON**, **ARRAY** → **JSON**. **Cutover**: **switch traffic** после **sync**.

### 13. Online schema change (gh-ost, pt-online-schema-change)

**Проблема**: **ALTER TABLE** на **большой** **таблице** (10 млн **rows**) → **lock** **длинный** → **downtime**.

**Online schema change** = **без lock** (или **short lock**):
1. **gh-ost** (GitHub): **copy** **data** в **new table** → **rename** (short lock).
2. **pt-online-schema-change** (Percona): **trigger** → **copy** → **rename**.

**gh-ost**:
```bash
gh-ost --database=prod \
  --alter="ADD COLUMN email VARCHAR(255)" \
  --cut-over=default \
  --critical-load="Query_latency.p95>100" \
  --execute
```
- **Copy**: **rows** по **chunks** (1000 **rows**).
- **Cutover**: **rename** (short lock, ~100ms).
- **Throttle**: **Query_latency** > **100ms** → **pause**.

**pt-online-schema-change**:
```bash
pt-online-schema-change \
  --alter="ADD COLUMN email VARCHAR(255)" \
  --execute \
  D=prod,t=orders,h=127.0.0.1
```
- **Trigger**: **AFTER INSERT**/**AFTER UPDATE**/**AFTER DELETE** → **copy** в **new table**.
- **Cutover**: **rename** (short lock).

**Сравнение**:
| Фича | gh-ost | pt-online-schema-change |
|------|--------|------------------------|
| Copy method | **WAL** (PostgreSQL) / **binlog** (MySQL) | **trigger** |
| Performance | **fast** (WAL/binlog) | **slow** (trigger) |
| Cutover | **rename** (short lock) | **rename** (short lock) |
| Throttle | **Query_latency** | **none** |
| PostgreSQL | **no** | **yes** |
| MySQL | **yes** | **yes** |

**Вывод**: **gh-ost** (**WAL/binlog**, **fast**, **throttle**), **pt-online-schema-change** (**trigger**, **slow**). **Cutover**: **rename** (short lock). **PostgreSQL**: **pt-online-schema-change**. **MySQL**: **gh-ost**.

### 14. Migrations в cloud (RDS, Aurora, Cloud SQL)

**Проблема**: **migrations** в **cloud** (RDS, Aurora, Cloud SQL) → **no SSH**, **no root**, **managed** **DB**.

**RDS/Aurora**:
- **No SSH**: **migrations** через **RDS Data API** (или **RDS Proxy**).
- **No root**: **Flyway** / **Liquibase** через **app** (не **DBA**).
- **Multi-AZ**: **primary** + **standby** → **migrations** на **primary** (auto **replication**).
- **Blue/green**: **RDS Blue/Green** (preview **migration**).

**Cloud SQL**:
- **No SSH**: **migrations** через **app** (не **DBA**).
- **Managed**: **Google** **migrations** (например: **Cloud SQL Migrate**).
- **Backup**: **automated** (по **retention**).

**Flyway + RDS**:
```yaml
# application.yml
spring:
  flyway:
    url: jdbc:aws-wrapper:rds://prod.abc123.us-east-1.rds.amazonaws.com:5432/app
    user: deploy
    password: ${DB_PASSWORD}
```
- **App** запускает **Flyway** (например: **CI** pipeline).
- **No root**: **deploy user** имеет **CREATE**, **ALTER**, **DROP** (но **no** **DROP DATABASE**).

**RDS Data API**:
```java
// RDS Data API (no JDBC):
RdsDataClient client = RdsDataClient.create(Region.US_EAST_1);
ExecuteStatementRequest req = ExecuteStatementRequest.builder()
  .resourceArn("arn:aws:rds:...")
  .secretArn("arn:aws:secretsmanager:...")
  .statement("SELECT * FROM orders")
  .build();
client.executeStatement(req);
```

**Blue/green (RDS)**:
1. **Create** **green** **DB** (copy **schema** + **data**).
2. **Apply** **migrations** на **green**.
3. **Cutover**: **switch** **traffic** на **green** (short downtime).
4. **Rollback**: **switch** back на **blue** (если **error**).

**Вывод**: **cloud** (RDS, Cloud SQL) → **no SSH**, **no root**, **migrations** через **app** (Flyway/Liquibase) или **RDS Data API**. **Multi-AZ**: **migrations** на **primary**. **Blue/green**: **preview** **migration**, **cutover** (short downtime).

### 15. Disaster recovery и migrations

**Проблема**: **disaster** (например: **DB crash**) → **migrations** **не завершены** → **inconsistent state**.

**DR** (Disaster Recovery) + **migrations**:
1. **Backup**: **automated** (например: **RDS** **snapshot** каждые **6 часов**).
2. **Recovery**: **restore** **backup** → **migrations** **re-apply** (idempotent).
3. **RPO** (Recovery Point Objective): **максимальная** **потеря** **data** (например: **15 мин**).
4. **RTO** (Recovery Time Objective): **максимальное** **время** **recovery** (например: **1 час**).

**Idempotent migrations**:
- **Flyway** / **Liquibase** — **idempotent** (если **migration** **уже** **applied**, **не** **re-apply**).
- **Data migration**: **idempotent** (например: **UPSERT**).

**Регламент**:
1. **DB crash** → **alert** (например: **Prometheus**).
2. **Restore** **backup** (например: **RDS** **restore**).
3. **Flyway**: **migrate** (re-apply **unapplied** **migrations**).
4. **Smoke test**: **check** **data** (например: **SELECT COUNT(*)**).
5. **Traffic**: **switch** на **restored** **DB**.

**РTO/RPO**:
| RTO | RPO | Уровен |
|-----|-----|--------|
| 1 час | 15 мин | **high** (production) |
| 6 часов | 1 час | **medium** (staging) |
| 24 часа | 6 часов | **low** (dev) |

**Вывод**: **DR** + **migrations** → **backup** (automated), **restore**, **idempotent** **migrations** (Flyway/Liquibase), **smoke test**. **RTO/RPO**: **high** (1 час / 15 мин), **medium** (6 часов / 1 час), **low** (24 часа / 6 часов).


### 16. Как мигрировать данные с сохранением консистентности

**Проблема:** **data migration** (например: **rename column**) → **data** могла **повредиться**.

**Подходы**:
1. **Expand-contract** — **добавить** **new column**, **заполнить**, **убрать** **old**.
2. **Dual-write** — **писать** в **обе** **таблицы** (временное).
3. **CDC** (Change Data Capture) — **Debezium** (Kafka Connect).

**Expand-contract**:
```sql
-- Step 1: Expand (add new column):
ALTER TABLE orders ADD COLUMN total DECIMAL(10,2);

-- Step 2: Backfill (copy data):
UPDATE orders SET total = amount;

-- Step 3: Code (use new column):
-- App code now uses total instead of amount

-- Step 4: Contract (drop old column):
ALTER TABLE orders DROP COLUMN amount;
```

**Dual-write**:
```java
// Write to both:
orderRepo.save(order);  // Old table
orderRepoV2.save(order);  // New table
```

**Вывод**: **data migration** → **expand-contract** (add, backfill, drop), **dual-write** (write to both), **CDC** (Debezium). **Consistency**: **backfill** + **dual-write** (temporary).

### 17. Как мигрировать данные в real-time (CDC)

**CDC** (Change Data Capture) = **захват** **изменений** **в real-time**.

**Debezium**:
```yaml
# Kafka Connect:
name: postgres-cdc
config:
  connector.class: io.debezium.connector.postgresql.PostgresConnector
  database.hostname: localhost
  database.port: 5432
  database.user: debezium
  database.password: dbz
  database.dbname: mydb
  database.server.name: mydb
  topic.prefix: mydb
```

**Flow**:
```
PostgreSQL (WAL) → Debezium (Kafka Connect) → Kafka topic → Consumer → New DB
```

**Use cases**:
- **Database migration** (PostgreSQL → MySQL)
- **Cache invalidation** (CDC → Redis)
- **Search indexing** (CDC → Elasticsearch)
- **Data lake** (CDC → S3)

**Вывод**: **CDC** = **захват** **изменений** **в real-time**. **Debezium**: **PostgreSQL** (WAL) → **Kafka** → **Consumer**. **Use cases**: **migration**, **cache invalidation**, **search indexing**, **data lake**.

### 18. Как мигрировать данные с минимальным downtime

**Проблема:** **data migration** (миллионы **rows**) → **downtime**.

**Подходы**:
1. **Online schema change** (gh-ost, pt-online-schema-change).
2. **Batch migration** (по **chunks**).
3. **CDC** (Debezium) — **real-time**.

**Batch migration**:
```sql
-- Migrate in batches:
INSERT INTO new_table (SELECT * FROM old_table WHERE id BETWEEN 1 AND 1000);
INSERT INTO new_table (SELECT * FROM old_table WHERE id BETWEEN 1001 AND 2000);
-- ...
```

**Cutover**:
```sql
-- Switch traffic (short downtime):
BEGIN;
RENAME TABLE old_table TO old_table_backup;
RENAME TABLE new_table TO old_table;
COMMIT;
```

**Вывод**: **data migration** (минимальный **downtime**) → **online schema change** (gh-ost), **batch migration** (chunks), **CDC** (Debezium). **Cutover**: **rename** (short downtime).

### 19. Как мигрировать данные между облачными СУБД

**Проблема:** **migration** между **облачными** **СУБД** (RDS → Aurora, Cloud SQL → Spanner).

**Инструменты**:
- **AWS DMS** (Database Migration Service)
- **Google DMS** (Database Migration Service)
- **Azure DMS** (Database Migration Service)
- **Debezium** (CDC)

**AWS DMS**:
```yaml
# AWS DMS:
# 1. Create replication instance
# 2. Create source endpoint (RDS)
# 3. Create target endpoint (Aurora)
# 4. Create replication task
# 5. Start migration
```

**Flow**:
```
RDS (source) → AWS DMS → Aurora (target)
```

**Вывод**: **migration** между **облачными** **СУБД** → **AWS DMS**, **Google DMS**, **Azure DMS**, **Debezium**. **Flow**: **source** → **DMS** → **target**.

### 20. Как мигрировать данные с проверкой целостности

**Проблема:** **data migration** → **data** могла **повредиться** (NULL, **type cast**).

**Проверки**:
1. **Count check** — **rows** до и после.
2. **Checksum** — **MD5/SHA** по **rows**.
3. **Aggregate** — **SUM**, **AVG**, **MIN**, **MAX**.
4. **Referential integrity** — **FK**.

**Пример**:
```sql
-- Before migration:
SELECT COUNT(*), SUM(amount) FROM orders;
-- Count: 1000000, Sum: 50000000

-- Migration:
ALTER TABLE orders RENAME COLUMN amount TO total;

-- After migration:
SELECT COUNT(*), SUM(total) FROM orders;
-- Count: 1000000, Sum: 50000000  (OK)
```

**Automated**:
- **Deequ** (Spark)
- **Great Expectations** (Python)
- **dbt tests** (SQL)

**Вывод**: **data migration** → **count check**, **checksum**, **aggregate**, **referential integrity**. **Automated**: **Deequ**, **Great Expectations**, **dbt tests**.
