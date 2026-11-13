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
