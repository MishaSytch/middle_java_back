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

---

<a id="razdel-25"></a>
