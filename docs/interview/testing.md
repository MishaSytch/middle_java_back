# Тестирование (JUnit 5 / Mockito / Testcontainers)


### 1. Зачем нужно тестирование и какие виды тестов существуют

Тестирование — это проверка того, что код ведёт себя так, как ожидается, и защита от регрессий: без автотестов любое изменение в системе превращается в «рулетку», а рефакторинг становится практически невозможным. Тесты также служат живой документацией: по юнит-тесту можно понять, как задумано использовать класс и какие краевые случаи существуют.

Основные виды тестов:
- **Юнит-тесты** — проверяют один класс/метод в изоляции, все внешние зависимости подменяются моками. Быстрые (миллисекунды), их много.
- **Интеграционные тесты** — проверяют взаимодействие нескольких компонентов: сервис + реальная БД (или Testcontainers), брокер, файловая система. Медленнее, их меньше.
- **E2E (end-to-end)** — проверяют весь сценарий через пользовательский интерфейс или публичный API целиком. Самые медленные и хрупкие, их мало.
- **Нагрузочные** (JMeter, Gatling) — проверяют производительность под нагрузкой.

```java
// Юнит-тест: класс тестируется в изоляции, репозиторий — мок
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock OrderRepository repository;
    @InjectMocks OrderService service;

    @Test
    void shouldCalculateTotal() {
        when(repository.findPrices(any())).thenReturn(Map.of("a", 100));
        assertEquals(200, service.total(List.of("a", "a"))); // чистая логика, без БД
    }
}
```

### 2. Что такое пирамида тестирования

**Пирамида тестирования** — модель распределения тестов по уровням: много быстрых юнит-тестов в основании, средний слой интеграционных тестов и тонкая верхушка E2E-тестов. Логика проста: чем выше уровень, тем дороже написание, медленнее выполнение и сложнее локализация ошибки.

Типичное распределение для backend-проекта:
- **~70% юнит-тестов** — логика классов, валидаторы, калькуляторы, преобразователи. Запускаются на каждый коммит локально.
- **~20% интеграционных** — репозитории с реальной БД, REST-слой через MockMvc/Testcontainers, взаимодействие с Kafka.
- **~10% E2E/смоук** — критические пользовательские сценарии на стенде.

Антипаттерны пирамиды: **«мороженое-рожок»** (много E2E, мало юнитов — медленный и хрупкий прогон) и **«сэндвич»** (юниты + E2E без интеграционного слоя). В тестах обязателен принцип **FIRST**: Fast, Independent, Repeatable, Self-validating, Timely.

### 3. Что такое JUnit 5 и из каких модулей он состоит

**JUnit 5** — стандартный фреймворк для юнит-тестирования в Java (появился в 2017, заменил JUnit 4). В отличие от монолитного JUnit 4, он построен как платформа и состоит из трёх модулей:

- **JUnit Platform** — фундамент: определяет `TestEngine` API и запуск тестов в IDE, Gradle, Maven, консоли. Позволяет на одной платформе работать не только JUnit-движку, но и, например, TestNG или Spock.
- **JUnit Jupiter** — новый программный API для написания тестов (`org.junit.jupiter`): аннотации, ассерты, расширения.
- **JUnit Vintage** — движок для запуска старых тестов JUnit 3/4 на платформе JUnit 5, чтобы мигрировать постепенно.

В Spring Boot 2.2+ и 3.x JUnit 5 подключается стартером `spring-boot-starter-test` по умолчанию:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

```java
import org.junit.jupiter.api.Test; // НЕ org.junit.Test (это JUnit 4!)
import static org.junit.jupiter.api.Assertions.*;

class CalculatorTest {
    @Test
    void twoPlusTwoIsFour() {
        assertEquals(4, new Calculator().add(2, 2));
    }
}
```

### 4. Какие основные аннотации есть в JUnit 5

Ключевые аннотации Jupiter:

| Аннотация                    | Назначение                                                                                                |
|------------------------------|-----------------------------------------------------------------------------------------------------------|
| `@Test`                      | Помечает тестовый метод (в отличие от JUnit 4 — без параметров)                                           |
| `@BeforeEach` / `@AfterEach` | Выполняется перед/после **каждого** теста (аналог @Before/@After из JUnit 4)                              |
| `@BeforeAll` / `@AfterAll`   | Один раз до/после всех тестов класса; метод должен быть `static` (или класс с `@TestInstance(PER_CLASS)`) |
| `@DisplayName`               | Человекочитаемое имя теста для отчёта                                                                     |
| `@Disabled`                  | Отключает тест (аналог `@Ignore`); можно с причиной                                                       |
| `@Nested`                    | Вложенный класс для группировки тестов по сценарию                                                        |
| `@Tag`                       | Метка для фильтрации (`@Tag("slow")`, запуск только быстрых)                                              |
| `@RepeatedTest(n)`           | Повторить тест n раз (ловит плавающие ошибки)                                                             |
| `@ParameterizedTest`         | Тест с параметрами — вместо набора одинаковых тестов                                                      |
| `@Timeout(5)`                | Падает, если тест выполняется дольше 5 секунд                                                             |
| `@TestMethodOrder`           | Управление порядком тестов (по умолчанию порядок не гарантирован)                                         |

```java
class UserServiceTest {
    @BeforeAll static void initAll() { /* старт тяжёлого ресурса */ }
    @BeforeEach void init() { /* свежее состояние перед каждым тестом */ }

    @Test
    @DisplayName("Email должен быть валиден")
    void emailValidation() { assertTrue(Validator.isEmail("a@b.io")); }

    @Nested
    @DisplayName("Когда пользователь заблокирован")
    class WhenBlocked {
        @Test void loginFails() { /* ... */ }
    }
}
```

### 5. Опишите жизненный цикл тестового метода в JUnit 5

Последовательность выполнения одного тестового класса:

1. `@BeforeAll` (static) — один раз перед всеми тестами: часто здесь поднимают общий ресурс (контейнер, сервер).
2. Создаётся **новый экземпляр тестового класса** для каждого теста (важно: по умолчанию `Lifecycle.PER_METHOD`) — это гарантирует изоляцию: поля теста не «протекают» между тестами.
3. `@BeforeEach` — свежее состояние перед каждым тестом.
4. Выполнение `@Test`-метода.
5. `@AfterEach` — очистка после каждого теста.
6. Шаги 2–5 повторяются для каждого теста класса.
7. `@AfterAll` (static) — один раз после всех тестов.

```java
@TestInstance(TestInstance.Lifecycle.PER_CLASS) // опция: один экземпляр на класс
class LifecycleTest {
    @BeforeAll static void beforeAll()   { System.out.println("1"); }
    @BeforeEach    void beforeEach()     { System.out.println("2"); }
    @Test          void testA()          { System.out.println("3"); }
    @Test          void testB()          { System.out.println("3"); }
    @AfterEach     void afterEach()      { System.out.println("4"); }
    @AfterAll      static void afterAll(){ System.out.println("5"); }
}
// Вывод: 1 2 3 4 2 3 4 5
```

Поскольку создаётся новый экземпляр на каждый тест, нестатические поля сбрасываются автоматически — мутабельное состояние в полях тестового класса не вызовет взаимовлияния тестов.

### 6. В чём разница между JUnit 4 и JUnit 5

Главные отличия:

- **Архитектура:** JUnit 5 — платформа с `TestEngine`; JUnit 4 — монолит. В JUnit 5 можно смешивать движки.
- **Пакет и зависимости:** `org.junit.jupiter` vs `org.junit`; в JUnit 5 тесты не требуют публичного класса и публичного тестового метода.
- **Аннотации:** `@BeforeAll/@AfterAll/@BeforeEach/@AfterEach` вместо `@BeforeClass/@AfterClass/@Before/@After`; `@Disabled` вместо `@Ignore`; `@Tag` вместо `@Category`.
- **Правила → расширения:** механизм `@Rule`/`@ClassRule` заменён моделью `@ExtendWith` и `Extension` API (например, `MockitoExtension`, `SpringExtension`).
- **Ассерты и assumptions:** обогащены (`assertAll`, `assertThrows` вместо `@ExpectedException`, лямбда-сообщения — сообщение формируется только при падении).
- **Параметризация:** `@ParameterizedTest` встроен с богатым набором источников, в JUnit 4 это был отдельный громоздкий `RunWith(Parameterized.class)`.
- **Вложенные классы** `@Nested` и повторение `@RepeatedTest` — новые возможности.
- **Java-версия:** JUnit 5 требует Java 8+ и активно использует лямбды в API.

```java
// JUnit 4: ожидание исключения через атрибут или правило
@Test(expected = IllegalArgumentException.class) public void oldWay() { }

// JUnit 5: программная проверка с лямбдой + проверка сообщения
@Test void newWay() {
    IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
        () -> new Range(-1, 10));
    assertEquals("min > max", ex.getMessage());
}
```

### 7. Какие методы проверки (assertions) есть в JUnit 5

Ассерты находятся в `org.junit.jupiter.api.Assertions`:

- `assertEquals(expected, actual)` / `assertNotEquals` — равенство (для `double` есть перегрузка с delta).
- `assertTrue` / `assertFalse` — булево условие.
- `assertNull` / `assertNotNull` — проверка на null.
- `assertSame` / `assertNotSame` — сравнение по ссылке (в отличие от `assertEquals`, который использует `equals()`).
- `assertArrayEquals` — сравнение массивов поэлементно.
- `assertIterableEquals`, `assertLinesMatch` — коллекции и строки с шаблонами.
- `assertThrows(Class, Executable)` — возвращает исключение, чтобы проверить его поля; `assertDoesNotThrow`.
- `assertTimeout(Duration, Executable)` / `assertTimeoutPreemptively` — проверка времени выполнения (`Preemptively` убивает выполнение по таймауту).
- `fail(message)` — принудительная ошибка.

```java
@Test void assertionsDemo() {
    List<String> list = List.of("a", "b");
    assertEquals(2, list.size());
    assertTrue(list.contains("a"));
    assertNotNull(list);

    TimeoutException t = assertThrows(TimeoutException.class,
        () -> assertTimeoutPreemptively(Duration.ofMillis(50),
             () -> Thread.sleep(200)));
    // assertTimeoutPreemptively не дожидается задачи — падает сразу после 50 мс
}
```

Сообщение об ошибке передаётся третьим аргументом; лямбда `() -> "msg"` вычисляется лениво, что экономит ресурсы при конкатенации больших строк.

### 8. Что такое assertAll и чем он отличается от последовательных assert

Обычные ассерты **прерывают тест при первом падении**: если упало `assertEquals` на второй строке, вы не узнаете о проблемах в остальных. **`assertAll`** выполняет **все** переданные проверки и собирает отчёт обо всех неудачах сразу — это «мягкие ассерты» (soft assertions).

```java
@Test void userDtoFields() {
    UserDto dto = mapper.toDto(new User("Ivan", "ivan@x.io", 30));

    assertAll("Маппинг пользователя",
        () -> assertEquals("Ivan", dto.name()),
        () -> assertEquals("ivan@x.io", dto.email()), // упадёт — но тест продолжится
        () -> assertEquals(30, dto.age())
    );
    // В отчёте будут показаны ВСЕ несовпадения, а не только первое
}
```

Типичное применение: проверка множества полей одного объекта/ответа API, валидация в нескольких группах (`assertAll` можно вкладывать друг в друга). Также `assertAll` гарантирует порядок выполнения проверок внутри группы, что важно для зависимых проверок.

### 9. Как писать параметризованные тесты

`@ParameterizedTest` позволяет прогнать одну логику на множестве входных данных, заменяя копипасту одинаковых тестов. Источники параметров:

- `@ValueSource(ints = {1, 2, 3})` — массив примитивов/строк.
- `@NullSource`, `@EmptySource`, `@NullAndEmptySource` — граничные случаи.
- `@EnumSource(Status.class)` — все или выбранные элементы enum.
- `@CsvSource({"'a, b', 2", "'x', 1"})` — строки с несколькими параметрами.
- `@CsvFileSource(resources = "/data.csv")` — данные из файла.
- `@MethodSource("provider")` — статический метод, возвращающий `Stream<Arguments>` (самый гибкий: сложные объекты).
- `@ArgumentsSource(MyProvider.class)` — свой провайдер.

```java
class PasswordValidatorTest {

    static Stream<Arguments> passwords() {
        return Stream.of(
            Arguments.of("Str0ng!pass", true),
            Arguments.of("weak", false),
            Arguments.of("нетцифр!!", false)
        );
    }

    @ParameterizedTest(name = "[{index}] {0} -> {1}")
    @MethodSource("passwords")
    void validation(String pwd, boolean expected) {
        assertEquals(expected, Validator.isValid(pwd));
    }

    @ParameterizedTest
    @CsvSource({"1, 2, 3", "5, 5, 10", "-1, 1, 0"})
    void sum(int a, int b, int expected) {
        assertEquals(expected, Math.addExact(a, b));
    }
}
```

### 10. Что такое TDD

**TDD (Test-Driven Development)** — практика разработки, при которой тест пишется **до** кода. Цикл «красный-зелёный-рефакторинг»:

1. **Красный** — пишем маленький тест, описывающий ещё не существующее поведение; запускаем и видим падение (тест корректно фиксирует отсутствие функциональности).
2. **Зелёный** — пишем **минимальный** код, чтобы тест прошёл (без обобщений и красоты).
3. **Рефакторинг** — при зелёных тестах улучшаем структуру кода: убираем дублирование, переименовываем, выделяем методы.

Преимущества: тесты появляются гарантированно, API проектируется «от потребителя», мгновенная обратная связь, отсутствие непротестированного кода. Ограничения: TDD плохо ложится на exploratory-код, legacy-интеграции и UI; требует дисциплины. Родственная практика — **BDD**: тесты описываются на языке бизнес-сценариев (Given-When-Then, инструменты Cucumber/JBehave).

```java
// Шаг 1 (красный): тест для ещё не написанного метода
@Test void shouldApplyTenPercentDiscountOver1000() {
    assertEquals(900, new Pricing().withDiscount(1000)); // метода ещё нет — компиляция/падение
}
// Шаг 2 (зелёный): минимальная реализация
// int withDiscount(int sum) { return sum >= 1000 ? sum / 10 * 9 : sum; }
// Шаг 3: рефакторинг и добавление следующего теста (граничного: 999)
```

### 11. Что такое тестовые дубли: mock, stub, fake, spy, dummy

**Test Double** (тестовый дубль) — общий термин для объектов-заменителей реальных зависимостей в тестах (термин из книги Мезароса «xUnit Test Patterns»):

- **Dummy** — объект-заполнитель, который только удовлетворяет компилятор, но не используется (`null`-подобный `User DUMMY`).
- **Stub** — возвращает заранее заданные ответы на вызовы. Проверяем **состояние**: «при вызове X верни Y».
- **Fake** — работающая упрощённая реализация: in-memory база вместо PostgreSQL, fake-репозиторий на `HashMap`.
- **Mock** — объект с заранее заданными ожиданиями взаимодействий; проверяем **поведение**: «метод X должен быть вызван ровно 1 раз с аргументом Y». Mockito-моки совмещают stubbing и verification.
- **Spy** — обёртка над **реальным** объектом: вызовы идут в настоящие методы, но их можно перехватить, заглушить выборочно и проверить.

Практическое правило: где можно — проверяйте **состояние** (что вернул метод) на stub/fake; проверку **взаимодействий** (verify на mock) оставляйте для граничных вызовов — отправка письма, публикация события, запись в платёжный шлюз. Избыточный verify делает тесты хрупкими к рефакторингу.

### 12. Что такое Mockito и как создать мок

**Mockito** — самый популярный Java-фреймворк для создания тестовых дублей (входит в `spring-boot-starter-test`). Мок создаётся для класса или интерфейса: Mockito генерирует подкласс/прокси, в котором все методы возвращают значения по умолчанию (`null`, `0`, `false`, пустой `Optional`/коллекция), пока поведение не задано явно.

```java
// Способ 1: программно
UserRepository repo = Mockito.mock(UserRepository.class);

// Способ 2: аннотация + активация (в JUnit 5 — расширение)
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock UserRepository repo;          // мок зависимости
    @InjectMocks UserService service;   // в него внедрятся моки (конструктор/setter/поле)

    @Test void findByIdReturnsUser() {
        when(repo.findById(42L)).thenReturn(Optional.of(new User("Anna")));
        assertEquals("Anna", service.nameById(42L));
        // не заданные вызовы: repo.count() вернёт 0, findById(1L) -> Optional.empty()
    }
}
```

Mockito работает через **Byte Buddy** (генерация прокси в рантайме). Ограничения: нельзя мокать `final` классы/методы и `static` методы обычным способом (нужно `mockito-inline`/`mockito-core` 5+, где это включено по умолчанию), а также `private` методы и `equals()/hashCode()`.
### 13. Как настроить поведение мока (stubbing)

Базовый синтаксис — `when(mock.method(args)).thenReturn(value)`. Варианты:

- `thenReturn(v1, v2, ...)` — последовательные ответы: 1-й вызов вернёт `v1`, 2-й — `v2`, далее последнее значение.
- `thenThrow(exception)` — выбросить исключение (или `thenThrow(new RuntimeException()).thenReturn(v)` — цепочка).
- `thenAnswer(invocation -> ...)` — программный ответ с доступом к аргументам вызова (для динамики).
- `thenCallRealMethod()` — вызвать настоящий метод (актуально для spy).
- Для void-методов синтаксис другой: `doThrow(...).when(mock).voidMethod(...)`.

```java
@ExtendWith(MockitoExtension.class)
class PricingTest {
    @Mock RateService rates;

    @Test void stubbingVariants() {
        when(rates.usd()).thenReturn(90.0, 91.5);        // 1-й вызов 90, далее 91.5
        when(rates.eur()).thenThrow(new IllegalStateException("нет курса"));
        when(rates.convert(anyDouble(), eq("JPY")))
            .thenAnswer(inv -> inv.getArgument(0) * 150); // динамический расчёт

        assertEquals(90.0, rates.usd());
        assertEquals(91.5, rates.usd());
        assertEquals(150.0, rates.convert(1.0, "JPY"));
    }
}
```

Важная тонкость: аргументы в `when()` сравниваются через `equals()`. Как только вы используете **один** матчер (`any()`, `anyLong()`), **все** аргументы вызова обязаны быть матчерами — нельзя смешивать значения и матчеры (`when(repo.find("a", any()))` — ошибка); значение оборачивают в `eq("a")`.

### 14. Чем mock отличается от spy

**`mock()`** создаёт полностью фиктивный объект: все методы заглушены и возвращают дефолты, настоящий код **не выполняется никогда**. **`spy()`** оборачивает реальный объект: по умолчанию вызовы идут в настоящие методы, но отдельные методы можно выборочно заглушить и все взаимодействия можно проверить.

```java
List<String> real = new ArrayList<>();
List<String> spyList = spy(real);

spyList.add("a");                 // вызывается НАСТОЯЩИЙ add
assertEquals(1, spyList.size());  // размер действительно 1

when(spyList.size()).thenReturn(100); // выборочная заглушка поверх реального объекта
assertEquals(100, spyList.size());

List<String> mockList = mock(ArrayList.class);
mockList.add("a");                      // add заглушен, элемент НЕ добавляется
assertEquals(0, mockList.size());       // дефолт для int
```

Для spy с заглушкой важно использовать синтаксис `doReturn(...).when(spy).method()`, а не `when(spy.method()).thenReturn(...)`: второй вариант **реально вызывает метод** во время записи заглушки, что для spy может дать побочный эффект или исключение. Spy полезен для легаси-классов, где переопределить нужно один-два метода, а остальная логика должна работать по-настоящему.

### 15. Что делают аннотации @Mock, @Spy, @InjectMocks и @ExtendWith(MockitoExtension)

- **`@Mock`** — поле станет моком. Эквивалент `Mockito.mock(Class)`.
- **`@Spy`** — поле станет spy реального экземпляра (экземпляр создаётся Mockito, либо можно инициализировать поле вручную).
- **`@Captor`** — создание `ArgumentCaptor<T>` без генерика-каста.
- **`@InjectMocks`** — Mockito создаст экземпляр тестируемого класса и внедрит в него моки/spy: сначала пробует **конструктор** с наибольшим числом аргументов, затем setter-инъекцию, затем field-инъекцию. Незаполненные зависимости останутся `null` — это частая причина NPE в тестах.
- **`@ExtendWith(MockitoExtension.class)`** — расширение JUnit 5, которое инициализирует аннотированные поля перед каждым тестом (в JUnit 4 был `MockitoAnnotations.openMocks(this)` или `@RunWith(MockitoJUnitRunner.class)`). Также строго следит за неиспользованными заглушками: лишний `when(...)` без последующего вызова уронит тест (`UnnecessaryStubbingException`) — это хорошо, поддерживает тесты в чистоте.

```java
@ExtendWith(MockitoExtension.class)
class CheckoutServiceTest {
    @Mock CartRepository carts;
    @Mock PaymentGateway gateway;
    @Spy SpyableClock clock = new SpyableClock();     // частично реальный
    @InjectMocks CheckoutService service;             // carts, gateway, clock внедрятся сюда
    @Captor ArgumentCaptor<Payment> paymentCaptor;
}
```

### 16. Как использовать ArgumentMatcher и ArgumentCaptor

**Матчеры** задают условия на аргументы при stubbing и verify: `any()`, `any(Class)`, `anyInt()`, `anyLong()`, `anyString()`, `eq(value)`, `nullable(Class)` (значение или null), `argThat(predicate)` (произвольное условие), `matches(regex)`. Правило: **либо все аргументы — конкретные значения (через `equals`), либо все — матчеры**.

**`ArgumentCaptor`** нужен на этапе **проверки**: он «ловит» фактический аргумент, с которым был вызван мок, чтобы затем ассертить его поля. Классический паттерн для проверки вызова в сторонний сервис.

```java
@Test void sendsConfirmationEmail() {
    service.completeOrder(order);

    verify(mailSender).send(paymentCaptor.capture());  // ловим аргумент
    Payment sent = paymentCaptor.getValue();
    assertAll(
        () -> assertEquals(order.id(), sent.orderId()),
        () -> assertEquals(TOTAL, sent.amount())
    );
}

@Test void matcherExample() {
    when(repo.findByName(argThat(n -> n != null && n.length() > 2)))
        .thenReturn(List.of(new User()));
    verify(repo, never()).deleteById(anyLong()); // условие на аргумент
}
```

Разница в назначении: матчер — «при каком аргументе сработает заглушка/проверка», каптор — «с каким аргументом реально вызвался метод».

### 17. Как проверять вызовы (verify): times, never, atLeast, inOrder

`verify(mock, mode).method(args)` проверяет, что взаимодействие произошло. Режимы (`VerificationMode`):

- `times(n)` — ровно n раз (по умолчанию, `verify(m).x()` ≡ `times(1)`).
- `never()` — ни разу.
- `atLeast(n)` / `atLeastOnce()` — не меньше n раз.
- `atMost(n)` — не больше n раз.
- `only()` — метод был единственным взаимодействием с моком.
- `inOrder(...)` — проверка порядка вызовов между методами/моками.
- `timeout(100)` — дождаться вызова асинхронно до 100 мс (для конкурентных тестов).
- `verifyNoInteractions(mock)`, `verifyNoMoreInteractions(mock)` — отсутствие взаимодействий.

```java
@Test void verificationModes() {
    service.retry(order); // внутри: шлюз зовётся дважды, аудит — один раз

    verify(gateway, times(2)).charge(order);
    verify(gateway, never()).refund(any());
    verify(audit, atLeastOnce()).log(any());

    InOrder inOrder = inOrder(gateway, audit);
    inOrder.verify(gateway).charge(order);  // сначала оплата,
    inOrder.verify(audit).log(any());       // потом аудит

    verifyNoMoreInteractions(gateway);      // других вызовов шлюза не было
}
```

Не злоупотребляйте verify: проверка «метод вызван» имеет смысл для побочных эффектов (отправка письма, запись в БД через gateway). Для чистых функций проверяйте результат, а не внутренние вызовы — иначе тесты сломаются при любом рефакторинге.

### 18. Как заглушить и проверить void-методы (doThrow, doAnswer, doNothing)

Синтаксис `when(mock.method())` не работает для void-методов (нечего возвращать), поэтому у Mockito семейство **`doXxx(...).when(mock).voidMethod(args)`**:

- `doThrow(ex).when(mock).voidMethod(...)` — выбросить исключение.
- `doNothing().when(mock).voidMethod(...)` — явно ничего не делать (для spy: подавить реальный метод).
- `doAnswer(inv -> { sideEffect(); return null; }).when(mock).voidMethod(...)` — выполнить действие при вызове.
- `doCallRealMethod().when(mock).voidMethod(...)` — вызвать настоящий метод.

```java
@Test void voidStubbing() {
    doThrow(new MailException("SMTP недоступен"))
        .when(mailSender).send(any());

    assertThatThrownBy(() -> service.register(user))
        .isInstanceOf(MailException.class);

    // Для spy: подавляем реальную запись
    doNothing().when(auditSpy).write(any());
    service.process(order); // auditSpy.write не выполнит реальную запись
}
```

Обратная сторона — **перехват исключения из void-метода** тоже делается через `verify` с каптором или через `doAnswer`, где внутри `Answer` можно зафиксировать аргументы.

### 19. Как мокать статические методы и final классы

До Mockito 5 статические и final-члены считались «нельзя мокать»: генерируемый прокси не мог переопределить `final`-методы. Решения:

1. **Mockito 5+ (`mockito-core`)** — инлайн-мокмейкер включён по умолчанию: final-классы/методы мокаются как обычные.
2. **`mockito-inline`** (для Mockito 3.4–4.x) — тот же inline-мокмейкер как отдельный артефакт.
3. **`Mockito.mockStatic()`** — мок статического метода в рамках области видимости (обязательно закрывать — лучше try-with-resources).
4. **Рефакторинг** (лучший способ): обернуть статику в зависимость с интерфейсом и мокать её — код становится тестируемым без магии.

```java
@Test void staticMocking() {
    try (MockedStatic<Instant> instantMock = mockStatic(Instant.class)) {
        instantMock.when(Instant::now).thenReturn(FIXED);
        assertEquals(FIXED, Clock.now());          // внутри теста время заморожено
    }
    // вне блока Instant::now работает по-настоящему
}
```

`mockStatic` заглушает **все** статические методы класса; для выборочного вызова реальных используйте `instantMock.when(Instant::now).callRealMethod()`. Злоупотреблять не стоит: мок статики — признак плохого дизайна; в Spring-коде время лучше получать через `Clock`-бин (и `Clock.fixed` в тестах).

### 20. Что такое Testcontainers и зачем он нужен

**Testcontainers** — библиотека, которая поднимает для тестов реальные инфраструктурные сервисы (PostgreSQL, Redis, Kafka, LocalStack) в **Docker-контейнерах**, управляя их жизненным циклом из кода теста. Это решает главную проблему интеграционных тестов: вместо H2/mocked-репозиториев тест работает с той же СУБД, что и в проде, со всеми её особенностями (диалект SQL, MVCC, индексы, расширения).

```java
@Testcontainers
class UserRepositoryIT {
    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("test").withUsername("t").withPassword("t");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }

    @Test void savesAndReadsUser(@Autowired UserRepository repo) {
        repo.save(new UserEntity("Anna"));
        assertThat(repo.findByName("Anna")).isPresent();
    }
}
```

Ключевые практики: singleton-контейнер на весь прогон (`static` + переиспользование), `@DynamicPropertySource` для передачи URL в Spring, ready-check (`waitingFor(Wait.forListeningPort())`). Альтернатива с Spring Boot 3.1+: `@ServiceConnection` — автоконфигурация DataSource по аннотированному контейнеру без ручных свойств.

### 21. Какие срезы тестов есть в Spring Boot (@SpringBootTest, @WebMvcTest, @DataJpaTest, @JsonTest)

**Тестовые срезы (test slices)** поднимают только нужную часть Spring-контекста, что ускоряет тесты в разы:

- **`@SpringBootTest`** — полный контекст приложения (или его части с `webEnvironment`): для тяжёлых интеграционных тестов. `webEnvironment = MOCK` (по умолчанию, MockMvc), `RANDOM_PORT` (реальный сервер + `TestRestTemplate`).
- **`@WebMvcTest(Controller.class)`** — только web-слой: контроллер, `@ControllerAdvice`, валидация. Сервисы и репозитории **не** поднимаются — их мокают `@MockBean`. Используется с `MockMvc`.
- **`@DataJpaTest`** — только JPA: `EntityManager`, репозитории, встроенная/H2- или Testcontainers-БД. По умолчанию каждая транзакция откатывается после теста.
- **`@DataRedisTest`**, **`@JdbcTest`**, **`@MybatisTest`** — аналогичные срезы для других технологий.
- **`@JsonTest`** — сериализация/десериализация Jackson (ObjectMapper бин).

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {
    @Autowired MockMvc mvc;
    @MockBean OrderService service;   // заменяет бин в контексте

    @Test void returnsOrder() throws Exception {
        when(service.find(5L)).thenReturn(new OrderDto(5L, "NEW"));
        mvc.perform(get("/api/orders/5").accept(MediaType.APPLICATION_JSON))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.id").value(5))
           .andExpect(jsonPath("$.status").value("NEW"));
    }
}
```

Правило выбора: логика — юнит-тест без Spring; web-контракт — `@WebMvcTest`; запросы к БД — `@DataJpaTest` (+ Testcontainers); сквозной сценарий — `@SpringBootTest`.

### 22. Чем @MockBean отличается от @Mock

- **`@Mock` (Mockito)** — чистый мок вне Spring-контекста; работает с `@ExtendWith(MockitoExtension.class)`. Быстро, без поднятия ApplicationContext.
- **`@MockBean` (Spring Boot)** — создаёт мок и **регистрирует его в ApplicationContext**, заменяя существующий бин того же типа (или добавляя, если бина нет). Нужен, когда тест поднимает контекст (`@SpringBootTest`, `@WebMvcTest`) и внутри него зависимость надо подменить. Контекст с `@MockBean` кэшируется отдельно от контекста без него — это влияет на скорость.
- В Spring Boot 3.4+ `@MockBean` объявлен deprecated в пользу **`@MockitoBean`** (из пакета `org.springframework.test.context.bean.override.mockito`) — та же семантика, унифицированный механизм bean-override.

```java
@SpringBootTest
class FullContextTest {
    @MockitoBean NotificationClient notifications; // подмена бина в контексте

    @Test void flow() {
        given(notifications.notify(any())).willReturn(true);
        // весь контекст настоящий, только NotificationClient — мок
    }
}
```

Типичная ошибка — использовать `@Mock` в `@WebMvcTest`: контекст не узнает о моке, контроллер получит реальный (или отсутствующий) бин и тест упадёт с `NoSuchBeanDefinitionException`.

### 23. Как протестировать REST-контроллер через MockMvc

`MockMvc` имитирует HTTP-запросы без реального сетевого стека (или поверх живого сервера при `RANDOM_PORT`). Схема теста: подготовка моков сервиса → `perform(request)` → каскад `andExpect`.

```java
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired MockMvc mvc;
    @MockBean UserService users;
    @Autowired ObjectMapper json;   // для сериализации тела

    @Test void createReturns201AndLocation() throws Exception {
        UserDto req = new UserDto("Anna", "anna@x.io");
        given(users.create(any())).willReturn(new UserDto(7L, "Anna", "anna@x.io"));

        mvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(req)))
            .andExpect(status().isCreated())
            .andExpect(header().string("Location", "/api/users/7"))
            .andExpect(jsonPath("$.id").value(7));

        then(users).should().create(argThat(u -> "Anna".equals(u.name())));
    }

    @Test void invalidBodyGives400WithFieldErrors() throws Exception {
        mvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"\",\"email\":\"bad\"}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors.name").exists()); // от @Valid + @ControllerAdvice
    }
}
```

Полезные матчеры: `jsonPath("$.a[0].b")`, `content().string(...)`, `model()`, `flash()`. Для проверки ошибок валидации отдельный тест обязателен — это самый частый контракт фронта и бэка.

### 24. Как тестировать асинхронный код и что такое покрытие (JaCoCo)

**Асинхронность.** `Thread.sleep()` в тестах — антипаттерн: медленно и нестабильно. Инструменты:

- **Awaitility** — DSL-ожидание условия с таймаутом и поллингом.
- `CompletableFuture` — возвращайте future из тестируемого метода и ассерьте `get(1, SECONDS)`.
- Mockito `verify(mock, timeout(500))` — дождаться вызова мока.

```java
@Test void asyncProcessing() {
    service.processAsync(order);                 // внутри @Async / пул потоков

    await().atMost(Duration.ofSeconds(2))
           .with().pollInterval(Duration.ofMillis(50))
           .untilAsserted(() ->
               verify(repository).markDone(order.id())); // условие, а не сон
}
```

**Покрытие кода** измеряет, какие строки/ветки исполнились в тестах. Инструмент в Java-экосистеме — **JaCoCo** (maven/gradle-плагин, отчёт HTML/XML, гейты в CI). Метрики: line, branch, instruction coverage. Важно понимать: **покрытие — индикатор непротестированного кода, а не качества тестов**. 100% строк может означать тесты без ассертов; 70% с сильными ассертами на бизнес-логике ценнее, чем 95% формальных. Разумная практика: требовать высокий порог на новом коде (diff coverage) и не гнаться за общими 100%.

