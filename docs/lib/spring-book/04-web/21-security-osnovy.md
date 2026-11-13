# Глава 21. Spring Security: архитектура, фильтры, аутентификация и авторизация

> **Уровень:** junior → middle+ (ключевая глава книги)
> **Время:** 5 часов
> **Цель:** понимать цепочку фильтров, уметь настраивать доступ осознанно и объяснять, почему «403 вместо 401» и «CSRF token not found».

## 21.1. Базовые понятия

* **Аутентификация** — кто ты (`Authentication`, `Principal`).
* **Авторизация** — что тебе можно (`GrantedAuthority`, роли/права).
* `Authentication` содержит: principal (обычно `UserDetails`), credentials (пароль/токен), authorities, `isAuthenticated()`.
* **Роль** — это authority с префиксом `ROLE_`. `hasRole("ADMIN")` ищет `ROLE_ADMIN`, `hasAuthority("ROLE_ADMIN")` — то же самое. 🪤 `hasAuthority("ADMIN")` **не** найдёт `ROLE_ADMIN`.

## 21.2. ⚙️ Архитектура: путь запроса

```text
Servlet container
 └─ DelegatingFilterProxy (springSecurityFilterChain)
     └─ FilterChainProxy  → выбирает SecurityFilterChain по RequestMatcher
         └─ фильтры по порядку:
             DisableEncodeUrlFilter
             ForceEagerSessionCreationFilter
             ChannelProcessingFilter
             WebAsyncManagerIntegrationFilter
             SecurityContextHolderFilter          ← загружает SecurityContext из репозитория (сессия)
             HeaderWriterFilter                   ← security-заголовки
             CorsFilter
             CsrfFilter                           ← проверка CSRF-токена
             LogoutFilter
             UsernamePasswordAuthenticationFilter ← form login
             BasicAuthenticationFilter            ← HTTP Basic
             BearerTokenAuthenticationFilter      ← JWT/OAuth2 resource server
             RequestCacheAwareFilter
             SecurityContextHolderAwareRequestFilter
             AnonymousAuthenticationFilter        ← «аноним», если никто не аутентифицировал
             SessionManagementFilter              ← фиксация сессии, concurrent sessions
             ExceptionTranslationFilter           ← ловит AuthnException/AccessDenied → entryPoint/deniedHandler
             AuthorizationFilter                  ← ★ собственно проверка доступа (authorizeHttpRequests)
         └─ далее DispatcherServlet → контроллер
```

**Три ключевых вывода:**
1. **Security работает до MVC.** Поэтому `@RestControllerAdvice` **не поймает** `AccessDeniedException`, брошенный `AuthorizationFilter` — ответ формируется раньше. Обработчики — `AuthenticationEntryPoint` (401) и `AccessDeniedHandler` (403).
2. `SecurityContextHolder` — по умолчанию `ThreadLocal`. В `@Async`/виртуальных потоках контекст нужно переносить явно (`DelegatingSecurityContextAsyncTaskExecutor`, `TaskDecorator`).
3. `ExceptionTranslationFilter` **выше** `AuthorizationFilter` — он и превращает исключения в HTTP-ответы.

## 21.3. Что Boot включает по умолчанию

Добавили `spring-boot-starter-security` → получили:
* все запросы требуют аутентификации;
* form login + HTTP Basic;
* сгенерированный пароль в логах (`Using generated security password: ...`) и пользователя `user`;
* CSRF-защиту включённой;
* security-заголовки (X-Content-Type-Options, X-Frame-Options, HSTS и др.);
* сессионное хранение контекста.

🪤 Это отлично для старта и **непригодно** для API. Первое, что делает зрелая команда — явная конфигурация.

## 21.4. Современная конфигурация (Security 7 **[4.x]** / 6.5 **[3.5]**)

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity            // включает @PreAuthorize/@PostAuthorize
class SecurityConfig {

    @Bean
    SecurityFilterChain api(HttpSecurity http, ObjectMapper problemMapper) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(csrf -> csrf.disable())                       // stateless API + Bearer → CSRF не нужен
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.GET, "/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.DELETE, "/api/tasks/**").hasAuthority("task:delete")
                .anyRequest().authenticated())
            .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))
            .exceptionHandling(e -> e
                .authenticationEntryPoint((req, res, ex) -> writeProblem(res, 401, "Не аутентифицирован"))
                .accessDeniedHandler((req, res, ex) -> writeProblem(res, 403, "Недостаточно прав")))
            .headers(h -> h
                .frameOptions(f -> f.deny())
                .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'")));
        return http.build();
    }

    @Bean
    SecurityFilterChain actuator(HttpSecurity http) throws Exception {
        http.securityMatcher("/actuator/**")
            .authorizeHttpRequests(a -> a
                .requestMatchers("/actuator/health/**", "/actuator/info").permitAll()
                .anyRequest().hasRole("OPS"))
            .httpBasic(Customizer.withDefaults());
        return http.build();
    }

    @Bean PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();   // {bcrypt}..., {argon2}...
    }
}
```

Важные детали:
* **Lambda DSL обязателен**: `.and()` и «плоские» вызовы удалены. Только `Customizer`.
* **`authorizeHttpRequests`** (на базе `AuthorizationManager`) — современный API; `authorizeRequests` удалён.
* **Порядок правил важен**: от частного к общему, `anyRequest()` — последним.
* Несколько `SecurityFilterChain` различаются `securityMatcher`; порядок — `@Order`. Первая подходящая цепочка выигрывает.
* **[Security 7]** матчинг путей по умолчанию — `PathPatternRequestMatcher` (выровнен с MVC `PathPattern`). `AntPathRequestMatcher`/`MvcRequestMatcher` — legacy; при миграции проверьте правила с `**` и trailing slash (в 7 trailing-slash matching удалён).
* **[Security 7]** Spring Authorization Server входит в состав Security (отдельный проект больше не нужен).

## 21.5. Аутентификация: `UserDetailsService`, `PasswordEncoder`, `AuthenticationManager`

```java
@Service
@RequiredArgsConstructor
class DbUserDetailsService implements UserDetailsService {
    private final UserRepository users;

    @Override public UserDetails loadUserByUsername(String email) {
        var u = users.findByEmail(email).orElseThrow(() -> new UsernameNotFoundException(email));
        return User.withUsername(u.email())
                   .password(u.passwordHash())               // уже с префиксом {bcrypt}
                   .authorities(u.authorities().toArray(String[]::new))
                   .accountLocked(u.locked())
                   .disabled(!u.active())
                   .build();
    }
}
```

⚙️ Как проходит form/Basic-аутентификация:
```text
UsernamePasswordAuthenticationFilter → AuthenticationManager (ProviderManager)
  → DaoAuthenticationProvider
      → UserDetailsService.loadUserByUsername
      → PasswordEncoder.matches(raw, encoded)
      → pre/post AuthenticationChecks (locked/disabled/expired)
  → успешный Authentication → SecurityContextHolder + SecurityContextRepository (сессия)
```

**Пароли:**
```java
PasswordEncoder enc = PasswordEncoderFactories.createDelegatingPasswordEncoder();
String hash = enc.encode("s3cret");     // {bcrypt}$2a$10$...
```
* BCrypt (strength 10–12) — дефолт; Argon2id — современнее и лучше против GPU; PBKDF2 — для FIPS.
* `DelegatingPasswordEncoder` хранит префикс алгоритма → можно **плавно мигрировать** алгоритм без сброса паролей.
* Никогда: MD5/SHA-1/«свой» хэш, соль отдельно «в коде», пароль в логах.
* 🪤 BCrypt обрезает вход после 72 байт — длинные пароли надо предварительно хэшировать (или использовать Argon2).

Кастомный `AuthenticationProvider` (например, вход по одноразовому коду):
```java
@Component
class OtpAuthenticationProvider implements AuthenticationProvider {
    @Override public Authentication authenticate(Authentication auth) {
        // проверка кода → new UsernamePasswordAuthenticationToken(user, null, authorities)
    }
    @Override public boolean supports(Class<?> type) { return OtpToken.class.isAssignableFrom(type); }
}
```

## 21.6. Сессии, CSRF, CORS, заголовки

**Сессии:**
```java
http.sessionManagement(s -> s
    .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
    .sessionFixation(f -> f.migrateSession())        // защита от session fixation
    .maximumSessions(3).maxSessionsPreventsLogin(false));
```
Для распределённых сессий — Spring Session (JDBC/Redis): **[4.x]** стартеры `spring-boot-starter-session-jdbc` / `-session-data-redis`, свойства переехали в `spring.session.data.redis.*`.

**CSRF:** нужен, когда браузер автоматически отправляет credentials (cookie-сессия). Не нужен для stateless API с `Authorization: Bearer` (браузер не добавляет его сам).
```java
// SPA + cookie-сессия: токен в cookie, читаемой JS
http.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    .csrfTokenRequestHandler(new SpaCsrfTokenRequestHandler()));   // BREACH-защита, Security 6+
```
🪤 Классика: SPA получает 403 на POST — забыли передать `X-XSRF-TOKEN`. В Security 6+ токен ещё и «отложенный» (`DeferredCsrfToken`), поэтому важно, чтобы фронт делал GET перед первым POST или использовал `SpaCsrfTokenRequestHandler`.

**CORS:** при включённом Security настраивайте `http.cors(...)` с `CorsConfigurationSource` — иначе preflight отбивается до MVC.

**Заголовки:** HSTS (только под HTTPS!), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`/CSP `frame-ancestors`, `Referrer-Policy`, `Cache-Control: no-store` для чувствительных ответов.

## 21.7. Авторизация: URL vs метод

| Уровень | Инструмент | Плюс | Минус |
|---|---|---|---|
| URL | `authorizeHttpRequests` | централизованно, видно всё | не знает про id ресурса |
| Метод | `@PreAuthorize` | доступ к аргументам, доменные правила | размазано по коду |
| Домен | проверка в сервисе | точные бизнес-правила | нужно не забывать |

```java
@PreAuthorize("hasRole('ADMIN') or #ownerId == authentication.name")
public void delete(String ownerId, Long id) { ... }

@PostAuthorize("returnObject.owner == authentication.name")
public TaskView find(Long id) { ... }

@PreFilter("filterObject.owner == authentication.name")
public void process(List<Task> tasks) { ... }
```

Своя аннотация-правило (лучше строк):
```java
@Target(METHOD) @Retention(RUNTIME)
@PreAuthorize("hasAuthority('task:write') and @taskSecurity.isOwner(#id, authentication)")
public @interface CanWriteTask {}
```
```java
@Component("taskSecurity")
@RequiredArgsConstructor
class TaskSecurity {
    private final TaskRepository repo;
    public boolean isOwner(Long id, Authentication a) {
        return repo.findById(id).map(t -> t.owner().email().equals(a.getName())).orElse(false);
    }
}
```

Кастомный `AuthorizationManager` **[Security 6+/7]**:
```java
@Component
class TenantAuthorizationManager implements AuthorizationManager<RequestAuthorizationContext> {
    @Override public AuthorizationDecision check(Supplier<Authentication> auth, RequestAuthorizationContext ctx) {
        var tenant = ctx.getRequest().getHeader("X-Tenant");
        var ok = auth.get() != null && auth.get().getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("TENANT_" + tenant));
        return new AuthorizationDecision(ok);
    }
}
// .requestMatchers("/api/**").access(tenantAuthorizationManager)
```

🎯 **BOLA/IDOR — самая частая реальная уязвимость API.** `hasRole("USER")` не защищает от чтения чужой задачи. Проверка владения обязательна и должна быть в одном месте (сервис или `@PreAuthorize`), покрыта тестами.

## 21.8. Тестирование безопасности

**[4.x]** нужен `spring-boot-starter-security-test`; **[3.5]** — `org.springframework.security:spring-security-test`.

```java
@SpringBootTest @AutoConfigureMockMvc
class TaskSecurityTest {
    @Autowired MockMvc mvc;

    @Test void anonymousGets401() throws Exception {
        mvc.perform(get("/api/tasks/1")).andExpect(status().isUnauthorized());
    }

    @Test @WithMockUser(username = "ann", roles = "USER")
    void userCanRead() throws Exception {
        mvc.perform(get("/api/tasks/1")).andExpect(status().isOk());
    }

    @Test @WithMockUser(roles = "USER")
    void userCannotDelete() throws Exception {
        mvc.perform(delete("/api/tasks/1").with(csrf())).andExpect(status().isForbidden());
    }

    @Test @WithUserDetails("admin@corp.local")
    void adminCanDelete() throws Exception { ... }
}
```
🪤 `@WithMockUser` **не** проходит через вашу `UserDetailsService` — он создаёт синтетический `Authentication`. Если ваша логика зависит от кастомного principal (`CurrentUser`), используйте `@WithUserDetails` или `@WithSecurityContext(factory = ...)`.

Обязательный набор тестов: аноним → 401, аутентифицирован без прав → 403, с правами → 200, чужой ресурс → 403/404, CSRF (если включён) → 403 без токена.

## 21.9. 🪤 Топ-12 граблей Security

1. `hasAuthority("ADMIN")` вместо `hasRole("ADMIN")`.
2. Порядок `requestMatchers`: общий раньше частного.
3. Ожидание, что `@RestControllerAdvice` обработает 403 из фильтра.
4. CSRF включён для stateless API → 403 на всех POST.
5. CSRF выключен для cookie-сессии → уязвимость.
6. CORS настроен только в MVC.
7. `permitAll()` на `/actuator/**` → утечка env/beans.
8. SecurityContext «теряется» в `@Async`.
9. `@PreAuthorize` на `private`/self-invocation → не работает (это AOP!).
10. Пароль без префикса `{bcrypt}` при delegating encoder → «There is no PasswordEncoder mapped for the id null».
11. Нет проверки владения ресурсом (BOLA).
12. `@WithMockUser` при кастомном principal → NPE в бизнес-коде.

## 21.10. 🧪 Практика

1. Настройте две цепочки (`/api/**` stateless и `/actuator/**` basic) и проверьте порядок.
2. Реализуйте `UserDetailsService` + BCrypt, сделайте логин и проверьте сессию.
3. Добавьте `@PreAuthorize` с проверкой владения и тесты на чужой ресурс.
4. Воспроизведите 403 при включённом CSRF и почините двумя способами (stateless / SPA-handler).
5. Сделайте кастомный `AuthorizationManager` для тенанта.
6. Напишите полный набор security-тестов из §21.8.

## 21.11. Вопросы (middle+)

1) Нарисуйте цепочку фильтров и скажите, где проверяется доступ. 2) Почему 403 не попадает в `@ControllerAdvice`? 3) `AuthenticationManager` vs `AuthenticationProvider`? 4) Зачем `DelegatingPasswordEncoder`? 5) Когда CSRF нужен, а когда нет? 6) Чем `authorizeHttpRequests` отличается от старого `authorizeRequests`? 7) Как перенести SecurityContext в другой поток? 8) Что такое BOLA и как защититься? 9) Что изменилось в матчинге путей в Security 7?

---

**Назад:** [Глава 20](20-http-klienty.md) · **Дальше:** [Глава 22. JWT, OAuth2 и OIDC →](22-security-jwt-oauth2.md)