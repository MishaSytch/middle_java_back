# Глава 13. Транзакции: от ACID до `UnexpectedRollbackException`

> **Уровень:** junior → middle+ (ключевая глава книги)
> **Время:** 5–6 часов
> **Цель:** понимать, что реально делает `@Transactional`, уметь выбирать propagation и isolation, диагностировать «транзакция не работает» и проектировать консистентность за пределами одной БД.

## 13.1. ACID и что из него даёт Spring

* **A**tomicity — всё или ничего.
* **C**onsistency — переход между корректными состояниями (обеспечивают constraints + бизнес-логика).
* **I**solation — параллельные транзакции не мешают друг другу (уровень задаётся БД).
* **D**urability — закоммиченное не потеряется.

**Spring не реализует ACID** — его реализует БД. Spring делает три вещи: (1)统一管理 границ (`begin/commit/rollback`), (2) привязывает ресурсы (соединение, `EntityManager`) к потоку, (3) транслирует исключения. Всё.

## 13.2. Аномалии и уровни изоляции

| Аномалия | Что происходит |
|---|---|
| Dirty read | читаем незакоммиченные данные другой транзакции |
| Non-repeatable read | повторное чтение той же строки даёт другое значение |
| Phantom read | повторный запрос по условию даёт новый набор строк |
| Lost update | два «прочитал-изменил-записал» затирают друг друга |
| Write skew | обе транзакции читают согласованный набор и пишут в разные строки, ломая инвариант |

| Уровень | Dirty | Non-repeatable | Phantom |
|---|---|---|---|
| READ_UNCOMMITTED | ✔ | ✔ | ✔ |
| READ_COMMITTED | ✘ | ✔ | ✔ |
| REPEATABLE_READ | ✘ | ✘ | ✔ (в стандарте) |
| SERIALIZABLE | ✘ | ✘ | ✘ |

**Реальность вендоров (это спрашивают):**
* **PostgreSQL**: дефолт `READ_COMMITTED`; `READ_UNCOMMITTED` фактически = `READ_COMMITTED`; `REPEATABLE_READ` — снапшотная изоляция (нет фантомов, но возможен write skew); `SERIALIZABLE` — SSI, ловит аномалии и бросает `40001 serialization_failure` → **приложение обязано уметь retry**.
* **MySQL/InnoDB**: дефолт `REPEATABLE_READ` с gap-локами; `SERIALIZABLE` превращает чтения в блокирующие.
* Вывод: **не полагайтесь на изоляцию для бизнес-инвариантов**. Используйте явные блокировки, `@Version`, уникальные индексы и атомарные UPDATE.

```java
@Transactional(isolation = Isolation.REPEATABLE_READ)   // применять точечно и осознанно
public Report build() { ... }
```

## 13.3. Абстракция Spring

```text
PlatformTransactionManager
 ├── DataSourceTransactionManager        (JDBC)
 ├── JpaTransactionManager               (JPA/Hibernate; JDBC-код на том же DataSource тоже участвует)
 ├── JtaTransactionManager               (XA — почти всегда не нужен)
 └── ReactiveTransactionManager          (WebFlux/R2DBC)

TransactionDefinition: propagation, isolation, timeout, readOnly, name
TransactionStatus:     isNewTransaction, setRollbackOnly, isCompleted, createSavepoint
```

Программное управление (там, где аннотация неудобна):
```java
@Service
@RequiredArgsConstructor
class ImportService {
    private final TransactionTemplate tx;      // Boot создаёт сам при наличии менеджера

    void importAll(List<Row> rows) {
        for (List<Row> chunk : Lists.partition(rows, 500)) {
            tx.executeWithoutResult(status -> {
                try { repo.saveAll(chunk); }
                catch (DataIntegrityViolationException e) { status.setRollbackOnly(); }
            });
        }
    }
}
```
🎯 `TransactionTemplate` — правильный инструмент для «транзакция на чанк», «транзакция внутри цикла», «нужен явный контроль границ». Аннотация на методе не умеет «частичных» границ.

## 13.4. `@Transactional`: полный разбор атрибутов

```java
@Transactional(
    propagation = Propagation.REQUIRED,
    isolation = Isolation.DEFAULT,
    timeout = 5,                                  // секунды
    readOnly = false,
    rollbackFor = {BusinessException.class},       //.checked-исключения тоже откатывают
    noRollbackFor = {NotificationException.class},
    transactionManager = "jpaTransactionManager"
)
public TaskId create(CreateTaskRequest req) { ... }
```

### Что реально делает `readOnly = true`
1. Ставит `FlushMode.MANUAL` у Hibernate → **нет dirty checking и нет flush** (экономия CPU/памяти на чтении).
2. Передаёт hint драйверу/БД (`Connection.setReadOnly(true)`); PostgreSQL может использовать это для оптимизаций и для роутинга на реплику.
3. **Не** запрещает запись физически во всех БД — это подсказка, а не защита. Полагаться на «readOnly защитит от записи» нельзя.

Правило: **все читающие сервисные методы — `readOnly = true`**. Идеально — на уровне класса:
```java
@Service
@Transactional(readOnly = true)
public class TaskService {
    public TaskView find(long id) { ... }                  // readOnly
    @Transactional public TaskId create(...) { ... }       // переопределяет на write
}
```

### Правила откатa — источник половины инцидентов
По умолчанию откат **только** на `RuntimeException` и `Error`. Checked-исключение → **коммит**.

```java
@Transactional
public void pay() throws IOException {
    repo.debit(...);
    externalCall();          // бросил IOException (checked) → транзакция ЗАКОММИТИТСЯ! 💥
}
```
Лечение: `@Transactional(rollbackFor = Exception.class)` или обернуть в unchecked.

🪤 **Второй капкан — проглоченное исключение:**
```java
@Transactional
public void process() {
    try { risky(); }                       // risky — @Transactional(REQUIRED), бросила RuntimeException
    catch (Exception e) { log.warn("...", e); }   // «съели», но inner пометил tx rollback-only
    repo.save(something);
}                                          // → UnexpectedRollbackException на коммите
```
Причина: внутренняя транзакция **та же самая** (REQUIRED), она пометила `rollbackOnly`. Внешний метод думает, что всё хорошо, а коммит невозможен. Решения: не глотать, либо `REQUIRES_NEW` для внутренней операции, либо не делать её транзакционной.

## 13.5. Propagation: все семь, с примерами

| Propagation | Есть tx | Нет tx |
|---|---|---|
| `REQUIRED` (дефолт) | присоединиться | создать |
| `REQUIRES_NEW` | приостановить внешнюю, создать новую | создать |
| `NESTED` | savepoint внутри текущей | создать |
| `SUPPORTS` | присоединиться | работать без tx |
| `NOT_SUPPORTED` | приостановить | работать без tx |
| `MANDATORY` | присоединиться | **исключение** |
| `NEVER` | **исключение** | работать без tx |

```java
// REQUIRED: одна транзакция на весь сценарий — 95 % случаев
@Transactional public void checkout(Cart cart) { orders.create(cart); payments.charge(cart); }

// REQUIRES_NEW: аудит должен сохраниться, даже если основная операция откатится
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void writeAudit(AuditEvent e) { auditRepo.save(e); }

// NESTED: частичный откат внутри большой операции (savepoint; работает не со всеми менеджерами)
@Transactional(propagation = Propagation.NESTED)
public void importRow(Row r) { ... }

// MANDATORY: метод обязан вызываться в транзакции — защита от неправильного использования
@Transactional(propagation = Propagation.MANDATORY)
public void applyDiscount(Order o) { ... }
```

🪤 **Грабли `REQUIRES_NEW`:**
* Берёт **второе соединение** из пула. При `maximum-pool-size=2` и вложенных вызовах получите deadlock пула.
* Внутренняя транзакция коммитится **независимо** → «дырка» в атомарности: внешняя откатится, внутренняя — нет. Это осознанный выбор (аудит, счётчики), а не баг.
* Внутренняя не видит незакоммиченных изменений внешней (при READ_COMMITTED). Классический баг: «сохранили сущность, вызвали REQUIRES_NEW-метод, он её не нашёл».

🪤 **`NESTED`** поддерживается `DataSourceTransactionManager` (savepoints), но **не** `JpaTransactionManager` в общем случае. Не используйте «на всякий случай».

## 13.6. ⚙️ Под капотом: путь вызова `@Transactional`-метода

```text
proxy.create(req)
 └─ TransactionInterceptor.invoke(invocation)
     └─ TransactionAspectSupport.invokeWithinTransaction
         ├─ TransactionAttributeSource.getTransactionAttribute(method, targetClass)   // читает аннотацию
         ├─ determineTransactionManager(...)
         ├─ createTransactionIfNecessary → tm.getTransaction(definition)
         │    └─ AbstractPlatformTransactionManager
         │        ├─ doGetTransaction(): берёт ConnectionHolder/EntityManagerHolder из
         │        │      TransactionSynchronizationManager (ThreadLocal!)
         │        ├─ isExistingTransaction? → handleExistingTransaction (propagation!)
         │        │      REQUIRED → join; REQUIRES_NEW → suspend + doBegin; NESTED → savepoint
         │        └─ doBegin(): con.setAutoCommit(false), bind ресурс в ThreadLocal
         ├─ retVal = invocation.proceedWithInvocation()      // ваш метод
         ├─ catch → completeTransactionAfterThrowing: rollbackOn(ex)? rollback : commit
         └─ commitTransactionAfterReturning → tm.commit(status)
              ├─ triggerBeforeCommit / triggerBeforeCompletion (сюда встаёт @TransactionalEventListener)
              ├─ doCommit()
              ├─ triggerAfterCommit / triggerAfterCompletion
              └─ cleanupAfterCompletion: unbind ресурсов, resume приостановленной tx
```

**Три следствия, которые надо знать наизусть:**
1. Ресурсы живут в **`ThreadLocal`** → смена потока (`@Async`, `CompletableFuture`, `parallelStream`) = **другая транзакция** (или её отсутствие).
2. Прокси создаётся `BeanPostProcessor` **после** `@PostConstruct` → в `@PostConstruct` транзакций нет.
3. `@Transactional` работает через **вызов на прокси** → self-invocation не перехватывается.

## 13.7. «Транзакция не работает»: полный чек-лист причин

| Причина | Симптом | Лечение |
|---|---|---|
| Self-invocation | изменения не сохраняются / нет откатa | вынести в другой бин / `ObjectProvider` self |
| `private`/`final`/`static` метод | аннотация игнорируется | public non-final |
| Класс не бин (`new`) | нет прокси | сделать бином |
| Checked-исключение | закоммитилось вместо откатa | `rollbackFor` |
| Исключение проглочено | нет откатa или `UnexpectedRollbackException` | не глотать / `REQUIRES_NEW` |
| `@Async` | данные не видны, отдельная tx | передавать id, открывать tx в async-методе |
| Другой поток | `LazyInitializationException`, нет tx | явные границы |
| Другой `DataSource`/менеджер | изменения в другой БД не откатываются | указать `transactionManager`, или outbox |
| `@PostConstruct` | нет tx | `ApplicationReadyEvent` |
| `propagation=NOT_SUPPORTED/SUPPORTS` | нет tx | проверить атрибут |
| Бин «not eligible for auto-proxying» | нет прокси вообще | убрать раннюю зависимость от BFPP |
| MyISAM/DDL в MySQL | нет откатa | InnoDB; DDL не транзакционен в MySQL |

Проверка «есть ли транзакция прямо сейчас»:
```java
boolean active = TransactionSynchronizationManager.isActualTransactionActive();
String name = TransactionSynchronizationManager.getCurrentTransactionName();
boolean ro = TransactionSynchronizationManager.isCurrentTransactionReadOnly();
```
🎯 Это первый инструмент диагностики. Добавьте временный лог в спорный метод — и вопрос закрыт.

## 13.8. Блокировки и потерянные обновления

### Lost update: воспроизведение
```java
// T1 и T2 одновременно:
Task t = repo.findById(id).orElseThrow();   // оба прочитали version=1, counter=5
t.setCounter(t.getCounter() + 1);           // оба вычислили 6
repo.save(t);                               // оба записали 6 → потеряли одно увеличение
```

**Решение 1 — оптимистическая блокировка (`@Version`)**:
```java
@Entity class Task {
    @Id @GeneratedValue Long id;
    @Version long version;      // Hibernate добавляет WHERE version = ? и инкрементит
    int counter;
}
```
При конфликте — `OptimisticLockingFailureException`. **Обязательно** добавьте retry на уровне выше транзакции:
```java
@Retryable(includes = OptimisticLockingFailureException.class, maxAttempts = 3, delay = 50)  // [4.x] core
public void incrementWithRetry(long id) { txTemplate.executeWithoutResult(s -> repo.increment(id)); }
```
🪤 Retry **не должен** быть внутри той же транзакции: откатившаяся tx не «оживает».Retry-обёртка снаружи, транзакция внутри.

**Решение 2 — атомарный UPDATE** (лучший вариант для счётчиков):
```java
@Modifying
@Query("update Task t set t.counter = t.counter + 1 where t.id = :id")
int increment(@Param("id") long id);
```

**Решение 3 — пессимистическая блокировка**:
```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@QueryHints(@QueryHint(name = "jakarta.persistence.lock.timeout", value = "3000"))
@Query("select t from Task t where t.id = :id")
Optional<Task> findByIdForUpdate(@Param("id") long id);
```
`SELECT ... FOR UPDATE` — держим строку до конца tx. Обязательно таймаут, иначе повиснете. Следите за **порядком захвата** блокировок (одинаковый во всём коде) — иначе deadlock.

| | Optimistic | Pessimistic |
|---|---|---|
| Конфликты редки | ✅ идеально | ❌ лишние блокировки |
| Конфликты часты | ❌ много retry | ✅ лучше |
| Долгие операции/внешние вызовы | ✅ | ❌ нельзя |
| Риск deadlock | нет | есть |

## 13.9. Транзакции и внешние эффекты

**Золотое правило: внутри транзакции — только работа с БД.** Никаких HTTP, Kafka, отправки писем, `Thread.sleep`. Причины: соединение занято, время растёт, а откатить внешний эффект невозможно.

```java
// ❌ плохо
@Transactional
public void create(req) {
    repo.save(task);
    mailClient.send(...);        // 2 секунды в транзакции; при откате письмо уже ушло
}

// ✅ хорошо: событие после коммита
@Transactional
public TaskId create(req) {
    var t = repo.save(task);
    events.publishEvent(new TaskCreated(t.id()));
    return t.id();
}

@TransactionalEventListener(phase = AFTER_COMMIT)
@Async
public void onCreated(TaskCreated e) { mailClient.send(...); }
```

🎯 **Но и это не гарантия**: между коммитом и отправкой процесс может умереть. Промышленное решение — **transactional outbox**:
```sql
CREATE TABLE outbox (
  id uuid PRIMARY KEY, aggregate_type text, aggregate_id text,
  event_type text, payload jsonb, created_at timestamptz DEFAULT now(), published_at timestamptz
);
```
```java
@Transactional
public TaskId create(req) {
    var t = repo.save(task);
    outbox.append("Task", t.id().toString(), "TaskCreated", json(t));   // в ТОЙ ЖЕ транзакции
    return t.id();
}

@Scheduled(fixedDelay = 1000)
void publish() {   // отдельный воркер: читает outbox → Kafka/HTTP → помечает published
}
```
Гарантия — **at-least-once**, значит консьюмер обязан быть идемпотентным. Готовая реализация — Spring Modulith Event Publication Registry.

За пределами одной БД: **никакого 2PC**. Паттерны — Saga (последовательность локальных транзакций + компенсации), outbox + идемпотентные консьюмеры, TCC для редких случаев.

## 13.10. Транзакции в тестах

```java
@SpringBootTest
@Transactional                      // тест откатится после каждого метода
class TaskServiceIT {
    @Test void creates() { service.create(req); assertThat(repo.count()).isEqualTo(1); }
}
```

🪤 Подводные камни:
* Тестовая транзакция **скрывает** проблемы flush/commit: `LazyInitializationException` не появится, constraint violation может «не выстрелить» до flush.
* `@Transactional` в тесте + `REQUIRES_NEW` в коде → внутренняя tx закоммитится **по-настоящему** и оставит мусор.
* `@Async`/`@TransactionalEventListener(AFTER_COMMIT)` в тесте **не сработают** (коммита нет). Тестируйте их отдельным тестом без `@Transactional`, с `TestTransaction.flagForCommit()` или через `TransactionTemplate`.

```java
TestTransaction.flagForCommit();
TestTransaction.end();          // принудительный коммит внутри теста
TestTransaction.start();
```

## 13.11. 🧪 Практика (обязательный минимум)

1. Воспроизведите «checked-исключение закоммитилось» и починьте `rollbackFor`.
2. Воспроизведите `UnexpectedRollbackException` и объясните механизм rollback-only.
3. Покажите, что `REQUIRES_NEW`-аудит сохраняется при откате внешней tx.
4. Воспроизведите lost update двумя потоками, исправьте `@Version` + retry снаружи tx.
5. Докажите, что `@Async`-метод не видит незакоммиченных данных.
6. Сделайте outbox-таблицу и воркер; убейте приложение между коммитом и публикацией — событие должно дойти после рестарта.
7. Найдите в своём проекте все `@Transactional` без `readOnly` на читающих методах.

## 13.12. Чек-лист и вопросы

- [ ] Границы транзакций — на сервисном слое, не на контроллере/репозитории.
- [ ] Читающие методы `readOnly = true`.
- [ ] Внутри tx нет внешних вызовов.
- [ ] Правила откатa осознанны (`rollbackFor` для checked).
- [ ] Есть стратегия конкурентного доступа (`@Version`/атомарный UPDATE/блокировка).
- [ ] Внешние эффекты — после коммита, критичные — через outbox.
- [ ] Retry — снаружи транзакции.

**Вопросы (middle+):** 1) Что делает `readOnly=true` в Hibernate? 2) Почему checked-исключение не откатывает? 3) Откуда `UnexpectedRollbackException`? 4) Чем `REQUIRES_NEW` опасен для пула? 5) Почему `NESTED` не работает с JPA? 6) Как Spring связывает соединение с потоком? 7) Почему retry внутри tx бесполезен? 8) Как гарантировать отправку события после коммита? 9) Чем снапшотная изоляция PG отличается от стандарта REPEATABLE_READ? 10) Что произойдёт с `@Transactional` при `@Async`?

---

**Назад:** [Глава 12](12-jdbc-i-pul-soedinenij.md) · **Дальше:** [Глава 14. JPA и Hibernate →](14-jpa-hibernate.md)