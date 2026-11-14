# Java Core — тонкости

### 1. Может ли enum реализовать интерфейс

Да, enum может реализовать любой интерфейс (или несколько). Это частый паттерн для «стратегий» и «констант с поведением»:

```java
public interface Operation {
    int apply(int a, int b);
}

public enum MathOp implements Operation {
    ADD { public int apply(int a, int b) { return a + b; } },
    SUB { public int apply(int a, int b) { return a - b; } },
    MUL { public int apply(int a, int b) { return a * b; } };
}

// Использование:
int result = MathOp.ADD.apply(5, 3); // 8
```

Каждое значение enum может иметь своё тело метода — это делает enum «полноценным» объектом с поведением.

### 2. Может ли enum наследоваться от другого enum или класса

Нет. Enum **не может наследоваться** ни от другого enum, ни от обычного класса. Причины:

- **Все enum неявно наследуются от `java.lang.Enum<E>`** — это базовый класс, и в Java нет множественного наследования классов.
- **Каждый enum неявно `final`** — его нельзя расширить.
- **Нельзя создать подкласс enum** — компилятор не даст.

```java
// ❌ Ошибка: enum не может наследоваться
enum Color extends BaseEnum {}  // compile error
enum Color extends SomeClass {} // compile error

// ✅ Правильно: enum реализует интерфейс
interface Colorable { String name(); }
enum Color implements Colorable {
    RED { public String name() { return "red"; } },
    BLUE { public String name() { return "blue"; } };
}
```

### 3. Почему все значения enum final

Каждое значение enum — это **singleton** (одиночка). Это гарантирует:
- **Идентичность**: `Color.RED == Color.RED` всегда `true`.
- **Безопасность в concurrency**: значения enum не меняются после создания.
- **Hashable**: `hashCode()` и `equals()` работают на основе `ordinal()` (порядкового номера) — быстро и предсказуемо.

```java
Color c1 = Color.RED;
Color c2 = Color.RED;
System.out.println(c1 == c2);       // true (одинаковый объект)
System.out.println(c1.equals(c2));  // true
System.out.println(c1.hashCode());  // 0 (ordinal)
```

### 4. Что такое ordinal() и когда его НЕ использовать

`ordinal()` возвращает порядковый номер значения в enum (начиная с 0). **Не рекомендуется** использовать `ordinal()` как:
- **Ключ для хранения** (в БД, в конфигурации) — если порядок значений изменится, данные «сдвинутся».
- **Идентификатор** в API — клиент не должен знать про внутреннюю нумерацию.

```java
enum Status {
    NEW,       // ordinal = 0
    ACTIVE,    // ordinal = 1
    CLOSED;    // ordinal = 2
}

// ❌ Плохо: зависимость от ordinal
int dbStatus = Status.ACTIVE.ordinal(); // 1
// Если в будущем добавим Status.PENDING перед ACTIVE — dbStatus станет неверным

// ✅ Хорошо: явный код
int code;
Status status;
switch (status) {
    case NEW -> code = 0;
    case ACTIVE -> code = 1;
    case CLOSED -> code = 2;
}
```

### 5. Как enum поддерживает switch (и почему это работает)

Enum работает в `switch` потому, что каждый компилируется в **int-константу** (ordinal). Компилятор генерирует `tableswitch` или `lookupswitch` — быстрый прыжок по индексу.

```java
enum Day { MON, TUE, WED, THU, FRI, SAT, SUN }

Day day = Day.WED;
switch (day) {
    case MON, TUE, WED, THU, FRI -> System.out.println("Workday");
    case SAT, SUN -> System.out.println("Weekend");
}
```

### 6. Что такое abstract-методы в enum

Enum может содержать **абстрактные методы**, которые каждое значение обязано реализовать. Это делает enum «обязывающим»:

```java
public enum Operation {
    ADD { public int apply(int a, int b) { return a + b; } },
    SUB { public int apply(int a, int b) { return a - b; } },
    MUL { public int apply(int a, int b) { return a * b; } };

    // Абстрактный метод — каждое значение должно реализовать
    public abstract int apply(int a, int b);
}
```

Если какое-то значение не реализует метод — **ошибка компиляции**.

### 7. Можно ли добавить поля и конструктор в enum

Да, enum поддерживает **поля** и **конструктор** (приватный по умолчанию):

```java
public enum Plan {
    FREE(0, "Free", 1),
    PRO(10, "Pro", 10),
    ENTERPRISE(50, "Enterprise", 1000);

    private final int pricePerUser;
    private final String name;
    private final int maxUsers;

    Plan(int price, String name, int maxUsers) {
        this.pricePerUser = price;
        this.name = name;
        this.maxUsers = maxUsers;
    }

    public int getPricePerUser() { return pricePerUser; }
    public String getName() { return name; }
    public int getMaxUsers() { return maxUsers; }
}

// Использование:
Plan p = Plan.PRO;
System.out.println(p.getPricePerUser()); // 10
System.out.println(p.getName());         // "Pro"
```

### 8. Что такое singleton-pattern в enum

Enum — это **встроенный singleton** в Java. Каждое значение создаётся **один раз** при загрузке класса и переиспользуется:

```java
// Каждое значение — singleton
Config config1 = Config.INSTANCE;
Config config2 = Config.INSTANCE;
System.out.println(config1 == config2); // true

// Enum безопасен в multi-thread без synchronized
enum Singleton {
    INSTANCE;
    // ... поля и методы
}
```

Это **лучше**, чем классический singleton (`private static final` + `private` конструктор + `getInstance()`), потому что:
- **Serializing**: enum автоматически корректно сериализуется (не создаёт дубликат).
- **Reflection**: enum защищён от создания дополнительных экземпляров через reflection.
- **Simplicity**: нет boilerplate-кода.

### 9. Можно ли переопределить hashCode() и equals() в enum

**Нельзя** — и не нужно. Enum уже имеет корректные реализации:
- **`equals()`**: сравнивает по идентичности (`==`) — быстро, O(1).
- **`hashCode()`**: возвращает `ordinal()` — предсказуемо, O(1).

```java
// Enum уже корректен для Map/Set
Map<Color, String> colorNames = new HashMap<>();
colorNames.put(Color.RED, "Red");
colorNames.put(Color.RED, "Red"); // Не дублирует (equals работает)
```

### 10. Что такое static-инициализация enum и когда она выполняется

Все значения enum создаются **при загрузке класса** (статическая инициализация). Это происходит **один раз** при первом обращении к enum:

```java
public enum Heavy {
    A(1000),
    B(2000),
    C(3000);

    private final int value;

    Heavy(int value) {
        // Этот конструктор вызывается при загрузке класса Heavy
        // (при первом обращении к Heavy.A, Heavy.B, или Heavy.C)
        System.out.println("Initializing " + value);
        this.value = value;
    }

    public int getValue() { return value; }
}

// При первом обращении:
Heavy h = Heavy.A;
// Вывод: "Initializing 1000", "Initializing 2000", "Initializing 3000"
```

**Важно**: если в конструкторе есть дорогая операция (создание объекта, чтение файла) — она выполнится **при загрузке класса**, а не при создании экземпляра. Это может замедлить старт приложения.

### 11. Как enum работает с generics

Enum может быть **параметризован** (generic enum), но только через **свой тип**:

```java
// ❌ Нельзя: enum не может быть generic-классом
enum MyEnum<T> { ... } // compile error

// ✅ Можно: enum реализует generic-интерфейс
interface Wrapper<T> { T get(); }
enum ColorWrapper implements Wrapper<String> {
    RED("red"),
    BLUE("blue");

    private final String value;
    ColorWrapper(String value) { this.value = value; }
    public String get() { return value; }
}
```

### 12. Что такое values() и valueOf()

- **`values()`**: возвращает массив всех значений enum (в порядке объявления). Создаёт **новый массив** при каждом вызове — не кэшируйте.
- **`valueOf(String)`**: находит значение по имени (case-sensitive). Бросает `IllegalArgumentException`, если не найдено.

```java
enum Status { NEW, ACTIVE, CLOSED }

// values()
Status[] all = Status.values(); // [NEW, ACTIVE, CLOSED]
for (Status s : all) {
    System.out.println(s);
}

// valueOf()
Status s = Status.valueOf("ACTIVE"); // OK
Status t = Status.valueOf("active"); // IllegalArgumentException (case-sensitive)
```

### 13. Можно ли создать «пустое» enum (без значений)

Нет, enum должен иметь **хотя бы одно** значение. Пустой enum — ошибка компиляции:

```java
// ❌ Ошибка: enum должен иметь значения
enum Empty { } // compile error

// ✅ Минимальный enum
enum Empty { NONE }
```

### 14. Как enum взаимодействует с serialization

Enum **автоматически сериализуется** корректно: при десериализации создаётся **тот же самый** singleton (не дубликат). Это делает enum **безопасным** для network, RMI, JPA:

```java
// При сериализации
ObjectOutputStream oos = new ObjectOutputStream(...);
oos.writeObject(Color.RED);
// Сохраняется: класс + имя ("RED")

// При десериализации
ObjectInputStream ois = new ObjectInputStream(...);
Color c = (Color) ois.readObject();
System.out.println(c == Color.RED); // true (тот же singleton)
```

### 15. Что такое EnumSet и EnumMap

`EnumSet` и `EnumMap` — оптимизированные реализации `Set` и `Map` для ключей-enum:

```java
// EnumSet — битовая маска, очень быстро
EnumSet<Status> statuses = EnumSet.of(Status.NEW, Status.ACTIVE);
statuses.add(Status.CLOSED);
statuses.remove(Status.NEW);
System.out.println(statuses.contains(Status.ACTIVE)); // true

// EnumMap — массив по ordinal, очень быстро
EnumMap<Status, Integer> counts = new EnumMap<>(Status.class);
counts.put(Status.NEW, 10);
counts.put(Status.ACTIVE, 20);
System.out.println(counts.get(Status.NEW)); // 10

// Преимущества:
// - EnumSet: O(1) для add/remove/contains (битовая маска)
// - EnumMap: O(1) для get/put (массив по ordinal)
// - Меньше памяти, чем HashSet/HashMap
```

### 16. Что такое sealed class (Java 17+)

Sealed class — класс, который **ограничивает** свои подклассы перечислением:

```java
public sealed class Shape permits Circle, Square, Triangle {
    public abstract double area();
}

public final class Circle extends Shape {
    private final double radius;
    public Circle(double radius) { this.radius = radius; }
    public double area() { return Math.PI * radius * radius; }
}

public final class Square extends Shape {
    private final double side;
    public Square(double side) { this.side = side; }
    public double area() { return side * side; }
}

// Только Circle, Square, Triangle могут наследоваться от Shape
// Любой другой класс — compile error
```

Sealed class похож на enum, но:
- **Enum**: фиксированный набор значений (singleton).
- **Sealed class**: фиксированный набор подклассов (каждый подкласс может иметь свои экземпляры).

### 17. Что такое record (Java 16+) и чем отличается от enum

Record — **неизменяемый** контейнер для данных:

```java
public record Point(int x, int y) {
    // Автоматически генерируется:
    // - Поля x, y (private final)
    // - Конструктор Point(int x, int y)
    // - Getters: x(), y()
    // - equals(), hashCode(), toString()
}

Point p1 = new Point(1, 2);
Point p2 = new Point(1, 2);
System.out.println(p1.equals(p2)); // true (сравнение по полям)
```

**Разница:**
- **Enum**: фиксированный набор singleton'ов.
- **Record**: неизменяемый контейнер для произвольных данных (может быть множество экземпляров).

### 18. Что такое sealed interface (Java 17+)

Sealed interface — интерфейс с ограниченным набором реализаций:

```java
public sealed interface Expression permits Number, Sum { }

public final record Number(int value) implements Expression { }

public final record Sum(Expression left, Expression right) implements Expression { }

// Только Number и Sum могут реализовывать Expression
// pattern matching в switch:
int evaluate(Expression e) {
    return switch (e) {
        case Number n -> n.value();
        case Sum s -> evaluate(s.left()) + evaluate(s.right());
    };
}
```

### 19. Что такое pattern matching для switch (Java 21+)

Pattern matching позволяет использовать `instanceof` и `switch` с автоматическим приведением типа:

```java
Object obj = ...;

// instanceof pattern matching (Java 16+)
if (obj instanceof String s) {
    System.out.println(s.length()); // s — String, без приведения
}

// switch pattern matching (Java 21+)
switch (obj) {
    case String s -> System.out.println("String: " + s.length());
    case Integer i -> System.out.println("Integer: " + i);
    case Double d -> System.out.println("Double: " + d);
    case null -> System.out.println("null");
    default -> System.out.println("Unknown: " + obj.getClass());
}
```

### 20. Что такое virtual threads (Java 21+)

Virtual threads — **лёгкие** потоки, управляемые JVM (не ОС). Они позволяют создавать **миллионы** потоков без overhead:

```java
// Создание virtual thread
Thread.startVirtualThread(() -> {
    // Лёгкий поток — JVM управляет им
    System.out.println("Running in virtual thread");
});

// ExecutorService с virtual threads
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 100_000; i++) {
        executor.submit(() -> {
            // 100 000 concurrent tasks
            doWork();
        });
    }
}

// Преимущества:
// - Миллионы потоков без memory overhead
// - Идеально для I/O-bound задач (HTTP, DB, file I/O)
// - Не подходят для CPU-bound (blocking operations)
```

### 21. Что такое records с compact constructor

Record поддерживает **compact constructor** — упрощённый синтаксис для инициализации:

```java
public record Range(int start, int end) {
    // Compact constructor — аргументы уже доступны
    Range {
        if (start > end) {
            throw new IllegalArgumentException("start > end");
        }
    }

    // Или с модификацией полей
    Range {
        if (start < 0) start = 0;
        if (end > 100) end = 100;
    }
}

// Использование:
Range r1 = new Range(10, 20);  // OK
Range r2 = new Range(50, 10);  // IllegalArgumentException
Range r3 = new Range(-5, 150); // [0, 100] (clamp)
```

### 22. Что такое sealed class с pattern matching

Sealed class + pattern matching = **исчерпывающий switch** без `default`:

```java
public sealed interface Shape permits Circle, Square, Triangle {
    double area();
}

public record Circle(double radius) implements Shape {
    public double area() { return Math.PI * radius * radius; }
}

public record Square(double side) implements Shape {
    public double area() { return side * side; }
}

public record Triangle(double base, double height) implements Shape {
    public double area() { return 0.5 * base * height; }
}

// Исчерпывающий switch — компилятор знает все варианты
String describe(Shape shape) {
    return switch (shape) {
        case Circle c -> "Circle with radius " + c.radius();
        case Square s -> "Square with side " + s.side();
        case Triangle t -> "Triangle with base " + t.base();
        // Нет default — компилятор проверит, что все варианты покрыты
    };
}
```

### 23. Что такое instanceof pattern matching (Java 16+)

`instanceof` с pattern matching убирает необходимость в явном приведении типа:

```java
// До (Java 15):
if (obj instanceof String) {
    String s = (String) obj; // Явное приведение
    System.out.println(s.length());
}

// После (Java 16+):
if (obj instanceof String s) {
    System.out.println(s.length()); // s уже String
}

// Сложные условия:
if (obj instanceof String s && s.length() > 0) {
    System.out.println(s.toUpperCase());
}
```

### 24. Что такое switch pattern matching (Java 21+)

Switch pattern matching позволяет использовать pattern matching в switch:

```java
Object obj = getSomething();

switch (obj) {
    case null -> System.out.println("null");
    case Integer i -> System.out.println("Integer: " + i);
    case Long l -> System.out.println("Long: " + l);
    case String s -> System.out.println("String: " + s.length());
    case Double d -> System.out.println("Double: " + d);
    default -> System.out.println("Unknown: " + obj.getClass());
}

// С sealed interface — без default:
Shape shape = getShape();
switch (shape) {
    case Circle c -> processCircle(c);
    case Square s -> processSquare(s);
    case Triangle t -> processTriangle(t);
}
```

### 25. Что такое record pattern (Java 21+)

Record pattern позволяет **распаковать** record на компоненты:

```java
public record Point(int x, int y) { }
public record Line(Point start, Point end) { }

Line line = new Line(new Point(0, 0), new Point(10, 10));

// Record pattern — распаковка
switch (line) {
    case Line(Point(x1, y1), Point(x2, y2)) -> {
        System.out.println("Start: (" + x1 + ", " + y1 + ")");
        System.out.println("End: (" + x2 + ", " + y2 + ")");
    }
}

// В instanceof:
if (obj instanceof Line(Point(x1, y1), Point(x2, y2))) {
    System.out.println("Length: " + Math.sqrt((x2-x1)^2 + (y2-y1)^2));
}
```

### 26. Что такое sealed class в иерархии

Sealed class может быть частью **иерархии**:

```java
public sealed abstract class Expression permits Number, Sum, Product { }

public record Number(int value) extends Expression { }

public record Sum(Expression left, Expression right) extends Expression { }

public record Product(Expression left, Expression right) extends Expression { }

// Pattern matching для evaluation:
int eval(Expression e) {
    return switch (e) {
        case Number n -> n.value();
        case Sum s -> eval(s.left()) + eval(s.right());
        case Product p -> eval(p.left()) * eval(p.right());
    };
}

// Использование:
Expression expr = new Sum(new Number(5), new Product(new Number(2), new Number(3)));
System.out.println(eval(expr)); // 11
```

### 27. Что такое non-sealed class

Non-sealed class — класс, который **раскрывает** иерархию (разрешает наследование другим классам):

```java
public sealed abstract class Shape permits Circle, Square, OpenShape { }

public record Circle(double radius) extends Shape { }
public record Square(double side) extends Shape { }

// OpenShape — non-sealed, можно наследоваться
public non-sealed class OpenShape extends Shape { }

// Теперь можно создать подкласс OpenShape
public class Triangle extends OpenShape { }
public class Hexagon extends OpenShape { }
```

### 28. Что такое class pattern (Java 21+)

Class pattern — pattern matching для обычных классов (не только record):

```java
public abstract class Event {
    public abstract long timestamp();
}

public record LoginEvent(long timestamp, String user) extends Event {
    public long timestamp() { return timestamp; }
}

public record LogoutEvent(long timestamp, String user) extends Event {
    public long timestamp() { return timestamp; }
}

// Pattern matching
void process(Event e) {
    if (e instanceof LoginEvent le) {
        System.out.println("Login: " + le.user() + " at " + le.timestamp());
    } else if (e instanceof LogoutEvent le) {
        System.out.println("Logout: " + le.user() + " at " + le.timestamp());
    }
}
```

### 29. Что такое guard conditions в switch pattern matching

Guard conditions — дополнительные условия в case:

```java
switch (obj) {
    case Integer i when i > 0 -> System.out.println("Positive: " + i);
    case Integer i when i < 0 -> System.out.println("Negative: " + i);
    case Integer i -> System.out.println("Zero"); // i == 0
    case null -> System.out.println("null");
    default -> System.out.println("Unknown");
}
```

### 30. Что такое type testing в pattern matching

Type testing — проверка типа в pattern:

```java
// instanceof — type testing
if (obj instanceof String s) {
    // s — String
}

// Switch — type testing
switch (obj) {
    case String s -> { /* s — String */ }
    case Integer i -> { /* i — Integer */ }
}
```

### 31. Что такое destructuring pattern

Destructuring pattern — распаковка объекта на компоненты:

```java
// Record pattern
case Point(x, y) -> { /* x, y — int */ }

// Nested record pattern
case Line(Point(x1, y1), Point(x2, y2)) -> {
    /* x1, y1, x2, y2 — int */
}

// В массиве
int[] coords = {10, 20};
if (coords instanceof int[]{x, y}) {
    System.out.println("x=" + x + ", y=" + y);
}
```

### 32. Что такое null pattern в switch

Null pattern — явная проверка на null в switch (Java 21+):

```java
switch (obj) {
    case null -> System.out.println("null");
    case Integer i -> System.out.println("Integer: " + i);
    case String s -> System.out.println("String: " + s);
    default -> System.out.println("Unknown");
}
```

### 33. Что такое exhaustiveness в pattern matching

Exhaustiveness — проверка, что все возможные значения покрыты:

```java
// Sealed interface — компилятор знает все варианты
sealed interface Color permits Red, Green, Blue { }

// Исчерпывающий switch — без default
String colorName(Color c) {
    return switch (c) {
        case Red r -> "Red";
        case Green g -> "Green";
        case Blue b -> "Blue";
        // Нет default — компилятор проверит, что все варианты покрыты
        // Если добавим новый вариант в permits — compile error
    };
}
```

### 34. Что такое virtual threads и platform threads

Virtual threads (Java 21+) vs platform threads:

| | Virtual threads | Platform threads |
|---|---|---|
| **Управление** | JVM | ОС |
| **Количество** | Миллионы | Сотни (ограничено памятью) |
| **Память** | ~KB на поток | ~MB на поток (stack) |
| **Blocking** | Блокирует только virtual thread | Блокирует platform thread |
| **I/O-bound** | Идеально | Нормально |
| **CPU-bound** | Не подходит | Хорошо |

```java
// Virtual threads
Thread.startVirtualThread(() -> {
    // Лёгкий поток
    doIO();
});

// Platform threads (по умолчанию)
Thread thread = new Thread(() -> {
    // Тяжёлый поток
    doCPU();
});
thread.start();
```

### 35. Что такое Structured Concurrency (Java 21+)

Structured Concurrency — API для управления структурированным concurrency:

```java
// Sequentially — последовательно
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    Supplier<String> user = scope.fork(() -> fetchUser());
    Supplier<String> orders = scope.fork(() -> fetchOrders());
    scope.join(); // Дождаться завершения всех
    scope.throwIfFailed(); // Бросить исключение, если есть
    return user.get() + " " + orders.get();
}

// ShutdownOnFailure — остановить всё, если одна задача упала
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    var task1 = scope.fork(() -> doTask1());
    var task2 = scope.fork(() -> doTask2());
    scope.join();
    scope.throwIfFailed();
}
```

### 36. Что такое CompletableFuture с virtual threads

CompletableFuture можно использовать с virtual threads:

```java
// С virtual threads
CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
    // Выполняется в virtual thread
    return doIO();
}, Executors.newVirtualThreadPerTaskExecutor());

// Chain
CompletableFuture<String> result = future
    .thenApply(s -> transform(s))
    .thenCombine(otherFuture, (s, t) -> combine(s, t));
```

### 37. Что такое thread pinning с virtual threads

Thread pinning — проблема, когда virtual thread **блокирует** platform thread:

```java
// ❌ Thread pinning: synchronized блокирует platform thread
synchronized (lock) {
    doIO(); // Virtual thread блокирует platform thread
}

// ✅ Решение: ReentrantLock вместо synchronized
ReentrantLock lock = new ReentrantLock();
lock.lock();
try {
    doIO(); // Virtual thread может unmount с carrier thread
} finally {
    lock.unlock();
}
```

### 38. Что такое try-with-resources с virtual threads

Try-with-resources корректно закрывает ресурсы:

```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 1000; i++) {
        executor.submit(() -> doWork());
    }
} // executor.shutdown() вызывается автоматически
```

### 39. Что такое ScopedValue (Java 21+)

ScopedValue — альтернатива ThreadLocal для virtual threads:

```java
// ThreadLocal — не масштабируется на миллионы virtual threads
ThreadLocal<String> context = new ThreadLocal<>();

// ScopedValue — масштабируется
ScopedValue<String> context = ScopedValue.newInstance();

try (var scope = ScopedValue.open(context, "value")) {
    // Внутри scope — context.get() = "value"
    doWork();
} // Вне scope — context не задан
```

### 40. Что difference между ThreadLocal и ScopedValue

| | ThreadLocal | ScopedValue |
|---|---|---|
| **Создание** | Для каждого потока | Общий для всех потоков в scope |
| **Память** | Оверhead на поток | Минимальный |
| **Virtual threads** | Не масштабируется | Масштабируется |
| **Имутабельность** | Можно менять | Read-only |
| **Использование** | Legacy code | Новый код (Java 21+) |

### 41. Что такое value-based classes

Value-based classes — классы, которые сравниваются по **значению** (не по идентичности):

```java
// Record — value-based
record Point(int x, int y) { }
Point p1 = new Point(1, 2);
Point p2 = new Point(1, 2);
System.out.println(p1.equals(p2)); // true

// Class — не value-based
class Point {
    int x, y;
    // equals() нужно писать вручную
}
```

### 42. Что такое identity vs equality

Identity (`==`) vs equality (`equals()`):

```java
Object a = new Object();
Object b = a;
Object c = new Object();

// Identity
System.out.println(a == b); // true (тот же объект)
System.out.println(a == c); // false (разные объекты)

// Equality
System.out.println(a.equals(b)); // true (по умолчанию — identity)
System.out.println(a.equals(c)); // false
```

### 43. Что такое hashCode contract

Contract для `hashCode()`:
1. Если `a.equals(b)`, то `a.hashCode() == b.hashCode()`.
2. Если `a.hashCode() == b.hashCode()`, то `a` **не обязательно** равен `b` (collision).

```java
// Нарушение contract:
class Bad {
    int x;
    @Override
    public boolean equals(Object o) {
        return o instanceof Bad && x == ((Bad)o).x;
    }
    @Override
    public int hashCode() {
        return new Random().nextInt(); // ❌ Разные hashCode для равных объектов
    }
}
```

### 44. Что такое String interning

String interning — механизм, при котором одинаковые строки **разделяют** один объект в памяти:

```java
String s1 = "hello";
String s2 = "hello";
String s3 = new String("hello");

System.out.println(s1 == s2); // true (interned)
System.out.println(s1 == s3); // false (new String)
System.out.println(s3.intern() == s1); // true (после intern)
```

### 45. Что такое StringBuilder vs StringBuffer

| | StringBuilder | StringBuffer |
|---|---|---|
| **Thread-safe** | Нет | Да (synchronized) |
| **Производительность** | Быстрее | Медленнее |
| **Использование** | Single-thread | Multi-thread |

```java
// StringBuilder (single-thread)
StringBuilder sb = new StringBuilder();
sb.append("Hello");
sb.append(" ");
sb.append("World");

// StringBuffer (multi-thread)
StringBuffer sb = new StringBuffer();
sb.append("Hello");
```

### 46. Что такое StringPool

StringPool — область памяти, где хранятся interned строки:

```java
// String literals попадают в StringPool
String s1 = "hello"; // В StringPool

// new String() — не в StringPool (пока не intern)
String s2 = new String("hello"); // Не в StringPool

// intern() — помещает в StringPool
String s3 = s2.intern(); // Теперь в StringPool
System.out.println(s3 == s1); // true
```

### 47. Что такое CharSequence

CharSequence — интерфейс для последовательности символов:

```java
// Implementations: String, StringBuilder, StringBuffer, CharBuffer
interface CharSequence {
    int length();
    char charAt(int index);
    CharSequence subSequence(int start, int end);
}

// Можно использовать как параметр
void process(CharSequence text) {
    System.out.println(text.length());
}

process("hello"); // String
process(new StringBuilder("hello")); // StringBuilder
```

### 48. Что такое String vs StringBuilder в цикле

StringBuilder быстрее в цикле (не создаёт новые объекты):

```java
// ❌ String — создаёт N объектов
String result = "";
for (int i = 0; i < 10000; i++) {
    result += i; // Новый String на каждой итерации
}

// ✅ StringBuilder — один объект
StringBuilder sb = new StringBuilder();
for (int i = 0; i < 10000; i++) {
    sb.append(i); // Модицирует существующий объект
}
String result = sb.toString();
```

### 49. Что такое text block (Java 15+)

Text block — многострочная строка:

```java
// Обычная строка
String json = "{\"name\": \"John\", " +
              "\"age\": 30}";

// Text block
String json = """
    {
        "name": "John",
        "age": 30
    }
    """;

// С форматированием
String html = """
    <html>
        <body>
            <h1>Hello, %s</h1>
        </body>
    </html>
    """.formatted("World");
```

### 50. Что такое switch expression (Java 14+)

Switch expression — switch как выражение (возвращает значение):

```java
// Старый способ
int days;
switch (month) {
    case 1, 3, 5, 7, 8, 10, 12 -> days = 31;
    case 2 -> days = 28;
    default -> days = 30;
}

// Switch expression (Java 14+)
int days = switch (month) {
    case 1, 3, 5, 7, 8, 10, 12 -> 31;
    case 2 -> 28;
    default -> 30;
};
```

### 51. Что такое arrow syntax в switch

Arrow syntax — новый синтаксис для case:

```java
// Старый синтаксис
switch (day) {
    case MON:
    case TUE:
    case WED:
    case THU:
    case FRI:
        System.out.println("Workday");
        break;
    case SAT:
    case SUN:
        System.out.println("Weekend");
        break;
}

// Arrow syntax (Java 14+)
switch (day) {
    case MON, TUE, WED, THU, FRI -> System.out.println("Workday");
    case SAT, SUN -> System.out.println("Weekend");
}
```

### 52. Что такое yield в switch

Yield — возвращает значение из switch expression:

```java
String result = switch (obj) {
    case String s -> {
        System.out.println("Processing string");
        yield s.toUpperCase(); // Возвращает значение
    }
    case Integer i -> {
        System.out.println("Processing integer");
        yield String.valueOf(i);
    }
    default -> "Unknown";
};
```

### 53. Что такое pattern matching в instance of

Pattern matching в instanceof:

```java
// До
if (obj instanceof String) {
    String s = (String) obj;
    process(s);
}

// После
if (obj instanceof String s) {
    process(s); // s уже String
}
```

### 54. Что такое record components

Record components — поля, доступные через accessors:

```java
public record Point(int x, int y) {
    // Компоненты: x, y
    // Accessors: x(), y()
}

Point p = new Point(10, 20);
System.out.println(p.x()); // 10
System.out.println(p.y()); // 20
```

### 55. Что такое record canonical constructor

Canonical constructor — конструктор, сгенерированный для record:

```java
public record Point(int x, int y) { }

// Сгенерирован:
public Point(int x, int y) {
    this.x = x;
    this.y = y;
}

// Можно добавить compact constructor:
public record Point(int x, int y) {
    Point {
        if (x < 0) x = 0;
        if (y < 0) y = 0;
    }
}
```

### 56. Что такое record equals и hashCode

Record автоматически генерирует `equals()` и `hashCode()` по **компонентам**:

```java
public record Point(int x, int y) { }

Point p1 = new Point(1, 2);
Point p2 = new Point(1, 2);
Point p3 = new Point(3, 4);

System.out.println(p1.equals(p2)); // true (x и y равны)
System.out.println(p1.equals(p3)); // false
System.out.println(p1.hashCode() == p2.hashCode()); // true
```

### 57. Что такое record toString

Record автоматически генерирует `toString()`:

```java
public record Point(int x, int y) { }

Point p = new Point(10, 20);
System.out.println(p); // "Point[x=10, y=20]"
```

### 58. Что такое sealed class и enum

Sealed class vs enum:

| | Sealed class | Enum |
|---|---|---|
| **Цель** | Ограничить подклассы | Фиксированный набор значений |
| **Экземпляры** | Множество (в каждом подклассе) | Одиночка (singleton) |
| **Сравнение** | По значению (если record) | По идентичности |
| **Использование** | Типы данных, иерархии | Константы, стратегии |

### 59. Что такое non-sealed в sealed иерархии

Non-sealed — класс, который **раскрывает** иерархию:

```java
public sealed abstract class Shape permits Circle, OpenShape { }

public record Circle(double radius) extends Shape { }

// OpenShape — non-sealed
public non-sealed class OpenShape extends Shape { }

// Можно наследоваться от OpenShape
public class Triangle extends OpenShape { }
```

### 60. Что такое final class

Final class — класс, который **нельзя наследовать**:

```java
public final class Utils {
    public static int max(int a, int b) {
        return Math.max(a, b);
    }
}

// ❌ Ошибка: Utils — final
class MyUtils extends Utils { } // compile error
```

### 61. Что такое final method

Final method — метод, который **нельзя переопределить**:

```java
public class Base {
    public final void doWork() {
        System.out.println("Base work");
    }
}

public class Child extends Base {
    // ❌ Ошибка: doWork() — final
    @Override
    public void doWork() { } // compile error
}
```

### 62. Что такое final field

Final field — поле, которое **нельзя изменить** после инициализации:

```java
public class Config {
    private final String name;
    private final int timeout;

    public Config(String name, int timeout) {
        this.name = name;
        this.timeout = timeout;
        // После конструктора — нельзя изменить
    }

    // ❌ Ошибка: name — final
    public void setName(String name) {
        this.name = name; // compile error
    }
}
```

### 63. Что такое static final constant

Static final constant — константа (записывается в капсе):

```java
public class Constants {
    public static final int MAX_SIZE = 100;
    public static final String APP_NAME = "MyApp";
    public static final double PI = 3.14159;
}

// Использование:
System.out.println(Constants.MAX_SIZE); // 100
```

### 64. Что такое compile-time constant

Compile-time constant — значение, известное на этапе компиляции:

```java
// Compile-time constants
public static final int MAX = 100; // int, long, float, double, boolean, char, String
public static final String NAME = "App";

// Можно использовать в switch (без ошибки):
switch (MAX) {
    case 100 -> System.out.println("Max");
}

// Не compile-time constant:
public static final Random random = new Random(); // Не compile-time
```

### 65. Что такое constant folding

Constant folding — оптимизация компилятора (подстановка констант):

```java
public static final int A = 5;
public static final int B = 10;

int sum = A + B; // Компилятор заменит на 15

// В bytecode:
int sum = 15; // A и B вlined
```

### 66. Что такое inlining

Inlining — подстановка значения константы в bytecode:

```java
public static final int MAX = 100;

if (x > MAX) {
    // В bytecode: if (x > 100)
}
```

### 67. Что такое static initialization

Static initialization — инициализация static полей:

```java
public class Config {
    public static final String VERSION = "1.0.0"; // Инициализация
    public static int counter = 0; // Инициализация

    static {
        // Static initializer
        System.out.println("Config loaded");
    }

    public Config() {
        // Instance constructor
        counter++;
    }
}

// При первом обращении к Config:
// 1. Static initializer выполнится
// 2. Static поля инициализируются
```

### 68. Что такое class loading

Class loading — загрузка класса в JVM:

```java
// Загрузка класса
Class<?> cls = Class.forName("com.example.MyClass");

// Загрузка происходит:
// 1. При первом обращении к классу
// 2. При Class.forName()
// 3. При создании экземпляра (new)
```

### 69. Что такое class initialization

Class initialization — инициализация класса (static поля + static initializer):

```java
public class MyClass {
    static int count = 0; // Инициализация

    static {
        count = initialize(); // Static initializer
    }

    private static int initialize() {
        return 42;
    }
}

// При первом обращении к MyClass:
// 1. Загрузка класса
// 2. Инициализация static полей
// 3. Выполнение static initializer
```

### 70. Что такое lazy class loading

Lazy class loading — отложенная загрузка класса:

```java
// Class.forName() с параметром
Class<?> cls = Class.forName("com.example.MyClass", false, ClassLoader.getSystemClassLoader());
// false = не инициализировать (только загрузить)
```

### 71. Что такое ClassLoader

ClassLoader — механизм загрузки классов:

```java
// ClassLoader hierarchy:
// Bootstrap ClassLoader (java.lang.*)
//   └─ Platform ClassLoader (java.*, jdk.*)
//       └─ Application ClassLoader (classpath)
//           └─ Custom ClassLoader

// Custom ClassLoader
class MyClassLoader extends ClassLoader {
    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        // Загрузка из кастомного источника
        return super.findClass(name);
    }
}
```

### 72. Что такое class isolation

Class isolation — изоляция классов (разные ClassLoader'ы):

```java
// Два ClassLoader'а — разные классы
ClassLoader cl1 = new URLClassLoader(new URL[]{...});
ClassLoader cl2 = new URLClassLoader(new URL[]{...});

Class<?> c1 = cl1.loadClass("com.example.MyClass");
Class<?> c2 = cl2.loadClass("com.example.MyClass");

System.out.println(c1 == c2); // false (разные ClassLoader'ы)
```

### 73. Что такое reflection

Reflection — доступ к метаданным класса в runtime:

```java
Class<?> cls = MyClass.class;

// Методы
Method[] methods = cls.getMethods();
Method m = cls.getMethod("doWork", String.class);
m.invoke(instance, "arg");

// Поля
Field[] fields = cls.getFields();
Field f = cls.getField("name");
f.set(instance, "new value");

// Конструкторы
Constructor<?> ctor = cls.getConstructor(String.class);
Object obj = ctor.newInstance("arg");
```

### 74. Что такое annotation processing

Annotation processing — обработка аннотаций на этапе компиляции:

```java
// Аннотация
@Retention(RetentionPolicy.SOURCE)
@Target(ElementType.METHOD)
public @interface Validate { }

// Обработка (Lombok, MapStruct, Dagger)
// Компилятор генерирует код при обработке аннотаций
```

### 75. Что такое RetentionPolicy

RetentionPolicy — когда аннотация доступна:

```java
// SOURCE — только в исходном коде (Lombok)
@Retention(RetentionPolicy.SOURCE)

// CLASS — в .class файле (по умолчанию)
@Retention(RetentionPolicy.CLASS)

// RUNTIME — в runtime (Spring, JPA)
@Retention(RetentionPolicy.RUNTIME)
```

### 76. Что такое Target

Target — где можно использовать аннотацию:

```java
@Target({ElementType.TYPE, ElementType.METHOD, ElementType.FIELD})
public @interface MyAnnotation { }

// Можно использовать:
@MyAnnotation
class MyClass { }

@MyAnnotation
void myMethod() { }

@MyAnnotation
String myField;
```

### 77. Что такое Repeatable

Repeatable — аннотация, которую можно использовать несколько раз:

```java
@Repeatable(MyAnnotations.class)
@Target(ElementType.METHOD)
public @interface Constraint {
    String message();
}

// Container
@Target(ElementType.METHOD)
public @interface MyAnnotations {
    Constraint[] value();
}

// Использование:
@Constraint(message = "Must be positive")
@Constraint(message = "Must be less than 100")
void setAge(int age) { }
```

### 78. Что такое meta-annotation

Meta-annotation — аннотация для аннотаций:

```java
// Standard meta-annotations:
@Target
@Retention
@Documented
@Inherited
@Repeatable

// Custom meta-annotation
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.ANNOTATION_TYPE)
public @interface CustomMeta { }

@CustomMeta
public @interface MyAnnotation { }
```

### 79. Что такое @Inherited

@Inherited — аннотация наследуется подклассами:

```java
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface MyAnnotation { }

@MyAnnotation
class Base { }

class Child extends Base { }

// Child наследует @MyAnnotation
Class<?> cls = Child.class;
MyAnnotation ann = cls.getAnnotation(MyAnnotation.class);
System.out.println(ann != null); // true
```

### 80. Что такое @Documented

@Documented — аннотация отображается в Javadoc:

```java
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface MyAnnotation {
    String value();
}

@MyAnnotation("Important class")
public class MyClass { }

// В Javadoc:
// @MyAnnotation("Important class")
public class MyClass { }
```

### 81. Что такое annotation values

Annotation values — параметры аннотации:

```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Timeout {
    int value() default 30; // seconds
    TimeUnit unit() default TimeUnit.SECONDS;
    boolean retry() default false;
}

// Использование:
@Timeout(60)
void longOperation() { }

@Timeout(value = 10, unit = TimeUnit.MILLISECONDS, retry = true)
void quickOperation() { }
```

### 82. Что такое default values в annotations

Default values — значения по умолчанию для параметров аннотации:

```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Config {
    String name() default "default";
    int timeout() default 30;
    boolean enabled() default true;
}

// Можно не указывать default:
@Config
void myMethod() { } // name="default", timeout=30, enabled=true

// Можно переопределить:
@Config(name = "custom", timeout = 60)
void myMethod() { }
```

### 83. Что такое annotation on parameters

Annotation на параметрах метода:

```java
public void process(
    @NotNull String name,
    @Min(0) @Max(100) int age,
    @Email String email
) { }
```

### 84. Что такое annotation on type parameters

Annotation на type parameters (Java 8+):

```java
public class Cache<K extends @NonNull Object, V extends @NonNull Object> { }

// Annotation на generics
Map<@NonNull String, @Nullable Integer> map = new HashMap<>();
```

### 85. Что такое type annotations (Java 8+)

Type annotations — аннотации на типах:

```java
// На типах
@NonNull String name;

// На generics
Map<@NonNull String, @Nullable Integer> map;

// На casts
String s = (@NonNull) obj;

// На instanceof
if (obj instanceof @NonNull String s) { }
```

### 86. Что такое annotation on field

Annotation на поле:

```java
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Email
    private String email;
}
```

### 87. Что такое annotation on method

Annotation на метод:

```java
public class Service {
    @Transactional
    @Cacheable("users")
    public User getUser(Long id) {
        return userRepository.findById(id).orElseThrow();
    }

    @Async
    @Timeout(60)
    public void notifyUser(Long id) {
        // Async notification
    }
}
```

### 88. Что такое annotation on class

Annotation на класс:

```java
@Service
@Component
@Configuration
public class MyService {
    // ...
}

@Entity
@Table(name = "users")
public class User {
    // ...
}
```

### 89. Что такое annotation on constructor

Annotation на конструктор:

```java
public class Config {
    @Autowired
    public Config(DataSource dataSource) {
        this.dataSource = dataSource;
    }
}
```

### 90. Что такое annotation on method parameter

Annotation на параметр метода:

```java
public void process(
    @RequestParam String name,
    @PathVariable Long id,
    @RequestBody Order order
) { }
```

### 91. Что такое annotation on return type

Annotation на return type:

```java
@NonNull
public User getUser(Long id) {
    return userRepository.findById(id).orElseThrow();
}
```

### 92. Что такое annotation on exception

Annotation на исключение:

```java
@ExceptionHandler(OrderNotFoundException.class)
public ResponseEntity<ProblemDetail> handleNotFound(OrderNotFoundException ex) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ProblemDetail.forStatus(ex));
}
```

### 93. Что такое annotation on enum

Annotation на enum:

```java
public enum Status {
    @Deprecated
    OLD_STATUS,
    ACTIVE,
    CLOSED
}
```

### 94. Что такое annotation on interface

Annotation на интерфейс:

```java
@FunctionalInterface
@Deprecated
public interface OldInterface {
    void doWork();
}
```

### 95. Что такое annotation on package

Annotation на package:

```java
// package-info.java
@NonNullApi
@NonNullFields
package com.example;
```

### 96. Что такое annotation on module

Annotation на module (Java 9+):

```java
// module-info.java
@Open
module com.example {
    exports com.example.api;
    requires com.other;
}
```

### 97. Что такое annotation processing order

Annotation processing order — порядок обработки аннотаций:

```java
// Компилятор обрабатывает аннотации в цикле:
// 1. Первая — обработать аннотации, сгенерировать код
// 2. Вторая — обработать аннотации в сгенерированном коде
// 3. ... (пока нет новых аннотаций)
```

### 98. Что такое annotation processor

Annotation processor — класс, обрабатывающий аннотации:

```java
public class MyProcessor extends AbstractProcessor {
    @Override
    public Set<String> getSupportedAnnotationTypes() {
        return Set.of("com.example.MyAnnotation");
    }

    @Override
    public boolean process(Set<? extends Element> elements, RoundEnvironment env) {
        for (Element element : elements) {
            // Обработка аннотации
            MyAnnotation ann = element.getAnnotation(MyAnnotation.class);
            System.out.println(ann.value());
        }
        return true;
    }
}
```

### 99. Что такое lombok как annotation processor

Lombok — annotation processor, генерирующий код:

```java
@Data  // Генерирует: getters, setters, equals, hashCode, toString
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {
    private String name;
    private int age;
}

// Lombok генерирует:
// public String getName() { return name; }
// public void setName(String name) { this.name = name; }
// public boolean equals(Object o) { ... }
// public int hashCode() { ... }
// public String toString() { ... }
// public User() { }
// public User(String name, int age) { ... }
// public static UserBuilder builder() { ... }
```

### 100. Что такое mapstruct как annotation processor

MapStruct — annotation processor для маппинга объектов:

```java
@Mapper
public interface UserMapper {
    UserMapper INSTANCE = Mappers.getMapper(UserMapper.class);

    UserDto toDto(User user);
    User toEntity(UserDto dto);
    List<UserDto> toDtos(List<User> users);
}

// MapStruct генерирует реализацию:
// public class UserMapperImpl implements UserMapper {
//     public UserDto toDto(User user) {
//         UserDto dto = new UserDto();
//         dto.setName(user.getName());
//         dto.setAge(user.getAge());
//         return dto;
//     }
// }
```
