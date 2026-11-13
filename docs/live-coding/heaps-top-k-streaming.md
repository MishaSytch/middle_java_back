# Кучи, top-K и потоковые выборки

> Что проверяют: PriorityQueue как «максимум из потока», инвариант кучи размера k, выбор мин-кучи или макс-кучи.

<a id="r11-t1"></a>
**1. [Дизайн] K-й по величине в потоке добавлений**
```java
class KthLargest {
    private final PriorityQueue<Integer> min = new PriorityQueue<>();  // мин-куча — корень = k-й максимум
    private final int k;
    public KthLargest(int k, int[] init) {
        this.k = k;
        for (int x : init) add(x);
    }
    public int add(int x) {
        min.offer(x);
        if (min.size() > k) min.poll();      // вытесняем меньших
        return min.peek();
    }
}
```
O(log k) на добавление. Почему мин-куча для «k-й максимум» — вопрос-фильтр: корень мин-кучи размера k и есть k-й по величине.

<a id="r11-t2"></a>
**2. [Классика] Слить k отсортированных списков**
```java
static ListNode mergeK(ListNode[] lists) {
    PriorityQueue<ListNode> pq = new PriorityQueue<>(Comparator.comparingInt(n -> n.val));
    for (ListNode h : lists) if (h != null) pq.offer(h);   // по голове каждого списка
    ListNode dummy = new ListNode(0), tail = dummy;
    while (!pq.isEmpty()) {
        ListNode n = pq.poll();              // минимальная голова
        tail.next = n;
        tail = n;
        if (n.next != null) pq.offer(n.next);
    }
    return dummy.next;
}
```
O(N log k), N — суммарное число узлов. Альтернатива — попарное слияние «внахлёст», O(N log k) тоже, но хуже по константе.

<a id="r11-t3"></a>
**3. [Классика] K ближайших точек к началу координат**
```java
static int[][] kClosest(int[][] points, int k) {
    PriorityQueue<int[]> max = new PriorityQueue<>((p, q) -> Long.compare(dist2(q), dist2(p))); // макс-куча!
    for (int[] p : points) {
        max.offer(p);
        if (max.size() > k) max.poll();
    }
    return max.toArray(new int[0][]);
}
static long dist2(int[] p) { return (long) p[0] * p[0] + (long) p[1] * p[1]; }
```
Дистанцию считаем без sqrt — она монотонна. Переполнение при больших координатах исключаем умножениями в long.

<a id="r11-t4"></a>
**4. [Классика|hard] Task Scheduler: минимум слотов при охлаждении n**
```java
static int leastInterval(char[] tasks, int n) {
    int[] f = new int[26];
    for (char t : tasks) f[t - 'A']++;
    int maxFreq = 0, maxCount = 0;
    for (int x : f) {
        if (x > maxFreq) { maxFreq = x; maxCount = 1; }
        else if (x == maxFreq) maxCount++;
    }
    // каркас из самой частой задачи: (maxFreq-1) блоков по (n+1) + хвост из maxCount штук
    return Math.max(tasks.length, (maxFreq - 1) * (n + 1) + maxCount);
}
```
Формула + объяснение: длина ограничена либо количеством задач, либо каркасом самой частой. Уметь на примере A,A,A,B,B,B,n=2 показать 8.

<a id="r11-t5"></a>
**5. [Классика|hard] Медиана потока чисел**
```java
class MedianFinder {
    private final PriorityQueue<Integer> low  = new PriorityQueue<>(Comparator.reverseOrder()); // меньшая половина (макс-куча)
    private final PriorityQueue<Integer> high = new PriorityQueue<>();                          // большая половина (мин-куча)

    public void add(int x) {
        if (low.isEmpty() || x <= low.peek()) low.offer(x); else high.offer(x);
        if (low.size() > high.size() + 1) high.offer(low.poll());   // ребаланс: |size| <= 1
        else if (high.size() > low.size()) low.offer(high.poll());
    }
    public double median() {
        return low.size() > high.size() ? low.peek() : (low.peek() + high.peek()) / 2.0;
    }
}
```
O(log n) на добавление, O(1) медиана. Инвариант: всё в low ≤ всё в high, размеры отличаются максимум на 1. Объяснить наизусть — топ-вопрос собесов.

<a id="r11-t6"></a>
**6. [Классика] Last Stone Weight**
Берём два самых тяжёлых камня, разбиваем друг о друга.
```java
static int lastStone(int[] stones) {
    PriorityQueue<Integer> pq = new PriorityQueue<>(Comparator.reverseOrder());
    for (int s : stones) pq.offer(s);
    while (pq.size() > 1) {
        int y = pq.poll(), x = pq.poll();
        if (y != x) pq.offer(y - x);
    }
    return pq.isEmpty() ? 0 : pq.peek();
}
```
Моделирование на макс-куче, O(n log n). Простая задача «насколько вы знаете PriorityQueue».

---
<a id="razdel-12"></a>
