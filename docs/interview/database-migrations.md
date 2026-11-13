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
