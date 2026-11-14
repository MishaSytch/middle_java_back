# Legacy Modernization

### 1. Переход с монолита на микросервисы: Strangler Fig, Branch by Abstraction

**Strangler Fig Pattern (паттерн «strangler fig» — strangler-фига, дерево, которое обвивает и постепенно заменяет host-дерево):**
- Постепенная замена монолита микросервисами.
- Каждый новый сервис «выращивается» рядом с монолитом, перехватывая трафик (через API gateway).
- Monolith (монолит) постепенно «умирает», когда все функции перенесены.

```
Фаза 1: Monolith + API Gateway
  Gateway → Monolith (все запросы)

Фаза 2: Monolith + Service 1
  Gateway → Service 1 (новые фичи)
  Gateway → Monolith (остальное)

Фаза 3: Monolith + Service 1 + Service 2
  Gateway → Service 1
  Gateway → Service 2
  Gateway → Monolith (остаток)

Фаза N: Service 1 + Service 2 + ... (Monolith удалён)
```

**Branch by Abstraction (ветвление через абстракцию — введение интерфейса, чтобы заменить реализацию без изменения вызывающего кода):**
- Введение абстракции (interface, adapter) в монолит.
- Замена реализации через абстракцию (feature toggle — переключатель, который определяет, какая реализация используется).
- Удаление legacy (устаревшей) реализации.

```java
// 1. Ввести абстракцию
public interface PaymentProcessor {
    PaymentResult process(PaymentRequest request);
}

// 2. Legacy реализация (старый код)
public class LegacyPaymentProcessor implements PaymentProcessor {
    // old code
}

// 3. Новая реализация
public class ModernPaymentProcessor implements PaymentProcessor {
    // new code
}

// 4. Feature toggle (переключатель — конфигурация определяет, какую реализацию использовать)
@Value("${payment.processor:legacy}")
String processorType;

PaymentProcessor processor = processorType.equals("legacy")
    ? new LegacyPaymentProcessor()
    : new ModernPaymentProcessor();
```

**Когда что:**
- **Strangler Fig**: большие монолиты, много независимых доменов (business domains — бизнес-доменов).
- **Branch by Abstraction**: конкретные компоненты внутри монолита, а не весь монолит сразу.

**Практика:**
1. Идентифицировать bounded contexts (ограниченные контексты — границы бизнес-доменов, DDD — Domain-Driven Design).
2. Определить, что выносить первым (низкая сложность, high value — высокая ценность для бизнеса).
3. Ввести API gateway (шлюз — единая точка входа, которая маршрутизирует запросы).
4. Постепенно выносить сервисы.
5. Monolith → «dumb» router (глупый роутер — просто перенаправляет, без логики) → удаление.

### 2. Миграция базы данных: от shared DB (общей БД) к database-per-service (БД на сервис)

**Проблема:** монолит = одна общая БД (shared database). Микросервисы = каждая должна иметь свою БД (data ownership — принцип, что сервис владеет своими данными и никто другой не может читать/писать его БД напрямую).

**Стратегии:**

1. **Database-per-service (БД на сервис — целевая архитектура):**
   - Каждый сервис — своя БД (PostgreSQL, MongoDB, Redis).
   - Сервисы не читают чужие БД напрямую (только через API или events — события).
   - **Data ownership** (власть над данными): сервис владеет своими данными, сам определяет схему и индексы.

2. **Shared database, separate schemas (общая БД, отдельные схемы):**
   - Один Postgres, разные schemas (схемы — пространства имён) per service.
   - Проще миграция (данные уже в одном месте), но coupling (связанность) остаётся — если один сервис упадёт, другие тоже (общая БД — единая точка отказа).
   - Когда: промежуточный этап (когда пока не готовы на физическое разделение).

3. **CQRS + Event Sourcing (Command Query Responsibility Segregation + Event Sourcing):**
   - **CQRS** (разделение команд и запросов): write model (модель записи — event store — хранилище событий) + read models (модели чтения — materialized views — материализованные представления, которые пересчитываются из событий).
   - **Event Sourcing** (хранение событий): вместо хранения текущих состояний хранится последовательность событий; текущее состояние вычисляется из событий.
   - Каждый сервис — свой read model.
   - Когда: high consistency (высокая консистентность), audit trail (аудит — полная история изменений).

**Миграция (поэтапно):**
```
Фаза 1: Shared DB, one schema (общая БД, одна схема)
Фаза 2: Shared DB, separate schemas (общая БД, отдельные схемы per service)
Фаза 3: Database-per-service (физическое разделение — отдельные инстансы БД)
Фаза 4: CQRS (если нужно)
```

**Практика:**
- Не переносить весь монолит сразу.
- Выносить домены (bounded contexts) по одному.
- Для каждого домена: вынести код + данные.
- **Data sync** (синхронизация данных): CDC (Debezium — инструмент для CDC), events (события), или dual-write (двойная запись — временно писать в обе БД).

**Risks (риски):**
- **Distributed transactions** (распределённые транзакции): 2PC (Two-Phase Commit — двухфазное согласование — все участники подтверждают, потом все коммитят), saga (сaga — последовательность локальных транзакций с компенсацией).
- **Data consistency** (консистентность данных): eventual consistency (конечная консистентность — данные «сходятся» через некоторое время).
- **Data ownership** (власть над данными): кто владелец данных? (должен быть один сервис, а не все).

### 3. Refactoring «Big Ball of Mud» (комок грязи): стратегии

**Big Ball of Mud (BoM — «комок грязи» — код без архитектуры):**
- Тесно связанные модули, дублирование, нет границ между компонентами.
- Типичные симптомы:
  - Классы на 1000+ строк.
  - Глобальные state (состояния — static fields, singletons — одиночные объекты).
  - Дублирование логики (одна и та же функция в разных местах).
  - Нет тестов.

**Стратегии:**

1. **Characterization tests (характеризующие тесты — тесты, фиксирующие текущее поведение кода):**
   - Написать тесты для existing behavior (текущего поведения — без изменения кода).
   - **TDD** (Test-Driven Development — тестирование с упреждением): cover (покрыть) → refactor (рефакторинг) → verify (верифицировать).
   - **Tools** (инструменты): `jqwik` (property-based testing — тестирование на основе свойств), `Pitest` (mutation testing — мутационное тестирование).

2. **Boundary identification (идентификация границ):**
   - Идентифицировать домены (DDD — Domain-Driven Design).
   - Ввести interfaces (интерфейсы) между доменами.
   - Убрать прямые зависимости (direct dependencies — одна часть кода напрямую вызывает другую).

3. **Dependency inversion (инверсия зависимостей):**
   - **High-level** (высокоуровневые) modules не зависят от **low-level** (низкоуровневых) — наоборот.
   - Ввести abstractions (абстракции — интерфейсы).
   - Invert dependencies (DI — Dependency Injection — внедрение зависимостей).

4. **Extract methods/classes (выделение методов/классов):**
   - Разбивать большие методы на мелкие.
   - Выделять классы по ответственности (Single Responsibility — одна ответственность на класс).
   - Использовать подсказки IDE (refactoring tools).

5. **Strangler Fig (внутри BoM):**
   - Постепенная замена legacy кода.
   - **Feature toggle** (переключатель фич) для **gradual rollout** (постепенное развёртывание).

**Практика:**
1. Написать characterization tests (покрыть текущее поведение).
2. Идентифицировать boundaries (границы доменов, DDD).
3. Ввести abstractions (интерфейсы).
4. Refactor incrementally (рефакторинг инкрементально — небольшими PR).
5. Verify (верифицировать — тесты, monitoring — мониторинг).

**Anti-patterns (антипаттерны — что НЕ делать):**
- **Big-bang rewrite** (полная переписывание с нуля — слишком рискованно, долгий таймлайн, нет value до завершения).
- Refactoring без тестов (high risk — высокий риск сломать).
- «Clean code» (чистый код) без boundaries (границ) — косметика, не решает проблему связанности.

### 4. Anti-Corruption Layer (ACL — слой антикоррупции) при интеграции с legacy

**Проблема:** новый сервис должен общаться с legacy API (устаревший контракт, strange semantics — странные семантики — непонятные соглашения, например, сокращения полей, особые форматы).

**Anti-Corruption Layer (ACL — слой антикоррупции):**
- Изоляция legacy модели от domain модели (доменной модели — бизнес-логики).
- **Адаптер** (adapter — компонент, который конвертирует один интерфейс в другой), который конвертирует legacy API → domain API.

```java
// Legacy API (strange — странные имена полей, Map вместо типизированных объектов)
public class LegacyBankingApi {
    public Map<String, Object> getAccount(String accountId) {
        // returns: { "acc_no": "123", "bal": 100.50, "cust_id": 42 }
    }
}

// Domain model (clean — чистая доменная модель)
public record Account(String id, BigDecimal balance, Customer customer) {}

// ACL (adapter — адаптер)
public class LegacyBankingAdapter implements BankingProvider {
    private final LegacyBankingApi legacyApi;

    @Override
    public Account getAccount(AccountId id) {
        Map<String, Object> raw = legacyApi.getAccount(id.value());
        return new Account(
            (String) raw.get("acc_no"),
            new BigDecimal(String.valueOf(raw.get("bal"))),
            new Customer((Integer) raw.get("cust_id"))
        );
    }
}
```

**Правила:**
- Legacy model не проникает в domain (доменную модель).
- ACL — **thin layer** (тонкий слой — только conversion, no business logic — без бизнес-логики).
- Если legacy API меняется → менять ACL (адаптер), а не domain (доменную модель).

**Когда применять:**
- Интеграция с legacy системами (banking — банковские, ERP — enterprise resource planning, CRM — customer relationship management).
- **Third-party** (сторонние) APIs (strange contracts — странные контракты).
- Migration period (период миграции — dual system — две системы работают параллельно).

### 5. Incremental migration (инкрементальная миграция) vs big-bang rewrite (полная переписывание)

**Big-bang rewrite (полная переписывание с нуля):**
- Полная переписывание системы с нуля.
- Все или ничего (all-or-nothing).
- Риски: долгий таймлайн (timeline — сроки), нет value (ценности) до завершения, high risk (высокий риск).

**Incremental migration (инкрементальная миграция — постепенная замена):**
- Постепенная замена, feature by feature (по фиче).
- Value на каждом этапе (каждый шаг даёт результат).
- Lower risk (меньший риск — rollback possible — откат возможен).

**Сравнение:**

| | Big-bang | Incremental |
|---|---|---|
| **Timeline** (сроки) | Долгий (6-24 months) | Короткие итерации (2-4 weeks) |
| **Risk** (риск) | High (все или ничего) | Low (rollback) |
| **Value** (ценность) | Нет до завершения | На каждом этапе |
| **Complexity** (сложность) | High (parallel systems — параллельные системы) | Medium (gradual — постепенное) |
| **Team** (команда) | Large (rewrite team — команда переписывания) | Small (feature teams — команды фич) |

**Когда big-bang:**
- Legacy code слишком тесно связан (невозможно разбить на части).
- Technology change (смена технологии — COBOL → Java).
- Business deadline (бизнес-дедлайн — запуск нового продукта).

**Когда incremental:**
- Monolith с boundaries (границами — DDD).
- Technology upgrade (апгрейд технологии — Java 8 → Java 21).
- Architecture change (смена архитектуры — monolith → microservices).

**Практика 2026:**
- **Incremental preferred** (инкрементальная предпочтительна — 90% случаев).
- Big-bang только для extreme cases (экстремальных случаев).
- **Hybrid** (гибрид): incremental + big-bang для отдельных компонентов.

### 6. Characterization tests (характеризующие тесты) для legacy-кода

**Цель:** задокументировать existing behavior (текущее поведение — чтобы refactoring не сломал).

**Подходы:**

1. **Record-and-replay (запись и воспроизведение):**
   - Записать input/output legacy кода.
   - Play back (воспроизвести), compare (сравнить).
   - **Tools** (инструменты): `JMockit`, `Mockito`.

2. **Property-based testing (тестирование на основе свойств):**
   - Сгенерировать random inputs (случайные входные данные).
   - Verify invariants (проверить инварианты — output valid, no exceptions — выход валиден, нет исключений).
   - **Tool**: `jqwik`
   ```java
   @Property
   void legacyCalculationShouldBeConsistent(
       @ForAll int a, @ForAll int b
   ) {
       int result = legacyCalculator.compute(a, b);
       assertThat(result).isEqualTo(a * b); // known behavior (известное поведение)
   }
   ```

3. **Mutation testing (мутационное тестирование):**
   - Внести mutations (мутации — намеренные изменения кода) в legacy код.
   - Проверить, что тесты ловят mutations (тесты обнаруживают изменения).
   - **Tool**: `Pitest`
   - **Mutation score** (мутационный счёт): % killed mutations (уничтоженных мутаций — тесты должны «убивать» мутации, чтобы быть эффективными).

4. **Integration tests (интеграционные тесты):**
   - Тесты на уровне API (не unit — не на уровне отдельного класса).
   - Verify end-to-end behavior (проверить сквозное поведение — от входа до выхода).
   - **Tools**: `RestAssured`, `Testcontainers`.

**Практика:**
1. Идентифицировать critical paths (критические пути — high value, high risk).
2. Написать characterization tests (покрыть текущее поведение).
3. Refactor (рефакторинг — small changes — небольшие изменения).
4. Verify (верифицировать — tests pass — тесты проходят).
5. Add new tests (добавить новые тесты — TDD для new features — новых фич).

**Metrics (метрики):**
- **Coverage** (покрытие): % legacy code covered by characterization tests (доля legacy-кода, покрытого тестами).
- **Mutation score** (мутационный счёт): % mutations killed (доля уничтоженных мутаций).
- **Regression rate** (скорость регрессии): % bugs caught by tests (доля багов, пойманных тестами).

### 7. Domain extraction (выделение домена) из монолита

**Цель:** вынести bounded context (ограниченный контекст) из монолита в отдельный сервис.

**Процесс:**

1. **Identify bounded context (идентификация ограниченного контекста, DDD):**
   - **Domain model** (доменная модель): entities (сущности), value objects (объекты значения), domain services (доменные сервисы).
   - **Boundaries** (границы): что входит, что не входит.
   - **Data ownership** (власть над данными): какие таблицы/колонки.

2. **Design API (проектирование API):**
   - **Public API** (публичный API — REST/gRPC) для других сервисов.
   - **Events** (события — outbox pattern — паттерн «отправочное письмо»: события пишутся в таблицу outbox и асинхронно отправляются в очередь) для async communication (асинхронной коммуникации).
   - **Internal API** (внутренний API — для monolith, temporarily — временно).

3. **Extract code (выделение кода):**
   - Вынести domain model, services, repositories (доменную модель, сервисы, репозитории).
   - Ввести adapter (адаптер) для legacy dependencies (устаревших зависимостей).
   - **Feature toggle** (переключатель фич — dual-run — параллельный запуск, gradually shift traffic — постепенно перенаправить трафик).

4. **Migrate data (миграция данных):**
   - Database-per-service (физическое разделение).
   - **Data sync** (синхронизация данных): CDC (Debezium), events (события), dual-write (двойная запись).
   - Verify data consistency (проверить консистентность данных — reconciliation — сверка).

5. **Deploy (деплой):**
   - **Canary deployment** (канареечный деплой — развёртывание на части трафика: 10% → 50% → 100%).
   - **Monitoring** (мониторинг): latency (задержка), error rate (доля ошибок), data consistency.
   - **Rollback** (откат): revert traffic to monolith (вернуть трафик на монолит).

**Практика:**
```
Monolith: [Orders] [Payments] [Users] [Inventory]

Выносим Payments (оплаты):
1. Identify: Payment, Transaction, Refund (domain)
2. API: POST /payments, GET /payments/{id}
3. Events: payment.created, payment.refunded
4. Extract: PaymentService, PaymentRepository
5. Data: payments table → payments DB
6. Deploy: canary 10% → 100%
```

**Risks (риски):**
- **Distributed transactions** (распределённые транзакции): 2PC (двухфазное согласование), saga (сaga — последовательность локальных транзакций с компенсацией).
- **Data consistency** (консистентность данных): eventual consistency (конечная консистентность).
- **API design** (проектирование API): breaking changes (ломающие изменения — изменения контракта, которые требуют обновления клиентов).
- **Team coordination** (координация команд): monolith team (команда монолита) + new service team (команда нового сервиса).
