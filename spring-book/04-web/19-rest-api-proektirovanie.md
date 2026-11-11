# Глава 19. Проектирование REST API: контракт, идемпотентность, версионирование

> **Уровень:** junior → middle+
> **Время:** 3–4 часа
> **Цель:** проектировать API, которое не придётся ломать через полгода: предсказуемые ресурсы, честные статусы, безопасные повторы, продуманная эволюция.

## 19.1. Ресурсы и методы

```text
GET    /api/tasks              список (безопасный, идемпотентный, кэшируемый)
GET    /api/tasks/{id}         элемент
POST   /api/tasks              создать (НЕ идемпотентный → нужен Idempotency-Key)
PUT    /api/tasks/{id}         полная замена (идемпотентный)
PATCH  /api/tasks/{id}         частичное обновление (не обязательно идемпотентный)
DELETE /api/tasks/{id}         удалить (идемпотентный: повтор → 204/404)
GET    /api/tasks/{id}/comments  подресурс
POST   /api/tasks/{id}/actions/complete   действие, не CRUD (осознанное исключение)
```

Правила:
* Существительные во множественном числе, без глаголов (`/getTasks` — антипаттерн).
* Вложенность максимум 2 уровня; глубже — плоский ресурс с фильтром.
* Действие, которое не выражается CRUD, оформляйте как подресурс-действие (`/actions/cancel`) — это практичнее, чем «натягивать» PATCH.
* Никаких сессий/состояния в URI; версия — не «состояние», см. §19.5.

## 19.2. Статус-коды: рабочая таблица

| Код | Когда | Частая ошибка |
|---|---|---|
| 200 OK | успешный GET/PATCH/PUT с телом | возвращать 200 на создание |
| 201 Created | создано; **обязателен `Location`** | забыть Location |
| 202 Accepted | принято в обработку (async) | отдавать 200 и «делать долго» |
| 204 No Content | успех без тела (DELETE) | тело при 204 |
| 304 Not Modified | ETag/If-None-Match совпал | не поддерживать условные запросы |
| 400 Bad Request | невалидный синтаксис/параметры | использовать для бизнес-ошибок |
| 401 Unauthorized | нет/невалидна аутентификация | путать с 403 |
| 403 Forbidden | аутентифицирован, но нет прав | отдавать 404 «для скрытности» без причины |
| 404 Not Found | ресурса нет | 404 при ошибке валидации |
| 405 Method Not Allowed | метод не поддерживается | — |
| 406 / 415 | negotiation / неподдерживаемый Content-Type | — |
| 409 Conflict | конфликт состояния (дубликат, версия) | 500 на duplicate key |
| 412 Precondition Failed | `If-Match` не совпал | игнорировать условные заголовки |
| 422 Unprocessable Content | семантическая ошибка (бизнес-правило) | 400 на всё |
| 428 Precondition Required | требуется `If-Match` | — |
| 429 Too Many Requests | rate limit (+ `Retry-After`) | 500 при перегрузке |
| 500 | наша ошибка | отдавать наружу стектрейс |
| 503 | недоступны/деградация (+ `Retry-After`) | — |

🎯 Разница 400 vs 422: 400 — «не могу разобрать/параметры неверны», 422 — «понял, но бизнес-правило нарушено». Выберите одно правило и держитесь его во всём API; главное — консистентность.

## 19.3. Контракт списков: пагинация, фильтры, сортировка

```http
GET /api/tasks?status=NEW&q=отчёт&sort=createdAt,desc&page=0&size=20
```
```json
{
  "content": [ { "id": 1, "title": "Отчёт", "status": "NEW" } ],
  "page": { "number": 0, "size": 20, "totalElements": 137, "totalPages": 7 },
  "links": { "self": "/api/tasks?page=0", "next": "/api/tasks?page=1" }
}
```
или курсорная пагинация:
```json
{ "content": [...], "nextCursor": "eyJ0IjoiMjAyNi0xMS0wMVQxMDowMFoiLCJpZCI6MTIzfQ" }
```

Правила:
* **Не отдавайте `Page<T>` из Spring Data напрямую** — его JSON-структура нестабильна между версиями (в Boot 3.3+ есть `spring.data.web.pageable.serialization-mode=VIA_DTO`, но лучше свой envelope).
* Ограничивайте `size` (например, ≤ 100) и валидируйте `sort` по whitelist.
* Фильтры — плоские параметры; сложные — `POST /api/tasks/search` с телом (осознанный компромисс с кэшируемостью).
*Sparse fieldsets (`?fields=id,title`) — экономия трафика, но усложнение контракта; вводите только при реальной необходимости.

## 19.4. Идемпотентность: обязательна для платежей и создания

```http
POST /api/payments
Idempotency-Key: 8f14e45f-ea0f-4b1c-9c2a-1d2f3a4b5c6d
```

Реализация (надёжная, на БД):
```sql
CREATE TABLE idempotency_keys (
  key         VARCHAR(64) PRIMARY KEY,
  endpoint    VARCHAR(120) NOT NULL,
  request_hash VARCHAR(64) NOT NULL,
  status      VARCHAR(20) NOT NULL,       -- IN_PROGRESS | DONE
  response    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```
```java
@Transactional
public ResponseEntity<PaymentView> pay(String key, PayRequest req) {
    var hash = sha256(canonicalJson(req));
    try {
        idem.insert(key, endpoint, hash, IN_PROGRESS);     // unique PK → защита от гонок
    } catch (DuplicateKeyException e) {
        var existing = idem.find(key).orElseThrow();
        if (!existing.requestHash().equals(hash))
            throw new IdempotencyKeyReusedException();     // 422: тот же ключ, другое тело
        if (existing.status() == IN_PROGRESS)
            return ResponseEntity.status(409).header("Retry-After", "1").build();
        return ResponseEntity.ok(existing.responseAs(PaymentView.class));   // отдаём сохранённый ответ
    }
    var result = payments.charge(req);                     // бизнес-операция в той же tx
    idem.complete(key, result);
    return ResponseEntity.status(201).body(result);
}
```
Нюансы:
* Ключ генерирует **клиент** (UUID), сервер хранит результат минимум 24 ч.
* Тот же ключ + другое тело → ошибка (не «перезапись»).
* Параллельные запросы с тем же ключом: один работает, второй получает 409/`Retry-After`.
* Хранить **ответ**, а не только факт — иначе повтор вернёт другое тело.
* Альтернатива для «естественной» идемпотентности — уникальный индекс по бизнес-ключу (`external_id`).

## 19.5. Версионирование: стратегии и выбор

| Стратегия | Пример | Плюсы | Минусы |
|---|---|---|---|
| Путь | `/api/v1/tasks` | явно, просто, кэшируется | «ресурс меняет идентичность» |
| Заголовок | `X-API-Version: 2` | чистый URI | сложнее тестировать в браузере |
| Media type | `Accept: application/vnd.taskflow.v2+json` | «правильный» REST | громоздко |
| Query | `?version=2` | просто | легко потерять при проксировании |
| Без версии | эволюция аддитивная | минимум боли | требует дисциплины |

**[4.x]** используйте встроенную поддержку (`spring.mvc.apiversion.*`, `@GetMapping(version="1.1+")`, `ApiVersionDeprecationHandler` → заголовки `Deprecation`/`Sunset`). **[3.5]** — путь или свой `RequestCondition`.

🎯 **Правило эволюции:** ломающие изменения — только в новой версии; аддитивные (новое необязательное поле, новый эндпоинт) — без версии. Никогда не меняйте семантику существующего поля.

Что считается ломающим: удаление/переименование поля, сужение типа, новое обязательное поле в запросе, изменение значения по умолчанию, изменение кода ошибки, ужесточение валидации.

## 19.6. Конкурентность на уровне HTTP

```java
@PatchMapping("/{id}")
ResponseEntity<TaskView> patch(@PathVariable Long id,
                               @RequestHeader(value = "If-Match", required = false) String ifMatch,
                               @Valid @RequestBody PatchTaskRequest req) {
    var current = service.find(id);
    if (ifMatch == null) return ResponseEntity.status(428).build();          // требуем условие
    if (!ifMatch.equals("\"" + current.version() + "\"")) return ResponseEntity.status(412).build();
    var updated = service.patch(id, req);                                    // + @Version в БД
    return ResponseEntity.ok().eTag("\"" + updated.version() + "\"").body(updated);
}
```
Два уровня защиты: HTTP-условие (быстрый отказ) + `@Version` в БД (гарантия). Только ETag без `@Version` — недостаточно (гонка между чтением и записью).

## 19.7. Валидация: группы, кастомные правила, cross-field

```java
public record CreateTaskRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 4000) String description,
        @FutureOrPresent LocalDate dueDate,
        @NotNull Priority priority,
        @Email String notifyEmail
) {}

// Разные правила для create/patch
public interface OnCreate {} public interface OnPatch {}
@PostMapping void create(@Validated(OnCreate.class) @RequestBody Req r) {}
@PatchMapping void patch(@Validated(OnPatch.class) @RequestBody Req r) {}
```

Свой валидатор:
```java
@Target({TYPE}) @Retention(RUNTIME)
@Constraint(validatedBy = DateRangeValidator.class)
public @interface ValidDateRange {
    String message() default "dueDate не может быть раньше startDate";
    Class<?>[] groups() default {}; Class<? extends Payload>[] payload() default {};
}

class DateRangeValidator implements ConstraintValidator<ValidDateRange, CreateTaskRequest> {
    @Override public boolean isValid(CreateTaskRequest r, ConstraintValidatorContext ctx) {
        return r.startDate() == null || r.dueDate() == null || !r.dueDate().isBefore(r.startDate());
    }
}
```
🪤 Валидация — **не** бизнес-логика. «Нельзя закрыть задачу без исполнителя» — это доменное правило (409/422 из сервиса), а не аннотация на DTO. Держите границу.

## 19.8. Долгие операции, bulk, rate limiting

**Долгая операция:**
```http
POST /api/reports → 202 Accepted, Location: /api/reports/jobs/123
GET  /api/reports/jobs/123 → 200 {"status":"RUNNING","progress":42}
GET  /api/reports/jobs/123 → 303 See Other, Location: /api/reports/456   (готово)
```

**Bulk:** `POST /api/tasks/batch` с массивом и **явным** контрактом частичного успеха:
```json
{ "results": [ {"index":0,"status":201,"id":1}, {"index":1,"status":422,"error":{"code":"INVALID_DATE"}} ] }
```
Плюс лимит размера батча (например, 100) и 413 при превышении.

**Rate limiting:** на уровне gateway (лучше) или в приложении (Bucket4j / `@ConcurrencyLimit` **[4.x]**). Обязательно `429` + `Retry-After`, метрика отказов, отдельный лимит на «дорогие» эндпоинты.

## 19.9. Документация и contract-first

* **springdoc-openapi** (`springdoc-openapi-starter-webmvc-ui`) генерирует OpenAPI 3 и Swagger UI из кода. Версию выбирайте по матрице совместимости с вашей линейкой Boot.
```java
@Operation(summary = "Создать задачу")
@ApiResponse(responseCode = "201", description = "Создано")
@ApiResponse(responseCode = "409", description = "Дубликат slug")
@PostMapping TaskView create(@RequestBody CreateTaskRequest req) { ... }
```
* **Spring REST Docs** — документация **из тестов** (не врёт, потому что тесты падают при изменении контракта). **[4.x]** стартер `spring-boot-starter-restdocs` (с 4.0.4).
* **Contract-first** (OpenAPI-файл → генерация интерфейсов) — лучший вариант для публичных API и межкомандного взаимодействия.
* **Consumer-driven contracts** (Spring Cloud Contract/Pact) — когда есть потребители, которых нельзя сломать.

🎯 На middle+ спрашивают: «как вы гарантируете, что документация соответствует коду?» Правильный ответ: генерация из тестов/схемы + CI-проверка совместимости (openapi-diff), а не «мы обновляем вики».

## 19.10. Безопасность контракта

* **Mass assignment / over-posting**: никогда не биндите запрос в сущность. Отдельные DTO для create/patch, где нет `id`, `ownerId`, `role`, `version`.
* **BOLA/IDOR**: проверяйте владение ресурсом на уровне сервиса (`task.owner == currentUser`), а не только «есть роль USER».
* Лимиты: размер тела, глубина JSON, число элементов массива, `size` пагинации.
* Никаких внутренних деталей в ошибках; `traceId` вместо стектрейса.
* Логируйте факты доступа к чувствительным ресурсам (аудит).

## 19.11. Чек-лист ревью API

- [ ] Ресурсы — существительные, методы по семантике, статусы по таблице.
- [ ] `201` + `Location`; `204` без тела; ошибки в `ProblemDetail`.
- [ ] Пагинация с лимитом, сортировка по whitelist, свой envelope.
- [ ] POST-создание защищено `Idempotency-Key` или бизнес-ключом.
- [ ] Конкурентные обновления: `If-Match` + `@Version`.
- [ ] DTO ≠ сущность; нет over-posting; проверка владения.
- [ ] Ломающие изменения — только через версию; есть deprecation-политика.
- [ ] OpenAPI актуален и проверяется в CI.

## 19.12. 🧪 Практика

1. Спроектируйте API задач на бумаге (10 эндпоинтов) и пройдите по чек-листу.
2. Реализуйте `Idempotency-Key` с таблицей и тестом на параллельные запросы.
3. Добавьте `If-Match`/`ETag` и тест на 412.
4. Сделайте долгую операцию с 202 + статус-эндпоинтом.
5. Подключите OpenAPI и найдите в нём случайно «утёкшую» сущность — исправьте на DTO.

## 19.13. Вопросы

1) Какие методы идемпотентны и почему PATCH — не обязательно? 2) Чем 401 отличается от 403? 3) 400 vs 422 — ваше правило? 4) Как реализовать идемпотентность POST? 5) Зачем `If-Match`, если есть `@Version`? 6) Что считается ломающим изменением? 7) Почему нельзя отдавать `Page<T>` напрямую? 8) Что такое over-posting и как защититься?

---

**Назад:** [Глава 18](18-web-mvc-vnutri.md) · **Дальше:** [Глава 20. HTTP-клиенты →](20-http-klienty.md)