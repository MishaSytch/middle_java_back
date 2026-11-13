# Стеки, очереди, деки

> Что проверяют: инвариант «монотонный стек», амортизированные структуры, дек как окно.

<a id="r9-t1"></a>
**1. [Классика] Корректность скобочной последовательности**
```java
static boolean valid(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (char c : s.toCharArray()) {
        switch (c) {
            case '(', '[', '{' -> st.push(c);
            case ')' -> { if (st.isEmpty() || st.pop() != '(') return false; }
            case ']' -> { if (st.isEmpty() || st.pop() != '[') return false; }
            case '}' -> { if (st.isEmpty() || st.pop() != '{') return false; }
            default -> { }
        }
    }
    return st.isEmpty();          // остались незакрытые — false
}
```
O(n). Любимая ошибка: забыть финальную проверку `isEmpty` для случая `"(("`.

<a id="r9-t2"></a>
**2. [Дизайн] Стек с минимумом за O(1)**
```java
class MinStack {
    private final Deque<Integer> values = new ArrayDeque<>();
    private final Deque<Integer> mins = new ArrayDeque<>();     // параллельный стек минимумов
    public void push(int v) {
        values.push(v);
        mins.push(mins.isEmpty() || v < mins.peek() ? v : mins.peek());
    }
    public int pop()     { mins.pop(); return values.pop(); }
    public int peek()    { return values.peek(); }
    public int min()     { return mins.peek(); }
}
```
O(1) на все операции. Одностековые трюки с кодированием разницы — упомянуть, но параллельный стек — чистое решение.

<a id="r9-t3"></a>
**3. [Классика] Обратная польская запись**
```java
static int rpn(String[] tokens) {
    Deque<Integer> st = new ArrayDeque<>();
    for (String t : tokens) {
        switch (t) {
            case "+" -> st.push(st.pop() + st.pop());
            case "*" -> st.push(st.pop() * st.pop());
            case "-" -> { int b = st.pop(), a = st.pop(); st.push(a - b); }   // порядок!
            case "/" -> { int b = st.pop(), a = st.pop(); st.push(a / b); }
            default  -> st.push(Integer.parseInt(t));
        }
    }
    return st.pop();
}
```
Порядок операндов для «−» и «/» — главный источник бага. Отрицательные числа парсятся `parseInt` нормально — проговорить.

<a id="r9-t4"></a>
**4. [Классика] Следующий больший элемент для каждого**
```java
static int[] nextGreater(int[] a) {
    int[] res = new int[a.length];
    Arrays.fill(res, -1);
    Deque<Integer> st = new ArrayDeque<>();        // индексы; значения в стеке убывают
    for (int i = 0; i < a.length; i++) {
        while (!st.isEmpty() && a[st.peek()] < a[i])
            res[st.pop()] = a[i];                  // a[i] — «следующий больший» для них
        st.push(i);
    }
    return res;
}
```
Монотонный стек: каждый индекс кладётся и вынимается один раз — O(n), несмотря на вложенный while. Уметь доказать амортизированную оценку.

<a id="r9-t5"></a>
**5. [С_нуля] Очередь на двух стеках**
```java
class MyQueue<T> {
    private final Deque<T> in = new ArrayDeque<>();
    private final Deque<T> out = new ArrayDeque<>();
    public void offer(T v) { in.push(v); }
    public T poll() { peek(); return out.pop(); }
    public T peek() {
        if (out.isEmpty())                        // перекладываем лениво, один раз на элемент
            while (!in.isEmpty()) out.push(in.pop());
        return out.peek();
    }
    public boolean isEmpty() { return in.isEmpty() && out.isEmpty(); }
}
```
Амортизированно O(1): каждый элемент перекладывается ровно один раз. Классический вопрос про амортизацию.

<a id="r9-t6"></a>
**6. [Классика|hard] Максимумы всех окон длины k**
```java
static int[] windowMax(int[] a, int k) {
    int[] res = new int[a.length - k + 1];
    Deque<Integer> dq = new ArrayDeque<>();       // индексы; значения убывают; максимум — в голове
    for (int i = 0; i < a.length; i++) {
        if (!dq.isEmpty() && dq.peekFirst() <= i - k) dq.pollFirst();     // протухший индекс
        while (!dq.isEmpty() && a[dq.peekLast()] <= a[i]) dq.pollLast();  // бесполезные кандидаты
        dq.offerLast(i);
        if (i >= k - 1) res[i - k + 1] = a[dq.peekFirst()];
    }
    return res;
}
```
O(n) — дек с убывающими значениями. Наив «окно × пересчёт» — O(n·k), интервьюер обязательно спросит «а быстрее?».

<a id="r9-t7"></a>
**7. [Дизайн] История браузера: back/forward**
```java
class BrowserHistory {
    private final Deque<String> back = new ArrayDeque<>();
    private final Deque<String> forward = new ArrayDeque<>();
    private String current;
    public BrowserHistory(String home) { current = home; }
    public void visit(String url)  { back.push(current); current = url; forward.clear(); }
    public String back()     { if (back.isEmpty()) return current; forward.push(current); return current = back.pop(); }
    public String forward()  { if (forward.isEmpty()) return current; back.push(current); return current = forward.pop(); }
}
```
Два стека, `forward.clear()` при новом переходе. Спросить про лимит памяти — «предефайненный maxSize с вытеснением».

<a id="r9-t8"></a>
**8. [Классика] Сколько дней до потепления**
```java
static int[] dailyTemperatures(int[] t) {
    int[] res = new int[t.length];
    Deque<Integer> st = new ArrayDeque<>();       // индексы «ещё не дождавшихся»
    for (int i = 0; i < t.length; i++) {
        while (!st.isEmpty() && t[st.peek()] < t[i]) {
            int j = st.pop();
            res[j] = i - j;
        }
        st.push(i);
    }
    return res;
}
```
Монотонный стек «ожидающих». Остаток в стеке — дни без потепления (0 по умолчанию).

---
<a id="razdel-10"></a>
