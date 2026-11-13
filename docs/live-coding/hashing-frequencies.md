# Хеширование и частоты

> Что проверяют: выбор HashMap/HashSet как инструмента O(1)-поиска, аккуратность с компараторами, бинальный поиск по куче.

<a id="r3-t1"></a>
**1. [Классика] K самых частых элементов**
```java
static int[] topKFrequent(int[] a, int k) {
    Map<Integer, Integer> f = new HashMap<>();
    for (int x : a) f.merge(x, 1, Integer::sum);
    PriorityQueue<int[]> min = new PriorityQueue<>(Comparator.comparingInt(p -> p[1])); // мин-куча размера k
    for (Map.Entry<Integer, Integer> e : f.entrySet()) {
        min.offer(new int[]{e.getKey(), e.getValue()});
        if (min.size() > k) min.poll();          // выталкиваем самый редкий
    }
    int[] res = new int[k];
    for (int i = k - 1; i >= 0; i--) res[i] = min.poll()[0];
    return res;
}
```
O(n log k). Фоллоу-ап: bucket sort по частоте — O(n) время и память: индекс = частота.

<a id="r3-t2"></a>
**2. [Классика] Сгруппировать анаграммы**
```java
static List<List<String>> groupAnagrams(String[] words) {
    Map<String, List<String>> groups = new HashMap<>();
    for (String w : words) {
        char[] c = w.toCharArray();
        Arrays.sort(c);                                        // нормализованный ключ
        groups.computeIfAbsent(new String(c), x -> new ArrayList<>()).add(w);
    }
    return new ArrayList<>(groups.values());
}
```
O(n·m log m). Быстрее: ключ — строка из 26 счётчиков; сказать как вариант.

<a id="r3-t3"></a>
**3. [Классика|hard] Самая длинная последовательность подряд идущих чисел**
`{100,4,200,1,3,2}` → 4 (1,2,3,4). Сортировка — O(n log n); нужно O(n).
```java
static int longestConsecutive(int[] a) {
    Set<Integer> set = new HashSet<>();
    for (int x : a) set.add(x);
    int best = 0;
    for (int x : set) {
        if (set.contains(x - 1)) continue;    // начинаем только с начала последовательности
        int len = 1;
        while (set.contains(x + len)) len++;
        best = Math.max(best, len);
    }
    return best;
}
```
Каждый элемент посещается максимум дважды — суммарно O(n), хотя вложенный while. Уметь доказать.

<a id="r3-t4"></a>
**4. [Дизайн] Первый неповторяющийся символ в потоке**
Символы приходят по одному; в любой момент — запрос «первый неповторяющийся».
```java
class FirstNonRepeating {
    private final Set<Character> repeated = new HashSet<>();
    private final LinkedHashSet<Character> once = new LinkedHashSet<>(); // сохраняет порядок поступления
    public synchronized void add(char c) {
        if (!once.add(c)) { once.remove(c); repeated.add(c); }
    }
    public synchronized Character first() {
        return once.isEmpty() ? null : once.iterator().next();
    }
}
```
O(1) на операцию. Фоллоу-ап: удалять из `once` только реально существующий ключ (иначе `LinkedHashSet.remove` отсутствующего — no-op, безопасно, но проговорить).

<a id="r3-t5"></a>
**5. [Классика] Пересечение массивов с учётом кратности**
```java
static int[] intersect(int[] a, int[] b) {
    Map<Integer, Integer> f = new HashMap<>();
    for (int x : a) f.merge(x, 1, Integer::sum);
    List<Integer> res = new ArrayList<>();
    for (int x : b) {
        int left = f.getOrDefault(x, 0);
        if (left > 0) { res.add(x); f.put(x, left - 1); }
    }
    return res.stream().mapToInt(Integer::intValue).toArray();
}
```
O(n+m). Фоллоу-ап: если оба массива отсортированы — два указателя без доп. памяти.

<a id="r3-t6"></a>
**6. [Классика] Можно ли собрать заметку из букв журнала**
```java
static boolean canConstruct(String note, String magazine) {
    int[] f = new int[26];
    for (char c : magazine.toCharArray()) f[c - 'a']++;
    for (char c : note.toCharArray())
        if (--f[c - 'a'] < 0) return false;
    return true;
}
```
Одна карта частот; вычитаем и падаем на первом дефиците.

<a id="r3-t7"></a>
**7. [Классика] Дубликат на расстоянии не больше k**
```java
static boolean containsNearbyDuplicate(int[] a, int k) {
    Set<Integer> window = new HashSet<>();          // окно из последних k элементов
    for (int i = 0; i < a.length; i++) {
        if (i > k) window.remove(a[i - k - 1]);
        if (!window.add(a[i])) return true;         // add вернул false — уже в окне
    }
    return false;
}
```
O(n). Слить проверку и вставку через возвращаемое значение `add` — типичный вопрос «а можно короче?».

<a id="r3-t8"></a>
**8. [Стримы] Топ-3 самых частых слова текста**
```java
static List<String> topWords(String text, int k) {
    Map<String, Integer> f = new HashMap<>();
    for (String w : text.toLowerCase().split("\\W+"))
        if (!w.isEmpty()) f.merge(w, 1, Integer::sum);
    return f.entrySet().stream()
        .sorted(Map.Entry.<String, Integer>comparingByValue().reversed()
            .thenComparing(Map.Entry.comparingByKey()))          // равная частота — по алфавиту
        .limit(k)
        .map(Map.Entry::getKey)
        .collect(Collectors.toList());                            // toList() — Java 16+
}
```
Один проход + сортировка. Проговорить детерминированный tie-break — иначе порядок нестабилен.

---

<a id="razdel-4"></a>
