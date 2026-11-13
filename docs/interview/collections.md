# Коллекции

### 1. Какие основные интерфейсы Collection Framework

Основные интерфейсы Java Collection Framework:
- **`Collection`** — корневой интерфейс для всех коллекций (кроме `Map`). Определяет базовые методы: `add`, `remove`, `size`, `iterator`, `contains`.
- **`List`** — упорядоченная коллекция с доступом по индексу, допускает дубликаты. Реализации: `ArrayList`, `LinkedList`, `Vector`, `Stack`.
- **`Set`** — коллекция, не допускающая дубликатов. Реализации: `HashSet`, `LinkedHashSet`, `TreeSet`, `EnumSet`.
- **`Queue`** — коллекция для организации очереди (обычно FIFO). Реализации: `LinkedList`, `PriorityQueue`, `ArrayDeque`, `BlockingQueue` и её наследники.
- **`Deque`** — двусторонняя очередь (double-ended queue). Реализации: `ArrayDeque`, `LinkedList`.
- **`Map`** — отображение «ключ-значение», не наследует `Collection`, но входит в фреймворк. Реализации: `HashMap`, `LinkedHashMap`, `TreeMap`, `Hashtable`, `ConcurrentHashMap`, `WeakHashMap`.
- **`SortedSet`** / **`NavigableSet`** — расширения `Set` с поддержкой сортировки (`TreeSet`).
- **`SortedMap`** / **`NavigableMap`** — расширения `Map` с сортировкой по ключу (`TreeMap`).
- **`Iterable`** — корневой интерфейс иерархии, предоставляющий `iterator()`.


### 2. В чём разница между List, Set и Queue

- **`List`** — **упорядоченная** коллекция, сохраняет порядок вставки, **допускает дубликаты**, поддерживает доступ по индексу (`get(i)`, `set(i, e)`).
- **`Set`** — коллекция, **не допускающая дубликатов** (сравнение через `equals()`/`hashCode()` или `Comparator`). Порядок зависит от реализации (`HashSet` — не гарантирует, `LinkedHashSet` — порядок вставки, `TreeSet` — сортировка).
- **`Queue`** — коллекция для **упорядоченной обработки** элементов с определённой дисциплиной (FIFO, LIFO, приоритет). Обычно не поддерживает доступ по индексу, но предоставляет методы `offer`, `poll`, `peek`.


### 3. В чём разница между ArrayList и LinkedList

- **`ArrayList`** — основан на **динамическом массиве**. Быстрый доступ по индексу (O(1)), быстрая итерация. Вставка/удаление в середину — O(n) из-за сдвига элементов. При переполнении массив пересоздаётся с увеличением ёмкости (обычно в 1.5 раза).
- **`LinkedList`** — основан на **двусвязном списке**. Каждый элемент — узел со ссылками на предыдущий и следующий. Вставка/удаление по известной ссылке на узел — O(1), но доступ по индексу — O(n), так как нужно пройти по списку. Итерация медленнее из-за плохой локальности кэша.


### 4. Когда использовать ArrayList, а когда LinkedList

- **`ArrayList`** — в большинстве случаев. Особенно когда преобладают **чтение**, **итерация** и **доступ по индексу**, а вставки/удаления происходят в **конец** (амортизированное O(1)). Меньше накладных расходов на память (один массив вместо узлов со ссылками).
- **`LinkedList`** — когда преобладают **вставки и удаления в начало/середину** по известной позиции (например, реализация `Deque`/`Queue`), либо когда требуется именно двусторонняя очередь. В остальных случаях `ArrayList` почти всегда предпочтительнее, даже для очередей — `ArrayDeque` быстрее `LinkedList`.


### 5. Какова временная сложность операций в ArrayList

- `get(index)` — **O(1)**.
- `set(index, e)` — **O(1)**.
- `add(e)` в конец — **O(1)** амортизированное (O(n) при resize).
- `add(index, e)` в середину/начало — **O(n)** (сдвиг элементов).
- `remove(index)` / `remove(Object)` — **O(n)** (сдвиг элементов).
- `contains(Object)` — **O(n)**.
- `iterator()` обход — **O(n)**.
- `size()` — **O(1)**.


### 6. Какова временная сложность операций в LinkedList

- `get(index)` / `set(index, e)` — **O(n)** (проход по списку).
- `add(e)` в конец — **O(1)**.
- `addFirst(e)` / `addLast(e)` — **O(1)**.
- `add(index, e)` в середину — **O(n)** (поиск позиции) + O(1) на вставку.
- `removeFirst()` / `removeLast()` — **O(1)**.
- `remove(index)` — **O(n)** (поиск позиции).
- `contains(Object)` — **O(n)**.
- `iterator()` обход — **O(n)**.


### 7. Что такое Vector и чем он отличается от ArrayList

`Vector` — устаревшая (с Java 1.0) реализация `List` на основе динамического массива, **все методы которой синхронизированы** (`synchronized`). Отличия от `ArrayList`:
- Все операции потокобезопасны, но за счёт блокировки на каждом вызове — **медленнее** в однопоточной среде.
- При resize увеличивает ёмкость **вдвое** (ArrayList — в 1.5 раза).
- Поддерживает `Enumeration` (устаревший предшественник `Iterator`).

Современный подход: вместо `Vector` использовать `ArrayList` (для однопоточных сценариев) или `CopyOnWriteArrayList` / `Collections.synchronizedList()` (для многопоточных).


### 8. Что такое Stack

`Stack` — устаревший (Java 1.0) класс, наследующий `Vector`, реализующий структуру **LIFO (Last-In-First-Out)**. Основные методы: `push()`, `pop()`, `peek()`, `empty()`, `search()`. Все методы синхронизированы (наследуют синхронизацию `Vector`).

**Не рекомендуется** использовать `Stack` в новом коде. Современная альтернатива — **`ArrayDeque`** (реализует `Deque`, поддерживает `push`/`pop` и работает быстрее, без наследования синхронизации).


### 9. Что такое Queue и какие реализации существуют

`Queue` — интерфейс для коллекций, организованных по принципу очереди (обычно FIFO). Основные методы:
- `offer(e)` — добавить элемент (возвращает `false`, если не удалось).
- `poll()` — извлечь и удалить голову (возвращает `null`, если пусто).
- `peek()` — посмотреть голову без удаления (возвращает `null`, если пусто).
- `add(e)`, `remove()`, `element()` — варианты, бросающие исключения.

Реализации:
- **`LinkedList`** — реализует `Queue`/`Deque`.
- **`ArrayDeque`** — быстрая реализация `Deque` на массиве (рекомендуется для очередей и стеков).
- **`PriorityQueue`** — очередь с приоритетом (элементы извлекаются в порядке, определяемом `Comparator`/`Comparable`).
- **`BlockingQueue`** и её наследники (`ArrayBlockingQueue`, `LinkedBlockingQueue`, `PriorityBlockingQueue`, `SynchronousQueue`) — для многопоточных producer-consumer сценариев.


### 10. Что такое Deque

`Deque` (Double-Ended Queue) — интерфейс **двусторонней очереди**, позволяющий добавлять и извлекать элементы **с обоих концов**. Расширяет `Queue`. Основные методы: `addFirst`, `addLast`, `offerFirst`, `offerLast`, `pollFirst`, `pollLast`, `peekFirst`, `peekLast`, `push`, `pop`.

Реализации: **`ArrayDeque`** (рекомендуется как для очередей, так и для стеков) и `LinkedList`. `Deque` можно использовать как **FIFO-очередь**, **LIFO-стек** или **двустороннюю очередь**.


### 11. В чём разница между HashSet, LinkedHashSet и TreeSet

- **`HashSet`** — основан на `HashMap`. Не гарантирует **никакого порядка** итерации. Операции `add`/`contains`/`remove` — O(1) в среднем. Самый быстрый.
- **`LinkedHashSet`** — расширяет `HashSet`, дополнительно поддерживает **двусвязный список** для сохранения **порядка вставки**. Итерация идёт в порядке добавления. Производительность чуть ниже `HashSet`.
- **`TreeSet`** — основан на `TreeMap` (красно-чёрное дерево). Хранит элементы **в отсортированном порядке** (естественный порядок через `Comparable` или заданный `Comparator`). Операции — O(log n). Поддерживает `NavigableSet` (first, last, headSet, tailSet).


### 12. Как работает HashSet внутри

`HashSet` внутри использует **`HashMap`**, где элементы множества хранятся как **ключи**, а значением служит константа-заглушка (`PRESENT`, объект `Object`). При добавлении элемента `HashSet` вызывает `map.put(element, PRESENT)`: вычисляется хеш, определяется bucket, проверяется наличие дубликата через `equals()`. Если элемент уже есть, `put` не меняет map. Соответственно, все свойства `HashSet` (отсутствие порядка, O(1) в среднем, требования к `equals`/`hashCode`) наследуются от `HashMap`.


### 13. Что такое TreeSet и как он работает

`TreeSet` — реализация `Set` на основе **`TreeMap`**, который, в свою очередь, основан на **красно-чёрном дереве** (самобалансирующемся бинарном дереве поиска). Элементы хранятся **в отсортированном порядке**: по естественному порядку (`Comparable`) или по заданному при создании `Comparator`. Операции `add`/`contains`/`remove` — **O(log n)**. `TreeSet` реализует `NavigableSet`, предоставляя методы `first()`, `last()`, `headSet()`, `tailSet()`, `subSet()`, `floor()`, `ceiling()`, `higher()`, `lower()`. Дубликаты запрещены, а элементы должны быть сравнимы между собой, иначе `ClassCastException`.


### 14. Что такое Map и какие реализации существуют

`Map` — интерфейс для структуры «**ключ-значение**», где каждый ключ уникален. Не наследует `Collection`, но входит в Collection Framework. Основные методы: `put`, `get`, `remove`, `containsKey`, `containsValue`, `keySet`, `values`, `entrySet`.

Реализации:
- **`HashMap`** — на хеш-таблице, без порядка, O(1) в среднем.
- **`LinkedHashMap`** — `HashMap` + двусвязный список для сохранения порядка (вставки или доступа).
- **`TreeMap`** — красно-чёрное дерево, сортировка по ключу, O(log n).
- **`Hashtable`** — устаревшая синхронизированная реализация, запрещает `null`.
- **`ConcurrentHashMap`** — потокобезопасная и высокопроизводительная реализация.
- **`WeakHashMap`** — ключи хранятся через слабые ссылки.
- **`EnumMap`** — оптимизированная map для ключей-`enum`.


### 15. В чём разница между HashMap, LinkedHashMap и TreeMap

- **`HashMap`** — не гарантирует **порядок** ключей. O(1) в среднем. Допускает один `null`-ключ и `null`-значения.
- **`LinkedHashMap`** — сохраняет **порядок вставки** (по умолчанию) или **порядок доступа** (если `accessOrder = true`). Реализует LRU-кэш через переопределение `removeEldestEntry`. Производительность чуть ниже `HashMap`.
- **`TreeMap`** — хранит ключи **в отсортированном порядке** (по `Comparable` или `Comparator`). Операции O(log n). Не допускает `null`-ключи (если `Comparator` не поддерживает). Реализует `NavigableMap`.


### 16. Когда использовать TreeMap

`TreeMap` стоит использовать, когда:
- Нужен **отсортированный по ключу** порядок итерации.
- Требуются операции **диапазонного поиска** (`subMap`, `headMap`, `tailMap`), поиска ближайших ключей (`floorKey`, `ceilingKey`, `higherKey`, `lowerKey`), а также `firstKey`/`lastKey`.
- Нужна реализация `NavigableMap`/`SortedMap`.

Не стоит использовать `TreeMap`, если сортировка не нужна: `HashMap` быстрее (O(1) против O(log n)).


### 17. Что такое WeakHashMap

`WeakHashMap` — реализация `Map`, в которой **ключи хранятся через слабые ссылки** (`WeakReference`). Если на ключ больше нет **сильных ссылок** извне, сборщик мусора может удалить его, и соответствующая запись автоматически исчезает из map. Это полезно для **кэшей**, где нужно автоматически освобождать память, когда ключ больше не используется. Значения хранятся через обычные ссылки, поэтому важно, чтобы значение не ссылалось на ключ (иначе ключ не будет собран).


### 18. Что такое ConcurrentHashMap

`ConcurrentHashMap` — потокобезопасная реализация `Map`, предназначенная для **высокопроизводительной конкурентной работы**. В отличие от `Hashtable` (блокирует весь объект) и `Collections.synchronizedMap` (тоже блокирует весь объект), `ConcurrentHashMap` позволяет множеству потоков читать и писать **одновременно**. Не допускает `null`-ключи и `null`-значения. Предоставляет атомарные составные операции: `putIfAbsent`, `computeIfAbsent`, `compute`, `merge`, `replace`. Итераторы **слабо согласованы** (weakly consistent) и не бросают `ConcurrentModificationException`.


### 19. Как ConcurrentHashMap обеспечивает thread-safety

- **В Java 7** использовалась **сегментированная блокировка**: map делилась на 16 сегментов, каждый со своей блокировкой. Потоки, работающие с разными сегментами, не блокировали друг друга.
- **В Java 8+** сегменты убраны. Используются:
  - **CAS-операции** для вставки в пустой bucket.
  - **`synchronized` на первом узле bucket'а** (bin lock) при коллизиях — блокируется только одна корзина, а не вся map.
  - **`volatile`** для полей узлов и таблицы, обеспечивая видимость.
  - **Красно-чёрные деревья** для длинных цепочек (как в `HashMap`).
  - **`CounterCell`** (аналог `LongAdder`) для эффективного подсчёта `size`.

Это даёт гораздо более высокую степень параллелизма: операции записи в разные bucket'ы выполняются одновременно.


### 20. Что такое CopyOnWriteArrayList

`CopyOnWriteArrayList` — потокобезопасная реализация `List`, в которой **любая модификация** (`add`, `set`, `remove`) создаёт **новую копию** внутреннего массива. Читающие операции (`get`, `iterator`) работают с **неизменяемым снимком** и не блокируются. Итераторы **fail-safe**: они никогда не бросают `ConcurrentModificationException` и видят состояние на момент создания.

Подходит для сценариев с **преобладанием чтения** над записью (например, список слушателей/подписчиков, конфигурации). При частых записях крайне неэффективен из-за копирования всего массива.


### 21. Когда использовать synchronized collections

`Collections.synchronizedXxx()` (например, `Collections.synchronizedList`, `synchronizedMap`, `synchronizedSet`) стоит использовать, когда:
- Нужна **базовая потокобезопасность** для legacy-кода или простых случаев, где конкуренция низкая.
- Нет подходящей конкурентной реализации (например, для `List`, кроме `CopyOnWriteArrayList`).

**Не рекомендуется** для высоконагруженных систем: синхронизация блокирует **весь объект** на каждой операции, что убивает параллелизм. Предпочтительнее использовать `ConcurrentHashMap`, `CopyOnWriteArrayList`, `ConcurrentLinkedQueue` и другие классы из `java.util.concurrent`.

Важно: даже синхронизированная коллекция требует **внешней синхронизации при итерации** (`synchronized (list) { ... }`), иначе возможен `ConcurrentModificationException`.


### 22. Как получить synchronized коллекцию

С помощью статических методов класса **`Collections`**:
- `Collections.synchronizedList(List<T> list)`
- `Collections.synchronizedSet(Set<T> set)`
- `Collections.synchronizedMap(Map<K,V> map)`
- `Collections.synchronizedCollection(Collection<T> c)`
- `Collections.synchronizedSortedSet(...)`, `synchronizedSortedMap(...)`, `synchronizedNavigableSet(...)`, `synchronizedNavigableMap(...)`

Эти методы возвращают **обёртку**, все методы которой синхронизированы на внутреннем мьютексе (обычно `this` обёртки). Оригинальная коллекция остаётся доступной и изменяемой в обход синхронизации, что может привести к проблемам.


### 23. Что такое Collections.unmodifiableList()

`Collections.unmodifiableList(list)` возвращает **неизменяемое представление (unmodifiable view)** над исходным списком. Любая попытка модификации через это представление (`add`, `remove`, `set`) вызывает `UnsupportedOperationException`.

**Важно**: это **не копия**. Изменения, сделанные в исходном списке через другую ссылку, **будут видны** через неизменяемое представление. Поэтому `unmodifiableList` не обеспечивает истинной иммутабельности — он только запрещает модификацию через конкретную ссылку. Для настоящей иммутабельности используйте `List.copyOf()` (Java 10+) или `List.of()` (Java 9+), которые создают реальную копию.


### 24. В чём разница между Iterator и ListIterator

- **`Iterator`** — базовый итератор для всех коллекций. Методы: `hasNext()`, `next()`, `remove()`. Позволяет идти **только вперёд**.
- **`ListIterator`** — расширенный итератор **только для `List`**. Дополнительно:
  - Движение **в обоих направлениях**: `hasPrevious()`, `previous()`.
  - **Индексы**: `nextIndex()`, `previousIndex()`.
  - **Модификация**: `set(e)` (заменить последний возвращённый элемент) и `add(e)` (вставить перед следующим).
  
`ListIterator` можно получить через `list.listIterator()`.


### 25. Что такое fail-fast и fail-safe итераторы

- **Fail-fast (быстрый отказ)** — итераторы стандартных коллекций (`ArrayList`, `HashMap`, `HashSet` и др.). Они отслеживают **`modCount`** (счётчик модификаций) и при обнаружении изменения структуры коллекции **вне итератора** бросают `ConcurrentModificationException`. Это защита от неопределённого поведения, но **не гарантия** (поведение не детерминировано при конкурентных модификациях).
- **Fail-safe (безопасный)** — итераторы конкурентных коллекций (`ConcurrentHashMap`, `CopyOnWriteArrayList`, `ConcurrentLinkedQueue`). Они работают со **снимком** или **слабо согласованным** представлением данных и **не бросают** `ConcurrentModificationException`. Модификации во время итерации не влияют на текущий обход (могут быть видны или не видны, в зависимости от реализации).


### 26. Что такое ConcurrentModificationException

`ConcurrentModificationException` — unchecked-исключение, выбрасываемое **fail-fast итераторами**, когда обнаруживается, что коллекция была **структурно изменена** после создания итератора (кроме через сам итератор). «Структурное изменение» — добавление/удаление элементов (изменение `modCount`), но не замена значения существующего элемента.

Обычно возникает при попытке удалить элемент **напрямую через коллекцию**, пока идёт итерация:
```java
for (String s : list) {
    if (s.equals("x")) list.remove(s); // CME!
}
```


### 27. Как правильно удалять элементы во время итерации

Правильные способы:
1.  **Через `Iterator.remove()`** — единственный безопасный способ удаления при обходе fail-fast коллекций:
    ```java
    Iterator<String> it = list.iterator();
    while (it.hasNext()) {
        if (it.next().equals("x")) it.remove();
    }
    ```
2.  **Через `removeIf()`** (Java 8+) — самый лаконичный способ:
    ```java
    list.removeIf(s -> s.equals("x"));
    ```
3.  **Через `Collection.removeIf` / `Map`-специфичные методы** (`entrySet().removeIf(...)`).
4.  **Собрать элементы для удаления в отдельную коллекцию**, а затем удалить после цикла (если нельзя использовать `Iterator.remove()`).
5.  Для **конкурентных коллекций** (`ConcurrentHashMap`, `CopyOnWriteArrayList`) удаление напрямую во время итерации допустимо — fail-safe итераторы это выдерживают.


### 28. Что такое Comparable и Comparator

- **`Comparable<T>`** — интерфейс, определяющий **естественный порядок** объектов. Содержит один метод `int compareTo(T other)`. Класс, реализующий `Comparable`, может быть отсортирован «по умолчанию» (`Collections.sort(list)`, `TreeSet`, `TreeMap`). Возвращает отрицательное число, 0 или положительное число (меньше, равно, больше).
- **`Comparator<T>`** — функциональный интерфейс для определения **внешнего, настраиваемого порядка**. Метод `int compare(T a, T b)`. Позволяет сортировать объекты **по-разному**, не меняя сам класс, и комбинировать критерии (`.thenComparing(...)`).


### 29. В чём разница между Comparable и Comparator

| Аспект           | `Comparable`                                                        | `Comparator`                                              |
|------------------|---------------------------------------------------------------------|-----------------------------------------------------------|
| Пакет            | `java.lang`                                                         | `java.util`                                               |
| Метод            | `compareTo(T)`                                                      | `compare(T, T)`                                           |
| Где реализуется  | **Внутри** самого класса                                            | **Снаружи**, отдельный класс/лямбда                       |
| Порядок          | Естественный (один)                                                 | Настраиваемый (много разных)                              |
| Изменение класса | Требуется                                                           | Не требуется                                              |
| Использование    | `Collections.sort(list)`, `TreeSet` по умолчанию                    | `Collections.sort(list, cmp)`, `TreeSet(cmp)`             |
| Когда выбирать   | Если у объекта есть **очевидный единственный** естественный порядок | Если нужно **несколько** порядков или нельзя менять класс |


### 30. Какие операции поддерживает интерфейс Collection

`Collection<E>` определяет базовые операции:
- **Добавление**: `add(E)`, `addAll(Collection<? extends E>)`.
- **Удаление**: `remove(Object)`, `removeAll(Collection<?>)`, `retainAll(Collection<?>)`, `removeIf(Predicate<? super E>)` (Java 8+), `clear()`.
- **Проверка**: `contains(Object)`, `containsAll(Collection<?>)`, `isEmpty()`, `size()`.
- **Преобразование**: `toArray()`, `toArray(T[])`, `stream()` (Java 8+), `parallelStream()` (Java 8+).
- **Итерация**: `iterator()` (из `Iterable`), `forEach(Consumer<? super E>)` (Java 8+).
- **Сравнение**: `equals(Object)`, `hashCode()` (контракт определён, но реализации в подынтерфейсах разные).

`Collection` **не** предоставляет доступ по индексу — это прерогатива `List`. Также `Collection` не гарантирует порядка; порядок определяется конкретной реализацией.


### 31. Какие методы определяет интерфейс Map

`Map<K, V>` — не наследует `Collection`, но входит в Collection Framework. Полный перечень методов:

| Метод                                            | Назначение                                                                                          |
|--------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| `V put(K key, V value)`                          | Добавляет или заменяет пару. Возвращает **предыдущее** значение (или `null`).                       |
| `V get(Object key)`                              | Возвращает значение по ключу, либо `null`.                                                          |
| `V remove(Object key)`                           | Удаляет пару по ключу. Возвращает удалённое значение (или `null`).                                  |
| `boolean remove(K key, V value)`                 | Удаляет, **только если** значение равно заданному (Java 8+).                                        |
| `boolean containsKey(Object key)`                | Есть ли ключ?                                                                                       |
| `boolean containsValue(Object value)`            | Есть ли значение? (O(n) для HashMap)                                                                |
| `int size()`                                     | Количество пар.                                                                                     |
| `boolean isEmpty()`                              | Пустая ли map.                                                                                      |
| `void clear()`                                   | Удаляет все пары.                                                                                   |
| `Set<K> keySet()`                                | `Set` всех ключей.                                                                                  |
| `Collection<V> values()`                         | `Collection` всех значений (может содержать дубли).                                                 |
| `Set<Map.Entry<K,V>> entrySet()`                 | `Set` пар ключ-значение — **лучший способ** итерации.                                               |
| `V getOrDefault(Object key, V defaultValue)`     | Значение или дефолт (Java 8+).                                                                      |
| `void forEach(BiConsumer<? super K, ? super V>)` | Обход каждой пары (Java 8+).                                                                        |
| `void putAll(Map<? extends K, ? extends V>)`     | Копирует все пары из другой map.                                                                    |
| `V computeIfAbsent(K, Function)`                 | Вычисляет и вставляет, если ключ **отсутствует** (Java 8+).                                         |
| `V computeIfPresent(K, BiFunction)`              | Вычисляет и вставляет, если ключ **присутствует** (Java 8+).                                        |
| `V compute(K, BiFunction)`                       | Вычисляет заново всегда (Java 8+).                                                                  |
| `V merge(K, V, BiFunction)`                      | Объединяет: если ключ отсутствует — вставляет, если есть — применяет `remappingFunction` (Java 8+). |
| `V replace(K, V)`                                | Заменяет значение, если ключ есть (Java 8+).                                                        |
| `boolean replace(K, V oldValue, V newValue)`     | Заменяет, только если текущее значение равно `oldValue` (Java 8+).                                  |
| `void replaceAll(BiFunction)`                    | Пересчитывает все значения (Java 8+).                                                               |

Примеры Java 8+ методов в деле:

```java
Map<String, List<String>> grouped = new HashMap<>();

// computeIfAbsent — группировка без if
grouped.computeIfAbsent("paid", k -> new ArrayList<>()).add("order-1");
grouped.computeIfAbsent("paid", k -> new ArrayList<>()).add("order-2");
grouped.computeIfAbsent("new", k -> new ArrayList<>()).add("order-3");

// merge — счётчик
Map<String, Long> counts = new HashMap<>();
for (String s : List.of("a", "b", "a", "c", "a")) {
    counts.merge(s, 1L, Long::sum);
}
// {a=3, b=1, c=1}

// replace — атомарная замена
Map<String, String> versions = Map.of("lib", "1.0");
versions.put("lib", "2.0");          // обычная замена
Map<String, String> versions2 = new HashMap<>(Map.of("lib", "1.0"));
versions2.replace("lib", "1.0", "2.0");  // true, заменили
versions2.replace("lib", "3.0", "4.0");  // false, 3.0 не найдено
```


### 32. Чем entrySet лучше keySet и values

| Способ итерации               | Что возвращает          | Oпераций на пару                                   | Когда использовать       |
|-------------------------------|-------------------------|----------------------------------------------------|--------------------------|
| `map.keySet()` + `map.get(k)` | только ключи            | **2 хеш-вычисления** на пару (get = лишний lookup) | Нужен только ключ        |
| `map.values()`                | только значения         | 1 (прямой доступ)                                  | Нужны только значения    |
| `map.entrySet()`              | `Map.Entry<K,V>` — пара | **1** (напрямую)                                   | Нужны и ключ, и значение |

```java
Map<String, Integer> prices = Map.of("a", 10, "b", 20, "c", 30);

// ❌ Плохо: 2 hash-lookup на элемент
int sum1 = 0;
for (String k : prices.keySet()) {
    sum1 += prices.get(k);  // лишний get
}

// ✅ Хорошо: 1 lookup, прямой доступ к паре
int sum2 = 0;
for (Map.Entry<String, Integer> e : prices.entrySet()) {
    sum2 += e.getValue();
}

// ✅ Java 8+: forEach с BiConsumer
int sum3 = 0;
prices.forEach((k, v) -> { /* sum3 += v */ });
```

**Важно:** модификация через `entrySet` итератора (удаление пары через `iterator.remove()`) допустима; удаление через `map.remove()` во время итерации вызывает `ConcurrentModificationException` (fail-fast у HashMap).


### 33. В чём разница между putAll и put

|                        | `put(k, v)`               | `putAll(map)`                            |
|------------------------|---------------------------|------------------------------------------|
| Сколько пар            | 1                         | **все** из переданной map                |
| Поведение при коллизии | Заменяет значение         | Заменяет **каждое** совпадающее значение |
| Возвращает             | `V` (предыдущее значение) | `void`                                   |

```java
Map<String, Integer> base = new HashMap<>();
base.put("a", 1);
base.put("b", 2);

Map<String, Integer> extra = new HashMap<>();
extra.put("b", 20);   // перезапишет "b"
extra.put("c", 30);

base.putAll(extra);
// base = {a=1, b=20, c=30}  — "b" заменён, "c" добавлен
```

Применение: инициализация map из конфигурации, обновление словаря, «slapping» одного словаря поверх другого.


### 34. В чём разница между computeIfAbsent, compute и merge

| Метод                    | Когда вызывается функция                                               | Аргументы функции                               | Типичный сценарий                                                    |
|--------------------------|------------------------------------------------------------------------|-------------------------------------------------|----------------------------------------------------------------------|
| `computeIfAbsent(k, f)`  | Ключ **отсутствует**                                                   | `f(key)` → значение                             | Группировка: `map.computeIfAbsent(k, x -> new ArrayList<>()).add(v)` |
| `computeIfPresent(k, f)` | Ключ **присутствует**                                                  | `f(key, oldVal)` → новое                        | Увеличение счётчика, если ключ есть                                  |
| `compute(k, f)`          | **Всегда** (и если ключ есть, и если нет)                              | `f(key, oldVal)` → новое (или `null` — удалить) | Универсальная пересборка значения                                    |
| `merge(k, v, f)`         | Ключ **отсутствует** → вставить `v`; **присутствует** → `f(oldVal, v)` | `f(oldVal, v)` → новое                          | Счётчики: `map.merge(k, 1L, Long::sum)`                              |

```java
Map<String, List<String>> groups = new HashMap<>();

// computeIfAbsent: добавляем в список, создавая его при первом обращении
groups.computeIfAbsent("cat", k -> new ArrayList<>()).add("milk");
groups.computeIfAbsent("cat", k -> new ArrayList<>()).add("fish");

// merge: считаем частоту слов
Map<String, Long> freq = new HashMap<>();
for (String word : List.of("java", "spring", "java")) {
    freq.merge(word, 1L, Long::sum);
}
// freq = {java=2, spring=1}

// compute: условная замена/удаление
Map<String, String> cfg = new HashMap<>(Map.of("debug", "true"));
cfg.compute("debug", (k, v) -> "true".equals(v) ? null : v);
// cfg = {} — значение null → запись удалена
```


### 35. Можно ли хранить null ключ и null значение в HashMap

- **`null` ключ** — **можно**, в `HashMap` ровно один. Хранится в bucket 0 (индекс `0`). `Hashtable` и `ConcurrentHashMap` **не допускают** `null`-ключи (бросают `NullPointerException`).
- **`null` значение** — **можно**, сколько угодно. `Hashtable` и `ConcurrentHashMap` **не допускают** `null`-значения.

```java
Map<String, String> m = new HashMap<>();
m.put(null, "null-key-value");  // OK
m.put("a", null);               // OK
m.put("b", null);               // OK
System.out.println(m.get(null)); // "null-key-value"
System.out.println(m.get("a"));  // null

// ConcurrentHashMap — NPE
Map<String, String> chm = new ConcurrentHashMap<>();
chm.put(null, "x");   // NullPointerException
chm.put("x", null);   // NullPointerException
```

**Почему это важно:** если ваш код может передать `null`-ключ, а в будущем переключится с `HashMap` на `ConcurrentHashMap`, — получится скрытый `NPE`. Рекомендуется избегать `null`-ключей и `null`-значений вообще, либо использовать `getOrDefault` / `Optional`.


### 36. Что такое Map.of() и чем она отличается от new HashMap<>()

`Map.of(...)` (Java 9+) — статический фабрик для создания **неизменяемых** map.

|                       | `Map.of()`                                                          | `new HashMap<>()`                           |
|-----------------------|---------------------------------------------------------------------|---------------------------------------------|
| Изменяемость          | **Неизменяемая** (`put`/`remove` → `UnsupportedOperationException`) | Изменяемая                                  |
| `null`-ключи/значения | **Запрещены** (`NullPointerException`)                              | Разрешены (один null-ключ, null-значения)   |
| Максимум пар          | **10** (далее `Map.ofEntries`)                                      | Неограниченно                               |
| Итерационный порядок  | Не гарантирован (внутренний порядок может меняться между версиями)  | Не гарантирован (но стабильнее на практике) |
| Производительность    | Нет resize, нет load factor — быстрее на малых размерах             | Возможный resize при росте                  |

```java
// OK — до 10 пар
Map<String, Integer> m1 = Map.of("a", 1, "b", 2, "c", 3);

// Более 10 пар — через Map.entry
Map<String, Integer> m2 = Map.ofEntries(
    Map.entry("a", 1),
    Map.entry("b", 2),
    Map.entry("c", 3)
    // ... до сколь угодно пар
);

// NPE на null
Map<String, String> m3 = Map.of("key", null);  // NullPointerException

// UnsupportedOperationException при попытке изменить
Map<String, Integer> m4 = Map.of("a", 1);
m4.put("b", 2);  // UnsupportedOperationException
```

**Когда использовать `Map.of`:** константные конфигурации, тестовые фикстуры, factory-методы для DTO.
**Когда использовать `HashMap`:** если map нужно будет мутировать, если возможны `null`, если размер > 10.


### 37. Как удалить элемент из Map во время итерации

**Правильно** — через `iterator.remove()` (у `Map.Entry`):

```java
Map<String, Integer> m = new HashMap<>(Map.of("a", 1, "b", 2, "c", 3));

// ✅ Правильно: iterator.remove()
Iterator<Map.Entry<String, Integer>> it = m.entrySet().iterator();
while (it.hasNext()) {
    Map.Entry<String, Integer> e = it.next();
    if (e.getValue() < 2) {
        it.remove();  // безопасно
    }
}
// m = {b=2, c=3}

// ✅ Java 8+: removeIf — самый простой способ
m.entrySet().removeIf(e -> e.getValue() < 2);
```

**Неправильно** — `map.remove(key)` во время итерации:

```java
Map<String, Integer> m = new HashMap<>(Map.of("a", 1, "b", 2, "c", 3));

// ❌ ConcurrentModificationException
for (String key : m.keySet()) {
    if (m.get(key) < 2) {
        m.remove(key);  // CME на следующей итерации!
    }
}
```

Причина: у `HashMap` fail-fast итератор — он отслеживает `modCount`. Любое изменение структуры map (не через `iterator.remove()`) между `next()` вызовами вызывает исключение.


### 38. В чём разница между remove(key) и remove(key, value)

|             | `remove(Object key)`                                      | `remove(K key, V value)` (Java 8+)       |
|-------------|-----------------------------------------------------------|------------------------------------------|
| Удаляет     | **Всегда** если ключ есть                                 | Только если значение **равно** заданному |
| Возвращает  | `V` — удалённое значение или `null`                       | `boolean` — удалось ли удалить           |
| Атомарность | Нет (в многопоточном коде может удалить «чужое» значение) | **Атомарно** (CAS в ConcurrentHashMap)   |

```java
Map<String, Integer> m = new HashMap<>(Map.of("a", 10, "b", 20));

// remove(key): удаляет независимо от значения
m.remove("a");        // true-подобное: удалили, вернули 10
m.get("a");           // null

// remove(key, value): удаляет только при совпадении значения
m.remove("b", 99);    // false — 99 ≠ 20, не удалили
m.get("b");           // 20 — всё на месте
m.remove("b", 20);    // true — 20 == 20, удалили
m.get("b");           // null
```

**Ключевое применение:** в многопоточном коде `remove(key, value)` безопаснее, чем `get` + `remove`, потому что исключает race condition, когда между `get` и `remove` другой поток изменил значение.



