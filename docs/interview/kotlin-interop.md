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
