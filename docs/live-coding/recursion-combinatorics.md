# Рекурсия и комбинаторика

> Что проверяют: выход из рекурсии, копирование состояния при возврате (backtracking), оценка числа путей.

<a id="r6-t1"></a>
**1. [Классика] Все перестановки**
```java
static List<List<Integer>> permutations(int[] a) {
    List<List<Integer>> res = new ArrayList<>();
    backtrack(a, new boolean[a.length], new ArrayList<>(), res);
    return res;
}
private static void backtrack(int[] a, boolean[] used, List<Integer> cur, List<List<Integer>> res) {
    if (cur.size() == a.length) { res.add(new ArrayList<>(cur)); return; } // КОПИЯ!
    for (int i = 0; i < a.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        cur.add(a[i]);
        backtrack(a, used, cur, res);
        cur.remove(cur.size() - 1);            // откат состояния
        used[i] = false;
    }
}
```
O(n·n!). Главная ошибка — положить в результат сам `cur` без копии: он продолжит мутировать.

<a id="r6-t2"></a>
**2. [Классика] Все подмножества (power set)**
```java
static List<List<Integer>> subsets(int[] a) {
    List<List<Integer>> res = new ArrayList<>();
    dfs(a, 0, new ArrayList<>(), res);
    return res;
}
private static void dfs(int[] a, int i, List<Integer> cur, List<List<Integer>> res) {
    if (i == a.length) { res.add(new ArrayList<>(cur)); return; }
    dfs(a, i + 1, cur, res);                               // без a[i]
    cur.add(a[i]);
    dfs(a, i + 1, cur, res);                               // с a[i]
    cur.remove(cur.size() - 1);
}
```
O(2^n). Битовый вариант: перебор масок 0..2^n−1 — сказать как альтернатива.

<a id="r6-t3"></a>
**3. [Классика] Combination Sum: набор монет, дающий сумму (повторения разрешены)**
```java
static List<List<Integer>> combinationSum(int[] candidates, int target) {
    List<List<Integer>> res = new ArrayList<>();
    Arrays.sort(candidates);
    cs(candidates, 0, target, new ArrayList<>(), res);
    return res;
}
private static void cs(int[] cand, int start, int target, List<Integer> cur, List<List<Integer>> res) {
    if (target == 0) { res.add(new ArrayList<>(cur)); return; }
    for (int i = start; i < cand.length; i++) {
        if (cand[i] > target) break;                    // отсортированы — дальше только больше
        cur.add(cand[i]);
        cs(cand, i, target - cand[i], cur, res);        // i, а не i+1: элемент можно брать повторно
        cur.remove(cur.size() - 1);
    }
}
```
`start` отсекает дубликатные комбинации — «2,2,3» и «2,3,2» не обе.

<a id="r6-t4"></a>
**4. [Классика] Буквы телефонного калькулятора**
```java
private static final String[] KEYS = {"", "", "abc", "def", "ghi", "jkl", "mno", "pqrs", "tuv", "wxyz"};

static List<String> keypad(String digits) {
    List<String> res = new ArrayList<>();
    if (!digits.isEmpty()) backtrack(digits, 0, new StringBuilder(), res);
    return res;
}
private static void backtrack(String d, int i, StringBuilder sb, List<String> res) {
    if (i == d.length()) { res.add(sb.toString()); return; }
    for (char c : KEYS[d.charAt(i) - '0'].toCharArray()) {
        sb.append(c);
        backtrack(d, i + 1, sb, res);
        sb.deleteCharAt(sb.length() - 1);
    }
}
```
O(4^n). StringBuilder переиспользуется — append/delete на каждом шаге.

<a id="r6-t5"></a>
**5. [Классика] Сгенерировать все корректные скобочные последовательности**
```java
static List<String> generateParentheses(int n) {
    List<String> res = new ArrayList<>();
    gen(n, n, new StringBuilder(), res);
    return res;
}
private static void gen(int open, int close, StringBuilder sb, List<String> res) {
    if (open == 0 && close == 0) { res.add(sb.toString()); return; }
    if (open > 0)     { sb.append('('); gen(open - 1, close, sb, res); sb.deleteCharAt(sb.length() - 1); }
    if (close > open) { sb.append(')'); gen(open, close - 1, sb, res); sb.deleteCharAt(sb.length() - 1); }
}
```
Инварианты: открывающих осталось ≥ 0; закрывающую ставим только если уже есть незакрытая открывающая (`close > open`). Число Каталана.

<a id="r6-t6"></a>
**6. [Классика] Развернуть произвольно вложенный список**
```java
static void flatten(List<Object> nested, List<Integer> out) {
    for (Object o : nested) {
        if (o instanceof List<?> inner) flatten((List<Object>) inner, out);  // Java 16+ pattern matching
        else out.add((Integer) o);
    }
}
```
Фоллоу-ап: та же задача итеративно через явный стек `Deque<Iterator<?>>` — частый вопрос на middle, уметь набросать.

<a id="r6-t7"></a>
**7. [Классика] Рекурсивный реверс строки и разговор о TCO**
```java
static String reverse(String s) {
    return s.isEmpty() ? s : reverse(s.substring(1)) + s.charAt(0);
}
```
O(n²) по времени (конкатенация) и O(n²) памяти; глубина стека O(n), на строке в миллионы символов — StackOverflowError. В Java НЕТ оптимизации хвостовой рекурсии — итеративный вариант со StringBuilder обязателен. Любят спрашивать «чем плох этот красивый однострочник».

<a id="r6-t8"></a>
**8. [Классика] Ханойские башни**
```java
static void hanoi(int n, char from, char to, char via, List<String> moves) {
    if (n == 0) return;
    hanoi(n - 1, from, via, to, moves);
    moves.add(from + " -> " + to);
    hanoi(n - 1, via, to, from, moves);
}
// число перемещений: 2^n - 1
```
Классика объяснения рекурсии: «снимаем n−1 на запасную, перекладываем нижний, возвращаем n−1 сверху».

---
<a id="razdel-7"></a>
