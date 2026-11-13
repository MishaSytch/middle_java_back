# Глава 17. Кэширование: абстракция Spring, Caffeine, Redis и грабли консистентности

> **Уровень:** junior → middle+
> **Время:** 3 часа
> **Цель:** уметь включать кэш там, где он даёт выигрыш, и не создавать «загадочные баги с устаревшими данными».

## 17.1. Когда кэш нужен, а когда вреден

Кэш помогает, если: (а) чтение дороже записи, (б) данные терпят устаревание, (в) есть повторяемость запросов (высокий hit ratio).

Кэш **вреден**, если: данные персональные и ключ не учитывает пользователя; нужна строгая консистентность (баланс, остатки); hit ratio < 20 % (вы платите памятью и сложностью за ничего); вы кэшируете JPA-сущности (detached-объекты, ленивые связи, «протечки» изменений).

Уровни кэша в реальном приложении:
```text
Браузер (Cache-Control, ETag) → CDN → API-gateway → локальный (Caffeine) → распределённый (Redis) → БД (shared buffers)
```
Правило: **начинайте с самого дешёвого уровня**. Часто `Cache-Control: max-age=60` на справочнике даёт больше, чем Redis-кластер.

## 17.2. Абстракция Spring Cache

```java
@Configuration @EnableCaching class CacheConfig {}

@Service
public class TaskQueryService {

    @Cacheable(cacheNames = "tasks", key = "#id", unless = "#result == null")
    public TaskView findById(Long id) { return repo.findView(id); }

    @CachePut(cacheNames = "tasks", key = "#result.id()")
    public TaskView update(Long id, UpdateTaskRequest req) { ... }

    @CacheEvict(cacheNames = "tasks", key = "#id")
    public void delete(Long id) { ... }

    @Caching(evict = {
        @CacheEvict(cacheNames = "tasks", key = "#id"),
        @CacheEvict(cacheNames = "taskLists", allEntries = true)
    })
    public void archive(Long id) { ... }

    @Cacheable(cacheNames = "stats", key = "#root.methodName + ':' + #owner", sync = true)
    public Stats stats(String owner) { /* дорогой расчёт */ }
}
```

| Атрибут | Смысл |
|---|---|
| `key` | SpEL-ключ (`#id`, `#req.slug()`, `#root.methodName`, `#p0`) |
| `keyGenerator` | свой генератор ключей |
| `condition` | кэшировать только если условие истинно (до вызова) |
| `unless` | не класть результат, если условие истинно (после вызова) |
| `sync = true` | только один поток считает значение (защита от stampede) |
| `beforeInvocation` (у `@CacheEvict`) | удалить до вызова (даже если метод упадёт) |
| `allEntries` | очистить весь кэш |

⚙️ **Под капотом:** `CacheInterceptor` (AOP!) → `CacheResolver` → `Cache` → `CacheManager`. Отсюда все ограничения прокси: self-invocation не кэширует, `private` не кэширует, `@PostConstruct` не кэширует.

🪤 **`@Cacheable` + `@Transactional`:** порядок интерсепторов определяет, попадёт ли в кэш результат «до коммита». По умолчанию кэш-интерсептор имеет `LOWEST_PRECEDENCE`, как и транзакционный — порядок неочевиден. Хотите гарантию «кэшируем только закоммиченное» — кэшируйте **отдельный бин**, вызываемый после транзакции, или задайте `@EnableCaching(order = ...)`.

## 17.3. Провайдеры

### Caffeine — локальный кэш (лучший выбор по умолчанию)

```xml
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-cache</artifactId></dependency>
<dependency><groupId>com.github.ben-manes.caffeine</groupId><artifactId>caffeine</artifactId></dependency>
```
```yaml
spring:
  cache:
    type: caffeine
    cache-names: tasks, users, dicts
    caffeine:
      spec: maximumSize=10000,expireAfterWrite=10m,recordStats
```

Разные политики для разных кэшей:
```java
@Bean
CaffeineCacheManager cacheManager() {
    var manager = new CaffeineCacheManager();
    manager.setCaffeine(Caffeine.newBuilder().maximumSize(10_000).expireAfterWrite(Duration.ofMinutes(10)).recordStats());
    manager.registerCustomCache("dicts",
        Caffeine.newBuilder().maximumSize(500).expireAfterWrite(Duration.ofHours(6)).recordStats().build());
    manager.registerCustomCache("shortLived",
        Caffeine.newBuilder().maximumSize(1_000).expireAfterWrite(Duration.ofSeconds(15)).recordStats().build());
    return manager;
}
```

| Политика | Когда |
|---|---|
| `expireAfterWrite` | данные устаревают по времени (справочники) |
| `expireAfterAccess` | «горячие» данные держать, холодные вытеснять |
| `refreshAfterWrite` | асинхронное обновление «на фоне» (нужен `CacheLoader`) |
| `maximumSize` / `maximumWeight` | ограничение памяти (обязательно!) |
| `weakKeys`/`softValues` | почти никогда: непредсказуемое поведение под GC |

### Redis — распределённый кэш

```xml
<dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-redis</artifactId></dependency>
```
```yaml
spring:
  cache:
    type: redis
    redis:
      time-to-live: 10m
      cache-null-values: false        # кэшировать «отсутствие» — отдельное решение
      key-prefix: "taskflow:"
      use-key-prefix: true
  data:
    redis:
      host: redis
      port: 6379
      timeout: 2s
      lettuce.pool: { max-active: 16, max-idle: 8, min-idle: 2 }
```

Тонкая настройка (сериализация, TTL per cache):
```java
@Bean
RedisCacheConfiguration cacheConfiguration(JsonMapper mapper) {          // [4.x] JsonMapper; [3.5] ObjectMapper
    return RedisCacheConfiguration.defaultCacheConfig()
        .entryTtl(Duration.ofMinutes(10))
        .disableCachingNullValues()
        .prefixCacheNameWith("taskflow:")
        .serializeKeysWith(RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
        .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(
                new GenericJacksonJsonRedisSerializer(mapper)));         // [4.x]; в 3.5 GenericJackson2JsonRedisSerializer
}

@Bean
RedisCacheManagerBuilderCustomizer ttlPerCache() {
    return builder -> builder
        .withCacheConfiguration("dicts", RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofHours(6)))
        .withCacheConfiguration("sessions", RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofMinutes(30)));
}
```

🪤 **Сериализация — главный источник боли в Redis-кэше:**
* JDK-сериализация (дефолт) — компактно, но нечитаемо, ломается при изменении класса, требует `Serializable`. Не используйте.
* JSON — читаемо, но нужен полиморфный тип (`@class`), иначе `LinkedHashMap` вместо вашего объекта.
* **[4.x]** Jackson 3: используйте Jackson-3-совместимый сериализатор; старый `GenericJackson2JsonRedisSerializer` относится к Jackson 2.
* Держите кэшируемые DTO **простыми record-ами** — это решает 90 % проблем.

## 17.4. Паттерны и грабли консистентности

| Паттерн | Как |Trade-off |
|---|---|---|
| Cache-aside | приложение читает кэш, при промахе — БД и кладёт | просто; возможен race |
| Read-through | кэш сам грузит из БД (`CacheLoader`) | чище код; нужен провайдер |
| Write-through | пишем в кэш и БД синхронно | консистентно; медленнее запись |
| Write-behind | пишем в кэш, БД асинхронно | быстро; риск потери |
| Refresh-ahead | обновляем до истечения TTL | нет пиков latency; сложнее |

### Cache stampede (thundering herd)
TTL истёк → 500 параллельных запросов идут в БД за одним значением. Решения:
1. `@Cacheable(sync = true)` — локально только один поток считает (в Caffeine работает; в Redis — **не** распределённая блокировка!).
2. Распределённая блокировка (Redis SETNX) на пересчёт.
3. Probabilistic early expiration / `refreshAfterWrite`.
4. Никогда не ставьте одинаковый TTL всем ключам — добавляйте jitter.

### Инвалидация
* **TTL** — самый надёжный «самоочистка»-механизм. Начинайте с него.
* **Явная инвалидация** (`@CacheEvict`) — точечно, но легко забыть одно место.
* **Версионирование ключей**: `tasks:v2:{id}` — «инвалидировать всё» сменой версии (deploy-safe).
* **Событийная инвалидация**: доменное событие → сброс кэша во всех инстансах (Redis pub/sub, Kafka).

🎯 Классический вопрос: «как инвалидировать локальный кэш на 10 подах?» — либо короткий TTL, либо broadcast-инвалидация, либо распределённый кэш вместо локального. Ответ «никак, у нас Caffeine» означает, что вы приняли eventual consistency — это надо сказать явно.

### Что нельзя кэшировать
* JPA-сущности (detached, ленивые прокси, риск случайно изменить и записать).
* Данные без учёта пользователя/тенанта в ключе (`key = "#id"` для персональных данных = утечка чужих данных!).
* Результат внутри незакоммиченной транзакции.
* `null` без осознанного решения (кэш «отсутствия» защищает от penetration-атак, но ломает «создали → сразу читаем»).

```java
// ✅ ключ учитывает тенанта и пользователя
@Cacheable(cacheNames = "tasks", key = "T(dev.book.TenantContext).tenant() + ':' + #id")
```

## 17.5. HTTP-кэш: дешевле и эффективнее

```java
@GetMapping("/api/dicts/{name}")
ResponseEntity<Dict> dict(@PathVariable String name) {
    Dict d = service.dict(name);
    return ResponseEntity.ok()
            .cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePublic())
            .eTag("\"" + d.version() + "\"")
            .body(d);
}

@GetMapping("/api/tasks/{id}")
ResponseEntity<TaskView> task(@PathVariable Long id, WebRequest request) {
    var view = service.find(id);
    if (request.checkNotModified("\"" + view.version() + "\"")) return null;   // 304 без тела
    return ResponseEntity.ok().eTag("\"" + view.version() + "\"").body(view);
}
```
`ETag` + `If-None-Match` → 304 Not Modified, экономия трафика и сериализации. Для списков — `Last-Modified`. Это часто даёт больший эффект, чем серверный кэш.

## 17.6. Наблюдаемость и тестирование

```yaml
management.endpoints.web.exposure.include: health,metrics,caches
```
```bash
curl localhost:8080/actuator/caches
curl -X DELETE localhost:8080/actuator/caches/dicts     # сбросить кэш в рантайме
curl localhost:8080/actuator/metrics/cache.gets?tag=result:hit
```
Метрики Caffeine/Redis: `cache.gets{result=hit|miss}`, `cache.puts`, `cache.evictions`, `cache.size`. **Алерт: hit ratio < 50 %** на «горячем» кэше — кэш не работает.

Тест:
```java
@SpringBootTest
class CachingTest {
    @Autowired TaskQueryService service;
    @MockitoBean TaskRepository repo;              // [4.x]; [3.5] @MockBean

    @Test void secondCallHitsCache() {
        service.findById(1L); service.findById(1L);
        verify(repo, times(1)).findView(1L);
    }
}
```
🎯 Обязательно проверяйте **и** инвалидацию: после `update` повторное чтение должно вернуть новое значение. Это самый частый пропущенный тест.

## 17.7. 🪤 Топ-10 граблей кэша

1. Ключ без пользователя/тенанта → утечка данных.
2. Кэш JPA-сущностей.
3. Self-invocation → кэш не работает.
4. Одинаковый TTL у всех ключей → синхронный stampede.
5. `sync=true` как «распределённая блокировка» в Redis — это не она.
6. JDK-сериализация в Redis.
7. Забыли `@CacheEvict` в одном из методов записи.
8. Нет `maximumSize` → OOM.
9. Кэш внутри незакоммиченной транзакции.
10. Нет метрик hit ratio → никто не знает, что кэш бесполезен.

## 17.8. 🧪 Практика

1. Включите Caffeine с `recordStats`, сделайте `@Cacheable`-метод, посмотрите hit ratio в actuator.
2. Добавьте `@CachePut`/`@CacheEvict` и напишите тест на инвалидацию.
3. Воспроизведите stampede: TTL 1s, 100 параллельных запросов, `sync=false` vs `true`.
4. Переведите кэш на Redis (Testcontainers), сравните latency и объясните разницу.
5. Сделайте ETag для списочного эндпоинта и проверьте 304 через curl.

## 17.9. Вопросы

1) Почему `@Cacheable` не работает при внутреннем вызове? 2) Что делает `unless`? 3) Чем `expireAfterWrite` отличается от `expireAfterAccess`? 4) Как инвалидировать локальный кэш на N инстансах? 5) Почему нельзя кэшировать сущности? 6) Что такое cache stampede и три способа защиты? 7) Чем `ETag` лучше серверного кэша?

---

**Назад:** [Глава 16](16-migracii-flyway-liquibase.md) · **Дальше:** [Глава 18. Spring MVC изнутри →](../04-web/18-web-mvc-vnutri.md)