# Kotlin Interop

### 1. Kotlin для Java-разработчиков: null-safety, data classes, extension functions
**Null-safety:**
```kotlin
// Kotlin: null-safety в компайлере
fun process(name: String) { ... }       // не может быть null
fun processNullable(name: String?) { ... } // явно nullable

// Safe call
val length = name?.length ?: 0

// Elvis
val default = name ?: "Anonymous"

// !! (non-null assertion) — избегай, аналог NPE
val risky = name!!.length
```

В Java: `@Nullable` / `@NonNull` (JSR 305, JetBrains annotations) — только hints для IDE, runtime не проверяет.

**Data classes:**
```kotlin
data class Order(
    val id: String,
    val total: BigDecimal,
    val items: List<Item>
)
// Auto: equals(), hashCode(), toString(), component1()..., copy()

// copy — immutable update
val updated = order.copy(total = order.total * 1.1)
```

Аналог в Java: record (Java 16+), но нет `copy()`.

**Extension functions:**
```kotlin
fun String.truncateTo(maxLen: Int): String =
    if (length <= maxLen) this else take(maxLen) + "..."

// Use
val short = "Very long string...".truncateTo(20)
```

В Java: utility classes (StringUtils), или Kotlin extension вызывается статически.

**Other Kotlin features:**
- **Type inference**: `val x = 42` (int), `val s = "hello"` (String)
- **Operators overloading**: `+`, `-`, `*`, `in`, `is`
- **Destructuring**: `val (id, name) = pair`
- **Scope functions**: `let`, `run`, `with`, `apply`, `also`
- **Sealed classes** (подробнее в вопросе 6)

**Когда Java-разработчику переходить на Kotlin:**
- Новые проекты (Android, microservices, scripts)
- Legacy Java → Kotlin (incremental)
- Data-heavy code (data classes, immutability)

### 2. Interop: вызов Java из Kotlin и наоборот
**Kotlin → Java:**
```kotlin
// Java class
public class OrderService {
    public Order getOrder(String id) { ... }
    public void process(Order order) { ... }
}

// Kotlin: прямой вызов
val service = OrderService()
val order = service.getOrder("123")
service.process(order)

// Java static:
Math.max(1, 2)
// Java companion object:
MyCompanion.doSomething()

// Java generics:
val list: List<String> = ArrayList()
```

**Java → Kotlin:**
```java
// Kotlin
class OrderService {
    fun getOrder(id: String): Order { ... }
    fun process(order: Order) { ... }
}

// Java: прямой вызов (если top-level или @JvmStatic)
OrderService service = new OrderService();
Order order = service.getOrder("123");
service.process(order);

// Kotlin extension functions:
StringKt.truncateTo("long string", 20);
// or import as static:
import static org.example.StringKt.truncateTo;
truncateTo("long string", 20);

// Kotlin top-level functions:
// компилируются в class с именем файла (FileKt)
GreetingKt.greet("World");
```

**Pitfalls:**
- Kotlin `val` / `var` → Java getter/setter (если не `@JvmField`)
- Kotlin `suspend` functions → Java: `CompletableFuture` или callback
- Kotlin `sealed` → Java: interface + implementations
- Kotlin `enum` → Java: enum (совместимо)

### 3. @JvmOverloads, @JvmStatic, @JvmField
**@JvmOverloads:**
```kotlin
@JvmOverloads
fun connect(
    host: String,
    port: Int = 8080,
    timeout: Int = 5000
) { ... }

// Генерирует:
// connect(host)
// connect(host, port)
// connect(host, port, timeout)
```
Без аннотации: только `connect(host, port, timeout)` в Java.

**@JvmStatic:**
```kotlin
class Utils {
    companion object {
        @JvmStatic
        fun parseId(raw: String): Long = raw.toLong()
    }
}

// Java: Utils.parseId("123") (static, без Companion)
```

**@JvmField:**
```kotlin
class Config {
    @JvmField
    var maxRetries = 3
    @JvmField
    val timeout: Int = 5000
}

// Java: config.maxRetries (field, не getter/setter)
```

**Когда использовать:**
- `@JvmOverloads`: API с default params, используемое из Java
- `@JvmStatic`: utility functions в companion object
- `@JvmField`: public fields (исключительно для interop, лучше избегать)

**Другие interop annotations:**
- `@JvmName("customName")` — переименовать function в bytecode
- `@JvmMultifunctionClass` — для functional interface
- `@JvmDefault` / `@JvmDefaultWithCompatibility` — default methods в interface

### 4. Kotlin coroutines vs Java Virtual Threads
**Coroutines (Kotlin):**
```kotlin
suspend fun fetchOrder(id: String): Order {
    delay(100) // non-blocking
    return orderRepo.findById(id)
}

// Sequential
val order = fetchOrder("123")
val items = fetchItems(order.id)

// Parallel
coroutineScope {
    val orderDeferred = async { fetchOrder("123") }
    val inventoryDeferred = async { checkInventory(orderDeferred.await().items) }
    val total = orderDeferred.await() + inventoryDeferred.await()
}
```

**Virtual Threads (Java 21):**
```java
// Virtual thread per request
try (var virtualThread = Thread.ofVirtual().start(() -> {
    Order order = fetchOrder("123");
    List<Item> items = fetchItems(order.getId());
})) {
    virtualThread.join();
}

// Structured concurrency (Java 21+)
try (var scope = StructuredTaskScope.open()) {
    Subtask<Optional<Order>> order = scope.fork(() -> fetchOrder("123"));
    Subtask<List<Item>> items = scope.fork(() -> fetchItems("123"));
    scope.join();
}
```

**Сравнение:**
| | Coroutines | Virtual Threads |
|---|---|---|
| Language | Kotlin only | Java 21+ |
| Syntax | `suspend`, `async`, `await` | Threads, `fork`, `join` |
| Cancellation | Cooperative (checkpoints) | Thread interrupt |
| Context | CoroutineContext (scope, dispatcher) | ThreadLocal, StructuredTaskScope |
| Interop | Java: callback, CompletableFuture | Kotlin: Thread, ExecutorService |
| Ecosystem | kotlinx.coroutines, Spring | Spring, JDK |
| Learning curve | Высокая (concepts: scope, dispatcher, context) | Низкая (threads, как в Java 8+) |

**Когда что:**
- **Kotlin + coroutines**: новый Kotlin-проект, Android
- **Java + virtual threads**: Java 21+, минимальные изменения, Spring Boot 3.2+
- **Mixed**: Kotlin coroutines + Java virtual threads (через `ExecutorService`)

**Практика 2026:** Virtual threads — стандарт для Java. Coroutines — стандарт для Kotlin. Interop через `ExecutorService`.

### 5. Kotlin + Spring: kotlin-spring plugin, coroutine support
**kotlin-spring plugin:**
```kotlin
// Kotlin: @Component, @Autowired работает как в Java
@Component
class OrderService(
    private val orderRepo: OrderRepository,
    private val paymentClient: PaymentClient
) {
    @Autowired
    lateinit var cache: Cache
}
```

**Dependency injection:**
```kotlin
// Constructor injection (preferred)
@Service
class OrderService(
    private val orderRepo: OrderRepository,
    private val paymentClient: PaymentClient
) { ... }

// Field injection (avoid)
@Service
class OrderService {
    @Autowired
    lateinit var orderRepo: OrderRepository
}
```

**Coroutines + Spring:**
```kotlin
// kotlinx-coroutines-spring
@Service
class OrderService(private val repo: OrderRepository) {
    suspend fun processOrder(id: String): Order {
        val order = repo.findById(id)
        repo.save(order.copy(status = Status.PROCESSED))
        return order
    }
}

// Controller
@RestController
class OrderController(private val service: OrderService) {
    @GetMapping("/orders/{id}")
    suspend fun getOrder(@PathVariable id: String): Order =
        service.processOrder(id)
}
```

**Maven:**
```xml
<dependency>
    <groupId>org.jetbrains.kotlinx</groupId>
    <artifactId>kotlinx-coroutines-spring</artifactId>
    <version>1.7.3</version>
</dependency>
```

**Best practices:**
- `suspend` functions в service layer
- `@Transactional` + `suspend` (Spring 6+ support)
- Structured concurrency: `coroutineScope` для parallel
- Error handling: `try/catch` или `CoroutineExceptionHandler`

### 6. Sealed classes в Kotlin vs Java
**Kotlin sealed classes:**
```kotlin
sealed interface Result<out T> {
    data class Success<T>(val data: T) : Result<T>
    data class Error(val code: String, val message: String) : Result<Nothing>
    object Loading : Result<Nothing>
}

// Exhaustive when
fun handle(result: Result<String>): String = when (result) {
    is Result.Success -> "OK: ${result.data}"
    is Result.Error -> "Error: ${result.code}"
    Result.Loading -> "Loading..."
}
// Компилятор: все случаи покрыты, нет default needed
```

**Java equivalents:**
```java
// Java 17+: sealed interface
public sealed interface Result<T> permits Success, Error, Loading {}
record Success<T>(T data) implements Result<T> {}
record Error(String code, String message) implements Result<Nothing> {}
record Loading() implements Result<Nothing> {}

// Exhaustive switch (Java 21+)
String handle(Result<String> result) {
    return switch (result) {
        case Success<String> s -> "OK: " + s.data();
        case Error e -> "Error: " + e.code();
        case Loading l -> "Loading...";
    };
}
```

**Сравнение:**
| | Kotlin sealed | Java sealed (17+) |
|---|---|---|
| Syntax | `sealed interface` / `sealed class` | `sealed interface` / `sealed class` |
| Exhaustive when/switch | Да (без default) | Да (Java 21+, без default) |
| Nesting | Subtypes must be nested (Kotlin 1.5+) | Subtypes in same package (Java) |
| Data class | `data class` | `record` |
| Companion object | Да | No (static methods) |

**Практика:** Java 21+ sealed + records = эквивалент Kotlin sealed + data classes. В Java-проектах предпочитайте Java syntax.

### 7. When to choose Kotlin vs Java in 2026
**Kotlin preferred:**
- Новые проекты (особенно Android, mobile)
- Data-heavy code (data classes, immutability)
- Functional style (extension functions, higher-order functions)
- Team comfortable with Kotlin
- Spring projects (excellent support)

**Java preferred:**
- Legacy codebase (Java 8/11, migration cost)
- Performance-critical (JVM tuning, AOT)
- Team only knows Java
- GraalVM Native Image (Java 21+ better support)
- Enterprise with strict Java-only policy

**Mixed approach:**
- New modules in Kotlin, legacy in Java
- Interop: `@JvmOverloads`, `@JvmStatic` для Java callers
- Build: Gradle Kotlin DSL, Maven kotlin-maven-plugin

**2026 reality:**
- Java 21+ (virtual threads, sealed, records, pattern matching) закрывает 80% Kotlin advantages
- Kotlin остаётся preferred для Android
- Для Spring: оба языка excellent, выбор по team preference
- Trend: новые проекты — Kotlin, legacy — Java, mixed — common

**Decision framework:**
1. Is it Android? → Kotlin
2. Is it new project? → Kotlin (если team OK)
3. Is it legacy Java? → Stay Java (migration cost)
4. Is it Spring? → Either, team preference
5. Is it performance-critical? → Java (AOT, tuning)
6. Is it data-heavy? → Kotlin (data classes) или Java records

### 8. Kotlin null-safety в interop: platform types
**Platform types** — типы, пришедшие из Java, компилятор Kotlin не может гарантировать их null-safety.

```kotlin
// Java метод возвращает String (может быть null)
// Kotlin видит: String! (platform type)
val name: String! = javaObj.getName()

// Компилятор НЕ ругается, но runtime может бросить NPE
val length = name.length  // NPE если name == null

// Решение: явно аннотировать Java-код
// @Nullable String getName() — Kotlin видит String?
// @NonNull String getName() — Kotlin видит String
```

**Аннотации (JSR 305, JetBrains annotations):**
```java
// Java:
@Nullable
public String maybeNull() { return null; }

@NonNull
public String notNull() { return "value"; }
```

**Правило:** platform types (`Type!`) — это «дыра» в null-safety. Всегда принудительно приводи к `Type?` или `Type` при interop.

### 9. Kotlin collections vs Java collections
**Различия:**

| Kotlin | Java | Примечание |
|--------|------|------------|
| `List<T>` | `List<T>` | read-only (в Kotlin `mutableListOf` = MutableList) |
| `MutableList<T>` | `List<T>` (mutable) | Kotlin разделяет read-only и mutable |
| `Map<K,V>` | `Map<K,V>` | read-only |
| `MutableMap<K,V>` | `Map<K,V>` (mutable) | mutable version |
| `Set<T>` | `Set<T>` | read-only |
| `MutableSet<T>` | `Set<T>` (mutable) | mutable version |

```kotlin
// Kotlin: read-only List
val list: List<String> = listOf("a", "b")
// list.add("c") — compile error (read-only)

val mutableList: MutableList<String> = mutableListOf("a", "b")
mutableList.add("c")  // OK

// Java List передаётся в Kotlin как MutableList!
// (потому что Java List — mutable по умолчанию)
fun acceptList(list: List<String>) {
    // list — read-only view
}
```

**Параметры функций:**
```kotlin
// Принимает read-only List, но Java передаст mutable
fun process(list: List<String>) {
    // list — read-only (можно только читать)
}

// Принимает mutable List
fun modify(list: MutableList<String>) {
    list.add("new")  // OK
}
```

### 10. Kotlin property vs Java field: backing field, getter, setter
```kotlin
class User {
    var name: String = "Anonymous"
    // Kotlin создаёт:
    // private String name (backing field)
    // public String getName()
    // public void setName(String name)
}
```

```java
// Java:
public class User {
    private String name = "Anonymous";
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
```

**Различия:**
- **Kotlin property** = backing field + getter + setter (автоматически).
- **Java field** = только поле (getter/setter вручную).
- **@JvmField** = только поле (без getter/setter).
- **@JvmStatic** = static method (в Java).
- **@JvmOverloads** = перегрузки по default-параметрам.

```kotlin
class User {
    @JvmField
    var name: String = "Anonymous"
    // Kotlin создаёт ТОЛЬКО поле (без getter/setter)
    // Java видит: public String name (поле, не property)
}
```

### 11. Kotlin default parameters vs Java overloads
```kotlin
// Kotlin:
fun greet(name: String, greeting: String = "Hello", punctuation: String = "!") {
    println("$greeting, $name$punctuation")
}

greet("Alice")                    // Hello, Alice!
greet("Alice", "Hi")             // Hi, Alice!
greet("Alice", "Hi", "?")        // Hi, Alice?
```

```java
// Java (без @JvmOverloads):
// Только 1 метод: greet(String name, String greeting, String punctuation)
// Default-параметры НЕ видны в Java

// Kotlin:
fun greet(name: String, greeting: String = "Hello", punctuation: String = "!") {
    println("$greeting, $name$punctuation")
}

// С @JvmOverloads:
@JvmOverloads
fun greet(name: String, greeting: String = "Hello", punctuation: String = "!") {
    println("$greeting, $name$punctuation")
}
// Java видит 3 перегрузки:
// greet(String name)
// greet(String name, String greeting)
// greet(String name, String greeting, String punctuation)
```

### 12. Kotlin scope functions: let, run, with, apply, also
```kotlin
// let — получает объект как `it`, возвращает результат
val length = "Hello".let { it.length }  // 5

// run — получает объект как `this`, возвращает результат
val length = "Hello".run { length }  // 5

// with — получает объект как `this`, возвращает результат
val length = with("Hello") { length }  // 5

// apply — получает объект как `this`, возвращает ОБЪЕКТ
val list = mutableListOf<String>().apply {
    add("a")
    add("b")
}  // list = ["a", "b"]

// also — получает объект как `it`, возвращает ОБЪЕКТ
val list = mutableListOf<String>().also {
    it.add("a")
    it.add("b")
}  // list = ["a", "b"]
```

**Когда использовать:**
- **let** — null-check + действие: `if (obj != null) obj.let { ... }`
- **run** — блок с `this`
- **with** — блок с `this` (для существующего объекта)
- **apply** — инициализация объекта
- **also** — побочное действие (logging)

### 13. Kotlin extension functions vs Java static methods
```kotlin
// Kotlin extension function:
fun String.truncateTo(maxLen: Int): String {
    return if (length <= maxLen) this else take(maxLen) + "..."
}

// Use:
val short = "Very long string...".truncateTo(20)  // "Very long string...."
```

```java
// Java: static method
public class StringUtils {
    public static String truncateTo(String str, int maxLen) {
        return str.length() <= maxLen ? str : str.substring(0, maxLen) + "...";
    }
}

// Use:
String short = StringUtils.truncateTo("Very long string...", 20);
```

**Различия:**
- **Kotlin extension** = вызов на объекте (`str.truncateTo(20)`)
- **Java static** = вызов на классе (`StringUtils.truncateTo(str, 20)`)
- **Kotlin extension** не имеет доступа к private-полям (это просто синтаксический сахар)
- **Kotlin extension** можно вызывать на объекте, Java static — только на классе

### 14. Kotlin suspend functions и как они выглядят из Java
```kotlin
// Kotlin:
suspend fun fetchUser(id: Long): User {
    // suspend function — может suspending
    return userRepository.findById(id)
}

// Call:
val user = fetchUser(42L)  // только из suspend context
```

```java
// Java: suspend function выглядит как метод с CoroutineScope
// Нужно передать Continuation
public User fetchUser(long id, Continuation<? super User> $completion) {
    // ...
}

// Удобнее: использовать kotlinx.coroutines
// или вызывать через runBlocking
```

**Правило:** suspend function из Java выглядит как метод с `Continuation`. Удобнее вызывать через `kotlinx.coroutines`.

### 15. Kotlin type system: generics, variance, in/out
```kotlin
// Invariant (по умолчанию):
fun <T> identity(value: T): T = value

// Covariant (out):
fun <out T : Any> printAll(items: List<T>) {
    items.forEach { println(it) }
}

// Contravariant (in):
fun <in T> addAll(list: MutableList<T>, items: List<T>) {
    list.addAll(items)
}

// Star projection:
fun printList(list: List<*>): String {
    // list — List<out Any?>
    return list.toString()
}
```

**Variance:**
- **out** (covariant) — только чтение (List<out T> = можно читать T, но не писать)
- **in** (contravariant) — только запись (List<in T> = можно писать T, но не читать)
- **star** — неизвестный тип (List<*> = List<out Any?>)

### 16. Kotlin operator overloading
```kotlin
// Kotlin: оператор +
class Vector(val x: Double, val y: Double) {
    operator fun plus(other: Vector): Vector {
        return Vector(x + other.x, y + other.y)
    }
    
    override fun toString(): String = "($x, $y)"
}

val v1 = Vector(1.0, 2.0)
val v2 = Vector(3.0, 4.0)
val v3 = v1 + v2  // Vector(4.0, 6.0)
```

```java
// Java: static method
public class Vector {
    private final double x, y;
    
    public Vector add(Vector other) {
        return new Vector(x + other.x, y + other.y);
    }
}

Vector v3 = v1.add(v2);
```

**Доступные операторы:** `+`, `-`, `*`, `/`, `%`, `plus`, `minus`, `times`, `div`, `mod`, `unaryPlus`, `unaryMinus`, `invoke`, `get`, `set`, `plusAssign`, `contains`

### 17. Kotlin destructuring declarations
```kotlin
// Pair
val (first, second) = Pair("Alice", 30)
println(first)  // "Alice"
println(second)  // 30

// Triple
val (name, age, city) = Triple("Alice", 30, "NYC")

// Data class
data class User(val name: String, val age: Int)
val (name, age) = User("Alice", 30)

// Map
val (key, value) = Map.Entry("key", "value")
```

**Как работает:** destructuring использует `componentN()` methods (генерируются автоматически для data classes, Pair, Triple, Map.Entry).

### 18. Kotlin inline functions и noinline
```kotlin
// Inline function:
inline fun <T, R> Array<T>.mapInline(transform: (T) -> R): Array<R> {
    val result = Array<R>(size) { transform(this[it]) }
    return result
}

// Use:
val arr = intArrayOf(1, 2, 3)
val result = arr.mapInline { it * 2 }  // inlined (no lambda overhead)
```

**Нюансы:**
- **inline** = тело функции копируется в место вызова (no lambda overhead)
- **noinline** = lambda не инлайнится (для capture в замыкание)
- **crossinline** = lambda инлайнится, но может быть вызвана из другого контекста

```kotlin
// crossinline:
inline fun runCrossinline(block: crossinline () -> Unit) {
    Thread {
        block()  // OK: crossinline разрешает вызов из другого потока
    }.start()
}
```

### 19. Kotlin reified generics
```kotlin
// Reified generics (только для inline functions):
inline fun <reified T : Any> List<*>.filterByType(): List<T> {
    return filterIsInstance<T>()
}

val list = listOf(1, "hello", 3.0, true)
val strings = list.filterByType<String>()  // ["hello"]
```

**Зачем:** в Java generics стёрты (type erasure). Reified generics позволяют использовать тип в runtime (только для inline functions).

```kotlin
// Без reified:
fun <T> List<*>.filterByType(): List<T> {
    // Т не известно в runtime (type erasure)
    return filter { it is T }  // compile error
}

// С reified:
inline fun <reified T : Any> List<*>.filterByType(): List<T> {
    // T известно в runtime (reified)
    return filter { it is T }  // OK
}
```

### 20. Kotlin sealed classes vs Java sealed interfaces (Java 17)
```kotlin
// Kotlin:
sealed class Result<out T> {
    data class Success<T>(val value: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

// Use:
when (result) {
    is Result.Success -> println(result.value)
    is Result.Error -> println(result.message)
    is Result.Loading -> println("Loading...")
}  // exhaustive (no default needed)
```

```java
// Java 17:
sealed interface Result<T> {
    record Success<T>(T value) implements Result<T> {}
    record Error(String message) implements Result<Nothing> {}
    record Loading() implements Result<Nothing> {}
}

// Use:
switch (result) {
    case Result.Success<T> s -> System.out.println(s.value());
    case Result.Error e -> System.out.println(e.message());
    case Result.Loading l -> System.out.println("Loading...");
}  // exhaustive (no default needed, Java 21)
```

**Различия:**
- **Kotlin sealed class** = наследование (extends)
- **Java sealed interface** = реализация (implements)
- **Kotlin**: exhaustive when (без default)
- **Java 17**: exhaustive switch (Java 21, без default)

**Правило:** sealed (Kotlin и Java 17+) = ограниченное множество наследников. Exhaustive matching (без default).
