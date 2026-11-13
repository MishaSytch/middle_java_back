# Деревья и BST

> Что проверяют: рекурсия с инвариантами, обходы без рекурсии, границы значений для BST.

Вспомогательный тип:
```java
class TreeNode { int val; TreeNode left, right; TreeNode(int val) { this.val = val; } }
```

<a id="r10-t1"></a>
**1. [Классика] Все обходы: рекурсивно и итеративно**
```java
static void preOrder(TreeNode n) {                 // корень, лево, право
    if (n == null) return;
    System.out.print(n.val + " ");
    preOrder(n.left);
    preOrder(n.right);
}
static void inOrder(TreeNode n) {                  // лево, корень, право — отсортированно для BST
    if (n == null) return;
    inOrder(n.left);
    System.out.print(n.val + " ");
    inOrder(n.right);
}
static void preOrderIter(TreeNode root) {
    Deque<TreeNode> st = new ArrayDeque<>();
    if (root != null) st.push(root);
    while (!st.isEmpty()) {
        TreeNode n = st.pop();
        System.out.print(n.val + " ");
        if (n.right != null) st.push(n.right);     // правого кладём первым — выйдет вторым
        if (n.left  != null) st.push(n.left);
    }
}
static void inOrderIter(TreeNode root) {
    Deque<TreeNode> st = new ArrayDeque<>();
    TreeNode cur = root;
    while (cur != null || !st.isEmpty()) {
        while (cur != null) { st.push(cur); cur = cur.left; }   // до упора влево
        cur = st.pop();
        System.out.print(cur.val + " ");
        cur = cur.right;
    }
}
static List<Integer> postOrder(TreeNode root) {    // обратный к «корень, право, лево»
    LinkedList<Integer> res = new LinkedList<>();
    Deque<TreeNode> st = new ArrayDeque<>();
    if (root != null) st.push(root);
    while (!st.isEmpty()) {
        TreeNode n = st.pop();
        res.addFirst(n.val);                       // prepend — разворачивает порядок
        if (n.left  != null) st.push(n.left);
        if (n.right != null) st.push(n.right);
    }
    return res;
}
```
Итеративный inorder — спрашивают чаще всего: «спускаемся влево, пока можем; достаём из стека; идём вправо».

<a id="r10-t2"></a>
**2. [Классика] Глубина дерева**
```java
static int depth(TreeNode n) {
    return n == null ? 0 : 1 + Math.max(depth(n.left), depth(n.right));
}
```
O(n). Фоллоу-ап: минимальная глубина — не симметричная формула! Учесть узел с одним ребёнком: `if (n.left == null) return minDepth(n.right) + 1;` и наоборот.

<a id="r10-t3"></a>
**3. [Классика] Отразить дерево**
```java
static TreeNode invert(TreeNode n) {
    if (n == null) return null;
    TreeNode t = n.left;
    n.left = invert(n.right);
    n.right = invert(t);
    return n;
}
```
O(n). Проверка на понимание: результат обходов после инверта (preorder остаётся зеркальным).

<a id="r10-t4"></a>
**4. [Классика] Симметрично ли дерево**
```java
static boolean symmetric(TreeNode root) { return mirror(root.left, root.right); }
private static boolean mirror(TreeNode a, TreeNode b) {
    if (a == null || b == null) return a == b;
    return a.val == b.val && mirror(a.left, b.right) && mirror(a.right, b.left);
}
```
Сравнение перекрёстно: `a.left ↔ b.right`. Не путать с «два одинаковых дерева» (`a.left↔b.left`).

<a id="r10-t5"></a>
**5. [Классика] Проверить корректность BST**
```java
static boolean validBST(TreeNode n) { return valid(n, Long.MIN_VALUE, Long.MAX_VALUE); }
private static boolean valid(TreeNode n, long lo, long hi) {
    if (n == null) return true;
    if (n.val <= lo || n.val >= hi) return false;        // строгое неравенство: дубликаты запрещены
    return valid(n.left, lo, n.val) && valid(n.right, n.val, hi);
}
```
Частая ошибка: проверять только «левый меньше родителя» — ломается на внуках (пример: 5 → правый 7 → левый 6 у семёрки). Границы в long — от int-экстремумов. Альтернатива: inorder-обход должен быть строго возрастающим.

<a id="r10-t6"></a>
**6. [Классика] Общий предок: в бинарном дереве и в BST**
```java
static TreeNode lca(TreeNode root, TreeNode a, TreeNode b) {   // общее дерево
    if (root == null || root == a || root == b) return root;
    TreeNode left = lca(root.left, a, b), right = lca(root.right, a, b);
    if (left != null && right != null) return root;   // развилка — это и есть предок
    return (left != null) ? left : right;
}
static TreeNode lcaBst(TreeNode root, TreeNode a, TreeNode b) { // BST: спуск по значениям
    while (root != null) {
        if (a.val < root.val && b.val < root.val)      root = root.left;
        else if (a.val > root.val && b.val > root.val) root = root.right;
        else return root;
    }
    return null;
}
```
BST-вариант O(h) без обхода. Проговорить: узел считается предком самого себя.

<a id="r10-t7"></a>
**7. [Классика] Обход по уровням списками**
```java
static List<List<Integer>> levels(TreeNode root) {
    List<List<Integer>> res = new ArrayList<>();
    if (root == null) return res;
    Queue<TreeNode> q = new ArrayDeque<>();
    q.offer(root);
    while (!q.isEmpty()) {
        int size = q.size();                    // фиксируем размер УРОВНЯ до начала выборки
        List<Integer> level = new ArrayList<>();
        for (int i = 0; i < size; i++) {
            TreeNode n = q.poll();
            level.add(n.val);
            if (n.left  != null) q.offer(n.left);
            if (n.right != null) q.offer(n.right);
        }
        res.add(level);
    }
    return res;
}
```
Паттерн «size-снимок» — базовый для всех BFS-по-уровням. Змейка (zigzag) — тот же BFS + `Collections.reverse` на нечётных уровнях.

<a id="r10-t8"></a>
**8. [Классика] Есть ли путь от корня к листу с заданной суммой**
```java
static boolean hasPathSum(TreeNode n, int target) {
    if (n == null) return false;
    if (n.left == null && n.right == null) return target == n.val;   // лист
    return hasPathSum(n.left, target - n.val) || hasPathSum(n.right, target - n.val);
}
```
Определять лист строго как «оба ребёнка null». Фоллоу-ап: собрать все пути (backtracking с общим списком).

<a id="r10-t9"></a>
**9. [Классика|hard] Сериализация/десериализация дерева**
```java
static String serialize(TreeNode root) {
    StringBuilder sb = new StringBuilder();
    ser(root, sb);
    return sb.toString();
}
private static void ser(TreeNode n, StringBuilder sb) {
    if (n == null) { sb.append("# "); return; }
    sb.append(n.val).append(' ');
    ser(n.left, sb);
    ser(n.right, sb);
}
static TreeNode deserialize(String data) {
    return des(new ArrayDeque<>(Arrays.asList(data.split(" "))));
}
private static TreeNode des(Deque<String> tokens) {
    String t = tokens.poll();
    if (t.equals("#")) return null;
    TreeNode n = new TreeNode(Integer.parseInt(t));
    n.left = des(tokens);
    n.right = des(tokens);
    return n;
}
```
Preorder + маркер `#` — минимум информации для однозначного восстановления. BST можно сериализовать только значениями (null не нужен) — упомянуть.

<a id="r10-t10"></a>
**10. [Классика] K-й наименьший элемент BST**
```java
static int kthSmallest(TreeNode root, int k) {
    Deque<TreeNode> st = new ArrayDeque<>();
    TreeNode cur = root;
    while (cur != null || !st.isEmpty()) {
        while (cur != null) { st.push(cur); cur = cur.left; }
        cur = st.pop();
        if (--k == 0) return cur.val;        // inorder выдаёт элементы по возрастанию
        cur = cur.right;
    }
    throw new IllegalArgumentException("k больше размера дерева");
}
```
Ранний выход — преимущество итеративного inorder перед рекурсивным. Фоллоу-ап: частые запросы → в узлах держать счётчик размера поддерева.

---

<a id="razdel-11"></a>
