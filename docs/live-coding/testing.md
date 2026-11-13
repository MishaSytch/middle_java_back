# Тестирование

> Проверяют: структуру теста (given/when/then), охват краёв, параметризацию, поведение моков (а не «какую кнопку нажать в Mockito»).

<a id="r24-t1"></a>
**1. [Тесты] Юнит-тесты для FizzBuzz-подобной функции**
Требование: `fb(n)`: кратно 3 → "Fizz", кратно 5 → "Buzz", 15 → "FizzBuzz", иначе число; n < 1 → IllegalArgumentException.
```java
@Test
void fizzBuzzCoversAllBranches() {
    assertAll(
        () -> assertEquals("1", fb(1)),
        () -> assertEquals("2", fb(2)),
        () -> assertEquals("Fizz", fb(3)),
        () -> assertEquals("Buzz", fb(5)),
        () -> assertEquals("FizzBuzz", fb(15)),
        () -> assertEquals("FizzBuzz", fb(30)),
        () -> assertEquals("7", fb(7)),
        () -> assertThrows(IllegalArgumentException.class, () -> fb(0)),
        () -> assertThrows(IllegalArgumentException.class, () -> fb(-15))
    );
}
```
Проговорить структуру: каждая ветка кода покрыта + обе границы ошибки. Отдельный happy-path и отдельный edge-case — тоже нормальная альтернатива вместо assertAll.

<a id="r24-t2"></a>
**2. [Тесты] Параметризованные тесты**
```java
@ParameterizedTest
@ValueSource(ints = {3, 6, 9, 99})
void fizz(int n) { assertEquals("Fizz", fb(n)); }

@ParameterizedTest(name = "{0} -> {1}")
@CsvSource({ "1, 1", "3, Fizz", "5, Buzz", "15, FizzBuzz" })
void table(int input, String expected) { assertEquals(expected, fb(input)); }
```
CsvSource-таблица = table-driven подход: один прогон на строку, имя теста подставляет параметры — падение сразу показывает ввод. Упомянуть `@MethodSource` для сложных объектов.

<a id="r24-t3"></a>
**3. [Тесты] Проверка исключений**
```java
@Test
void withdrawMoreThanBalanceThrows() {
    Account acc = new Account(100);
    InsufficientFundsException e = assertThrows(InsufficientFundsException.class,
        () -> acc.withdraw(500));
    assertEquals(100, e.available());     // assertThrows ВОЗВРАЩАЕТ исключение — проверяем детали
    assertEquals(500, e.requested());
}

@Test
void balanceUnchangedAfterFailedWithdraw() {
    Account acc = new Account(100);
    assertThrows(InsufficientFundsException.class, () -> acc.withdraw(500));
    assertEquals(100, acc.balance());     // инвариант состояния после ошибки
}
```
Уровни проверки: тип исключения → сообщение/поля → состояние системы после сбоя (часто забывают).

<a id="r24-t4"></a>
**4. [Тесты] Мок зависимости и верификация взаимодействий**
```java
@Test
void secondLoadHitsCacheNotRepo() {
    UserRepo repo = mock(UserRepo.class);                       // Mockito
    when(repo.findById(42L)).thenReturn(Optional.of(new User(42L, "ann")));
    UserService service = new UserService(repo);

    service.load(42L);
    service.load(42L);

    verify(repo, times(1)).findById(42L);      // в БД сходили ровно один раз
    // ненужные взаимодействия тоже проверяем:
    verifyNoMoreInteractions(repo);
}
```
Проговорить границы моков: мокаем только владение-границей (репозиторий, шлюз), НЕ мокаем value-объекты и утилиты; состояние сервиса проверяем на реальном объекте. `verify` — про взаимодействие, `assertEquals` — про результат: тест должен проверять хоть что-то без verify.

<a id="r24-t5"></a>
**5. [Тесты] @Spy и частичное мокирование**
```java
@Test
void spyCallsRealMethodUnlessStubbed() {
    List<Integer> list = new ArrayList<>(List.of(1, 2, 3));
    List<Integer> spy = spy(list);

    // Реальный вызов:
    assertEquals(3, spy.size());

    // Подменяем только один метод:
    doReturn(99).when(spy).get(0);
    assertEquals(99, spy.get(0));
    assertEquals(2, spy.get(1)); // остальные — реальные

    // Проверка: add вызвался 1 раз
    spy.add(4);
    verify(spy).add(4);
    assertEquals(4, spy.size());
}
```
`spy` vs `mock`: mock — всё заглушено, spy — реальные методы + точечная подмена. Подмена через `doReturn().when()` (не `when().thenReturn()`), иначе реальный метод вызывается. Ограничение: spy не работает с final-методами и final-классами.

<a id="r24-t6"></a>
**6. [Тесты] Integration test с Testcontainers**
```java
@SpringBootTest
@ServiceConnection  // Spring Boot 3.1+: авто-настройка datasource из контейнера
@Testcontainers
class OrderRepositoryIT {
    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @Autowired
    OrderRepository repo;

    @Test
    void saveAndFind() {
        var order = repo.save(new Order("ORD-1", BigDecimal.TEN));
        Optional<Order> found = repo.findById(order.getId());
        assertTrue(found.isPresent());
        assertEquals("ORD-1", found.get().getOrderNumber());
    }

    @Test
    void findByStatusUsesIndex() {
        // 1000 записей → find by status за < 10ms (индекс работает)
        for (int i = 0; i < 1000; i++)
            repo.save(new Order("ORD-" + i, BigDecimal.ONE));
        List<Order> paid = repo.findByStatus("PAID");
        assertNotNull(paid);
    }
}
```
`@ServiceConnection` — Spring Boot 3.1: автоматически подставляет JDBC URL, user, password из контейнера в `DataSource`. Без аннотации — `@DynamicPropertySource`. Контейнер живёт на время класса (static `@Container`), а не теста.

<a id="r24-t7"></a>
**7. [Тесты] Property-based: инвариант для пары операций**
```java
// jqwik
@Property(tries = 1000)
void depositThenWithdrawReturnsToInitial(
        @ForAll @IntRange(min = 0, max = 100_000) int initial,
        @ForAll @IntRange(min = 0, max = 50_000)  int deposit) {
    Account acc = new Account(initial);
    acc.deposit(deposit);
    acc.withdraw(deposit);
    assertEquals(initial, acc.balance()); // инвариант: баланс вернулся
}

@Property(tries = 500)
void withdrawCannotExceedBalance(
        @ForAll @IntRange(min = 0, max = 100_000) int initial,
        @ForAll @IntRange(min = 0, max = 200_000) int amount) {
    Account acc = new Account(initial);
    if (amount > initial) {
        assertThrows(InsufficientFundsException.class, () -> acc.withdraw(amount));
        assertEquals(initial, acc.balance()); // баланс не изменился
    } else {
        acc.withdraw(amount);
        assertEquals(initial - amount, acc.balance());
    }
}
```
Property-based: генератор создаёт тысячи комбинаций, инвариант проверяется на каждой. `@IntRange` — диапазон, `tries` — сколько прогонов. Сильнее unit-тестов: находит краевые случаи, которые человек не придумал.

---

<a id="razdel-25"></a>
