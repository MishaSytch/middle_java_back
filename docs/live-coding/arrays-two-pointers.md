# Массивы и два указателя

> Что проверяют: уверенная работа с индексами, инварианты цикла, замена O(n²) на O(n), аккуратность с границами.

<a id="r1-t1"></a>
**1. [Классика] Two Sum**
Дан массив чисел и target. Вернуть индексы двух чисел, дающих в сумме target.
```java
static int[] twoSum(int[] nums, int target) {
    Map<Integer, Integer> seen = new HashMap<>();       // значение -> индекс
    for (int i = 0; i < nums.length; i++) {
        Integer j = seen.get(target - nums[i]);
        if (j != null) return new int[]{j, i};
        seen.put(nums[i], i);
    }
    throw new IllegalArgumentException("пары нет");
}
```
Сложность O(n) время / O(n) память. Фоллоу-апы: «если массив отсортирован?» — два указателя с концов, O(1) памяти; «сколько пар?» — копим частоты и комбинаторика.

<a id="r1-t2"></a>
**2. [Классика] Максимальная сумма подотрезка (алгоритм Кадана)**
```java
static int maxSubArray(int[] a) {
    int best = a[0], cur = a[0];
    for (int i = 1; i < a.length; i++) {
        cur = Math.max(a[i], cur + a[i]);   // продолжаем или начинаем заново
        best = Math.max(best, cur);
    }
    return best;
}
```
O(n), один проход. Фоллоу-ап: вернуть ещё и границы отрезка — храним старт текущего при «начали заново».

<a id="r1-t3"></a>
**3. [Классика] Число подотрезков с суммой ровно k**
Массив может содержать отрицательные — окно тут не работает.
```java
static int countSubarrays(int[] a, int k) {
    Map<Long, Integer> freq = new HashMap<>(); // префиксная сумма -> сколько раз встречалась
    freq.put(0L, 1);
    long sum = 0;
    int count = 0;
    for (int x : a) {
        sum += x;
        count += freq.getOrDefault(sum - k, 0);
        freq.merge(sum, 1, Integer::sum);
    }
    return count;
}
```
O(n). Ключевой факт: сумма отрезка = разность двух префиксов. Почему окно не работает с отрицательными — обязательно объяснить.

<a id="r1-t4"></a>
**4. [Классика] Произведение всех элементов кроме текущего**
Без деления. `{"1","2","3","4"}` → `{24,12,8,6}`.
```java
static int[] productExceptSelf(int[] a) {
    int n = a.length;
    int[] res = new int[n];
    res[0] = 1;
    for (int i = 1; i < n; i++) res[i] = res[i - 1] * a[i - 1]; // произведения слева
    int right = 1;
    for (int i = n - 1; i >= 0; i--) {                          // домножаем произведениями справа
        res[i] *= right;
        right *= a[i];
    }
    return res;
}
```
O(n), O(1) дополнительной памяти (кроме ответа). Фоллоу-ап: как поведёт себя деление при нуле в массиве — почему подход «перемножить всё и делить» ломается.

<a id="r1-t5"></a>
**5. [Классика] Сдвинуть нули в конец, сохранив порядок ненулевых**
```java
static void moveZeroes(int[] a) {
    int w = 0;                                   // позиция для следующего ненулевого
    for (int i = 0; i < a.length; i++)
        if (a[i] != 0) {
            int t = a[w]; a[w++] = a[i]; a[i] = t;
        }
}
```
O(n), обмены in-place. Вариант без лишних свопов — двойной указатель с записью и последующим занулением хвоста.

<a id="r1-t6"></a>
**6. [Классика] Поворот массива на k вправо на месте**
```java
static void rotate(int[] a, int k) {
    int n = a.length;
    k %= n;
    reverse(a, 0, n - 1);   // весь массив
    reverse(a, 0, k - 1);   // первые k
    reverse(a, k, n - 1);   // хвост
}
private static void reverse(int[] a, int lo, int hi) {
    while (lo < hi) { int t = a[lo]; a[lo++] = a[hi]; a[hi--] = t; }
}
```
O(n) обменов, O(1) памяти. Обязательно обработать `k > n`. Альтернатива — циклические замены (juggling algorithm), спросить не любят, но упомянуть стоит.

<a id="r1-t7"></a>
**7. [Классика] Удалить дубликаты из отсортированного массива на месте**
Вернуть новую «длину»; хвост значения не имеет.
```java
static int removeDuplicates(int[] a) {
    if (a.length == 0) return 0;
    int w = 1;
    for (int i = 1; i < a.length; i++)
        if (a[i] != a[w - 1]) a[w++] = a[i];
    return w;
}
```
Два указателя: медленный `w` — граница «уникального» префикса. Фоллоу-ап: разрешено не более 2 повторов — сравнивать с `a[w - 2]`.

<a id="r1-t8"></a>
**8. [Классика] Найти пропущенное число из 1..n**
В массиве n−1 различных чисел из диапазона 1..n.
```java
static int missing(int[] a) {
    int n = a.length + 1;
    long sum = (long) n * (n + 1) / 2;   // n может дать переполнение int — считаем в long
    for (int x : a) sum -= x;
    return (int) sum;
}
```
XOR-вариант: `r ^= i ^ a[i]` для всех i — не боится переполнения. Оба O(n)/O(1).

<a id="r1-t9"></a>
**9. [Классика|hard] Найти единственный дубликат**
n+1 чисел из диапазона 1..n, ровно одно число повторяется. Массив менять нельзя, доп. память O(1).
```java
static int findDuplicate(int[] a) {
    int slow = a[0], fast = a[a[0]];       // Флойд: массив — неявный связный список a[i] -> a[a[i]]
    while (slow != fast) { slow = a[slow]; fast = a[a[fast]]; }
    slow = 0;                              // вторая фаза — вход в цикл
    while (slow != fast) { slow = a[slow]; fast = a[fast]; }
    return slow;
}
```
Идея: индекс → значение трактуем как ссылку; повторное число = вход в цикл. Если разрешено менять массив — проще пометить знак у `a[abs(x)]`.

<a id="r1-t10"></a>
**10. [Классика] Контейнер с водой: максимум площади**
Высоты стенок; выбрать две, максимизировать `min(h[i], h[j]) * (j - i)`.
```java
static int maxArea(int[] h) {
    int lo = 0, hi = h.length - 1, best = 0;
    while (lo < hi) {
        best = Math.max(best, (hi - lo) * Math.min(h[lo], h[hi]));
        if (h[lo] < h[hi]) lo++; else hi--;   // двигаем МЕНЬШУЮ стенку
    }
    return best;
}
```
O(n). Обоснование: сдвиг большей стенки никогда не увеличит площадь (лимитирует меньшая).

---
<a id="razdel-2"></a>
