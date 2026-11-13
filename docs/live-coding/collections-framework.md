# Collections Framework на практике

> Что проверяют: знание неочевидных возможностей (LinkedHashMap, TreeMap, EnumMap), потокобезопасность выбора, immutable-коллекций.

<a id="r14-t1"></a>
**1. [Дизайн] LRU-кэш через LinkedHashMap**
```java
class LRUCache<K, V> extends LinkedHashMap<K, V> {
    private final int cap;
    LRUCache(int cap) {
        super(16, 0.75f, true);          // accessOrder=true — порядок по доступу, не по вставке
        this.cap = cap;
    }
    @Override
    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
        return size() > cap;             // LinkedHashMap сам удалит устаревший элемент
    }
}
// НЕ потокобезопасно: для многопоточности — Collections.synchronizedMap(...) или своя реализация
```
Вопрос-бонус: почему `removeEldestEntry` — protected-хук, а не параметр (нужно кастомное условие вытеснения).

<a id="r14-t2"></a>
**2. [Классика] Индекс вхождений (мультимап руками)**
```java
Map<String, List<Integer>> index = new HashMap<>();
for (int i = 0; i < words.length; i++)
    index.computeIfAbsent(words[i], w -> new ArrayList<>()).add(i);
// НЕЛЬЗЯ: index.get(w).add(i) — NPE при отсутствии ключа
// и НЕ НУЖНО: containsKey + put — две операции вместо одной
```
`computeIfAbsent` — атомарен в ConcurrentHashMap: важный мостик к потокобезопасности.

<a id="r14-t3"></a>
**3. [Стримы] Отсортировать Map по значениям**
```java
LinkedHashMap<String, Integer> sorted = map.entrySet().stream()
    .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
    .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue,
                              (a, b) -> a, LinkedHashMap::new));   // иначе HashMap потеряет порядок
```
Обязательно `LinkedHashMap::new` в 4-м аргументе toMap — типичная ловушка. Убывающий порядок — `reversed()`.

<a id="r14-t4"></a>
**4. [Классика] Расписание слотов: floor/ceiling по TreeMap**
«Дана бронь на 12:00 — какой свободный слот ближе до неё?»
```java
TreeMap<Integer, String> slots = new TreeMap<>(Map.of(9, "s9", 11, "s11", 14, "s14"));
Map.Entry<Integer, String> before = slots.floorEntry(12);   // наибольший ключ <= 12 → 11
Map.Entry<Integer, String> after  = slots.ceilingEntry(12); // наименьший ключ >= 12 → 14
Integer exactOrPrev = slots.floorKey(12);
```
NavigableMap — недооценённый API, интервьюеры любят проверять, знает ли кандидат про него, а не тащит стримы везде.

<a id="r14-t5"></a>
**5. [Классика] EnumSet/EnumMap: посещаемость по дням**
```java
enum Day { MON, TUE, WED, THU, FRI, SAT, SUN }

EnumSet<Day> workdays = EnumSet.range(Day.MON, Day.FRI);     // битовая маска внутри
EnumSet<Day> visited  = EnumSet.noneOf(Day.class);
visited.add(Day.WED);
visited.addAll(EnumSet.of(Day.MON, Day.TUE));
EnumMap<Day, Integer> visits = new EnumMap<>(Day.class);     // массив внутри, а не хеш
```
Почему быстрее: EnumMap — массив по ordinal (O(1) без хеширования), EnumSet — битовая маска (long/long[]). Плюс строгая типизация ключей.

<a id="r14-t6"></a>
**6. [Баг-хантинг] Неизменяемая конфигурация без утечек**
```java
class Config {
    private final Map<String, String> values;
    Config(Map<String, String> source) {
        this.values = Map.copyOf(source);          // защитная копия при строительстве
    }
    public Map<String, String> asMap() { return values; }   // уже immutable — отдавать безопасно
}
// List.copyOf / Set.copyOf / Map.copyOf — Java 10+
// НЮАНС: null-ключи и null-значения приводят к NPE — в отличие от HashMap
```
Проверяют: разница «неизменяемая ссылка» (`final Map<...>` с мутабельной HashMap) и неизменяемое содержимое; `Collections.unmodifiableList` — представление над оригиналом (изменится под ним), `List.copyOf` — настоящая копия.

<a id="r14-t7"></a>
**7. [Классика] BitSet: недостающие числа из потока**
Из n чисел часть приходит на вход; вернуть пропущенные без TreeSet.
```java
static List<Integer> missing(int n, int[] present) {
    BitSet seen = new BitSet(n + 1);
    for (int x : present) seen.set(x);
    List<Integer> res = new ArrayList<>();
    for (int i = 1; i <= n; i++)
        if (!seen.get(i)) res.add(i);
    return res;
}
```
BitSet — один бит на число, в 32+ раза меньше памяти, чем `int[]`. Спросить про `nextClearBit` как ускорение подряд идущих дыр.

<a id="r14-t8"></a>
**8. [Дизайн] Частоты событий по пользователю и часу (вложенные map)**
```java
record LogLine(String user, int hour) { }

Map<String, Map<Integer, Long>> events = new HashMap<>();
for (LogLine l : logs)
    events.computeIfAbsent(l.user(), u -> new HashMap<>())   // внешний уровень
          .merge(l.hour(), 1L, Long::sum);                   // внутренний уровень
// альтернатива: record Key(String user, int hour) как один ключ Map<Key, Long>
```
Паттерн computeIfAbsent+merge для вложенных структур — типовая рабочая задача. Фоллоу-ап: составной ключ-рекорд проще и без вложенности; `EnumMap`/`int[]` для часа.

---

<a id="razdel-15"></a>
