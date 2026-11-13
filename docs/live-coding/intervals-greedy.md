# Интервалы и жадные алгоритмы

> Что проверяют: сортировка как подготовка жадности, инвариант «текущий конец», отличие от ДП.

<a id="r13-t1"></a>
**1. [Классика] Слить пересекающиеся интервалы**
```java
static int[][] merge(int[][] intervals) {
    Arrays.sort(intervals, Comparator.comparingInt(a -> a[0]));
    List<int[]> res = new ArrayList<>();
    for (int[] cur : intervals) {
        if (!res.isEmpty() && cur[0] <= res.get(res.size() - 1)[1])          // пересекается
            res.get(res.size() - 1)[1] = Math.max(res.get(res.size() - 1)[1], cur[1]);
        else res.add(cur);
    }
    return res.toArray(new int[0][]);
}
```
O(n log n). Сортировка по старту — после неё пересекающиеся интервалы соседствуют. `Math.max` по концу — вложенные интервалы.

<a id="r13-t2"></a>
**2. [Классика] Может ли человек посетить все встречи**
```java
static boolean canAttendAll(int[][] meetings) {
    Arrays.sort(meetings, Comparator.comparingInt(a -> a[0]));
    for (int i = 1; i < meetings.length; i++)
        if (meetings[i][0] < meetings[i - 1][1]) return false;   // начало раньше прошлого конца
    return true;
}
```
O(n log n). Является ли «встреча начинается ровно в конце прошлой» пересечением — уточнить у интервьюера ([start, end) — нет).

<a id="r13-t3"></a>
**3. [Классика|hard] Минимальное число переговорных**
```java
static int minRooms(int[][] meetings) {
    Arrays.sort(meetings, Comparator.comparingInt(a -> a[0]));
    PriorityQueue<Integer> ends = new PriorityQueue<>();   // времена окончания активных встреч
    for (int[] m : meetings) {
        if (!ends.isEmpty() && ends.peek() <= m[0]) ends.poll();   // комната освободилась — переиспользуем
        ends.offer(m[1]);
    }
    return ends.size();    // размер кучи в пике = число одновременно идущих встреч
}
```
O(n log n). Альтернатива — два отсортированных массива стартов/концов с двумя указателями; объяснить эквивалентность. Обязательно пройти пример, где комнаты переиспользуются.

<a id="r13-t4"></a>
**4. [Классика] Минимум интервалов к удалению, чтобы убрать пересечения**
```java
static int eraseOverlap(int[][] intervals) {
    Arrays.sort(intervals, Comparator.comparingInt(a -> a[1]));   // по КОНЦУ
    int kept = 0, end = Integer.MIN_VALUE;
    for (int[] iv : intervals)
        if (iv[0] >= end) { kept++; end = iv[1]; }                // жадно берём заканчивающийся раньше
    return intervals.length - kept;
}
```
Жадность «минимальный конец» доказывается обменным аргументом — уметь пересказать: раньше заканчивающийся интервал не хуже любого другого для будущих.

<a id="r13-t5"></a>
**5. [Классика] Достижим ли последний индекс прыжками**
```java
static boolean canJump(int[] a) {
    int reach = 0;
    for (int i = 0; i < a.length; i++) {
        if (i > reach) return false;             // в эту клетку не добраться
        reach = Math.max(reach, i + a[i]);
    }
    return true;
}
```
O(n)/O(1). Инвариант: `reach` — самая правая достижимая клетка. Фоллоу-ап: минимальное число прыжков — BFS-по-уровням на той же идее.

<a id="r13-t6"></a>
**6. [Классика|hard] Круговая маршрутка: с какой заправки стартовать**
`gas[i]`/`cost[i]`, объезд по кругу.
```java
static int canCompleteCircuit(int[] gas, int[] cost) {
    int total = 0, tank = 0, start = 0;
    for (int i = 0; i < gas.length; i++) {
        int d = gas[i] - cost[i];
        total += d;
        tank += d;
        if (tank < 0) { start = i + 1; tank = 0; }   // с любого старта до i не доехать — стартуем после
    }
    return total >= 0 ? start : -1;
}
```
Два факта: суммарный дефицит ≥ 0 → решение существует; если из старта s до i не хватило — ни один старт внутри (s, i] не годится. O(n) один проход.

---
<a id="razdel-14"></a>
