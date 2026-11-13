# Глава 14. JPA и Hibernate: маппинг, persistence context, N+1 и производительность

> **Уровень:** junior → middle+ (ключевая глава книги)
> **Время:** 6–8 часов
> **Цель:** понимать, что Hibernate делает за вас, и уметь писать маппинг и запросы, которые не убивают прод. После этой главы вы объясняете `LazyInitializationException`, N+1, dirty checking и `MultipleBagFetchException` без запинки.

## 14.1. Версии и что изменилось

| | Boot 3.5 **[3.5]** | Boot 4.x **[4.x]** |
|---|---|---|
| JPA | 3.1 | **3.2** |
| Hibernate ORM | 6.6.x | **7.2.x** |
| Пакет нативной поддержки Spring | `org.springframework.orm.hibernate5` | **`org.springframework.orm.jpa.hibernate`** |
| Annotation processor | `hibernate-jpamodelgen` | **`hibernate-processor`** |
| Инъекция `EntityManager` | через `SharedEntityManagerBean` | напрямую `@Autowired` (JPA 3.2), включая квалификаторы |
| `StatelessSession` | вручную | транзакционный прокси из `LocalSessionFactoryBean` (рекомендуется ORM 7.2) |

## 14.2. Зачем ORM и в чём «impedance mismatch»

Объекты — граф с идентичностью и наследованием; реляционные данные — таблицы с внешними ключами. ORM примиряет это, но платит:
* **сложностью** (состояния сущности, кэш первого уровня, flush);
* **неявными запросами** (lazy-загрузка);
* **ограничениями** (аналитика, массовые операции).

Правило зрелого проекта: **JPA — для write-модели (домен), SQL/JDBC/проекции — для read-модели (отчёты, списки)**. Это гибрид, а не «или-или».

## 14.3. Persistence context: сердце Hibernate

```text
new/transient ──persist()──► managed ──remove()──► removed ──flush+commit──► (удалён в БД)
                               │
                            detach()/close()
                               ▼
                            detached ──merge()──► managed (копия!)
```

* **Persistence context = кэш первого уровня + unit of work.** Один `EntityManager` = один контекст. В Spring по умолчанию он привязан к транзакции.
* **Dirty checking**: при flush Hibernate сравнивает состояние managed-сущностей со снапшотом и сам генерирует UPDATE. `save()` для managed-сущности **не нужен**.
* **Write-behind**: SQL выполняется не в момент вызова сеттера, а при **flush** (перед коммитом, перед запросом, или явно).
* **Identity guarantee**: в рамках одного контекста `findById(1) == findById(1)` — тот же объект.

```java
@Transactional
public void demo(Long id) {
    Task t = em.find(Task.class, id);   // SELECT
    t.setTitle("new");                 // никакого SQL
    em.flush();                        // UPDATE здесь
    t.setStatus(DONE);                 // ещё один UPDATE при коммите
}
```

Порядок flush (важно для constraint-ов): **inserts → updates → collection removals/updates → deletes**. Отсюда классика: «удалил и вставил с тем же unique-ключом в одной tx → constraint violation». Лечение — явный `flush()` между операциями.

## 14.4. Маппинг сущности: эталон

```java
@Entity
@Table(name = "tasks",
       indexes = @Index(name = "ix_tasks_owner_status", columnList = "owner_id,status"),
       uniqueConstraints = @UniqueConstraint(name = "uq_tasks_slug", columnNames = "slug"))
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "task_seq")
    @SequenceGenerator(name = "task_seq", sequenceName = "task_seq", allocationSize = 50)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, unique = true, length = 120)
    private String slug;

    @Enumerated(EnumType.STRING)                 // ВСЕГДА STRING (ORDINAL ломается при рефакторинге)
    @Column(nullable = false, length = 20)
    private Status status = Status.NEW;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Version
    private long version;                        // оптимистическая блокировка

    @ManyToOne(fetch = FetchType.LAZY, optional = false)   // LAZY вручную: дефолт EAGER!
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @OneToMany(mappedBy = "task", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("createdAt ASC")
    private List<Comment> comments = new ArrayList<>();

    @Embedded
    private Address address;

    protected Task() {}                          // требование JPA: no-arg, не private

    public Task(String title, User owner) { this.title = title; this.owner = owner; }

    // синхронизация обеих сторон — обязательно
    public void addComment(Comment c) { comments.add(c); c.setTask(this); }
    public void removeComment(Comment c) { comments.remove(c); c.setTask(null); }

    @PrePersist void onCreate() { createdAt = Instant.now(); }

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Task other)) return false;
        return id != null && id.equals(other.id);
    }
    @Override public int hashCode() { return Task.class.hashCode(); }
}
```

### Стратегии генерации id — важный выбор

| Стратегия | Плюсы | Минусы |
|---|---|---|
| `IDENTITY` | просто, `auto_increment` | **отключает JDBC batch inserts**; id известен только после INSERT |
| `SEQUENCE` (+`allocationSize`) | batch работает, id до INSERT, лучшая производительность | нужна последовательность в БД |
| `TABLE` | универсально | медленно, блокировки — не использовать |
| `UUID` (клиентский) | распределённость, идемпотентность | индекс больше, случайный UUID плохо для B-tree (используйте UUIDv7) |

🎯 **Рекомендация: `SEQUENCE` с `allocationSize = 50`** (и `increment 50` в миграции!). Классический баг: `allocationSize=50` в Java и `INCREMENT 1` в БД → Hibernate «пропускает» id или конфликтует при нескольких инстансах.

### Типы и конвертеры
```java
@Column(precision = 19, scale = 4) BigDecimal amount;      // деньги — только BigDecimal
@Convert(converter = MoneyConverter.class) Money price;    // AttributeConverter
@JdbcTypeCode(SqlTypes.JSON) @Column(columnDefinition = "jsonb") Map<String,Object> meta;  // Hibernate
@Lob String description;                                  // осторожно: PG text vs oid
```
`java.time` (`Instant`, `LocalDate`, `LocalDateTime`, `OffsetDateTime`) поддерживается нативно — никаких `@Temporal`.

🪤 Храните время в UTC (`Instant`/`OffsetDateTime`) и настройте `spring.jpa.properties.hibernate.jdbc.time_zone=UTC`. Иначе «сдвиг на 3 часа» в отчётах гарантирован.

## 14.5. Ассоциации: правила, которые надо запомнить

| Ассоциация | Дефолт fetch | Что ставить |
|---|---|---|
| `@ManyToOne` | **EAGER** | всегда `LAZY` |
| `@OneToOne` | **EAGER** | `LAZY` (+ см. ниже) |
| `@OneToMany` | LAZY | оставить LAZY |
| `@ManyToMany` | LAZY | лучше заменить на явную сущность-связку |

**Почему `@OneToOne(fetch=LAZY)` часто не работает:** если связь по `mappedBy` (обратная сторона), Hibernate обязан знать, есть ли связанная запись → делает SELECT. Ленивость работает только для владеющей стороны с FK, либо нужен bytecode enhancement.

**`@ManyToMany` → явная сущность:**
```java
@Entity class TaskTag {
    @EmbeddedId TaskTagId id;
    @ManyToOne @MapsId("taskId") Task task;
    @ManyToOne @MapsId("tagId") Tag tag;
    Instant assignedAt;                 // ← вот зачем: у связки появляются свои атрибуты
}
```
Причины: нельзя добавить атрибуты к `@ManyToMany`, `remove` перегружает всю коллекцию, каскады опасны.

**`CascadeType` и `orphanRemoval`:**

| Каскад | Смысл |
|---|---|
| `PERSIST` | сохранить детей при сохранении родителя |
| `MERGE` | слить изменения детей |
| `REMOVE` | удалить детей при удалении родителя |
| `REFRESH`, `DETACH` | соответствующие операции |
| `ALL` | все выше |
| `orphanRemoval = true` | удалить ребёнка при удалении **из коллекции** |

🪤 `CascadeType.REMOVE` на `@ManyToOne` — почти всегда ошибка: удалите одного пользователя и снесёте всех, кто на него ссылается. Каскады — только «сверху вниз» по агрегату (parent → children).

## 14.6. Ленивая загрузка и `LazyInitializationException`

```java
Task t = repo.findById(1).orElseThrow();     // транзакция закончилась, контекст закрыт
t.getOwner().getName();                      // 💥 LazyInitializationException
```

Причина: прокси-коллекция/связь требует открытого persistence context.

**Четыре решения (в порядке правильности):**
1. **Загрузить нужное внутри транзакции** — `@EntityGraph` или `join fetch` (см. ниже).
2. **DTO-проекция** — сразу выбрать нужные поля запросом (лучший вариант для чтения).
3. Работать в границах транзакции (сервис возвращает DTO, а не сущность).
4. `spring.jpa.open-in-view=true` — **антипаттерн**, см. ниже.

### 🎯 `open-in-view`: почему выключают

По умолчанию Boot держит `EntityManager` открытым **на весь HTTP-запрос** (OSIV). Плюсы: нет `LazyInitializationException`. Минусы:
* соединение удерживается всё время запроса (включая рендеринг JSON) → пул исчерпан под нагрузкой;
* N+1 «прячется» и всплывает в проде;
* границы транзакции размываются: записи могут происходить вне явной tx.

```yaml
spring:
  jpa:
    open-in-view: false      # ← ставьте всегда и сразу
```
Boot предупреждает об этом в логах. Выключив OSIV, вы **вынуждены** проектировать загрузку данных — это и есть цель.

## 14.7. N+1: обнаружение и все способы лечения

**Симптом:** один запрос за списком + N запросов за связями.

```java
List<Task> tasks = repo.findAll();                 // 1 SELECT
tasks.forEach(t -> t.getOwner().getName());        // N SELECT-ов
```

**Как обнаружить:**
```yaml
spring.jpa.properties.hibernate.generate_statistics: true
logging.level.org.hibernate.SQL: DEBUG
logging.level.org.hibernate.stat: DEBUG
```
Плюс тест-ассерт на количество запросов (см. §14.11) и datasource-proxy/`spring-boot-starter-actuator` метрики.

**Способы лечения:**

1. **`@EntityGraph`** (декларативно, лучше всего для репозиториев):
```java
public interface TaskRepository extends JpaRepository<Task, Long> {
    @EntityGraph(attributePaths = {"owner", "comments"})
    List<Task> findByStatus(Status status);

    @EntityGraph(type = EntityGraph.EntityGraphType.LOAD, attributePaths = "owner")
    Optional<Task> findWithOwnerById(Long id);
}
```

2. **`join fetch` в JPQL**:
```java
@Query("select t from Task t join fetch t.owner where t.status = :status")
List<Task> findWithOwner(@Param("status") Status status);
```
🪤 `join fetch` + пагинация = **HHH000104: firstResult/maxResults specified with collection fetch; applying in memory** — Hibernate тянет ВСЁ в память. Для коллекций используйте два запроса или `@BatchSize`.

3. **Batch fetching** (лечит N+1 «пачками»):
```java
@BatchSize(size = 50) @OneToMany(mappedBy = "task") List<Comment> comments;
```
```yaml
spring.jpa.properties.hibernate.default_batch_fetch_size: 50   # глобально — очень рекомендую
```
Вместо N запросов будет `ceil(N/50)` с `IN (...)`.

4. **DTO-проекция** — вообще не грузить сущности:
```java
@Query("""
       select new dev.book.task.TaskListItem(t.id, t.title, o.name)
       from Task t join t.owner o where t.status = :status
       """)
List<TaskListItem> list(@Param("status") Status status);
```

5. **Два запроса** («сначала id страницы, потом всё по id») — стандарт для сложных списков с пагинацией.

🪤 **`MultipleBagFetchException`**: нельзя `join fetch` две `List`-коллекции одновременно (декартово произведение). Решения: `Set` вместо `List` (но тогда теряется порядок и появляется дубль-проблема), либо два запроса, либо `@BatchSize`.

## 14.8. Проекции: правильный read-слой

| Тип | Как | Особенности |
|---|---|---|
| Interface-based (closed) | `interface TaskView { String getTitle(); }` | прокси, только нужные колонки |
| Interface-based (open) | `@Value("#{target.title + ' ' + target.status}")` | грузит сущность целиком — осторожно |
| Class/record DTO | `new TaskListItem(...)` в JPQL | типобезопасно, лучший вариант |
| Dynamic | `<T> List<T> findByStatus(Status s, Class<T> type)` | гибко |
| Nested | `OwnerView getOwner()` | требует join |

```java
public record TaskListItem(Long id, String title, String ownerName) {}

public interface TaskRepository extends JpaRepository<Task, Long> {
    <T> List<T> findByStatus(Status status, Class<T> type);
}
// вызов: repo.findByStatus(NEW, TaskListItem.class)
```

🎯 **Правило:** контроллер **никогда** не возвращает сущность. Только DTO. Причины: ленивая загрузка при сериализации, утечка внутренних полей, бесконечная рекурсия双向 связей, случайный «mass assignment» при десериализации.

## 14.9. Наследование, soft delete, мультитенантность

```java
@Entity @Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "kind")
abstract class Payment {}
// SINGLE_TABLE — быстро, но nullable-колонки; JOINED — нормализовано, но join-ы; TABLE_PER_CLASS — плохо для полиморфных запросов
```

**Soft delete (Hibernate 7):**
```java
@Entity
@SQLRestriction("deleted_at is null")          // вместо устаревшего @Where
@SoftDelete(columnName = "deleted_at")         // Hibernate 6.4+: автоматический soft delete
class Task { ... }
```
🪤 Soft delete ломает уникальные индексы (нужен partial unique index `WHERE deleted_at IS NULL`) и «утекает» в отчёты. Решайте осознанно.

**Мультитенантность:** `@TenantId` (Hibernate 6+) + `CurrentTenantIdentifierResolver` — дискриминаторный вариант «одна БД, колонка tenant_id». Альтернативы: схема на тенанта (`MultiTenantConnectionProvider`), БД на тенанта.

## 14.10. Производительность: чек-лист Hibernate

```yaml
spring:
  jpa:
    open-in-view: false
    properties:
      hibernate:
        jdbc.batch_size: 50
        order_inserts: true
        order_updates: true
        batch_versioned_data: true
        default_batch_fetch_size: 50
        query.in_clause_parameter_padding: true      # меньше планов в кэше БД
        jdbc.time_zone: UTC
        generate_statistics: false                   # true только для диагностики
        connection.provider_disables_autocommit: true
  datasource.hikari.auto-commit: false
```

* **Batch inserts работают только с `SEQUENCE`/`UUID`, не с `IDENTITY`.**
* Второй уровень кэша (`hibernate.cache.use_second_level_cache`) — **по умолчанию не включайте**: сложная инвалидация, «загадочные» устаревшие данные. Лучше явный кэш на уровне сервиса (глава 17).
* Query plan cache: `in_clause_parameter_padding` уменьшает число вариантов `IN (?,?,?)`.
* Массовые операции — `@Modifying` JPQL или JDBC, не «загрузить-изменить-сохранить» в цикле.
* Для потоковой обработки — `StatelessSession` (без persistence context, без dirty checking) **[4.x]** Spring умеет инжектить транзакционный прокси.
* `@DynamicUpdate` — генерировать UPDATE только по изменённым колонкам (полезно при широких таблицах/триггерах, но ломает кэш планов).

## 14.11. Тестирование маппинга и запросов

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)
@Testcontainers
class TaskRepositoryTest {
    @Container @ServiceConnection static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:18");

    @Autowired TaskRepository repo;
    @Autowired TestEntityManager em;

    @Test void mapsAndLoadsOwner() {
        var owner = em.persist(new User("ann"));
        em.persist(new Task("t1", owner));
        em.flush(); em.clear();                       // ← обязательно: иначе тест «пройдёт» на кэше

        var found = repo.findWithOwnerById(...).orElseThrow();
        assertThat(found.getOwner().getName()).isEqualTo("ann");
    }
}
```

**Тест на N+1 (очень полезно иметь в проекте):**
```java
Statistics stats = sessionFactory.getStatistics();
stats.clear();
service.list();
assertThat(stats.getPrepareStatementCount()).isLessThanOrEqualTo(3);
```

🪤 `em.flush(); em.clear();` — без этого вы тестируете кэш первого уровня, а не маппинг. Это самая частая ошибка в `@DataJpaTest`.

## 14.12. 🪤 Топ-15 граблей JPA

1. `@ManyToOne` EAGER по умолчанию → лишние join-ы везде.
2. OSIV включён → пул исчерпан, скрытый N+1.
3. `IDENTITY` + batch → батч не работает.
4. `allocationSize` не совпадает с `INCREMENT` последовательности.
5. `equals/hashCode` на всех полях или на `id` в hashCode → «потеря» в `HashSet`.
6. Возврат сущности из контроллера → рекурсия/LazyInit/утечка полей.
7. `join fetch` коллекции + `Pageable` → загрузка всей таблицы в память.
8. Две `List` в `join fetch` → `MultipleBagFetchException`.
9. `CascadeType.REMOVE` на `@ManyToOne`.
10. `merge()` вместо managed-сущности → лишний SELECT и «потеря» изменений.
11. Ожидание, что `save()` нужен для managed-сущности (он не нужен).
12. Уникальный constraint + delete/insert в одной tx без flush.
13. `EnumType.ORDINAL` → данные «переехали» после добавления константы.
14. Нет `@Version` → потерянные обновления.
15. Тесты без `flush/clear` → ложная уверенность.

## 14.13. 🧪 Практика

1. Смапьте агрегат `Task` + `Comment` + `User` по эталону; выключите OSIV.
2. Воспроизведите N+1 и починьте тремя способами (`@EntityGraph`, `@BatchSize`, DTO).
3. Получите `MultipleBagFetchException` и объясните причину.
4. Сравните время вставки 10 000 сущностей с `IDENTITY` и `SEQUENCE(batch=50)`.
5. Напишите тест-ассерт на количество SQL-запросов для списочного метода.
6. Сделайте `join fetch` + `Pageable`, найдите предупреждение HHH000104 и переделайте на два запроса.

## 14.14. Чек-лист и вопросы

- [ ] OSIV выключен; все `@ManyToOne`/`@OneToOne` — LAZY.
- [ ] Стратегия id обоснована; batch включён и работает.
- [ ] Есть `@Version` там, где конкурентные изменения.
- [ ] Наружу отдаются DTO, а не сущности.
- [ ] Есть тесты на количество запросов для критичных списков.
- [ ] Каскады — только внутри агрегата.

**Вопросы (middle+):** 1) Что такое persistence context и unit of work? 2) Когда происходит flush? 3) Почему `save()` не нужен для managed? 4) Чем `merge` отличается от `persist`? 5) Почему `@OneToOne(LAZY)` не всегда ленивый? 6) Как работает dirty checking? 7) Почему `IDENTITY` ломает batch? 8) Что такое HHH000104 и как исправить? 9) Зачем `flush/clear` в тестах? 10) Почему второй уровень кэша часто вреден?

---

**Назад:** [Глава 13](13-tranzakcii.md) · **Дальше:** [Глава 15. Spring Data JPA →](15-spring-data-jpa.md)