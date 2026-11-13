# Глава 2. Окружение, сборка и первый работающий проект

> **Уровень:** zero → junior
> **Время:** 2–3 часа
> **Цель:** к концу главы у вас запущенное приложение, два рабочих билда (Maven и Gradle), горячая перезагрузка, отладчик и первый тест.

## 2.1. JDK

Ставим **Java 25 LTS** (рекомендация Spring Framework 7). Держим рядом Java 21 — под «прод-минимум».

```bash
# Linux/macOS: SDKMAN
curl -s "https://get.sdkman.io" | bash
sdk install java 25-tem          # Temurin 25
sdk install java 21-tem
sdk use java 25-tem
java -version                    # openjdk version "25" ...

# Windows: winget
winget install EclipseAdoptium.Temurin.25.JDK
```

Проверьте три вещи: `java -version`, `javac -version`, `echo $JAVA_HOME`. IDE должна использовать **тот же** JDK, что и сборка, иначе получите классику «в IDE работает, в CI — нет».

> **Грабли:** `UnsupportedClassVersionError: ... class file version 69.0` — код собран более новым JDK, чем запускается. Лечится `--release` (Maven: `<maven.compiler.release>`) и явным toolchain в Gradle.

## 2.2. Maven и Gradle: что выбрать

| | Maven | Gradle (Kotlin DSL) |
|---|---|---|
| Модель | декларативный XML, жёсткий lifecycle | граф задач, инкрементальность, кэш |
| Порог входа | ниже | выше |
| Скорость повторных сборок | средняя | высокая (build cache, configuration cache) |
| Типично в enterprise | ✅ доминирует | ✅ в продуктовых командах |
| Плагины Boot | `spring-boot-maven-plugin` | `org.springframework.boot` |

**В книге оба.** Основной листинг — Maven, рядом — Gradle KTS. Полные параллельные конфиги и шпаргалка команд — [Приложение C](../appendix/C-maven-gradle.md).

Всегда используйте **wrapper** (`mvnw`/`gradlew`): версия сборки фиксируется в репозитории.

```bash
mvn wrapper:wrapper -Dmaven=3.9.11        # Maven Wrapper
gradle wrapper --gradle-version 9.1.0     # Gradle Wrapper (Boot 4 поддерживает Gradle 9 и 8.14+)
```

> **[4.x]** Spring Boot 4 поддерживает **Gradle 9** (и 8.14+). **[3.5]** — Gradle 7.6.4+/8.4+ (9 не поддерживается). Это первая причина «почему у меня не собирается проект из книги на старой версии».

## 2.3. Генерируем проект

Через UI: <https://start.spring.io>. Через API:

```bash
# Трек 4.x (актуальный)
curl -s https://start.spring.io/starter.zip \
  -d type=maven-project -d language=java -d bootVersion=4.1.2 \
  -d javaVersion=25 -d groupId=dev.book -d artifactId=taskflow \
  -d name=taskflow -d packageName=dev.book.taskflow \
  -d dependencies=webmvc,data-jpa,validation,security,actuator,flyway,postgresql,devtools \
  -o taskflow.zip && unzip taskflow.zip -d taskflow

# Трек 3.5.x (мейнстрим)
curl -s https://start.spring.io/starter.zip \
  -d type=gradle-project-kotlin -d language=java -d bootVersion=3.5.14 \
  -d javaVersion=21 -d groupId=dev.book -d artifactId=taskflow35 \
  -d dependencies=web,data-jpa,validation,security,actuator,flyway,postgresql,devtools \
  -o taskflow35.zip
```

> **Обратите внимание на `webmvc` vs `web`.** **[4.x]** стартер называется `spring-boot-starter-webmvc`; старое имя `spring-boot-starter-web` оставлено как **deprecated-алиас**. **[3.5]** — только `spring-boot-starter-web`. Это часть большой модуляризации Boot 4 (глава 9 и глава 29).

## 2.4. Полный `pom.xml` — трек 4.x

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>4.1.2</version>
    <relativePath/>
  </parent>

  <groupId>dev.book</groupId>
  <artifactId>taskflow</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>taskflow</name>

  <properties>
    <java.version>25</java.version>          <!-- parent транслирует в maven.compiler.release -->
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>

  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-flyway</artifactId></dependency>
    <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
    <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><scope>runtime</scope></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-devtools</artifactId><scope>runtime</scope><optional>true</optional></dependency>

    <!-- Тесты: в 4.x указываем стартеры тестируемых технологий, spring-boot-starter-test придёт транзитивно -->
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-webmvc-test</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa-test</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security-test</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-testcontainers</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.testcontainers</groupId><artifactId>testcontainers-postgresql</artifactId><scope>test</scope></dependency>
    <dependency><groupId>org.testcontainers</groupId><artifactId>testcontainers-junit-jupiter</artifactId><scope>test</scope></dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude><groupId>org.springframework.boot</groupId><artifactId>spring-boot-devtools</artifactId></exclude>
          </excludes>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

**Что здесь важно понять (а не скопировать):**
* `spring-boot-starter-parent` даёт dependency management (BOM), кодировку, `--release`, разумные конфиги плагинов и `<delimiter>` для ресурсов. Версии зависимостей **не пишем** — ими управляет BOM.
* Альтернатива parent — импорт BOM (`dependencyManagement` + `spring-boot-dependencies` с `<scope>import</scope>`). Нужна, когда у вас корпоративный parent.
* **[4.x]** `spring-boot-starter-flyway` — **новый обязательный стартер**. В 3.5 хватало зависимости `org.flywaydb:flyway-core`.
* **[4.x]** Testcontainers 2.0: артефакты переименованы в `testcontainers-postgresql`, `testcontainers-junit-jupiter` (в 1.x было `postgresql`, `junit-jupiter`).
* **[4.x]** Тестовые стартеры по технологиям. Если оставить только `spring-boot-starter-test`, то `@WithMockUser` и MockMvc-инфраструктура могут не подняться.

## 2.5. Тот же проект на Gradle KTS — трек 4.x

`settings.gradle.kts`:
```kotlin
rootProject.name = "taskflow"
```

`build.gradle.kts`:
```kotlin
plugins {
    java
    id("org.springframework.boot") version "4.1.2"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "dev.book"
version = "0.0.1-SNAPSHOT"

java {
    toolchain { languageVersion = JavaLanguageVersion.of(25) }
}

repositories { mavenCentral() }

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")
    developmentOnly("org.springframework.boot:spring-boot-devtools")

    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.springframework.boot:spring-boot-starter-data-jpa-test")
    testImplementation("org.springframework.boot:spring-boot-starter-security-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> { useJUnitPlatform() }
```

> **Нюанс Gradle + Boot 4:** плагин `io.spring.dependency-management` не обязателен — можно использовать нативный `implementation(platform("org.springframework.boot:spring-boot-dependencies:4.1.2"))`. Нативный `platform()` честнее ведёт себя при конфликтах версий и лучше дружит с configuration cache.

## 2.6. Трек 3.5.x: минимальный диф

```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>3.5.14</version>   <!-- подставьте актуальный патч 3.5.x -->
</parent>
<properties><java.version>21</java.version></properties>
```
```xml
<!-- вместо webmvc / *-test / flyway-стартера -->
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
<dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId></dependency>
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
<dependency><groupId>org.springframework.security</groupId><artifactId>spring-security-test</artifactId><scope>test</scope></dependency>
<dependency><groupId>org.testcontainers</groupId><artifactId>postgresql</artifactId><scope>test</scope></dependency>
```

Держите этот диф под рукой: он объясняет 80 % расхождений между примерами из интернета и вашим проектом.

## 2.7. Структура проекта и первый код

```text
taskflow/
├── pom.xml / build.gradle.kts
├── src/main/java/dev/book/taskflow/
│   ├── TaskflowApplication.java
│   ├── config/            # @Configuration, свойства
│   ├── task/              # вертикальный срез: api + domain + persistence
│   │   ├── TaskController.java
│   │   ├── TaskService.java
│   │   ├── Task.java
│   │   └── TaskRepository.java
│   └── shared/            # ошибки, утилиты, общие абстракции
├── src/main/resources/
│   ├── application.yml
│   ├── application-local.yml
│   └── db/migration/V1__init.sql
└── src/test/java/...
```

```java
package dev.book.taskflow;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TaskflowApplication {
    public static void main(String[] args) {
        SpringApplication.run(TaskflowApplication.class, args);
    }
}
```

```java
package dev.book.taskflow.task;

import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/tasks")
class TaskController {

    @GetMapping("/ping")
    Map<String, Object> ping() {
        return Map.of("status", "ok", "time", Instant.now());
    }
}
```

> **Почему `@SpringBootApplication` должен быть в корне пакета:** он включает `@ComponentScan` **от своего пакета вниз**. Положите его в `dev.book.taskflow.config` — и `dev.book.taskflow.task` не будет просканирован. Это ошибка №1 у новичков.

## 2.8. Запуск

```bash
./mvnw spring-boot:run                       # Maven, dev-режим
./gradlew bootRun                            # Gradle, dev-режим

./mvnw -DskipTests clean package             # собрать uber-jar
java -jar target/taskflow-0.0.1-SNAPSHOT.jar

java -Dspring.profiles.active=local -jar app.jar
java -jar app.jar --server.port=8081         # аргументы командной строки сильнее конфигов

./mvnw spring-boot:build-image               # OCI-образ без Dockerfile (Cloud Native Buildpacks)
./gradlew bootBuildImage
```

Полезные флаги JVM для локальной разработки:
```bash
java -XX:TieredStopAtLevel=1 -Xshare:auto -jar app.jar   # быстрее старт, медленнее пик
```

Отладка:
```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar app.jar
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005"
```

## 2.9. DevTools: как ускорить цикл разработки

`spring-boot-devtools` даёт:
* **restart** — при изменении classpath перезапускается только «ваш» загрузчик классов (библиотеки живут в base-загрузчике). Это не hot-swap, а быстрый рестарт контекста;
* **свойства по умолчанию для разработки** (например, отключённые кэши шаблонов);
* **LiveReload-сервер** — **[4.x] по умолчанию выключен**, включается `spring.devtools.livereload.enabled=true` (в 3.5 был включён);
* удалённый рестарт (крайне редко нужен, требует явного включения и секрета).

Тонкая настройка:
```yaml
spring:
  devtools:
    restart:
      enabled: true
      additional-paths: src/main/java
      exclude: static/**,public/**,templates/**
      poll-interval: 2s
      quiet-period: 1s
    livereload:
      enabled: false
```

> **Важно:** DevTools автоматически отключается в «полностью упакованном» jar (`java -jar`) — он считается прод-запуском. И его исключают из uber-jar (см. `<excludes>` в pom).

Альтернативы/дополнения: JRebel (платный), IDEA «HotSwap» (ограничен телом метода), `spring-boot-docker-compose` и `spring-boot-testcontainers` для поднятия инфраструктуры на dev-старте (глава 23).

## 2.10. Что смотреть в логах старта

```text
Starting TaskflowApplication using Java 25 with PID 1234
The following 1 profile is active: "local"
Tomcat initialized with port 8080 (http)
Root WebApplicationContext: initialization completed in 1102 ms
HikariPool-1 - Start completed.
Exposing 13 endpoints beneath base path '/actuator'
Tomcat started on port 8080 (http) with context path '/'
Started TaskflowApplication in 2.418 seconds
```

Читайте построчно: профиль, порт, пул, время старта. Полезные приёмы диагностики:

```bash
java -jar app.jar --debug                   # отчёт CONDITIONS EVALUATION REPORT
java -jar app.jar --trace
```
```yaml
logging.level.org.springframework.boot.autoconfigure: DEBUG
```

Первый «runner» для проверки окружения:
```java
@Bean
ApplicationRunner smoke(TaskRepository repo) {
    return args -> log.info("Задач в БД: {}", repo.count());
}
```

## 2.11. Первый тест

```java
@SpringBootTest
@AutoConfigureMockMvc                      // [4.x] обязателен: @SpringBootTest больше не даёт MockMvc сам
class TaskControllerTest {

    @Autowired MockMvc mvc;

    @Test
    void pingReturnsOk() throws Exception {
        mvc.perform(get("/api/tasks/ping"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.status").value("ok"));
    }
}
```

**[3.5]** `@SpringBootTest` + `@AutoConfigureMockMvc` тоже работает (аннотация просто была необязательной для MockMvc). Так что этот стиль — «правильный по умолчанию» для обоих треков.

Запуск: `./mvnw test` / `./gradlew test`. Отчёт: `target/surefire-reports`, `build/reports/tests/test`.

## 2.12. Типовые ошибки старта и мгновенные диагнозы

| Симптом | Причина | Лечение |
|---|---|---|
| `Web server failed to start. Port 8080 was already in use` | занят порт | `--server.port=8081`, найти процесс: `lsof -i:8080` |
| `Cannot find a @SpringBootConfiguration` в тестах | тест вне пакета приложения | положить тест в тот же/дочерний пакет или указать `@ContextConfiguration(classes=...)` |
| `Failed to configure a DataSource` | нет URL и нет embedded БД | добавить `spring.datasource.url` или драйвер H2 |
| Бин не найден (`NoSuchBeanDefinitionException`) | класс вне `@ComponentScan` / нет аннотации | проверить пакет, `@Component`, `@Bean` |
| `no main manifest attribute` | jar собран без Boot-плагина | подключить `spring-boot-maven-plugin` / плагин Boot |
| `ClassNotFoundException: javax.servlet.*` | старая библиотека на javax | Jakarta EE: `jakarta.servlet.*`, обновить зависимость |
| Приложение стартует и сразу завершается | нет web-стартера | добавить `spring-boot-starter-webmvc` (или это осознанный CLI-runner) |

## 2.13. Практика

1. Сгенерируйте два проекта: Boot 4.1.x/Maven/Java 25 и Boot 3.5.x/Gradle/Java 21. Запустите оба на разных портах.
2. Сделайте `/api/tasks/ping`, верните record вместо `Map`.
3. Включите `--debug`, найдите в отчёте, почему `DataSourceAutoConfiguration` «matched», а `MongoAutoConfiguration` — «did not match».
4. Сломайте проект специально: перенесите `TaskflowApplication` в подпакет, получите `NoSuchBeanDefinitionException`, верните обратно.
5. Настройте remote debug и поставьте breakpoint в контроллере.

## 2.14. Чек-лист

- [ ] JDK 25 и 21 стоят, IDE и сборка используют один и тот же JDK.
- [ ] Проект собирается и Maven, и Gradle (wrapper в репозитории).
- [ ] Понимаю, зачем `parent`/BOM и почему не пишу версии зависимостей руками.
- [ ] Знаю разницу имён стартеров 4.x vs 3.5 (`webmvc`/`web`, тестовые стартеры, Flyway).
- [ ] DevTools работает, LiveReload осознанно включён/выключен.
- [ ] Есть первый зелёный тест и я умею читать condition report.

---

**Назад:** [Глава 1](01-java-dlya-spring.md) · **Дальше:** [Глава 3. Экосистема, версии и BOM →](03-ekosistema-versii-bom.md)