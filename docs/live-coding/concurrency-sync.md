# Многопоточность и синхронизация

> Что проверяют: wait/notify против ReentrantLock/Condition, volatile/atomic, InterruptedException-этикет, дедлоки, выбор примитива под задачу. Самый «.middle» раздел: задачи дают почти всегда.

<a id="r16-t1"></a>
**1. [Потоки] Два потока печатают чёт/нечет по очереди (wait/notify)**
```java
class OddEvenPrinter {
    private final Object monitor = new Object();
    private volatile boolean oddTurn = true;
    private final int limit;
    OddEvenPrinter(int limit) { this.limit = limit; }

    public void printOdd() throws InterruptedException {
        for (int i = 1; i <= limit; i += 2) {
            synchronized (monitor) {
                while (!oddTurn) monitor.wait();     // while — защита от ложных пробуждений
                System.out.println("odd: " + i);
                oddTurn = false;
                monitor.notifyAll();
            }
        }
    }
    public void printEven() throws InterruptedException {
        for (int i = 2; i <= limit; i += 2) {
            synchronized (monitor) {
                while (oddTurn) monitor.wait();
                System.out.println("even: " + i);
                oddTurn = true;
                monitor.notifyAll();
            }
        }
    }
}
// запуск:
OddEvenPrinter p = new OddEvenPrinter(10);
new Thread(() -> runUnchecked(p::printOdd)).start();
new Thread(() -> runUnchecked(p::printEven)).start();
```
Три вещи, которые спрашивают: wait в while; wait/notify только внутри synchronized (иначе IllegalMonitorStateException); notifyAll против notify (notify может разбудить «не того»).

<a id="r16-t2"></a>
**2. [Потоки] То же через ReentrantLock + Condition**
```java
class OddEvenLock {
    private final ReentrantLock lock = new ReentrantLock();
    private final Condition oddTurn  = lock.newCondition();
    private final Condition evenTurn = lock.newCondition();
    private boolean isOdd = true;

    void print(int from, int step, int limit, boolean odd) throws InterruptedException {
        for (int i = from; i <= limit; i += step) {
            lock.lock();
            try {
                while (isOdd != odd)
                    (odd ? oddTurn : evenTurn).await();
                System.out.println(i);
                isOdd = !isOdd;
                (odd ? evenTurn : oddTurn).signal();     // будим конкретного «соседа»
            } finally {
                lock.unlock();
            }
        }
    }
}
```
Преимущества против wait/notify: отдельные условия (не будим лишних), lock с таймаутом/прерыванием, честность (fairness). unlock — строго в finally.

<a id="r16-t3"></a>
**3. [Потоки] Три потока печатают A/B/C строго по кругу N раз**
```java
class ABCPrinter {
    private final ReentrantLock lock = new ReentrantLock();
    private final Condition[] ready = {lock.newCondition(), lock.newCondition(), lock.newCondition()};
    private int turn = 0;   // чей ход

    void print(int id, int times) throws InterruptedException {   // id = 0,1,2
        for (int k = 0; k < times; k++) {
            lock.lock();
            try {
                while (turn != id) ready[id].await();
                System.out.print((char) ('A' + id));
                turn = (id + 1) % 3;
                ready[turn].signal();
            } finally {
                lock.unlock();
            }
        }
    }
}
```
Обобщение чёт/нечет на N участников. Фоллоу-ап: semaphore-вариант — три Semaphore(1,0,0), после печати release следующего.

<a id="r16-t4"></a>
**4. [Потоки|hard] Producer/Consumer на wait/notify: ограниченный буфер**
```java
class BoundedBuffer<T> {
    private final Object[] buf;
    private int take, put, count;
    BoundedBuffer(int cap) { buf = new Object[cap]; }

    public synchronized void put(T v) throws InterruptedException {
        while (count == buf.length) wait();        // while, не if: после пробуждения могли заполнить
        buf[put] = v;
        if (++put == buf.length) put = 0;
        count++;
        notifyAll();
    }
    @SuppressWarnings("unchecked")
    public synchronized T take() throws InterruptedException {
        while (count == 0) wait();
        T v = (T) buf[take];
        buf[take] = null;                          // не держим ссылки
        if (++take == buf.length) take = 0;
        count--;
        notifyAll();
        return v;
    }
}
```
Каноничное решение из «Java Concurrency in Practice». Спросить: почему notifyAll (двустороннее ожидание — notify может разбудить однотипного); что будет с if вместо while (потерянные пробуждения/переполнение).

<a id="r16-t5"></a>
**5. [Потоки] Producer/Consumer на ArrayBlockingQueue**
```java
BlockingQueue<Integer> q = new ArrayBlockingQueue<>(100);

Runnable producer = () -> {
    try {
        for (int i = 0; i < 1_000; i++) q.put(i);   // блокируется при заполнении
        q.put(-1);                                   // poison pill — сигнал конца
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    }
};
Runnable consumer = () -> {
    try {
        while (true) {
            int v = q.take();                        // блокируется при пустой очереди
            if (v == -1) { q.put(-1); break; }       // пропустить сигнал дальше — для остальных потребителей
            process(v);
        }
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    }
};
```
put/take — блокирующие, offer/poll с таймаутом — неблокирующие. Poison pill — идиома завершения; фоллоу-ап: несколько продюсеров — счётчик завершившихся.

<a id="r16-t6"></a>
**6. [Потоки] Потокобезопасный счётчик: четыре способа и их цена**
```java
// 1. synchronized — прост, но сериализует все потоки
class Counter1 { private long v; public synchronized void inc() { v++; } public synchronized long get() { return v; } }
// 2. AtomicLong — CAS-цикл, без блокировки: лучше при низкой конкуренции
class Counter2 { private final AtomicLong v = new AtomicLong(); public void inc() { v.incrementAndGet(); } public long get() { return v.get(); } }
// 3. LongAdder — суммирование по ячейкам: побеждает при ОЧЕНЬ высокой конкуренции
class Counter3 { private final LongAdder v = new LongAdder(); public void inc() { v.increment(); } public long get() { return v.sum(); } }
// 4. единственный поток-писатель + volatile — нет конкуренции на запись
class Counter4 { private volatile long v; public void inc() { v++; } public long get() { return v; } }   // ++ НЕ атомарен: годится ТОЛЬКО если пишет один поток
```
Объяснить: `v++` = чтение+инкремент+запись (check-then-act); volatile даёт видимость и happens-before, но не атомарность составных операций.

<a id="r16-t7"></a>
**7. [Потоки] Написать дедлок и починить**
```java
final Object lock1 = new Object(), lock2 = new Object();

// ДЕДЛОК: каждый держит свой лок и ждёт чужой
new Thread(() -> {
    synchronized (lock1) { sleep(50); synchronized (lock2) { work(); } }
}).start();
new Thread(() -> {
    synchronized (lock2) { sleep(50); synchronized (lock1) { work(); } }
}).start();

// ФИКС 1 — единый глобальный порядок захвата (по id/по hash):
Object first = System.identityHashCode(lock1) <= System.identityHashCode(lock2) ? lock1 : lock2;

// ФИКС 2 — tryLock с таймаутом и откатом:
ReentrantLock l1 = new ReentrantLock(), l2 = new ReentrantLock();
if (l1.tryLock(1, TimeUnit.SECONDS)) {
    try {
        if (l2.tryLock(1, TimeUnit.SECONDS)) {
            try { work(); } finally { l2.unlock(); }
        }
    } finally { l1.unlock(); }
}
```
Диагностика: jstack / Thread.getStackTrace() — показывает «Found one Java-level deadlock». Проговорить: дедлок возможен только при вложенных захватах; минимальные критические секции снижают риск, но не устраняют его.

<a id="r16-t8"></a>
**8. [Потоки] Ленивый синглтон: три безопасных способа**
```java
// 1. enum — кратко, защищено от рефлексии и сериализации (Effective Java)
enum Singleton1 { INSTANCE; public void doWork() { /* ... */ } }

// 2. holder — ленивость бесплатно: класс Holder инициализируется при первом обращении
class Singleton2 {
    private Singleton2() { }
    private static class Holder { static final Singleton2 INSTANCE = new Singleton2(); }
    public static Singleton2 instance() { return Holder.INSTANCE; }
}

// 3. double-checked locking — работает ТОЛЬКО с volatile
class Singleton3 {
    private static volatile Singleton3 instance;      // volatile запрещает переупорядочение создания
    private Singleton3() { }
    public static Singleton3 instance() {
        if (instance == null)                          // быстрый путь без локов
            synchronized (Singleton3.class) {
                if (instance == null) instance = new Singleton3();
            }
        return instance;
    }
}
```
Почему DCL без volatile ломается: `new` — три шага (память, инициализация, присваивание ссылки), JMM может переупорядочить — другой поток увидит ссылку на неинициализированный объект.

<a id="r16-t9"></a>
**9. [Дизайн] Ограничитель частоты на Semaphore**
```java
class RateLimiter {
    private final Semaphore permits = new Semaphore(0);
    private final ScheduledExecutorService refiller = Executors.newSingleThreadScheduledExecutor();

    RateLimiter(int qps) {
        refiller.scheduleAtFixedRate(() -> {
            permits.drainPermits();        // сброс остатка: bucket не копится бесконечно
            permits.release(qps);          // выдать новую порцию
        }, 0, 1, TimeUnit.SECONDS);
    }
    public boolean allow() { return permits.tryAcquire(); }   // без ожидания: взял — прошёл
    public void shutdown() { refiller.shutdownNow(); }        // обязательно остановить поток-пополнитель!
}
```
Упрощённый token bucket. tryAcquire — неблокирующий отказ; producer'ы токенов нельзя забывать останавливать — утечка потока. Промышленный вариант: Guava RateLimiter, Resilience4j RateLimiter.

<a id="r16-t10"></a>
**10. [Потоки] Как правильно остановить фоновый поток**
```java
class Worker implements Runnable {
    private volatile boolean running = true;    // volatile — флаг виден из другого потока

    public void stop() { running = false; }

    @Override
    public void run() {
        while (running && !Thread.currentThread().isInterrupted()) {
            try {
                doWork();
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();   // ВОССТАНОВИТЬ флаг — иначе «проглотим» прерывание
                break;
            }
        }
    }
}
```
Thread.stop() — deprecated: снимает мониторы в произвольный момент, объекты остаются в неконсистентном состоянии. Правильно: флаг + interrupt(); interrupt() сбрасывает sleep/join/wait через InterruptedException. Проговорить идиому `interrupt() → catch → restore → break`.

<a id="r16-t11"></a>
**11. [Потоки] Напечатать числа 1..100 десятью потоками**
```java
AtomicInteger counter = new AtomicInteger(1);
ExecutorService pool = Executors.newFixedThreadPool(10);
for (int t = 0; t < 10; t++) {
    pool.submit(() -> {
        int v;
        while ((v = counter.getAndIncrement()) <= 100)   // атомарная выдача следующего числа
            System.out.println(Thread.currentThread().getName() + ": " + v);
    });
}
pool.shutdown();
// try { pool.awaitTermination(1, TimeUnit.MINUTES); } catch (InterruptedException e) { ... }
```
Каждое число ровно один раз, порядок недетерминирован. Если требуют строгий порядок — это задача чёт/нечет, обобщённая на 10 потоков (turn 0..9 + условия).

<a id="r16-t12"></a>
**12. [Дизайн] Кэш с ReadWriteLock**
```java
class SharedCache<K, V> {
    private final Map<K, V> data = new HashMap<>();      // НЕ потокобезопасная — защищаем локами
    private final ReadWriteLock lock = new ReentrantReadWriteLock();

    public V get(K key) {
        lock.readLock().lock();                          // читателей — много одновременно
        try { return data.get(key); }
        finally { lock.readLock().unlock(); }
    }
    public void put(K key, V value) {
        lock.writeLock().lock();                         // писатель — один, читатели ждут
        try { data.put(key, value); }
        finally { lock.writeLock().unlock(); }
    }
}
```
Когда выигрыш: читатели держат лок долго и их много; обновление по промаху — отпустить readLock и перезайти с writeLock (апгрейд лока запрещён — дедлок). Фоллоу-ап: ConcurrentHashMap без лаков.

<a id="r16-t13"></a>
**13. [Потоки] CountDownLatch и CyclicBarrier: скоординировать этапы**
```java
// CountDownLatch — ОДНОРАЗОВЫЙ: главный ждёт N воркеров
CountDownLatch ready = new CountDownLatch(3);
for (int i = 0; i < 3; i++)
    new Thread(() -> { doWork(); ready.countDown(); }).start();
ready.await();                                  // main продолжит, когда все доложатся
System.out.println("все готовы");

// CyclicBarrier — ПЕРЕИСПОЛЬЗУЕМЫЙ: N потоков встречаются в точке
CyclicBarrier barrier = new CyclicBarrier(3, () -> System.out.println("=== раунд завершён ==="));
for (int i = 0; i < 3; i++)
    new Thread(() -> {
        for (int round = 0; round < 5; round++) {
            doWork();
            try { barrier.await(); }            // ждём остальных — потом новый раунд
            catch (Exception e) { return; }
        }
    }).start();
```
Отличие — любимый вопрос: latch — «ждут все у одной двери, дверь одноразовая»; barrier — «команда бежит этапами, стартует заново». Phaser — если состав участников меняется.

<a id="r16-t14"></a>
**14. [Баг-хантинг] ThreadLocal-контекст: утечка в пуле потоков**
```java
class RequestContext {
    private static final ThreadLocal<String> USER = new ThreadLocal<>();
    public static void set(String user) { USER.set(user); }
    public static String get()           { return USER.get(); }
    public static void clear()           { USER.remove(); }   // КЛЮЧЕВОЕ
}

// НЕПРАВИЛЬНО: Tomcat/Executors переиспользуют поток между запросами
RequestContext.set("alice");
handleRequest();          // исключение → ThreadLocal остался: следующий запрос увидит «alice»

// ПРАВИЛЬНО:
try {
    RequestContext.set(user);
    handleRequest();
} finally {
    RequestContext.clear();   // очистка обязательна в пулах
}
```
Механика: ThreadLocalMap потока держит ссылку на значение, пока поток жив; в пуле потоков потоки живут вечно → утечка памяти + «чужие» данные. Фоллоу-ап: ThreadLocal со значениями-ClassLoader — классические утечки на перегрузке приложения.

---
<a id="razdel-17"></a>
