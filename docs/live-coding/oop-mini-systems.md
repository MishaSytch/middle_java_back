# ООП: значимые классы и мини-системы

> Что проверяют: иммутабельность, equals/hashCode, BigDecimal для денег, инкапсуляцию состояния, выбор между классом/record/enum.

<a id="r19-t1"></a>
**1. [Дизайн] Класс Money**
```java
enum Currency { USD, EUR, RUB }

final class Money implements Comparable<Money> {
    private final BigDecimal amount;      // деньги — НИКОГДА double (0.1 + 0.2 != 0.3)
    private final Currency currency;

    Money(BigDecimal amount, Currency currency) {
        this.amount = amount.setScale(2, RoundingMode.HALF_EVEN);   // банковское округление до копеек
        this.currency = currency;
    }
    static Money of(String s, Currency c) { return new Money(new BigDecimal(s), c); }

    Money add(Money other)      { requireSameCurrency(other); return new Money(amount.add(other.amount), currency); }
    Money multiply(int times)   { return new Money(amount.multiply(BigDecimal.valueOf(times)), currency); }

    private void requireSameCurrency(Money other) {
        if (currency != other.currency)
            throw new IllegalArgumentException("валюты не совпадают: " + currency + " vs " + other.currency);
    }

    @Override public int compareTo(Money o) { requireSameCurrency(o); return amount.compareTo(o.amount); }
    @Override public boolean equals(Object o) {
        return o instanceof Money m && currency == m.currency && amount.compareTo(m.amount) == 0;
    }
    @Override public int hashCode() { return Objects.hash(currency, amount.stripTrailingZeros()); }
    @Override public String toString() { return currency + " " + amount; }
}
```
Три столпа ответа: 1) BigDecimal (и конструктор из String, не из double); 2) equals через compareTo — BigDecimal.equals учитывает scale: `2.0` не равно `2.00`; 3) проверка валюты в операциях, иммутабельность каждой операции.

<a id="r19-t2"></a>
**2. [Дизайн] Диапазон значений на дженериках**
```java
record Range<T extends Comparable<T>>(T from, T to) {
    public Range {                                        // компактный конструктор с валидацией
        if (from.compareTo(to) > 0) throw new IllegalArgumentException("from > to");
    }
    boolean contains(T v)        { return from.compareTo(v) <= 0 && v.compareTo(to) <= 0; }
    boolean overlaps(Range<T> o) { return from.compareTo(o.to) <= 0 && o.from.compareTo(to) <= 0; }

    Optional<Range<T>> merge(Range<T> o) {                // объединение пересекающихся
        if (!overlaps(o)) return Optional.empty();
        return Optional.of(new Range<>(min(from, o.from), max(to, o.to)));
    }
    private T min(T a, T b) { return a.compareTo(b) <= 0 ? a : b; }
    private T max(T a, T b) { return a.compareTo(b) >= 0 ? a : b; }
}
```
Bounded type parameter + record с валидацией. Спросят: почему `extends Comparable` в типе (нужен compareTo); что вернёт merge для касающихся диапазонов (пересеклись — сольются).

<a id="r19-t3"></a>
**3. [Дизайн] Потокобезопасный банковский счёт и перевод**
```java
class Account {
    private final long id;
    private long balance;                      // в копейках: long, а не double

    Account(long id, long balance) { this.id = id; this.balance = balance; }

    synchronized void deposit(long amount) {
        requirePositive(amount);
        balance += amount;
    }
    synchronized void withdraw(long amount) {
        requirePositive(amount);
        if (balance < amount) throw new IllegalStateException("недостаточно средств: " + balance);
        balance -= amount;
    }
    synchronized long balance() { return balance; }

    // ДЕДЛОК-ОПАСНО: transfer(a, b) и transfer(b, a) одновременно захватят локи в разном порядке
    static void transfer(Account from, Account to, long amount) {
        Account first  = from.id < to.id ? from : to;   // ЕДИНЫЙ порядок захвата по id
        Account second = from.id < to.id ? to : from;
        synchronized (first) {
            synchronized (second) {
                from.withdraw(amount);
                to.deposit(amount);
            }
        }
    }
    private static void requirePositive(long amount) {
        if (amount <= 0) throw new IllegalArgumentException("сумма должна быть положительной");
    }
}
```
Разворот задачи на дедлок (см. concurrency-sync): без упорядочения — классический взаимный блок. Фоллоу-ап: tryLock с откатом; атомарность перевода при отсутствии денег (откат не нужен — withdraw кинет до deposit).

<a id="r19-t4"></a>
**4. [Дизайн] Конечный автомат заказа**
```java
enum OrderStatus {
    NEW, PAID, SHIPPED, DELIVERED, CANCELLED;

    public Set<OrderStatus> next() {
        return switch (this) {
            case NEW      -> Set.of(PAID, CANCELLED);
            case PAID     -> Set.of(SHIPPED, CANCELLED);
            case SHIPPED  -> Set.of(DELIVERED);
            case DELIVERED, CANCELLED -> Set.of();       // терминальные
        };
    }
    public boolean canMoveTo(OrderStatus target) { return next().contains(target); }
}

class Order {
    private OrderStatus status = OrderStatus.NEW;
    public synchronized void moveTo(OrderStatus target) {
        if (!status.canMoveTo(target))
            throw new IllegalStateException("недопустимый переход " + status + " -> " + target);
        status = target;
    }
    public OrderStatus status() { return status; }
}
```
Переходы локализованы в enum — новая логика не меняет старые состояния. Сравнить с switch-по-месту (правки размазаны) — аргумент за enum-метод.

<a id="r19-t5"></a>
**5. [Дизайн] Иерархия фигур на sealed + record**
```java
sealed interface Shape permits Circle, Square, Rect { }
record Circle(double r) implements Shape { }
record Square(double a) implements Shape { }
record Rect(double w, double h) implements Shape { }

static double area(Shape s) {
    return switch (s) {                       // exhaustive: default НЕ нужен — sealed закрыл множество
        case Circle c -> Math.PI * c.r() * c.r();
        case Square q -> q.a() * q.a();
        case Rect   r -> r.w() * r.h();
    };
}

List<Shape> byArea = shapes.stream()
    .sorted(Comparator.comparingDouble(s -> area((Shape) s)))
    .collect(Collectors.toList());
```
Sealed (Java 17): «алгебраическая» сумма типов; компилятор проверит полноту switch; добавление новой фигуры = ошибка компиляции во всех старых switch — сразу видно, где дописать. Отличный повод поговорить про иммутабельность record и ограничения sealed.

<a id="r19-t6"></a>
**6. [Дизайн] Пара значений и потокобезопасный кэш-загрузчик**
```java
record Pair<A, B>(A first, B second) { }

class Cache<K, V> {
    private final Map<K, V> store = new ConcurrentHashMap<>();

    public V getOrCompute(K key, Function<K, V> loader) {
        return store.computeIfAbsent(key, loader);   // атомарно для ключа: лоадер не вызовется дважды
    }
    public int size() { return store.size(); }
}
```
computeIfAbsent в ConcurrentHashMap выполняет loader под локом бакета: параллельные запросы одного ключа получат один вызов loader. Фоллоу-ап: долгий loader блокирует бакет (а в старых версиях — весь map) → считать в будущем значении: `Map<K, CompletableFuture<V>>`.

<a id="r19-t7"></a>
**7. [С_нуля] Итератор по матрице**
```java
class Matrix implements Iterable<Integer> {
    private final int[][] data;
    Matrix(int[][] data) { this.data = data; }

    @Override
    public Iterator<Integer> iterator() {
        return new Iterator<>() {
            int row, col;
            @Override public boolean hasNext() {           // пропускаем исчерпанные/пустые строки
                while (row < data.length && col == data[row].length) { row++; col = 0; }
                return row < data.length;
            }
            @Override public Integer next() {
                if (!hasNext()) throw new NoSuchElementException();
                return data[row][col++];
            }
        };
    }
}
// for (int v : matrix) — работает благодаря Iterable
```
Тонкое место: `col == data[row].length` корректно и для пустых строк (длина 0). Вопрос на понимание контракта итератора (next без hasNext → исключение).

<a id="r19-t8"></a>
**8. [Дизайн] Билдер с валидацией**
```java
class ServerConfig {
    private final String host;
    private final int port;
    private final int maxConnections;

    private ServerConfig(Builder b) {
        this.host = b.host; this.port = b.port; this.maxConnections = b.maxConnections;
    }

    public static Builder builder(String host) { return new Builder(host); }

    public static class Builder {
        private final String host;
        private int port = 8080;              // разумные значения по умолчанию
        private int maxConnections = 100;

        Builder(String host) {
            if (host == null || host.isBlank()) throw new IllegalArgumentException("host обязателен");
            this.host = host;
        }
        public Builder port(int port) {
            if (port < 1 || port > 65535) throw new IllegalArgumentException("port: " + port);
            this.port = port;
            return this;                       // fluent: цепочка вызовов
        }
        public Builder maxConnections(int n) {
            if (n < 1) throw new IllegalArgumentException("maxConnections: " + n);
            this.maxConnections = n;
            return this;
        }
        public ServerConfig build() { return new ServerConfig(this); }
    }
}
// ServerConfig cfg = ServerConfig.builder("db.internal").port(5432).maxConnections(30).build();
```
Зачем: телескопические конструкторы и мутируемые set-состояния. Валидация — на каждом шаге, объект рождается валидным и immutable. Фоллоу-ап: когда record с compact-конструктором проще (просто данные + инвариант, без дефолтов).

<a id="r19-t9"></a>
**9. [Рефакторинг] Наследование ради переиспользования → композиция**
```java
// ПЛОХО: перехватываем только add — addAll/set/listIterator/set всё равно «мимо логов»
class LoggingArrayList<T> extends ArrayList<T> {
    @Override public boolean add(T t) { System.out.println("add " + t); return super.add(t); }
}

// ХОРОШО: декоратор над интерфейсом — контролируем контракт, а не реализацию
interface InvoiceRepo { void save(String invoiceId); }

class AuditedRepo implements InvoiceRepo {
    private final InvoiceRepo delegate;               // любой другой репозиторий
    AuditedRepo(InvoiceRepo delegate) { this.delegate = delegate; }
    @Override public void save(String invoiceId) {
        System.out.println("сохраняем " + invoiceId);
        delegate.save(invoiceId);
    }
}
// InvoiceRepo repo = new AuditedRepo(new PostgresRepo(dataSource));
```
Правило «наследование = is-a, композиция = has-a»: наследоваться от конкретной коллекции ради «добавить поведения» — хрупко (17 методов addAll/subList/iterator-мутаций обходят override).

---

<a id="razdel-20"></a>
