# Структуры данных с нуля

> Что проверяют: понимание того, что внутри ArrayList/HashMap/кучи; амортизированные оценки; resize-стратегии.

<a id="r15-t1"></a>
**1. [С_нуля] Свой ArrayList**
```java
class MyArrayList<T> {
    private Object[] data = new Object[8];
    private int size;
    public void add(T v) {
        if (size == data.length) data = Arrays.copyOf(data, data.length * 2);  // рост x2 — амортизация O(1)
        data[size++] = v;
    }
    @SuppressWarnings("unchecked")
    public T get(int i) {
        if (i < 0 || i >= size) throw new IndexOutOfBoundsException("index " + i);
        return (T) data[i];
    }
    public T remove(int i) {
        T v = get(i);
        System.arraycopy(data, i + 1, data, i, size - i - 1);   // сдвиг хвоста влево
        data[--size] = null;                                    // не держим ссылку — GC
        return v;
    }
    public int size() { return size; }
}
```
Обязательные пояснения: рост ×2 → амортизированное add; зануление слота при remove; ArrayList из JDK shrinking не делает (только trimToSize).

<a id="r15-t2"></a>
**2. [С_нуля|hard] Свой HashMap**
```java
class MyHashMap<K, V> {
    private static final double LOAD = 0.75;
    private Node<K, V>[] buckets = new Node[8];
    private int size;

    private static class Node<K, V> {
        final K key; V value; Node<K, V> next;
        Node(K key, V value) { this.key = key; this.value = value; }
    }

    public V get(K key) {
        for (Node<K, V> n = buckets[index(key)]; n != null; n = n.next)
            if (n.key.equals(key)) return n.value;
        return null;
    }

    public void put(K key, V value) {
        int i = index(key);
        for (Node<K, V> n = buckets[i]; n != null; n = n.next)
            if (n.key.equals(key)) { n.value = value; return; }   // обновление существующего
        buckets[i] = new Node<>(key, value);                      // вставка в голову цепочки
        if (++size > buckets.length * LOAD) rehash();
    }

    private int index(K key) {   // «хеш-улучшение»: старшие биты участвуют в младших
        int h = key.hashCode();
        return (h ^ (h >>> 16)) & (buckets.length - 1);           // длина — степень двойки
    }

    @SuppressWarnings("unchecked")
    private void rehash() {
        Node<K, V>[] old = buckets;
        buckets = new Node[old.length * 2];
        size = 0;
        for (Node<K, V> head : old)
            for (Node<K, V> n = head; n != null; n = n.next)
                put(n.key, n.value);                              // переразмещение всех записей
    }

    public int size() { return size; }
}
```
Уметь рассказать: цепочки против открытой адресации; почему длина — степень двойки (`& (n-1)` вместо `%`); load factor и момент рехеша; null-ключи не поддержаны; JDK-версия с 8 превращает длинную цепочку в красно-чёрное дерево (O(log n) при плохих хешах).

<a id="r15-t3"></a>
**3. [С_нуля] Свой LinkedList с Iterable**
```java
class MyLinkedList<T> implements Iterable<T> {
    private static class Node<T> { T val; Node<T> next; Node(T v) { val = v; } }
    private Node<T> head, tail;
    private int size;

    public void add(T v) {
        Node<T> n = new Node<>(v);
        if (head == null) head = tail = n;
        else { tail.next = n; tail = n; }
        size++;
    }
    public int size() { return size; }

    @Override
    public Iterator<T> iterator() {
        return new Iterator<>() {
            Node<T> cur = head;
            @Override public boolean hasNext() { return cur != null; }
            @Override public T next() {
                if (cur == null) throw new NoSuchElementException();
                T v = cur.val;
                cur = cur.next;
                return v;
            }
        };
    }
}
```
Реализация `Iterable<T>` включает for-each — проверка, что кандидат знает про итератор, а не только про узлы.

<a id="r15-t4"></a>
**4. [С_нуля] Кольцевой буфер (bounded queue)**
```java
class RingBuffer<T> {
    private final Object[] buf;
    private int head, size;
    RingBuffer(int cap) { buf = new Object[cap]; }

    public boolean offer(T v) {                 // false — буфер полон (или расти, или блокировать)
        if (size == buf.length) return false;
        buf[(head + size) % buf.length] = v;
        size++;
        return true;
    }
    @SuppressWarnings("unchecked")
    public T poll() {
        if (size == 0) throw new NoSuchElementException();
        T v = (T) buf[head];
        buf[head] = null;
        head = (head + 1) % buf.length;
        size--;
        return v;
    }
    public int size() { return size; }
}
```
`(head + size) % len` для записи и инкремент head для чтения — два способа обойти деление по модулю. База для понимания ArrayBlockingQueue.

<a id="r15-t5"></a>
**5. [С_нуля] Своя мин-куча**
```java
class MinHeap {
    private int[] a = new int[8];
    private int size;

    public void add(int v) {
        if (size == a.length) a = Arrays.copyOf(a, a.length * 2);
        a[size] = v;
        int i = size++;
        while (i > 0 && a[i] < a[(i - 1) / 2]) { swap(i, (i - 1) / 2); i = (i - 1) / 2; }  // sift up
    }
    public int peek() {
        if (size == 0) throw new NoSuchElementException();
        return a[0];
    }
    public int poll() {
        int min = peek();
        a[0] = a[--size];
        siftDown(0);
        return min;
    }
    private void siftDown(int i) {
        while (true) {
            int l = 2 * i + 1, r = l + 1, m = i;
            if (l < size && a[l] < a[m]) m = l;
            if (r < size && a[r] < a[m]) m = r;
            if (m == i) return;
            swap(i, m);
            i = m;
        }
    }
    private void swap(int i, int j) { int t = a[i]; a[i] = a[j]; a[j] = t; }
}
```
Родитель `(i-1)/2`, дети `2i+1`/`2i+2` — знать наизусть. add/poll — O(log n), peek — O(1). Фоллоу-ап: heapify массива за O(n) — снизу вверх siftDown.

<a id="r15-t6"></a>
**6. [С_нуля] Префиксное дерево (trie)**
```java
class Trie {
    private static class Node {
        Node[] next = new Node[26];
        boolean end;
    }
    private final Node root = new Node();

    public void add(String w) {
        Node n = root;
        for (char c : w.toCharArray()) {
            int i = c - 'a';
            if (n.next[i] == null) n.next[i] = new Node();
            n = n.next[i];
        }
        n.end = true;                       // помечаем конец слова
    }
    public boolean contains(String w)  { Node n = find(w); return n != null && n.end; }
    public boolean startsWith(String p) { return find(p) != null; }
    private Node find(String s) {
        Node n = root;
        for (char c : s.toCharArray()) {
            n = n.next[c - 'a'];
            if (n == null) return null;
        }
        return n;
    }
}
```
O(len) на операцию. Применения: автодополнение, словари, IP-маршрутизация. Фоллоу-ап: узел с `Map<Character, Node>` для произвольного алфавита; поиск по префиксу с обходом поддерева.

<a id="r15-t7"></a>
**7. [С_нуля|hard] LRU-кэш на HashMap + двусвязном списке**
```java
class LRUCache<K, V> {
    private static class Node<K, V> {
        final K key; V value; Node<K, V> prev, next;
        Node(K key, V value) { this.key = key; this.value = value; }
    }
    private final Map<K, Node<K, V>> map = new HashMap<>();   // ключ -> узел
    private final Node<K, V> head = new Node<>(null, null);   // фиктивные границы
    private final Node<K, V> tail = new Node<>(null, null);
    private final int cap;

    public LRUCache(int cap) {
        this.cap = cap;
        head.next = tail;
        tail.prev = head;
    }

    public V get(K key) {
        Node<K, V> n = map.get(key);
        if (n == null) return null;
        unlink(n);
        pushFront(n);                       // любое обращение = «свежесть»
        return n.value;
    }

    public void put(K key, V value) {
        Node<K, V> n = map.get(key);
        if (n != null) { n.value = value; unlink(n); pushFront(n); return; }
        n = new Node<>(key, value);
        map.put(key, n);
        pushFront(n);
        if (map.size() > cap) {             // вытеснение хвостового (самого старого)
            Node<K, V> lru = tail.prev;
            unlink(lru);
            map.remove(lru.key);
        }
    }

    private void unlink(Node<K, V> n)       { n.prev.next = n.next; n.next.prev = n.prev; }
    private void pushFront(Node<K, V> n)    {
        n.next = head.next; n.prev = head;
        head.next.prev = n; head.next = n;
    }
}
```
O(1) на get/put. HashMap даёт доступ за O(1), список поддерживает порядок и вытеснение; узел хранит ключ — чтобы удалить из map при вытеснении. Фоллоу-апы: потокобезопасность (синхронизировать методы или шардировать); TTL поверх LRU.

<a id="r15-t8"></a>
**8. [С_нуля] Упрощённый Bloom-фильтр**
```java
class SimpleBloomFilter {
    private final BitSet bits;
    private final int size;
    SimpleBloomFilter(int size) { this.size = size; this.bits = new BitSet(size); }

    public void add(String s) {
        for (int h : hashes(s)) bits.set(h % size);
    }
    public boolean mightContain(String s) {   // false — точно нет; true — возможно (ложные срабатывания)
        for (int h : hashes(s))
            if (!bits.get(h % size)) return false;
        return true;
    }
    private int[] hashes(String s) {          // разные множители — «разные» хеш-функции
        int h1 = s.hashCode(), h2 = s.hashCode() * 31 + 7;
        return new int[]{ h1 & 0x7fffffff, h2 & 0x7fffffff };  // без Math.abs: abs(MIN_VALUE) < 0!
    }
}
```
Объяснить: нет ложноотрицательных, есть ложнопозитивные; вероятность падает с ростом размера и числа хешей; удаления нет (сброс бита заденет другие элементы). Подводный камень `Math.abs(Integer.MIN_VALUE)` — вернуть минус — стоит проговорить, интервьюеры это любят.

---
<a id="razdel-16"></a>
