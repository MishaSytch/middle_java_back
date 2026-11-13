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
