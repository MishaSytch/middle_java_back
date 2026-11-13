# Числа и битовые операции

> Что проверяют: переполнение int, модульная арифметика, битовые трюки и границы примитивов.

<a id="r5-t1"></a>
**1. [Классика] Решето Эратосфена**
Все простые до n.
```java
static boolean[] sieve(int n) {
    boolean[] composite = new boolean[n + 1];
    for (int p = 2; (long) p * p <= n; p++)      // p*p — уже int*int: привести к long
        if (!composite[p])
            for (int q = p * p; q <= n; q += p) composite[q] = true;
    return composite;                             // !composite[i] && i >= 2 => простое
}
```
O(n log log n). Начинать зачёркивание с p² — всё меньшее уже зачёркнуто меньшими делителями.

<a id="r5-t2"></a>
**2. [Классика] НОД/НОК и сокращение дроби**
```java
static int gcd(int a, int b) {
    while (b != 0) { int t = a % b; a = b; b = t; }
    return Math.abs(a);
}
static int lcm(int a, int b) { return a / gcd(a, b) * b; }   // сначала делим — против переполнения
record Frac(int num, int den) {
    Frac {
        if (den == 0) throw new IllegalArgumentException("den = 0");
        if (den < 0) { num = -num; den = -den; }             // знак держим в числителе
        int g = gcd(Math.abs(num), den);
        num /= g; den /= g;
    }
}
```
Евклид за O(log min(a,b)). Проговорить: `a / gcd * b`, а не `a * b / gcd` — второе переполняется раньше.

<a id="r5-t3"></a>
**3. [Классика] Число, встречающееся один раз, остальные — дважды**
```java
static int singleNumber(int[] a) {
    int r = 0;
    for (int x : a) r ^= x;      // пары взаимоуничтожаются: x ^ x = 0
    return r;
}
```
O(n)/O(1). Фоллоу-ап (hard): если два числа встречаются по разу — XOR всех даёт `x ^ y`; по младшему установленному биту результата делим массив на две группы и XOR-им каждую отдельно.

<a id="r5-t4"></a>
**4. [Классика] Быстрое возведение в степень по модулю**
```java
static long powMod(long base, long exp, long mod) {
    long res = 1;
    base %= mod;
    while (exp > 0) {
        if ((exp & 1) == 1) res = res * base % mod;
        base = base * base % mod;
        exp >>= 1;
    }
    return res;
}
```
O(log exp) умножений. Умножения — в long, если mod близок к 10^9: `int*int` переполнится.

<a id="r5-t5"></a>
**5. [Классика|hard] Перевернуть число с контролем переполнения**
```java
static int reverse(int x) {
    int res = 0;
    while (x != 0) {
        int digit = x % 10;
        x /= 10;
        if (res > Integer.MAX_VALUE / 10 || (res == Integer.MAX_VALUE / 10 && digit > 7)) return 0;
        if (res < Integer.MIN_VALUE / 10 || (res == Integer.MIN_VALUE / 10 && digit < -8)) return 0;
        res = res * 10 + digit;
    }
    return res;
}
```
Проверять ДО умножения. `MIN_VALUE = -2147483648` — последняя цифра -8, у MAX — 7: поэтому константы 7 и -8. Сказать про `Math.multiplyExact/addExact` как альтернативу через ArithmeticException.

<a id="r5-t6"></a>
**6. [Классика] Битовые трюки: степень двойки, подсчёт битов, обмен**
```java
static boolean isPow2(int x) { return x > 0 && (x & (x - 1)) == 0; }   // у степени двойки один бит
static int countBits(int x) {                                            // Керниган
    int n = 0;
    while (x != 0) { x &= x - 1; n++; }                                  // каждый шаг гасит младший установленный бит
    return n;
}
// в проде: Integer.bitCount(x) — табличная реализация
static void swap(int[] a, int i, int j) {   // XOR-обмен — только показать понимание битов
    if (i == j) return;                    // без проверки затрёт значение нулём!
    a[i] ^= a[j]; a[j] ^= a[i]; a[i] ^= a[j];
}
```
Уметь объяснить каждый трюк на примере на бумаге — интервьюер любит «покажи на числе 12».

---

<a id="razdel-6"></a>
