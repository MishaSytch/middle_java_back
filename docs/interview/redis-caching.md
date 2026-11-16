# Redis и кэширование


### 1. Что такое Redis и почему он быстрый

**Redis** (REmote DIctionary Server) — in-memory хранилище данных типа «ключ-значение» с расширенными структурами данных. Основные типы: `String` (строки, счётчики, бинарные данные), `Hash` (объекты — поля-значения), `List` (связные списки — очереди, ленты), `Set` (множества), `Sorted Set / ZSet` (множество с баллом — рейтинги, лидерборды), `Stream` (журнал событий), плюс Bitmap, HyperLogLog, Geo.

Почему быстрый:
- **Данные в памяти** — нет обращения к диску на каждый запрос (диск используется только для персистентности).
- **Однопоточное ядро** обработки команд — нет блокировок и переключений контекста на путь запроса (I/O в новых версиях частично многопоточен).
- **Мультиплексирование I/O** (epoll) — один поток обслуживает десятки тысяч соединений.
- **Экономичные структуры данных** (SDS-строки, зиплисты/listpack для маленьких коллекций).

Типичная производительность — 100К+ операций в секунду на инстанс. Применение: кэш, сессии, счётчики/лимитеры (rate limiting), распределённые локи, pub/sub, лидерборды. Клиент в Java — **Lettuce** (по умолчанию в Spring Boot, netty-based, потокобезопасен) или **Jedis**.

```java
try (Jedis jedis = pool.getResource()) {
    jedis.setex("user:42:session", 3600, json);  // ключ с TTL 1 час
    jedis.hset("user:42", Map.of("name", "Anna", "age", "30")); // Hash
    jedis.zadd("leaderboard", 1250, "user:42");  // Sorted Set: балл = очки
    long top = jedis.zrevrank("leaderboard", "user:42"); // место в рейтинге
}
```

### 2. Redis vs Memcached — что выбрать

| Критерий | Redis | Memcached |
|---|---|---|
| Структуры данных | String, Hash, List, Set, ZSet, Stream | Только строки/байты |
| Персистентность | RDB-снапшоты + AOF-журнал | Нет (только память) |
| Репликация/отказоустойчивость | Реплики, Sentinel, Cluster | Простая клиентская шардинг-логика |
| Максимальный размер значения | 512 МБ | 1 МБ (по умолчанию) |
| Многопоточность | Однопоточное ядро (+многопоточный I/O) | Многопоточный |
| Дополнительно | Lua-скрипты, pub/sub, транзакции, локи | Простой кэш |

**Вывод:** Memcached исторически выбирали для простейшего кэша маленьких объектов с очень высокой конкуренцией; практически во всех новых проектах выбирают Redis — структуры данных, персистентность, кластеризация и экосистема (Spring Data Redis, Redisson) перекрывают сценарий Memcached. Если нужен «просто кэш строк» и уже есть Memcached — он тоже жизнеспособен, но начинать новый проект на нём причин мало.

### 3. Что такое паттерн Cache-Aside (кэширование сбоку)

**Cache-Aside (Lazy Loading)** — самый распространённый паттерн кэширования: приложение само управляет кэшем, БД остаётся источником истины.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    classDef client fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef service fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef storage fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937

    App["Application"]:::client
    Redis[("Redis Cache")]:::storage
    DB[("PostgreSQL")]:::storage

    App -->|"1. GET user:42"| Redis
    Redis -->|"2a. HIT: return"| App
    Redis -->|"2b. MISS"| App
    App -->|"3. SELECT FROM users"| DB
    DB -->|"4. row"| App
    App -->|"5. SET user:42 EX 600"| Redis
```

Чтение: 1) ищем в кэше — **cache hit**: возвращаем; 2) **cache miss**: читаем из БД, кладём в кэш с TTL, возвращаем. Запись: сохраняем в БД, затем **инвалидируем** кэш (удалить ключ), а не обновляем его.

```java
public User getUser(long id) {
    String key = "user:" + id;
    User cached = redis.get(key);                 // 1. попытка из кэша
    if (cached != null) return cached;            // hit — 0 обращений к БД

    User user = repository.findById(id)           // 2. miss — идём в БД
        .orElseThrow(() -> new NotFoundException(id));
    redis.setex(key, Duration.ofMinutes(10), user); // 3. кладём с TTL
    return user;
}

public void updateUser(User u) {
    repository.save(u);
    redis.del("user:" + u.id());                  // инвалидация, не обновление
}
```

Плюсы: кэш содержит только реально запрашиваемые данные, сбой кэша не ломает систему (деградация к скорости БД), простота. Минусы: первый запрос после miss всегда медленный (cold start), код кэширования размазан по сервису. Почему при записи **инвалидируют, а не обновляют**: обновление может перезаписать свежее значение устаревшим (гонка двух писателей), а удаление заставляет следующий запрос перечитать актуальные данные из БД.

### 4. Что такое Write-Through, Write-Behind и Write-Around

Стратегии записи при кэшировании:

- **Write-Through** — запись идёт одновременно в кэш и в БД (кэш в пути записи). Данные в кэше всегда актуальны; каждая запись чуть медленнее. Хорош для read-heavy данных, которые читают сразу после записи.
- **Write-Behind (Write-Back)** — пишем в кэш, ответ отдаём сразу, а в БД данные попадают асинхронно (пакетно). Очень быстрый, но при падении кэша теряются незафлашенные записи — нужна репликация кэша и аккуратность. Редко оправдан в бизнес-данных, часто — в метриках/счётчиках.
- **Write-Around** — пишем напрямую в БД, кэш наполняется только при чтении (по сути Cache-Aside на чтение). Данные, записанные и не прочитанные, не замусоривают кэш.

```java
// Write-Through: синхронная запись в оба хранилища
public void save(User u) {
    repository.save(u);
    redis.setex("user:" + u.id(), ttl, u);   // кэш обновлён до ответа клиенту
}

// Write-Behind: быстрый ответ, отложенный flush
public void incrementViews(long videoId) {
    redis.incr("video:" + videoId + ":views");       // мгновенно
    flusher.schedule(videoId);                        // пакетная запись в БД раз в N сек
}
```

### 5. Что такое TTL и как устроено истечение ключей в Redis

**TTL (time to live)** — время жизни ключа. Задаётся при записи (`SETEX`, `SET ... EX 60`) или позже (`EXPIRE`). В Java-клиентах — `setex`/`set(key, value, Duration)`. TTL сбрасывается при перезаписи ключа командой `SET`.

Redis удаляет истёкшие ключи **двумя механизмами** (ленивая + активная очистка):
1. **Ленивое (passive)**: ключ проверяется при обращении — если истёк, клиент получает `null`, ключ удаляется.
2. **Активное (active)**: фоновый поток каждые 100 мс проверяет случайную выборку ключей с TTL и удаляет истёкшие.

Выбор TTL — компромисс: слишком длинный — устаревшие данные и рост памяти; слишком короткий — постоянные miss и нагрузка на БД. Практика: TTL = несколько минут для «горячих» справочников, часы — для стабильных данных; плюс **джиттер** (например, 10 ± 2 минуты), чтобы ключи не истекали синхронно и не вызывали штампед.

### 6. Что такое Cache Stampede (скачок кэша — «толпа» запросов после истечения ключа) и как с ним бороться

**Cache stampede (thundering herd)** — ситуация: «горячий» ключ истекает, и сотни параллельных запросов одновременно видят miss и идут в БД с одним и тем же тяжёлым запросом. БД получает всплеск нагрузки, деградирует, таймауты множат retries — каскадный сбой.

Способы борьбы:
1. **Мьютекс/блокировка на пересчёт**: один запрос берёт лок (например, `SET key:lock NX EX 5`), пересчитывает значение и пишет в кэш; остальные коротко ждут или возвращают старое значение.
2. **Прогрев заранее (early recomputation)**: хранить логическое время истечения внутри значения; когда до реального TTL осталось 10%, один из запросов асинхронно обновляет кэш, пока все продолжают читать старое значение (перенос перерасчёта в фон).
3. **Никогда не истекающий ключ + инвалидация при записи** — для данных, которые меняются редко.
4. **Rate limiting / bulkhead** на обращения к БД как страховка.

```java
public User getUser(long id) {
    String key = "user:" + id;
    User u = redis.get(key);
    if (u != null) return u;

    if (redis.setNxEx(key + ":lock", "1", Duration.ofSeconds(5))) {
        try {
            u = repository.findById(id).orElseThrow();
            redis.setex(key, ttlWithJitter(), u);   // только один пересчитывает
            return u;
        } finally { redis.del(key + ":lock"); }
    }
    Thread.sleep(50);                               // остальные — короткое ожидание
    return redis.get(key);                          // и повторная попытка из кэша
}
```

### 7. Что такое cache penetration (пробитие кэша) и кэширование null-значений

**Cache penetration** — запросы к данным, которых **не существует**: их нет ни в кэше, ни в БД. Каждый такой запрос всегда проходит до БД (miss), и атакующий может забить БД миллионами запросов несуществующих id.

Защиты:
1. **Кэшировать пустой результат** — положить в кэш маркер отсутствия с коротким TTL (30–60 сек): следующий запрос такого id получит быстрый «нет».
2. **Bloom filter** перед кэшем — вероятностная структура: «id точно отсутствует в наборе» отсекает запрос до БД.
3. **Валидация входных данных** — id по формату (диапазоны, UUID) отбрасываются на входе.
4. **Rate limiting** по клиенту/IP.

```java
private static final User ABSENT = new User(); // маркер-пустышка

public Optional<User> getUser(long id) {
    User cached = redis.get("user:" + id);
    if (cached != null) {
        return cached.id() == 0 ? Optional.empty() : Optional.of(cached); // маркер
    }
    Optional<User> db = repository.findById(id);
    // В БД тоже нет — кладём маркер на 30 сек, чтобы не бить БД каждый раз
    redis.setex("user:" + id, db.isPresent() ? TTL_LONG : Duration.ofSeconds(30),
                db.orElse(ABSENT));
    return db;
}
```

### 8. Как инвалидируют кэш и какие есть стратегии инвалидации

Инвалидация — удаление устаревших записей кэша. Стратегии:

1. **TTL** — простое время жизни. Всегда как страховка, редко как единственный механизм (между обновлением БД и истечением TTL данные в кэше неконсистентны).
2. **Инвалидация при записи (invalidate-on-write)** — после коммита в БД удаляем затронутые ключи. Проблема: нужно знать все ключи, зависящие от данных, и не забывать ни одну точку записи.
3. **Событийная инвалидация** — публикуем доменное событие (Kafka «UserUpdated»), отдельный обработчик инвалидирует кэш; работает и между сервисами (кэш пользователя в сервисе заказов).
4. **Версионирование ключей** — ключ включает версию данных: `user:{id}:v{version}`; при изменении версии старые ключи естественным образом уходят (по TTL).
5. **Краткий TTL + допускаемая просрочка** — бизнес-решение: если данные могут быть неактуальны N минут, TTL N/2 и никакой сложной логики.

Практика: комбинировать **короткий TTL как основу + событийную инвалидацию для чувствительных данных + версионирование для тяжёлых агрегатов**. В distributed-среде помните про гонку «запись в БД → инвалидация → параллельный miss → чтение старого значения из реплики БД → запись старого в кэш»; лечится версионированием или кратким TTL.

### 9. Как работает Spring Cache (@Cacheable, @CachePut, @CacheEvict)

Spring Cache — абстракция кэширования поверх AOP: методы перехватываются прокси, результат кладётся в `CacheManager` (Redis, Caffeine, Ehcache). Включение — `@EnableCaching` + зависимость (`spring-boot-starter-data-redis`) + `spring.cache.type=redis`.

- **`@Cacheable`** — перед вызовом метода смотрим в кэш; hit — метод не вызывается; miss — вызов и сохранение результата.
- **`@CachePut`** — метод выполняется всегда, результат кладётся в кэш (для обновления).
- **`@CacheEvict`** — удаляет записи (все `allEntries = true` или по ключу).
- **`@Caching`** — комбинация нескольких операций. **`cacheManager`** — выбор менеджера, **`condition`/`unless`** — условия кэширования (`unless = "#result == null"`).

```java
@Service
public class ProductService {
    @Cacheable(cacheNames = "products", key = "#id",
               unless = "#result == null")
    public Product get(long id) {
        return repository.findById(id).orElse(null);   // heavy query
    }

    @CachePut(cacheNames = "products", key = "#product.id")
    public Product update(Product product) {
        return repository.save(product);               // обновили и в кэше
    }

    @CacheEvict(cacheNames = "products", allEntries = true)
    public void recalculateAll() { /* массовый пересчёт */ }
}
```

Подводные камни: **self-invocation** (внутренний вызов `this.get()` идёт мимо прокси — кэш не работает, та же проблема, что у `@Transactional`); аннотации не работают на `private`-методах; `null` по умолчанию не кэшируется; ключ по умолчанию — `SimpleKey(аргументы)`, для объектов-аргументов нужен корректный `equals/hashCode` или SpEL-ключ.

**Критические подводные камни Spring Cache:**
1. **Генерация ключей:** По умолчанию Spring использует `SimpleKey`, создавая ключи вида `SimpleKey [123]`. Это делает ручную отладку и инвалидацию сложной. **Всегда** явно указывай `key = "#id"` или `key = "#user.login"`.
2. **Сериализация:** По умолчанию Spring может использовать JDK-сериализацию, которая хрупка к изменениям классов и создаёт нечитаемые ключи в Redis. Обязательно настраивай `GenericJackson2JsonRedisSerializer` или `StringRedisSerializer`.
3. **Кэширование null:** По умолчанию Spring не кэширует `null`. Если метод вернул `null` (запись не найдена), следующий запрос снова пойдёт в БД (риск Cache Penetration). Включай `cache-null-values = true` и задавай короткий TTL для таких записей.

### 10. Как настроить Redis в Spring Boot и какой TTL задать ключам

Конфигурация подключения и сериализации:

```yaml
spring:
  data:
    redis:
      host: redis-host
      port: 6379
  cache:
    type: redis
    redis:
      time-to-live: 10m           # глобальный TTL для всех кэшей
      cache-null-values: false    # не кэшировать null
```

```java
@Bean
public RedisCacheManager cacheManager(RedisConnectionFactory cf) {
    RedisCacheConfiguration base = RedisCacheConfiguration.defaultCacheConfig()
        .entryTtl(Duration.ofMinutes(10))                          // дефолт
        .serializeValuesWith(SerializationPair.fromSerializer(
            new GenericJackson2JsonRedisSerializer()));            // JSON вместо JDK-сериализации

    Map<String, RedisCacheConfiguration> perCache = Map.of(
        "products", base.entryTtl(Duration.ofHours(1)),            // стабильный справочник
        "stock",    base.entryTtl(Duration.ofSeconds(30)));        // часто меняется

    return RedisCacheManager.builder(cf)
        .cacheDefaults(base)
        .withInitialCacheConfigurations(perCache)
        .build();
}
```

Практика TTL: различать кэши по природе данных; добавлять джиттер; не хранить в Redis то, что страшно потерять без персистентности; для JDK-сериализации помнить, что она хрупка к изменениям классов — JSON-сериализатор удобнее для кэша.

### 11. Чем кэш Hibernate второго уровня отличается от Redis-кэша

**L2-кэш Hibernate** — кэш **сущностей и коллекций** на уровне EntityManagerFactory (провайдеры: Ehcache, Infinispan, Caffeine). Работает в терминах ORM: ключ — «сущность + id», данные — снимки состояния сущностей; учитывает dirty checking и пространства имен таблиц для инвалидации.

- **Что кэширует:** только сущности по первичному ключу (`em.find`) и коллекции; **запросы** кэширует отдельно Query Cache (с осторожностью).
- **Локальность:** в кластере каждый узел держит свой L2 (нужен распределённый провайдер), в то время как Redis — единый кэш для всех инстансов.
- **Согласованность:** L2 согласован с текущей сессией Hibernate; Redis-кэш на уровне сервиса должен инвалидироваться вручную.
- **Когда какой:** L2 — для часто читаемых по id справочников внутри одного приложения; Redis — когда кэш нужен нескольким сервисам, для DTO/агрегатов и когда важен контроль TTL/инвалидации.

```java
@Entity
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)  // включение L2 для сущности
public class Currency { ... }

// application.properties
spring.jpa.properties.hibernate.cache.use_second_level_cache=true
spring.jpa.properties.hibernate.cache.region.factory_class=jcache
```

На собеседовании важно назвать уровни: **L1** — кэш сессии (всегда включён), **L2** — фабрики сессий (опционален), **Query Cache** — результаты запросов.

### 12. Как Redis обеспечивает персистентность (RDB и AOF)

По умолчанию Redis хранит всё в памяти, но умеет сохраняться на диск двумя способами:

- **RDB (snapshots)** — периодические бинарные снапшоты всего датасета (настраиваются `save 900 1` — «если за 900 сек ≥1 изменения»). Плюсы: компактный файл, быстрый рестарт, не влияет на latency запросов (fork + copy-on-write). Минусы: теряются данные с последнего снапшота.
- **AOF (Append Only File)** — журнал всех команд записи, включается `appendonly yes`. Плюсы: потеря максимум ~1 сек (`appendfsync everysec`) или ноль (`always`, медленно). Минусы: файл больше, реконструкция дольше; периодический rewrite (AOF rewrite) сжимает журнал.
- Комбинация **RDB + AOF** — типовой прод-выбор: AOF для долговечности, RDB для быстрого рестарта и бэкапов.

Для чисто кэш-сценариев персистентность часто отключают: если кэш потерян, он прогреется из БД. Для данных-источников (сессии, локи, счётчики) — обязательно AOF + реплика.

### 13. Как сделать распределённую блокировку через Redis

Когда несколько инстансов сервиса не должны выполнять операцию одновременно (идемпотентный обработчик, пересчёт отчёта), лок в памяти JVM не помогает — нужна **распределённая блокировка**. Redis даёт её через атомарный `SET key value NX EX ttl`:

- `NX` — установить только если ключа нет (соревнование выигрывает один);
- `EX ttl` — автособождение, если владелец умер.

```java
public boolean tryLock(String key, String owner, Duration ttl) {
    return Boolean.TRUE.equals(redis.setIfAbsent(key, owner, ttl));
}

public void unlock(String key, String owner) {
    // удалять чужой лок нельзя: проверка + удаление атомарно через Lua
    redis.execute(LuaScript.of(
        "if redis.call('get', KEYS[1]) == ARGV[1] " +
        "then return redis.call('del', KEYS[1]) else return 0 end",
        key, owner));
}
```

Тонкости: разблокировка должна проверять **владельца** (Lua-скрипт, как выше) — иначе поток A снимет лок потока B, если тот протух; для долгих операций нужен «продлевающий» поток (watchdog).

**Готовое решение — Redisson:**
В продакшене Java-разработчики обычно используют **Redisson** вместо ручного Lua-скрипта. Основные возможности:
- **`RLock`** — простой распределённый лок.
- **Watchdog** — автоматически продлевает TTL блокировки, пока поток жив. Это предотвращает deadlock, если обработка заняла больше времени, чем TTL.
- **Reentrant-локи** — тот же поток может заблокировать лок повторно (без deadlock).
- **`RReadWriteLock`** — разделяемая блокировка (чтение) и эксклюзивная (запись).
- **RedLock** — вариант для кворума (несколько Redis-инстансов).

```java
// Пример использования Redisson:
RLock lock = redissonClient.getLock("order:12345");
if (lock.tryLock()) {
    try {
        // критическая секция
    } finally {
        lock.unlock();
    }
}
```

Помните: Redis-лок — это оптимизация, а не строгая гарантия (в отказных сценариях возможны два владельца); для строгих гарантий — ZooKeeper/etcd или idempotency-key на операции.

### 14. Какие топологии развертывания Redis бывают

- **Standalone** — один инстанс. Просто, но единственная точка отказа; для кэша приемлемо (потеря кэша деградирует производительность, не данные).
- **Master + Replica** — асинхронная репликация чтений на реплики (`READONLY`), масштабирует чтение и даёт резервную копию; при падении мастера нужен ручной promote.
- **Redis Sentinel** — надстройка над master+replica: 3+ Sentinel-процесса следят за мастером, проводят автоматический failover и сообщают клиентам актуальный мастер (Lettuce умеет по `redis-sentinel://...`). Минус: shards нет — все данные в одном мастере.
- **Redis Cluster** — шардинг на 16384 слота, ключи распределяются по хэш-слотам (`CRC16(key) % 16384`); автоматическая маршрутизация, отказоустойчивость, горизонтальное масштабирование. Ограничения: multi-key операции только по ключам одного слота (`hash tags` вида `{user42}:cart` решают), клиент должен понимать MOVED/ASK.
- Облачные управляемые варианты (Redis Cloud, ElastiCache, Aiven) — по сути вышеописанные топологии как сервис.

Практика для собеса: кэш и сессии — Sentinel достаточно; большой объём или высокая нагрузка записи — Cluster; данные, обрабатываемые мультиключевыми операциями, группируйте hash-tag'ами.

**Hash Tags в Redis Cluster:**
В **Redis Cluster** ключи распределяются по 16384 хэш-слотам. Проблема: мультиключевые команды (`MGET`, `SUNION`, `TRANSACTION`) работают **только если все ключи находятся в одном слоте**. Иначе Redis вернёт ошибку `CROSSSLOT Keys in request don't hash to the same slot`.

**Решение: Hash Tags.** Если в ключе есть подстрока в фигурных скобках `{...}`, Redis хэширует только её.

```text
Ключ: user:123:profile  → хэшируется весь ключ
Ключ: {user:123}:orders → хэшируется только "user:123"
Ключ: {user:123}:cart   → хэшируется только "user:123"
```

Все три ключа выше гарантированно попадут в **один и тот же слот** и на один узел кластера, что позволяет безопасно выполнять над ними атомарные операции или `MGET`, не нарушая архитектуру Cluster.

### 15. Что такое Cache Warming и как избежать Cold Start

**Проблема Cold Start:** после перезапуска приложения или сбоя Redis кэш пуст. Первый же всплеск трафика приводит к массовым `cache miss`, обрушивая нагрузку на БД (thundering herd).

**Стратегии прогрева (Cache Warming):**
1. **Eager Loading (при старте):** Использование `@EventListener(ApplicationReadyEvent.class)` для загрузки самых «горячих» данных (например, топ-1000 товаров) в кэш сразу после подъёма приложения.
2. **Фоновый прогрев (Scheduled):** Периодический `@Scheduled`-джоб, который обновляет кэш до того, как истечёт TTL.
3. **Lazy Loading с защитой:** Если прогрев невозможен, используем паттерн с мьютексом (см. вопрос 6 про Cache Stampede), чтобы только один поток шёл в БД, а остальные ждали или получали устаревшее, но валидное значение.

**Пример (Eager loading):**
```java
@Component
public class CacheWarmer {
    @Autowired private CacheManager cacheManager;
    @Autowired private ProductRepository productRepo;

    @EventListener(ApplicationReadyEvent.class)
    public void warmUp() {
        Cache cache = cacheManager.getCache("products");
        // Горячие товары (топ-1000 по просмотрам):
        List<Product> hot = productRepo.findTop1000ByViews();
        for (Product p : hot) {
            cache.put(p.getId(), p);
        }
        log.info("Cache warmed: {} products", hot.size());
    }
}
```

**Фоновый прогрев:**
```java
@Scheduled(cron = "0 0 * * * *")  // каждый час
public void refreshCache() {
    List<Product> hot = productRepo.findTop1000ByViews();
    for (Product p : hot) {
        cache.put(p.getId(), p);  // перезапись
    }
}
```

**Lazy warming (по первому запросу):**
```java
@Cacheable(value = "products", key = "#id")
public Product getProduct(Long id) {
    return productRepo.findById(id);  // первый вызов → БД, далее → кэш
}
```

**Выбор стратегии:**
| Метод | Когда использовать | Плюсы | Минусы |
|-------|-------------------|-------|--------|
| **Eager** | Горячие ключи (известны заранее) | Нет cold start | Потребляет память (все горячие ключи) |
| **Background** | Периодическое обновление | Данные свежие | Потребляет память, нагрузка на БД |
| **Lazy** | Неизвестные ключи | Память только для доступных | Cold start на первый запрос |

**Вывод:** Cache Warming — это Eager (горячие ключи при старте), Background (периодическое обновление) или Lazy (первый запрос). Eager устраняет cold start, но потребляет память. Background сохраняет свежесть данных. Lazy экономит память (только доступные ключи), но не решает проблему cold start.

### 16. Как выбрать TTL для кэша: trade-off между freshness и hit rate

**TTL (Time-To-Live)** — это время, в течение которого ключ живёт в кэше. Выбор TTL — баланс между **актуальностью данных (freshness)** и **нагрузкой на БД (hit rate)**.

**Trade-off:**
- **Короткий TTL** (например, 1 минута): данные свежие, но hit rate низкий, нагрузка на БД высокая.
- **Длинный TTL** (например, 1 час): hit rate высокий, но данные могут быть устаревшими.

**Как выбрать TTL:**
1. **Волатильность данных:** как часто данные меняются?
   - Редко (справочные данные: валюты, страны) → длинный TTL (1 час / 24 часа).
   - Часто (остатки на складе, курсы акций) → короткий TTL (1 минута) + инвалидация при записи.
2. **Бизнес-требования:** насколько важна актуальность?
   - Критично (платежи, баланс) → короткий TTL (1 минута).
   - Не критично (описание товара, страница) → длинный TTL (1 час).
3. **Нагрузка на БД:** сколько запросов допустимо?
   - Низкая (read-heavy) → длинный TTL (1 час).
   - Высокая (write-heavy) → короткий TTL (1 минута).

**Примеры:**
| Ключ | TTL | Почему |
|------|-----|--------|
| Описание товара | 1 час | Редко меняется, низкая критичность |
| Цена / остаток | 1 минута | Часто меняется, высокая критичность |
| Профиль пользователя | 30 минут | Иногда меняется, средняя критичность |
| Сессия | 30 минут | Неактивность пользователя |
| Справочные данные (страны) | 24 часа | Почти никогда не меняются |

**Jitter (дрожание):**
Если 10 000 ключей созданы одновременно с TTL = 1 час, они все истекут одновременно, вызвав лавину запросов к БД (Cache Stampede). Решение — добавить случайную величину к TTL при записи.

```java
// Без jitter: все ключи истекают одновременно → stampede.
int ttl = 3600;  // 1 час

// С jitter: ключи истекают в разное время → нет stampede.
int ttl = 3600 + ThreadLocalRandom.current().nextInt(600);  // 1 час + 0–10 минут
```

Это «размазывает» время истечения ключей, сглаживая нагрузку на БД.

**Вывод:** TTL зависит от волатильности данных, бизнес-требований и нагрузки на БД. Короткий TTL = свежие данные (но низкий hit rate). Длинный TTL = высокий hit rate (но устаревшие данные). Jitter предотвращает синхронное истечение ключей.

### 17. Как Redis справляется с memory pressure: eviction policies

**Memory pressure** — ситуация, когда память Redis заполнена, и нужно освободить место, выбросив часть ключей.

**Eviction policies (политики выброса):**
| Политика | Описание |
|-----------|----------|
| `noeviction` | Не выбрасывать (новые записи → ошибка) |
| `allkeys-lru` | Выбросить LRU (least recently used) из всех ключей |
| `allkeys-lfu` | Выбросить LFU (least frequently used) из всех ключей |
| `allkeys-random` | Выбросить случайный ключ из всех ключей |
| `volatile-lru` | Выбросить LRU из ключей с TTL |
| `volatile-lfu` | Выбросить LFU из ключей с TTL |
| `volatile-random` | Выбросить случайный ключ из ключей с TTL |
| `volatile-ttl` | Выбросить ключ с минимальным TTL из ключей с TTL |

**Как выбрать политику:**
- **Кэш** (все ключи — кэш) → `allkeys-lru` (или `allkeys-lfu`).
- **Сессии** (ключи с TTL) → `volatile-lru` (или `volatile-lfu`).
- **Критичные данные** (нельзя выбрасывать) → `noeviction` (но новые записи будут ошибкой).

**Настройка:**
```bash
# В конфигурации Redis:
maxmemory 1gb
maxmemory-policy allkeys-lru
```

```yaml
# В docker-compose:
redis:
  command: redis-server --maxmemory 1gb --maxmemory-policy allkeys-lru
```

**LRU vs LFU:**
- **LRU** (Least Recently Used): выбрасывает ключ, который не использовался давно. Проще (O(1)), но может выбросить ключ, который используется редко, но последне.
- **LFU** (Least Frequently Used): выбрасывает ключ, который используется редко. Точнее (учитывает частоту использования), но сложнее (нужно отслеживать счётчики).

**Вывод:** При memory pressure Redis применяет eviction policy. Для кэша — `allkeys-lru` (или `allkeys-lfu`). Для сессий (ключи с TTL) — `volatile-lru`. Для критичных данных — `noeviction` (но записи будут ошибкой). LRU проще, LFU точнее.

### 18. Как работать с Redis Streams и когда их использовать

**Redis Streams** — это append-only log (журнал), похожий на Kafka, но работающий в памяти.

**Когда использовать:**
1. **Лёгкое месседжирование** — когда Kafka избыточна, но нужна очередь сообщений.
2. **Consumer groups** — несколько потребителей читают один stream (каждый получает свою порцию сообщений).
3. **At-least-once delivery** — сообщение не теряется (можно перепутывать, но не терять).
4. **В памяти** — быстрее Kafka, но без персистентности (если Redis упадёт — данные потеряны).

**Пример:**
```java
// Producer:
Jedis jedis = new Jedis("localhost");
jedis.xadd("orders", StreamEntry.ID.NEW, "orderId", "order_12345", "amount", "100");

// Consumer group:
jedis.xgroupCreate("orders", "workers", StreamEntry.INF_ID, true);
List<Map<String, String>> messages = jedis.xread(
    XReadParams.xreadParams().group("orders", "worker-1").count(10),
    new String[]{"orders", ">"}
);
```

**Consumer groups:**
- `XGROUP CREATE stream group $` — создать группу.
- `XREADGROUP GROUP group consumer >` — прочитать сообщения.
- `XACK stream group consumer message_id` — подтвердить доставку.

**Вывод:** Redis Streams — это лёгкое месседжирование (не Kafka). Consumer groups позволяют N потребителям читать один stream. At-least-once delivery (сообщение не теряется). В памяти (быстрее Kafka, но без персистентности).

### 19. Как оптимизировать Redis pipeline и batching

**Pipeline** — это механизм, который группирует N команд в один round-trip (вместо N отдельных запросов).

**Пример:**
```java
// Без pipeline: N round-trips.
for (int i = 0; i < 1000; i++) {
    jedis.set("key" + i, "value" + i);  // 1000 round-trips
}

// С pipeline: 1 round-trip.
Pipeline p = jedis.pipelined();
for (int i = 0; i < 1000; i++) {
    p.set("key" + i, "value" + i);  // batch
}
p.sync();  // 1 round-trip
```

**Batching:**
- Партия из N команд → 1 запрос.
- Ответ: N результатов (но 1 round-trip).

**Когда использовать:**
- **Bulk load** — загрузка 1000+ ключей.
- **Fan-out** — N ключей → 1 запрос в БД.
- **Низкая задержка** — когда latency < 1 мс критична.

**Ограничения:**
- **Память:** pipeline буферизует команды в памяти.
- **Порядок:** команды выполняются в порядке FIFO (порядок сохранён).
- **Обработка ошибок:** если одна команда в batch упадёт — нужно обрабатывать ошибки или делать retry.

**Вывод:** Pipeline — это batch команд → 1 round-trip (вместо N). Используется для bulk load, fan-out, низкой задержки. Ограничения: память (буфер), порядок (FIFO), обработка ошибок (1 ошибка → retry).

### 20. Как настроить Redis в Kubernetes: StatefulSet, persistence

**K8s + Redis** — это StatefulSet (stateful-сервис) + PVC (persistent volume claim) + headless service (DNS).

**StatefulSet** обеспечивает:
- **Стабильный сетевой идентификатор** (например, `redis-0`, `redis-1`, `redis-2`).
- **Стабильное хранилище** (PVC на каждый под).
- **Порядковый деплой** (redis-0 → redis-1 → redis-2).

**Пример:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7
        command: ["redis-server", "--appendonly", "yes"]
        ports:
        - containerPort: 6379
        volumeMounts:
        - mountPath: /data
          name: data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**PVC (Persistent Volume Claim):**
- **Хранилище:** 10Gi (например, EBS в AWS).
- **Режим доступа:** ReadWriteOnce (1 под → 1 PVC).
- **Retain:** данные сохраняются после удаления пода.

**Service (headless):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  clusterIP: None  # Headless service
  selector:
    app: redis
  ports:
  - port: 6379
```

Headless service (`clusterIP: None`) создаёт DNS-записи для каждого пода: `redis-0.redis`, `redis-1.redis`, `redis-2.redis`.

**Sentinel (high availability):**
```yaml
# redis-sentinel (3 реплики):
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-sentinel
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: sentinel
        image: redis:7
        command: ["redis-sentinel", "/etc/redis/sentinel.conf"]
```

**Вывод:** K8s + Redis — это StatefulSet (стабильный идентификатор, хранилище) + PVC (персистентный том) + headless service (DNS). Sentinel обеспечивает high availability. Retain — данные сохраняются после удаления пода.

### 21. Паттерн двухуровневого кэширования (L1 Caffeine + L2 Redis)

В high-load системах поход в Redis (даже локальный) — это сетевой вызов (network hop), который добавляет задержку 1–5 мс. При огромном RPS это становится узким местом.

**Решение:** Комбинация локального in-memory кэша (L1) и распределённого (L2).
- **L1 (Caffeine):** хранит данные 5–10 секунд. Защищает от микро-всплесков и многократных запросов одного и того же объекта в рамках одного JVM.
- **L2 (Redis):** хранит данные 5–10 минут. Обеспечивает согласованность между разными инстансами приложения.

**Как работает:**
1. Запрос → проверяем Caffeine (Hit? → возвращаем).
2. Miss в Caffeine → проверяем Redis (Hit? → кладём в Caffeine, возвращаем).
3. Miss в Redis → идём в БД → кладём в Redis → кладём в Caffeine → возвращаем.

**Проблема инвалидации:** при обновлении данных нужно инвалидировать ключ и в Redis, и (через шину сообщений, например, Redis Pub/Sub или Kafka) во всех инстансах Caffeine, чтобы избежать рассинхрона. Библиотека **Caffeine + Redisson** или **JetCache** упрощают эту настройку в Spring.

