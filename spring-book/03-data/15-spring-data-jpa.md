# Глава 15. Spring Data JPA: репозитории, запросы, пагинация, спецификации

> **Уровень:** junior → middle+
> **Время:** 4–5 часов
> **Цель:** использовать репозитории осознанно: знать, откуда берётся реализация, когда derived-запросы вредны, как строить динамические фильтры и не убить БД пагинацией.

## 15.1. Иерархия и что вы реально получаете

```text
Repository (маркер)
 └── CrudRepository<T,ID>            save, saveAll, findById, existsById, count, delete...
      └── ListCrudRepository<T,ID>   List-версии (Spring Data 3+)
           └── JpaRepository<T,ID>   flush, saveAndFlush, saveAllAndFlush, deleteAllInBatch,
                                     getReferenceById, findAll(Pageable/Sort), findAll(Example)
 └── PagingAndSortingRepository
 └── QueryByExampleExecutor
 └── JpaSpecificationExecutor        findAll(Specification, ...)
```

```java
public interface TaskRepository extends JpaRepository<Task, Long>, JpaSpecificationExecutor<Task> { }
```

🎯 **Практика middle+:** не наследуйте `JpaRepository` «на всякий случай». Он тянет 30+ методов, которые ломают инкапсуляцию агрегата (`deleteAll()`, `save()` в обход домена). Часто лучше:
```java
@Repository
public interface TaskRepository extends Repository<Task, Long> {
    Optional<Task> findById(Long id);
    Task save(Task task);
    @EntityGraph(attributePaths = "owner") List<Task> findByStatus(Status s);
}
```
Или вообще свой интерфейс + адаптер (гексагональная архитектура, глава 28).

## 15.2. ⚙️ Как рождается реализация

```text
@EnableJpaRepositories (Boot делает сам)
 └─ JpaRepositoriesRegistrar → ImportBeanDefinitionRegistrar
     └─ на каждый интерфейс: JpaRepositoryFactoryBean (FactoryBean!)
         └─ JpaRepositoryFactory.getRepository(interface)
             └─ ProxyFactory с интерсепторами:
                 ├─ DefaultMethodInvokingMethodInterceptor   (default-методы интерфейса)
                 ├─ QueryExecutorMethodInterceptor           (derived + @Query)
                 ├─ ImplementationMethodExecutionInterceptor (ваши custom-фрагменты)
                 └─ TransactionalRepositoryProxyPostProcessor (@Transactional на CRUD)
             └─ target = SimpleJpaRepository (реальная реализация CRUD через EntityManager)
```

Следствия:
* Репозиторий — **прокси**, поэтому `@Transactional` работает, а `final`-методы в интерфейсе невозможны.
* Derived-запрос разбирается **на старте** (`PartTree`) → опечатка в имени метода = ошибка при поднятии контекста, а не в рантайме. Это фича.
* `SimpleJpaRepository` помечен `@Transactional(readOnly = true)`, а мутирующие методы — `@Transactional`. Поэтому «транзакция есть даже без аннотации на сервисе» — но полагаться на это нельзя: границы должны быть на сервисе.

Стратегии разбора имени метода (lookup strategies): `CREATE` (по имени), `USE_DECLARED_QUERY` (`@Query`), `CREATE_IF_NOT_FOUND` (дефолт).
```yaml
spring.data.jpa.repositories.bootstrap-mode: default   # deferred | lazy — для ускорения старта
```
**[4.1]** `deferred` теперь требует наличия подходящего `AsyncTaskExecutor`, иначе — исключение; `lazy` больше не задаёт bootstrap-executor.

## 15.3. Derived queries: справочник и границы применимости

```java
List<Task> findByStatusAndOwnerName(Status status, String ownerName);
List<Task> findByTitleContainingIgnoreCase(String q);
List<Task> findByDueDateBetween(LocalDate from, LocalDate to);
List<Task> findByCreatedAtAfterOrderByCreatedAtDesc(Instant since);
Optional<Task> findFirstByStatusOrderByCreatedAtAsc(Status s);
List<Task> findTop10ByStatus(Status s);
long countByStatus(Status s);
boolean existsBySlug(String slug);
@Modifying int deleteByStatusAndCreatedAtBefore(Status s, Instant before);
List<Task> findByOwner_IdAndStatusIn(Long ownerId, Collection<Status> statuses);
List<Task> findByCommentsIsEmpty();
List<Task> findByStatusNot(Status s);
```

| Ключевое слово | Пример |
|---|---|
| `And`, `Or` | `findByAAndB`, `findByAOrB` |
| `Is`, `Equals`, `Not` | `findByStatusNot` |
| `Between`, `LessThan`, `GreaterThanEqual` | `findByAgeBetween` |
| `Like`, `StartingWith`, `EndingWith`, `Containing` | `findByTitleContaining` |
| `IgnoreCase` | `findByTitleIgnoreCase` |
| `In`, `NotIn` | `findByStatusIn` |
| `True`, `False`, `IsNull`, `IsNotNull` | `findByDeletedFalse` |
| `OrderBy…Asc/Desc` | `findByStatusOrderByCreatedAtDesc` |
| `First`, `TopN`, `Distinct` | `findTop5By…`, `findDistinctOwnerBy…` |
| вложенные свойства | `findByOwner_Address_City` |

**Когда останавливаться:** если имя метода длиннее ~60 символов или содержит 4+ условия — переходите на `@Query`/Specification. Иначе получите нечитаемый «DSL в имени метода», который невозможно ревьюить.

🪤 `findByOwnerName` может неожиданно сделать `join` (если `owner.name`), а может искать поле `ownerName`. Разделяйте подчёркиванием: `findByOwner_Name`.

## 15.4. `@Query`: JPQL, native, модифицирующие

```java
public interface TaskRepository extends JpaRepository<Task, Long> {

    @Query("""
           select t from Task t
           where t.status = :status and (:ownerId is null or t.owner.id = :ownerId)
           order by t.createdAt desc
           """)
    List<Task> search(@Param("status") Status status, @Param("ownerId") Long ownerId, Pageable pageable);

    @Query(value = """
           select * from tasks
           where search_vector @@ plainto_tsquery('russian', :q)
           order by ts_rank(search_vector, plainto_tsquery('russian', :q)) desc
           """,
           countQuery = "select count(*) from tasks where search_vector @@ plainto_tsquery('russian', :q)",
           nativeQuery = true)
    Page<Task> fullText(@Param("q") String q, Pageable pageable);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Task t set t.status = :to where t.status = :from and t.dueDate < :date")
    int bulkStatusChange(@Param("from") Status from, @Param("to") Status to, @Param("date") LocalDate date);
}
```

🪤 **`@Modifying` и persistence context:** bulk-UPDATE идёт **мимо** контекста. Сущности в памяти останутся старыми → нужен `clearAutomatically = true` (очистить контекст) и `flushAutomatically = true` (сбросить свои изменения перед bulk). Иначе получите «обновил, а читается старое».

🪤 Native + `Pageable` **требует `countQuery`**, иначе Spring не сможет посчитать total (и упадёт или посчитает неверно).

SpEL в запросах (осторожно, читаемость):
```java
@Query("select t from Task t where t.owner.id = :#{#principal.id}")
List<Task> mine(@Param("principal") CurrentUser principal);
```

## 15.5. Пагинация: `Page`, `Slice`, `Sort` и глубокие страницы

```java
Page<Task> page = repo.findByStatus(NEW, PageRequest.of(0, 20, Sort.by("createdAt").descending()));
page.getContent(); page.getTotalElements(); page.getTotalPages(); page.hasNext();

Slice<Task> slice = repo.findByStatus(NEW, PageRequest.of(0, 20));   // без COUNT — дешевле
List<Task> list = repo.findByStatus(NEW, Sort.by("createdAt"));      // без пагинации
```

| | Запросов | Когда |
|---|---|---|
| `Page` | данные + `COUNT(*)` | нужен total (админки, таблицы) |
| `Slice` | данные + 1 лишняя строка | «показать ещё», ленты, мобильные списки |
| `List` + `Sort` | данные | маленькие справочники |

🎯 **Проблема глубокого OFFSET:** `OFFSET 100000 LIMIT 20` заставляет БД прочитать 100 020 строк. Решение — **keyset (seek) pagination**:
```java
@Query("""
       select t from Task t
       where t.status = :status and (t.createdAt, t.id) < (:cursorTime, :cursorId)
       order by t.createdAt desc, t.id desc
       """)
List<Task> pageAfter(@Param("status") Status s, @Param("cursorTime") Instant t,
                     @Param("cursorId") Long id, Pageable limit);
```
Курсор = (последний `createdAt`, последний `id`) — стабильно при вставках и O(log n).

🪤 `Sort` по несуществующему свойству → `PropertyReferenceException` на старте запроса; сортировка по связи (`owner.name`) создаёт join. Никогда не пропускайте пользовательскую строку сортировки напрямую — только whitelist полей.

## 15.6. Specifications: динамические фильтры без ада из if-ов

```java
public final class TaskSpecs {
    public static Specification<Task> hasStatus(Status s) {
        return (root, query, cb) -> s == null ? null : cb.equal(root.get("status"), s);
    }
    public static Specification<Task> titleContains(String q) {
        return (root, query, cb) -> q == null ? null
                : cb.like(cb.lower(root.get("title")), "%" + q.toLowerCase() + "%");
    }
    public static Specification<Task> ownedBy(Long ownerId) {
        return (root, query, cb) -> ownerId == null ? null : cb.equal(root.get("owner").get("id"), ownerId);
    }
    public static Specification<Task> dueBetween(LocalDate from, LocalDate to) {
        return (root, query, cb) -> {
            if (from == null && to == null) return null;
            if (from == null) return cb.lessThanOrEqualTo(root.get("dueDate"), to);
            if (to == null) return cb.greaterThanOrEqualTo(root.get("dueDate"), from);
            return cb.between(root.get("dueDate"), from, to);
        };
    }
}
```

```java
var spec = Specification.allOf(                     // Spring Data 3.5+: allOf/anyOf вместо where(...).and(...)
        TaskSpecs.hasStatus(filter.status()),
        TaskSpecs.titleContains(filter.q()),
        TaskSpecs.ownedBy(filter.ownerId()),
        TaskSpecs.dueBetween(filter.from(), filter.to()));

Page<TaskView> page = repo.findAll(spec, pageable).map(TaskView::from);
```

Типобезопасность через метамодель (`hibernate-processor` **[4.x]** / `hibernate-jpamodelgen` **[3.5]**):
```java
cb.equal(root.get(Task_.status), s)     // вместо строки "status" — проверка компилятором
```

🪤 Specification + `join fetch` + `Page` требует аккуратности: `query.distinct(true)`, отдельный count-запрос, и `root.fetch(...)` только если `query.getResultType() != Long.class` (иначе COUNT упадёт).

**Query by Example** — быстрая альтернатива для простых фильтров:
```java
var probe = new Task(); probe.setStatus(NEW);
var matcher = ExampleMatcher.matching().withIgnorePaths("id", "version")
        .withStringMatcher(StringMatcher.CONTAINING).withIgnoreCase();
List<Task> found = repo.findAll(Example.of(probe, matcher));
```
Ограничения: нет `OR` между разными полями, нет диапазонов, нет вложенных условий. Для сложного — Specification или jOOQ.

## 15.7. Custom-фрагменты: когда Spring Data не хватает

```java
public interface TaskSearchFragment {
    List<TaskListItem> advancedSearch(SearchCriteria criteria);
}

public interface TaskRepository extends Repository<Task, Long>, TaskSearchFragment { }

class TaskSearchFragmentImpl implements TaskSearchFragment {     // суффикс Impl обязателен
    @PersistenceContext private EntityManager em;
    @Override public List<TaskListItem> advancedSearch(SearchCriteria c) {
        // Criteria API / native / JdbcClient — что угодно
    }
}
```
🎯 Это правильный способ «добавить метод» вместо того, чтобы тащить `EntityManager` в сервис.

## 15.8. Аудит, блокировки, стриминг

```java
@Entity @EntityListeners(AuditingEntityListener.class)
class Task {
    @CreatedDate @Column(updatable = false) Instant createdAt;
    @LastModifiedDate Instant updatedAt;
    @CreatedBy @Column(updatable = false) String createdBy;
    @LastModifiedBy String updatedBy;
}

@Configuration @EnableJpaAuditing
class AuditingConfig {
    @Bean AuditorAware<String> auditor() {
        return () -> Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                             .map(Authentication::getName);
    }
}
```
🪤 `AuditorAware` пуст в `@Async`/`@Scheduled` (нет SecurityContext) → предусмотрите fallback (`"system"`).

Блокировки:
```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@QueryHints({@QueryHint(name = "jakarta.persistence.lock.timeout", value = "3000")})
Optional<Task> findById(Long id);
```

Стриминг больших выборок:
```java
@QueryHints(@QueryHint(name = "org.hibernate.fetchSize", value = "500"))
@Query("select t from Task t where t.status = :s")
Stream<Task> streamByStatus(@Param("s") Status s);

// использование — обязательно try-with-resources и транзакция
@Transactional(readOnly = true)
public void export(Status s) {
    try (var stream = repo.streamByStatus(s)) { stream.forEach(writer::write); }
}
```

🪤 `@Async` на методах репозитория работает, но транзакция/контекст не переносятся — почти всегда плохая идея. JPA блокирующий: не пытайтесь «сделать реактивным» через `Mono.fromCallable` без отдельного пула.

## 15.9. Массовые операции: что реально батчится

```java
repo.saveAll(list);            // persist в цикле; батч будет, если hibernate.jdbc.batch_size + SEQUENCE
repo.saveAllAndFlush(list);    // + flush в конце
repo.deleteAllInBatch(list);   // ОДИН DELETE ... IN (...) — быстро
repo.deleteAll();              // N DELETE-ов (загружает и удаляет по одному!) — медленно
repo.deleteAllByIdInBatch(ids);// один DELETE по id
```
🎯 `deleteAll()` vs `deleteAllInBatch()` — классический вопрос собеседования и реальная причина «удаление 10к строк заняло минуту».

Для 100k+ строк — JDBC batch (глава 12) или `StatelessSession`, а не JPA.

## 15.10. Тестирование

```java
@DataJpaTest                                            // только JPA-слайс, откат транзакций
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class TaskRepositoryTest {
    @Container @ServiceConnection static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:18");
    @Autowired TaskRepository repo;
    @Autowired TestEntityManager em;
}
```
Что даёт `@DataJpaTest`: `DataSource`, `EntityManagerFactory`, репозитории, `TestEntityManager`, откат; **не** поднимает web-слой, сервисы, security.

🪤 Не забудьте `em.flush(); em.clear();` перед проверками (глава 14) и не тестируйте на H2, если прод на PG.

## 15.11. 🪤 Топ-10 граблей Spring Data

1. `deleteAll()` вместо `deleteAllInBatch()`.
2. `@Modifying` без `clearAutomatically` → «обновилось, но читается старое».
3. Native + `Pageable` без `countQuery`.
4. Глубокий OFFSET вместо keyset.
5. Пользовательский `sort` без whitelist → исключение/инъекция в ORDER BY.
6. `JpaRepository` наружу как «публичный API домена» → нарушение инкапсуляции.
7. Specification с fetch и COUNT без проверки `getResultType()`.
8. `findByOwnerName` вместо `findByOwner_Name`.
9. `Stream` без закрытия/транзакции.
10. `AuditorAware` без fallback в фоновых задачах.

## 15.12. 🧪 Практика

1. Соберите фильтруемый список задач через Specification с 4 необязательными критериями.
2. Реализуйте keyset-пагинацию и сравните план запроса с OFFSET 100000.
3. Сделайте bulk-обновление и докажите тестом, что без `clearAutomatically` контекст устаревает.
4. Добавьте custom-фрагмент с native-запросом и полнотекстовым поиском.
5. Настройте аудит и проверьте `createdBy` в запросе и в `@Async`.
6. Сравните `deleteAll()` и `deleteAllInBatch()` на 10 000 строк.

## 15.13. Чек-лист и вопросы

- [ ] Репозитории узкие, без «всего CRUD наружу».
- [ ] Сложные фильтры — Specification/`@Query`, не «монстры» из имён методов.
- [ ] Пагинация осознанная: `Slice` для лент, keyset для глубоких страниц.
- [ ] Bulk-операции учитывают persistence context.
- [ ] Тесты на реальном движке БД, с `flush/clear`.

**Вопросы:** 1) Как создаётся реализация интерфейса репозитория? 2) Почему опечатка в derived-методе падает на старте? 3) Чем `Slice` дешевле `Page`? 4) Что делает `clearAutomatically`? 5) Почему `deleteAll()` медленный? 6) Как сделать динамический фильтр типобезопасно? 7) Что не так с `OFFSET 100000`?

---

**Назад:** [Глава 14](14-jpa-hibernate.md) · **Дальше:** [Глава 16. Миграции схемы →](16-migracii-flyway-liquibase.md)