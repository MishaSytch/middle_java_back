# Production Debugging

### 1. Что такое JFR (Java Flight Recorder) и как его использовать в production

**JFR (Java Flight Recorder)** — **встроенный** в JVM (Java 7+, значительно улучшен в Java 11+) инструмент **записи** (recording) **событий** **JVM** и **приложения** с **минимальным** **overhead** (**1–2%**). Записывает **CPU**, **GC**, **memory allocation**, **lock contention**, **I/O**, **method execution** и **кастомные** события.

**Зачем нужен**:
- **Production** **debugging** **без** **остановки** **приложения** (overhead ~1–2%).
- **Записывает** **всё** **в** **один** **файл** (**`.jfr`**) → **офлайн-анализ** в **JDK Mission Control** (JDK 11+) или **JFR** **viewer**.
- **Не** **требует** **перекомпиляции** (в отличие от **профайлеров**).
- **Java 11+**: **бесплатно** (в **JDK**).

**Как включить**:

```bash
# 1. Запуск с JFR (записывать 30 секунд в файл)
java -XX:StartFlightRecording=duration=30s,filename=recording.jfr -jar app.jar

# 2. Запуск с непрерывной записью (maxsize 100M, maxage 5m)
java -XX:StartFlightRecording=maxsize=100M,maxage=5m,filename=recording.jfr -jar app.jar

# 3. Вручную (на работающем процессе)
jcmd <pid> JFR.start duration=60s filename=recording.jfr
jcmd <pid> JFR.dump filename=recording.jfr all-user-data=false
```

**Ключевые события**:
- **`jdk.ExecutionSample`** — **CPU** **probing** (какой **метод** **выполняется**).
- **`jdk.GCHeapSummary`** — **GC** **before/after** (размер **heap** **до/после**).
- **`jdk.ObjectAllocationInNewTLAB`** — **allocation** (какой **объект** **создан**).
- **`jdk.JavaMonitorEnter`** — **lock contention** (какой **монитор** **блокирует**).
- **`jdk.SocketRead`/`jdk.SocketWrite`** — **I/O** (сетевые **вызовы**).
- **`jdk.ThreadPark`** — **wait** (поток **ждёт**).
- **`jdk.JavaMonitorDeadlock`** — **deadlock**.

**Кастомные события**:
```java
// 1. Анонимное событие (один раз)
JFR.event("com.myapp.Event")
    .withName("processOrder")
    .withAttribute("orderId", 123)
    .commit();

// 2. Событие с временем (start/stop)
JFR.Event event = JFR.event("com.myapp.ProcessOrder");
event.begin();
try {
    orderService.process(order);
} finally {
    event.end();
}

// 3. С custom events (Java 11+)
JFR.beginEvent()
    .withName("com.myapp.SlowQuery")
    .withAttribute("query", query)
    .commit();
```

**Анализ**:
- **JDK Mission Control** (JDK 11+) — **UI** для **анализа** `.jfr`.
- **JFR** **CLI**: `jfr print recording.jfr` (text dump).
- **Grafana** + **JFR** **exporter** (опционально).

**Типовой workflow**:
1. **Обнаружение** **проблемы** (metrics: CPU > 80%, GC pause > 500 ms).
2. **Запуск** **JFR** (`jcmd <pid> JFR.start duration=60s`).
3. **Сбор** **recording** (`.jfr`).
4. **Анализ** в **JDK Mission Control**:
   - **CPU** **flame graph** (какие **методы** **глубже**).
   - **GC** **timeline** (какие **GC** **чаще**).
   - **Allocation** (какие **объекты** **создаются** **чаще**).
   - **Lock contention** (какие **monitors** **блокируют**).
5. **Оптимизация** + **повторная** **проверка**.

**Вывод**: JFR — **стандарт** для **production** **debugging** в Java. **Overhead** ~1–2%, **бесплатно** (JDK 11+), **записывает** **CPU**/**GC**/**allocation**/**lock**/**I/O**. **Анализ** в **JDK Mission Control**.


### 2. Что такое async-profiler и как использовать CPU/allocation/lock profiling

**async-profiler** — **высокоточный** **профайлер** для **JVM** (Linux, macOS, Windows) с **минимальным** **overhead**. Использует **eBPF** (Linux) или **perf_events** для **sampling** **CPU** **stacks**. Генерирует **flame graphs** (HTML) и **collapsed stacks** (text).

**Отличие от JFR**:
| | JFR | async-profiler |
|---|---|---|
| **Overhead** | ~1–2% | ~1–3% |
| **CPU profiling** | ✅ | ✅ (точнее, eBPF) |
| **Allocation** | ✅ | ✅ (on-the-fly) |
| **Lock** | ✅ | ✅ |
| **Flame graph** | ❌ (Mission Control) | ✅ (HTML) |
| **Continuous** | ✅ | ❌ (one-shot) |
| **Kustom events** | ✅ | ❌ |
| **Java version** | JDK 7+ | JDK 8+ |

**Установка**:
```bash
# Linux: скачать из GitHub
wget https://github.com/async-profiler/async-profiler/releases/latest/download/async-profiler.tar.gz
tar xzf async-profiler.tar.gz
# или via jcmd (Java 14+): jcmd <pid> JFR.start ...
```

**Использование**:

```bash
# 1. CPU profiling (30 секунд, flame graph HTML)
./async-profiler/profile -d 30 -f cpu.html <pid>

# 2. Allocation profiling (on-the-fly, 30 секунд)
./async-profiler/profile -e alloc -d 30 -f alloc.html <pid>

# 3. Lock contention (30 секунд)
./async-profiler/profile -e lock -d 30 -f lock.html <pid>

# 4. Wall-clock (время, включая wait)
./async-profiler/profile -e wall -d 30 -f wall.html <pid>

# 5. Через jcmd (Java 14+)
jcmd <pid> JFR.start duration=30s filename=cpu.jfr

# 6. NPM (Node.js)
./async-profiler/profile -d 30 -f cpu.html <node-pid>
```

**Flame graph**:
- **Ширина** полосы = **доля** CPU в этом **методе**.
- **Высота** = **глубина** вызова (стек).
- **Красный** = **hot** (много CPU), **зелёный** = **холодный**.
- **Клик** на **полосу** → **фильтр** (показать только **этот** метод и **дети**).

**Типовой workflow**:
1. **Обнаружение** **высокого** CPU (metrics: CPU > 80%).
2. **Запуск** **async-profiler** (`./async-profiler/profile -d 30 -f cpu.html <pid>`).
3. **Открыть** `cpu.html` в **браузере**.
4. **Найти** **самые** **широкие** **полосы** (hot methods).
5. **Оптимизация** + **повторная** **проверка**.

**Важные нюансы**:
- **`-e alloc`** — **on-the-fly** allocation (не **heap dump**).
- **`-e wall`** — **wall-clock** (включает **wait**, **I/O**, **GC**).
- **`-t`** — **thread** **view** (разделить **по** **потокам**).
- **`-g`** — **GC** **events** (включить **GC** в **flame graph**).
- **`--latency`** — **latency** **histogram** (распределение **задержек**).

**Вывод**: async-profiler — **лучший** **CPU** **профайлер** для **JVM**. **Flame graph** (HTML) — **интуитивно** **понятный** **формат**. **`-e alloc`**/**`-e lock`**/**`-e wall`** — **дополнительные** **режимы**. **JFR** — для **continuous** **recording**, **async-profiler** — для **one-shot** **profiling**.


### 3. Что такое Arthas и как им диагностировать production Java-приложение

**Arthas** — **production** **diagnostic** **tool** для **Java** (Alibaba). **Прикрепляется** к **работающему** **процессу** (без **остановки**) и **позволяет**:
- **Просматривать** **классы** (декомпиляция).
- **Просматривать** **методы** (вход/выход, аргументы, результат).
- **Вызывать** **методы** (invoke).
- **Профилировать** (flame graph).
- **Просматривать** **потoki** (thread dump, deadlock).
- **Просматривать** **JVM** (memory, GC, classloader).

**Установка**:
```bash
# 1. Скачать
curl -O https://arthas.aliyun.com/install.sh
bash install.sh

# 2. Запустить (прикрепить к процессу)
./as.sh <pid>

# 3. Или via Docker
docker run -it --network host --volume /proc:/host/proc arthas/arthas
```

**Ключевые команды**:

```bash
# 1. Dashboard (CPU, memory, GC)
dashboard

# 2. Thread dump (показать потоки)
thread
thread -n 3  # top 3 по CPU
thread -b     # найти deadlock

# 3. Декомпиляция класса
jad com.myapp.OrderService

# 4. Просмотр метода (вход/выход, аргументы, результат)
watch com.myapp.OrderService processOrder '{params, returnObj, throwExp}' -x 2

# 5. Trace (время внутри метода)
trace com.myapp.OrderService processOrder

# 6. Stack (кто вызывает метод)
stack com.myapp.OrderService processOrder

# 7. Invoke (вызвать метод)
invoke com.myapp.OrderService findById 123

# 8. Memory (heap, non-heap)
memory

# 9. GC (статистика GC)
gc

# 10. Classloader (статистика, dump)
classloader
classloader -t  # tree

# 11. Profiler (flame graph)
profiler start
profiler stop --format html
profiler stop --file cpu.html

# 12. JVM info
jvm

# 13. Sysprops, sysenv
sysprop
sysenv

# 14. Log (просмотр логов в реальном времени)
log
```

**Типовой workflow**:
1. **Прикрепить** к процессу: `./as.sh <pid>`.
2. **Dashboard**: `dashboard` (CPU, memory, GC).
3. **Найти** **hot** **методы**: `thread -n 3` (top 3 по CPU).
4. **Просмотреть** **метод**: `watch com.myapp.OrderService processOrder '{params, returnObj}' -x 2`.
5. **Trace** **внутри** **метода**: `trace com.myapp.OrderService processOrder`.
6. **Профилировать**: `profiler start` → `profiler stop --format html`.
7. **Декомпилировать** **класс**: `jad com.myapp.OrderService`.

**Вывод**: Arthas — **универсальный** **production** **diagnostic** **tool**. **Не** **требует** **остановки** **приложения**. **Flame graph** (через **`profiler`**), **watch**/**`trace`**/**`stack`** для **методов**, **`thread`** для **deadlock**/**CPU**. **Комплементарен** **JFR**/**async-profiler** (JFR — **continuous**, Arthas — **interactive**).


### 4. Как анализировать heap dump: Eclipse MAT, OQL, Dominator Tree, Path to GC Roots

**Heap dump** — **снимок** **кучи** (Q60–61). **Анализ** **heap dump** — **ключевой** **инструмент** для **поиска** **утечек** **памяти**.

**Eclipse MAT (Memory Analyzer Tool)** — **стандарт** **офлайн-анализа** **heap dump**. **Основные** **отчёты**:

1. **Leak Suspects** — **автоматический** **отчёт** о **подозрительных** **утечках** (топ-10 **объектов**, **занимающих** **много** **памяти**).
2. **Dominator Tree** — **дерево** **объектов** по **retained heap** (какой **объект** **удерживает** **сколько** **памяти**).
3. **Histogram** — **список** **классов** по **count**/**шallow**/**retained** heap.
4. **Path to GC Roots** — **цепочка** **ссылок** от **объекта** до **GC root** (почему **объект** **не** **собран**).
5. **OQL** — **запросы** к **объектам** (SQL-подобный **синтаксис**).

**Dominator Tree**:
- **Каждый** **узел** — **объект**, **retained heap** = **память**, **которую** **объект** **удерживает** (включая **все** **дочерние**).
- **Сортировка** по **retained heap** (убывание).
- **Клик** на **узел** → **Path to GC Roots** + **references**.

**Path to GC Roots**:
- **Показывает** **цепочку** **ссылок**: **объект** → **... → GC root**.
- **GC root** = **локальная** **переменная**, **static field**, **JNI handle**, **thread local**.
- **Почему** **важно**: **показывает** **почему** **объект** **не** **собран** (какая **цепочка** **ссылок** **удерживает**).

**OQL (Object Query Language)**:
```sql
-- 1. Топ-10 объектов по retained heap
SELECT * FROM INSTANCEOF java.util.HashMap ORDER BY retainedHeap DESC LIMIT 10

-- 2. Все объекты с именем, содержащим "Order"
SELECT * FROM * WHERE toString(name) LIKE "%Order%"

-- 3. Все объекты, созданные в конкретном классе
SELECT * FROM * WHERE class.name = "com.myapp.Order"

-- 4. Объекты с конкретным полем
SELECT * FROM INSTANCEOF com.myapp.Order WHERE status = "PENDING"

-- 5. Топ-10 классов по count
SELECT class, COUNT(*) FROM * GROUP BY class ORDER BY COUNT(*) DESC LIMIT 10
```

**Типовой workflow (поиск утечки)**:
1. **Получить** **heap dump** (Q61).
2. **Открыть** в **MAT**.
3. **Leak Suspects** → **топ** **подозрительные** **объекты**.
4. **Dominator Tree** → **найти** **объект** с **большим** **retained heap**.
5. **Path to GC Roots** → **почему** **объект** **не** **собран**.
6. **OQL** → **детальный** **анализ** (например, **все** **Order** **с** **status** **PENDING**).
7. **Найти** **root cause** (например, **static** **map** **не** **очистить**).

**Пример (утечка)**:
- **Leak Suspects**: `java.util.HashMap` (retained 500 MB).
- **Dominator Tree**: `HashMap` (500 MB) → **дети**: **10 000** **Order** **объектов**.
- **Path to GC Roots**: `HashMap` → **static field** `OrderService.cache` → **GC root** (static).
- **Root cause**: **static** **map** **`OrderService.cache`** **не** **очистить** (нет **TTL**, нет **limit**).

**Вывод**: **MAT** — **стандарт** для **анализа** **heap dump**. **Leak Suspects** + **Dominator Tree** + **Path to GC Roots** + **OQL** — **основные** **инструменты**. **Типовой** **workflow**: **Leak Suspects** → **Dominator Tree** → **Path to GC Roots** → **OQL** → **root cause**.


### 5. Как анализировать thread dump: deadlocks, pinning, blocked threads

**Thread dump** — **снимок** **всех** **потоков** JVM в **один** **момент** **времени**. **Содержит**: **имя** **потока**, **стек** **вызовов**, **статус** (RUNNABLE, BLOCKED, WAITING, TIMED_WAITING), **monitors** (lock'и), **synchronizers**.

**Как получить**:
```bash
# 1. jstack (классический способ)
jstack <pid> > thread_dump.txt

# 2. jcmd (Java 9+)
jcmd <pid> Thread.print > thread_dump.txt

# 3. Arthas
./as.sh <pid>
thread  # или thread -b (deadlock)

# 4. По сигналу (kill -3)
kill -3 <pid>  # dump в stdout (log файл)
```

**Статусы потоков**:
- **RUNNABLE** — **выполняется** (CPU) или **готов** **к** **выполнению**.
- **BLOCKED** — **ждёт** **monitor** (lock).
- **WAITING** — **ждёт** **без** **timeout** (`Object.wait()`, `Lock.lock()`, `Thread.join()`).
- **TIMED_WAITING** — **ждёт** **с** **timeout** (`Thread.sleep()`, `Lock.lock(timeout)`).
- **NEW** — **создан**, **ещё** **не** **started**.
- **TERMINATED** — **завершён**.

**Deadlock**:
```
Found one Java-level deadlock:
=============================
"thread-1":
  waiting for lock <0x00000000eab0c800> (owned by "thread-2")
"thread-2":
  waiting for lock <0x00000000eab0c808> (owned by "thread-1")
```
- **Причина**: **два** **потока** **ждут** **каждый** **свой** **lock** (цикл).
- **Решение**: **изменить** **порядок** **получения** **lock'ов** (всегда **в** **одном** **порядке**).

**Pinning (virtual threads)**:
- **Java 21**: **virtual threads** **могут** **пинниться** к **carrier thread** при **`synchronized`** или **native** **call**.
- **Признак** в **thread dump**: **много** **virtual threads** в **`RUNNABLE`** **с** **одним** **carrier** **thread**.
- **Диагностика**: **JFR** (`jdk.VirtualThreadPinned` **event**).

**Типовой workflow (диагностика)**:
1. **Обнаружение** **проблемы** (CPU > 80%, **задержки**).
2. **Снять** **thread dump** (`jstack <pid>`).
3. **Найти** **BLOCKED** **потоки** (`grep -A 20 "BLOCKED" thread_dump.txt`).
4. **Найти** **deadlock** (`grep -A 30 "deadlock" thread_dump.txt`).
5. **Найти** **hot** **методы** (RUNNABLE **с** **глубоким** **стеком**).
6. **Сравнить** **несколько** **thread dump** (разница **в** **5–10 сек**).
7. **Root cause** + **fix**.

**Антипаттерны**:
- **Один** **thread dump** **не** **достаточно** (нужно **2–3** **с** **интервалом** **5–10 сек**).
- **BLOCKED** **не** **всегда** **проблема** (может **быть** **нормальным** **wait**).
- **RUNNABLE** **не** **всегда** **CPU** (может **быть** **I/O**).

**Вывод**: **Thread dump** — **ключевой** **инструмент** для **диагностики** **поточных** **проблем**. **Deadlock** + **BLOCKED** + **pinning** — **основные** **сценарии**. **Несколько** **thread dump** (разница **5–10 сек**) — **лучше** **одного**.


### 6. Как использовать jcmd, jmap, jstack для диагностики

**JDK** **утилиты** — **командная** **строка** для **диагностики** **JVM** **без** **остановки** **приложения**.

**jcmd** (Java 9+, **универсальная**):
```bash
# 1. Список команд
jcmd <pid> help

# 2. Heap dump
jcmd <pid> GC.heap_dump /path/to/heap.hprof

# 3. Thread dump
jcmd <pid> Thread.print

# 4. Stack trace (по потоку)
jcmd <pid> Thread.print -e

# 5. GC (статистика)
jcmd <pid> GC.heap_info
jcmd <pid> GC.class_histogram

# 6. JFR
jcmd <pid> JFR.start duration=60s filename=recording.jfr
jcmd <pid> JFR.dump filename=recording.jfr

# 7. VM (информация)
jcmd <pid> VM.version
jcmd <pid> VM.uptime
jcmd <pid> VM.flags

# 8. PerfCounter (JMX-метрики)
jcmd <pid> PerfCounter.print

# 9. Heap dumps (live objects only)
jcmd <pid> GC.heap_dump -all /path/to/heap.hprof
```

**jmap** (legacy, **устаревает**):
```bash
# 1. Heap dump
jmap -dump:format=b,file=heap.hprof <pid>

# 2. Live objects only (с GC)
jmap -dump:live,format=b,file=heap.hprof <pid>

# 3. Class histogram
jmap -histo <pid> | head -30

# 4. Class histogram (live only)
jmap -histo:live <pid> | head -30

# 5. Персональные переменные
jmap -permgen <pid>
jmap -clstats <pid>
```

**jstack** (thread dump):
```bash
# 1. Thread dump
jstack <pid>

# 2. Thread dump (с lock'ами)
jstack -l <pid>

# 3. Thread dump (с mixed mode)
jstack -m <pid>

# 4. Найти deadlock
jstack <pid> | grep -A 30 "deadlock"

# 5. Найти BLOCKED
jstack <pid> | grep -A 20 "BLOCKED"
```

**jstat** (GC-метрики **в** **реальном** **времени**):
```bash
# 1. GC (каждые 1 сек, 10 раз)
jstat -gc <pid> 1000 10

# 2. GC utilization
jstat -gcutil <pid> 1000 10

# 3. Compiler
jstat -compiler <pid>

# 4. Class loading
jstat -class <pid>
```

**jinfo** (JVM **flags**):
```bash
# 1. Все flags
jinfo -flags <pid>

# 2. Конкретный flag
jinfo -flag MaxHeapSize <pid>

# 3. Установить flag (без перезапуска)
jinfo -flag:+UseG1GC <pid>
```

**Типовой workflow**:
1. **jcmd** <pid> **help** (список **команд**).
2. **jcmd** <pid> **GC.heap_info** (состояние **heap**).
3. **jstack** <pid> (thread dump).
4. **jcmd** <pid> **GC.heap_dump** (heap dump).
5. **jcmd** <pid> **JFR.start** (JFR **recording**).

**Вывод**: **jcmd** — **универсальная** **утилита** (Java 9+), **заменяет** **jmap**/**jstack**/**jstat**/**jinfo**. **Используй** **jcmd** для **всего**, **jstack** для **thread dump** (быстрее).


### 7. Как использовать strace и perf для диагностики Java-приложений

**strace** — **low-level** **tracing** **системных** **вызовов** (Linux). **perf** — **CPU** **profiling** (eBPF/perf_events).

**strace**:
```bash
# 1. Trace все системные вызовы
strace -p <pid>

# 2. Trace только I/O
strace -p <pid> -e trace=network

# 3. Trace с таймстампами
strace -p <pid> -t

# 4. Trace с count
strace -p <pid> -c  # summary

# 5. Trace в файл
strace -p <pid> -o strace.log

# 6. Trace только конкретный syscall
strace -p <pid> -e trace=read,write
```

**Типовые сценарии (Java)**:
- **Много** **`read`/`write`** на **одном** **файле** → **file I/O** **bottleneck**.
- **Много** **`connect`/`accept`** → **сетевые** **вызовы** (DB, API).
- **`futex`** **wait** → **lock contention** (JVM **использует** **futex** для **monitor'ов**).
- **`mmap`**/`munmap` → **memory** **mapping** (NIO, DirectByteBuffer).

**perf**:
```bash
# 1. CPU profiling (30 секунд)
perf record -g -p <pid> -- sleep 30
perf report

# 2. Flame graph (через Brendan Gregg's tools)
perf record -g -p <pid> -- sleep 30
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# 3. Top CPU-функции
perf top -p <pid>

# 4. Specific event
perf record -e cycles -p <pid> -- sleep 30
```

**Когда strace, когда perf**:
| Задача | Инструмент |
|---|---|
| **System calls** (I/O, network) | strace |
| **CPU profiling** (hot methods) | perf / async-profiler |
| **Lock contention** (futex) | strace (`-e futex`) |
| **File I/O** bottleneck | strace (`-e trace=file`) |
| **Network** bottleneck | strace (`-e trace=network`) |

**Вывод**: **strace** — **системные** **вызовы** (I/O, network, futex). **perf** — **CPU** **profiling** (flame graph). **Для Java**: **async-profiler** **лучше** **perf** (JVM-aware), **strace** **для** **low-level** **I/O**.


### 8. Как настроить production-ready logging: structured logs, correlation IDs, log levels

**Production-ready logging** — **структурированные** **логи** с **корреляцией** (trace id, span id, request id) и **правильными** **уровнями**.

**Structured logging (JSON)**:
```json
{
  "timestamp": "2026-01-15T10:30:00.123Z",
  "level": "ERROR",
  "service": "order-api",
  "trace_id": "abc123def456",
  "span_id": "789xyz",
  "request_id": "req-001",
  "user_id": "user-123",
  "message": "Failed to process order",
  "order_id": 123,
  "error": "timeout",
  "exception": "java.util.concurrent.TimeoutException: ..."
}
```

**Преимущества**:
- **Поиск** по **любому** **полю** (не только **текст**).
- **Корреляция** с **traces** (trace_id, span_id).
- **Агрегация** (count по **level**, **service**).
- **Индексация** (Loki **индексирует** **метки**, Elasticsearch **всё**).

**Correlation IDs**:
- **trace_id** — **общий** для **всего** trace (OpenTelemetry).
- **span_id** — **уникальный** для **span**.
- **request_id** — **уникальный** для **HTTP request** (может **совпадать** с **trace_id**).
- **user_id** — **идентификатор** **пользователя**.

**Log levels** (SLF4J/Logback):
| Уровень | Когда использовать | Пример |
|---|---|---|
| **TRACE** | Очень детально (debug) | Каждый SQL-запрос |
| **DEBUG** | Debug (полезно в dev) | Вход/выход методов |
| **INFO** | Нормальная работа | Запрос обработан |
| **WARN** | Проблема, но не критично | Timeout, retry |
| **ERROR** | Ошибка | Исключение |

**Правила**:
- **Не** **логировать** **чувствительные** **данные** (password, token, CCV).
- **Не** **логировать** **большие** **объекты** (JSON > 10 KB).
- **Использовать** **parameterized** **logging** (`log.info("Order {}", orderId)`, **не** `log.info("Order " + orderId)`).
- **Логировать** **исключение** **последним** **аргументом** (`log.error("Failed", e)`).
- **Не** **логировать** **в** **цикле** (thundering herd).

**Logback** **конфигурация** (JSON + MDC):
```xml
<configuration>
    <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <customFields>{"service":"${APP_NAME}"}</customFields>
        </encoder>
    </appender>
    <root level="INFO">
        <appender-ref ref="JSON"/>
    </root>
    <logger name="com.myapp" level="DEBUG"/>
    <logger name="org.springframework" level="WARN"/>
</configuration>
```

**MDC** (Mapped Diagnostic Context):
```java
// Spring Boot: MDC auto-populated (trace_id, span_id)
log.info("Processing order {}", orderId);
// Вывод (JSON): {"trace_id":"abc123","span_id":"def456","message":"Processing order 123"}

// Ручное
MDC.put("userId", "user123");
log.info("User action");
MDC.remove("userId");
```

**В Reactor**: **MDC не работает** (ThreadLocal теряется). Используй **`Context`** (Q704) + **logback-reactive**.

**Вывод**: **Structured logging** (JSON) + **correlation IDs** (trace_id, span_id) + **правильные** **log levels** — **обязательны** для **production**. **LogstashEncoder** + **MDC** — **стандарт** для **Java**.


### 9. Как диагностировать медленный запрос в production (end-to-end workflow)

**Сценарий**: **API** **стал** **медленным** (p95 latency **вырос** с **200 ms** до **2 c**). **Как** **диагностировать**?

**Шаг 1: Metrics (Prometheus/Grafana)**:
```promql
# 1. p95 latency (по endpoint)
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{endpoint="/orders"}[5m])) by (le))

# 2. Error rate
sum(rate(http_requests_total{endpoint="/orders", status=~"5.."}[5m]))
  /
sum(rate(http_requests_total{endpoint="/orders"}[5m]))

# 3. CPU / Memory (pod)
sum(rate(container_cpu_usage_seconds_total{pod="order-api-..."}[5m]))
container_memory_working_set_bytes{pod="order-api-..."}
```

**Шаг 2: Traces (Jaeger/Tempo)**:
- **Найти** **медленные** **traces** (p95 > 2 c).
- **Посмотреть** **spans**: **где** **уходит** **время** (HTTP, DB, external API).
- **Пример**: **80%** **времени** — **DB** **query**.

**Шаг 3: Logs (Loki/ELK)**:
- **Поиск** по **trace_id** → **логи** **с** **этот** **запрос**.
- **Найти** **WARN/ERROR** (timeout, retry).
- **Пример**: `WARN - Slow query: 1.8s (SELECT ... FROM orders)`.

**Шаг 4: DB diagnostics**:
```sql
-- 1. EXPLAIN ANALYZE (план запроса)
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 123 AND created_at > NOW() - INTERVAL '1 month';

-- 2. pg_stat_statements (топ медленных запросов)
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- 3. pg_stat_user_tables (bloat, index usage)
SELECT relname, n_live_tup, n_dead_tup,
       (n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0)) * 100 AS bloat
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

**Шаг 5: JVM diagnostics (JFR/async-profiler)**:
```bash
# 1. JFR (60 секунд)
jcmd <pid> JFR.start duration=60s filename=recording.jfr

# 2. async-profiler (CPU flame graph)
./async-profiler/profile -d 30 -f cpu.html <pid>

# 3. Thread dump (несколько)
jstack <pid> > thread_dump_1.txt
sleep 10
jstack <pid> > thread_dump_2.txt
```

**Шаг 6: Root cause + fix**:
- **Пример**: **пропал** **индекс** **после** **миграции** (full table scan).
- **Fix**: **создать** **индекс** + **проверить** **migration**.

**Вывод**: **End-to-end** **workflow**: **Metrics** (Prometheus) → **Traces** (Jaeger) → **Logs** (Loki) → **DB** (EXPLAIN) → **JVM** (JFR/async-profiler) → **root cause** → **fix**. **Каждый** **шаг** **сужает** **диапазон** **поиска**.


### 10. Как использовать GC-метрики и heap histogram для диагностики памяти

**GC-метрики** — **ключ** для **диагностики** **проблем** **с** **памятью**.

**jstat** (GC-метрики **в** **реальном** **времени**):
```bash
# 1. GC (каждые 1 сек, 10 раз)
jstat -gc <pid> 1000 10

# Вывод:
# S0C S1C S0U S1U EC EU OC OU MC MNU CCS   Time  GCT  GCT   YGC   FGC
# 5120 5120 0 4992 51200 45000 512000 450000 5120 4800 2560  12.3  0.5  0.1   15   2

# Колонки:
# S0C/S1C — Young Gen (Survivor 0/1) capacity
# S0U/S1U — Young Gen used
# EC/EU — Eden capacity/used
# OC/OU — Old Gen capacity/used
# MC/MNU — Metaspace capacity/used
# CCS — Compressed Class Space
# YGC — Young GC count
# FGC — Full GC count
```

**jcmd** (heap **info**):
```bash
jcmd <pid> GC.heap_info
# Вывод:
# garbage-first heap   total 4096MB, used 3500MB [0x...)
#  region size 4MB, 50 young (200MB), 1 survivors (4MB)
# Metaspace       used 512MB, committed 600MB, reserved 1128MB
#  class space    used 50MB, committed 60MB, reserved 1024MB
```

**jmap** (class **histogram**):
```bash
# 1. Топ-30 классов по count
jmap -histo <pid> | head -30

# Вывод:
# num     #instances         #bytes  class name
#   1:         12345        123456  com.myapp.Order
#   2:         56789        234567  java.lang.String
#   3:         12345         98765  java.util.HashMap$Node
```

**GC-метрики (Prometheus/Micrometer)**:
```promql
# 1. GC pause time (p99)
histogram_quantile(0.99,
  sum(rate(jvm_gc_pause_seconds_bucket[5m])) by (le, action))

# 2. GC frequency (разы/сек)
sum(rate(jvm_gc_pause_seconds_count[5m])) by (action)

# 3. Heap used (по поколениям)
jvm_memory_used_bytes{area="heap", id="G1 Old Gen"}
jvm_memory_used_bytes{area="heap", id="G1 Eden Space"}

# 4. Metaspace used
jvm_memory_used_bytes{area="nonheap", id="Metaspace"}
```

**Типовые проблемы**:
| Симптом | Причина | Диагностика |
|---|---|---|
| **Много** **Young GC** (YGC > 10/sec) | **Много** **короткоживущих** **объектов** | **jmap -histo** (какие **классы** **создаются**) |
| **Много** **Full GC** (FGC > 1/min) | **Old Gen** **заполнен** (утечка) | **heap dump** + **MAT** (Leak Suspects) |
| **Длинные** **GC pause** (> 500 ms) | **Большая** **куча**, **Old Gen** **заполнен** | **jstat -gc** (размер **Old Gen**), **JFR** (GC **timeline**) |
| **Рост** **Metaspace** | **Classloader** **leak** | **jcmd** <pid> **GC.class_histogram** (много **классов**) |
| **ОOM** **Java Heap Space** | **Утечка** | **heap dump** + **MAT** (Path to GC Roots) |

**Типовой workflow**:
1. **jstat -gc** <pid> 1000 10 (GC-метрики).
2. **jcmd** <pid> **GC.heap_info** (состояние **heap**).
3. **jmap -histo** <pid> (класс **histogram**).
4. **heap dump** + **MAT** (Leak Suspects, Dominator Tree).
5. **JFR** (GC **timeline**).
6. **Root cause** + **fix**.

**Вывод**: **GC-метрики** (jstat, jcmd, Prometheus) + **heap histogram** (jmap) + **heap dump** (MAT) — **основные** **инструменты** для **диагностики** **памяти**. **Типовой** **workflow**: **jstat** → **jcmd** → **jmap** → **heap dump** → **MAT** → **root cause**.


### 11. Incident response: как реагировать на P1/P2/P3 инциденты

**Классификация:**
- **P1 (Critical)**: система недоступна для всех (99%+ пользователей). **SLA**: response < 5 мин, mitigation < 30 мин. **Пример**: DB down, API 500%.
- **P2 (High)**: деградация (5-20% пользователей, или critical feature). **SLA**: response < 15 мин, mitigation < 2 час. **Пример**: latency p99 > 5 сек, error rate 5%.
- **P3 (Medium)**: minor issue (1-5% пользователей, non-critical). **SLA**: response < 1 час, fix < 24 час. **Пример**: logging error, minor UI bug.

**Процесс (P1):**
1. **Detect** (5 мин): alert (PagerDuty) → on-call engineer → **triage** (что сломано, scope, impact).
2. **Mitigate** (30 мин): **rollback** (если deploy виноват), **feature flag** (отключить фичу), **rate limit** (защитить от overload), **scale** (добавить поды).
3. **Diagnose** (параллельно): logs, metrics, tracing → root cause.
4. **Communicate**: status page (для пользователей), Slack (для команды), **war room** (если P1).
5. **Resolve**: fix + verify (metrics норма).
6. **Post-mortem** (24-48 час): blameless, 5 Whys, action items.

**Комманды (production):**
```bash
# Triage:
kubectl get pods -n prod | grep -v Running  # какие поды не Running
kubectl logs <pod> -n prod --tail=100      # последние логи
curl -s https://api.example.com/health     # health check
# Metrics (Grafana):
# - Error rate, latency p99, throughput
# - DB connections, GC pause
# Mitigation:
kubectl rollout undo deployment/api -n prod  # rollback
kubectl scale deployment/api --replicas=10 -n prod  # scale up
```

**Anti-patterns:**
- **Blame**: «кто виноват?» → **blameless** (что пошло не так, как улучшить процесс).
- **Guess**: «может, перестартовать?» → **data-driven** (logs, metrics).
- **Silent**: не сообщать → **communicate** (status page, Slack).

**Post-mortem template:**
```markdown
## Timeline
- 10:00 — alert (error rate > 5%)
- 10:05 — on-call: triage, P1
- 10:15 — rollback deploy #1234
- 10:30 — metrics норма

## Root Cause (5 Whys)
1. Почему error rate > 5%? → OOM
2. Почему OOM? → memory leak
3. Почему memory leak? → ThreadLocal не очищен
4. Почему не очищен? → no finally block
5. Почему no finally? → code review не нашёл

## Action Items
- [ ] Добавить finally block (PR #1235)
- [ ] Unit test для ThreadLocal cleanup
- [ ] Code review checklist: ThreadLocal remove
```

### 12. Как диагностировать OOM в production

**Симптомы:**
- `java.lang.OutOfMemoryError: Java heap space`
- GC частый (каждые 10 сек), old gen > 90%
- Приложение медленнее, error rate растёт

**Диагностика:**
```bash
# 1. Heap dump (до OOM, если есть время):
jmap -dump:live,format=b,file=heap.hprof <pid>

# 2. Если OOM (автоматически):
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/dumps/
# После OOM: heap.hprof в /var/dumps/

# 3. Анализ (Eclipse MAT):
# - Leak Suspects Report
# - Dominator Tree (какой объект занимает больше всего)
# - Path to GC Roots (почему объект не собран)

# 4. GC log (паттерн):
-Xlog:gc*,gc+heap=debug:file=gc.log
# Если old gen не уменьшается после full GC → leak
```

**Типичные причины:**
1. **Memory leak** (ThreadLocal, collection без bound) → heap dump → Dominator Tree.
2. **Heap слишком мал** (allocation rate > capacity) → увеличить heap или оптимизировать.
3. **Object graph** (большой объект, например: 10 MB JSON) → streaming, chunked processing.
4. **Metaspace** (слишком много классов, dynamic proxies) → `-XX:MaxMetaspaceSize`, проверить class loading.

**Мониторинг (Prometheus):**
```promql
# Heap usage:
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}
# GC frequency:
rate(jvm_gc_pause_seconds_count[5m])
# Old gen:
jvm_memory_used_bytes{area="heap", id="G1 Old Gen"}
```
**Alert**: `heap_usage > 0.8` (5 мин) → P2.

**Mitigation:**
- **Restart** (если leak, и нет времени на fix) — временное.
- **Increase heap** (`-Xmx`) — если allocation rate высокий, но нет leak.
- **Fix** (ThreadLocal remove, collection limit) — permanent.

**Follow-up:**
- «А как воспроизвести leak в staging?» → **load test** (1 час), heap dump каждый 10 мин, сравнить.
- «А как предотвратить?» → **unit tests** (memory), **code review** (ThreadLocal, collections), **CI** (heap dump при OOM на load test).

### 13. Как диагностировать deadlock в production

**Симптомы:**
- Приложение зависло (no response, no logs)
- Thread dump: все потоки `BLOCKED` или `WAITING`
- CPU = 0% (потоки не работают)

**Диагностика:**
```bash
# 1. Thread dump:
jstack <pid> > thread_dump.txt
# Или:
jcmd <pid> Thread.dump_threads

# 2. Поиск deadlock:
grep -A 20 "deadlock" thread_dump.txt
# Java автоматически детектирует deadlock:
# "Found one Java-level deadlock"

# 3. Анализ:
# - Какие потоки? (Thread-1, Thread-2)
# - Какие lock'и? (lock A, lock B)
# - Круг: Thread-1 wait lock B, Thread-2 wait lock A

# 4. Если deadlock в C++ (JNI):
# - jstack не покажет (Java threads ok)
# - Нужно: gdb attach, или native profiler
```

**Пример thread dump (deadlock):**
```
"Thread-1" #12 prio=5 os_prio=0 tid=0x... nid=0x... waiting for monitor entry
   at com.example.Service.methodA(Service.java:50)
   - waiting to lock <0x00000000eab3c000> (a java.lang.Object)
   - locked <0x00000000eab3c100> (a java.lang.Object)

"Thread-2" #13 prio=5 os_prio=0 tid=0x... nid=0x... waiting for monitor entry
   at com.example.Service.methodB(Service.java:80)
   - waiting to lock <0x00000000eab3c100> (a java.lang.Object)
   - locked <0x00000000eab3c000> (a java.lang.Object)

Found one Java-level deadlock:
=============================
"Thread-1":
  waiting for lock <0x00000000eab3c000>
  held by "Thread-2"
"Thread-2":
  waiting for lock <0x00000000eab3c100>
  held by "Thread-1"
```

**Решение:**
1. **Lock ordering**: все потоки захватывают lock'и в одном порядке (A → B, не B → A).
2. **Timeout**: `tryLock(timeout)` — если не удалось → rollback, retry.
3. **Reduce locks**: один lock на critical section (не два).
4. **Lock-free**: Atomic (CAS), ConcurrentLinkedQueue.

**Мониторинг:**
- **Thread dump** каждые 5 мин (если CPU = 0% и no logs) → поиск deadlock.
- **JMX**: `ThreadMXBean.findDeadlockedThreads()` → alert.

**Follow-up:**
- «А как предотвратить?» → **code review** (lock ordering), **unit tests** (concurrent, stress), **async-profiler** (`e lock`).
- «А если deadlock в native code?» → **gdb** (attach), **native profiler**, или **restart** (временное).

### 14. Как диагностировать memory leak (кроме OOM)

**Симптомы:**
- Heap растёт (GC не помогает)
- Old gen > 80% после full GC
- Приложение медленнее (GC чаще)

**Диагностика:**
```bash
# 1. Heap dump (live):
jmap -dump:live,format=b,file=heap.hprof <pid>

# 2. Eclipse MAT:
# - Leak Suspects: "Suspect 1: com.example.Cache, 500 MB"
# - Dominator Tree: какой объект занимает больше всего
# - Path to GC Roots: почему объект не собран (strong reference)

# 3. GC log (паттерн):
# Если old gen не уменьшается → leak
# Если allocation rate высокий → много объектов

# 4. JFR (allocation profile):
# Какой класс allocates больше всего
```

**Типичные утечки:**
1. **ThreadLocal**:
   ```java
   // Утечка:
   static ThreadLocal<Context> ctx = new ThreadLocal<>();
   public void handle() {
       ctx.set(new Context());  // не очищен!
   }
   // Fix:
   try {
       ctx.set(new Context());
       // work
   } finally {
       ctx.remove();
   }
   ```
2. **Collection без bound**:
   ```java
   // Утечка:
   static List<String> cache = new ArrayList<>();
   public void add(String s) { cache.add(s); }  // растёт бесконечно
   // Fix:
   static Cache<String, String> cache = Caffeine.newBuilder()
       .maximumSize(10_000)
       .expireAfterWrite(Duration.ofHours(1))
       .build();
   ```
3. **Listener не deregistered**:
   ```java
   // Утечка:
   eventBus.addListener(listener);  // не удалён
   // Fix:
   try {
       eventBus.addListener(listener);
       // work
   } finally {
       eventBus.removeListener(listener);
   }
   ```
4. **Inner class → outer**:
   ```java
   // Утечка:
   class Outer {
       byte[] data = new byte[10 * 1024 * 1024];  // 10 MB
       void register() {
       }
   }
   // Fix: static inner class, или explicit reference cleanup
   ```

**Мониторинг:**
```promql
# Old gen usage:
jvm_memory_used_bytes{area="heap", id="G1 Old Gen"}
# Если > 80% после full GC → leak
# GC frequency:
rate(jvm_gc_pause_seconds_count[5m])
# Если чаще 1/мин → проблема
```

**Профилактика:**
- **Unit tests** (memory): создать N объектов, проверить heap (JOL, Instrumentation).
- **Load test** (1 час): heap trend (растёт или стабилен).
- **Code review**: ThreadLocal remove, collection limit, listener cleanup.

### 15. Как диагностировать высокий CPU в Java-приложении

**Симптомы:**
- CPU > 90% (один поток или все)
- Latency растёт, throughput падает
- GC не частый (не GC-проблема)

**Диагностика:**
```bash
# 1. Найти hot thread:
top -Hp <pid>  # PID, %CPU per thread
# Топ-1 thread: 95% CPU

# 2. Thread ID → hex:
printf '%x\n' <TID>

# 3. Thread dump (найти thread):
jstack <pid> | grep -A 30 "nid=0x<hex>"

# 4. async-profiler (flame graph):
./profiler.sh -e cpu -d 30 <pid>
# Открыть HTML: широкий блок = hot spot

# 5. JFR (CPU profile):
jcmd <pid> JFR.start duration=30s filename=cpu.jfr
# JMC: CPU tab → hot methods
```

**Типичные причины:**
1. **Infinite loop** (while true без break) → thread dump: один поток в loop.
2. **CPU-intensive computation** (regex, string parsing) → flame graph: hot method.
3. **Lock contention** (spinning) → `e lock` profile: кто держит lock.
4. **GC (if frequent)** → GC log: pause, allocation rate.

**Решение:**
1. **Infinite loop**: fix code (break condition).
2. **CPU-intensive**: optimize (cache, batch, async), или scale (больше CPU).
3. **Lock contention**: reduce critical section, lock-free (Atomic).
4. **GC**: ZGC (pause < 1 ms), increase heap, reduce allocation.

**Мониторинг:**
```promql
# CPU per process:
process_cpu_seconds_total{app="api"}
# Если > 0.9 (90%) → P2
# CPU per thread (JMX):
# ThreadMXBean.getThreadCpuTime(threadId)
```

**Follow-up:**
- «А как оптимизировать hot method?» → **JMH** (bench), **JIT flags** (`-XX:+UnlockDiagnosticVMOptions`), **algorithm** (O(n²) → O(n)).
- «А если CPU high на одном ядре?» → **CPU affinity** (pinning), или **load balance** (распределить по ядрам).

### 16. Как диагностировать высокий I/O (disk, network)

**Симптомы:**
- Disk I/O > 90% (iowait высокий)
- Network: latency > 100 ms, packet loss
- Приложение медленнее (I/O bound)

**Диагностика (disk):**
```bash
# 1. iostat:
iostat -x 1 5
# %iowait > 30% → disk bottleneck
# await > 10 ms → slow disk

# 2. iotop (per process):
iotop -o  # какие процессы пишут/читают

# 3. strace (per process):
strace -p <pid> -e trace=file  # file I/O calls
# Если много read/write → optimization (batch, cache)

# 4. Java: JFR (I/O profile):
# File I/O, Socket I/O
```

**Диагностика (network):**
```bash
# 1. iftop / nload:
iftop -i eth0  # per connection

# 2. netstat / ss:
ss -tnp  # TCP connections, state
# Если много CLOSE_WAIT → app не закрывает соединения

# 3. Ping / traceroute:
ping <host>  # latency, packet loss
traceroute <host>  # где bottleneck

# 4. Java: JFR (Socket I/O):
# Socket read/write time
```

**Решение:**
1. **Disk**: SSD (вместо HDD), **cache** (Caffeine, Redis), **batch I/O** (меньше syscalls).
2. **Network**: **connection reuse** (keep-alive, pool), **compression** (gzip), **CDN** (ближе к пользователю).
3. **I/O bound**: **async I/O** (CompletableFuture, Virtual Threads) — не блокировать thread.

**Мониторинг:**
```promql
# Disk I/O:
node_disk_io_time_seconds_total
# Если %iowait > 30% → P2
# Network:
node_network_receive_bytes_total, node_network_transmit_bytes_total
# Если saturation → scale
```

**Follow-up:**
- «А как оптимизировать file I/O?» → **NIO** (non-blocking), **mmap** (memory-mapped file), **batch** (меньше syscalls).
- «А как оптимизировать network I/O?» → **HTTP/2** (multiplexing), **gRPC** (streaming), **connection pool**.

### 17. Как использовать jcmd для диагностики (подробно)

**jcmd** (JDK 7+) — unified tool (jstack + jmap + jinfo + GC).

**Основные команды:**
```bash
# Список процессов:
jcmd -l

# Thread dump:
jcmd <pid> Thread.dump_threads
jcmd <pid> Thread.print  # alias

# Heap info:
jcmd <pid> GC.heap_info
jcmd <pid> GC.class_histogram  # top classes by count/size

# Heap dump:
jcmd <pid> GC.dump_heap /tmp/heap.hprof

# GC log:
jcmd <pid> VM.log output = gc:file=gc.log

# VM info:
jcmd <pid> VM.version
jcmd <pid> VM.uptime
jcmd <pid> VM.flags

# PerfCounter (JMX):
jcmd <pid> PerfCounter.print
jcmd <pid> PerfCounter.print sun.management

# Thread CPU:
jcmd <pid> Thread.print | grep "cpu="

# Help:
jcmd <pid> help
```

**Пример (OOM investigation):**
```bash
# 1. Heap info:
jcmd 12345 GC.heap_info
# Г1 heap:
#   region size: 4 MB, young: 100 MB, old: 800 MB
#   used: 950 MB / 1000 MB (95%)

# 2. Class histogram (какие объекты):
jcmd 12345 GC.class_histogram | head -20
# num     #instances         #bytes  class name
# 1:      5000000        400000000  [Ljava.lang.Object;
# 2:      1000000        100000000  com.example.Entity

# 3. Heap dump:
jcmd 12345 GC.dump_heap /tmp/heap.hprof
# Анализ: Eclipse MAT

# 4. Thread dump (если deadlock):
jcmd 12345 Thread.dump_threads > threads.txt
```

**JFR (via jcmd):**
```bash
# Start recording:
jcmd <pid> JFR.start duration=60s filename=rec.jfr

# Dump (online):
jcmd <pid> JFR.dump filename=rec.jfr

# Stop:
jcmd <pid> JFR.stop
```

**Follow-up:**
- «А как автоматизировать?» → **cron** (каждые 5 мин: thread dump, heap info), или **agent** (JMX → Prometheus).
- «А как в Kubernetes?» → `kubectl exec <pod> -- jcmd 1 ...` (PID = 1, если no init container).

### 18. Как диагностировать problem с connection pool (HikariCP, DB)

**Симптомы:**
- Timeout: `SQLTimeoutException: Connection is not available, request timed out after 30000ms`
- Waiting threads: много потоков `WAITING` на HikariPool
- DB connections = max (пул исчерпан)

**Диагностика:**
```bash
# 1. HikariCP metrics (JMX / Prometheus):
# - Active: 10 (max)
# - Idle: 0
# - Waiting: 50 (потоки ждут соединение)
# - Timeout: 10 (запросы таймаутят)

# 2. Thread dump:
jstack <pid> | grep -A 10 "HikariPool"
# Много потоков: "waiting for connection from pool"

# 3. DB connections:
psql -c "SELECT * FROM pg_stat_activity;"
# Если 100 connections (max) → пул исчерпан

# 4. Slow queries:
psql -c "SELECT pid, now() - query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC;"
# Если query > 10 сек → bottleneck
```

**Причины:**
1. **Пул слишком мал** (max = 10, load = 100 concurrent) → увеличить `maximum-pool-size`.
2. **Slow queries** (10 сек на запрос) → оптимизировать (index, query).
3. **Connection leak** (не закрыли транзакцию) → проверить code (try-with-resources).
4. **DB bottleneck** (DB не справляется) → scale (replica, shard).

**Решение:**
```yaml
# HikariCP config:
spring:
  datasource:
    hikari:
      maximum-pool-size: 20  # увеличить
      minimum-idle: 20
      connection-timeout: 30000
      max-lifetime: 1800000
```
```java
// Connection leak check:
try (Connection conn = dataSource.getConnection()) {
    // work
}  // auto-close
```

**Мониторинг:**
```promql
# HikariCP:
hikaricp_connections_active
hikaricp_connections_waiting
hikaricp_connections_timeout_total
# Alert: waiting > 10 (5 мин) → P2
```

**Follow-up:**
- «А как найти connection leak?» → **HikariCP** (`leak-detection-threshold=5000`) → log если connection > 5 сек.
- «А как scale DB?» → **read replica** (чтение), **sharding** (запись), **connection pool per shard**.

### 19. Как диагностировать problem с Kafka consumer (lag, throughput)

**Симптомы:**
- **Lag** (consumer отставает): `consumer lag > 100K`
- **Throughput** падает: consumer не успевает
- **Rebalance** частый: consumer group перераспределяет partitions

**Диагностика:**
```bash
# 1. Consumer lag:
kafka-consumer-groups --bootstrap-server kafka:9092 \
    --describe --group my-group
# TOPIC  PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
# orders  0          1000000         1050000         50000

# 2. Consumer throughput:
kafka-consumer-groups --describe --group my-group
# Через 1 мин:
# orders  0          1010000         1055000         45000
# Throughput: 10000 msg/min (низкий)

# 3. Rebalance events:
kafka-consumer-groups --describe --group my-group
# Если "REBALANCE" часто → проблема

# 4. Consumer app logs:
# - "Processing message" (slow?)
# - "Exception" (error?)
```

**Причины:**
1. **Consumer слишком медленный** (processing > 1 сек/msg) → optimize (batch, parallel).
2. **Too many partitions** (100 partitions, 10 consumers) → rebalance overhead.
3. **Consumer app error** (exception → retry → lag) → fix error.
4. **Kafka broker bottleneck** (network, disk) → scale broker.

**Решение:**
```java
// 1. Batch processing:
@KafkaListener(topics = "orders", batch = "true")
public void onBatch(List<Order> orders) {
    orderRepo.saveAll(orders);  // 1 SQL на 100 orders
}

// 2. Parallel processing:
@KafkaListener(topics = "orders", concurrency = "10")
public void onMessage(Order order) {
    process(order);  // 10 threads
}

// 3. Async processing:
@KafkaListener(topics = "orders")
public void onMessage(Order order) {
    CompletableFuture.runAsync(() -> process(order), executor);
}
```

**Мониторинг (Prometheus + kafka-exporter):**
```promql
# Consumer lag:
kafka_consumergroup_lag{group="my-group"}
# Alert: lag > 100K (5 мин) → P2

# Throughput:
rate(kafka_consumergroup_messages_consumed_total[5m])
# Если < 1000 msg/sec → проблема
```

**Follow-up:**
- «А как избежать rebalance?» → **static group membership** (consumer ID), **session timeout** (больше).
- «А как scale consumer?» → **increase consumers** (до partition count), **increase partitions** (если consumers < partitions).

### 20. Как диагностировать problem с DNS / network в Kubernetes

**Симптомы:**
- `UnknownHostException: service-a` (DNS не резолвится)
- `Connection refused` (service не найден)
- Latency > 100 ms (network bottleneck)

**Диагностика:**
```bash
# 1. DNS (из пода):
kubectl exec <pod> -- nslookup service-a
# Если "can't find" → CoreDNS problem

# 2. CoreDNS logs:
kubectl logs -n kube-system -l k8s-app=kube-dns
# Если " SERVFAIL" → problem

# 3. Service / Endpoint:
kubectl get svc service-a
kubectl get endpoints service-a
# Если endpoints пусто → no ready pods

# 4. Network policy:
kubectl get networkpolicy -n <ns>
# Если есть deny → проверить rules

# 5. Network latency:
kubectl exec <pod> -- ping <service-ip>
# Если latency > 100 ms → network problem

# 6. CNI (Calico, Cilium):
kubectl exec <pod> -- ip route
# Если route нет → CNI problem
```

**Причины:**
1. **CoreDNS down** (pod не Running) → `kubectl get pods -n kube-system`.
2. **Service нет endpoints** (no ready pods) → `kubectl get pods -l app=service-a`.
3. **NetworkPolicy** (deny) → проверить rules.
4. **CNI problem** (Calico, Cilium) → logs, restart.
5. **Network saturation** (bandwidth) → `iftop`, scale.

**Решение:**
```bash
# CoreDNS:
kubectl rollout restart deployment/coredns -n kube-system

# Service:
kubectl delete svc service-a && kubectl apply -f service.yaml

# NetworkPolicy:
kubectl delete networkpolicy <name> -n <ns>  # если wrong
```

**Мониторинг:**
- **DNS latency**: `node_dns_resolv_time_seconds` (Node Exporter).
- **Service endpoints**: `kubectl get endpoints` (empty → alert).
- **Network**: `node_network_receive_bytes_total` (saturation → alert).

**Follow-up:**
- «А как debug network между подами?» → **tcpreplay** (replay traffic), **tcpdump** (capture), **Cilium Hubble** (L7 visibility).
- «А как optimize DNS?» → **node-local DNS cache** (CoreDNS + cache на ноде), **long TTL** (если service stable).

### 21. Как настроить мониторинг и алертинг для Java-приложения

**Стек (Grafana Stack):**
- **Prometheus** (metrics): scrape `/metrics` (Micrometer, Actuator).
- **Grafana** (dashboards): latency, error rate, throughput, GC.
- **Loki** (logs): structured logs (JSON) → label-based indexing.
- **Alertmanager** (alerts): Prometheus → Slack / PagerDuty.

**Metrics (Micrometer + Actuator):**
```yaml
# application.yml:
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  metrics:
    tags:
      application: ${spring.application.name}
```
```java
// Custom metrics:
@Bean
public Counter orderCounter(MeterRegistry registry) {
    return Counter.builder("orders.created")
        .description("Total orders created")
        .register(registry);
}

// Timer (latency):
@Timed(value = "order.create.duration", percentiles = true)
public Order createOrder(CreateOrderRequest req) {
    // ...
}
```

**Dashboards (Grafana):**
1. **Overview**: error rate, latency p99, throughput, CPU, memory.
2. **JVM**: GC pause, heap usage, thread count.
3. **Database**: query latency, connection pool, slow queries.
4. **Kafka**: consumer lag, throughput, rebalance.

**Alerts (Alertmanager):**
```yaml
# Prometheus rules:
groups:
  - name: java-app
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: P1
        annotations:
          summary: "Error rate > 5% for 5 min"

      - alert: HighLatency
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 5
        for: 5m
        labels:
          severity: P2
        annotations:
          summary: "p99 latency > 5 sec for 5 min"

      - alert: GCHighPause
        expr: histogram_quantile(0.99, rate(jvm_gc_pause_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: P2
        annotations:
          summary: "GC pause p99 > 1 sec"
```

**SLO / Error Budget:**
```yaml
# SLO: error rate < 0.1% (monthly)
# Error budget: 100% - 99.9% = 0.1% = 43.8 мин/мес
# Если budget исчерпан → мораторий на новые фичи
```

**Follow-up:**
- «А как correlation с logs?» → `trace_id` в MDC → Loki (search by `trace_id`).
- «А как synthetic monitoring?» → **Grafana Synthetic** (каждые 1 мин: health check).

### 22. Как провести post-mortem (blameless) и извлечь lessons

**Процесс:**
1. **Собрать данные** (timeline, metrics, logs, alerts).
2. **Написать draft** (timeline, root cause, impact).
3. **Review** (команда, 30 мин meeting).
4. **Publish** (internal wiki, Slack).
5. **Action items** (assignee, deadline).

**Template:**
```markdown
# Post-mortem: API down (2024-01-15)

## Summary
API был недоступен 30 мин (10:00-10:30). Причина: OOM в Order Service. Impact: 15K пользователей.

## Timeline
- 10:00 — Alert: error rate > 5%
- 10:05 — On-call: triage, P1
- 10:10 — Диагностика: OOM в Order Service
- 10:15 — Mitigation: restart pod
- 10:30 — Metrics норма

## Root Cause (5 Whys)
1. Почему error rate > 5%? → OOM
2. Почему OOM? → Memory leak
3. Почему memory leak? → ThreadLocal не очищен
4. Почему не очищен? → No finally block
5. Почему no finally? → Code review не нашёл

## Impact
- 15K пользователей (30 мин)
- $5K revenue loss
- SLA breach (99.9% → 99.5%)

## Action Items
- [ ] Add finally block (PR #1235, 2024-01-20)
- [ ] Unit test для ThreadLocal cleanup (PR #1236, 2024-01-25)
- [ ] Code review checklist: ThreadLocal remove (2024-01-18)
- [ ] Alert: heap usage > 80% (2024-01-18)

## Lessons Learned
- ThreadLocal в thread pool — always remove in finally
- Code review: checklist для common patterns
- Alert: heap usage (до OOM)
```

**Принципы (blameless):**
- **Что пошло не так**, а не **кто виноват**.
- **Systemic** (процесс, tooling), а не individual.
- **Action items** (конкретные, с assignee и deadline).
- **Share** (internal wiki, чтобы другие учились).

**Anti-patterns:**
- **Blame**: «Петров виноват» → **no** (blameless).
- **Vague**: «улучшить код» → **no** (action items должны быть конкретные).
- **No follow-up**: action items без assignee → **no** (deadline, owner).

**Follow-up:**
- «А как автоматизировать?» → **incident.io**, **Jira** (auto-create action items).
- «А как measure improvement?» → **MTTR** (Mean Time To Resolve), **MTTD** (Mean Time To Detect), **incident frequency**.

### 23. Как диагностировать problem с latency (end-to-end)

**Симптомы:**
- p99 > 5 сек (SLA: < 1 сек)
- p50 ок, но p99 высокий (tail latency)

**Диагностика (end-to-end):**
```
Client → CDN → LB → API → DB / External API
```

**1. Client → CDN:**
- **Network**: `ping`, `traceroute` (latency, packet loss).
- **CDN**: cache hit rate (если miss → origin).

**2. CDN → LB:**
- **Network**: latency (geo distance).
- **LB**: health check (если pod не ready → retry).

**3. LB → API:**
- **API**: latency (JFR, async-profiler).
- **Thread pool**: если waiting → pool исчерпан.

**4. API → DB:**
- **Query**: EXPLAIN (slow query).
- **Connection pool**: HikariCP (waiting, timeout).
- **DB**: CPU, I/O, lock contention.

**5. API → External API:**
- **Network**: latency (external).
- **Retry**: если timeout → retry (exponential backoff).

**Инструменты:**
- **Tracing** (OpenTelemetry): `trace_id` через все сервисы → где bottleneck.
- **Metrics** (Prometheus): latency per span (p50, p99).
- **Logs**: `trace_id` → correlation.

**Решение (по bottleneck):**
1. **Network**: CDN (ближе), compression (gzip).
2. **API**: optimize (cache, async, batch).
3. **DB**: index, query optimization, connection pool.
4. **External API**: timeout, retry, async.

**Мониторинг:**
```promql
# Latency per span (tracing):
# Jaeger / Tempo: span duration
# Prometheus: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

**Follow-up:**
- «А как воспроизвести?» → **load test** (Gatling: 1000 users), замерить p99.
- «А как optimize tail?» → **hedged requests** (2 запроса, взять первый), **GC** (ZGC), **lock contention** (async).

### 24. Как использовать strace и perf для диагностики Java

**strace** (trace system calls):
```bash
# File I/O:
strace -p <pid> -e trace=file -o strace.txt
# Если много open/read/write → optimization (batch, cache)

# Network I/O:
strace -p <pid> -e trace=network -o strace_net.txt
# Если много connect/recv → connection reuse

# All syscalls:
strace -p <pid> -o strace_all.txt  # огромный файл, осторожно
```

**perf** (CPU profiling, Linux):
```bash
# CPU profile (30 сек):
perf record -g -p <pid> -- sleep 30
perf report
# Топ-10 функций (CPU time)

# Flame graph:
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# Off-CPU (waiting):
perf record -e sched:sched_switch -g -p <pid> -- sleep 30
# Кто ждёт (I/O, lock)
```

**Когда strace/perf:**
- **JFR / async-profiler не хватает** (native code, syscall).
- **Disk I/O**: strace (file syscalls).
- **Network I/O**: strace (network syscalls).
- **CPU bottleneck**: perf (native + Java).

**Ограничения:**
- **Overhead**: strace (10-20%), perf (< 1%).
- **Production**: осторожно (overhead, disk для strace output).
- **Docker**: нужно `--cap-add SYS_PTRACE` (для strace/perf).

**Follow-up:**
- «А как в Kubernetes?» → `kubectl exec <pod> -- strace -p 1 ...` (PID = 1, если no init).
- «А как automate?» → **cron** (если CPU high: strace + perf, отправить на S3).

### 25. Как диагностировать problem с virtual threads (Java 21)

**Симптомы:**
- Virtual threads не масштабируются (no gain от VT).
- **Pinning**: carrier thread заблокирован (synchronized).
- **Latency** не улучшился (I/O bound).

**Диагностика:**
```bash
# 1. Virtual thread metrics (JFR):
jcmd <pid> JFR.start duration=30s filename=vt.jfr
# JMC: Virtual Threads tab
# - Count: сколько VT создано
# - Parked: сколько VT в ожидании
# - Pinned: сколько VT pinned (проблема!)

# 2. Pinning detection:
-XX:+EnableMonitorInflation  # warn если synchronized
# Или:
-XX:+ShowCodeDetailsInExceptionMessages
# Stack trace покажет "pinned"

# 3. Thread dump:
jstack <pid>
# Если carrier thread: "pinned by virtual thread"
```

**Причины pinning:**
1. **Synchronized** (в VT): carrier thread заблокирован.
   ```java
   // Плохо:
   synchronized (lock) {
       blockingIO();  // carrier pinned
   }
   // Хорошо:
   ReentrantLock lock = new ReentrantLock();
   lock.lock();
   try {
       blockingIO();  // VT unpinned (lock released)
   } finally {
       lock.unlock();
   }
   ```
2. **Native code** (JNI): carrier pinned.
   ```java
   // Плохо:
   nativeMethod();  // blocking, pinned
   // Хорошо:
   // Обернуть в platform thread, или async
   ```

**Решение:**
1. **Replace synchronized** → `ReentrantLock` (или lock-free).
2. **Avoid native blocking** → platform thread (если нужно).
3. **Monitor**: JFR (Virtual Threads), alert если pinned > 10.

**Мониторинг:**
```promql
# Virtual threads (JMX / Micrometer):
jvm_virtual_threads_count
# Если pinned > 10 → P2
```

**Follow-up:**
- «А когда VT не помогают?» → **CPU-bound** (нет выигрыша), **synchronized hot path** (pinning).
- «А как test VT?» → **load test** (Gatling), сравнить platform vs virtual (latency, throughput).
