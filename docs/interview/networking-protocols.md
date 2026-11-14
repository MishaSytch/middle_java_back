# Сети и протоколы


### 1. Что такое OSI-модель и TCP/IP — в чём разница

**OSI-модель** — 7 уровней (Physical, Data Link, Network, Transport, Session, Presentation, Application). Это **концептуальная** модель для разговора о сетях. **TCP/IP** — 4 уровня (Link, Internet, Transport, Application) — **практическая** модель, по которой реально работает интернет.

**Соответствие уровней:**

| OSI                                       | TCP/IP      | Примеры              |
|-------------------------------------------|-------------|----------------------|
| 1. Physical                               | Link        | Ethernet, Wi-Fi      |
| 2. Data Link                              | Link        | ARP, MAC             |
| 3. Network                                | Internet    | IP, ICMP, BGP        |
| 4. Transport                              | Transport   | TCP, UDP             |
| 5–7. Session / Presentation / Application | Application | HTTP, DNS, TLS, SMTP |

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph TD
    subgraph OSI ["OSI-модель (7 уровней)"]
        direction TB
        L7["Application"]
        L6["Presentation"]
        L5["Session"]
        L4["Transport (TCP/UDP)"]
        L3["Network (IP, ICMP)"]
        L2["Data Link (ARP, MAC)"]
        L1["Physical (Ethernet, Wi-Fi)"]
        L7 --> L6 --> L5 --> L4 --> L3 --> L2 --> L1
    end
    subgraph TCP ["TCP/IP (4 уровня)"]
        direction TB
        T4["Application (HTTP, DNS)"]
        T3["Transport (TCP, UDP)"]
        T2["Internet (IP, ICMP, BGP)"]
        T1["Link (ARP, MAC)"]
        T4 --> T3 --> T2 --> T1
    end
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n3 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class L7 n0
    class L6 n0
    class L5 n0
    class L4 n1
    class L3 n2
    class L2 n3
    class L1 n3
    class T4 n0
    class T3 n1
    class T2 n2
    class T1 n3
    class OSI n4
    class TCP n4
```

**На собеседовании важно:** понимать, на каком уровне живёт каждый протокол (DNS — Application, IP — Network, TCP — Transport) и где решаются конкретные проблемы (маршрутизация — Network, доставка — Transport, шифрование — Presentation/Application).

### 2. TCP vs UDP: в чём разница и когда что использовать

| Критерий             | **TCP**                                         | **UDP**                                        |
|----------------------|-------------------------------------------------|------------------------------------------------|
| Соединение           | connection-oriented (SYN/SYN-ACK/ACK handshake) | connectionless                                 |
| Доставка             | гарантия (ретрансмит, порядок)                  | best-effort                                    |
| Порядок              | да (sequence numbers)                           | нет                                            |
| Контроль потока/окна | да (sliding window, congestion)                 | нет                                            |
| Header               | 20 байт                                         | 8 байт                                         |
| Latency              | выше (ACK, ретрансмиссии)                       | ниже                                           |
| Примеры              | HTTP, HTTPS, SSH, SMTP, PostgreSQL              | DNS, VoIP, видео, игры, NTP, QUIC (внутри UDP) |

**Когда TCP:** REST API, базы данных, email — нужен порядок и доставка.

**Когда UDP:** DNS-запросы (быстрее, потери не критичны), стриминг (потеря кадра важнее задержки), realtime-игры.

```java
// TCP в Java (на уровне Java NIO)
// ServerSocket — TCP server
ServerSocket server = new ServerSocket(8080);
Socket client = server.accept(); // блокирующий accept
// Каждый connection = отдельный TCP-поток

// UDP в Java
DatagramSocket udp = new DatagramSocket(53);
byte[] buf = new byte[512];
DatagramPacket pkt = new DatagramPacket(buf, buf.length);
udp.receive(pkt); // один packet = один запрос (без соединения)

// Netty: транспорт выбирается конфигурацией
// TCP: NioServerSocketChannel
// UDP: NioDatagramChannel
EventLoopGroup boss = new NioEventLoopGroup(1);
EventLoopGroup workers = new NioEventLoopGroup();
Channel pipeline = new NioServerSocketChannel(); // TCP
// Channel pipeline = new NioDatagramChannel(); // UDP
```

**На middle-уровне:** уверенно объяснить таблицу и дать 2–3 примера для каждого.

### 3. Как работает TCP-соединение: handshake и teardown

**Three-way handshake (установка):**
1. Клиент → `SYN` (seq=x)
2. Сервер → `SYN-ACK` (seq=y, ack=x+1)
3. Клиент → `ACK` (ack=y+1) — соединение установлено

**Four-way teardown (закрытие):**
1. Клиент → `FIN` (хочу закрыть)
2. Сервер → `ACK`
3. Сервер дописал данные → `FIN`
4. Клиент → `ACK` — соединение закрыто (TIME_WAIT ~60с, чтобы дошли поздние пакеты)

**Ключевые состояния** (для сетевого debug):
- `ESTABLISHED` — активное соединение
- `TIME_WAIT` — клиент ждёт «остатки» (~60 с)
- `CLOSE_WAIT` — сервер не закрыл — признак утечки соединений
- `FIN_WAIT_2` — ожидаем FIN от сервера

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(245,248,255)
    Note over C,S: 1. Three-way handshake (установка)
    C->>S: SYN (seq=x)
    S->>C: SYN-ACK (seq=y, ack=x+1)
    C->>S: ACK (ack=y+1)
    Note over C,S: ESTABLISHED
    end

    rect rgb(255,252,240)
    Note over C,S: 2. Обмен данными
    C->>S: data
    S->>C: data
    end

    rect rgb(245,255,245)
    Note over C,S: 3. Four-way teardown (закрытие)
    C->>S: FIN (хочу закрыть)
    S->>C: ACK
    S->>S: дописывает данные
    S->>C: FIN
    C->>S: ACK
    Note over C,S: TIME_WAIT (~60s) → CLOSED
    end
```

```bash
ss -tan | head -20   # кто и на каком состоянии
# CLOSE_WAIT в больших количествах — у кода не закрываются соединения
```

### 4. Что такое TLS/SSL handshake и как он работает

TLS (Transport Layer Security) — шифрование канала поверх TCP. **TLS 1.2** (классика) и **TLS 1.3** (быстрее, безопаснее, по умолчанию в современных браузерах).

**TLS 1.3 handshake (упрощённо):**
1. `ClientHello` — клиент шлёт поддерживаемые cipher suites + `random`
2. `ServerHello` + `Certificate` — сервер выбирает cipher, шлёт сертификат
3. `Finished` от сервера — клиент проверяет подпись и шлёт `Finished`
4. Дальше — **шифрованный** обмен данными (симметричное шифрование, ключи согласованы через ECDHE)

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(245,248,255)
    Note over C,S: 1. ClientHello
    C->>S: ClientHello (cipher suites, random, SNI)
    end

    rect rgb(255,252,240)
    Note over C,S: 2. ServerHello + Certificate
    S->>C: ServerHello (cipher choice, random)
    S->>C: Certificate (X.509, CA chain)
    S->>C: Finished (подпись)
    end

    rect rgb(245,255,245)
    Note over C,S: 3. Client проверяет и завершает
    C->>C: проверка сертификата (CA chain)
    C->>C: ECDHE — согласование ключей
    C->>S: Finished (подпись)
    end

    rect rgb(243,246,255)
    Note over C,S: 4. Шифрованный обмен
    C->>S: encrypted data
    S->>C: encrypted data
    end
```

**Ключевые концепции:**
- **Certificate** — X.509, подписан CA; браузер проверяет цепочку до trusted root
- **ECDHE** — ephemeral key exchange, forward secrecy (даже если приватный ключ утечёт — старые сессии не раскрыть)
- **Cipher suite** — набор: `TLS_AES_128_GCM_SHA256` = аутентификация + шифрование + hash
- **SNI** (Server Name Indication) — клиент в `ClientHello` сообщает, какой хост хочет, чтобы один IP мог обслуживать множество сайтов

**Что спрашивают на собеседовании:** почему HTTPS (порт 443), что такое certificate pinning, как работает SNI, чем TLS 1.3 лучше 1.2 (1 RTT вместо 2, меньше cipher suites, обязательная forward secrecy).

### 5. Что такое HTTP и каков жизненный цикл запроса

**HTTP** (HyperText Transfer Protocol) — текстовый протокол уровня Application поверх TCP. **HTTP/1.1** — по умолчанию, **HTTP/2** (binary framing, multiplexing) и **HTTP/3** (на UDP/QUIC, ещё быстрее) — поддерживаются современными серверами и браузерами.

**Жизненный цикл запроса:**
```
Клиент → DNS lookup (имя → IP)
      → TCP handshake (или TLS)
      → HTTP request (method, URL, headers, body)
      → Сервер → HTTP response (status, headers, body)
      → TCP teardown (или keep-alive)
```

**HTTP/1.1 features:**
- `Connection: keep-alive` — одно TCP-соединение на много запросов (по умолчанию)
- `Pipelining` — несколько запросов без ожидания ответов (на практике мало используется)
- `Chunked encoding` — ответ передаётся кусками, без заранее известного `Content-Length`
- `Caching` — `ETag`, `Cache-Control`, `If-None-Match`

**HTTP/2** (по умолчанию в Chrome на HTTPS):
- **Binary framing** — бинарные фреймы вместо текста
- **Multiplexing** — много request/response по одному TCP-соединению (нет head-of-line blocking на HTTP-уровне)
- **Header compression** (HPACK)
- **Server push** (в новых версиях — deprecated)

**HTTP/3** (на QUIC/UDP):
- Устойчив к packet loss (каждый stream независим)
- 0-RTT connection establishment (возвращающиеся клиенты)

**На middle-уровне:** достаточно знать разницу HTTP/1.1 vs HTTP/2 (multiplexing) и понимать, что HTTP/3 = HTTP поверх QUIC на UDP.

### 6. Что такое DNS и как работает запрос

**DNS** (Domain Name System) — иерархическая система имён → IP-адреса. Работает поверх UDP (порт 53), иногда TCP (для больших ответов, zone transfer).

**Иерархия:**
```
.com (TLD)
  ├── example.com (NS: ns1.example-dns.net)
  │     ├── www (A: 93.184.216.34)
  │     ├── api (CNAME → www)
  │     └── mx (MX: mail.example.com)
  └── another.com
```

**Типы записей (самые важные):**
- **A** — IPv4 адрес
- **AAAA** — IPv6 адрес
- **CNAME** — алиас на другое имя
- **MX** — почтовый сервер
- **NS** — nameserver зоны
- **TXT** — произвольный текст (SPF, DKIM)
- **PTR** — обратный lookup (IP → имя)
- **SOA** — Start of Authority (параметры зоны)

**Как работает запрос (recursive resolution):**
1. Клиент → local DNS resolver (192.168.x.x)
2. Resolver → root server `.` (a.root-servers.net)
3. Root → TLD `.com` (a.gtld-servers.net)
4. TLD → authoritative NS `example.com` (ns1.example-dns.net)
5. NS → ответ A-записью
6. Resolver кэширует ответ (TTL) → клиенту

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant Cl as Client
    participant R as Resolver (local)
    participant Root as Root (.)
    participant TLD as TLD (.com)
    participant NS as Authoritative NS

    rect rgb(245,248,255)
    Note over Cl,R: 1. Клиент → Resolver
    Cl->>R: example.com (A)
    end

    rect rgb(255,252,240)
    Note over R,Root: 2. Resolver → Root
    R->>Root: example.com (A)
    Root-->>R: referral: TLD .com
    end

    rect rgb(245,255,245)
    Note over R,TLD: 3. Resolver → TLD
    R->>TLD: example.com (A)
    TLD-->>R: referral: NS ns1.example-dns.net
    end

    rect rgb(243,246,255)
    Note over R,NS: 4. Resolver → Authoritative NS
    R->>NS: example.com (A)
    NS-->>R: A: 93.184.216.34 (TTL=300)
    end

    rect rgb(245,248,255)
    Note over Cl,R: 5. Ответ клиенту
    R->>Cl: A: 93.184.216.34
    Note over R: кэш на TTL=300s
    end
```

**TTL** (Time To Live) — сколько секунд ответ живёт в кэше. Меньше TTL → быстрее обновление, но больше нагрузка на DNS.

```bash
dig example.com A +trace   # полный путь
dig example.com +short     # только ответ
nslookup example.com
host -t MX example.com     # почтовый сервер
```

### 7. Что такое IP-адреса и подсети (CIDR)

**IP-адрес** — 32 бита (IPv4) или 128 бит (IPv6). **IPv4** — `a.b.c.d` (каждый октет 0-255). **IPv6** — 8 групп по 16 бит в hex (`2001:db8::1`).

**CIDR** (Classless Inter-Domain Routing) — способ описать подсеть: `IP/маска`.
- `192.168.1.0/24` — маска 255.255.255.0, 256 адресов (0-255)
- `192.168.1.0/16` — маска 255.255.0.0, 65536 адресов
- `10.0.0.0/8` — «внутренняя» сеть, 16 777 216 адресов

**Классы (исторические):**
- **A** (1-126.x.x.x) — крупные сети, /8
- **B** (128-191.x.x.x) — средние, /16
- **C** (192-223.x.x.x) — мелкие, /24
- **D** (224-239) — multicast
- **E** (240-255) — reserved

**Private-диапазоны** (RFC 1918, не роутятся в интернет):
- `10.0.0.0/8`
- `172.16.0.0/12` (172.16-31.x.x)
- `192.168.0.0/16`

**NAT** (Network Address Translation) — преобразование внутренних IP в внешний (и обратно), чтобы один публичный IP обслуживал множество внутренних машин. В облаках (AWS VPC, GCP VPC) подсети — основа сети.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph LR
    subgraph IPv4 ["IPv4 (32 бита)"]
        direction LR
        Net["Network bits (сеть)"]
        Host["Host bits (хост)"]
    end
    subgraph CIDR ["Примеры CIDR"]
        C24["/24 → 255.255.255.0 → 256 addr"]
        C16["/16 → 255.255.0.0 → 65536 addr"]
        C8["/8 → 255.0.0.0 → 16M addr"]
    end
    subgraph Private ["Private (RFC 1918)"]
        P1["10.0.0.0/8"]
        P2["172.16.0.0/12"]
        P3["192.168.0.0/16"]
    end
    IPv4 --> CIDR
    IPv4 --> Private
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n2 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n3 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class Net n0
    class Host n0
    class C24 n1
    class C16 n1
    class C8 n1
    class P1 n3
    class P2 n3
    class P3 n3
    class IPv4 n4
    class CIDR n4
    class Private n4
```

### 8. Что такое HTTP status codes и как их группировать

**Классы статусов (4-значных кодов):**
- **1xx** — Informational (100 Continue, 101 Switching Protocols)
- **2xx** — Success
  - `200 OK` — обычный успех
  - `201 Created` — ресурс создан (REST POST)
  - `202 Accepted` — принято, но обработка асинхронная
  - `204 No Content` — успех без тела (DELETE)
- **3xx** — Redirect
  - `301 Moved Permanently` — новый URL навсегда (кэшируется)
  - `302 Found` — временный редирект
  - `304 Not Modified` — кэш валиден, тело не передаём (с `ETag`)
  - `307 Temporary Redirect` — временный, метод сохраняется
  - `308 Permanent Redirect` — постоянный, метод сохраняется
- **4xx** — Client Error
  - `400 Bad Request` — malformed запрос
  - `401 Unauthorized` — нужна аутентификация
  - `403 Forbidden` — авторизован, но нет доступа
  - `404 Not Found` — ресурс не найден
  - `409 Conflict` — конфликт (REST: дубликат, версия)
  - `422 Unprocessable Entity` — semantically invalid
  - `429 Too Many Requests` — rate limit
- **5xx** — Server Error
  - `500 Internal Server Error` — generic
  - `501 Not Implemented`
  - `502 Bad Gateway` — upstream вернул garbage
  - `503 Service Unavailable` — временно недоступен
  - `504 Gateway Timeout` — upstream не ответил

**Частые ошибки в REST-дизайне:**
- Возвращать `200` для ошибок (вместо `4xx`/`5xx`)
- Путать `401` (не авторизован) и `403` (авторизован, но не может)
- Возвращать `200` с пустым телом вместо `204` для DELETE

### 9. Что такое proxy и типы прокси

**Proxy** — промежуточный сервер между клиентом и origin-сервером. Бывает **forward proxy** (клиент → proxy → интернет, для корпоративных сетей) и **reverse proxy** (клиент → proxy → origin, за сервером).

**Типы reverse proxy:**
- **Load balancer** — распределяет трафик между экземплярами (nginx, HAProxy, ALB)
- **Caching proxy** — кеширует ответы (Varnish, nginx cache)
- **TLS termination** — завершает TLS, дальше — plain HTTP (AWS ALB, nginx)
- **API gateway** — маршрутизация, аутентификация, rate limiting (Kong, Apigee)

**Пример nginx reverse proxy:**
```nginx
upstream backend {
    server 10.0.0.1:8080;
    server 10.0.0.2:8080;
}
server {
    listen 443 ssl;
    server_name api.example.com;
    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60s;
    }
}
```

**Зачем reverse proxy:**
- Терминация TLS (серверы не трогают сертификаты)
- Балансировка нагрузки
- Кеширование статики
- Rate limiting, WAF
- Health checks и failover

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph LR
    subgraph Clients ["Клиенты"]
        C1["Browser / App"]
    end
    subgraph Proxy ["Reverse Proxy (nginx)"]
        TLS["TLS termination"]
        LB["Load balancing"]
        Cache["Cache"]
        WAF["WAF / Rate limit"]
    end
    subgraph Backends ["Backend-серверы"]
        B1["App 1 :8080"]
        B2["App 2 :8080"]
        B3["App 3 :8080"]
    end
    C1 -->|HTTPS| TLS
    TLS --> LB
    LB --> B1
    LB --> B2
    LB --> B3
    LB --> Cache
    LB --> WAF
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class C1 n0
    class TLS n1
    class LB n1
    class Cache n1
    class WAF n1
    class B1 n2
    class B2 n2
    class B3 n2
    class Clients n3
    class Proxy n3
    class Backends n3
```

### 10. Что такое load balancing и алгоритмы распределения

**Load balancing** — распределение входящего трафика между несколькими инстансами приложения, чтобы:
- Не перегружать один инстанс
- Обеспечивать отказоустойчивость (failover)
- Позволять горизонтально масштабироваться

**Уровни балансировки:**
- **L4 (Transport)** — по IP+порт (TCP, UDP). Быстрый, но «глупый» (не смотрит HTTP-заголовок). Примеры: AWS NLB, nginx stream.
- **L7 (Application)** — по HTTP-заголовкам, cookie, URL. Медленнее, но гибче (path-based routing, A/B). Примеры: AWS ALB, nginx http, HAProxy.

**Алгоритмы:**
- **Round-robin** — по кругу (по умолчанию)
- **Weighted round-robin** — с весами (большие инстансы — больше запросов)
- **Least connections** — тому, у кого меньше активных соединений
- **IP hash** — sticky по IP клиента (session affinity)
- **Consistent hashing** — стабильное распределение (минимум перемещений при добавлении/удалении ноды)

**Health checks** — балансировщик периодически опрашивает инстансы (`/actuator/health`) и убирает из пула те, что не отвечают. **Session stickiness** (sticky session) — один клиент всегда на одном инстансе (проблема: нарушает stateless-принцип, лучше external session store).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph TD
    subgraph LB ["Load Balancer"]
        HC["Health checks (/health)"]
        Algo["Algorithm (round-robin / least conn / IP hash)"]
    end
    subgraph Inst ["Инстансы"]
        I1["Instance 1"]
        I2["Instance 2"]
        I3["Instance 3 (down)"]
    end
    Client["Client"]
    Client -->|HTTP| LB
    HC -.->|probe| I1
    HC -.->|probe| I2
    HC -.->|probe X| I3
    Algo --> I1
    Algo --> I2
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class Client n0
    class HC n1
    class Algo n1
    class I1 n2
    class I2 n2
    class I3 n3
    class LB n4
    class Inst n4
```

### 11. Что такое firewall и сетевая безопасность

**Firewall** — устройство/программа, фильтрующая сетевой трафик по правилам. Бывает:
- **Stateless** — фильтрует каждый пакет независимо
- **Stateful** — следит за состоянием соединений (TCP handshake, ACK), разрешает ответ на исходящий запрос

**Уровни защиты:**
- **Network firewall** — по IP, порту, протоколу (iptables, nftables, AWS Security Groups)
- **Application firewall (WAF)** — по содержимому HTTP (ModSecurity, AWS WAF)
- **Host-based firewall** — на конкретной машине (iptables, ufw)

**Пример iptables:**
```bash
# Разрешить HTTP и HTTPS, только с конкретного IP
iptables -A INPUT -p tcp --dport 80 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP   # всё остальное — блок
```

**AWS Security Groups** (stateful, allow-only):
```yaml
- CidrIp: 10.0.0.0/8
  FromPort: 8080
  ToPort: 8080
  IpProtocol: tcp
```

**WAF rules** (OWASP Top 10):
- SQL injection
- XSS
- Path traversal (`../../etc/passwd`)
- Malicious user agents
- CC attack (rate limiting)

### 12. Что такое VPN и как он работает

**VPN** (Virtual Private Network) — создание приватного туннеля поверх публичной сети. Типы:

- **Site-to-site** — соединяет две сети (офис + офис, офис + облако). Пример: AWS Site-to-Site VPN, IPsec tunnel.
- **Client-to-site (remote access)** — пользователь из дома подключается к корпоративной сети. Пример: OpenVPN, WireGuard, Cisco AnyConnect.
- **WireGuard** — современный, быстрый, простой протокол (по умолчанию в AWS Client VPN, Proton VPN).
- **IPsec** — классический протокол для site-to-site (ESP, AH).
- **OpenVPN** — гибкий, поддерживает TLS и IPsec.

**Как работает WireGuard (упрощённо):**
1. Клиент и сервер обмениваются public keys (Diffie-Hellman)
2. Устанавливается symmetric key
3. Все пакеты шифруются ChaCha20-Poly1305
4. Ноль overhead на handshake (stateless)

**Зачем VPN:**
- Шифрование трафика (WIFI в кафе, публичные сети)
- Обход гео-блокировок
- Доступ к корпоративной сети извне
- Соединение веток офисов (SD-WAN)

**Проблемы VPN:**
- Latency (шифрование + обход)
- Single point of failure (сервер)
- Scale (ограничение по числу клиентов)

### 13. Что такое CDN и как он работает

**CDN** (Content Delivery Network) — распределённая сеть edge-серверов по всему миру, которая кэширует контент ближе к пользователям.

**Как работает:**
1. Клиент → ближайший edge (по GeoDNS)
2. Edge проверяет кэш
   - **Hit** — отдаёт из кэша (быстро)
   - **Miss** — идёт на origin-сервер, кеширует ответ, отдаёт клиенту
3. Дальнейшие запросы — hit (быстро)

**Что кэшируют:**
- Статика (CSS, JS, изображения, видео)
- HTML (если `Cache-Control` позволяет)
- API-ответы (если идемпотентные и с `ETag`)

**Пример nginx cache:**
```nginx
proxy_cache_path /var/cache/nginx levels=1:2
    keys_zone=my_cache:10m max_size=1g inactive=60m;

server {
    location /api/ {
        proxy_pass http://backend;
        proxy_cache my_cache;
        proxy_cache_key $scheme$proxy_host$request_uri;
        proxy_cache_valid 200 10m;
        proxy_cache_stale_while_revalidate 30s;
    }
}
```

**Плюсы CDN:**
- Latency (ближе к пользователю)
- Нагрузка на origin (меньше запросов)
- DDoS mitigation (распределение)
- Global reachability

**Примеры:** CloudFlare, Akamai, AWS CloudFront, Fastly.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph LR
    User["User"]
    subgraph Edge ["CDN Edge (closest)"]
        Cache["Cache (hit/miss)"]
    end
    Origin["Origin Server"]
    GeoDNS["GeoDNS"]
    User -->|1. DNS| GeoDNS
    GeoDNS -->|2. nearest edge IP| User
    User -->|3. request| Cache
    Cache -->|hit: 4a| User
    Cache -->|miss: 4b| Origin
    Origin -->|5. response + cache| Cache
    Cache -->|6. response| User
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class User n0
    class GeoDNS n3
    class Cache n1
    class Origin n2
    class Edge n4
```

### 14. Что такое DDoS и как от него защищаться

**DDoS** (Distributed Denial of Service) — атака, когда множество ботов/компрометированных машин шлют трафик на цель, чтобы её «положить».

**Типы атак:**
- **Volume-based** (L3/L4) — flood пакетов (UDP, ICMP, SYN flood). Цель — исчерпать bandwidth.
- **Protocol-based** (L3/L4) — SYN flood (half-open connections), amplification (DNS, NTP reflection).
- **Application-layer** (L7) — HTTP flood (много GET/POST на `/login`), Slowloris (медленные соединения), R.U.D.Y.

**Защита (многоуровневая):**
1. **CDN / DDoS protection** (CloudFlare, AWS Shield) — фильтрует на edge
2. **Rate limiting** — на балансировщике (nginx, APISIX)
3. **WAF rules** — блокирует подозрительные patterns
4. **Anycast** — распределяет трафик на множество IP (AWS, CloudFlare)
5. **Syn cookies** — stateless SYN-ACK (ядро Linux)
6. **Blackholing** — временно отбрасывает трафик на атакованный IP

**nginx rate limiting:**
```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
server {
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://backend;
    }
}
```

### 15. Что такое REST vs GraphQL vs gRPC

| Критерий       | **REST**                    | **GraphQL**          | **gRPC**                         |
|----------------|-----------------------------|----------------------|----------------------------------|
| Протокол       | HTTP/1.1 или HTTP/2         | HTTP/1.1 (POST)      | HTTP/2 (binary)                  |
| Формат         | JSON                        | JSON                 | Protocol Buffers (binary)        |
| Эндпоинты      | много (`/users`, `/orders`) | один (`/graphql`)    | методы в `.proto`                |
| Over-fetching  | да (все поля)               | нет (только нужные)  | нет (определённый schema)        |
| Under-fetching | да (несколько запросов)     | нет (одним запросом) | нет                              |
| Кэширование    | легко (GET)                 | сложнее (POST)       | нет (идемпотентность)            |
| Streaming      | нет (chunked)               | подписки (WebSocket) | да (server/client/bidirectional) |
| Типизация      | Swagger/OpenAPI             | SDL (GraphQL)        | `.proto` (сильная)               |
| Использование  | публичные API               | фронтенд, mobile     | микросервисы (внутренние)        |

**REST** — де-факто стандарт для публичных API. **GraphQL** — когда клиенту нужны «ровно те поля, что нужны» (mobile, web с разными UI). **gRPC** — между микросервисами (быстро, сильно типизировано, streaming).

```java
// gRPC в Java (Spring Boot)
// 1. .proto файл:
// service OrderService {
//   rpc GetOrder (OrderRequest) returns (OrderResponse);
//   rpc WatchOrders (OrderFilter) returns (stream OrderResponse);
// }

// 2. Generated stub (gRPC code generation):
ManagedChannel channel = ManagedChannelBuilder
    .forAddress("orders-service:9090")
    .usePlaintext()
    .build();
OrderServiceGrpc.OrderServiceBlockingStub stub =
    OrderServiceGrpc.newBlockingStub(channel);

// Unary call
OrderResponse order = stub.getOrder(
    OrderRequest.newBuilder().setOrderId("123").build());

// Server streaming
OrderServiceGrpc.OrderServiceStub asyncStub =
    OrderServiceGrpc.newStub(channel);
asyncStub.watchOrders(filter).nextListener(order -> {
    System.out.println("New order: " + order.getOrderId());
});
```

**Когда что:**
- Публичный API → REST (простота, кэширование, универсальность)
- Фронтенд с разными UI (mobile + web) → GraphQL (гибкие запросы)
- Внутренние микросервисы → gRPC (производительность, typing)

### 16. Что такое WebSocket и как он работает

**WebSocket** — full-duplex протокол поверх TCP (порт 80/443), который устанавливает одно длинное соединение и позволяет обмениваться сообщениями в обе стороны без overhead HTTP-заголовков.

**Handshake:**
1. Клиент → HTTP GET с `Upgrade: websocket` + `Connection: Upgrade` + `Sec-WebSocket-Key`
2. Сервер → `101 Switching Protocols` + `Sec-WebSocket-Accept`
3. Дальше — бинарные/текстовые фреймы (не HTTP)

**Пример (Spring WebSocket):**
```java
@Controller
public class WsController {
    @MessageMapping("/chat")          // клиент шлёт
    public void handle(@Payload String msg) {
        logger.info("Received: {}", msg);
    }
}

@Configuration
@EnableWebSocketMessageBroker
public class WsConfig implements WebSocketMessageBrokerConfigurer {
    public void configureMessageBroker(MessageBrokerRegistry reg) {
        reg.enableSimpleBroker("/topic");
        reg.setApplicationDestinationPrefixes("/app");
    }
}
```

**Когда WebSocket:**
- Realtime чаты, уведомления
- Live-дашборды (метрики, котировки)
- Многопользовательские игры
- Совместное редактирование (collaborative editing)

**Противопоставление REST:**
- **REST** — request/response (клиент инициирует)
- **WebSocket** — full-duplex (сервер может сам слать)

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(245,248,255)
    Note over C,S: 1. HTTP Upgrade (handshake)
    C->>S: GET /ws, Upgrade: websocket, Key: ...
    S->>C: 101 Switching Protocols, Accept: ...
    end

    rect rgb(255,252,240)
    Note over C,S: 2. Bidirectional frames (не HTTP)
    C->>S: text frame: "hello"
    S->>C: text frame: "welcome"
    end

    rect rgb(245,255,245)
    Note over C,S: 3. Server-initiated push
    S->>C: text frame: "notification: order #123"
    end

    rect rgb(255,243,243)
    Note over C,S: 4. Close
    C->>S: close frame (code=1000)
    S->>C: close frame (code=1000)
    end
```

**Проблемы:**
- Stateful (сложнее масштабировать — нужен sticky session или broadcast через Redis pub/sub)
- Не кэшируется
- TLS termination на proxy (nginx) должен поддерживать `Upgrade`

### 17. Что такое API Gateway и его функции

**API Gateway** — единая точка входа для клиентских запросов к микросервисам (см. также вопрос 422). Функции:
- **Маршрутизация** — по URL/path → нужный микросервис
- **Аутентификация и авторизация** — проверка JWT, OAuth2
- **Rate limiting** — ограничение по клиенту/IP
- **TLS termination**
- **Caching** — кэш ответов (idempotent GET)
- **Logging и metrics** — единый лог всех запросов
- **Transformation** — преобразование запроса (REST → gRPC, versioning)
- **Circuit breaker** — защита от каскадных сбоев
- **Versioning** — `/api/v1/...` vs `/api/v2/...`

**Примеры:** AWS API Gateway, Kong, Apigee, Zuul (Netflix), Spring Cloud Gateway.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
graph LR
    Client["Client"]
    subgraph GW ["API Gateway"]
        Auth["Auth (JWT/OAuth2)"]
        RateLimit["Rate limiting"]
        Route["Routing (path → service)"]
        Transform["Transform (REST→gRPC)"]
        CB["Circuit breaker"]
    end
    subgraph Svcs ["Микросервисы"]
        S1["Order Service"]
        S2["User Service"]
        S3["Payment Service"]
    end
    Client -->|HTTPS| GW
    GW --> S1
    GW --> S2
    GW --> S3
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class Client n0
    class Auth n1
    class RateLimit n1
    class Route n1
    class Transform n1
    class CB n1
    class S1 n2
    class S2 n2
    class S3 n2
    class GW n3
    class Svcs n3
```

**Spring Cloud Gateway (reactive):**
```java
@Bean
public RouteLocator routes(RouteLocatorBuilder builder) {
    return builder.routes()
        .route("orders", r -> r.path("/api/orders/**")
            .filters(f -> f.rewritePath("/api/orders/(?<seg>.*)", "/orders/$\{seg}"))
            .uri("lb://order-service"))
        .route("users", r -> r.path("/api/users/**")
            .uri("lb://user-service"))
        .build();
}
```

### 18. Что такое mTLS и зачем он нужен

**mTLS** (mutual TLS) — расширение TLS, при котором **и клиент, и сервер** предъявляют сертификаты друг другу. В обычном TLS проверяется только сервер (клиент доверяет CA).

**Как работает:**
1. ClientHello
2. ServerHello + Certificate (сервер)
3. **CertificateRequest** (сервер просит сертификат клиента)
4. Клиент → Certificate (клиент) + CertificateVerify
5. Дальше — шифрованный обмен

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(245,248,255)
    Note over C,S: 1. ClientHello
    C->>S: ClientHello (cipher suites, SNI)
    end

    rect rgb(255,252,240)
    Note over C,S: 2. ServerHello + Certificate
    S->>C: ServerHello
    S->>C: Certificate (server cert)
    S->>C: CertificateRequest (просит cert клиента)
    S->>C: Finished
    end

    rect rgb(245,255,245)
    Note over C,S: 3. Client Certificate (mTLS отличие)
    C->>C: проверка server cert
    C->>S: Certificate (client cert)
    C->>S: CertificateVerify (подпись)
    C->>S: Finished
    end

    rect rgb(243,246,255)
    Note over C,S: 4. Шифрованный обмен
    C->>S: encrypted data
    S->>C: encrypted data
    end
```

**Зачем mTLS:**
- **Zero Trust** — сервисы в микросервисной архитектуре удостоверяют друг друга
- **Kubernetes Service Mesh** (Istio, Linkerd) — автоматический mTLS между подами (см. вопрос 617)
- **High-security environments** — банковские API, IoT
- **Безопасность без IP-based аутентификации** — сертификат = идентичность

**Пример (Kubernetes + Istio):**
```yaml
# Включаем mTLS по умолчанию в namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT   # mTLS обязателен
```

**Как получить сертификаты для mTLS:**
- **Private CA** (свой) — для внутренней сети
- **Public CA** (Let's Encrypt, DigiCert) — для публичных API
- **SPIFFE/SPIRE** — стандарт для сервис-идентичности (Kubernetes, service mesh)

### 19. Что такое service mesh и зачем он нужен

**Service Mesh** — слой сетевой абстракции для микросервисов, который «встраивается» в каждый под (sidecar-прокси) и предоставляет:
- **mTLS** между сервисами (автоматически)
- **Traffic management** — canary, A/B, retries, timeouts
- **Observability** — distributed tracing, metrics
- **Resilience** — circuit breaker, bulkhead
- **Service discovery** — автоматический

**Примеры:** **Istio** (самый популярный), **Linkerd**, **Cilium** (eBPF-based, без sidecar).

**Архитектура Istio:**
```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TD
    subgraph Cluster[Kubernetes cluster]
        subgraph PodA[Pod A]
            AppA[App]
            EnvoyA[Envoy sidecar]
            AppA --> EnvoyA
        end
        subgraph PodB[Pod B]
            AppB[App]
            EnvoyB[Envoy sidecar]
            AppB --> EnvoyB
        end
        EnvoyA <-->|mTLS| EnvoyB
    end
    CP[Istio Control Plane]
    CP -.->|policies| EnvoyA
    CP -.->|policies| EnvoyB
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n3 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class AppA n0
    class AppB n0
    class EnvoyA n1
    class EnvoyB n1
    class CP n2
    class PodA n3
    class PodB n3
    class Cluster n3
```

**Когда нужен service mesh:**
- Много микросервисов (>10)
- Нужен mTLS без ручного управления сертификатами
- Нужны advanced traffic policies (canary, retries)
- Нужна observability без изменений в коде

**Когда не нужен:**
- Малое число сервисов (простые таймауты/retries в коде)
- Высокая чувствительность к latency (sidecar = overhead)
- Команда не готова к сложности (Istio — это «зверь»)

### 20. Что такое networking в Kubernetes (Pod, Service, Ingress)

**Уровни сети в K8s:**
1. **Pod** — имеет свой IP (ClusterIP), доступен внутри кластера
2. **Service** — виртуальный IP + DNS имя, балансировка между подами
   - `ClusterIP` (по умолчанию) — только внутри кластера
   - `NodePort` — открывает порт на каждом ноде (30000-32767)
   - `LoadBalancer` — внешний cloud LB (AWS ELB, GCP LB)
   - `ExternalName` — CNAME на внешний DNS
3. **Ingress** — L7 маршрутизация (по host/path) на Service
4. **NetworkPolicy** — firewall между подами (allow/deny по label)

**Пример Service + Ingress:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
```

**DNS в K8s:**
- Pod: `pod-name.namespace.svc.cluster.local`
- Service: `service-name.namespace.svc.cluster.local`
- CoreDNS (по умолчанию) резолвит имена внутри кластера

**NetworkPolicy (firewall):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-only
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: frontend
      ports:
        - port: 8080
```

### 21. Что такое DNS в Kubernetes и как работает service discovery

**DNS в K8s** — CoreDNS (по умолчанию) или coredns + node-local DNS cache. Каждый Service получает DNS-запись:
- `service-name.namespace.svc.cluster.local` → ClusterIP
- `service-name.svc.cluster.local` (default namespace)

**Как работает:**
1. Приложение в поде делает `getaddrinfo("api-svc.default.svc.cluster.local")`
2. Запрос идёт на CoreDNS (Service `kube-dns` в namespace `kube-system`)
3. CoreDNS резолвит в ClusterIP (виртуальный IP)
4. Traffic идёт через kube-proxy (iptables/ipvs) на поды с соответствующими label

**Service discovery — два подхода:**
- **DNS-based** (по умолчанию) — приложение резолвит имя в IP
- **Client-side** — приложение опрашивает API K8s (Kube Client) и выбирает под

**Headless Service** (`clusterIP: None`):
- Не создаёт виртуальный IP
- DNS возвращает **все** IP подов (round-robin)
- Используется для statefulset (каждый под имеет стабильное имя)

**Пример:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None   # headless
  selector:
    app: postgres
  ports:
    - port: 5432
```

Тогда `postgres-0.postgres.default.svc.cluster.local` резолвится в IP первого пода.

### 22. Что такое Zero Trust Network

**Zero Trust** — модель безопасности, где **никому не доверяем по умолчанию** (ни внутренним пользователям, ни сервисам, ни устройствам). Каждый запрос авторизуется независимо.

**Принципы:**
1. **Never trust, always verify** — каждый запрос проверяется (даже из внутренней сети)
2. **Least privilege** — минимальные права
3. **Micro-segmentation** — сеть разбита на зоны, между ними — firewall
4. **Assume breach** — предположим, что сеть уже скомпрометирована
5. **Continuous verification** — постоянная проверка (не «раз при входе»)

**Как реализовать:**
- **mTLS** между сервисами (service mesh)
- **Identity-based access** (OAuth2, OIDC, SPIFFE)
- **Network segmentation** (NetworkPolicy в K8s, VPC в облаке)
- **Micro-segmentation** — каждый под имеет свою политику
- **Zero Trust Network Access (ZTNA)** — альтернатива VPN (CloudFlare Access, Zscaler)

**Противопоставление «perimeter security»:**
- **Классика** — «внутри — доверяем, снаружи — нет» (VPN)
- **Zero Trust** — «внутри и снаружи — проверяем каждый запрос»

**Технологии Zero Trust:**
- **SPIFFE/SPIRE** — standard для сервис-идентичности
- **Service mesh** (Istio, Linkerd) — mTLS + policies
- **ZTNA** — CloudFlare Access, Zscaler, Palo Alto Prisma
- **IAM** — AWS IAM, Okta, Keycloak

### 23. Что такое QUIC и в чём его преимущества

**QUIC** (Quick UDP Internet Connection) — современный транспортный протокол (RFC 9000), работающий **поверх UDP**. Сочетает в себе возможности TCP (надёжная доставка, порядок, контроль потока) и шифрование TLS 1.3 **в одном стеке**, без отдельных handshakes.

**Ключевые особенности:**
- **1-RTT handshake** (TLS + transport в одном обмене); для возвращающихся клиентов — **0-RTT** (data сразу).
- **Multiplexing** — множество независимых **streams** в одном соединении; потеря пакета в одном stream **не блокирует** другие (нет head-of-line blocking на транспортном уровне).
- **Built-in TLS 1.3** — шифрование с первого пакета (в отличие от TLS поверх TCP, где handshake идёт открытым текстом).
- **Connection migration** — смена IP/сети (Wi-Fi → LTE) **не рвёт** соединение (connection ID ≠ IP:port).
- **Congestion control** — на уровне приложения (каждый реализует свой алгоритм: Cubic, BBR).

**Противопоставление TCP:**
| Критерий | TCP + TLS | QUIC |
|----------|-----------|------|
| Transport | TCP (reliable, ordered) | UDP (best-effort) |
| Handshake | TCP 3-way + TLS (2-RTT) | 1-RTT (0-RTT return) |
| Head-of-line blocking | да (один stream) | нет (множество streams) |
| Encryption | после handshake | с первого пакета |
| Network changes | connection break | migration (connection ID) |
| Port | 80/443 | 443 (обычно) |

**Примеры использования:**
- **HTTP/3** — HTTP поверх QUIC (по умолчанию в Chrome на HTTPS с 2023)
- **gRPC over QUIC** (экспериментально)
- **CDN/edge** — CloudFlare, AWS CloudFront

**Проблемы:**
- Некоторые firewalls блокируют UDP (QoS, corporate proxies)
- Меньше зрелости в инструментах (Wireshark, tcpdump хуже читают QUIC)
- Конгестия на уровне приложения — сложнее дебажить

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant S as Server

    rect rgb(245,248,255)
    Note over C,S: 1. QUIC 1-RTT handshake (новый клиент)
    C->>S: Initial (ClientHello + TLS 1.3, conn_id)
    S->>C: Initial (ServerHello + TLS 1.3, cert)
    C->>C: проверка cert, ECDHE
    C->>S: 1-RTT data (шифровано)
    end

    rect rgb(255,252,240)
    Note over C,S: 2. 0-RTT (возвращающийся клиент)
    C->>S: 0-RTT data (шифровано, early data)
    S->>C: response
    end

    rect rgb(245,255,245)
    Note over C,S: 3. Connection migration
    C->>C: смена сети (Wi-Fi → LTE, новый IP)
    C->>S: data (тот же conn_id, новый IP)
    S->>C: response (тот же conn_id)
    Note over C,S: соединение не разорвано
    end
```

### 24. Что такое HTTP/3 и чем он отличается от HTTP/2

**HTTP/3** — третья версия HTTP, работающая **поверх QUIC** (а не TCP, как HTTP/1.1 и HTTP/2). Основные отличия от HTTP/2:

**Что изменено:**
- **Транспорт**: QUIC (UDP) вместо TCP → нет head-of-line blocking на транспортном уровне.
- **Handshake**: 1-RTT (TLS + transport вместе) vs 2-RTT (TCP + TLS по отдельности).
- **Multiplexing**: на уровне QUIC streams (не TCP) → потеря пакета не блокирует другие запросы.
- **Connection migration**: смена IP не рвёт соединение (важно для мобильных).
- **Encrypted frames**: заголовки и данные шифруются с первого пакета (в HTTP/2 TLS шифрует после handshake, но сам TCP-слой открытый).

**Сохранено от HTTP/2:**
- Binary framing
- Header compression (HPACK)
- Multiplexing (но на новом уровне)
- Priority

**Когда HTTP/3:**
- Мобильные клиенты (смена сети Wi-Fi ↔ LTE)
- Высоко-латентные сети (потери пакетов)
- CDN/edge (быстрее handshake)

**Практика:**
- Бrowsers: Chrome (default на HTTPS), Firefox (default), Safari (experimental)
- Серверы: nginx 1.25+, Caddy, Envoy, AWS CloudFront
- **Fallback**: если QUIC недоступен (firewall блокирует UDP) → автоматически переход на HTTP/2 (TCP)

```bash
# Проверить поддерживает ли сайт HTTP/3
curl --http3 https://example.com
# или в браузере: chrome://net-internals#hsts
```

### 25. Что такое WebRTC и как он работает

**WebRTC** (Web Real-Time Communication) — набор браузерных API для **real-time** передачи аудио, видео и данных между браузерами (peer-to-peer) без плагинов. Работает на трёх уровнях:

**Протокольный стек:**
- **Signaling** (не входит в WebRTC) — обмен SDP offer/answer через WebSocket, HTTP, XMPP. Устанавливает параметры сессии.
- **ICE** (Interactive Connectivity Establishment) — поиск лучшего пути доставки медиа (host, srflx, relay). Использует STUN (рефлексивные адреса) и TURN (реле-сервер).
- **DTLS** — шифрование канала (аналог TLS, но на UDP).
- **RTP/RTCP** — транспорт медиа (Real-time Transport Protocol). RTP — пакеты медиа, RTCP — статистика и контроль.
- **SRTP** — шифрованные RTP (после DTLS handshake).
- **DataChannel** — произвольные данные поверх DTLS (reliable/unreliable, ordered/unordered).

**SDP** (Session Description Protocol) — текстовый формат описания сессии: какие кодеки, порты, IP, ICE candidates.

**Кодирование:**
- **Видео**: H.264 (AVC), VP8, VP9, AV1
- **Аудио**: Opus (по умолчанию), G.711
- **Данные**: protobuf, JSON, raw bytes (DataChannel)

**ICE candidates (типы):**
- **host** — локальный IP (192.168.x.x)
- **srflx** (server reflexive) — через STUN (публичный IP)
- **relay** — через TURN (реле-сервер, когда NAT симметричный)

**Проблемы WebRTC:**
- **NAT traversal** — симметричный NAT требует TURN (иначе не соединятся)
- **Codec negotiation** — несовместимость кодеков (пример: Pion v4 не выдаёт `/2` в rtpmap для Opus stereo)
- **Connection migration** — смена сети рвёт DTLS/RTP (в отличие от QUIC)
- **Latency** — realtime требования (audio <150ms, video <300ms)

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant A as Peer A (offerer)
    participant S as Signaling (WS)
    participant B as Peer B (answerer)
    participant ST as STUN
    participant TU as TURN

    rect rgb(245,248,255)
    Note over A,B: 1. SDP offer/answer (через signaling)
    A->>S: SDP offer (codecs, ICE ufrag/pwd)
    S->>B: relay offer
    B->>B: createAnswer()
    B->>S: SDP answer
    S->>A: relay answer
    end

    rect rgb(255,252,240)
    Note over A,ST: 2. ICE gathering
    A->>ST: STUN request
    ST-->>A: reflexive IP
    A->>B: ICE candidate (host + srflx)
    B->>A: ICE candidate
    end

    rect rgb(245,255,245)
    Note over A,B: 3. ICE pair selection
    A->>B: connectivity check (UDP)
    B-->>A: success
    A->>A: best pair selected
    end

    rect rgb(243,246,255)
    Note over A,B: 4. DTLS handshake
    A->>B: DTLS ClientHello
    B->>A: DTLS ServerHello + cert
    A->>B: DTLS Finished
    end

    rect rgb(245,248,255)
    Note over A,B: 5. Media flow (SRTP)
    A->>B: SRTP (video H.264)
    B->>A: SRTP (audio Opus)
    A->>B: RTCP (stats)
    end
```

**Когда WebRTC:**
- Видеозвонки, видеоконференции
- Realtime chat (голос, видео)
- Multiplayer-игры (low latency)
- File sharing peer-to-peer
- Remote desktop / screen sharing (scrcpy-like)

**Противопоставление WebSocket:**
- **WebSocket** — full-duplex, reliable, ordered (для команд, событий)
- **WebRTC DataChannel** — reliable/unreliable, ordered/unordered (для медиа, realtime данных)
- **WebRTC RTP** — media-only, low latency, loss-tolerant

**Примеры реализации:**
- Браузеры: Chrome, Firefox, Safari (нативная поддержка)
- Серверы: Pion (Go), mediasoup (Node.js), Janus (C)
- Cloud: AWS IVS, LiveKit, Daily, Agora


