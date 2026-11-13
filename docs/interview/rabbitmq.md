# RabbitMQ

### 1. Что такое RabbitMQ и как он работает

RabbitMQ — это брокер сообщений (message broker), реализующий стандарт **AMQP** (Advanced Message Queuing Protocol). В отличие от Kafka (которая работает с потоками событий, где сообщения накапливаются в партициях), RabbitMQ строит вокруг **очередей (queues)**: продюсер отправляет сообщение на **обменник (exchange)**, а обменник по заданным правилам распределяет его в очереди, из которых консьюмеры его забирают.

**Ключевые понятия:**
- **Exchange** — точка, куда продюсер публикует сообщения. Не хранит сообщения, только маршрутизирует.
- **Queue** — хранит сообщения, пока их не заберёт консьюмер.
- **Binding** — правило, связывающее exchange с очередью (через binding key).
- **Producer / Consumer** — отправитель и получатель сообщений.

```java
// Простой продюсер (Spring AMQP)
@Service
public class OrderProducer {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public void send(OrderEvent event) {
        rabbitTemplate.convertAndSend("orders.exchange", "order.created", event);
    }
}
```

**На собеседовании важно:** объяснить разницу между обменником (маршрутизация) и очередью (хранение), и то, что одно сообщение может попасть в несколько очередей (fanout).

### 2. Какие типы exchange существуют в RabbitMQ

В RabbitMQ есть четыре встроенных типа обменников, различающихся стратегией маршрутизации:

- **Direct** — сообщение попадает в очередь, если binding key **строго совпадает** с routing key. Пример: exchange `orders`, binding key `created` → сообщения с routing key `created` уходят в эту очередь.
- **Fanout** — сообщение дублируется во **все** очереди, привязанные к обменнику. Routing key игнорируется. Используется для broadcast-уведомлений.
- **Topic** — routing key содержит несколько слов, разделённых точками (например, `order.eu.created`). Binding key поддерживает шаблоны: `*` (ровно одно слово), `#` (ноль и более слов). Гибкий topic-based роутинг.
- **Headers** — маршрутизация по заголовкам сообщения, а не по routing key. Редко используется.

```java
// Конфигурация exchange и очередей (Spring Boot)
@Configuration
public class RabbitConfig {
    @Bean
    public TopicExchange ordersExchange() {
        return new TopicExchange("orders.exchange", true, false);
    }

    @Bean
    public Queue createdQueue() {
        return new Queue("orders.created.queue", true);
    }

    @Bean
    public Queue euCreatedQueue() {
        return new Queue("orders.eu.created.queue", true);
    }

    @Bean
    public Binding createdBinding() {
        // '#' — любое кол-во слов до 'created'
        return BindingBuilder.bind(createdQueue()).to(ordersExchange()).with("order.#.created");
    }

    @Bean
    public Binding euCreatedBinding() {
        return BindingBuilder.bind(euCreatedQueue()).to(ordersExchange()).with("order.eu.created");
    }
}
```

```mermaid
flowchart LR
    P[Producer] --> TX[(Topic Exchange)]
    TX -->|order.eu.created| Q1[Queue A]
    TX -->|order.eu.created| Q2[Queue B]
    Q1 --> C1[Consumer 1]
    Q2 --> C2[Consumer 2]
```

### 3. Что такое routing key и как он работает

**Routing key** — это строка, которую продюсер указывает при отправке сообщения. Именно по routing key (и типу обменника) брокер решает, в какую очередь положить сообщение.

- В **direct** exchange: routing key должен **точно совпадать** с binding key.
- В **topic** exchange: routing key — это набор слов через точку (`a.b.c`), а binding key — шаблон со `*` (одно слово) и `#` (ноль или более слов).
- В **fanout**: routing key игнорируется, сообщение уходит во все привязанные очереди.

```java
// Topic exchange: пример routing keys и шаблонов
// routing key: "order.eu.created"
// binding key "order.#"      -> совпало (# = eu.created)
// binding key "order.*"      -> НЕ совпало (ожидалось ровно 2 слова)
// binding key "order.eu.*"   -> совпало
// binding key "order.#.created" -> совпало
rabbitTemplate.convertAndSend("orders.exchange", "order.eu.created", payload);
```

**Важный момент:** если ни один binding key не совпал с routing key (и exchange не fanout), сообщение **теряется** (если не включён `mandatory` flag — тогда брокер вернёт его продюсеру как returned message).

### 4. Что такое очередь (queue) в RabbitMQ и её свойства

**Очередь** — это именованное хранилище сообщений, которое «висит» на обменнике(ах) через binding. Консьюмеры подписываются на очередь и извлекают из неё сообщения.

Ключевые свойства очереди:
- **Name** — имя (если не указано, RabbitMQ создаёт anonymous-очередь и возвращает её имя в confirm-ответе).
- **Durable** — переживает перезапуск брокера (сохраняется на диск).
- **Exclusive** — доступна только одному подключению; удаляется при закрытии соединения.
- **Auto-delete** — автоматически удаляется, когда последняя очередь/консьюмер отписывается.

```java
// Создание очереди с параметрами (JDK client)
ConnectionFactory factory = new CachingConnectionFactory("localhost", 5672);
factory.setUsername("guest");
factory.setPassword("guest");

try (Connection conn = factory.createConnection()) {
    Channel channel = conn.createChannel();
    // durable=true — очередь переживёт рестарт брокера
    channel.queueDeclare("orders.queue", /*durable*/true, /*exclusive*/false, /*autoDelete*/false, null);
}
```

**Почему это важно:** неправильные свойства очереди — частый источник проблем (потеря сообщений при рестарте, конфликты при переиспользовании имени с разными параметрами — ошибка `PRECONDITION_FAILED`).

### 5. Что такое dead letter exchange (DLX) и зачем он нужен

**Dead Letter Exchange (DLX)** — это «обменник для мёртвых» сообщений, в который попадают сообщения, которые:
- просрочились по **TTL** (time-to-live) в очереди,
- превысили **max length** очереди,
- были **отклонены** консьюмером (`basic.nack` / `reject` с `requeue=false`).

Это ключевой механизм, чтобы не терять «проблемные» сообщения, а перенаправить их в отдельную очередь для последующего анализа или ручной обработки.

```java
@Configuration
public class DlxConfig {
    // DLX и «мёртвая» очередь
    @Bean
    public DirectExchange deadExchange() {
        return new DirectExchange("orders.dlx");
    }

    @Bean
    public Queue deadQueue() {
        return new Queue("orders.dead.queue", true);
    }

    @Bean
    public Binding deadBinding() {
        return BindingBuilder.bind(deadQueue()).to(deadExchange()).with("dead");
    }

    // Основная очередь, ссылающаяся на DLX
    @Bean
    public Queue mainQueue() {
        Map<String, Object> args = new HashMap<>();
        args.put("x-dead-letter-exchange", "orders.dlx");
        args.put("x-dead-letter-routing-key", "dead");
        args.put("x-message-ttl", 60000);      // 60 секунд
        args.put("x-max-length", 10000);
        return new Queue("orders.main.queue", true, false, false, args);
    }

    @Bean
    public Binding mainBinding() {
        return BindingBuilder.bind(mainQueue()).to(ordersExchange()).with("order.#");
    }
}
```

**На собеседовании важно:** объяснить три случая попадания в DLX и то, что DLX — это не «очередь», а отдельный exchange, в который можно вешать сколько угодно очередей.

### 6. Как работает delivery и подтверждение (ack/nack) сообщения

Когда консьюмер получает сообщение, он может:
- **ack** (`basic.ack`) — подтвердить, что сообщение обработано. Брокер удаляет его из очереди.
- **nack** (`basic.nack`) — отклонить. Можно указать `requeue` (поставить обратно в очередь) или отправить в DLX.
- **reject** (`basic.reject`) — отклонить одно сообщение.

По умолчанию (если не включён manual ack) RabbitMQ считает сообщение доставленным сразу после `basic.get`/`push` — и при падении консьюмера сообщение **не будет доставлено заново**. Поэтому для гарантии используют **manual acknowledgement**.

```java
@Component
public class OrderConsumer {

    @RabbitListener(queues = "orders.main.queue")
    public void onMessage(Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            // бизнес-обработка
            processOrder(new String(message.getBody()));

            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            // requeue=false -> сообщение уйдёт в DLX (если настроено)
            channel.basicNack(deliveryTag, false, false);
            log.error("Failed to process order", e);
        }
    }
}
```

**prefetch** — ограничивает число «неподтверждённых» сообщений, которые брокер выдает одному консьюмеру:
```java
@RabbitListener(queues = "orders.main.queue", ackMode = "MANUAL", prefetch = 10)
```

### 7. Что такое publisher confirm и publisher return

**Publisher confirm** — механизм, при котором брокер подтверждает продюсеру, что принял и поставил сообщение в очередь (или подтвердил доставку в DLX). Без confirm продюсер «выстрелил и забыл» — не знает, дошло ли сообщение.

```java
@Configuration
public class ConfirmConfig {
    @Bean
    public CachingConnectionFactory connectionFactory() {
        CachingConnectionFactory factory = new CachingConnectionFactory("localhost", 5672);
        factory.setPublisherConfirms(true);   // брокер шлёт confirm
        factory.setPublisherReturns(true);    // брокер возвращает unroutable сообщения
        return factory;
    }
}

@Service
public class OrderProducer implements RabbitTemplate.ConfirmCallback, RabbitTemplate.ReturnsCallback {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public OrderProducer(RabbitTemplate rabbitTemplate) {
        rabbitTemplate.setConfirmCallback(this);
        rabbitTemplate.setReturnsCallback(this);
    }

    public void send(String message) {
        rabbitTemplate.convertAndSend("orders.exchange", "order.created", message);
    }

    @Override
    public void confirm(CorrelationData data, boolean ack, String cause) {
        if (!ack) log.error("Message not accepted: {}", cause);
    }

    @Override
    public void setReturn(ReturnedMessage returned) {
        log.error("Unroutable message: {}", returned.getReplyText());
    }
}
```

**Publisher return** — работает в связке с confirm: если сообщение не нашло ни одну очередь (нет совпадения binding), брокер возвращает его продюсеру (а не тихо удаляет).

### 8. В чём разница между RabbitMQ и Kafka

| Критерий             | **RabbitMQ**                              | **Kafka**                                  |
|----------------------|-------------------------------------------|--------------------------------------------|
| Модель               | Очереди + обменники (AMQP)                | Партиции топиков (лог-стрим)               |
| Маршрутизация        | Гибкая (direct/topic/fanout/headers)       | По ключу → партиция                        |
| Повторное чтение      | Сообщение удаляется после ack              | Можно читать с любого offset (retention)   |
| Use case             | Task queues, RPC, low-latency routing      | Event streaming, log aggregation, CDC      |
| Order guarantee      | В пределах одной очереди                  | В пределах одной партиции                  |
| Replay               | Нет (нужен DLX / separate queue)           | Да (consumer group с rewind offset)        |
| Latency              | Низкая (millisecond)                       | Выше (batching)                            |
| Throughput           | Средний/высокий                            | Очень высокий (streaming)                  |

**Когда RabbitMQ:** когда нужны гибкая маршрутизация, низкая задержка, task-очереди (например, «взять задачу и обработать»), RPC.

**Когда Kafka:** когда нужен стрим событий, replay (много независимых потребителей читают один поток), высокая пропускная способность.

**Можно ли вместе:** да — часто Kafka для event stream, RabbitMQ для task-очередей. Или Kafka + Stream Processing + RabbitMQ для команд.

### 9. Что такое prefetch и как он влияет на балансировку

**Prefetch** (`basic.qos`) — ограничивает число сообщений, которые брокер выдаёт одному консьюмеру **до подтверждения** (ack).

```java
channel.basicQos(10);  // не более 10 неподтверждённых сообщений одному консьюмеру
```

**Зачем нужен:**
- Без prefetch (или с `prefetch=250` по умолчанию в Spring) брокер отдаёт все накопленные сообщения одному консьюмеру «одной волной» — другие консьюмеры сидят без работы, пока первый не обработает всё. Это **нефэр-распределение**.
- С малым prefetch (например, 1–10) брокер выдаёт по одному-двум сообщениям на консьюмера и сразу отдаёт следующим. Нагрузка распределяется равномерно.

```mermaid
flowchart TB
    subgraph "Без prefetch (или prefetch=250)"
        Q[Queue: 100 msgs] -->|100 сразу| C1[Consumer 1]
        Q -.->|0 msgs| C2[Consumer 2]
    end
    subgraph "С prefetch=1"
        Q2[Queue: 100 msgs] -->|1 msg| C3[Consumer 1]
        Q2 -->|1 msg| C4[Consumer 2]
        Q2 -->|1 msg| C5[Consumer 3]
    end
```

**Типичная ошибка:** `prefetch=0` или очень большое значение → один консьюмер «съедает» всю очередь, остальные простаивают. Для балансировки между консьюмерами одной очереди — маленький prefetch.

### 10. Что такое TTL (time-to-live) и max length очереди

**TTL** (`x-message-ttl`) — время жизни сообщения в очереди (в миллисекундах). Если сообщение «прожило» дольше TTL и его так никто не забрал, оно считается «мёртвым» и уходит в DLX (если настроен).

**Max length** (`x-max-length`) — максимальное количество сообщений в очереди. Когда очередь полна, новые сообщения отбрасываются (старейшее уходит в DLX, если настроен).

```java
Map<String, Object> args = new HashMap<>();
args.put("x-message-ttl", 30000);   // 30 секунд
args.put("x-max-length", 1000);     // не более 1000 сообщений
Queue queue = new Queue("temp.queue", true, false, false, args);
```

**Ситуации использования:**
- **TTL** — для временных сообщений (например, «ответ на запрос», который устареет, если его не заберут).
- **Max length** — защита от переполнения, когда консьюмеры «застряли» и очередь растёт бесконечно.

**Важно:** TTL можно задать на уровне очереди (все сообщения) или на уровне конкретного сообщения (`MessageProperties.setExpire`). Max length — только на уровне очереди.

### 11. Как настроить Spring AMQP (RabbitTemplate, RabbitListener)

**RabbitTemplate** — клиент для отправки сообщений (аналог KafkaProducer). **RabbitListener** (аннотация `@RabbitListener`) — для обработки входящих сообщений.

```java
// Конфигурация
@Configuration
public class RabbitConfig {
    @Bean
    public TopicExchange ordersExchange() {
        return new TopicExchange("orders.exchange", true, false);
    }

    @Bean
    public Queue ordersQueue() {
        return new Queue("orders.queue", true);
    }

    @Bean
    public Binding binding() {
        return BindingBuilder.bind(ordersQueue()).to(ordersExchange()).with("order.#");
    }
}

// Продюсер
@Service
public class OrderProducer {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public void send(String orderId, String action, Object payload) {
        rabbitTemplate.convertAndSend("orders.exchange", "order." + action, payload);
    }
}

// Консьюмер (auto ack по умолчанию)
@Component
public class OrderConsumer {
    @RabbitListener(queues = "orders.queue")
    public void onMessage(Map<String, Object> payload) {
        log.info("Received order: {}", payload.get("orderId"));
    }
}
```

**Ключевые настройки connection factory:**
```java
@Configuration
public class RabbitConfig {
    @Bean
    public CachingConnectionFactory connectionFactory() {
        CachingConnectionFactory factory = new CachingConnectionFactory();
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setUsername("guest");
        factory.setPassword("guest");
        factory.setPublisherConfirms(true);
        factory.setPublisherReturns(true);
        return factory;
    }
}
```

**Manual ack:**
```java
@RabbitListener(queues = "orders.queue", ackMode = AckMode.MANUAL, prefetch = 5)
public void onMessage(Message message, Channel channel) throws IOException {
    try {
        process(message);
        channel.basicAck(message.getMessageProperties().getDeliveryTag(), false);
    } catch (Exception e) {
        channel.basicNack(message.getMessageProperties().getDeliveryTag(), false, false);
    }
}
```

### 12. Как обеспечить надёжную доставку сообщений (не потерять)

Надёжная доставка в RabbitMQ — это три уровня:

1. **Продюсер → брокер:**
   - **Publisher confirm** — брокер подтверждает приём (`ConfirmCallback`).
   - **Durable exchange** — exchange не теряется при рестарте.
   - **Transactional publish** (редко) — транзакция на уровне AMQP.

2. **Брокер (хранение):**
   - **Durable queue** — очередь сохраняется на диск.
   - **Persistent message** (`MessageProperties.setDeliveryMode(DeliveryMode.PERSISTENT)`) — сообщение пишется на диск, переживает рестарт брокера.
   - **HA / Quorum queue** — репликация очереди на несколько нод кластера.

3. **Брокер → консьюмер:**
   - **Manual ack** — сообщение удаляется только после подтверждения консьюмером.
   - **Prefetch** — равномерное распределение.
   - **DLX** — сообщения, которые не удалось обработать, не теряются.

```java
// Продюсер: persistent сообщение
MessageProperties props = new MessageProperties();
props.setDeliveryMode(MessageProperties.DeliveryMode.PERSISTENT);
Message message = new Message(payload, props);
rabbitTemplate.send("orders.exchange", "order.created", message);
```

**Итог:** для «at-least-once» (сообщение может быть доставлено повторно, но не потеряется) — publisher confirm + durable queue + persistent message + manual ack. Для «at-most-once» (сообщение теряется при сбое) — без confirm, auto ack.

### 13. Что такое quorum queue и в чём разница от classic queue

**Classic queue** — очередь хранится на одной ноде. Если нода падает, очередь недоступна (или сообщения теряются, если не durable).

**Quorum queue** — очередь реплицируется на несколько нод кластера (например, 3). Работает по алгоритму **Raft**:
- Один лидер принимает сообщения, реплицирует на фолловеров.
- Если лидер падает — выбирается новый (большинство = quorum).
- Сообщения хранятся на всех репликах — **отказоустойчивость к падению нод**.

```java
// Создание quorum queue (JDK client)
Map<String, Object> args = new HashMap<>();
args.put("x-queue-type", "quorum");
args.put("x-queue-leader-locator", "client-locality");  // опционально
channel.queueDeclare("orders.quorum.queue", true, false, false, args);
```

**Когда quorum queue:**
- Критичные очереди, где потеря сообщений недопустима.
- Кластер из 3+ нод.

**Минусы quorum queue:**
- Большая нагрузка на диск и сеть (реплицирование).
- Выше latency, чем у classic queue.
- Требует 3+ ноды для полноценной отказоустойчивости.

**Когда classic queue:**
- Низкая критичность, высокая нагрузка (огромный throughput), мало нод в кластере.
- Очереди, где потеря нескольких сообщений при сбое допустима.

### 14. Как работает clustering в RabbitMQ и что такое mirrored queues

RabbitMQ поддерживает кластеризацию: несколько нод работают как единый брокер.

**Архитектура кластера:**
```mermaid
flowchart TD
    subgraph Cluster
        N1[Node 1<br/>Leader]
        N2[Node 2]
        N3[Node 3]
    end
    P[Producer] --> N1
    P --> N2
    C[Consumer] --> N1
    C --> N2
    N1 <-->|replication| N2
    N2 <-->|replication| N3
```

**Mirrored queue** (устаревший механизм, deprecated в новых версиях):
- Очередь реплицируется на несколько нод синхронно.
- Лидер принимает сообщения, реплицирует на mirrors.
- Если лидер падает — один из mirrors становится лидером.

**Проблемы mirrored queue:**
- **Расхождение реплик** (replica drift) — при сетевых сбоях mirrors могут «отстать» и расконфигурироваться.
- **Двойной записи** — при сбое, когда два лидера считают себя лидерами.
- **Высокая нагрузка** на сеть и диск.

**Почему quorum queue лучше:**
- Работает по **Raft** — строго одна копия-лидер, нет расхождения.
- Более предсказуемое поведение при сбоях.
- Репликация асинхронная (меньше overhead).

**Рекомендация:** в новых системах использовать **quorum queues** вместо mirrored. Mirrored — только для легаси.

### 15. Что такое federation в RabbitMQ и зачем она нужна

**Federation** — механизм, который позволяет связать очереди **разных** кластеров (или разных брокеров) так, что сообщения из «upstream» очереди автоматически пересылаются в «downstream» очередь.

```mermaid
flowchart LR
    subgraph "Cluster A"
        QA[Upstream Queue]
    end
    subgraph "Cluster B"
        QB[Downstream Queue]
    end
    QA -->|federation link| QB
```

**Как работает:**
1. На каждом кластере включается **federation plugin**.
2. Создаётся **federation link** — «мост» между двумя очередями.
3. Консьюмер на upstream очереди забирает сообщения и пересылает их в downstream очередь.

**Конфигурация:**
```yaml
# rabbitmq.conf (Cluster B — downstream)
federation.upstream.cluster_a = amqp://guest:guest@cluster-a
federation.upstream.cluster_a.exchange = orders.exchange
federation.upstream.cluster_a.queues = orders.queue
```

**Когда federation:**
- **DR (Disaster Recovery)** — репликация очередей в гео-распределённых кластерах.
- **Геораспределённые системы** — сообщения из региона A уходят в регион B.
- **Миграция** — перенос трафика с одного кластера на другой.

**Ограничения:**
- Federation **не** гарантирует at-least-once между кластерами (без publisher confirm на upstream + manual ack на downstream).
- Задержка выше (дополнительный hop через upstream-консьюмер).
- Сложнее отлаживать (сообщения проходят через 2 очереди).

**Альтернатива:** использовать Kafka MirrorMaker (для Kafka) или собственную репликацию через shared storage.

### 16. Как мониторить RabbitMQ (management UI, Prometheus, Grafana)

**RabbitMQ Management** — встроенный веб-интерфейс (порт 15672):
- Очереди: размер, rate (in/out), consumers.
- Connections, channels, exchanges.
- Алerts: dead letter queues, memory/disk threshold.

**Prometheus + Grafana** (production monitoring):
```java
// Включаем metrics endpoint в Spring Boot
spring.rabbitmq.metrics.enabled=true
```

```yaml
# prometheus.yaml (scrape RabbitMQ)
scrape_configs:
  - job_name: rabbitmq
    static_configs:
      - targets: ['rabbitmq-node-1:15692', 'rabbitmq-node-2:15692']
```

**Ключевые метрики:**
- `rabbitmq_queue_messages` — кол-во сообщений в очереди.
- `rabbitmq_queue_consumers` — кол-во активных консьюмеров.
- `rabbitmq_channel_messages_published` / `delivered` — rate.
- `rabbitmq_node_mem_used` — память ноды.
- `rabbitmq_exchange_messages_delivered` — rate на уровне exchange.

**Алерты (Grafana):**
- Очередь растёт быстрее, чем консьюмеры обрабатывают (backlog).
- Dead letter queue не пустая (проблемные сообщения).
- Нода близка к memory/disk threshold.

### 17. Как работает security в RabbitMQ (VHost, пользователи, permissions)

**VHost** (Virtual Host) — логическое изолированное пространство в одном брокере. Каждый vhost имеет свои exchanges, queues, users.

```java
ConnectionFactory factory = new CachingConnectionFactory();
factory.setVirtualHost("/production");  // vhost
factory.setUsername("service_account");
factory.setPassword("secret");
```

**Пользователи и permissions:**
- Каждый пользователь имеет права на операции с exchanges и queues в vhost:
  - **Configure** — создавать/удалять exchange/queue.
  - **Write** — публиковать сообщения на exchange.
  - **Read** — читать из queue.

**CLI (rabbitmqctl):**
```bash
# Создать пользователя с правами
rabbitmqctl add_user service_account 'secret'
rabbitmqctl set_permissions -p /production service_account ".*" ".*" ".*"
# (configure, write, read)
```

**Best practices:**
- **Отдельный vhost на окружение** (dev/staging/prod).
- **Отдельные пользователи для каждого сервиса** (не один shared account).
- **Минимальные права** (service получает только read на свою очередь).
- **TLS** для соединения (порт 5671 вместо 5672).
- **Не использовать guest** в production (по умолчанию guest только на localhost).

### 18. Что такое message ordering и как гарантировать порядок

**Message ordering** в RabbitMQ — это гарантия того, что сообщения из одной очереди обрабатываются **в том же порядке**, в котором они были опубликованы.

**Почему порядок может нарушиться:**
1. **Множество консьюмеров** на одной очереди — сообщения распределяются между ними, порядок между консьюмерами **не гарантируется** (каждый консьюмер обрабатывает свои сообщения по порядку, но глобально — нет).
2. **Prefetch** — консьюмер получает несколько сообщений сразу и может обработать их не по порядку (если обработка асинхронная).

**Как гарантировать порядок:**
- **Один консьюмер на очередь** (для критичных случаев) — тогда порядок сохраняется.
- **Prefetch=1 + manual ack** — консьюмер обрабатывает по одному сообщению, ack'ит, потом берёт следующее.
- **Разделить на несколько очередей** (по ключу) — как в Kafka партициях. Каждый «поток» (например, по orderId) идёт в свою очередь, где один консьюмер гарантированно сохраняет порядок.

```java
// Разделение на очереди по orderId (как партиции в Kafka)
// order_1 -> queue_1 -> consumer_1 (по одному)
// order_2 -> queue_2 -> consumer_2 (по одному)
int partition = Math.abs(orderId.hashCode() % 10);
String queueName = "orders.queue." + partition;
rabbitTemplate.convertAndSend("orders.exchange", "order." + queueName, payload);
```

**Важно:** если бизнес-логика допускает перестановку (например, «все уведомления для пользователя») — не нужно гарантировать глобальный порядок. Если критичен порядок **в рамках сущности** (например, команды по одной сессии) — разделяйте на очереди по ключу.

### 19. Что такое RPC over RabbitMQ и как он работает

**RPC (Remote Procedure Call) over RabbitMQ** — паттерн, когда клиент отправляет «запрос» в очередь, а сервер обрабатывает и возвращает «ответ» в reply-очередь.

```mermaid
sequenceDiagram
    participant Client
    participant ReqExch as Request Exchange
    participant ReqQ as Request Queue
    participant Server
    participant RplyExch as Reply Exchange
    participant RplyQ as Reply Queue
    Client ->> ReqExch: request (correlationId)
    ReqExch ->> ReqQ:
    ReqQ ->> Server:
    Server ->> RplyExch: response (correlationId)
    RplyExch ->> RplyQ:
    RplyQ ->> Client:
```

**Как работает:**
1. Клиент создаёт **exclusive, auto-delete reply-очередь** (unique name).
2. Клиент публикует сообщение в **request exchange** с `replyTo` = имя reply-очереди и `correlationId` (уникальный идентификатор запроса).
3. Сервер читает из request-очереди, обрабатывает, публикует ответ в очередь из `replyTo` с тем же `correlationId`.
4. Клиент слушает reply-очередь, находит ответ по `correlationId`.

```java
// Spring AMQP RPC-клиент (упрощённо)
@Service
public class RpcClient {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public String call(String payload) {
        String replyQueueName = "reply." + UUID.randomUUID();
       rabbitTemplate.convertAndSend("rpc.exchange", "rpc.request", payload,
            message -> {
                message.getMessageProperties().setReplyTo(replyQueueName);
                message.getMessageProperties().setCorrelationId(UUID.randomUUID().toString());
                return message;
            });
        // Ожидание ответа
        return (String) rabbitTemplate.receiveAndConvert(replyQueueName, 5000);
    }
}
```

**Проблемы RPC over RabbitMQ:**
- **Высокая latency** (2+ hops через брокер).
- **Трудно масштабировать** (каждый запрос создаёт reply-очередь).
- **Timeouts** — нужно обрабатывать случаи, когда сервер не ответил.

**Когда RPC:**
- Легаси-интеграции.
- Простые request/response с низкой нагрузкой.

**Альтернатива:** gRPC, REST, или Kafka Streams (если нужен stream processing).

### 20. Как выбрать между RabbitMQ и Kafka для конкретной задачи

Выбор зависит от **типа данных** и **паттерна потребления**:

**RabbitMQ лучше, когда:**
- **Task queue** — «взять задачу и обработать» (например, «отправить email», «сгенерировать PDF»).
- **Низкая latency** нужна (millisecond).
- **Гибкая маршрутизация** — одно сообщение в несколько очередей (fanout), или по сложным правилам (topic).
- **RPC** — request/response паттерн.
- **Умеренный throughput** (тысячи–сотни тысяч msg/s).
- **Множество независимых потребителей** (каждый читает свою очередь).

**Kafka лучше, когда:**
- **Event streaming** — поток событий, который нужно **replay** (много потребителей читают один поток).
- **Высокий throughput** (миллионы msg/s).
- **Log aggregation** — сбор логов из множества сервисов.
- **CDC (Change Data Capture)** — изменение в БД → событие в Kafka → другие сервисы.
- **Stream processing** — Kafka Streams / Flink.
- **Потребители могут «отставать»** и потом «догнать» (retention позволяет).

**Итог:**
- **RabbitMQ** = «очереди задач + гибкая маршрутизация + RPC».
- **Kafka** = «стрим событий + replay + высокий throughput + stream processing».

**Частая комбинация:** Kafka для event stream (например, «order.created»), а RabbitMQ для task-очередей (например, «send_email», «send_sms»). Или Kafka → Stream Processing → RabbitMQ (команды).

