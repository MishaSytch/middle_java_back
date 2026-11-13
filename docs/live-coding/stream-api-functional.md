# Stream API и функциональный стиль

> Что проверяют: коллекционеры (groupingBy семейство), flatMap, отсутствие состояния в лямбдах, когда parallel вредит.

Для задач раздела:
```java
record Employee(String name, String dept, String city, int salary) { }
record Order(String customer, int amount) { }
```

<a id="r18-t1"></a>
**1. [Стримы] Сгруппировать сотрудников по отделам**
```java
Map<String, List<Employee>> byDept = employees.stream()
    .collect(Collectors.groupingBy(Employee::dept));
```
База. Фоллоу-ап: внизу Map с предсказуемым порядком — `groupingBy(classifier, LinkedHashMap::new, toList())`.

<a id="r18-t2"></a>
**2. [Стримы] Средняя зарплата по отделу и двухуровневая группировка**
```java
Map<String, Double> avgByDept = employees.stream()
    .collect(Collectors.groupingBy(Employee::dept, Collectors.averagingInt(Employee::salary)));

Map<String, Map<String, List<Employee>>> byCityThenDept = employees.stream()
    .collect(Collectors.groupingBy(Employee::city, Collectors.groupingBy(Employee::dept)));
```
Вложенные коллекторы читаются «изнутри наружу». Уметь объяснить разницу downstream-коллектора и внешнего.

<a id="r18-t3"></a>
**3. [Стримы] Топ-3 по зарплате; минимум в каждом отделе**
```java
List<Employee> top3 = employees.stream()
    .sorted(Comparator.comparingInt(Employee::salary).reversed())
    .limit(3)
    .collect(Collectors.toList());

Employee best = employees.stream()
    .max(Comparator.comparingInt(Employee::salary))
    .orElseThrow(() -> new NoSuchElementException("пустой список"));

Map<String, Optional<Employee>> minPerDept = employees.stream()
    .collect(Collectors.groupingBy(Employee::dept,
        Collectors.minBy(Comparator.comparingInt(Employee::salary))));
```
`Optional` в значении — цена группировки (отдел может быть без... нет, в groupingBy отдел существует только если есть элементы — Optional никогда не пуст; упомянуть `Collectors.collectingAndThen` чтобы избавиться от Optional).

<a id="r18-t4"></a>
**4. [Стримы] Разделить на прошедших/непрошедших порог**
```java
Map<Boolean, List<Employee>> parted = employees.stream()
    .collect(Collectors.partitioningBy(e -> e.salary() >= 100_000));
List<Employee> rich = parted.get(true);
```
partitioningBy всегда содержит оба ключа (true/false) — в отличие от groupingBy. Двухаргументная версия — со своим downstream.

<a id="r18-t5"></a>
**5. [Стримы] Частота слов в списке предложений**
```java
Map<String, Long> freq = sentences.stream()
    .flatMap(s -> Arrays.stream(s.split("\\W+")))     // предложение -> слова: flatMap!
    .filter(w -> !w.isEmpty())
    .collect(Collectors.groupingBy(String::toLowerCase, Collectors.counting()));
```
flatMap: один элемент → много. Ошибка-двойник: map с Arrays::stream даст Stream<Stream<String>>.

<a id="r18-t6"></a>
**6. [Стримы] Соединить имена с разделителями**
```java
String names = employees.stream()
    .map(Employee::name)
    .collect(Collectors.joining(", ", "[", "]"));   // [ann, bob, cyd]
```
joining — единственный коллектор, которому нужны именно строки: `.map(toString)` обязателен заранее.

<a id="r18-t7"></a>
**7. [Стримы] Сумма заказов по клиентам (toMap с merge)**
```java
Map<String, Integer> total = orders.stream()
    .collect(Collectors.toMap(Order::customer, Order::amount, Integer::sum));   // конфликт ключей — складываем

Map<String, Integer> total2 = orders.stream()
    .collect(Collectors.groupingBy(Order::customer, Collectors.summingInt(Order::amount)));   // эквивалент
// Фоллоу-ап (Java 12+): одновременно число заказов и сумма — teeing:
OrderStats stats = orders.stream().collect(Collectors.teeing(
    Collectors.counting(),
    Collectors.summingInt(Order::amount),
    OrderStats::new));
```
Без третьего аргумента toMap бросит IllegalStateException на дубликате ключа — любимая проверка «а вы запускали это на реальных данных?».

<a id="r18-t8"></a>
**8. [Стримы|hard] distinct по ключу (у объектов нет equals)**
```java
static <T> Predicate<T> distinctBy(Function<? super T, ?> key) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();   // потокобезопасный set — на случай parallel
    return v -> seen.add(key.apply(v));                 // add возвращает false для повтора
}

List<Employee> uniqueByDept = employees.stream()
    .filter(distinctBy(Employee::dept))
    .collect(Collectors.toList());
```
Приём «stateful predicate». Обсудить цену: память под множество, порядок сохраняется только у последовательных стримов. Альтернатива: toMap с merge (key, v) -> v — но потеряем порядок без LinkedHashMap.

<a id="r18-t9"></a>
**9. [Стримы] Топ-K записей Map по значению**
```java
LinkedHashMap<String, Integer> top = map.entrySet().stream()
    .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
    .limit(k)
    .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue,
                              (a, b) -> a, LinkedHashMap::new));
```
Типовой формат «конвертировать Map → отсортированный Map». Проговорить: K меньше N — иначе просто TreeMap с компаратором по значениям (через entrySet-обёртку).

<a id="r18-t10"></a>
**10. [Баг-хантинг] Parallel stream: три способа выстрелить в ногу**
```java
// 1) Состояние в не-потокобезопасной коллекции
List<Integer> out = new ArrayList<>();
bigList.parallelStream().forEach(out::add);          // потерянные элементы / ArrayIndexOutOfBoundsException
List<Integer> ok  = bigList.parallelStream().collect(Collectors.toList());   // collect — корректен

// 2) Неверная нейтраль в reduce
int bad  = numbers.parallelStream().reduce(0, Integer::max);   // 0 — НЕ нейтральный элемент max: max(0, -5) = 0
int good = numbers.parallelStream().reduce(Integer.MIN_VALUE, Integer::max);

// 3) Блокирующий IO в parallelStream — занимает воркеры commonPool
urls.parallelStream().forEach(u -> httpClient.call(u));        // см. completablefuture-async: нужен свой пул
```
Правило: parallel уместен для больших N-вычислений без общего состояния; выгоду мерить (JMH/System.nanoTime по-минимуму), а не угадывать.

---
<a id="razdel-19"></a>
