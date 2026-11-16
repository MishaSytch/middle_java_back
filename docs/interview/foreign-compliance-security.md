# Иностранные компании: Compliance и Security (GDPR, PCI-DSS, SOC 2, DORA, PSD2)

Раздел — тематический: compliance и security-требования, которые обязательны в EU/UK-компаниях (Revolut, Wise, Monzo, Starling, Booking). В US-компаниях compliance менее строгий (SOC 2, но не GDPR), в Israel — security-фокус (zero trust, RBAC), в Singapore — local regulations (PDPA).

> Ключевое отличие от локальных: в EU/UK-финтехе compliance — **не опция**, а **обязательное требование** (GDPR, PCI-DSS, SOC 2, DORA, PSD2). Middle-разработчик должен **понимать** требования и **реализовывать** их в коде (encryption, access control, audit log).

### 1. GDPR (General Data Protection Regulation, EU): что должен знать middle

**Core principles** (ст. 5):
- **Lawfulness, fairness, transparency** (законность, справедливость, прозрачность) — пользователь должен знать, какие данные собираются и зачем.
- **Purpose limitation** (ограничение цели) — данные собираются только для указанной цели.
- **Data minimization** (минимизация данных) — собирать только нужные данные (не больше).
- **Accuracy** (точность) — данные должны быть точными и актуальными.
- **Storage limitation** (ограничение хранения) — хранить данные только столько, сколько нужно.
- **Integrity and confidentiality** (целостность и конфиденциальность) — защищать данные (encryption, access control).

**Data subject rights** (ст. 12–22) — **права пользователя**:
- **Right to access** (ст. 15) — пользователь может запросить все свои данные (в течение 30 дней).
- **Right to rectification** (ст. 16) — исправить неточные данные.
- **Right to erasure** (ст. 17, «right to be forgotten») — удалить все свои данные (в течение 30 дней). **Исключения**: если данные нужны для compliance (налоги, audit) или для исполнения договора.
- **Right to restrict processing** (ст. 18) — ограничить обработку данных.
- **Right to data portability** (ст. 20) — получить данные в machine-readable формате (JSON, CSV).
- **Right to object** (ст. 21) — возражать против обработки (например, marketing).

**Consent** (ст. 6, 7):
- **Explicit** (явный) — пользователь должен **активно** дать согласие (checkbox, не pre-ticked).
- **Granular** (подробный) — согласие на каждый тип обработки (marketing, analytics, third-party).
- **Revocable** (отзываемый) — пользователь может отозвать согласие в любой момент.
- **Documentation** (документация) — нужно хранить, когда и как дано согласие (timestamp, IP, version).

**Data minimization** (ст. 5(1)(c)):
- **Collect only what you need** (собирай только нужное) — не собирай email, если нужен только телефон.
- **Pseudonymization** (псевдонимизация) — заменяй PII (Personally Identifiable Information) на токены (e.g. `user_123` вместо `john@example.com`).
- **Anonymization** (анонимизация) — удаляй PII, если не нужно (e.g. IP address после аутентификации).

**Privacy by design** (ст. 25):
- **Default privacy** (приватность по умолчанию) — настройки приватности должны быть максимальными по умолчанию.
- **Encryption at rest** (шифрование на диске) — данные в БД зашифрованы (AES-256).
- **Encryption in transit** (шифрование в транзите) — данные передаются по TLS 1.2+.
- **Access control** (контроль доступа) — только авторизованные пользователи могут видеть PII.

**DPO** (Data Protection Officer, ст. 37–39):
- **Обязателен** в финтехе (Revolut, Wise, Monzo, Starling) — компания должна назначить DPO.
- **Responsibilities** (ответственности) — monitoring compliance, advising on DPIA (Data Protection Impact Assessment), liaising with supervisory authority.
- **Independence** (независимость) — DPO не может иметь конфликт интересов (не может быть CTO или CFO).

**Breach notification** (ст. 33–34):
- **72 hours** (72 часа) — компания должна уведомить supervisory authority (e.g. ICO в UK, CNIL во Франции) о breach в течение 72 часов.
- **Notify users** (уведомить пользователей) — если breach влияет на пользователей, нужно уведомить их (clear language, what happened, what to do).
- **Documentation** (документация) — записать все breach (даже если не уведомляли).

**Cross-border transfer** (ст. 44–49):
- **Standard Contractual Clauses** (SCC, 2021) — стандартные договорные условия для передачи данных в non-EU страны (e.g. US).
- **Adequacy decision** (решение об адекватности) — EU решила, что страна имеет адекватную защиту (e.g. Japan, Canada, UK).
- **Binding Corporate Rules** (BCR) — внутренние правила для multi-national companies.
- **EU-US Data Privacy Framework** (2023) — новый механизм для передачи данных в US (заменит Privacy Shield).

**Вопросы на интервью**:
- «Как реализовать right to erasure?» → **Ответ**: «При запросе пользователя на удаление мы **soft-delete** данные (ставим флаг `deleted_at`), **анонимизируем** PII (заменяем на токены), **удаляем** из search-индексов. **Исключения**: если данные нужны для compliance (налоги, audit), мы **retention** (храним) в течение 7 лет, но **ограничиваем** доступ (только compliance-команда)».
- «Как настроить consent management?» → **Ответ**: «Используем **cookie banner** (OneTrust, Cookiebot), **granular consent** (отдельные checkbox'ы для marketing, analytics, third-party), **documentation** (timestamp, IP, version). **Revocation** — пользователь может отозвать согласие в настройках профиля. **Default** — все consent off (privacy by design)».
- «Как передавать данные в US (SCC)?» → **Ответ**: «Подписываем **Standard Contractual Clauses** (2021), делаем **Transfer Impact Assessment** (оцениваем риски), **encryption** (TLS 1.2+ в транзите, AES-256 at rest). **EU-US Data Privacy Framework** — если US-компания сертифицирована, можно передавать без SCC».
- «Как пройти GDPR audit?» → **Ответ**: «**DPIA** (Data Protection Impact Assessment) для high-risk обработки, **data inventory** (перечень всех данных, где хранятся, кто имеет доступ), **access control** (RBAC, только нужные люди), **encryption** (at rest + in transit), **breach response plan** (процедура при breach), **training** (обучение сотрудников)».

**Пример ответа на интервью**: «В прошлой компании (фintech, EU) мы реализовали **GDPR** compliance. **Right to erasure**: при запросе пользователя мы **soft-delete** данные (флаг `deleted_at`), **анонимизируем** PII (заменяем на токены), **удаляем** из Elasticsearch. **Consent**: **OneTrust** (consent management), **granular** (отдельные checkbox'ы), **documentation** (timestamp, IP, version). **Data minimization**: собираем только email + телефон (не собираем address, если не нужно). **Encryption**: **AES-256** at rest (RDS, S3), **TLS 1.2+** in transit. **Access control**: **RBAC** (только compliance-команда видит PII). **Breach response**: **72 hours** (уведомить ICO), **documentation** (записать все breach). **Cross-border**: **SCC** (2021) для передачи данных в US. **Result**: прошли **GDPR audit** (ICO), **zero breaches** за 2 года»».

### 2. PCI-DSS (Payment Card Industry Data Security Standard): что должен знать middle

**Core requirements** (12):
1. **Install and maintain firewall** (установить и поддерживать firewall) — сегментация сети, ограничение доступа.
2. **Not use vendor-supplied defaults** (не использовать дефолтные пароли) — сменить все дефолтные пароли, unique IDs.
3. **Protect stored cardholder data** (защитить хранящиеся данные) — **encryption** (AES-256) или **tokenization** (замена PAN на токен).
4. **Encrypt cardholder data in transit** (шифровать данные в транзите) — **TLS 1.2+**, **strong cryptography**.
5. **Protect against malware** (защититься от malware) — **antivirus**, **patch management**.
6. **Develop and maintain secure systems** (разрабатывать безопасные системы) — **secure coding**, **penetration testing**.
7. **Restrict access to cardholder data** (ограничить доступ) — **least privilege**, **RBAC**, **MFA**.
8. **Identify and authenticate access** (идентифицировать и аутентифицировать) — **unique IDs**, **strong passwords**, **MFA**.
9. **Restrict physical access** (ограничить физический доступ) — **data center security**, **CCTV**, **badges**.
10. **Log and monitor all access** (логировать и мониторить) — **audit log** (все операции), **SIEM** (Security Information and Event Management).
11. **Test security of network regularly** (регулярно тестировать безопасность) — **penetration testing** (внешний + внутренний), **vulnerability scanning**.
12. **Maintain a security policy** (поддерживать security policy) — **documented policy**, **training**, **incident response plan**.

**CDE** (Cardholder Data Environment) — **изолированная зона**, где хранятся/обрабатываются/транспортируются card data. **Требования**:
- **Network segmentation** (сегментация сети) — CDE отделена от остальной сети (firewall, VLAN).
- **Access control** (контроль доступа) — только авторизованные люди/системы могут acceder CDE.
- **Encryption** (шифрование) — **PAN** (Primary Account Number, 16 цифр карты) **зашифрован** или **tokenized**.
- **Audit log** (аудит-лог) — все операции в CDE логируются (кто, что, когда).
- **Monitoring** (мониторинг) — SIEM мониторит CDE 24/7.

**PAN** (Primary Account Number) — **16 цифр карты**. **Защита**:
- **Encryption** (AES-256) — шифровать PAN при хранении.
- **Tokenization** (замена на токен) — заменить PAN на токен (e.g. `token_abc123`), токен хранится в **token vault** (безопасное хранилище).
- **Truncation** (усечение) — хранить только **last 4 цифры** (e.g. `****-****-****-1234`), остальные 12 цифр не хранить.

**Вопросы на интервью**:
- «Как защитить card data?» → **Ответ**: «**Encryption** (AES-256 at rest, TLS 1.2+ in transit), **tokenization** (PAN → токен, токен в token vault), **truncation** (хранить только last 4 цифры). **Access control** (RBAC, только payment-команда), **audit log** (все операции), **network segmentation** (CDE отделена)».
- «Как настроить access control для CDE?» → **Ответ**: «**RBAC** (Role-Based Access Control — роли: developer, ops, compliance), **MFA** (Multi-Factor Authentication — обязательный для CDE), **jump host** (доступ только через bastion server), **session recording** (запись всех сессий)».
- «Как пройти PCI-DSS audit?» → **Ответ**: «**QSA** (Qualified Security Assessor — внешний аудитор), **self-assessment** (внутренняя проверка по 12 требованиям), **penetration testing** (внешний + внутренний), **vulnerability scanning** (регулярный), **documentation** (policy, procedures, training records)».
- «Как encrypt-ить PAN?» → **Ответ**: «**AES-256-GCM** (authenticated encryption), **key management** (AWS KMS, HashiCorp Vault — keys не хранятся вместе с данными), **re-encryption** (регулярная смена keys, e.g. каждые 90 дней)».

**Пример ответа на интервью**: «В прошлой компании (фintech, UK) мы прошли **PCI-DSS audit**. **CDE**: **network segmentation** (отдельный VPC, firewall), **access control** (RBAC, MFA, jump host), **encryption** (AES-256 at rest, TLS 1.2+ in transit), **tokenization** (PAN → токен, token vault в AWS KMS), **audit log** (все операции в CDE → CloudWatch Logs → SIEM). **Penetration testing**: **внешний** (раз в год, QSA), **внутренний** (раз в год, QSA). **Vulnerability scanning**: **weekly** (Nessus, Qualys). **Result**: прошли **PCI-DSS audit** (Level 1 — highest), **zero card data breaches** за 3 года»».

### 3. SOC 2 (System and Organization Controls): что должен знать middle

**Core trust services criteria** (5):
- **Security** (безопасность) — **access control** (RBAC, MFA), **encryption** (at rest + in transit), **audit log** (все операции), **penetration testing** (регулярный), **vulnerability management** (patching).
- **Availability** (доступность) — **uptime** (99.9%+), **backup** (ежедневный, off-site), **disaster recovery** (RPO < 1 час, RTO < 4 часа), **load testing** (регулярный).
- **Confidentiality** (конфиденциальность) — **encryption** (at rest + in transit), **access control** (least privilege), **data classification** (public, internal, confidential, restricted).
- **Processing integrity** (целостность обработки) — **input validation** (проверка данных), **error handling** (корректная обработка ошибок), **reconciliation** (сверка данных).
- **Privacy** (приватность) — **GDPR compliance** (см. выше), **data minimization**, **consent management**.

**Types of audit**:
- **Type I** (моментальный) — проверка **design** (дизайн controls на один момент времени). **Длительность**: 1–2 недели.
- **Type II** (периодический) — проверка **operating effectiveness** (как controls работали за период). **Длительность**: 3–12 месяцев. **Обязателен** для enterprise clients (Revolut, Wise, Monzo).

**Controls** (что проверяют):
- **Access control** — **RBAC**, **MFA**, **password policy** (12+ chars, complexity), **session timeout** (30 мин), **audit log** (все login/logout).
- **Change management** — **code review** (обязательный), **testing** (unit + integration), **deployment** (staging → prod), **rollback** (процедура отката).
- **Incident response** — **procedure** (процедура при incident), **communication** (уведомление stakeholders), **post-mortem** (анализ после incident).
- **Business continuity** — **BCP** (Business Continuity Plan), **DR** (Disaster Recovery), **RPO/RTO** (Recovery Point/Time Objective), **testing** (регулярный DR test).
- **Vendor management** — **due diligence** (проверка vendors), **contract** (SLA, security requirements), **monitoring** (проверка compliance vendors).

**Вопросы на интервью**:
- «Как подготовить к SOC 2 audit?» → **Ответ**: «**Gap analysis** (проверка, какие controls уже есть), **documentation** (policy, procedures, training records), **technical controls** (RBAC, MFA, encryption, audit log), **process controls** (change management, incident response), **testing** (penetration testing, vulnerability scanning)».
- «Какие controls нужны?» → **Ответ**: «**Access control** (RBAC, MFA), **change management** (code review, testing, deployment), **incident response** (procedure, communication), **business continuity** (BCP, DR, RPO/RTO), **vendor management** (due diligence, contract)».
- «Как настроить continuous monitoring?» → **Ответ**: «**SIEM** (Security Information and Event Management — сбор логов, correlation, alerts), **vulnerability scanning** (weekly, Nessus/Qualys), **configuration management** (Terraform, Ansible — as code), **compliance dashboard** (Grafana — статус всех controls)».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы прошли **SOC 2 Type II** audit (12 месяцев). **Access control**: **RBAC** (роли: developer, ops, compliance), **MFA** (обязательный для prod), **password policy** (12+ chars, complexity), **session timeout** (30 мин). **Change management**: **code review** (обязательный, 2 reviewers), **testing** (unit + integration, coverage 80%+), **deployment** (staging → prod, canary), **rollback** (процедура, < 5 мин). **Incident response**: **procedure** (классификация, communication, post-mortem), **communication** (Slack #incidents, email stakeholders), **post-mortem** (в течение 48 часов). **Business continuity**: **BCP** (documented), **DR** (RPO < 1 час, RTO < 4 часа), **testing** (раз в год, DR test). **Result**: прошли **SOC 2 Type II** (clean report, zero exceptions)»».

### 4. DORA (Digital Operational Resilience Act, EU 2025): что должен знать middle

**Core requirements**:
- **ICT risk management** (управление рисками IT) — **risk assessment** (оценка рисков), **risk register** (реестр рисков), **risk mitigation** (снижение рисков), **monitoring** (мониторинг).
- **Operational resilience** (операционная устойчивость) — **identify critical functions** (критические функции), **tolerability objectives** (допустимые уровни: RPO, RTO), **business continuity plan** (BCP), **testing** (регулярный DR test).
- **Incident reporting** (отчёт об инцидентах) — **classify incidents** (классификация: minor, major, critical), **report to supervisor** (отчёт в регулятор, 72 часа для major/critical), **post-incident analysis** (анализ после инцидента).
- **Third-party risk** (риски поставщиков) — **due diligence** (проверка vendors), **contract** (SLA, security requirements, exit strategy), **monitoring** (проверка compliance vendors), **concentration risk** (риски концентрации, e.g. один vendor для 50% функций).
- **Threat-led testing** (тестирование на основе угроз) — **TLPT** (Threat-Led Penetration Testing — внешний pentest с simuляции real-world attack), **frequency** (раз в 3 года для critical ICT third parties).

**Вопросы на интервью**:
- «Как настроить operational resilience?» → **Ответ**: «**Identify critical functions** (какие функции критичны для бизнеса), **tolerability objectives** (RPO < 1 час, RTO < 4 часа), **BCP** (documented, tested), **DR test** (раз в год)».
- «Как управлять third-party risk?» → **Ответ**: «**Due diligence** (проверка vendors: SOC 2, PCI-DSS, ISO 27001), **contract** (SLA, security requirements, exit strategy), **monitoring** (проверка compliance vendors, e.g. раз в год), **concentration risk** (один vendor не может быть для 50% критических функций)».
- «Как пройти DORA audit?» → **Ответ**: «**Risk assessment** (оценка рисков), **risk register** (реестр рисков), **ICT risk management** (политика, процедуры), **operational resilience** (BCP, DR test), **incident reporting** (процедура, классификация), **third-party risk** (due diligence, contract, monitoring), **TLPT** (раз в 3 года)».

**Пример ответа на интервью**: «В прошлой компании (fintech, EU) мы готовились к **DORA** (2025). **ICT risk management**: **risk assessment** (оценка рисков: availability, confidentiality, integrity), **risk register** (реестр: 50+ рисков, owner, mitigation), **monitoring** (SIEM, alerts). **Operational resilience**: **critical functions** (payments, authentication, reporting), **tolerability objectives** (RPO < 1 час, RTO < 4 часа), **BCP** (documented, tested), **DR test** (раз в год, RTO achieved < 4 часа). **Incident reporting**: **classification** (minor, major, critical), **reporting** (72 часа для major/critical), **post-incident analysis** (в течение 48 часов). **Third-party risk**: **due diligence** (SOC 2, PCI-DSS, ISO 27001), **contract** (SLA, security requirements, exit strategy), **monitoring** (раз в год), **concentration risk** (один vendor не более 30% критических функций). **Result**: готовы к **DORA** (2025), **zero critical incidents** за год»».

### 5. PSD2 (Payment Services Directive 2, EU): что должен знать middle

**Core requirements**:
- **Strong Customer Authentication** (SCA, ст. 97) — **2 из 3 факторов**: **knowledge** (пароль, PIN), **possession** (телефон, token), **inherence** (biometric: fingerprint, face). **Обязателен** для online payments (кроме low-value: < €30, trusted beneficiary).
- **Open banking** (ст. 86–89) — **API** для third parties (AISP — Account Information Service, PISP — Payment Initiation Service), **consent** (явное согласие пользователя), **security** (OAuth 2.0, mTLS).
- **Transaction reporting** (ст. 41–42) — **instant access** (мгновенный доступ к транзакциям), **search** (поиск по транзакциям), **alerts** (уведомления о новых транзакциях).
- **Fraud prevention** (ст. 95–96) — **PSD2 transaction monitoring** (мониторинг транзакций), **PSD2 fraud reporting** (отчёт о fraud), **PSD2 liability** (ответственность за fraud).

**Вопросы на интервью**:
- «Как реализовать SCA?» → **Ответ**: «**2 из 3 факторов**: **knowledge** (пароль), **possession** (телефон, OTP), **inherence** (biometric: fingerprint). **Low-value exemption**: < €30, trusted beneficiary (белый список). **Flow**: login (пароль) → SCA (OTP в телефон) → payment (подтверждение)».
- «Как настроить open banking API?» → **Ответ**: «**OAuth 2.0** (authorization code + PKCE), **mTLS** (mutual TLS — клиент и сервер обмениваются сертификатами), **consent** (явное согласие пользователя, timestamp, scope), **API** (AISP: read transactions, PISP: initiate payment)».
- «Как предотвратить fraud?» → **Ответ**: «**Monitoring** (аномальные транзакции: сумма, география, время), **velocity checks** (сколько транзакций за минуту), **device fingerprinting** (уникальный ID устройства), **ML model** (классификация: fraud vs legit, accuracy 95%+)».

**Пример ответа на интервью**: «В прошлой компании (fintech, EU) мы реализовали **PSD2** compliance. **SCA**: **2 из 3 факторов** (пароль + OTP в телефон), **low-value exemption** (< €30, trusted beneficiary). **Open banking**: **OAuth 2.0** (authorization code + PKCE), **mTLS** (mutual TLS), **consent** (явное согласие, timestamp, scope). **Transaction reporting**: **instant access** (API для AISP/PISP), **search** (поиск по транзакциям), **alerts** (push notification). **Fraud prevention**: **monitoring** (аномальные транзакции), **velocity checks** (10 транзакций/мин), **device fingerprinting** (уникальный ID), **ML model** (accuracy 95%+). **Result**: прошли **PSD2** audit (regulator), **zero fraud incidents** за год»».

### 6. Security в архитектуре: zero trust, defense in depth, least privilege

**Zero trust** (модель «не доверяй никому»):
- **Never trust, always verify** (никогда не доверяй, всегда проверяй) — каждый запрос аутентифицируется и авторизуется (даже из внутренней сети).
- **Micro-segmentation** (микросегментация) — сеть разделена на маленькие сегменты (каждый сервис — свой сегмент), **NetworkPolicy** (K8s) или **security groups** (AWS).
- **Least privilege** (минимальные привилегии) — каждый пользователь/сервис имеет только нужные права (не больше).
- **MFA** (Multi-Factor Authentication) — обязательный для prod, **SSO** (Single Sign-On) — один вход для всех сервисов.
- **Encryption everywhere** (шифрование везде) — **at rest** (AES-256), **in transit** (TLS 1.2+), **in use** (homomorphic encryption — редко).

**Defense in depth** (многослойная защита):
- **Network layer** (сетевой уровень) — **firewall** (iptables, AWS Security Groups), **IDS/IPS** (Intrusion Detection/Prevention System), **DDoS protection** (AWS Shield, CloudFlare).
- **Host layer** (уровень хоста) — **OS hardening** (CIS Benchmark), **patch management** (регулярный), **antivirus** (если есть), **file integrity monitoring** (FIM — проверка целостности файлов).
- **Application layer** (уровень приложения) — **input validation** (проверка данных), **output encoding** (защита от XSS), **secure coding** (OWASP Top 10), **authentication** (OAuth 2.0, OIDC), **authorization** (RBAC, ABAC).
- **Data layer** (уровень данных) — **encryption** (at rest + in transit), **access control** (RBAC), **data classification** (public, internal, confidential, restricted), **DLP** (Data Loss Prevention — предотвращение утечки).

**Least privilege** (минимальные привилегии):
- **RBAC** (Role-Based Access Control) — **роли** (developer, ops, compliance), **права** (read, write, delete), **привязка** (user → role → permissions).
- **ABAC** (Attribute-Based Access Control) — **атрибуты** (user.department, user.clearance, resource.sensitivity), **policy** (если user.clearance >= resource.sensitivity, то allow).
- **IAM** (Identity and Access Management, AWS) — **roles** (для сервисов), **users** (для людей), **policies** (JSON, Allow/Deny), **least privilege** (только нужные ресурсы).

**MFA** (Multi-Factor Authentication):
- **2FA** (Two-Factor Authentication) — **2 фактора** (пароль + OTP), **3FA** (Three-Factor) — **3 фактора** (пароль + OTP + biometric).
- **TOTP** (Time-based One-Time Password) — **6-значный код** (меняется каждые 30 секунд), **app** (Google Authenticator, 1Password), **hardware token** (YubiKey).
- **WebAuthn** (FIDO2) — **passwordless** (без пароля), **biometric** (fingerprint, face), **hardware key** (YubiKey), **phishing-resistant** (устойчивый к фишингу).

**SSO** (Single Sign-On):
- **SAML** (Security Assertion Markup Language) — **XML-based**, **enterprise** (Okta, Azure AD, OneLogin), **federation** (SSO между системами).
- **OAuth 2.0** (Open Authorization) — **token-based**, **API** (Google, GitHub, Slack), **authorization** (доступ к API).
- **OIDC** (OpenID Connect) — **OAuth 2.0 + authentication**, **identity** (кто ты), **tokens** (ID token, access token, refresh token).

**Вопросы на интервью**:
- «Как настроить zero trust architecture?» → **Ответ**: «**Micro-segmentation** (NetworkPolicy, security groups), **least privilege** (RBAC, IAM roles), **MFA** (обязательный для prod), **SSO** (OIDC, Okta), **encryption** (at rest + in transit), **audit log** (все операции)».
- «Как управлять keys?» → **Ответ**: «**KMS** (AWS KMS, HashiCorp Vault), **key rotation** (регулярная смена, e.g. каждые 90 дней), **key hierarchy** (master key → data keys), **access control** (least privilege, audit log)».
- «Как реализовать MFA?» → **Ответ**: «**TOTP** (Google Authenticator, 1Password), **WebAuthn** (YubiKey, biometric), **mandatory** (для prod), **audit log** (все MFA attempts)».
- «Сравнить SAML vs OAuth2 vs OIDC» → **Ответ**: «**SAML** — **enterprise SSO** (Okta, Azure AD), **XML**, **federation**. **OAuth 2.0** — **API authorization** (Google, GitHub), **token-based**, **authorization**. **OIDC** — **OAuth 2.0 + authentication** (identity), **tokens** (ID, access, refresh), **modern** (JSON, REST)».

**Пример ответа на интервью**: «В прошлой компании (fintech, UK) мы реализовали **zero trust architecture**. **Micro-segmentation**: **NetworkPolicy** (K8s, default deny), **security groups** (AWS, ingress/egress). **Least privilege**: **RBAC** (роли: developer, ops, compliance), **IAM** (AWS, roles для сервисов). **MFA**: **WebAuthn** (YubiKey, biometric), **mandatory** (для prod). **SSO**: **OIDC** (Okta), **tokens** (ID, access, refresh). **Encryption**: **AES-256** (at rest), **TLS 1.2+** (in transit). **Audit log**: **все операции** → CloudWatch Logs → SIEM. **Result**: **zero trust** (не доверяем никому), **least privilege** (минимальные привилегии), **zero breaches** за 2 года»».
