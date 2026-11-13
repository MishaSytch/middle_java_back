# Паззлы «что выведет»

> Формат — «прочитай код вслух и предскажи вывод». Главное не угадать, а объяснить правило, по которому JVM себя ведёт.

<a id="r23-t1"></a>
**1. [Вывод] Кэш Integer**
```java
Integer a = 127, b = 127;
System.out.println(a == b);   // true
Integer c = 128, d = 128;
System.out.println(c == d);   // false
System.out.println(c.equals(d));   // true
```
Объяснение: автобоксинг вызывает `Integer.valueOf`, который кэширует значения от −128 до 127 (`IntegerCache`); вне диапазона создаются разные объекты, и `==` для ссылок сравнивает адреса. Обобщение: `==` для примитивов — значение, для ссылок — тождество; упакованные типы всегда через equals.

<a id="r23-t2"></a>
**2. [Вывод] Пул строк и конкатенация**
```java
String a = "hello";
String b = "hello";
String c = new String("hello");
String d = "hel" + "lo";                // склеится компилятором
String e = "hel" + new String("lo");    // вычислится в рантайме

System.out.println(a == b);              // true  — один объект в пуле литералов
System.out.println(a == c);              // false — new всегда новый объект
System.out.println(a == d);              // true  — константное сворачивание: литералы склеены на компиляции
System.out.println(a == e);              // false — в рантайме StringBuilder, объект мимо пула
System.out.println(a == e.intern());     // true  — intern вернёт объект из пула
System.out.println(a.equals(c));         // true  — содержимое одинаково
```
Ключевые правила: литералы интернируются; конкатенация двух констант сворачивается компилятором; конкатенация с runtime-значением — нет.

<a id="r23-t3"></a>
**3. [Вывод] finally и возврат значения**
```java
static int demo1() {
    try { return 1; }
    finally { System.out.println("finally"); }   // напечатается ДО возврата
}
static int demo2() {
    try { return 1; }
    finally { return 2; }                          // вернёт 2 — затирает результат try
}
static int demo3() {
    int x = 1;
    try { return x; }
    finally { x = 99; }                            // вернёт 1 — значение уже скопировано
}
```
Порядок JVM: вычислить return-выражение → выполнить finally → вернуть. Изменение локальной переменной в finally уже не влияет на скопированный результат, а return/throw в finally — влияют (и это антипаттерн).

<a id="r23-t4"></a>
**4. [Вывод] Порядок инициализации класса и объекта**
```java
class Parent {
    static { System.out.println("1. static Parent"); }
    { System.out.println("3. init Parent"); }
    Parent() { System.out.println("4. ctor Parent"); }
}
class Child extends Parent {
    static { System.out.println("2. static Child"); }
    { System.out.println("5. init Child"); }
    Child() { System.out.println("6. ctor Child"); }
}
new Child();
// вывод:
// 1. static Parent
// 2. static Child        (статика — один раз, при первой загрузке класса, родитель раньше)
// 3. init Parent         (далее — на каждый new: блоки инициализации ПОСЛЕ super(), ПЕРЕД телом конструктора)
// 4. ctor Parent
// 5. init Child
// 6. ctor Child
```
Порядок запоминать как: статика (родитель → потомок, единожды) → для каждого объекта: super() → init-блоки своего уровня → конструктор.

<a id="r23-t5"></a>
**5. [Вывод] Unboxing в условии тернарника**
```java
Boolean flag = null;
System.out.println(flag ? "да" : "нет");    // NullPointerException!

Integer boxed = null;
int ok   = (boxed != null) ? boxed : 0;     // ОК: guard-проверка защищает
int boom = true ? boxed : 0;                // NPE: тип выражения int — boxed распаковывается
```
Условие `Boolean` неявно распаковывается в boolean: null → NPE. Во второй паре: приоритет разрешения перегрузок делает `Integer?int` выражением типа int, и выбранная null-ветка распаковывается. Объяснять через «тернарник с смешанными Integer/int распаковывает обе ветки при определении типа».

<a id="r23-t6"></a>
**6. [Вывод] Инкремент и выбор перегрузки**
```java
int i = 0;
i = i++;
System.out.println(i);        // 0: постфикс вернул СТАРОЕ значение, инкремент — во временную переменную

static void f(int x)      { System.out.println("int"); }
static void f(Integer x)  { System.out.println("Integer"); }
static void f(int... x)   { System.out.println("varargs"); }

f(5);                       // int      — точное совпадение
f((short) 5);               // int      — расширение short→int ближе, чем боксинг
f(Integer.valueOf(5));      // Integer  — точное совпадение по ссылке
f(new int[]{5});            // varargs  — только он и подходит
// приоритет: точное совпадение > расширение примитива > боксинг > varargs
```
`i = i++` — вычислить i (0) → увеличить i (1) → присвоить сохранённое 0. Финал: i == 0. Приоритет фаз разрешения перегрузок — редкий, но «элитный» вопрос на middle.

---

<a id="razdel-24"></a>
