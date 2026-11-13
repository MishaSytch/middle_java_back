# Date/Time API и файловый ввод-вывод

> Что проверяют: java.time вместо Date/Calendar, Period против Duration, try-with-resources, потоковую обработку файлов.

<a id="r25-t1"></a>
**1. [Классика] Возраст в полных годах**
```java
static int age(LocalDate birth, LocalDate today) {
    return Period.between(birth, today).getYears();
}
// нюанс 29 февраля: Period.between корректно вернёт год и в невисокосном году (28.02+1 день = 01.03)
```
Фоллоу-ап: «сколько дней до следующего дня рождения» — `ChronoUnit.DAYS.between(today, nextBirthday)`; почему НЕ `(today.toEpochDay() - birth.toEpochDay()) / 365` (високосные).

<a id="r25-t2"></a>
**2. [Классика] Прибавить N рабочих дней**
```java
static LocalDate plusBusinessDays(LocalDate date, int days) {
    LocalDate res = date;
    int added = 0;
    while (added < days) {
        res = res.plusDays(1);
        DayOfWeek dow = res.getDayOfWeek();
        if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) added++;
    }
    return res;
}
```
Ограничение озвучить: праздники не учтены — нужен календарь праздников (список дат или ProductionCalendar-зависимость). Period — календарные единицы, Duration — точные секунды: это различие спрашивают почти всегда.

<a id="r25-t3"></a>
**3. [Классика] Частота слов в файле**
```java
try (Stream<String> lines = Files.lines(Path.of("book.txt"))) {   // Stream нужно ЗАКРЫВАТЬ — дескриптор файла!
    Map<String, Long> freq = lines
        .flatMap(l -> Arrays.stream(l.split("\\W+")))
        .filter(w -> !w.isEmpty())
        .collect(Collectors.groupingBy(String::toLowerCase, Collectors.counting()));
    System.out.println(freq.getOrDefault("the", 0L));
}
```
Три обязательных пункта: try-with-resources над stream от Files (иначе утечка дескриптора), Files.lines — лениво и не грузит файл в память, большие файлы — ок; кодировка: `Files.lines(path, StandardCharsets.UTF_8)`.

<a id="r25-t4"></a>
**4. [Классика|hard] Парсер CSV-строки с кавычками**
`book, second,author,"quoted, comma"` → поля не рвать по запятой внутри кавычек.
```java
static List<String> parseCsvLine(String line) {
    List<String> fields = new ArrayList<>();
    StringBuilder cur = new StringBuilder();
    boolean inQuotes = false;
    for (int i = 0; i < line.length(); i++) {
        char c = line.charAt(i);
        if (c == '"') {
            inQuotes = !inQuotes;             // кавычки в поле не сохраняем (упрощение)
        } else if (c == ',' && !inQuotes) {
            fields.add(cur.toString());
            cur.setLength(0);
        } else {
            cur.append(c);
        }
    }
    fields.add(cur.toString());               // последнее поле
    return fields;
}
```
Состояние `inQuotes` меняет смысл запятой — классический конечный автомат. Обсудить ограничения: удвоенные кавычки `""` внутри поля, переводы строк внутри кавычек — для полного CSV есть библиотека (opencsv, Jackson CSV); на интервью важен сам автомат.

<a id="r25-t5"></a>
**5. [Классика] Форматирование даты: локаль и паттерн**
`2026-11-13T14:30:00Z` → «13 ноября 2026, 16:30» (Europe/Moscow).
```java
static String format(Instant instant) {
    ZonedDateTime dt = instant.atZone(ZoneId.of("Europe/Moscow"));
    return dt.format(DateTimeFormatter.ofPattern("d MMMM yyyy, HH:mm", Locale.RUSSIAN));
}
```
Обсудить: `DateTimeFormatter` неизменяем и thread-safe → static final; `LocalDate`/`LocalTime` vs `Instant`/`ZonedDateTime` — почему Instant для хранения, ZonedDateTime для отображения; `DateTimeFormatterBuilder` для сложных форматов.

<a id="r25-t6"></a>
**6. [Классика] Сравнение дат: Duration vs Period**
Сколько секунд между `2026-01-01T00:00` и `2026-12-31T23:59:59`? Сколько лет между `1990-06-15` и `2026-11-13`?
```java
// Точное время — Duration (секунды/нано):
Duration d = Duration.between(
    LocalDateTime.of(2026, 1, 1, 0, 0),
    LocalDateTime.of(2026, 12, 31, 23, 59, 59));
d.getSeconds(); // 31 622 399

// Календарные единицы — Period (годы/месяцы/дни):
Period p = Period.between(LocalDate.of(1990, 6, 15), LocalDate.of(2026, 11, 13));
p.getYears(); // 36
p.getMonths(); // 5
p.getDays(); // 29
```
Ключевое различие: `Duration` — фиксированное количество секунд, `Period` — календарные единицы (месяцы разной длины). Складывать Period с LocalDate: `date.plus(period)`. Складывать Duration с LocalDateTime: `dt.plus(duration)`.

<a id="r25-t7"></a>
**7. [hard] Чтение большого файла чанками (без OOM)**
Файл 2 ГБ, память 512 МБ. Прочитать и посчитать сумму чисел (по одному на строку).
```java
static long sum(Path path) throws IOException {
    long total = 0;
    try (BufferedReader br = Files.newBufferedReader(path)) {
        String line;
        while ((line = br.readLine()) != null) {
            total += Long.parseLong(line.trim());
        }
    }
    return total;
}
// Альтернатива — Files.newByteChannel + ByteBuffer (chunk 8KB):
try (FileChannel ch = FileChannel.open(path, StandardOpenOption.READ)) {
    ByteBuffer buf = ByteBuffer.allocateDirect(8192);
    long total = 0;
    while (ch.read(buf) != -1) {
        buf.flip();
        // парсинг чисел из буфера (учитывать, что число может обрезаться по границе чанка)
        buf.clear();
    }
}
```
Обсудить: `BufferedReader` — строки, `FileChannel` — байты (быстрее, без String аллокаций); `allocateDirect` — off-heap, не давит на GC; `MMap` для очень больших файлов (но OOM при недостатке виртуальной памяти).

---
