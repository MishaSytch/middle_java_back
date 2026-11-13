# Динамическое программирование

> Что проверяют: переход от рекурсии к таблице, сжатие состояний до одномерного массива, направление обхода.

<a id="r7-t1"></a>
**1. [Классика] Лестница из n ступеней шагами 1 или 2**
```java
static int stairs(int n) {
    int a = 1, b = 1;                       // f(0)=1, f(1)=1
    for (int i = 2; i <= n; i++) {
        int c = a + b;
        a = b; b = c;
    }
    return b;
}
```
O(n)/O(1). Ходовой вопрос: почему O(2^n) наивная рекурсия плоха (пересчёт), и что f(n) — числа Фибоначчи; для больших n — длинная арифметика или быстрое возведение матрицы.

<a id="r7-t2"></a>
**2. [Классика] Минимальное число монет для суммы**
```java
static int minCoins(int[] coins, int amount) {
    final int INF = amount + 1;
    int[] dp = new int[amount + 1];         // dp[x] = мин. монет для суммы x
    Arrays.fill(dp, INF);
    dp[0] = 0;
    for (int x = 1; x <= amount; x++)
        for (int c : coins)
            if (c <= x) dp[x] = Math.min(dp[x], dp[x - c] + 1);
    return dp[amount] > amount ? -1 : dp[amount];
}
```
O(amount·coins). `INF = amount+1` — корректный «недостижимо», не нужен Integer.MAX_VALUE (и +1 не переполнится).

<a id="r7-t3"></a>
**3. [Классика|hard] Наибольшая возрастающая подпоследовательность за O(n log n)**
```java
static int lis(int[] a) {
    List<Integer> tails = new ArrayList<>();  // tails[i] = мин. возможный хвост НВП длины i+1
    for (int x : a) {
        int lo = 0, hi = tails.size();
        while (lo < hi) {
            int mid = (lo + hi) >>> 1;
            if (tails.get(mid) < x) lo = mid + 1; else hi = mid;   // lower bound
        }
        if (lo == tails.size()) tails.add(x); else tails.set(lo, x);
    }
    return tails.size();
}
```
База для объяснения: O(n²) — `dp[i] = max(dp[j]+1)` для всех j<i, a[i]>a[j]; затем факт о «хвостах» и бинарный поиск. `tails` — НЕ сама подпоследовательность, только её длины.

<a id="r7-t4"></a>
**4. [Классика] Наибольшая общая подпоследовательность**
```java
static int lcs(String s, String t) {
    int[][] dp = new int[s.length() + 1][t.length() + 1];
    for (int i = 1; i <= s.length(); i++)
        for (int j = 1; j <= t.length(); j++)
            dp[i][j] = s.charAt(i - 1) == t.charAt(j - 1)
                ? dp[i - 1][j - 1] + 1
                : Math.max(dp[i - 1][j], dp[i][j - 1]);
    return dp[s.length()][t.length()];
}
```
O(n·m). Фоллоу-ап: восстановить саму НОП — идти по таблице назад от `dp[n][m]`.

<a id="r7-t5"></a>
**5. [Классика] Расстояние редактирования (Левенштейна)**
```java
static int editDistance(String s, String t) {
    int[][] dp = new int[s.length() + 1][t.length() + 1];
    for (int i = 0; i <= s.length(); i++) dp[i][0] = i;     // i удалений
    for (int j = 0; j <= t.length(); j++) dp[0][j] = j;     // j вставок
    for (int i = 1; i <= s.length(); i++)
        for (int j = 1; j <= t.length(); j++) {
            int cost = s.charAt(i - 1) == t.charAt(j - 1) ? 0 : 1;
            dp[i][j] = Math.min(dp[i - 1][j - 1] + cost,      // замена/совпадение
                       Math.min(dp[i - 1][j] + 1,             // удаление из s
                                dp[i][j - 1] + 1));           // вставка в s
        }
    return dp[s.length()][t.length()];
}
```
O(n·m). Практическое применение: diff, автодополнение, fuzzy-поиск — интервьюеры любят спросить «где это используется».

<a id="r7-t6"></a>
**6. [Классика] Максимум суммы без соседних элементов**
```java
static int rob(int[] a) {
    int prev2 = 0, prev1 = 0;
    for (int x : a) {
        int cur = Math.max(prev1, prev2 + x);   // берём x (тогда соседа нельзя) или не берём
        prev2 = prev1; prev1 = cur;
    }
    return prev1;
}
```
O(n)/O(1). Фоллоу-ап: дома по кругу (первый и последний соседствуют) — два прогона: без первого и без последнего, берём max.

<a id="r7-t7"></a>
**7. [Классика] Уникальные пути в сетке m×n (только вправо/вниз)**
```java
static int uniquePaths(int m, int n) {
    int[] dp = new int[n];
    Arrays.fill(dp, 1);                       // первая строка — один путь
    for (int i = 1; i < m; i++)
        for (int j = 1; j < n; j++)
            dp[j] += dp[j - 1];               // сверху + слева
    return dp[n - 1];
}
```
O(m·n), память O(n). Комбинаторная альтернатива: C(m+n−2, m−1) — сказать.

<a id="r7-t8"></a>
**8. [Классика] Самый длинный палиндром-подстрока**
```java
static String longestPalindrome(String s) {
    int[] best = {0, 0};                      // [lo, hi) лучшего ответа
    for (int i = 0; i < s.length(); i++) {
        expand(s, i, i, best);                // нечётная длина
        expand(s, i, i + 1, best);            // чётная длина
    }
    return s.substring(best[0], best[1]);
}
private static void expand(String s, int l, int r, int[] best) {
    while (l >= 0 && r < s.length() && s.charAt(l) == s.charAt(r)) { l--; r++; }
    l++; r--;
    if (r - l + 1 > best[1] - best[0]) { best[0] = l; best[1] = r + 1; }
}
```
O(n²) время, O(1) память — расширение от центра. ДП-таблица тоже O(n²)/O(n²) — уметь нарисовать оба и сказать, что Manacher даёт O(n), но его не спрашивают писать.

<a id="r7-t9"></a>
**9. [Классика] Word Break: разбивается ли строка на слова словаря**
```java
static boolean wordBreak(String s, List<String> dict) {
    Set<String> words = new HashSet<>(dict);
    boolean[] can = new boolean[s.length() + 1];   // can[i] = разбивается ли префикс длины i
    can[0] = true;
    for (int i = 1; i <= s.length(); i++)
        for (int j = 0; j < i; j++)
            if (can[j] && words.contains(s.substring(j, i))) { can[i] = true; break; }
    return can[s.length()];
}
```
O(n²) с хеш-поиском. Улучшение: перебирать только длины слов словаря; для полного разбора — backtracking с мемоизацией.

<a id="r7-t10"></a>
**10. [Классика|hard] Разбить ли массив на два равных по сумме подмножества**
0/1-рюкзак по булевой таблице.
```java
static boolean canPartition(int[] a) {
    int sum = Arrays.stream(a).sum();
    if (sum % 2 != 0) return false;
    int target = sum / 2;
    boolean[] dp = new boolean[target + 1];      // dp[s] = набирается ли сумма s
    dp[0] = true;
    for (int x : a)
        for (int s = target; s >= x; s--)        // ОБРАТНЫЙ порядок: каждый предмет один раз
            dp[s] |= dp[s - x];
    return dp[target];
}
```
O(n·sum). Прямой порядок — ошибка: предмет попадёт в набор несколько раз (станет полным рюкзаком). Различие направлений обхода — топ-вопрос.

---
<a id="razdel-8"></a>
