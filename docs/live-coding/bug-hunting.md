# Баг-хантинг

> Формат «найди баг» встречается на middle всё чаще: смотрят на читку чужого кода и знание JMM/контрактов. Во всех задачах: сначала назвать баг вслух, потом — минимальный фикс.

<a id="r21-t1"></a>
**1. [Баг-хантинг] ConcurrentModificationException**
```java
List<String> names = new ArrayList<>(List.of("ann", "bob", "cyd"));
for (String n : names)
    if (n.equals("bob")) names.remove(n);        // ConcurrentModificationException

// фиксы:
for (Iterator<String> it = names.iterator(); it.hasNext(); )   // 1) итератор с remove
    if (it.next().equals("bob")) it.remove();
names.removeIf("bob"::equals);                                  // 2) идеоматично (внутри — тот же итератор)
List<String> copy = List.copyOf(names);                          // 3) итерация по копии, удаление из оригинала
```
Механика: modCount проверяется на каждом next(); remove через коллекцию его увеличивает мимо итератора. removeIf — единственный корректный «одной строкой».

<a id="r21-t2"></a>
**2. [Баг-хантинг] Сравнение Integer через ==**
```java
Integer a = 127, b = 127;
System.out.println(a == b);     // true  — Integer.valueOf кэширует значения [-128, 127]
Integer c = 128, d = 128;
System.out.println(c == d);     // false — разные объекты вне кэша
Integer e = new Integer(127);   // deprecated, но живёт в старом коде
System.out.println(e == a);     // false — new всегда новый объект
```
Правило: ссылочные типы — только equals(). Гадость бага в том, что «работает» на малых числах и в тестах, а падает в проде 29-го числа месяца (id пересёк 127).

<a id="r21-t3"></a>
**3. [Баг-хантинг] equals без hashCode**
```java
class Point {
    final int x, y;
    Point(int x, int y) { this.x = x; this.y = y; }
    @Override public boolean equals(Object o) {
        return o instanceof Point p && p.x == x && p.y == y;
    }
    // hashCode НЕ переопределён
}
Set<Point> points = new HashSet<>();
points.add(new Point(1, 2));
System.out.println(points.contains(new Point(1, 2)));   // false: другой hashCode → ищем не в том бакете
map.put(new Point(1, 2), "a");
System.out.println(map.get(new Point(1, 2)));           // null — «потеряли» значение
```
Контракт: равные объекты обязаны иметь равный hashCode; иначе хеш-структуры ведут себя как описано. Фикс: `Objects.hash(x, y)`.

<a id="r21-t4"></a>
**4. [Баг-хантинг] SimpleDateFormat как статическое поле**
```java
class DateFormatter {
    private static final SimpleDateFormat FMT = new SimpleDateFormat("yyyy-MM-dd");
    static String format(Date d) { return FMT.format(d); }   // гонка: SimpleDateFormat НЕ потокобезопасен
}
// симптомы: то правильная дата, то «прыжки» года на 1970/3900, NumberFormatException
// фикс (Java 8+): DateTimeFormatter — immutable и потокобезопасен
private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
static String format(LocalDate d) { return d.format(FMT); }
```
Баг коварен малой воспроизводимостью: проявляется под нагрузкой. Альтернативный фикс — ThreadLocal<SimpleDateFormat>, но новый API лучше.

<a id="r21-t5"></a>
**5. [Баг-хантинг] Double-checked locking без volatile**
```java
class Lazy {
    private static Lazy instance;                    // нет volatile!
    public static Lazy instance() {
        if (instance == null)
            synchronized (Lazy.class) {
                if (instance == null) instance = new Lazy();
            }
        return instance;                             // другой поток видит НЕДОСТРОЕННЫЙ объект
    }
}
```
`new` — выделение памяти + инициализация полей + запись ссылки; переупорядочение шагов допустимо. Фикс: `volatile` (happens-before на запись/чтение) или holder-идиома. Показать связку с задачей про синглтоны в разделе 16.

<a id="r21-t6"></a>
**6. [Баг-хантинг] wait() вне synchronized**
```java
Object monitor = new Object();
synchronized (monitor) { /* подготовка */ }
monitor.wait();        // IllegalMonitorStateException: ждём без захваченного монитора

// правильная форма:
synchronized (monitor) {
    while (!ready)     // и только while — если пробуждение ложное
        monitor.wait();
}
```
wait снимает лок и усыпляет; вызов без лока — исключение (JLS требует владение монитором). Тот же сюжет у notify/notifyAll.

<a id="r21-t7"></a>
**7. [Баг-хантинг] return в finally**
```java
static int f() {
    try { return 1; }
    finally { return 2; }        // вернёт 2: finally выполняется ПОСЛЕ вычисления return, но ДО возврата
}
static int g() {
    int x = 1;
    try { return x; }
    finally { x = 99; }          // вернёт 1: значение уже скопировано в возвращаемый слот
}
```
finally с return/throw глотает и результат try, и его исключение. Правило: finally — только очистка (close, unlock-семантика), никаких управляемых возвратов.

<a id="r21-t8"></a>
**8. [Баг-хантинг] Утёкшая инкапсуляция**
```java
class Team {
    private final List<String> members = new ArrayList<>(List.of("ann", "bob"));
    public List<String> getMembers() { return members; }   // наружу ушла живая ссылка
}
team.getMembers().add("mallory");       // «неизменяемый» Team мутировал извне

// фикс:
public List<String> getMembers() { return List.copyOf(members); }        // копия (Java 10+)
public List<String> getMembers() { return Collections.unmodifiableList(members); } // представление: само меняться будет под ним
```
Разницу List.copyOf (снимок) и unmodifiableList (view поверх оригинала) спросят обязательно. То же для массивов: геттер массива — всегда clone().

<a id="r21-t9"></a>
**9. [Баг-хантинг] Check-then-act на HashMap**
```java
Map<Long, Cart> carts = new HashMap<>();          // общий на все запросы
Cart c = carts.get(userId);
if (c == null)
    carts.put(userId, new Cart());                // гонка: два потока увидели null, две корзины
// а при конкурентном resize HashMap может построить цикл в бакетах — get() повиснет НАВСЕГДА

// фикс:
Map<Long, Cart> carts = new ConcurrentHashMap<>();
Cart c = carts.computeIfAbsent(userId, Cart::new); // атомарно
```
HashMap под конкурентной записью — UB на уровне JDK: потерянные записи, бесконечный цикл (до Java 8 «зацикливание» — известная история prod-инцидентов). Единственный фикс — concurrent-структура.

<a id="r21-t10"></a>
**10. [Баг-хантинг] Мутабельный ключ в HashSet**
```java
List<Integer> key = new ArrayList<>(List.of(1));
Map<List<Integer>, String> map = new HashMap<>();
map.put(key, "первый");
key.add(2);                                       // hashCode ключа ИЗМЕНИЛСЯ
System.out.println(map.get(key));                 // null — запись «в другом бакете»
System.out.println(map.containsKey(List.of(1)));  // false — и по старому значению тоже не найти: ключ-то теперь [1, 2]
```
Ключи хеш-структур обязаны быть неизменяемыми (или хотя бы не мутировать hash-значимые поля). Фикс: `List.of(...)` / record / String в качестве ключа.

<a id="r21-t11"></a>
**11. [Баг-хантинг] Проглоченное исключение**
```java
try {
    save(order);
} catch (Exception e) {
    log.error("не сохранилось", e);     // залогировали — и молча продолжили «успешный» сценарий
}
chargeCustomer(order);                  // клиент платит за несуществующий заказ

// фикс: наверх с сохранением причины
catch (Exception e) {
    throw new OrderPersistenceException("order " + order.id(), e);   // e — причина, стектрейс цел
}
```
Два поучения: (1) лог ≠ обработка — если метод не может честно продолжить, исключение летит выше; (2) оборачивание без передачи причины (`new X(e.getMessage())`) выбрасывает стектрейс — всегда передавать `e` последним аргументом.

---

<a id="razdel-22"></a>
