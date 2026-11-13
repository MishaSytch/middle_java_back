# Связные списки

> Что проверяют: перелинковка указателей без потери узлов, fixed-узор «фиктивная голова», slow/fast.

Вспомогательный тип для всех задач:
```java
class ListNode { int val; ListNode next; ListNode(int val) { this.val = val; } }
```

<a id="r8-t1"></a>
**1. [Классика] Развернуть список. Итеративно и рекурсивно**
```java
static ListNode reverse(ListNode head) {
    ListNode prev = null;
    while (head != null) {
        ListNode next = head.next;   // запомнили хвост
        head.next = prev;            // развернули ссылку
        prev = head;                 // сдвинули prev
        head = next;                 // сдвинули head
    }
    return prev;
}
static ListNode reverseRec(ListNode head) {
    if (head == null || head.next == null) return head;
    ListNode newHead = reverseRec(head.next);
    head.next.next = head;
    head.next = null;
    return newHead;
}
```
O(n). Рекурсивная версия — O(n) стека: уметь объяснить переприсваивание `head.next.next = head` на рисунке из 3 узлов.

<a id="r8-t2"></a>
**2. [Классика|hard] Цикл: обнаружить и найти его начало**
```java
static ListNode cycleStart(ListNode head) {
    ListNode slow = head, fast = head;
    while (fast != null && fast.next != null) {
        slow = slow.next;
        fast = fast.next.next;
        if (slow == fast) {              // встретились внутри цикла
            slow = head;
            while (slow != fast) { slow = slow.next; fast = fast.next; }
            return slow;                 // вход в цикл
        }
    }
    return null;                         // цикла нет
}
```
Флойд. Объяснение второй фазы: пусть до входа в цикл d, цикл длины c; на встрече slow прошёл d + k, fast — d + k + m·c, и 2(d+k) = d+k+m·c → d + k ≡ 0 (mod c). Значит, от головы и от точки встречи до входа — одинаковое число шагов.

<a id="r8-t3"></a>
**3. [Классика] Середина списка**
```java
static ListNode middle(ListNode head) {
    ListNode slow = head, fast = head;
    while (fast != null && fast.next != null) {
        slow = slow.next;
        fast = fast.next.next;
    }
    return slow;   // чётная длина — второй из двух средних
}
```
Один проход. Фоллоу-ап: вернуть первый из средних — условие `fast.next != null && fast.next.next != null`.

<a id="r8-t4"></a>
**4. [Классика] Слить два отсортированных списка**
```java
static ListNode merge(ListNode a, ListNode b) {
    ListNode dummy = new ListNode(0), tail = dummy;
    while (a != null && b != null) {
        if (a.val <= b.val) { tail.next = a; a = a.next; }
        else                { tail.next = b; b = b.next; }
        tail = tail.next;
    }
    tail.next = (a != null) ? a : b;    // прицепили остаток
    return dummy.next;
}
```
Фиктивная голова (dummy) избавляет от if на первом элементе — проговорить этот приём явно.

<a id="r8-t5"></a>
**5. [Классика] Удалить n-й узел с конца за один проход**
```java
static ListNode removeNth(ListNode head, int n) {
    ListNode dummy = new ListNode(0);
    dummy.next = head;
    ListNode fast = dummy, slow = dummy;
    for (int i = 0; i <= n; i++) fast = fast.next;   // разрыв n между slow и fast
    while (fast != null) { fast = fast.next; slow = slow.next; }
    slow.next = slow.next.next;
    return dummy.next;
}
```
dummy обязателен: удаляемый может быть головой (n = длина).

<a id="r8-t6"></a>
**6. [Классика] Палиндром-список за O(n) время / O(1) памяти**
```java
static boolean isPalindrome(ListNode head) {
    ListNode mid = middle(head);
    ListNode second = reverse(mid);      // развернули вторую половину
    ListNode p1 = head, p2 = second;
    boolean ok = true;
    while (p2 != null) {
        if (p1.val != p2.val) { ok = false; break; }
        p1 = p1.next; p2 = p2.next;
    }
    return ok;   // по желанию восстановить: middle-узел.next = reverse(second)
}
```
Три шага: середина → реверс половины → сравнение. Не забыть: интеграция «восстановить список» — вежливый ответ на фоллоу-ап.

<a id="r8-t7"></a>
**7. [Классика] Сложить два числа, заданных списками в обратном порядке**
`(2→4→3) + (5→6→4)` = `7→0→8` (342 + 465 = 807).
```java
static ListNode add(ListNode a, ListNode b) {
    ListNode dummy = new ListNode(0), tail = dummy;
    int carry = 0;
    while (a != null || b != null || carry != 0) {
        int sum = carry;
        if (a != null) { sum += a.val; a = a.next; }
        if (b != null) { sum += b.val; b = b.next; }
        tail.next = new ListNode(sum % 10);
        tail = tail.next;
        carry = sum / 10;
    }
    return dummy.next;
}
```
Условие цикла с `carry != 0` обрабатывает появление нового разряда (999 + 1).

<a id="r8-t8"></a>
**8. [Классика|hard] Копия списка с random-указателем**
```java
class RNode { int val; RNode next, random; }

static RNode copy(RNode head) {
    Map<RNode, RNode> map = new HashMap<>();       // старый узел -> его копия
    for (RNode p = head; p != null; p = p.next)
        map.put(p, new RNode(p.val));
    for (RNode p = head; p != null; p = p.next) {
        RNode c = map.get(p);
        c.next = map.get(p.next);       // map.get(null) == null — корректно
        c.random = map.get(p.random);
    }
    return map.get(head);
}
```
O(n)/O(n). Фоллоу-ап: O(1) памяти — трюк с вплетением копий `A→A'→B→B'...` с последующим разъединением; уметь описать словами.

---

<a id="razdel-9"></a>
