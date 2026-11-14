# Cloud-Native Java

### 1. GraalVM Native Image: AOT-компиляция, ограничения, Spring Boot 3 support

**GraalVM Native Image** — компиляция Java-приложения в **нативный** бинарник (AOT, Ahead-Of-Time). Бинарник **не** требует JVM, **запускается** за **миллисекунды**, **занимает** **мало** памяти.

**Плюсы**:
- **Старт**: **5–50 мс** (vs 5–30 с для JVM).
- **Память**: **50–200 МБ** (vs 500 МБ+ для JVM).
- **Деплой**: **один** бинарник (без JVM, без JRE).
- **Serverless**: **cold start** **минимальный**.

**Ограничения**:
- **AOT**: код **анализируется** **до** **компиляции** → **рефлексия**, **динамическая** **загрузка** **классов** **не** **работают** **из** **коробки**.
- **Reflection**: нужно **зарегистрировать** **классы/методы** через **reflection hints** (`@ImportRuntimeHints`, `reflect-config.json`).
- **Resource**: **файлы** (templates, properties) нужно **включить** в **образ** (`resource-config.json`).
- **Build time**: **компиляция** **долгая** (2–10 мин).
- **Debugging**: **сложнее** (нет JVM, **stack trace** **обрезан**).
- **Не** **все** **библиотеки** **поддерживают** (например, **JNA**, **некоторые** **JDBC** **драйверы**).

**Spring Boot 3 support**:
- **Spring Boot 3.0+** **нативно** **поддерживает** **GraalVM Native Image** (через **AOT processing**).
- **`@ImportRuntimeHints`** — **аннотация** для **регистрации** **reflection hints**.
- **`spring.aot.enabled=true`** — **включает** **AOT** **обработку** (генерация **кода** для **native**).

```java
@Configuration
@ImportRuntimeHints(NativeHints.class)
public class NativeConfig {
    // Spring Boot автоматически генерирует hints для:
    // - @Entity (JPA)
    // - @RestController (JSON)
    // - @Configuration (beans)
    // - Jackson (serialization)
    
    // Кастомные hints:
    @RegisterReflection(forType = MyClass.class)
    static class NativeHints implements RuntimeHints {
        @Override
        public void register(RuntimeHintsRegistrar registrar) {
            registrar.reflect(MyClass.class).onConstructors().onMethods();
            registrar.resources().register("templates/*.html");
        }
    }
}
```

**Сборка**:
```bash
# Maven:
mvn package -Pnative

# Gradle:
./gradlew nativeCompile

# Результат: target/native-image/my-app (бинарник)
```

**Когда GraalVM, когда JVM**:
- **GraalVM**: **serverless** (Lambda, Cloud Functions), **CLI** **утилиты**, **микро-сервисы** с **быстрым** **стартом**.
- **JVM**: **большие** **приложения** (JPA, AOP, dynamic proxies), **debugging**, **hot deployment**.

**Типовые проблемы**:
- **`ClassNotFoundException`** при **запуске** → **не** **зарегистрирован** **класс** в **reflection hints**.
- **`NoClassDefFoundError`** для **Jackson** → **не** **включён** **resource**.
- **Build fails** → **библиотека** **использует** **dynamic class loading** (не **поддерживается**).

### 2. Quarkus vs Spring Boot: trade-offs, dev mode, extension model

**Quarkus** — **cloud-native** Java фреймворк (Red Hat), **собранный** на **Arc** (DI) + **Mutiny** (reactive) + **Vert.x** (non-blocking I/O).

**Сравнение**:
| | Spring Boot | Quarkus |
|---|---|---|
| **Старт** | 5–30 с | 100–500 мс (JVM), **5–50 мс** (native) |
| **Память** | 500 МБ+ | 100–300 МБ (JVM), **50–200 МБ** (native) |
| **DI** | Spring IoC (reflection) | Arc (compile-time, AOT) |
| **Реактивность** | WebFlux (Reactor) | Mutiny (Reactive Streams) |
| **JPA** | Hibernate (full) | Hibernate (compile-time optimized) |
| **Dev mode** | `spring-boot:run` (restart) | `quarkus:dev` (hot reload, **no** restart) |
| **Extension** | Starter (jar) | Extension (jar + **metadata**) |
| **Экосистема** | Огромная | Растёт (Red Hat ecosystem) |
| **Learning curve** | Средняя | Низкая (похож на Spring) |

**Dev Mode (Quarkus)**:
- **Hot reload**: **изменение** **кода** → **автоматический** **reload** **без** **restart**.
- **Dev UI**: **встроенный** **UI** (http://localhost:8080/q/dev) — **metrics**, **config**, **extensions**.
- **Dev Services**: **автоматический** **запуск** **PostgreSQL**, **Kafka**, **Redis** (Docker) при **dev**.

```bash
# Dev mode:
./mvnw quarkus:dev
# Изменил код → hot reload (1–2 сек)
```

**Extension Model**:
- **Extension** = **jar** + **build step** (compile-time processing).
- **Пример**: **`quarkus-jdbc-postgresql`** — **compile-time** **генерация** **кода** для **JDBC**.
- **Плюс**: **меньше** **reflection**, **быстрее** **старт**, **меньше** **память**.

**Когда Quarkus, когда Spring Boot**:
- **Quarkus**: **cloud-native** (Kubernetes, serverless), **быстрый** **старт**, **мало** **памяти**, **Red Hat** **экосистема**.
- **Spring Boot**: **большие** **приложения**, **огромная** **экосистема**, **проще** **найди** **специалиста**, **hot deployment** (не **native**).

**Миграция Spring → Quarkus**:
- **Похожий** **API** (`@Inject` вместо `@Autowired`, `@RESTEasy` вместо `@RestController`).
- **Hibernate** **совместим** (Quarkus **использует** Hibernate **под** **капотом**).
- **Kafka**, **RabbitMQ** — **аналогичные** **extensions**.

### 3. Micronaut: особенности, compile-time DI

**Micronaut** — **lightweight** Java фреймворк, **compile-time** **DI** (без **reflection**).

**Особенности**:
- **Compile-time DI**: **граф** **зависимостей** **строится** **при** **компиляции** (не **при** **запуске**).
- **Без** **reflection**: **меньше** **память**, **быстрее** **старт**.
- **Modular**: **каждый** **модуль** (HTTP, JDBC, Kafka) — **отдельный** **jar**.
- **Reactive**: **Reactor** или **Reactive Streams** (не **обязательно** WebFlux).

**Сравнение**:
| | Micronaut | Spring Boot | Quarkus |
|---|---|---|---|
| **DI** | Compile-time | Runtime (reflection) | Compile-time (Arc) |
| **Старт** | 100–500 мс | 5–30 с | 100–500 мс |
| **Память** | 50–200 МБ | 500 МБ+ | 100–300 МБ |
| **Реактивность** | Reactor / Reactive Streams | WebFlux | Mutiny |
| **Экосистема** | Средняя | Огромная | Растёт |
| **Learning curve** | Низкая | Средняя | Низкая |

**Пример (Micronaut)**:
```java
@Singleton
class OrderService {
    private final OrderRepository repo;
    
    @Inject
    OrderService(OrderRepository repo) {
        this.repo = repo;
    }
    
    Order findById(Long id) {
        return repo.findById(id);
    }
}

@Controller("/orders")
class OrderController {
    private final OrderService service;
    
    @Inject
    OrderController(OrderService service) {
        this.service = service;
    }
    
    @Get("/{id}")
    Order getOrder(@PathVariable Long id) {
        return service.findById(id);
    }
}
```

**Когда Micronaut**:
- **Микро-сервисы** (мало памяти, быстрый старт).
- **Serverless** (Lambda, Cloud Functions).
- **Embedded** (IoT, edge).
- **Не** нужен **огромный** **Spring** **экосистема**.

**Типовые проблемы**:
- **Меньше** **библиотек** (не **все** Spring **стартеры** **есть**).
- **Меньше** **сообщество** (сложнее **найти** **ответы**).
- **Compile-time** **DI** → **сложнее** **dynamic** **beans** (например, **conditional** **beans**).

### 4. Serverless Java: AWS Lambda, cold start optimization, SnapStart

**AWS Lambda** — **serverless** compute (pay-per-use, **авто** **масштабирование**).

**Cold Start**:
- **Первый** **запрос** к **Lambda** → **создание** **контейнера** + **запуск** **JVM** + **инициализация** **классов**.
- **JVM**: **5–30 с** (без **оптимизации**).
- **GraalVM Native**: **5–50 мс**.

**Оптимизация Cold Start (JVM)**:
- **Уменьшить** **heap** (`-Xmx512m` → **меньше** **времени** на **GC**).
- **Warm up**: **pre-warm** **контейнер** (приёмный **запрос** при **deploy**).
- **GraalVM Native**: **убрать** **JVM** (**5–50 мс**).
- **SnapStart** (AWS): **snapshot** **JVM** heap **после** **инициализации** → **восстановление** из **snapshot** (**100–500 мс**).

**SnapStart**:
- **AWS** **снимает** **snapshot** **JVM** heap **после** **первого** **запуска**.
- **Последующие** **запуски**: **восстановление** из **snapshot** (**без** **инициализации** **классов**).
- **Cold start**: **100–500 мс** (vs **5–30 с**).
- **Ограничение**: **только** **immutable** **functions** (без **external** **state**).

**Приложение (Lambda)**:
```java
// AWS Lambda handler:
public class OrderHandler implements RequestHandler<OrderRequest, OrderResponse> {
    @Override
    public OrderResponse handleRequest(OrderRequest request, Context context) {
        // Логика (без main, без server)
        return orderService.process(request);
    }
}
```

**Деплой**:
- **Maven/Gradle**: **собрать** **jar** (thin jar, **без** **зависимостей**).
- **AWS CLI**: `aws lambda update-function-code --function-name order-fn --zip-file fileb://function.zip`.
- **SAM** (Serverless Application Model): ** IaC** для **Lambda** + **API Gateway** + **DynamoDB**.

**Когда Serverless, когда Container**:
- **Serverless**: **burst** **нагрузки** (непредсказуемая), **мало** **трафика** (pay-per-use), **event-driven** (S3, SQS, API).
- **Container**: **постоянная** **нагрузка**, **долгие** **вычисления** (> 15 мин для Lambda), **stateful** (соединения, сессии).

**Типовые проблемы**:
- **512 МБ** **ограничение** (Lambda) → **оптимизация** **памяти**.
- **15 мин** **ограничение** (Lambda) → **async** (SQS) для **долгих** **задач**.
- **VPC** **настройка** (Lambda в VPC) → **cold start** **дольше** (ENI allocation).

### 5. FinOps: cost optimization, right-sizing, spot instances

**FinOps** — **дисциплина** **управления** **облачными** **затратами** (finance + operations).

**Cost Optimization**:
- **Right-sizing**: **выбрать** **правильный** **размер** **ресурса** (CPU, RAM) под **нагрузку**.
  - **Слишком** **много** → **переплата**.
  - **Слишком** **мало** → **деградация** **производительности**.
  - **Инструменты**: **CloudWatch** (AWS), **GCP Cost Management**, **Azure Cost Manager**.
- **Reserved Instances / Savings Plans**: **запасание** **ресурсов** **на** **1–3 года** → **30–70%** **скидка**.
- **Spot Instances**: **временные** **инстансы** (до **90%** **скидка**), **но** **могут** **завершиться** **в** **любой** **момент** (2 мин **предупреждение**).
  - **Когда**: **batch** **обработки**, **CI/CD**, **test environments**.
  - **Риск**: **потеря** **инстанса** → **нужен** **retry** / **checkpoint**.

**Practices**:
1. **Visibility**: **понимать** **где** **уходит** **деньги** (tagging, cost allocation).
2. **Optimization**: **right-sizing**, **spot**, **reserved**.
3. **Operation**: **мониторинг** **затрат** (alerts при **превышении** **бюджета**).

**В Kubernetes**:
- **Vertical Pod Autoscaler (VPA)**: **автоматически** **подбирает** **requests/limits**.
- **Cluster Autoscaler**: **добавляет/убирает** **ноды** под **нагрузку**.
- **Spot Instances** в **Kubernetes**: **NodePool** с **spot** **инстансами** (для **batch** **workloads**).

**Best practice**:
- **Tagging** **всех** **ресурсов** (project, team, environment).
- **Budget alerts** (AWS Budget, GCP Budget).
- **Right-sizing** **раз** в **квартал** (нагрузка **меняется**).
- **Spot** для **non-critical** (batch, test, dev).

### 6. 12-Factor App методология

**12-Factor App** — **методология** **построения** **cloud-ready** **приложений** (Heroku, 2011).

**12 факторов**:
1. **Codebase**: **один** **код** **в** **репозитории**, **много** **деплоев** (dev, staging, prod).
2. **Dependencies**: **явно** **декларированные** (Maven/Gradle), **не** **имплиcit** (system-wide).
3. **Config**: **хранится** в **окружении** (env vars), **не** в **коде**.
4. **Backing Services**: **attach** **ресурсы** (БД, Redis) через **handle** (env var), **не** **hardcoded**.
5. **Build, Ship, Run**: **чёткое** **разделение** **build** (jar) и **run** (deploy), **минимум** **различий**.
6. **Exec**: **запуск** как **stateless** **процесс** (no in-memory state).
7. **Port Binding**: **сервис** **привязывается** к **порту** через **config** (не **hardcoded**).
8. **Concurrency**: **масштабирование** через **процессы** (не **threads**).
9. **Disposability**: **быстрый** **старт** и **graceful** **shutdown** (минимум **downtime**).
10. **Dev/Prod Parity**: **минимум** **различий** **между** **dev** и **prod** (Docker, env vars).
11. **Logs**: **логи** — **поток** **событий** (stdout), **не** **файлы** (собираются **инфраструктурой**).
12. **Admin Processes**: **админ** **задачи** (migrations, scripts) — **одноразовые** **процессы** в **том же** **окружении**.

**Пример (Spring Boot)**:
```properties
# .env (или Kubernetes ConfigMap):
DB_HOST=prod-db.example.com
DB_PORT=5432
DB_USER=app
DB_PASSWORD=${DB_PASSWORD}  # secret
REDIS_HOST=prod-redis.example.com
PORT=8080
```
```yaml
# Dockerfile:
FROM eclipse-temurin:21-jre
COPY target/app.jar /app.jar
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

**Когда 12-Factor**:
- **Cloud-native** (Kubernetes, serverless).
- **CI/CD** (build → ship → run).
- **Масштабирование** (stateless, port binding).

**Типовые проблемы**:
- **Hardcoded** **config** (не **env vars**).
- **In-memory** **state** (sessions, caches) → **не** **масштабируется**.
- **Logs** в **файл** (не **stdout**) → **сложно** **собирают**.

### 7. Cloud providers: AWS/Azure/GCP — базовые сервисы для Java-разработчика

**AWS**:
- **Compute**: **EC2** (VM), **Lambda** (serverless), **EKS** (Kubernetes).
- **Database**: **RDS** (PostgreSQL, MySQL), **DynamoDB** (NoSQL), **ElastiCache** (Redis).
- **Storage**: **S3** (object), **EBS** (block), **EFS** (file).
- **Networking**: **VPC**, **ELB** (load balancer), **CloudFront** (CDN).
- **Messaging**: **SQS** (queue), **SNS** (pub/sub), **Kafka** (MSK).
- **Monitoring**: **CloudWatch**, **X-Ray** (tracing).

**Azure**:
- **Compute**: **VM**, **Functions** (serverless), **AKS** (Kubernetes).
- **Database**: **Azure SQL** (SQL Server), **Cosmos DB** (NoSQL), **Cache for Redis**.
- **Storage**: **Blob**, **Disk**, **File**.
- **Networking**: **VNet**, **Load Balancer**, **CDN**.
- **Messaging**: **Service Bus**, **Event Hubs**.
- **Monitoring**: **Monitor**, **Application Insights**.

**GCP**:
- **Compute**: **GCE** (VM), **Cloud Functions** (serverless), **GKE** (Kubernetes).
- **Database**: **Cloud SQL** (PostgreSQL, MySQL), **Firestore** (NoSQL), **Memorystore** (Redis).
- **Storage**: **Cloud Storage** (S3-like), **PD** (block).
- **Networking**: **VPC**, **Load Balancer**, **CDN**.
- **Messaging**: **Pub/Sub** (Kafka-like), **Cloud Tasks**.
- **Monitoring**: **Cloud Monitoring**, **Cloud Trace**.

**Сравнение**:
| | AWS | Azure | GCP |
|---|---|---|---|
| **Доля рынка** | ~31% | ~25% | ~11% |
| **Сервисов** | 200+ | 100+ | 100+ |
| **Kubernetes** | EKS | AKS | GKE |
| **Serverless** | Lambda | Functions | Cloud Functions |
| **NoSQL** | DynamoDB | Cosmos DB | Firestore |
| **Качество доков** | Отличное | Хорошее | Хорошее |
| **Экосистема** | Огромная | Средняя (MS ecosystem) | Средняя |

**Выбор**:
- **AWS**: **наибольшее** **число** **сервисов**, **лучшие** **доки**, **огромная** **экосистема**.
- **Azure**: **интеграция** с **Microsoft** (AD, Office, Dynamics).
- **GCP**: **лучший** **Kubernetes** (GKE), **лучший** **ML/AI** (Vertex AI).

### 8. Infrastructure as Code: Terraform basics для Java-разработчика

**Terraform** (HashiCorp) — **IaC** (Infrastructure as Code) для **любого** **провайдера** (AWS, Azure, GCP, Kubernetes, ...).

**Почему IaC**:
- **Инфраструктура** **в** **коде** (version control, review, CI/CD).
- **Репroducibility**: **одна** **команда** → **одна** **инфраструктура** (dev, staging, prod).
- **Drift detection**: **разница** между **кодом** и **реальностью** (`terraform plan`).

**Базовые концепции**:
- **Provider**: **плагин** для **конкретного** **провайдера** (AWS, Azure, GCP).
- **Resource**: **один** **объект** (S3 bucket, EC2 instance, RDS database).
- **Module**: **переиспользуемый** **блок** (например, **VPC** с **subnet'ами**).
- **State**: **состояние** **инфраструктуры** (`.terraform.tfstate`), **хранится** **в** **S3** (remote state).

**Пример (Terraform)**:
```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "app" {
  bucket = "my-app-data"
  
  tags = {
    Name = "my-app-data"
    Env  = "prod"
  }
}

resource "aws_rds_cluster" "postgres" {
  cluster_identifier = "my-app-db"
  engine             = "postgres"
  engine_version     = "15.4"
  master_username    = "app"
  master_password    = var.db_password  # из variables.tf
  database_name      = "myapp"
  storage_encrypted  = true
  
  tags = {
    Name = "my-app-db"
  }
}

# variables.tf
variable "db_password" {
  type      = string
  sensitive = true
}
```

**Команды**:
```bash
terraform init       # инициализация (download providers)
terraform plan       # план изменений (что будет создано/изменено)
terraform apply      # применить изменения (создать/изменить)
terraform destroy    # уничтожить всё (осторожно!)
```

**В CI/CD**:
```yaml
# GitHub Actions:
- name: Terraform Plan
  run: terraform plan -out=tfplan
  
- name: Terraform Apply (if approved)
  run: terraform apply tfplan
```

**Когда Terraform, когда CloudFormation**:
- **Terraform**: **мульти-провайдер** (AWS + Azure + GCP), **гибкость**, **больше** **модулей**.
- **CloudFormation** (AWS): **только** AWS, **встроен** в **AWS** (не нужно **отдельный** **tool**).

**Best practice**:
- **Remote state** (S3 + DynamoDB locking) → **команда** **работает** **с** **одним** **state**.
- **Modules** для **переиспользования** (VPC, RDS, S3).
- **Terraform Cloud / Atlas** для **управления** **state** и **plan/apply** в **UI**.
- **Never** **commit** **secrets** (использовать **AWS Secrets Manager** / **HashiCorp Vault**).

### 9. Что такое 12-factor app и как его применить в Java

**12-Factor App** = методология для построения **cloud-native** приложений (Heroku, 2011).

| # | Factor | Суть | Java-пример |
|---|--------|------|-------------|
| 1 | **Codebase** | 1 codebase → N deployments | 1 repo → dev/staging/prod (env vars) |
| 2 | **Dependencies** | Явные зависимости | `pom.xml` (Maven) — все зависимости объявлены |
| 3 | **Config** | Config в env vars, не в коде | `SPRING_PROFILES_ACTIVE=prod`, `DB_URL=...` |
| 4 | **Backing services** | Services = attached resources | DB, Redis, Kafka — через env vars (не hardcode) |
| 5 | **Build, release, run** | Строго разделить | Maven build → Docker image → Kubernetes run |
| 6 | **Processes** | Stateless processes | Приложение не хранит session в памяти (Redis) |
| 7 | **Port binding** | Порты через env | `SERVER_PORT=8080` (не hardcode) |
| 8 | **Concurrency** | Масштабирование через процессы | `replicas: 3` в K8s (не thread pool в 1 process) |
| 9 | **Disposability** | Быстрый start/stop | `@PreDestroy` — graceful shutdown |
| 10 | **Dev/prod parity** | Dev ≈ prod | Docker в dev (как в prod) |
| 11 | **Logs** | Logs = stream | `System.out` → stdout (не файл) |
| 12 | **Admin processes** | Админка = один-off process | `java -jar app.jar --migrate` (не отдельный сервис) |

**Spring Boot 12-factor**:
```yaml
# application.yml (12-factor compliant):
server:
  port: ${SERVER_PORT:8080}  # Factor 7: port binding

spring:
  datasource:
    url: ${DB_URL}            # Factor 4: backing services
    username: ${DB_USER}      # Factor 3: config in env
    password: ${DB_PASS}

logging:
  file:                        # Factor 11: logs = stream (stdout)
  console:
    include-startup: true
```

**K8s 12-factor**:
```yaml
# deployment.yaml
spec:
  replicas: 3  # Factor 8: concurrency via processes
  template:
    spec:
      containers:
      - name: app
        image: myapp:1.0  # Factor 5: build → image → run
        ports:
        - containerPort: 8080  # Factor 7
        env:  # Factor 3: config in env
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        - name: SPRING_PROFILES_ACTIVE
          value: "prod"
```

**Вывод**: **12-factor** = 12 принципов **cloud-native** (codebase, dependencies, config, services, build/release/run, processes, port binding, concurrency, disposability, dev/prod parity, logs, admin). **Spring Boot**: env vars, stdout logging, stateless. **K8s**: replicas, env, secrets.

### 10. Что такое service discovery и как он работает

**Service discovery** = механизм **нахождения** **microservices** (IP + port) в **dynamic** окружении (K8s, cloud).

**Типы**:
1. **Client-side**: **client** спрашивает **registry** → **IP:port** → **connect**.
2. **Server-side**: **load balancer** спрашивает **registry** → **proxy** **traffic**.

**Client-side (Eureka, Consul)**:
```
Client → Eureka (registry) → [service-a: 10.0.0.1:8080]
Client → service-a (10.0.0.1:8080)
```

**Server-side (K8s Service, NGINX)**:
```
Client → K8s Service (ClusterIP: 10.96.0.1:8080)
K8s Service → Pod (10.244.0.1:8080)
```

**Eureka (Netflix, Spring Cloud)**:
```java
// Eureka Client:
@GetToUrl("/api/orders")
@FeignClient(name = "orders-service")
public interface OrdersClient {
  @GetMapping("/orders/{id}")
  Order getOrder(@PathVariable Long id);
}
```
- **Registry**: **Eureka Server** (хранит **service** → **IP:port**).
- **Client**: **Feign** (declarative **HTTP client**) → **Eureka** (discovery).

**Consul (HashiCorp)**:
- **Service mesh**: **sidecar** (например: **Envoy**) → **proxy** **traffic**.
- **Health check**: **HTTP**/**TCP**/**gRPC** (каждые **10 сек**).
- **Service discovery**: **DNS** (например: **orders-service.service.consul**).

**K8s Service Discovery**:
- **DNS**: **orders-service** (name) → **ClusterIP** (например: **10.96.0.1**).
- **Service**: **ClusterIP** → **Pod** (например: **10.244.0.1:8080**).
- **Health check**: **readiness probe** (например: **/actuator/health**).

**Вывод**: **Service discovery** = **нахождение** **microservices** (IP + port). **Client-side** (Eureka, Consul): **client** спрашивает **registry**. **Server-side** (K8s Service, NGINX): **load balancer** спрашивает **registry**. **K8s**: **DNS** (service name) → **ClusterIP** → **Pod**.

### 11. Что такое circuit breaker и как его настроить

**Circuit breaker** = паттерн **защиты** от **cascade failure** (когда **1** **service** **падает** → **все** **services** **падают**).

**Состояния**:
1. **Closed** (норма): **requests** **pass** → **service**.
2. **Open** (сработал): **requests** **fail fast** (не **pass**).
3. **Half-open** (testing): **N** **requests** **pass** → **service** (test **recovery**).

**Порог**:
- **Failure count** > **N** (например: **5**) → **Open**.
- **Wait time** (например: **30 сек**) → **Half-open**.
- **Success count** > **M** (например: **3**) → **Closed**.

**Resilience4j (Spring Boot)**:
```java
// application.yml:
resilience4j:
  circuitbreaker:
    instances:
      orders-service:
        failureRateThreshold: 50  # 50% failures
        slidingWindowSize: 10     # 10 requests
        waitDurationInOpenState: 30s  # 30s in Open state
        permittedNumberOfCallsInHalfOpenState: 3  # 3 calls in Half-open

// @RestController:
@RestController
public class OrdersController {
  @Autowired private OrdersClient ordersClient;
  
  @GetMapping("/orders/{id}")
  @CircuitBreaker(name = "orders-service", fallbackMethod = "getOrderFallback")
  public Order getOrder(@PathVariable Long id) {
    return ordersClient.getOrder(id);
  }
  
  private Order getOrderFallback(Long id, Throwable t) {
    return new Order(id, "FALLBACK", "Service unavailable");
  }
}
```

**Fallback**:
- **Return cached data** (например: **Redis cache**).
- **Return default value** (например: **empty list**).
- **Return error** (например: **503 Service Unavailable**).

**Вывод**: **Circuit breaker** = **защита** от **cascade failure**. **3 состояния**: **Closed** (норма), **Open** (fail fast), **Half-open** (testing). **Порог**: **failure count** > **N** → **Open**. **Resilience4j**: **@CircuitBreaker** + **fallbackMethod**. **Fallback**: **cached data**, **default value**, **error**.

### 12. Что такое graceful shutdown и как его настроить

**Graceful shutdown** = **корректное** **остановка** **application** (не **kill** **process**).

**Проблема**:
- **Kill process** → **in-flight requests** **теряются**.
- **DB connection** **не закрыта** → **data loss**.
- **K8s** **delete pod** → **connection** **drop**.

**Graceful shutdown (Spring Boot)**:
```yaml
# application.yml:
server:
  shutdown: graceful  # Graceful shutdown

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s  # 30s timeout
```

**Flow**:
1. **Stop accepting new requests** (не **reject** **in-flight**).
2. **Wait** для **in-flight requests** (например: **30 сек**).
3. **Close DB connections** (например: **HikariCP**).
4. **Flush logs** (например: **Logback**).
5. **Exit** (process **terminated**).

**@PreDestroy**:
```java
@Component
public class ShutdownHook {
  @PreDestroy
  public void cleanup() {
    // Close resources:
    httpClient.close();
    cache.clear();
    log.info("Shutdown complete");
  }
}
```

**K8s graceful shutdown**:
```yaml
# deployment.yaml:
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 30  # 30s
      containers:
      - name: app
        lifecycle:
          preStop:
            exec:
              command: ["sleep", "5"]  # Wait for LB to remove pod
```
- **preStop**: **sleep 5** (wait for **load balancer** **remove** **pod**).
- **SIGTERM**: **Spring Boot** **graceful shutdown** (30 сек).

**Вывод**: **Graceful shutdown** = **корректное** **остановка** (не **kill** **process**). **Spring Boot**: **server.shutdown: graceful** + **timeout-per-shutdown-phase**. **Flow**: **stop new requests** → **wait in-flight** → **close DB** → **flush logs** → **exit**. **K8s**: **terminationGracePeriodSeconds** + **preStop** (sleep).

### 13. Как настроить health checks в Spring Boot

**Health checks** = **проверка** **health** **application** (например: **/actuator/health**).

**Spring Boot Actuator**:
```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

**application.yml**:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: always  # Show details
  health:
    db:
      enabled: true  # DB health check
    disk-space:
      enabled: true  # Disk space check
```

**Health indicators**:
```java
@Component
public class CustomHealthIndicator implements HealthIndicator {
  @Override
  public Health health() {
    // Check custom resource:
    if (redis.ping()) {
      return Health.up().withDetail("redis", "OK").build();
    } else {
      return Health.down().withDetail("redis", "FAIL").build();
    }
  }
}
```

**K8s probes**:
```yaml
# deployment.yaml:
spec:
  template:
    spec:
      containers:
      - name: app
        livenessProbe:  # Is pod alive?
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:  # Is pod ready?
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

**Liveness vs Readiness**:
- **Liveness**: **is pod alive?** (если **fail** → **restart pod**).
- **Readiness**: **is pod ready?** (если **fail** → **remove from LB**).

**Вывод**: **Health checks** = **проверка** **health** **application**. **Spring Boot Actuator**: **/actuator/health** (DB, disk, custom). **K8s**: **liveness probe** (restart) + **readiness probe** (LB). **Custom health indicator**: **HealthIndicator** interface.

### 14. Что такое config management и как его настроить

**Config management** = **управление** **configuration** **application** (env vars, properties, secrets).

**Проблемы**:
- **Config** в **code** (hardcode) → **hard to change**.
- **Config** в **file** (например: **application.yml**) → **hard to update** (restart).
- **Secrets** в **code** → **security risk**.

**Подходы**:
1. **Env vars** (12-factor): **`DB_URL=...`**, **`DB_PASS=...`**.
2. **Config server** (Spring Cloud Config): **centralized** config (Git-based).
3. **Secrets manager** (AWS Secrets Manager, Vault): **secrets** (DB password, API keys).
4. **Feature flags** (LaunchDarkly, Unleash): **dynamic** config (без **restart**).

**Spring Cloud Config**:
```yaml
# application.yml:
spring:
  cloud:
    config:
      uri: http://config-server:8888
      profile: prod
```
- **Config server**: **Git-based** (например: **GitHub** repo).
- **Client**: **pull** config от **config server**.
- **Refresh**: **/actuator/refresh** (без **restart**).

**AWS Secrets Manager**:
```java
// Read secret:
SecretsManagerClient client = SecretsManagerClient.builder()
  .region(Region.US_EAST_1)
  .build();
GetSecretValueResponse secret = client.getSecretValue(
  GetSecretValueRequest.builder()
    .secretId("prod/db-password")
    .build()
);
String password = secret.secretString();
```

**Вывод**: **Config management** = **управление** **configuration** (env vars, properties, secrets). **Env vars** (12-factor). **Spring Cloud Config** (Git-based, **/actuator/refresh**). **Secrets manager** (AWS, Vault). **Feature flags** (dynamic config).

### 15. Как настроить logging и metrics в cloud-native application

**Cloud-native logging** = **structured** (JSON) + **stdout** (не файл) + **centralized** (Loki, ELK).

**Spring Boot logging**:
```yaml
# application.yml:
logging:
  level:
    root: INFO
    com.example: DEBUG
  pattern:
    console: "%d{ISO8601} %-5level [%thread] %logger{36} - %msg%n"
```

**Structured logging (JSON)**:
```xml
<!-- logback-spring.xml: -->
<appender name="JSON" class="net.logstash.logback.LogstashEncoder">
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"app":"orders-service"}</customFields>
  </encoder>
</appender>
```

**Metrics (Micrometer + Prometheus)**:
```java
// Micrometer:
@Autowired private MeterRegistry meterRegistry;

// Timer:
Timer.builder("orders.create")
  .tag("status", "success")
  .register(meterRegistry)
  .record(() -> orderService.create(order));
```

**Prometheus endpoint**:
```yaml
# application.yml:
management:
  endpoints:
    web:
      exposure:
        include: prometheus
  metrics:
    tags:
      application: ${SPRING_APPLICATION_NAME}
```

**K8s + Prometheus**:
```yaml
# prometheus config:
scrape_configs:
  - job_name: orders-service
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: "jvm_.*"
        action: keep
```

**Вывод**: **Cloud-native logging** = **structured** (JSON) + **stdout** + **centralized** (Loki, ELK). **Spring Boot**: **logback** + **LogstashEncoder**. **Metrics**: **Micrometer** + **Prometheus** (/**actuator/prometheus**). **K8s**: **Prometheus** **scrape** (pod **labels**).


### 16. Что такое service mesh и когда он нужен

**Service mesh** = **инфраструктурный** **слой** для **управления** **коммуникацией** между **сервисами**.

**Когда нужен:**
1. **N** **сервисов** → **N×N** **connections** (управление **сложное**).
2. **mTLS** (mutual TLS) между **сервисами**.
3. **Traffic management** (canary, blue/green).
4. **Observability** (traces, metrics, logs).

**Компоненты**:
- **Sidecar** (например: **Envoy**) — **proxy** рядом с **сервисом**.
- **Control plane** (например: **Istiod**) — **управление** **sidecar**.
- **Data plane** (sidecars) — **проксирование** **трафика**.

**Istio**:
```yaml
# VirtualService:
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: orders-service
spec:
  hosts:
  - orders-service
  http:
  - route:
    - destination:
        host: orders-service
        subset: v1
      weight: 90
    - destination:
        host: orders-service
        subset: v2
      weight: 10
```

**Вывод**: **Service mesh** = **инфраструктурный** **слой** для **управления** **коммуникацией** между **сервисами**. **Компоненты**: **sidecar** (Envoy), **control plane** (Istiod). **Когда нужен**: **N** **сервисов**, **mTLS**, **traffic management**, **observability**.

### 17. Что такое canary deployment и как его настроить

**Canary deployment** = **постепенное** **развертывание** **нового** **verсии** (10% **трафика** → **new** **version**).

**Process**:
1. **Deploy** **new** **version** (10% **подов**).
2. **Route** **10%** **трафика** на **new** **version**.
3. **Monitor** (metrics, errors).
4. **Increase** **traffic** (20%, 50%, 100%).
5. **Rollback** (если **errors**).

**K8s**:
```yaml
# Deployment (canary):
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-service-canary
spec:
  replicas: 1  # 1 canary pod
  template:
    spec:
      containers:
      - name: orders-service
        image: orders-service:2.0  # New version
```

**Istio (canary)**:
```yaml
# VirtualService:
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: orders-service
spec:
  hosts:
  - orders-service
  http:
  - route:
    - destination:
        host: orders-service
        subset: v1
      weight: 90
    - destination:
        host: orders-service
        subset: v2
      weight: 10
```

**Вывод**: **Canary deployment** = **постепенное** **развертывание** **нового** **verсии** (10% → 100%). **Process**: **deploy** → **route** → **monitor** → **increase** → **rollback**. **K8s**: **Deployment** (canary **подов**). **Istio**: **VirtualService** (weight).

### 18. Что такое blue/green deployment и чем он отличается от canary

**Blue/green deployment** = **2** **полных** **окружения** (blue = **current**, green = **new**).

**Process**:
1. **Blue** = **current** **version** (100% **трафика**).
2. **Green** = **new** **version** (deploy).
3. **Test** **green** (smoke tests).
4. **Switch** **traffic** на **green** (100%).
5. **Rollback** = **switch** back на **blue**.

**Canary vs Blue/Green**:
| Фича | Canary | Blue/Green |
|------|--------|------------|
| Traffic | **10%** → **100%** (постепенно) | **100%** → **100%** (резко) |
| Rollback | **Постепенный** (убрать **new** **поды**) | **Мгновенный** (switch back) |
| Cost | **Lower** (10% **подов**) | **Higher** (2× **подов**) |
| Risk | **Lower** (10% **трафика**) | **Higher** (100% **трафика**) |

**Вывод**: **Blue/green** = **2** **полных** **окружения** (blue = **current**, green = **new**). **Canary** = **постепенное** (10% → 100%). **Rollback**: **canary** (постепенный), **blue/green** (мгновенный). **Cost**: **canary** (lower), **blue/green** (higher).

### 19. Что такое Helm charts и как их использовать

**Helm** = **package manager** для **K8s**.
**Helm chart** = **пакет** **K8s** **ресурсов** (Deployment, Service, ConfigMap, Secret).

**Структура**:
```
mychart/
  Chart.yaml       # Chart metadata
  values.yaml      # Default values
  templates/       # K8s manifests
    deployment.yaml
    service.yaml
    configmap.yaml
    secret.yaml
```

**Chart.yaml**:
```yaml
apiVersion: v2
name: orders-service
description: Orders service
version: 1.0.0
appVersion: "1.0.0"
```

**values.yaml**:
```yaml
replicaCount: 3
image:
  repository: orders-service
  tag: "1.0.0"
service:
  type: ClusterIP
  port: 8080
```

**Install**:
```bash
helm install orders-service ./mychart
helm install orders-service ./mychart --set replicaCount=5
```

**Upgrade**:
```bash
helm upgrade orders-service ./mychart
```

**Uninstall**:
```bash
helm uninstall orders-service
```

**Вывод**: **Helm** = **package manager** для **K8s**. **Helm chart** = **пакет** **K8s** **ресурсов**. **Структура**: **Chart.yaml**, **values.yaml**, **templates/**. **Install**: **helm install**. **Upgrade**: **helm upgrade**. **Uninstall**: **helm uninstall**.

### 20. Как настроить secrets management в Kubernetes

**Secrets** = **сensible** **данные** (passwords, API keys, TLS certificates).

**К8s Secrets**:
```yaml
# Secret:
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=  # base64("admin")
  password: cGFzc3dvcmQ=  # base64("password")
```

**Использование**:
```yaml
# Deployment:
spec:
  containers:
  - name: app
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

**Внешние секреты**:
- **AWS Secrets Manager**
- **HashiCorp Vault**
- **Google Secret Manager**

**CSM** (CSI Secrets Store):
```yaml
# SecretProviderClass:
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db-secret-provider
spec:
  provider: aws-secrets-manager
  parameters:
    secretId: "prod/db-password"
```

**Вывод**: **Secrets** = **сensible** **данные**. **К8s Secrets**: **base64** (не **encryption**). **Внешние**: **AWS Secrets Manager**, **Vault**, **Google Secret Manager**. **CSM** (CSI Secrets Store): **внешние** **секреты** → **K8s**.
