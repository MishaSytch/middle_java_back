# Графы: BFS, DFS и топологическая сортировка

> Что проверяют: сетка-граф, очередь/стек, посещённость, многоисточниковый BFS, инварианты раскраски.

<a id="r12-t1"></a>
**1. [Классика] Число островов в сетке**
```java
static int islands(char[][] g) {                 // '1' — земля, '0' — вода
    int count = 0;
    for (int i = 0; i < g.length; i++)
        for (int j = 0; j < g[0].length; j++)
            if (g[i][j] == '1') { count++; sink(g, i, j); }
    return count;
}
private static void sink(char[][] g, int i, int j) {
    if (i < 0 || j < 0 || i >= g.length || j >= g[0].length || g[i][j] != '1') return;
    g[i][j] = '0';                               // «утопили» — заодно отметка посещённости
    sink(g, i + 1, j); sink(g, i - 1, j); sink(g, i, j + 1); sink(g, i, j - 1);
}
```
O(V+M). Фоллоу-апы: диагонали тоже считаются связью — добавить направления; нельзя менять вход — `boolean[][] visited` или множество «i:j»; большая сетка — итеративный стек против StackOverflowError.

<a id="r12-t2"></a>
**2. [Классика] Копия графа**
```java
class GNode { int val; List<GNode> neighbors; GNode(int v) { val = v; neighbors = new ArrayList<>(); } }

static GNode clone(GNode node) {
    if (node == null) return null;
    return dfs(node, new HashMap<>());
}
private static GNode dfs(GNode n, Map<GNode, GNode> copies) {
    if (copies.containsKey(n)) return copies.get(n);     // уже скопирован: циклы!
    GNode copy = new GNode(n.val);
    copies.put(n, copy);                                 // кладём ДО обхода соседей
    for (GNode nb : n.neighbors) copy.neighbors.add(dfs(nb, copies));
    return copy;
}
```
Помещать копию в map до рекурсии — иначе бесконечная рекурсия на цикле. Классика на понимание «visited в процессе».

<a id="r12-t3"></a>
**3. [Классика|hard] Можно ли закончить все курсы (топологическая сортировка, алгоритм Кана)**
`prerequisites[i] = {a, b}`: для курса a нужен курс b.
```java
static boolean canFinish(int numCourses, int[][] prerequisites) {
    List<List<Integer>> adj = new ArrayList<>();
    for (int i = 0; i < numCourses; i++) adj.add(new ArrayList<>());
    int[] indeg = new int[numCourses];
    for (int[] p : prerequisites) { adj.get(p[1]).add(p[0]); indeg[p[0]]++; }
    Deque<Integer> q = new ArrayDeque<>();
    for (int i = 0; i < numCourses; i++) if (indeg[i] == 0) q.offer(i);
    int seen = 0;
    while (!q.isEmpty()) {
        int c = q.poll();
        seen++;
        for (int next : adj.get(c))
            if (--indeg[next] == 0) q.offer(next);
    }
    return seen == numCourses;   // меньше — цикл, порядок невозможен
}
```
O(V+E). Фоллоу-ап: вернуть сам порядок (массив course'ов по мере poll); DFS-вариант с тремя цветами (белый/серый/чёрный, цикл = ребро в серый).

<a id="r12-t4"></a>
**4. [Классика|hard] Word Ladder: кратчайшая цепочка слов**
hot → dot → dog → cog, меняя по одной букве.
```java
static int ladderLength(String begin, String end, List<String> words) {
    Set<String> dict = new HashSet<>(words);
    if (!dict.contains(end)) return 0;
    Map<String, List<String>> pattern = new HashMap<>();      // "*ot" -> [hot, dot, lot]
    for (String w : dict)
        for (int i = 0; i < w.length(); i++)
            pattern.computeIfAbsent(w.substring(0, i) + '*' + w.substring(i + 1),
                    x -> new ArrayList<>()).add(w);
    Set<String> visited = new HashSet<>();
    visited.add(begin);
    Deque<String> q = new ArrayDeque<>();
    q.offer(begin);
    int steps = 1;
    while (!q.isEmpty()) {
        int size = q.size();
        for (int s = 0; s < size; s++) {
            String cur = q.poll();
            if (cur.equals(end)) return steps;
            for (int i = 0; i < cur.length(); i++) {
                String key = cur.substring(0, i) + '*' + cur.substring(i + 1);
                for (String next : pattern.getOrDefault(key, List.of()))
                    if (visited.add(next)) q.offer(next);
            }
        }
        steps++;
    }
    return 0;
}
```
BFS = кратчайший путь в невзвешенном графе. Вместо генерации 26 букв на позицию — предпосчитанные wildcard-группы: O(N·L) вместо O(N·26·L). Уметь объяснить, почему BFS, а не DFS.

<a id="r12-t5"></a>
**5. [Классика] Двудольный ли граф (2-раскраска)**
```java
static boolean bipartite(int[][] adj) {          // adj[v] — соседи вершины v
    int[] color = new int[adj.length];           // 0 — не раскрашен, 1 / -1 — цвета
    for (int start = 0; start < adj.length; start++) {   // граф может быть несвязным!
        if (color[start] != 0) continue;
        color[start] = 1;
        Deque<Integer> q = new ArrayDeque<>();
        q.offer(start);
        while (!q.isEmpty()) {
            int v = q.poll();
            for (int nb : adj[v]) {
                if (color[nb] == 0) { color[nb] = -color[v]; q.offer(nb); }
                else if (color[nb] == color[v]) return false;   // ребро внутри цвета
            }
        }
    }
    return true;
}
```
Забыть внешний цикл по компонентам — самая частая ошибка.

<a id="r12-t6"></a>
**6. [Классика] Гниющие апельсины: минуты до полного распространения**
```java
static int orangesRotting(int[][] g) {           // 0 пусто, 1 свежий, 2 гнилой
    Deque<int[]> q = new ArrayDeque<>();
    int fresh = 0;
    for (int i = 0; i < g.length; i++)
        for (int j = 0; j < g[0].length; j++) {
            if (g[i][j] == 2) q.offer(new int[]{i, j});     // ВСЕ источники сразу
            if (g[i][j] == 1) fresh++;
        }
    int minutes = 0;
    int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
    while (!q.isEmpty() && fresh > 0) {
        int size = q.size();
        for (int s = 0; s < size; s++) {
            int[] c = q.poll();
            for (int[] d : dirs) {
                int i = c[0] + d[0], j = c[1] + d[1];
                if (i >= 0 && j >= 0 && i < g.length && j < g[0].length && g[i][j] == 1) {
                    g[i][j] = 2;
                    fresh--;
                    q.offer(new int[]{i, j});
                }
            }
        }
        minutes++;
    }
    return fresh == 0 ? minutes : -1;
}
```
Многоисточниковый BFS с шагом «уровень = минута». Фоллоу-ап: почему начальные гнилые не добавляют минуту (счётчик инкрементится после волны — объяснить off-by-one).

<a id="r12-t7"></a>
**7. [Классика] Заливка области цветом**
```java
static int[][] floodFill(int[][] img, int sr, int sc, int color) {
    int from = img[sr][sc];
    if (from == color) return img;               // без проверки — бесконечная рекурсия!
    fill(img, sr, sc, from, color);
    return img;
}
private static void fill(int[][] img, int i, int j, int from, int color) {
    if (i < 0 || j < 0 || i >= img.length || j >= img[0].length || img[i][j] != from) return;
    img[i][j] = color;
    fill(img, i + 1, j, from, color); fill(img, i - 1, j, from, color);
    fill(img, i, j + 1, from, color); fill(img, i, j - 1, from, color);
}
```
Проверка «from == color» — обязательный edge case, о нём спрашивают.

<a id="r12-t8"></a>
**8. [С_нуля] Union-Find (системы непересекающихся множеств)**
```java
class DSU {
    private final int[] parent, rank_;
    DSU(int n) {
        parent = new int[n];
        rank_ = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;
    }
    int find(int x) {
        return parent[x] == x ? x : (parent[x] = find(parent[x]));   // сжатие пути
    }
    boolean union(int a, int b) {
        a = find(a); b = find(b);
        if (a == b) return false;              // уже вместе: ребро избыточно (цикл)
        if (rank_[a] < rank_[b]) { int t = a; a = b; b = t; }
        parent[b] = a;
        if (rank_[a] == rank_[b]) rank_[a]++;
        return true;
    }
}
// пример: число связных компонент = n - (число успешных union)
```
Почти O(1) амортизированно (обратная функция Аккермана). Применения: компоненты, циклы в неориентированном графе, Краскал. Фоллоу-ап: считать размер компоненты — массив sizes, обновляемый в union.

---

<a id="razdel-13"></a>
