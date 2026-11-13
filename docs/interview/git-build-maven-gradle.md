# Git и сборка (Maven / Gradle)


### 1. Что такое Git и чем он отличается от централизованных VCS

**Git** — распределённая система контроля версий: у каждого разработчика **полная копия репозитория** с историей. Это главное отличие от централизованных систем (SVN, CVS), где история живёт на сервере, а у разработчика — рабочая копия.

Следствия распределённости:
- Почти все операции (commit, branch, diff, log) выполняются **локально** — мгновенно и без сети.
- Можно коммитить офлайн, история не теряется при падении сервера.
-push/pull — только синхронизация между копиями.

Git хранит не дельты, а **снимки (snapshots)** всего дерева файлов; каждый коммит — неизменяемый объект с хэшем SHA-1/SHA-256, ссылками на родителя и на снимок. Отсюда целостность истории: подменить коммит незаметно невозможно.

```bash
git init                          # новый репозиторий
git clone git@github.com:org/repo.git
git add file.java && git commit -m "feat: add order validation"
git log --oneline --graph --all   # красивая история
```

### 2. Какие области есть в Git и что делает команда add

Три основные области:

1. **Working Directory** — текущие файлы на диске, с которыми вы работаете.
2. **Staging Area (Index)** — «сцена»: подготовленный набор изменений для следующего коммита.
3. **Repository (.git)** — локальная история коммитов.

`git add` переносит изменения из рабочей директории в staging, `git commit` фиксирует staging-область в историю. `git status` показывает статус файлов: *untracked* (новый, не в Git), *modified* (изменён, не в staging), *staged* (готов к коммиту).

```bash
git status                     # что изменено и что в сцене
git add src/Main.java          # один файл в staging
git add -p                     # интерактивно, по кускам (hunk) — лучший способ
git commit -m "msg"            # фиксация staged-изменений
git commit -am "msg"           # add изменённых tracked-файлов + commit (без новых)
git restore --staged file.java # убрать файл из staging (сам файл не трогаем)
git restore file.java          # отменить незакоммиченные изменения файла (!)
```

Зачем staging: позволяет собрать **атомарный коммит** из разрозненных правок — например, закоммитить отдельно фикс бага и отдельно рефакторинг, хотя делались вперемешку.

### 3. В чём разница между merge и rebase

Обе команды интегрируют изменения одной ветки в другую, но по-разному:

- **merge** создаёт **merge-коммит** с двумя родителями, сохраняя реальную историю ветвления. Граф истории ветвистый.
- **rebase** переписывает commits: берёт ваши коммиты и «переигрывает» их поверх целевой ветки, создавая новые коммиты с новыми хэшами. История становится линейной.

```bash
# merge: безопасно, история честная, но с коммитами "Merge branch..."
git checkout feature && git merge main

# rebase: линейная история
git checkout feature && git rebase main
```

**Золотое правило:** не делать rebase **опубликованных** веток, над которыми работают другие — переписывание хэшей заставит коллег разбираться с конфликтами и потерянными ссылками. Практика больших команд: rebase своей feature-ветки на свежий `main` перед PR (аккуратная история), merge или squash-merge PR при влитии. `git pull --rebase` вместо простого pull не плодит merge-коммиты при синхронизации с удалённой веткой.

### 4. Что такое fast-forward merge

**Fast-forward** — вариант merge, при котором Git просто передвигает указатель ветки вперёд, потому что целевая ветка — прямой предок merges-ой (новых коммитов в ней не было с момента ветвления). Merge-коммит при этом не создаётся.

```bash
# main: A---B        feature: A---B---C---D (ответвилась от B)
git checkout main && git merge feature
# fast-forward: main = A---B---C---D, без merge-коммита

git merge --no-ff feature   # принудительно создать merge-коммит
```

`--no-ff` полезен, когда влитие фичи должно остаться видимым событием в истории (коммит-«контейнер» всей фичи, удобно откатывать целиком `git revert -m 1`). fast-forward даёт чистую линейную историю, но теряет информацию о том, что работа шла в отдельной ветке. В GitHub/GitLab настройка «merge commit / squash / rebase» на PR как раз управляет этим поведением.

### 5. Как разрешить конфликт слияния

Конфликт возникает, когда одна и та же область файла изменена в обеих ветках. Git помечает конфликтные участки маркерами:

```
<<<<<<< HEAD
int timeout = 30;        // ваша версия
=======
int timeout = 60;        // входящая версия
>>>>>>> feature-retry
```

Процесс разрешения:
1. `git merge feature` (или `git rebase main`) — Git сообщает о конфликтах.
2. `git status` — список конфликтных файлов.
3. Открыть файл, выбрать правильный вариант (обе стороны, одна, новый код), удалить маркеры.
4. `git add file` — пометить разрешённым.
5. `git commit` (merge) или `git rebase --continue` (rebase). Прервать: `git merge --abort` / `git rebase --abort`.

```bash
git checkout --ours file.txt    # взять нашу версию целиком
git checkout --theirs file.txt  # взять их версию целиком
git diff --name-only --diff-filter=U   # только конфликтные файлы
```

При rebase стороны «наоборот»: HEAD — это ветка, на которую ребейзим, поэтому `--ours` = целевая ветка. Хорошая профилактика конфликтов: маленькие частые PR, синхронизация feature-ветки с main, договорённости о структуре кода.

### 6. В чём разница между git reset (--soft, --mixed, --hard) и git revert

**`git reset`** передвигает указатель ветки на другой коммит, меняя локальную историю, — с тремя уровнями:

| Команда                            | HEAD | Staging   | Working dir    | Применение                          |
|------------------------------------|------|-----------|----------------|-------------------------------------|
| `reset --soft <commit>`            | ✔    | остаётся  | остаётся       | «пересобрать» последний коммит      |
| `reset --mixed <commit>` (default) | ✔    | очищается | остаётся       | убрать изменения из сцены           |
| `reset --hard <commit>`            | ✔    | очищается | **затирается** | выбросить всё до указанного коммита |

**`git revert`** создаёт **новый коммит**, отменяющий изменения указанного, — история не переписывается. Единственный безопасный способ отмены **опубликованных** коммитов.

```bash
git reset --soft HEAD~1        # забрать последний коммит обратно в staging
git reset --hard origin/main   # привести рабочую копию к состоянию удалённой ветки
git revert abc1234             # отменить чужой коммит новым коммитом
git revert -m 1 <merge>        # отменить merge-коммит (1 = "оставляем main-сторону")
```

Правило: reset — для локальных ошибок до push; revert — для общей истории после push. Опасный спасательный инструмент для «затёртых» коммитов — `git reflog` (журнал передвижений HEAD, из которого можно восстановить почти всё).

### 7. Что такое HEAD и detached HEAD

**HEAD** — указатель на текущий коммит (обычно через ветку): `HEAD → main → abc123`. Все новые коммиты добавляются туда, куда смотрит HEAD. Символические ссылки: `HEAD~1` — родитель, `HEAD~2` — два коммита назад, `HEAD@{2}` — где HEAD был два перемещения назад (reflog).

**Detached HEAD** — состояние, когда HEAD смотрит **напрямую на коммит**, а не на ветку (после `git checkout <hash>`, `checkout <tag>`). Коммиты в этом состоянии не принадлежат ни одной ветке и будут потеряны при переключении (сборщик мусора их удалит).

```bash
git checkout v2.1.0            # смотрим на тег — detached HEAD
# ...эксперименты...
git switch -c fix-from-tag     # сохранить работу: новая ветка отсюда
git switch main                # вернуться на ветку
```

Это не ошибка — легитимный способ посмотреть старую версию кода или снять отладку; опасность только в том, чтобы коммитить, не создав ветку.

### 8. Какие стратегии ветвления существуют (Git Flow, GitHub Flow, trunk-based)

- **Git Flow** — классика для релизных продуктов с версиями: `main` (прод) + `develop` (интеграция) + `feature/*` (задачи) + `release/*` (подготовка релиза) + `hotfix/*` (срочные фиксы прода). Мощно, но много церемоний; подservice с длительной поддержкой версий.
- **GitHub Flow** — упрощённо: `main` всегда рабочая, вся работа в коротких feature-ветках через PR. Подходит для continuous deployment.
- **Trunk-Based Development** — все коммитят в `main` (trunk) мелкими частями; долгие фичи скрываются за **feature flags**. Требует зрелых тестов и CI, зато нет «адских» мержей долгоживущих веток. Стандарт для команд с ежедневными деплоями.

```bash
git switch -c feature/order-validation main   # новая ветка от main
# ... работа, rebase на main перед PR ...
git push -u origin feature/order-validation   # первый push ветки
```

На собеседовании полезно уметь объяснить выбор: чем быстрее релизный цикл, тем ближе к trunk-based; чем длиннее поддержка мажоров — тем нужнее Git Flow-подобные схемы.

### 9. Что такое .gitignore и что делать, если файл уже закоммичен

**`.gitignore`** — файл с шаблонами путей, которые Git не должен трекать (сборка, IDE-конфиги, секреты, зависимости). Правила: `/build` — только в корне, `build/` — где угодно, `*.log` — по маске, `!keep.log` — отрицание (не игнорировать). Игнорируются только **untracked** файлы: уже закоммиченные продолжают отслеживаться.

```gitignore
target/          # Maven-сборка
build/
.idea/           # IntelliJ
*.iml
.env             # секреты!
.DS_Store
```

Если секрет или мусор уже в истории:
```bash
git rm --cached .env          # убрать из индекса, оставить на диске
git commit -m "chore: remove .env"
# Полная вычистка из истории (опасно, требует force-push и координации):
git filter-repo --path .env --invert-paths
```

Важно: если в репозиторий попал реальный секрет, одной вычистки мало — ключ считается скомпрометированным, его нужно **ротировать**. Для защиты от случайных коммитов секретов используют pre-commit-хуки (например, gitleaks/trufflehog).

### 10. Что такое Maven и как устроен его жизненный цикл

**Maven** — стандартный инструмент сборки Java-проектов: декларативное описание в `pom.xml`, соглашения над конфигурацией (каталоги `src/main/java`, `src/test/resources` предопределены), управление зависимостями из центрального репозитория.

Жизненный цикл — упорядоченный набор **фаз**; вызов фазы выполняет **все предыдущие**. Три основных цикла:

- **default**: `validate → compile → test → package → verify → install → deploy`
  - `compile` — компиляция `src/main/java` в `target/classes`;
  - `test` — прогон юнит-тестов;
  - `package` — JAR/WAR в `target/`;
  - `verify` — интеграционные проверки (Failsafe, JaCoCo check);
  - `install` — положить артефакт в **локальный** репозиторий (`~/.m2`);
  - `deploy` — опубликовать в **удалённый** репозиторий (Nexus/Artifactory).
- **clean** — удаление `target/`.
- **site** — генерация документации.

```bash
mvn clean package       # очистить, скомпилировать, протестировать, собрать JAR
mvn test -DskipITs      # только юнит-тесты
mvn dependency:tree     # дерево зависимостей (диагностика конфликтов)
```

Фазы связаны с **целями плагинов** (`compiler:compile`, `surefire:test`); Maven запускает нужные цели на нужных фазах — именно поэтому достаточно «`mvn package`», всё остальное подтянется по конфигурации.

### 11. Из чего состоит pom.xml и какие scope у зависимостей

**Координаты** (GAV): `groupId` (организация), `artifactId` (имя), `version`; плюс `packaging` (jar/war/pom). Ключевые секции:

```xml
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>order-service</artifactId>
  <version>1.2.0</version>
  <properties>
    <java.version>21</java.version>
    <spring-boot.version>3.3.0</spring-boot.version>
  </properties>
  <dependencyManagement>   <!-- версии, но не сами зависимости -->
    <dependencies>
      <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-dependencies</artifactId>
        <version>${spring-boot.version}</version>
        <type>pom</type> <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>
  <dependencies>           <!-- сами зависимости, версии берутся из BOM -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
  </dependencies>
</project>
```

**Scope** зависимостей:
- `compile` (по умолчанию) — везде: компиляция, тесты, рантайм;
- `provided` — нужен на компиляции, дают в рантайме (Lombok, servlet-api);
- `runtime` — не нужен на компиляции, нужен при выполнении (драйверы JDBC);
- `test` — только тесты (JUnit, Mockito);
- `import` — импорт BOM в `dependencyManagement`.

Свойства/профили (`<profiles>`) позволяют менять сборку под окружение (dev/prod), плагины (`spring-boot-maven-plugin`) — добавлять сборку исполняемого JAR.

### 12. Чем Gradle отличается от Maven

**Gradle** — сборщик следующего поколения: конфигурация кодом (`build.gradle.kts` на Kotlin DSL), инкрементальность, кэширование, гибкость.

| Критерий     | Maven                                  | Gradle                                      |
|--------------|----------------------------------------|---------------------------------------------|
| Конфигурация | XML, декларативно                      | Kotlin/Groovy DSL                           |
| Скорость     | Медленнее                              | Инкрементальная сборка, build cache, daemon |
| Гибкость     | Плагины, ограниченная точка расширения | Любая логика в build-скрипте                |
| Порог входа  | Ниже, «все знают»                      | Выше (DSL + Kotlin/Groovy)                  |
| Экосистема   | Огромная, legacy-стандарт              | Android-стандарт, растёт в backend          |

```kotlin
// build.gradle.kts
plugins {
    java
    id("org.springframework.boot") version "3.3.0"
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    runtimeOnly("org.postgresql:postgresql")
}

tasks.test {
    useJUnitPlatform()
}
```

Выбор: Maven — если команда знает Maven, проект классический, важна предсказуемость; Gradle — большой монорепозиторий, Android, потребность в кэшировании и быстрой сборке. По возможностям оба закрывают 95% сценариев одинаково.

### 13. Как решаются конфликты версий транзитивных зависимостей

Подключая библиотеку, вы получаете и её зависимости (**транзитивные**). Когда две ветки дерева тянут один артефакт разных версий, возникает **конфликт версий** — классический источник загадочных `NoSuchMethodError` в рантайме.

Стратегии Maven:
- **«Ближайший к корню выигрывает» (nearest-wins)**: побеждает версия с минимальной глубиной дерева; при равной глубине — объявленная раньше. 
- **`<dependencyManagement>`** — принудительно зафиксировать версию для всего проекта, независимо от транзитивности.
- **`<exclusions>`** — исключить конкретную транзитивную зависимость у конкретного артефакта.
- **BOM (Bill of Materials)** — платформенный pom с согласованными версиями (Spring Boot dependencies, Jackson BOM): один источник правды для десятков библиотек.

```bash
mvn dependency:tree -Dverbose           # увидеть конфликты прямо в дереве
mvn dependency:analyze                  # неиспользуемые и объявленные без нужды
```

```xml
<dependency>
  <groupId>com.example</groupId>
  <artifactId>legacy-client</artifactId>
  <exclusions>
    <exclusion>       <!-- убираем старый jackson, подтягиваемый legacy -->
      <groupId>com.fasterxml.jackson.core</groupId>
      <artifactId>jackson-databind</artifactId>
    </exclusion>
  </exclusions>
</dependency>
```

Практика: версии Spring-стека держать только через BOM, зависимости с уязвимостями (OWASP dependency-check, `mvn versions:display-dependency-updates`) регулярно обновлять.

### 14. Что такое CI/CD и из чего состоит пайплайн

**CI (Continuous Integration)** — каждая ветка автоматически собирается и тестируется при пуше; сломанный main — событие, которое чинят немедленно. **CD (Continuous Delivery/Deployment)** — артефакт после CI автоматически готов к деплою (Delivery: до кнопки «выкатить», Deployment: деплой полностью автоматический).

Типовой пайплайн Java-сервиса:

1. **Build** — `mvn clean package` (или Gradle), кэш зависимостей.
2. **Unit tests** — прогон юнит-тестов, отчёты, JaCoCo-гейт по покрытию.
3. **Static analysis** — Checkstyle/SpotBugs/SonarQube (качество и уязвимости).
4. **Integration tests** — Testcontainers против реальных БД/Kafka.
5. **Build image** — Docker-образ, тег `git-sha` + версия.
6. **Security scan** — Trivy/Snyk по образу и зависимостям.
7. **Publish** — push артефакта/образа в registry.
8. **Deploy** — стенд → staging → prod (через GitLab CI/GitHub Actions/Jenkins).

```yaml
# .github/workflows/ci.yml (фрагмент)
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin', cache: 'maven' }
      - run: mvn -B verify                    # compile + unit + IT + verify-гейты
      - run: docker build -t orders:${{ github.sha }} .
```

Ключевые понятия для собеса: артефакт собирается **один раз** и проходит среды без пересборки («build once, deploy many»); параметры окружения — через конфиг, а не пересборку; тег образа = хэш коммита гарантирует воспроизводимость.

