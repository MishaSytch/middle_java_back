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

---
