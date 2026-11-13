# Рефакторинг

> Формат «улучши код, сохранив поведение»: оценивается способность видеть запахи кода и малыми шагами улучшать. Проговаривай каждый шаг — интервьюер оценивает ход мысли.

<a id="r22-t1"></a>
**1. [Рефакторинг] Пирамида вложенных if → guard clauses**
```java
// ДО
double orderTotal(Order o) {
    if (o != null) {
        if (o.items() != null) {
            if (!o.items().isEmpty()) {
                double sum = 0;
                for (Item i : o.items()) sum += i.price() * i.qty();
                return sum;
            } else return 0;
        } else return 0;
    } else throw new IllegalArgumentException();
}
// ПОСЛЕ
double orderTotal(Order o) {
    if (o == null) throw new IllegalArgumentException("order");
    List<Item> items = o.items() == null ? List.of() : o.items();
    return items.stream().mapToDouble(i -> i.price() * i.qty()).sum();
}
```
Принцип: «возвращайся как можно раньше». Основной сценарий остаётся на нулевом уровне вложенности.

<a id="r22-t2"></a>
**2. [Рефакторинг] Цепочка null-проверок → Optional**
```java
// ДО
String city = null;
if (user != null) {
    Address addr = user.getAddress();
    if (addr != null) city = addr.getCity();
}

// ПОСЛЕ
Optional<String> city = Optional.ofNullable(user)
    .map(User::getAddress)
    .map(Address::getCity);
String resolved = city.orElse("не указан");
```
Сразу оговорить (спрашивают!): Optional — тип возврата, а не тип поля/параметра; `orElseGet` против eager `orElse`; не `Optional.get()` без проверки.

<a id="r22-t3"></a>
**3. [Рефакторинг] Императивный цикл → конвейер стрима**
```java
// ДО
List<String> names = new ArrayList<>();
for (Employee e : employees)
    if (e.salary() > 100_000 && e.dept().equals("IT"))
        names.add(e.name().toUpperCase());

// ПОСЛЕ
List<String> names = employees.stream()
    .filter(e -> e.dept().equals("IT"))
    .filter(e -> e.salary() > 100_000)
    .map(e -> e.name().toUpperCase())
    .collect(Collectors.toList());
```
Шаги рефакторинга называть вслух: фильтры вперёд (меньше работы дальше), map в конце. Сказать, когда цикл лучше: побочные эффекты, break по сложному условию, изменение нескольких коллекций.

<a id="r22-t4"></a>
**4. [Рефакторинг] switch по коду типа → полиморфизм**
```java
// ДО: тип в поле, поведение размазано по switch
double area(ShapeData s) {
    return switch (s.type()) {
        case CIRCLE -> Math.PI * s.r() * s.r();
        case RECT   -> s.w() * s.h();
        default -> throw new IllegalStateException();
    };
}
// и ещё switch в toString(), в validate(), в export()...

// ПОСЛЕ: поведение живёт рядом с данными
sealed interface Shape permits Circle, Rect { double area(); }
record Circle(double r) implements Shape { public double area() { return Math.PI * r * r; } }
record Rect(double w, double h) implements Shape { public double area() { return w * h; } }
```
Признак к рефакторингу: switch по одному и тому же полю в нескольких местах. Новая фигура = новый класс, нулевые правки существующих.

<a id="r22-t5"></a>
**5. [Рефакторинг] Магические строки → enum**
```java
// ДО: опечатка = тихий баг, автодополнение не поможет
if (user.getRole().equals("ADIN")) return false;
// ...и так в 20 местах

// ПОСЛЕ
enum Role { ADMIN, USER, SUPPORT }
if (user.role() != Role.ADMIN) return false;
```
Область значений фиксируется компилятором; enum умеет методы и поля (права доступа). String остаётся только на границах (DTO/БД) + маппинг в enum раз в одном месте.

<a id="r22-t6"></a>
**6. [Рефакторинг] Телескопический конструктор → объект-параметр**
```java
// ДО
createOrder(userId, sku, qty, currency, gift, promo, note, urgent);   // 8 параметров, 4 перегрузки

// ПОСЛЕ
record OrderRequest(String userId, String sku, int qty, Currency currency,
                    boolean gift, Optional<String> promo) {
    public OrderRequest {                                  // валидация в одном месте
        if (qty < 1) throw new IllegalArgumentException("qty");
    }
}
void createOrder(OrderRequest req) { /* ... */ }
```
Record-параметр: иммутабелен, самодокументируем, расширяется без ломки сигнатур. Для дефолтов и пошаговой сборки — билдер (см. oop-mini-systems).

<a id="r22-t7"></a>
**7. [Рефакторинг] Три почти одинаковых цикла → дженерик-метод**
```java
// ДО: groupEmployeesByDept(), groupOrdersByCustomer(), groupUsersByCity() — копипаст

// ПОСЛЕ
static <T, K> Map<K, List<T>> groupBy(Collection<T> items, Function<T, K> key) {
    Map<K, List<T>> res = new HashMap<>();
    for (T item : items)
        res.computeIfAbsent(key.apply(item), k -> new ArrayList<>()).add(item);
    return res;
}
Map<String, List<Employee>> byDept = groupBy(employees, Employee::dept);
Map<String, List<Order>> byCustomer = groupBy(orders, Order::customer);
```
Функция-ключ — единственная точка различия. Проверить: поведение сохранено, дженерик не «переусложнён» (одна ответственность).

<a id="r22-t8"></a>
**8. [Рефакторинг] Разбор god-метода (ход рассуждений)**
Дан метод `processRequest(...)` на 300 строк: валидация, авторизация, тарификация, запись в БД, уведомления, логи — всё в одном.
Шаги, которые ожидают услышать:
1. Выделить «абзацы» по пустым строкам/комментариям — кандидаты в Extract Method.
2. Именовать каждый по глаголу бизнес-действия: `validate`, `authorize`, `charge`, `persist`, `notify`.
3. Ввести объект-контекст (record `RequestContext`), чтобы не таскать 10 параметров.
4. Побочные эффекты (логи, метрики) — декораторами/перехватчиками, а не внутрь логики.
5. Разные уровни абстракции не смешивать: метод либо оркестрирует, либо делает работу.
6. После каждого шага — тесты зелёные (малые безопасные шажки, не «перепишем всё»).
```java
Response processRequest(Request r) {
    RequestContext ctx = validate(r);          // бросает IllegalArgumentException
    authorize(ctx);
    charge(ctx);
    Order saved = persist(ctx);
    notify(saved);
    return Response.ok(saved.id());
}
```

---
<a id="razdel-23"></a>
