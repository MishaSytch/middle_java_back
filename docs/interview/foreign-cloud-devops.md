# Иностранные компании: Облако и DevOps (AWS, GCP, Azure, Terraform, K8s)

Раздел — тематический: облако и DevOps-инструменты, которые требуют на Middle/Middle+ в иностранных (глобальных) компаниях. В US-компаниях (Amazon, Netflix, Uber, Airbnb, Stripe) AWS-интеграция **обязательна**; в EU/UK — чаще multi-cloud (AWS + GCP); в Israel — AWS + GCP (ML); в Singapore — AWS (основное) + GCP.

> Ключевое отличие от локальных: в global-компаниях middle-разработчик **сам** поднимает инфраструктуру (Terraform), **сам** настраивает CI/CD, **сам** debug-ит Kubernetes. В локальных компаниях часто есть выделенный DevOps-инженер.

### 1. Какие AWS-сервисы обязаны знать middle-разработчик в US-компаниях

**Обязательный минимум** (Amazon, Netflix, Uber, Airbnb, Stripe):

- **EC2** (Elastic Compute Cloud) — виртуальные машины в AWS. **Типы инстансов**: `t3.micro` (dev), `m5.large` (general), `c5.xlarge` (compute-optimized), `r5.xlarge` (memory-optimized). **Instance store** (эфемерное хранилище, теряется при stop) vs **EBS** (Elastic Block Store — персистентное). **Auto Scaling Group** (ASG) — автоматическое масштабирование (min 2, max 10, target CPU 70%).
- **S3** (Simple Storage Service) — объектное хранилище. **BUCKETS** (контейнеры, глобально уникальные имена), **objects** (key + value), **versions** (версии объектов), **lifecycle** (перенос в Glacier через 30 дней), **CORS** (Cross-Origin Resource Sharing), **pre-signed URLs** (временные ссылки, TTL 15 мин – 7 дней). **Storage classes**: `STANDARD` (hot), `GLACIER` (cold, 1 мин retrieval), `DEEP ARCHIVE` (coldest, 12 часов retrieval). **Вопросы**: «Как настроить S3 для multi-region?», «Как использовать pre-signed URLs?», «Как настроить lifecycle policy?».
- **RDS** (Relational Database Service) — managed-БД (PostgreSQL, MySQL, MariaDB, Oracle, SQL Server). **Multi-AZ** (2 AZ, automatic failover, RTO < 1 мин), **Read replicas** (до 15, asynchronous replication), **storage** (GP3, до 64 TB), **backup** (automated, 1–35 days, PITR — Point-In-Time Recovery). **Вопросы**: «Как масштабировать RDS на 10×?», «Как настроить read replicas?», «RDS vs Aurora — trade-offs?».
- **DynamoDB** (NoSQL, key-value) — **partition key** (hash, до 4000 байт) + **sort key** (range, до 4000 байт), **provisioned capacity** (RCU/WCU — Read/Write Capacity Units, 1 RCU = 1 read/sec 4 KB) vs **on-demand** (pay per request), **indexes**: **GSI** (Global Secondary Index, по другому ключу) + **LSI** (Local Secondary Index, по sort key), **TTL** (Time To Live, авто-удаление), **streams** (CDC — Change Data Capture). **Вопросы**: «DynamoDB vs PostgreSQL — когда что?», «Как настроить GSI?», «Как использовать TTL?».
- **Lambda** (serverless, function-as-a-service) — **code** (Java, Python, Node.js, Go, .NET), **triggers** (S3, SQS, SNS, API Gateway, CloudWatch Events, DynamoDB Streams), **memory** (128 MB – 10 GB, влияет на CPU), **timeout** (15 мин максимум), **invocation** (sync, async, event), **cold start** (100–300 мс для Java, 50–100 мс для Node.js), **concurrency** (1000 по умолчанию, можно увеличить). **Вопросы**: «Как использовать Lambda для event-driven?», «Как настроить concurrency?», «Lambda vs ECS — trade-offs?».
- **SQS** (Simple Queue Service) — message queue (FIFO или Standard). **Standard**: at-least-once, high throughput, no order. **FIFO**: exactly-once, order, lower throughput. **DLQ** (Dead Letter Queue — для failed messages, max receive count 10). **Visibility timeout** (30 сек – 12 часов). **Вопросы**: «SQS vs SNS — когда что?», «Как настроить DLQ?», «FIFO vs Standard — trade-offs?».
- **SNS** (Simple Notification Service) — pub/sub (publish/subscribe). **Topics** (каналы), **subscribers** (SQS, Lambda, email, SMS), **protocols** (SQS, Lambda, email, SMS, HTTP/S). **Вопросы**: «SNS vs SQS — когда что?», «Как настроить fan-out (1 publisher → 10 subscribers)?».
- **ECS** (Elastic Container Service) — Docker-контейнеры (без Kubernetes). **Services** (deploy + scale), **Tasks** (контейнер + ресурсы), **Clusters** (группа задач), **Load Balancer** (ALB/NLB), **Auto Scaling** (по CPU/memory). **Вопросы**: «ECS vs EKS — когда что?», «Как настроить auto-scaling?».
- **EKS** (Elastic Kubernetes Service) — managed Kubernetes. **Control plane** (AWS управляет), **worker nodes** (EC2, ты управляешь), **add-ons** (CoreDNS, kube-proxy, VPC CNI), **irsa** (IAM Roles for Service Accounts — least-privilege). **Вопросы**: «EKS vs ECS — trade-offs?», «Как настроить IRSA?», «Как масштабировать EKS?».
- **CloudFront** (CDN) — **edge locations** (200+ worldwide), **origin** (S3, EC2, ELB), **cache behavior** (TTL, headers, query strings), **invalidation** (очистка кэша), **WAF** (Web Application Firewall), **signed URLs** (защищённый доступ). **Вопросы**: «Как настроить CloudFront для S3?», «Как использовать WAF?», «CloudFront vs CloudFlare — trade-offs?».
- **IAM** (Identity and Access Management) — **Users** (люди), **Roles** (сервисы, assumed), **Policies** (JSON, Allow/Deny), **Groups** (группа пользователей), **MFA** (Multi-Factor Authentication), **STS** (Security Token Service — временные токены). **Least privilege** (минимальные привилегии). **Вопросы**: «Как настроить IAM policy для least-privilege?», «IAM User vs Role — когда что?», «Как использовать STS?».
- **VPC** (Virtual Private Cloud) — **Subnets** (Public — с Internet Gateway, Private — только NAT Gateway), **Security Groups** (stateful, ingress/egress), **Network ACLs** (stateless, до 20 правил), **Route Tables** (маршрутизация), **NAT Gateway** (доступ в интернет из private subnet), **Peering** (связь между VPC), **Transit Gateway** (hub-and-spoke). **Вопросы**: «Как настроить multi-VPC architecture?», «Security Group vs NACL — trade-offs?», «Как использовать Transit Gateway?».
- **ELB** (Elastic Load Balancer) — **ALB** (Application Layer, HTTP/HTTPS, path-based routing), **NLB** (Network Layer, TCP/UDP, high performance), **GLB** (Global Load Balancer, multi-region). **Health checks** (проверка доступности), **Target groups** (группа инстансов), **Sticky sessions** (session affinity). **Вопросы**: «ALB vs NLB — когда что?», «Как настроить health checks?», «Как использовать sticky sessions?».
- **Route 53** (DNS) — **Record types** (A, AAAA, CNAME, MX, TXT, NS, SOA), **Routing policies** (Simple, Weighted, Latency-based, Failover, Geolocation), **Health checks** (проверка доступности), **Traffic Flow** (complexc routing), **DNSSEC** (защита от спуфинга). **Вопросы**: «Как настроить failover с Route 53?», «Weighted vs Latency-based — когда что?», «Как использовать DNSSEC?».
- **CloudWatch** (monitoring) — **Metrics** (CPU, memory, network, custom), **Alarms** (уведомления при превышении порога), **Logs** (CloudWatch Logs, structured), **Dashboards** (визуализация), **Events** (CloudWatch Events — event-driven), **Insights** (аномалии). **Вопросы**: «Как настроить CloudWatch для microservices?», «Как использовать custom metrics?», «CloudWatch vs Datadog — trade-offs?».
- **Kinesis** (streaming) — **Streams** (real-time, до 1000 shards, 10 MB/s write), **Data Firehose** (delivery к S3/Redshift/ES), **Analytics** (SQL поверх стрима). **Вопросы**: «Kinesis vs Kafka — trade-offs?», «Как настроить Kinesis Data Firehose?», «Shard management — как масштабировать?».
- **Aurora** (PostgreSQL/MySQL-compatible, managed) — **6× faster** чем vanilla MySQL, **storage auto-scaling** (до 128 TB), **5 read replicas** (synchronous, RTO < 1 мин), **Multi-Master** (write на любой реплике), **Serverless** (auto-scaling, pay per ACU — Aurora Capacity Unit). **Вопросы**: «Aurora vs RDS — trade-offs?», «Как настроить Multi-Master?», «Aurora Serverless — когда использовать?».
- **Redshift** (data warehouse) — **MPP** (Massively Parallel Processing), **columnar storage** (колонное хранение), **COPY** (загрузка из S3), **UNLOAD** (выгрузка в S3), **Spectrum** (querying Parquet в S3), **RA3 nodes** (RA3.4xlarge — 16 TB storage). **Вопросы**: «Redshift vs BigQuery — trade-offs?», «Как настроить columnar storage?», «RA3 vs RA2 — когда что?».
- **ElastiCache** (Redis/Memcached, managed) — **Redis** (persistent, data structures, pub/sub), **Memcached** (volatile, simple cache), **Cluster mode** (multi-AZ, auto-scaling), **Encryption** (at rest + in transit), **Parameter groups** (configuration). **Вопросы**: «Redis vs Memcached — когда что?», «Как настроить cluster mode?», «ElastiCache vs self-managed Redis — trade-offs?».

**Пример ответа на интервью**: «В прошлой компании мы использовали **AWS** как основной cloud. Для **compute** — **EKS** (Kubernetes, 3 AZ, min 3 worker nodes), для **DB** — **Aurora** (PostgreSQL, 5 read replicas, Multi-AZ), для **cache** — **ElastiCache** (Redis, cluster mode, 2 shards), для **messaging** — **SQS** (FIFO, DLQ для failed messages), для **CDN** — **CloudFront** (TTL 1 час, WAF для DDoS protection), для **monitoring** — **CloudWatch** (metrics + logs + alarms). **IAM** — least privilege (каждый сервис — отдельный Role, policy только на нужные ресурсы). **VPC** — 3 public subnets + 3 private subnets, Security Groups (ингресс только с ALB, эгресс только в DB). **Cost optimization** — Spot Instances для batch (экономия 60–90%), S3 lifecycle (перенос в Glacier через 90 дней)».

### 2. Multi-cloud и GCP/Azure: когда и почему используют

**GCP** (Google Cloud Platform) — основной в **Google** (BigQuery, Cloud Functions, Cloud Run, GKE, Pub/Sub, Cloud Storage, Spanner). **Почему GCP**: **ML** (TensorFlow, Vertex AI), **data analytics** (BigQuery — petabyte-scale, columnar), **serverless** (Cloud Functions, Cloud Run — cold start < 1 сек), **global infrastructure** (30+ regions, 90+ zones). **Вопросы**: «GCP vs AWS — trade-offs?», «Как использовать BigQuery для analytics?», «Cloud Run vs Lambda — trade-offs?».

**Azure** (Microsoft) — основной в **Microsoft** (AKS, Azure Functions, Cosmos DB, Service Bus, Key Vault, Event Hubs). **Почему Azure**: **enterprise** (Active Directory, Intune, Microsoft 365 integration), **hybrid cloud** (Azure Stack — private cloud в дата-центре), **compliance** (HIPAA, FedRAMP, ISO 27001), **data lake** (ADLS — Azure Data Lake Storage). **Вопросы**: «Azure vs AWS — trade-offs?», «Cosmos DB vs DynamoDB — trade-offs?», «Как настроить hybrid cloud с Azure Stack?».

**Multi-cloud** (AWS + GCP + Azure) — **Netflix** (AWS основной + GCP experiments), **Uber** (AWS основной + GCP ML), **Airbnb** (AWS основной). **Почему multi-cloud**: **avoid lock-in** (не зависеть от одного провайдера), **best-of-breed** (лучшие сервисы из каждого), **regional compliance** (GDPR — EU regions, HIPAA — US regions), **cost optimization** (разные цены за разные ресурсы). **Trade-offs**: **complexity** (3 набора tools, 3 набора IAM, 3 набора billing), **data transfer** (между облаками — дорого, $0.09/GB), **consistency** (разные SLA, разные API). **Вопросы**: «Почему AWS, а не GCP?», «Как мигрировать с AWS на GCP?», «Какие trade-offs между multi-cloud и single-cloud?».

**Пример ответа на интервью**: «В прошлой компании мы использовали **multi-cloud**: **AWS** (основное, production) + **GCP** (ML, analytics). **Почему**: **avoid lock-in** (не зависеть от AWS), **best-of-breed** (GCP BigQuery для analytics — дешевле AWS Redshift), **cost optimization** (GCP для ML — дешевле AWS SageMaker). **Trade-offs**: **complexity** (2 набора tools, 2 набора IAM), **data transfer** (между облаками — $0.09/GB, для 10 TB — $900/месяц). **Решение**: **data** остаётся в AWS (RDS, S3), **analytics** — в GCP (BigQuery, sync через Dataflow). **Result**: экономили **$5K/месяц** на analytics, но **complexity** увеличилась (2 CI/CD pipeline, 2 мониторинга)».

### 3. Infrastructure as Code (IaC): Terraform, CloudFormation, Pulumi, Ansible

**Terraform** (HashiCorp) — **основной** в US-компаниях (Netflix, Uber, Airbnb, Stripe). **Core concepts**: **HCL** (HashiCorp Configuration Language, декларативный синтаксис), **Providers** (AWS, GCP, Azure, Kubernetes, etc.), **Resources** (конкретные объекты: `aws_instance`, `aws_s3_bucket`), **Modules** (переиспользуемые блоки), **State** (`terraform.tfstate`, JSON-файл с текущим состоянием), **Workspaces** (разные среды: dev, staging, prod), **Backend** (S3, для хранения state). **Вопросы**: «Как спроектировать Terraform module?», «Как управлять state в Terraform?», «Terraform vs Pulumi vs CloudFormation — trade-offs?».

```hcl
# example: VPC + subnets + security groups
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "prod-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
}

resource "aws_instance" "app" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.app.id]
  tags = { Name = "app-${count.index}", Env = var.env }
}
```

**CloudFormation** (AWS-native) — **YAML/JSON**, только для AWS. **Преимущества**: **native** (интеграция с AWS, no extra tools), **free** (без дополнительных затрат), **stacks** (логические группы ресурсов), **drift detection** (обнаружение ручных изменений). **Недостатки**: **only AWS** (не работает с GCP/Azure), **complex syntax** (YAML, нет циклов/условий), **no modularization** (сложно переиспользовать код). **Вопросы**: «Terraform vs CloudFormation — trade-offs?», «Как использовать CloudFormation для multi-AZ?».

**Pulumi** (Python/Go/TypeScript/C#) — **IaC на обычных языках**. **Преимущества**: **code** (Python/Go/TS, не HCL), **cic** (циклы, условия, функции — как в обычном коде), **multi-cloud** (AWS, GCP, Azure, K8s), **state** (S3, Azure Blob, GCS). **Недостатки**: **newer** (менее зрелый, чем Terraform), **community** (меньше модулей), **learning curve** (нужно знать язык). **Вопросы**: «Terraform vs Pulumi — trade-offs?», «Как использовать Pulumi для multi-cloud?».

**Ansible** (configuration management) — **agentless** (SSH, no agent на целевой машине), **YAML** (playbooks, tasks), **roles** (переиспользуемые блоки), **inventory** (список хостов), **modules** (tasks: `apt`, `copy`, `template`, `service`). **Вопросы**: «Terraform vs Ansible — когда что?», «Как использовать Ansible для configuration?».

**Разделение ответственности**: **Terraform** — **infrastructure** (VPC, EC2, RDS, S3), **Ansible** — **configuration** (packages, services, users, firewall rules). **Пример**: Terraform создаёт EC2, Ansible настраивает Nginx, устанавливает пакет, запускает сервис.

**Пример ответа на интервью**: «В прошлой компании мы использовали **Terraform** для **infrastructure** (VPC, EKS, RDS, S3, CloudFront) и **Ansible** для **configuration** (Nginx, packages, users). **Terraform**: **modules** (vpc, eks, rds, s3), **state** в **S3** (encrypted, versioning), **workspaces** (dev, staging, prod). **Ansible**: **playbooks** (nginx, packages, users), **roles** (переиспользуемые), **inventory** (dynamic, из AWS). **CI/CD**: **GitHub Actions** запускает `terraform plan` + `terraform apply` (при merge в main), **Ansible** — при деплое. **Result**: infrastructure **as code** (воспроизводимость), **drift detection** (Terraform показывает, что изменилось вручную), **cost** (Spot Instances, S3 lifecycle)».

### 4. CI/CD: GitHub Actions, GitLab CI, Jenkins, CircleCI, ArgoCD, Spinnaker

**GitHub Actions** (основной в US-компаниях: Netflix, Uber, Airbnb, Stripe) — **workflows** (`.github/workflows/*.yml`), **jobs** (steps, matrix), **runners** (GitHub-hosted или self-hosted), **secrets** (encrypted), **artifacts** (build outputs), **caching** (npm, Maven, Gradle). **Вопросы**: «Как настроить CI/CD pipeline?», «Как использовать feature flags?», «Как делать canary deployment?».

```yaml
# example: .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - run: mvn clean package
      - uses: actions/upload-artifact@v4
        with:
          name: build
          path: target/*.jar
  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: build
          path: target/
      - run: mvn test
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to AWS
        run: |
          aws s3 cp target/*.jar s3://my-bucket/
          aws deploy create-deployment \
            --application-name my-app \
            --deployment-group-name my-group \
            --s3-location s3://my-bucket/*.jar
```

**GitLab CI** (Uber, Airbnb) — **`.gitlab-ci.yml`**, **stages** (build, test, deploy), **runners** (shared или specific), **variables** (encrypted), **artifacts** (build outputs), **caching** (npm, Maven, Gradle). **Вопросы**: «GitLab CI vs GitHub Actions — trade-offs?», «Как настроить multi-stage pipeline?».

**Jenkins** (legacy, многие компании) — **pipeline** (Jenkinsfile, Groovy), **plugins** (2000+), **agents** (build workers), **credentials** (encrypted), **artifacts** (build outputs). **Преимущества**: **flexible** (Groovy, any logic), **plugins** (огромная экосистема). **Недостатки**: **complex** (сложно настроить), **maintenance** (нужно обновлять plugins), **scalability** (медленно на больших проектах). **Вопросы**: «Jenkins vs GitHub Actions — trade-offs?», «Как настроить Jenkins pipeline?».

**CircleCI** (Stripe) — **`.circleci/config.yml`**, **jobs** (steps), **orbs** (переиспользуемые блоки), **context** (secrets), **artifacts** (build outputs), **caching** (npm, Maven, Gradle). **Вопросы**: «CircleCI vs GitHub Actions — trade-offs?», «Как использовать orbs?».

**ArgoCD** (Kubernetes CD) — **GitOps** (declarative, Git как source of truth), **Applications** (K8s manifests), **Sync** (auto или manual), **Helm** (charts), **Kustomize** (config management), **notifications** (Slack, email). **Вопросы**: «ArgoCD vs manual deploy — trade-offs?», «Как настроить GitOps с ArgoCD?».

**Spinnaker** (Netflix, multi-cloud) — **pipelines** (stages, tasks), **triggers** (Git, webhook), **artifacts** (Docker images), **environments** (test, staging, prod), **rollback** (auto или manual). **Вопросы**: «Spinnaker vs ArgoCD — trade-offs?», «Как настроить multi-cloud deployment с Spinnaker?».

**Стратегии деплоя**: **Rolling update** (по одному pod, zero-downtime), **Blue-Green** (2 среды, переключение трафика), **Canary** (10% трафика на новую версию, потом 50%, потом 100%), **Recreate** (убрать старые, запустить новые, downtime). **Вопросы**: «Rolling vs Blue-Green vs Canary — trade-offs?», «Как настроить canary deployment?», «Как откатить деплой?».

**Feature flags** (LaunchDarkly, Unleash, Flagd) — **enable/disable** фичи без деплоя, **A/B testing** (50% пользователей — версия A, 50% — версия B), **gradual rollout** (10% → 50% → 100%), **kill switch** (быстро отключить фичу при проблемах). **Вопросы**: «Как использовать feature flags?», «LaunchDarkly vs Unleash — trade-offs?».

**Пример ответа на интервью**: «В прошлой компании мы использовали **GitHub Actions** для **CI/CD**. **CI**: `mvn clean package` (build) + `mvn test` (tests) + `sonarqube` (code quality). **CD**: **ArgoCD** (GitOps, K8s). **Стратегия**: **canary deployment** (10% → 50% → 100%, 5 мин на каждом этапе). **Feature flags**: **Unleash** (self-hosted), enable/disable фичи без деплоя. **Rollback**: **auto** (если error rate > 1%, ArgoCD откатывает). **Result**: **zero-downtime** deployments, **fast rollback** (< 1 мин), **feature flags** (можно отключить фичу без деплоя)».

### 5. Kubernetes: EKS, GKE, AKS — что должен знать middle

**Core objects**: **Pod** (минимальная единица, 1+ контейнеры), **Deployment** (desired state, replicas, rolling update), **Service** (stable IP, load balancing), **Ingress** (HTTP routing, path-based), **ConfigMap** (config, key-value), **Secret** (sensitive data, base64), **Namespace** (логическое разделение), **PVC** (Persistent Volume Claim, storage). **Вопросы**: «Как настроить zero-downtime deployment?», «Как управлять secrets в K8s?», «Как debug-ить failing pod?».

```yaml
# example: Deployment + Service + Ingress
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-svc
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: my-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-svc
            port:
              number: 80
```

**Helm** (charts) — **package manager** для K8s. **Chart** (пакет: templates, values.yaml), **Release** (конкретный инстанс чарта), **Values** (конфигурация, override). **Вопросы**: «Как создать Helm chart?», «Helm vs Kustomize — trade-offs?».

**Kustomize** (config management) — **base** + **overlays** (dev, staging, prod), **no templates** (plain YAML), **patch** (override полей). **Вопросы**: «Kustomize vs Helm — trade-offs?», «Как настроить overlays?».

**HPA** (Horizontal Pod Autoscaler) — **auto-scaling** по CPU/memory (target 70%), **min 3, max 10**, **scale up** (быстро, 30 сек), **scale down** (медленно, 5 мин). **Вопросы**: «Как настроить HPA?», «HPA vs VPA — trade-offs?».

**VPA** (Vertical Pod Autoscaler) — **auto-scaling** по ресурсам (CPU, memory), **recommendations** (suggestion, не auto-apply), **recreate** (при изменении ресурсов pod перезапускается). **Вопросы**: «VPA vs HPA — когда что?», «Как использовать VPA recommendations?».

**NetworkPolicy** (network security) — **ingress** (какие поды могут подключаться), **egress** (какие поды могут обращаться), **default deny** (закрыть всё, открыть только нужное). **Вопросы**: «Как настроить NetworkPolicy?», «Default deny vs allow — trade-offs?».

**RBAC** (access control) — **Roles** (права в namespace), **ClusterRoles** (права на весь cluster), **RoleBindings** (привязка Role к User/ServiceAccount), **ServiceAccount** (для pod'ов). **Вопросы**: «Как настроить RBAC?», «RBAC vs NetworkPolicy — когда что?».

**Debugging**: `kubectl get pods` (статус), `kubectl describe pod <name>` (events, probes), `kubectl logs <pod>` (логи), `kubectl exec -it <pod> -- /bin/bash` (внутрь pod), `kubectl port-forward <pod> 8080:8080` (локальный порт), `kubectl top pods` (CPU/memory). **Вопросы**: «Как debug-ить failing pod?», `CrashLoopBackOff` — что делать?», `ImagePullBackOff` — что делать?».

**Пример ответа на интервью**: «В прошлой компании мы использовали **EKS** (Kubernetes, 3 AZ, min 3 worker nodes). **Deployments**: 3 replicas, **HPA** (CPU 70%, min 3, max 10), **readiness/liveness probes** (HTTP /health). **Ingress**: **NGINX** (path-based routing, TLS termination). **Secrets**: **AWS Secrets Manager** (external, CSM — CSI Secrets Store). **NetworkPolicy**: **default deny** (закрыть всё, открыть только нужное). **RBAC**: **least privilege** (каждый сервис — отдельный ServiceAccount, Role только на нужные ресурсы). **Debugging**: `kubectl describe pod` (events), `kubectl logs` (логи), `kubectl exec` (внутрь pod). **Result**: **zero-downtime** deployments (rolling update), **auto-scaling** (HPA), **security** (NetworkPolicy, RBAC)».

### 6. Observability: Prometheus, Grafana, ELK, Jaeger, OpenTelemetry, Datadog

**Prometheus** (metrics) — **pull** (собирает metrics с сервисов), **exposition** (сервисы экспонируют metrics на `/metrics`), **query** (PromQL — язык запросов), **alerts** (Alertmanager, уведомления), **storage** (TSDB — Time Series Database, 15 дней по умолчанию). **Вопросы**: «Как настроить Prometheus для microservices?», «PromQL — как написать query для error rate?».

```yaml
# example: prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'my-app'
    metrics_path: /metrics
    static_configs:
      - targets: ['my-app:8080']
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

**Grafana** (dashboard) — **dashboards** (JSON, visualizations), **panels** (timeseries, heatmap, table, stat), **data sources** (Prometheus, Elasticsearch, Loki, InfluxDB), **alerts** (уведомления, Slack/email), **variables** (dynamic, query-based). **Вопросы**: «Как настроить Grafana dashboard?», «Как использовать variables?».

**ELK / Elasticsearch** (logs) — **Elasticsearch** (full-text search, JSON documents), **Logstash** (ingestion, parsing, enrichment), **Kibana** (UI, visualization). **Стек**: **Filebeat** (collect logs) → **Logstash** (parse) → **Elasticsearch** (store) → **Kibana** (visualize). **Вопросы**: «Как настроить ELK для microservices?», «Как использовать structured logging?».

**Jaeger / Zipkin** (distributed tracing) — **traces** (запрос проходит через 5 сервисов — один trace с 5 spans), **spans** (каждый сервис — свой span), **sampling** (10% запросов, чтобы не перегружать), **UI** (визуализация, where is the bottleneck?). **Вопросы**: «Как настроить distributed tracing?», «Jaeger vs Zipkin — trade-offs?».

**OpenTelemetry** (standard) — **API** (инструментация кода: `Tracer`, `Meter`, `Logger`), **SDK** (реализация: `OpenTelemetrySdk`), **Collector** (агент: `otlp` endpoint, batch export). **Вопросы**: «OpenTelemetry vs Jaeger — trade-offs?», «Как использовать OpenTelemetry в Java?».

```java
// example: OpenTelemetry в Java
import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;

public class MyService {
    private static final Tracer tracer =
        GlobalOpenTelemetry.getTracer("my-service");

    public void processOrder(String orderId) {
        Span span = tracer.spanBuilder("processOrder").startSpan();
        try (Span ignored = span) {
            span.setAttribute("order.id", orderId);
            // business logic
            System.out.println("Processing order " + orderId);
        } finally {
            span.end();
        }
    }
}
```

**Datadog** (commercial) — **APM** (Application Performance Monitoring, traces + metrics), **Logs** (ingestion, search, alerts), **Infrastructure** (host metrics, network), **RUM** (Real User Monitoring, frontend), **Synthetics** (synthetic monitoring, simulated users). **Вопросы**: «Datadog vs self-managed (Prometheus + Grafana + Jaeger) — trade-offs?», «Как настроить Datadog APM?».

**New Relic** (commercial) — **APM**, **Logs**, **Infrastructure**, **Browser** (frontend), **Mobile** (mobile apps). **Вопросы**: «New Relic vs Datadog — trade-offs?».

**Пример ответа на интервью**: «В прошлой компании мы использовали **Prometheus** (metrics) + **Grafana** (dashboard) + **Elasticsearch** (logs) + **Jaeger** (tracing). **Prometheus**: scrape_interval 15s, **Alertmanager** (уведомления в Slack при error rate > 1%). **Grafana**: dashboard (CPU, memory, error rate, latency P95/P99). **Elasticsearch**: **Filebeat** (collect logs) → **Logstash** (parse, JSON) → **Elasticsearch** (store) → **Kibana** (search). **Jaeger**: **OpenTelemetry** (instrumentation, Java SDK), **sampling** 10%. **Result**: **full observability** (metrics + logs + traces), **fast debugging** (trace показывает, где bottleneck), **alerts** (Slack при проблемах)».
