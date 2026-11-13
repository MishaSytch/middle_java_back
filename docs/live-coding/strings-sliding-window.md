# Строки и скользящее окно

> Что проверяют: работа с char/кодами, понимание неизменяемости String, окно как приём, аккуратность с UTF-16 суррогатами.

<a id="r2-t1"></a>
**1. [Классика] Анаграммы**
```java
static boolean isAnagram(String s, String t) {
    if (s.length() != t.length()) return false;
    int[] f = new int[26];
    for (int i = 0; i < s.length(); i++) {
        f[s.charAt(i) - 'a']++;
        f[t.charAt(i) - 'a']--;
    }
    for (int x : f) if (x != 0) return false;
    return true;
}
```
O(n). Фоллоу-ап: произвольный Unicode — `HashMap<Integer,Integer>` по `codePoints()`; сортировка O(n log n) — хуже по константе.

<a id="r2-t2"></a>
**2. [Классика] Самая длинная подстрока без повторяющихся символов**
```java
static int lengthOfLongestSubstring(String s) {
    int[] last = new int[128];
    Arrays.fill(last, -1);
    int best = 0, start = 0;                     // start — левая граница окна
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if (last[c] >= start) start = last[c] + 1;  // повтор внутри окна — сдвигаем левую границу
        last[c] = i;
        best = Math.max(best, i - start + 1);
    }
    return best;
}
```
O(n) — каждый индекс входит и выходит из окна максимум один раз. Классика окна; уметь объяснить инвариант «в окне нет дубликатов».

<a id="r2-t3"></a>
**3. [Классика] Индекс первого неповторяющегося символа**
```java
static int firstUnique(String s) {
    int[] f = new int[26];
    for (char c : s.toCharArray()) f[c - 'a']++;
    for (int i = 0; i < s.length(); i++)
        if (f[s.charAt(i) - 'a'] == 1) return i;
    return -1;
}
```
Два прохода: O(n). Одним проходом по потоку символов — см. hashing-frequencies, задача про FirstNonRepeating.

<a id="r2-t4"></a>
**4. [Классика] Сжатие строки на месте**
`"aaabbc"` → `"a3b2c"`; вернуть новую длину (символ + число повторов, если больше 1).
```java
static int compress(char[] a) {
    int w = 0;
    for (int i = 0; i < a.length; ) {
        char c = a[i];
        int j = i;
        while (j < a.length && a[j] == c) j++;
        a[w++] = c;
        int len = j - i;
        if (len > 1)
            for (char d : String.valueOf(len).toCharArray()) a[w++] = d;
        i = j;
    }
    return w;
}
```
O(n). Число может быть многозначным — писать по цифрам.

<a id="r2-t5"></a>
**5. [Классика] Перевернуть порядок слов в строке**
`"  hello   world "` → `"world hello"`.
```java
static String reverseWords(String s) {
    String[] words = s.trim().split("\\s+");
    StringBuilder sb = new StringBuilder();
    for (int i = words.length - 1; i >= 0; i--) {
        sb.append(words[i]);
        if (i > 0) sb.append(' ');
    }
    return sb.toString();
}
```
Фоллоу-ап: сделать за O(1) памяти над char[] — два указателя: развернуть всю строку, затем каждое слово, попутно уплотняя пробелы.

<a id="r2-t6"></a>
**6. [Классика] Палиндром с пропуском не-букв**
`"A man, a plan, a canal: Panama"` → true.
```java
static boolean isPalindrome(String s) {
    for (int i = 0, j = s.length() - 1; i < j; ) {
        if (!Character.isLetterOrDigit(s.charAt(i))) i++;
        else if (!Character.isLetterOrDigit(s.charAt(j))) j--;
        else if (Character.toLowerCase(s.charAt(i++)) != Character.toLowerCase(s.charAt(j--))) return false;
    }
    return true;
}
```
O(n), O(1). Регекс-вариант `s.replaceAll("\\W","")` — дополнительная строка и проход, сказать про это.

<a id="r2-t7"></a>
**7. [Классика|hard] parseInt руками с ограничением по переполнению**
Как `Integer.parseInt`, но: пробелы по краям, необязательный знак, обрыв на первом нецифровом символе, клэмп в границы int при переполнении.
```java
static int parseInt(String s) {
    s = s.strip();
    if (s.isEmpty()) return 0;
    int sign = 1, i = 0;
    char c0 = s.charAt(0);
    if (c0 == '+' || c0 == '-') { if (c0 == '-') sign = -1; i = 1; }
    long acc = 0;
    for (; i < s.length(); i++) {
        char c = s.charAt(i);
        if (c < '0' || c > '9') break;
        acc = acc * 10 + (c - '0');
        if (acc > Integer.MAX_VALUE + 1L) break;   // дальше смысла копить нет
    }
    long res = sign * acc;
    if (res > Integer.MAX_VALUE) return Integer.MAX_VALUE;
    if (res < Integer.MIN_VALUE) return Integer.MIN_VALUE;
    return (int) res;
}
```
Скоп значения — в `long` (или ручная проверка `res > MAX/10`). Обязательно проговорить `Integer.MIN_VALUE` по модулю больше `MAX` на 1.

<a id="r2-t8"></a>
**8. [Классика] Римские числа в int**
```java
static int romanToInt(String s) {
    Map<Character, Integer> v = Map.of('I', 1, 'V', 5, 'X', 10, 'L', 50, 'C', 100, 'D', 500, 'M', 1000);
    int sum = 0;
    for (int i = 0; i < s.length(); i++) {
        int cur = v.get(s.charAt(i));
        sum += (i + 1 < s.length() && cur < v.get(s.charAt(i + 1))) ? -cur : cur; // IV, IX, XL...
    }
    return sum;
}
```
O(n). Инвариант: вычитание — только когда текущая цифра меньше следующей.

<a id="r2-t9"></a>
**9. [Классика] Run-length кодирование и декодирование**
```java
static String encode(String s) {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < s.length(); ) {
        char c = s.charAt(i);
        int j = i;
        while (j < s.length() && s.charAt(j) == c) j++;
        sb.append(c).append(j - i);
        i = j;
    }
    return sb.toString();
}
static String decode(String s) {                    // "a10" — счётчик многозначный
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < s.length(); ) {
        char c = s.charAt(i++);
        int n = 0;
        while (i < s.length() && Character.isDigit(s.charAt(i)))
            n = n * 10 + (s.charAt(i++) - '0');
        sb.append(String.valueOf(c).repeat(n));      // Java 11+
    }
    return sb.toString();
}
```
Проговорить ограничение формата: исходный алфавит не должен содержать цифр — иначе нужно экранирование.

<a id="r2-t10"></a>
**10. [Классика] Изоморфные строки**
`"paper"`/`"title"` → true (взаимно однозначная замена символов).
```java
static boolean isIsomorphic(String s, String t) {
    int[] m1 = new int[128], m2 = new int[128];
    Arrays.fill(m1, -1);
    Arrays.fill(m2, -1);
    for (int i = 0; i < s.length(); i++) {
        char a = s.charAt(i), b = t.charAt(i);
        if (m1[a] != -1 && m1[a] != b) return false;
        if (m2[b] != -1 && m2[b] != a) return false;
        m1[a] = b; m2[b] = a;
    }
    return true;
}
```
Две карты: s→t И t→s. Частая ошибка кандидатов — проверять только одно направление.

---
<a id="razdel-3"></a>
