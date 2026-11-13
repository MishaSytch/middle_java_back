# Сортировка и бинарный поиск

> Что проверяют: Comparator API, инварианты бинарного поиска, переполнение mid, аккуратность на границах.

<a id="r4-t1"></a>
**1. [Классика] Многоуровневая сортировка объектов**
Сотрудники: по убыванию зарплаты, при равенстве — по имени.
```java
record Employee(String name, String dept, String city, int salary) { }

List<Employee> sorted = new ArrayList<>(employees);
sorted.sort(Comparator.comparingInt(Employee::salary).reversed()
        .thenComparing(Employee::name));
```
Ключевое: `thenComparing` комбинатор; `reversed()` инвертирует только предыдущий уровень, а не всю цепочку — любимый вопрос-ловушка.

<a id="r4-t2"></a>
**2. [Классика] Первое и последнее вхождение в отсортированном массиве**
```java
static int first(int[] a, int t) {
    int lo = 0, hi = a.length - 1, res = -1;
    while (lo <= hi) {
        int mid = (lo + hi) >>> 1;               // беззнаковый сдвиг: (lo+hi)/2 может переполниться
        if (a[mid] >= t) { if (a[mid] == t) res = mid; hi = mid - 1; }
        else lo = mid + 1;
    }
    return res;
}
```
Последнее — симметрично (`<=`, сдвигаем `lo`). Двоится до сходимости к границе; O(log n).

<a id="r4-t3"></a>
**3. [Классика|hard] Поиск в повёрнутом отсортированном массиве**
```java
static int searchRotated(int[] a, int t) {
    int lo = 0, hi = a.length - 1;
    while (lo <= hi) {
        int mid = (lo + hi) >>> 1;
        if (a[mid] == t) return mid;
        if (a[lo] <= a[mid]) {                                   // левая половина отсортирована
            if (a[lo] <= t && t < a[mid]) hi = mid - 1; else lo = mid + 1;
        } else {                                                 // правая отсортирована
            if (a[mid] < t && t <= a[hi]) lo = mid + 1; else hi = mid - 1;
        }
    }
    return -1;
}
```
Инвариант: хотя бы одна половина отсортирована — определяем по `a[lo] <= a[mid]`. O(log n).

<a id="r4-t4"></a>
**4. [Классика] Слияние двух отсортированных массивов на месте**
В `a` длины m+n первые m отсортированы, дальше место; `b` длины n.
```java
static void merge(int[] a, int m, int[] b, int n) {
    int i = m - 1, j = n - 1, w = m + n - 1;     // запись с конца — не затираем ещё не перенесённое
    while (j >= 0) {
        if (i >= 0 && a[i] > b[j]) a[w--] = a[i--];
        else a[w--] = b[j--];
    }
}
```
Классический приём «писать с хвоста». Спросить: почему с начала нельзя.

<a id="r4-t5"></a>
**5. [Классика] Сортировка слов по кастомному алфавиту**
```java
static String[] sortByAlphabet(String[] words, String order) {
    int[] rank = new int[128];
    for (int i = 0; i < order.length(); i++) rank[order.charAt(i)] = i;
    Comparator<String> byOrder = (x, y) -> {
        int n = Math.min(x.length(), y.length());
        for (int i = 0; i < n; i++) {
            int d = rank[x.charAt(i)] - rank[y.charAt(i)];
            if (d != 0) return d;
        }
        return x.length() - y.length();
    };
    Arrays.sort(words, byOrder);
    return words;
}
```
Предвычислить ранги → компаратор O(len). Сортировка целиком O(n log n · len).

<a id="r4-t6"></a>
**6. [Классика|hard] K-й по величине без полной сортировки (quickselect)**
```java
static final java.util.Random RND = new java.util.Random();

static int kthLargest(int[] a, int k) {
    int target = a.length - k;                    // индекс в отсортированном по возрастанию
    int lo = 0, hi = a.length - 1;
    while (true) {
        int p = partition(a, lo, hi);
        if (p == target) return a[p];
        if (p < target) lo = p + 1; else hi = p - 1;
    }
}
private static int partition(int[] a, int lo, int hi) {
    int idx = lo + RND.nextInt(hi - lo + 1);      // случайный опорный — защита от худшего случая
    swap(a, idx, hi);
    int pivot = a[hi], w = lo;
    for (int i = lo; i < hi; i++)
        if (a[i] < pivot) swap(a, i, w++);
    swap(a, w, hi);
    return w;
}
private static void swap(int[] a, int i, int j) { int t = a[i]; a[i] = a[j]; a[j] = t; }
```
Среднее O(n), худшее O(n²). Альтернатива для собеса: мин-куча размера k — O(n log k), гарантированно; в потоке данных — только куча.

<a id="r4-t7"></a>
**7. [Классика] Компаратор с null-полями**
```java
Comparator<Employee> c = Comparator
    .comparing(Employee::name, Comparator.nullsLast(Comparator.naturalOrder()))
    .thenComparing(Employee::dept, Comparator.nullsFirst(Comparator.naturalOrder()));
```
`nullsLast/nullsFirst` оборачивают любой компаратор; без них NPE на первом же null. Стандартная задача «а у нас в данных бывают null».

<a id="r4-t8"></a>
**8. [Классика] Позиция вставки в отсортированный массив**
```java
static int searchInsert(int[] a, int t) {
    int lo = 0, hi = a.length;                    // полуинтервал [lo, hi)
    while (lo < hi) {
        int mid = (lo + hi) >>> 1;
        if (a[mid] < t) lo = mid + 1; else hi = mid;
    }
    return lo;
}
```
Шаблон «левая граница» с полуинтервалом: `while (lo < hi)`, ответ — `lo`. Уметь объяснить, почему цикл не зацикливается.

---
<a id="razdel-5"></a>
