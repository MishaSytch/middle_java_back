# Legacy Modernization

### 1. Monolith to microservices: Strangler Fig, Branch by Abstraction
**Strangler Fig Pattern:**
- Постепенная замена монолита микросервисами
- Каждый новый сервис «выращивается» рядом, перехватывая трафик
- Monolith постепенно «умирает», когда все функции перенесены

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

**Branch by Abstraction:**
- Введение абстракции (interface, adapter) в монолит
- Замена реализации через абстракцию
- Удаление legacy реализации

```java
// 1. Ввести абстракцию
public interface PaymentProcessor {
    PaymentResult process(PaymentRequest request);
}

// 2. Legacy реализация
public class LegacyPaymentProcessor implements PaymentProcessor {
    // old code
}

// 3. Новая реализация
public class ModernPaymentProcessor implements PaymentProcessor {
    // new code
}

// 4. Feature toggle
@Value("${payment.processor:legacy}")
String processorType;

PaymentProcessor processor = processorType.equals("legacy")
    ? new LegacyPaymentProcessor()
    : new ModernPaymentProcessor();
```

**Когда что:**
- **Strangler Fig**: большие монолиты, много независимых доменов
- **Branch by Abstraction**: конкретные компоненты, не весь монолит

**Практика:**
1. Идентифицировать bounded contexts (DDD)
2. Определить, что выносить первым (низкая сложность, high value)
3. Ввести API gateway
4. Постепенно выносить сервисы
5. Monolith → "dumb" router → удаление

### 2. Database migration: от shared DB к database-per-service
**Проблема:** монолит = одна БД. Микросервисы = каждая своя БД.

**Стратегии:**
1. **Database-per-service (целевая)**:
   - Каждый сервис — своя БД (PostgreSQL, MongoDB, Redis)
   - Сервисы не читают чужие БД напрямую (через API/events)
   - Data ownership: сервис владеет своей данными

2. **Shared database, separate schemas**:
   - Один Postgres, разные schemas per service
   - Проще миграция, но coupling остаётся
   - Когда: промежуточный этап

3. **CQRS + Event Sourcing**:
   - Write model (event store) + Read models (materialized views)
   - Каждый сервис — свой read model
   - Когда: high consistency, audit trail

**Миграция:**
```
Фаза 1: Shared DB, one schema
Фаза 2: Shared DB, separate schemas (per service)
Фаза 3: Database-per-service (physical separation)
Фаза 4: CQRS (если нужно)
```

**Практика:**
- Не переносить весь монолит сразу
- Выносить домены по одному
- Для каждого домена: вынести код + данные
- Data sync: CDC (Debezium), events, или dual-write (temporarily)

**Risks:**
- Distributed transactions (2PC, saga)
- Data consistency (eventual consistency)
- Data ownership (кто владелец данных?)

### 3. Big Ball of Mud refactoring: strategies
**Big Ball of Mud (BoM):**
- Код без архитектуры: тесно связанные модули, дублирование, нет границ
- Типичные симптомы:
  - Классы на 1000+ строк
  - Глобальные state (static fields, singletons)
  - Дублирование логики
  - Нет тестов

**Стратегии:**
1. **Characterization tests**:
   - Написать тесты для existing behavior (без изменения кода)
   - TDD: cover → refactor → verify
   - Tool: `jqwik` (property-based), `Pitest` (mutation)

2. **Boundary identification**:
   - Идентифицировать домены (DDD)
   - Ввести interfaces между доменами
   - Убрать прямые зависимости

3. **Dependency inversion**:
   - High-level modules не зависят от low-level
   - Ввести abstractions (interfaces)
   - Invert dependencies (DI)

4. **Extract methods/classes**:
   - Разбивать большие методы на мелкие
   - Выделять классы по ответственности
   - Use compiler hints (IDE refactoring)

5. **Strangler Fig (внутри BoM)**:
   - Постепенная замена legacy кода
   - Feature toggle для gradual rollout

**Практика:**
1. Написать characterization tests (cover existing behavior)
2. Идентифицировать boundaries (DDD)
3. Ввести abstractions (interfaces)
4. Refactor incrementally (small PRs)
5. Verify (tests, monitoring)

**Anti-patterns:**
- Big-bang rewrite (слишком рискованно)
- Refactoring без тестов (high risk)
- «Clean code» без boundaries (косметика)

### 4. Anti-Corruption Layer при интеграции с legacy
**Проблема:** новый сервис должен общаться с legacy API (устаревший контракт, strange semantics).

**Anti-Corruption Layer (ACL):**
- Изоляция legacy модели от domain модели
- Адаптер, который конвертирует legacy API → domain API

```java
// Legacy API (strange)
public class LegacyBankingApi {
    public Map<String, Object> getAccount(String accountId) {
        // returns: { "acc_no": "123", "bal": 100.50, "cust_id": 42 }
    }
}

// Domain model (clean)
public record Account(String id, BigDecimal balance, Customer customer) {}

// ACL (adapter)
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
- Legacy model не проникает в domain
- ACL — thin layer (только conversion, no business logic)
- Если legacy API меняется → менять ACL, не domain

**Когда:**
- Интеграция с legacy системами (banking, ERP, CRM)
- Third-party APIs (strange contracts)
- Migration period (dual system)

### 5. Incremental migration vs big-bang rewrite
**Big-bang rewrite:**
- Полная переписывание системы с нуля
- Все или ничего
- Риски: долгий таймлайн, нет value до завершения, high risk

**Incremental migration:**
- Постепенная замена, feature by feature
- Value на каждом этапе
- Lower risk (rollback possible)

**Сравнение:**
| | Big-bang | Incremental |
|---|---|---|
| Timeline | Долгий (6-24 months) | Короткие итерации (2-4 weeks) |
| Risk | High (все или ничего) | Low (rollback) |
| Value | Нет до завершения | На каждом этапе |
| Complexity | High (parallel systems) | Medium (gradual) |
| Team | Large (rewrite team) | Small (feature teams) |

**Когда big-bang:**
- Legacy code слишком тесно связан (невозможно разбить)
- Technology change (COBOL → Java)
- Business deadline (запуск нового продукта)

**Когда incremental:**
- Monolith с boundaries (DDD)
- Technology upgrade (Java 8 → Java 21)
- Architecture change (monolith → microservices)

**Практика 2026:**
- Incremental preferred (90% случаев)
- Big-bang только для extreme cases
- Hybrid: incremental + big-bang для отдельных компонентов

### 6. Characterization tests для legacy-кода
**Цель:** задокументировать existing behavior (чтобы refactoring не сломал).

**Подходы:**
1. **Record-and-replay**:
   - Записать input/output legacy кода
   - Play back, compare
   - Tool: `JMockit`, `Mockito`

2. **Property-based testing**:
   - Сгенерировать random inputs
   - Verify invariants (output valid, no exceptions)
   - Tool: `jqwik`
   ```java
   @Property
   void legacyCalculationShouldBeConsistent(
       @ForAll int a, @ForAll int b
   ) {
       int result = legacyCalculator.compute(a, b);
       assertThat(result).isEqualTo(a * b); // known behavior
   }
   ```

3. **Mutation testing**:
   - Внести mutations в legacy код
   - Проверить, что тесты ловят mutations
   - Tool: `Pitest`
   - Mutation score: % killed mutations

4. **Integration tests**:
   - Тесты на уровне API (не unit)
   - Verify end-to-end behavior
   - Tool: `RestAssured`, `Testcontainers`

**Практика:**
1. Идентифицировать critical paths (high value, high risk)
2. Написать characterization tests (cover existing behavior)
3. Refactor (small changes)
4. Verify (tests pass)
5. Add new tests (TDD для new features)

**Metrics:**
- Coverage: % legacy code covered by characterization tests
- Mutation score: % mutations killed
- Regression rate: % bugs caught by tests

### 7. Domain extraction из монолита
**Цель:** вынести bounded context из монолита в отдельный сервис.

**Процесс:**
1. **Identify bounded context** (DDD):
   - Domain model: entities, value objects, domain services
   - Boundaries: что входит, что не входит
   - Data ownership: какие таблицы/колонки

2. **Design API**:
   - Public API (REST/gRPC) для других сервисов
   - Events (outbox pattern) для async communication
   - Internal API (для monolith, temporarily)

3. **Extract code**:
   - Вынести domain model, services, repositories
   - Ввести adapter для legacy dependencies
   - Feature toggle (dual-run, gradually shift traffic)

4. **Migrate data**:
   - Database-per-service (physical separation)
   - Data sync: CDC (Debezium), events, dual-write
   - Verify data consistency (reconciliation)

5. **Deploy**:
   - Canary deployment (10% → 50% → 100%)
   - Monitoring: latency, error rate, data consistency
   - Rollback: revert traffic to monolith

**Практика:**
```
Monolith: [Orders] [Payments] [Users] [Inventory]

Выносим Payments:
1. Identify: Payment, Transaction, Refund (domain)
2. API: POST /payments, GET /payments/{id}
3. Events: payment.created, payment.refunded
4. Extract: PaymentService, PaymentRepository
5. Data: payments table → payments DB
6. Deploy: canary 10% → 100%
```

**Risks:**
- Distributed transactions (2PC, saga)
- Data consistency (eventual consistency)
- API design (breaking changes)
- Team coordination (monolith team + new service team)
