# Spring Security


### 1. Что такое Spring Security и какова его архитектура

**Spring Security** — фреймворк аутентификации и авторизации для Spring-приложений, построенный поверх **цепочки сервлетных фильтров**. Ключевая идея: перед тем как запрос дойдёт до вашего контроллера, он проходит через упорядоченный набор фильтров (`SecurityFilterChain`), каждый из которых решает свою задачу.

Основные фильтры (в порядке работы):
1. **SecurityContextHolderFilter** (Spring Security 6; ранее `SecurityContextPersistenceFilter`) — загрузка контекста безопасности (кто я?) из сессии/токена;
2. **CorsFilter** — обработка CORS;
3. **CsrfFilter** — проверка CSRF-токена;
4. **UsernamePasswordAuthenticationFilter** — обработка формы логина (или кастомный фильтр для JWT);
5. **ExceptionTranslationFilter** — превращение исключений безопасности в 401/403;
6. **AuthorizationFilter** (Spring Security 6; ранее `FilterSecurityInterceptor`, deprecated) — финальная проверка прав доступа через `AuthorizationManager`.

> **Spring Security 6:** `FilterSecurityInterceptor` и `AccessDecisionManager` устарели (deprecated) и заменены на `AuthorizationFilter` + `AuthorizationManager`. Аналогично, `SecurityContextPersistenceFilter` (делал лишние вызовы к репозиторию сессий) заменён на `SecurityContextHolderFilter`, который просто читает контекст и не сохраняет его в `HttpSession` — идеально для stateless (JWT).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant R as HTTP Request
    participant F1 as SecurityContextHolderFilter
    participant F2 as CorsFilter
    participant F3 as CsrfFilter
    participant F4 as Auth Filter (JWT)
    participant F5 as ExceptionTranslationFilter
    participant F6 as AuthorizationFilter
    participant C as Controller

    rect rgb(245,248,255)
    Note over R,C: 1. Context + CORS + CSRF
    R->>F1: request arrives
    F1->>F2: chain.doFilter
    F2->>F3: chain.doFilter
    end

    rect rgb(255,252,240)
    Note over F4,C: 2. Authentication
    F3->>F4: chain.doFilter
    F4->>F4: extract Bearer token, validate
    F4->>F5: SecurityContext set
    end

    rect rgb(245,255,245)
    Note over F5,C: 3. Authorization + handler
    F5->>F6: chain.doFilter
    F6->>C: AuthorizationManager check → dispatch
    end
```

```java
@Bean
SecurityFilterChain chain(HttpSecurity http) throws Exception {
    http
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/public/**").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated())
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
}
```

Важно понимать: Spring Security по умолчанию «всё запрещает, кроме настроенного» — новый проект без конфигурации потребует логин от каждой страницы, а сгенерированный пароль печатается в лог старта приложения.

### 2. В чём разница между аутентификацией и авторизацией

- **Аутентификация (Authentication)** — проверка того, **кто** вы: «докажите, что вы — Anna». Механизмы: логин/пароль, JWT-токен, OAuth2, сертификаты, биометрия. Результат — объект `Authentication` с `principal` (кто), `credentials` (чем доказал), `authorities` (что разрешено).
- **Авторизация (Authorization)** — проверка того, **что вам можно**: «этот endpoint доступен роли ADMIN». Работает с уже аутентифицированным пользователем и его `GrantedAuthority`.

Классическая метафора: паспорт на границе — аутентификация; пропуск в конкретное здание — авторизация. В коде: `AuthenticationManager` отвечает за аутентификацию, а `AuthorizationManager`/`@PreAuthorize` — за авторизацию. Ошибки различаются статусами: не аутентифицирован — **401 Unauthorized**, аутентифицирован, но прав нет — **403 Forbidden**.

### 3. Как работают AuthenticationManager, ProviderManager, AuthenticationProvider и UserDetailsService

Цепочка аутентификации по логину/паролю:

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant Client
    participant Filter as UsernamePassword<br/>AuthenticationFilter
    participant AM as AuthenticationManager<br/>(ProviderManager)
    participant AP as DaoAuthenticationProvider
    participant UDS as UserDetailsService
    participant PE as PasswordEncoder

    rect rgb(245,248,255)
    Note over Client,PE: 1. Request → AuthenticationManager
    Client->>Filter: POST /login (login, password)
    Filter->>AM: authenticate(UsernamePasswordToken)
    AM->>AP: supports()? yes
    end

    rect rgb(255,252,240)
    Note over AP,PE: 2. Load user + verify password
    AP->>UDS: loadUserByUsername(login)
    UDS-->>AP: UserDetails (hash, authorities)
    AP->>PE: matches(rawPassword, hash)
    PE-->>AP: true
    end

    rect rgb(245,255,245)
    Note over Client,AM: 3. Success → SecurityContext
    AP-->>AM: Authentication (principal, authorities)
    AM-->>Filter: Authentication
    Filter-->>Client: 200 + Session/JWT
    end
```

1. Фильтр (например, `UsernamePasswordAuthenticationFilter`) собирает из запроса `UsernamePasswordAuthenticationToken` (login + пароль) и передаёт его **`AuthenticationManager`**.
2. `AuthenticationManager` — интерфейс; стандартная реализация — **`ProviderManager`**, который перебирает список `AuthenticationProvider`'ов.
3. **`AuthenticationProvider`** (например, `DaoAuthenticationProvider`) решает, умеет ли он обработать такой токен. Для проверки пароля он вызывает **`UserDetailsService.loadUserByUsername()`**, который возвращает `UserDetails` (логин, хэш пароля, authorities), затем сравнивает пароли через `PasswordEncoder`.
4. Успех → возвращается заполненный `Authentication` (плюс он кладётся в `SecurityContext`); неудача → `BadCredentialsException` → 401.

```java
@Bean
AuthenticationManager authManager(UserDetailsService uds, PasswordEncoder encoder) {
    DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
    provider.setUserDetailsService(uds);
    provider.setPasswordEncoder(encoder);       // BCrypt
    return new ProviderManager(provider);
}

@Bean
UserDetailsService users(UserRepository repo) {
    return login -> repo.findByLogin(login)
        .map(u -> User.withUsername(u.login())
                      .password(u.passwordHash())
                      .roles(u.role())          // -> ROLE_ADMIN
                      .build())
        .orElseThrow(() -> new UsernameNotFoundException(login));
}
```

Собственная логика (двухфакторная аутентификация, вход по OTP) делается кастомным `AuthenticationProvider` — ProviderManager сам найдёт его по типу токена.

### 4. Что такое SecurityContext и SecurityContextHolder

**`SecurityContextHolder`** — хранилище текущего контекста безопасности: внутри — `SecurityContext` c объектом `Authentication` (кто аутентифицирован и какие authorities). Фильтры заполняют его в начале запроса, очищают в конце.

**`SecurityContextHolderFilter`** (Spring Security 6, замена `SecurityContextPersistenceFilter`):
- **Stateless (JWT)**: просто читает контекст из заголовка/токена, **не** сохраняет в `HttpSession` (нет лишних вызовов к репозиторию сессий).
- **Stateful (cookie-session)**: загружает `SecurityContext` из сессии, при изменении — сохраняет обратно.
- Старый `SecurityContextPersistenceFilter` делал `saveSecurityContext()` после каждого запроса (даже если не изменился) — лишняя запись в сессию/БД.

Стратегия хранения (`SecurityContextHolder.MODE_*`):
- **`MODE_THREADLOCAL`** (по умолчанию) — контекст привязан к текущему потоку: каждый HTTP-запрос обрабатывается одним потоком, поэтому контекст «виден» во всём колстеке запроса;
- **`MODE_INHERITABLETHREADLOCAL`** — контекст наследуют дочерние потоки (осторожно с пулами);
- **`MODE_GLOBAL`** — один на JVM (редко нужно).

Последствия для многопоточности: в `@Async`, CompletableFuture с ForkJoinPool и listener'ах Kafka контекст **не доступен** — потоки другие. Решения: `DelegatingSecurityContextAsyncTaskExecutor`, `DelegatingSecurityContextExecutor`, перенос данных явно.

```java
Authentication auth = SecurityContextHolder.getContext().getAuthentication();
String login = auth.getName();                        // principal.getUsername()
boolean admin = auth.getAuthorities().stream()
    .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
```

В контроллере проще: параметр метода `@AuthenticationPrincipal UserDetails user` или `Principal principal` — Spring сам достанет из контекста.

### 5. Как настроить SecurityFilterChain и что изменилось по сравнению с WebSecurityConfigurerAdapter

С Spring Security 5.7+ (и полностью в Spring Boot 3) конфигурация через наследование `WebSecurityConfigurerAdapter` **удалена** — теперь декларативная сборка бина `SecurityFilterChain`:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain apiChain(HttpSecurity http, JwtAuthFilter jwt) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)            // для stateless REST API
            .cors(Customizer.withDefaults())                   // берём CorsConfigurationSource
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**", "/actuator/health").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/products/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .sessionManagement(s ->
                s.sessionCreationPolicy(SessionCreationPolicy.STATELESS)) // JWT
            .exceptionHandling(e -> e
                .authenticationEntryPoint(rest401())           // 401 JSON вместо redirect
                .accessDeniedHandler(rest403()))               // 403 JSON
            .addFilterBefore(jwt, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
```

Ключевые изменения по сравнению с адаптером: несколько `SecurityFilterChain` можно объявить как несколько бинов с `securityMatcher(...)` (например, отдельная цепочка для API и для админки); DSL-методы принимают `Customizer`; `authorizeRequests` заменён на `authorizeHttpRequests` с новым `AuthorizationManager` и `requestMatchers` (вместо `antMatchers`).

### 6. Как работает аутентификация по JWT end-to-end

**JWT (JSON Web Token)** — самодостаточный подписанный токен из трёх частей Base64URL: `header.payload.signature`. Payload содержит claims (`sub` — субъект, `exp` — время жизни, `roles`). Подпись (HMAC или RSA/ECDSA) гарантирует, что токен не подделан — серверу не нужно хранить сессию.

Полный цикл:

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client
    participant AF as JwtAuthFilter
    participant S as SecurityContextHolder
    participant CTRL as Controller

    rect rgb(245,248,255)
    Note over C,CTRL: 1. Login
    C->>CTRL: POST /auth/login (login, password)
    CTRL-->>C: 200 { access_token (15min), refresh_token (7d) }
    end

    rect rgb(255,252,240)
    Note over C,CTRL: 2. Authenticated request
    C->>AF: GET /api/orders (Bearer <at>)
    AF->>AF: validate signature + exp
    AF->>S: setAuthentication(claims)
    AF->>CTRL: doFilter (chain continues)
    CTRL-->>C: 200 [orders]
    end

    rect rgb(255,245,245)
    Note over C,CTRL: 3. Token expired → refresh
    C->>AF: GET /api/orders (Bearer <expired>)
    AF-->>C: 401 Unauthorized
    C->>CTRL: POST /auth/refresh (refresh_token)
    CTRL-->>C: 200 { new_access, new_refresh }
    end
```

1. **Логин**: клиент POST /api/auth/login {login, password} → сервер проверяет через `AuthenticationManager` → генерирует access (15 мин) и refresh (7 дней) токены, подписанные секретом.
2. **Запросы**: клиент шлёт `Authorization: Bearer <access-token>`.
3. **Фильтр** (`OncePerRequestFilter`) до `UsernamePasswordAuthenticationFilter`: извлекает Bearer-токен, валидирует подпись/срок, достаёт claims, строит `Authentication` и кладёт в `SecurityContextHolder`.
4. Дальше обычная авторизация по authorities.

```java
public class JwtAuthFilter extends OncePerRequestFilter {
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws IOException, ServletException {
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            Claims claims = jwt.parse(header.substring(7));     // подпись + exp
            var auth = new UsernamePasswordAuthenticationToken(
                claims.getSubject(), null,
                ((List<String>) claims.get("roles")).stream()
                    .map(SimpleGrantedAuthority::new).toList());
            SecurityContextHolder.getContext().setAuthentication(auth);
        }
        chain.doFilter(req, res);
    }
}
```

Плюсы JWT: stateless, масштабируется без sticky sessions, микросервисы валидируют токен без обращения к серверу аутентификации. Минусы: **нельзя отозвать до exp** (лечится коротким TTL access + refresh-механикой и blacklist'ом в Redis), размер больше session-id, данные в payload **читаемы** всеми (Base64 — не шифрование).

### 7. Как правильно хранить пароли: PasswordEncoder, BCrypt, соль

**Золотое правило: пароли никогда не хранятся в открытом виде и не хешируются MD5/SHA-одиночкой.** Для паролей нужны **адаптивные медленные хэши**: BCrypt, SCrypt, Argon2. Они содержат **соль** (случайные данные, встроенные в результат хэша) и **фактор стоимости** — количество итераций, настраиваемое под рост вычислительных мощностей.

```java
PasswordEncoder encoder = new BCryptPasswordEncoder(12); // фактор стоимости 2^12 итераций

String hash = encoder.encode("myPassword123");
// $2a$12$X5... — алгоритм/фактор/соль зашиты в строку результата, соль хранить отдельно НЕ нужно

boolean ok = encoder.matches("myPassword123", hash); // сравнение с постоянным временем
```

Особенности:
- **BCrypt** — самая частая практика в Java (Spring: `PasswordEncoderFactories.createDelegatingPasswordEncoder()` выдаёт `{bcrypt}`-делегат, позволяющий смешивать форматы и мигрировать);
- **DelegatingPasswordEncoder** позволяет менять алгоритм без перегенерации всех хэшей: новые записи — новый алгоритм, старые — валидируются по префиксу;
- Проверка через `matches()` требует того же salt — поэтому он хранится вместе с хэшем;
- **Rehash on login**: при успешном входе, если фактор стоимости устарел, можно перехэшировать пароль.

Что НЕ делать: хранить пароль в БД открыто; `MD5/SHA-256` без соли и итераций (мгновенный перебор радужными таблицами); «своя криптография». Для Kafka/БД-паролей и секретов — это не про PasswordEncoder, а про хранилище секретов (Vault, Secrets Manager).

### 8. В чём разница между hasRole и hasAuthority

`GrantedAuthority` — единое понятие «право» (строка). **Роли** — конвенция поверх прав: роль `ADMIN` хранится как `ROLE_ADMIN`. Методы проверки:

- **`hasAuthority("ADMIN")`** — точное сравнение строки authority: нужна ровно `ADMIN`;
- **`hasRole("ADMIN")`** — автоматически добавляет префикс `ROLE_`: эквивалентно `hasAuthority("ROLE_ADMIN")`;
- **`hasAnyRole("ADMIN", "USER")`**, **`hasAnyAuthority(...)`** — несколько вариантов;
- **`@PreAuthorize("hasRole('ADMIN') and #id == authentication.principal.id")`** — SpEL в метод-секьюрити.

```java
// authorities пользователя: [ROLE_ADMIN, order:read]
.requestMatchers("/api/admin/**").hasRole("ADMIN")        // проверит ROLE_ADMIN
.requestMatchers("/api/orders/**").hasAuthority("order:read") // тонкое право

@PreAuthorize("@orderSecurity.isOwner(#orderId, authentication)")
public OrderDto get(long orderId) { ... }                 // кастомный бин-вычислитель
```

Практика: роли — грубые категории (ADMIN/USER/MANAGER), authorities — точные права (`invoice:create`). Смешение приводит к багам: если `UserDetailsService` выдаёт `roles("ADMIN")` (→ `ROLE_ADMIN`), а проверка стоит `hasAuthority("ADMIN")` — доступ не будет получен никогда. Отладочный приём: логировать `authentication.getAuthorities()` при непонятных 403.

### 9. Как работает метод-безопасность (@PreAuthorize, @PostAuthorize, @Secured)

Аннотации включаются `@EnableMethodSecurity` (в Boot 3; старое `@EnableGlobalMethodSecurity` — prePostEnabled и т.п.) и проверяются **AOP-прокси**: вызов метода проходит через interceptor с SpEL-оценкой выражения до/после выполнения.

- **`@PreAuthorize`** — проверка **до** вызова; доступ к аргументам через `#имяПараметра`;
- **`@PostAuthorize`** — проверка **после**; доступ к результату через `returnObject` (защита «могу видеть только свои объекты»);
- **`@PostFilter`/`@PreFilter`** — фильтрация коллекций (дорого на больших данных);
- **`@Secured("ROLE_ADMIN")`** — старый упрощённый вариант, только роли;
- **`@RolesAllowed`** — JSR-250 стандартная аннотация.

```java
@Configuration
@EnableMethodSecurity   // включает @PreAuthorize и friends
public class MethodSecurityConfig { }

@Service
public class InvoiceService {

    @PreAuthorize("hasRole('ACCOUNTANT') or hasAuthority('invoice:read')")
    public Invoice get(long id) { ... }

    @PostAuthorize("returnObject.ownerId == authentication.principal.id")
    public Report readMy(long id) { ... }   // чужой отчёт -> AccessDeniedException 403

    @PreAuthorize("@acl.canWrite(#docId, authentication)")  // кастомный бин ACL
    public void edit(long docId, DocDto dto) { ... }
}
```

Тонкости: аннотации работают только через прокси. **Self-invocation**: `this.securedMethod()` из другого метода того же класса **проигнорирует** проверку прав (прокси не участвует) — та же проблема, что у `@Transactional`. Решение: вынести в отдельный бин или `AopContext.currentProxy()` (требует `@EnableMethodSecurity` + `exposeProxy`). Для REST-контроллеров предпочтительнее URL-правила, метод-секьюрити — для доменных сервисов, где одни и те же методы вызываются из разных мест.

### 10. Что такое CSRF-атака и когда её нужно защищать

**CSRF (Cross-Site Request Forgery)** — атака, при которой браузер жертвы отправляет запрос на ваш сайт **с её же аутентификацией** (cookie сессии приложится автоматически), потому что вредоносная страница инициировала POST, например `bank.com/transfer?to=hacker`. Сервер не может отличить «пользователь нажал кнопку» от «страница злоумышленника отправила форму» — куки-то валидные.

**Защита — CSRF-токен**: сервер выдаёт случайный токен (в сессии или cookie), клиент обязан вернуть его в каждом модифицирующем запросе (заголовок `X-CSRF-TOKEN` или поле формы). Токен с другого origin у злоумышленника недоступен из-за same-origin policy.

```java
// Для cookie-session веб-приложения CSRF защита ОБЯЗАТЕЛЬНА:
http.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    .csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler()));

// Для stateless REST API с JWT в заголовке Authorization — CSRF невозможен:
// браузер не приложит чужой JWT автоматически (это не cookie),
// поэтому csrf можно отключать:
http.csrf(AbstractHttpConfigurer::disable);
```

Ответ на собесе, который ценят: «CSRF актуален только для cookie-based аутентификации; token-in-header схемы (JWT Bearer) от CSRF не страдают, потому что атакующий не может заставить браузер автоматически подставить заголовок». В Spring Security 6 токены по умолчанию привязаны к сессии и используют `XorCsrfTokenRequestAttributeHandler` (защита от BREACH).

### 11. Чем CORS отличается от CSRF и как настроить CORS в Spring

**CORS (Cross-Origin Resource Sharing)** — это **не защита от атакующего**, а механизм **разрешения** браузеру делать запросы с другого origin (протокол+домен+порт). По умолчанию same-origin policy блокирует JS фронтенда `app.example.ru` при запросе к `api.example.ru`. Сервер должен явно разрешить: заголовки `Access-Control-Allow-Origin`, `-Methods`, `-Headers`; для запросов с нестандартными заголовками браузер сначала шлёт **preflight OPTIONS**.

```java
@Bean
CorsConfigurationSource corsSource() {
    CorsConfiguration cfg = new CorsConfiguration();
    cfg.setAllowedOrigins(List.of("https://app.example.ru")); // НЕ "*"+credentials
    cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    cfg.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-CSRF-TOKEN"));
    cfg.setAllowCredentials(true);        // куки/Authorization
    cfg.setMaxAge(3600L);
    UrlBasedCorsConfigurationSource src = new UrlBasedCorsConfigurationSource();
    src.registerCorsConfiguration("/api/**", cfg);
    return src;
}

// В цепочке: .cors(Customizer.withDefaults()) — фильтр CorsFilter встанет первым
```

Резюме различий: **CORS** — «какому сайту разрешить пользоваться моим API» (сервер → браузер), **CSRF** — «как убедиться, что запрос сделал сам пользователь» (защита от подделки). Настройка в Spring: бин `CorsConfigurationSource` + `.cors()` в SecurityFilterChain, либо `@CrossOrigin` на контроллере (для мелких случаев), либо глобальный `WebMvcConfigurer#addCorsMappings` — но при использовании Spring Security security-конфигурация важнее MVC-шной.

### 12. Как в Spring Security настроить OAuth2/OIDC-вход и что такое resource server

Два разных режима интеграции с внешним identity-провайдером (Keycloak, Auth0, Google):

1. **OAuth2 Login (клиент)** — ваше приложение — веб-приложение, пользователи входят через провайдера: `spring-boot-starter-oauth2-client`, редирект на провайдера, авторизационный код, обмен на токены, сессия внутри вашего приложения.

```java
http.oauth2Login(o -> o.userInfoEndpoint(u ->
        u.userService(customAuthoritiesMapper)));  // маппинг ролей из Keycloak
```

2. **Resource Server** — ваше приложение — REST API, проверяющий чужие JWT: `spring-boot-starter-oauth2-resource-server`. Spring сам валидирует подпись (JWKS-эндпоинт провайдера) и создаёт `Authentication` из claims.

```java
http.oauth2ResourceServer(rs -> rs.jwt(j -> j
    .decoder(JwtDecoders.fromIssuerLocation("https://idp.example.ru/realms/app")))
);
// authorities из claim realm_access.roles:
@Bean
JwtAuthenticationConverter jwtConverter() {
    var conv = new JwtAuthenticationConverter();
    conv.setJwtGrantedAuthoritiesConverter(token -> {
        var realm = (Map<String, Object>) token.getClaims().get("realm_access");
        return ((List<String>) realm.get("roles")).stream()
            .map(r -> new SimpleGrantedAuthority("ROLE_" + r)).toList();
    });
    return conv;
}
```

Терминология для собеса: **OIDC** — слой идентификации поверх OAuth2 (id_token с юзером); **issuer** — адрес провайдера; **JWKS** — публичные ключи для проверки подписи; **scopes** — делегированные права API. Понимать, что JWT в этом сценарии — access-токен, выданный провайдером, а не вашим сервисом (как в self-signed JWT из вопрос 592).



### 13. OAuth2-флоу детально: Authorization Code + PKCE, Client Credentials, Device Code

**Authorization Code + PKCE** (для публичных клиентов: SPA, mobile):

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
sequenceDiagram
    participant C as Client (SPA/Mobile)
    participant U as User (Browser)
    participant P as Provider (IdP)

    rect rgb(245,248,255)
    Note over C,P: 1. Prepare PKCE + redirect
    Note over C: code_verifier = random(43-128)<br/>code_challenge = SHA256(verifier)
    C->>U: redirect /authorize?code_challenge=...
    end

    rect rgb(255,252,240)
    Note over U,P: 2. User login + code back
    U->>P: GET /authorize (user logs in)
    P-->>U: 302 ?code=AUTH_CODE&state=...
    U->>C: receive code (redirect)
    end

    rect rgb(245,255,245)
    Note over C,P: 3. Token exchange (PKCE verify)
    C->>P: POST /token (code + code_verifier)
    Note over P: verify: SHA256(verifier)==challenge?
    P-->>C: 200 { access_token, refresh_token }
    end
```

1. Клиент генерирует `code_verifier` (случайная строка 43–128 символов) и `code_challenge = BASE64URL(SHA256(code_verifier))`.
2. Клиент редиректит на `/authorize?response_type=code&client_id=...&code_challenge=...&code_challenge_method=S256&state=...`.
3. Пользователь логинится на провайдере, провайдер редиректит обратно с `?code=...&state=...`.
4. Клиент шлёт `/token` с `grant_type=authorization_code&code=...&code_verifier=...`.
5. Провайдер проверяет: `SHA256(code_verifier) == code_challenge`? Да → выдаёт `access_token` + `refresh_token`.

**Зачем PKCE**: без него злоумышленник, перехватив `code` (например, через custom scheme `myapp://`), мог бы обменять его на токен. С PKCE обмен без `code_verifier` невозможен.

**Client Credentials** (service-to-service, без пользователя):
1. Клиент шлёт `/token` с `grant_type=client_credentials&client_id=...&client_secret=...&scope=...`.
2. Провайдер проверяет credentials → выдаёт `access_token` (без `refresh_token`).
3. Используется для машинных вызовов (API-to-API), не для пользователей.

**Device Code** (устройства без браузера: TV, IoT):
1. Клиент шлёт `/device_authorization` с `client_id` → получает `device_code`, `user_code`, `verification_uri`.
2. Пользователь вводит `user_code` на другом устройстве (с браузером).
3. Клиент поллит `/token` с `grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=...` до получения токена (с exponential backoff по `interval`).

**Сравнение**:
| Флоу | Клиент | Пользователь | Сценарий |
|---|---|---|---|
| Auth Code + PKCE | Публичный (SPA, mobile) | Да | Веб-приложение, мобильное приложение |
| Client Credentials | Конфиденциальный (сервис) | Нет | API-to-API, микросервисы |
| Device Code | Публичный (TV, IoT) | Да (на другом устройстве) | Устройства без браузера |

**В Spring Boot 3**:
```java
// Authorization Code + PKCE (oauth2-client)
http.oauth2Login(o -> o
    .authorizationEndpoint(a -> a.baseUri("/auth"))
    .redirectionEndpoint(r -> r.baseUri("/login/oauth2/code/myprovider")));

// Client Credentials (oauth2-client как resource server для других)
@Bean
OAuth2ClientRegistrationRepository clientRegistrations() {
    ClientRegistration reg = ClientRegistration.withRegistrationId("my-service")
        .clientName("my-service")
        .clientSecret("{noop}secret")
        .authorizationGrantType(AuthorizationGrantType.CLIENT_CREDENTIALS)
        .tokenUri("https://idp/token")
        .scope("api:read")
        .build();
    return new InMemoryClientRegistrationRepository(reg);
}
```

### 14. Refresh Token Rotation: зачем, как работает, проблемы

**Refresh Token Rotation** — при каждом использовании `refresh_token` провайдер выдаёт **новый** `refresh_token` и **инвалидирует старый**. Если старый пытаются использовать повторно (утёк) — провайдер **отзывает всю цепочку** токенов (detect stolen token).

**Почему важно**:
- Обычный `refresh_token` живёт долго (30–90 дней). Если он утёк — злоумышленник получает доступ всё это время.
- С rotation: если утёкший `refresh_token` используют **после** того, как легитимный клиент уже получил новый — провайдер понимает, что токен украден, и **отзывает всю сессию**.

**Как работает (псевдокод)**:

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#f3f4f6' } } }%%
stateDiagram-v2
    [*] --> Active: RT issued
    Active --> Rotated: client uses RT (POST /token)
    Rotated --> [*]: RT_NEW issued, RT_OLD invalidated
    Active --> Revoked: stolen RT used after rotation
    Rotated --> Revoked: replay attack detected
    Revoked --> [*]: entire token family revoked
    classDef s0 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef s1 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef s2 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    state "Active" as Active
    state "Rotated" as Rotated
    state "Revoked" as Revoked
    class Active s0
    class Rotated s1
    class Revoked s2
```

```
// Клиент: POST /token
// { grant_type: "refresh_token", refresh_token: "RT_OLD" }

// Провайдер:
1. Найти RT_OLD в хранилище.
2. Если RT_OLD уже использован (rotated) → УТЁК → отозвать все токены сессии.
3. Если RT_OLD активен:
   a. Пометить RT_OLD как использованный.
   b. Создать RT_NEW.
   c. Выдать: { access_token: "AT_NEW", refresh_token: "RT_NEW" }.
```

**Проблемы**:
- **Race condition**: если два клиента используют один `refresh_token` одновременно (например, десктоп + мобильный) — один из них получит `invalid_grant`. Решение: **family ID** (цепочка rotation) + **grace period** (старый токен валиден N секунд после rotation).
- **Идемпотентность**: повторный запрос с тем же `refresh_token` в grace period → выдаём тот же новый токен (не создаём новый).
- **Хранение**: `refresh_token` нужно хранить на сервере (в отличие от JWT access). Использовать **Redis** (TTL = срок жизни) или **БД** (с индексом по token hash).

**В Spring Security 6**:
```java
// RefreshTokenRotation не встроена — нужно кастомный OAuth2AuthorizationService
// или использовать Keycloak (встроенная rotation)
```

**Best practice**:
- **Access token**: 5–15 мин (JWT, stateless).
- **Refresh token**: 7–30 дней (opaque, stateless на клиенте, stateful на сервере).
- **Rotation**: обязательно для публичных клиентов.
- **Replay detection**: если старый refresh token использовали после rotation → отозвать всё.

### 15. JWT: JWS vs JWE, key rotation, JWKS endpoint

**JWS (JSON Web Signature)** — JWT с **подписью** (HMAC, RSA, ECDSA). Гарантирует **целостность** и **аутентичность**, но **не конфиденциальность** (payload читается).

**JWE (JSON Web Encryption)** — JWT с **шифрованием** (RSA-OAEP, A256GCM). Гарантирует **конфиденциальность** (payload зашифрован), но **не подпись** (если не комбинировать: JWE + JWS = signed + encrypted).

**Когда что**:
- **Access token** в API: **JWS** (RS256/ES256) — каждый сервис проверяет подпись, payload содержит claims (roles, sub).
- **Сенситивные данные** в токене (email, phone): **JWE** или **JWE+JWS** — чтобы при перехвате не читали.
- **Refresh token**: обычно **opaque** (не JWT), хранится на сервере.

**Структура JWS**:
```
eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIiwiZXhwIjoxNzAwMDAwMDAwfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
│                    │                          │
Header (Base64URL)   Payload (Base64URL)        Signature
{"alg":"RS256"}      {"sub":"user123","exp":...} RSA signature
```

**Key Rotation**:
- **Публичный ключ** провайдера меняется периодически (ежемесячно, при компрометации).
- **JWKS (JSON Web Key Set)** — endpoint `https://idp/.well-known/jwks.json`, содержит **все** активные публичные ключи (текущий + предыдущие).
- **Клиент** кэширует JWKS и обновляет по TTL (обычно 1 час) или при `unknown kid`.
- **`kid` (Key ID)** — в header JWT, указывает **каким** ключом подписано. Клиент находит ключ по `kid` в JWKS.

```json
// JWKS response
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "key-2026-01",
      "alg": "RS256",
      "use": "sig",
      "n": "0vx7...",
      "e": "AQAB"
    },
    {
      "kty": "RSA",
      "kid": "key-2025-12",  // предыдущий (ещё валиден)
      "alg": "RS256",
      "n": "abc1...",
      "e": "AQAB"
    }
  ]
}
```

**В Spring Boot 3**:
```java
// Resource server: автоматически кэширует JWKS
http.oauth2ResourceServer(rs -> rs
    .jwt(j -> j
        .jwtAuthenticationConverter(jwtConverter())
        // NimbusJwtDecoder сам ходит на JWKS и кэширует
        .decoder(JwtDecoders.fromIssuerLocation("https://idp.example.ru/realms/app"))
    )
);

// Custom cache TTL:
@Bean
NimbusJwtDecoder jwtDecoder() {
    JWKSetSource<RemoteJWKSet> jwkSource = JWKSetSources
        .from(RSAClient.create("https://idp/.well-known/jwks.json"))
        .withCache(new CachingJWKSetCache(3600, 86400)); // TTL 1h, max 1d
    return NimbusJwtDecoder.withJwkSet(jwkSource.get()).build();
}
```

**Типовые ошибки**:
- **Не обновлять JWKS** при ротации → `invalid signature`.
- **`alg: none`** (CRITICAL): злоумышленник подделывает заголовок JWT, убирает подпись и ставит `alg: none` — невалидирующий декодер примет токен как легитимный. **Никогда** не принимать токены с `alg: none`. Spring `NimbusJwtDecoder` защищает по умолчанию (отклоняет `none`), но при кастомном парсинге — проверять.
- **Не проверять `iss`** (issuer) → токен от другого провайдера принят.
- **Не проверять `aud`** (audience) → токен для другого API принят.
- **Чувствительные данные в payload**: помним, что payload — это **Base64, а не шифрование**. Пароли, PII, токены — **никогда** в claims JWS.

### 16. Token revocation: blacklist vs short TTL + refresh

**Проблема**: JWT stateless — **нельзя отозвать** до `exp`. Пользователь сменил пароль, вышел из аккаунта, но access token (15 мин) всё ещё валиден.

**Два подхода**:

**1. Blacklist (Redis)**:
- При logout/смене пароля: добавить `jti` (JWT ID) или `sub + iat` в **Redis** с TTL = оставшееся время жизни токена.
- При каждом запросе: фильтр проверяет Redis — есть ли `jti` в blacklist?
- **Плюс**: мгновенное отозвание.
- **Минус**: каждый запрос → Redis (latency ~1–5 мс), Redis = single point of failure.

```java
// Logout:
String jti = jwt.getJwtId();
redis.opsForValue().set("revoked:" + jti, "1", jwt.getExpiresAt().toInstant().minus(Instant.now()));

// Filter:
String jti = jwt.getJwtId();
if (redis.hasKey("revoked:" + jti)) {
    throw new BadCredentialsException("Token revoked");
}
```

**2. Short TTL + Refresh**:
- **Access token**: 5–15 мин (малый TTL → окно отозвания мало).
- **Refresh token**: 7–30 дней (хранится на сервере, можно отозвать мгновенно).
- При logout: **отозвать refresh token** (удалить из Redis/БД) → access token умрёт через 5–15 мин.
- **Плюс**: нет Redis-запроса на каждый request, stateless.
- **Минус**: окно отозвания = TTL access (до 15 мин).

**Сравнение**:
| | Blacklist | Short TTL + Refresh |
|---|---|---|
| Скорость отозвания | Мгновенная | До TTL access (5–15 мин) |
| Нагрузка на Redis | Каждый request | Только при refresh/logout |
| Stateless | Нет (Redis) | Да (access) |
| Сложность | Средняя | Низкая |
| Подходит для | Высокая безопасность (банки) | Обычные API |

**Best practice 2026**: **Short TTL + Refresh** для большинства API. **Blacklist** только для критичных (финансы, здоровье).

### 17. Method Security глубже: SpEL, custom PermissionEvaluator, @PostFilter

**SpEL (Spring Expression Language)** в `@PreAuthorize`/`@PostAuthorize`:
```java
@PreAuthorize("hasRole('ADMIN') or #id == authentication.principal.id")
public Order get(long id) { ... }

@PostAuthorize("returnObject.ownerId == authentication.principal.id or hasRole('ADMIN')")
public Order update(OrderDto dto) { ... }

// Доступ к аргументам: #id, #dto, #dto.field
// Доступ к возвращаемому: returnObject, returnObject.field
// Доступ к authentication: authentication.principal, authentication.authorities
// Вызов бина: @myBean.method(#arg)
```

**Custom PermissionEvaluator** (legacy API, Spring Security 5):
```java
@Component
public class MyPermissionEvaluator implements PermissionEvaluator {
    @Override
    public boolean isGranted(F_permission permission, Authentication auth) {
        // Кастомная логика
        return auth.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals(permission.get()));
    }
    // hasPermission(Object targetDomainObject, Authentication auth, String permission)
    // hasPermission(Class<?> targetDomainClass, Authentication auth, String permission)
}
```

**Modern: AuthorizationManager (Spring Security 6)**:
```java
// Method-level AuthorizationManager
@Bean
AuthorizationManager<MethodInvocation> myMethodAuthZManager() {
    return (auth, invocation) -> {
        Method method = invocation.getMethod();
        if (method.isAnnotationPresent(AdminOnly.class)) {
            boolean isAdmin = auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
            return AuthorizationDecision.of(isAdmin);
        }
        return AuthorizationDecision.notAuthorized();
    };
}
```

**@PostFilter** (фильтрация коллекции):
```java
@PostFilter("filterObject.ownerId == authentication.principal.id")
public List<Order> getAll() {
    return orderRepo.findAll(); // вернёт только свои заказы
}

@PostFilter("filterObject.status == 'PUBLISHED'")
public List<Article> getPublished() {
    return articleRepo.findAll(); // только опубликованные
}
```
**Важно**: `@PostFilter` фильтрует **в памяти** (после загрузки из БД) — **дорого** на больших данных. Лучше фильтровать в БД (WHERE).

**Типовые ошибки**:
- **Self-invocation**: `this.method()` → прокси не срабатывает (та же проблема, что у `@Transactional`).
- **`@PostFilter` на 100K строк** → OOM.
- **SpEL injection**: `@PreAuthorize("#userInput")` → **критичная уязвимость** (выполнение произвольного кода). **Никогда** не передавать пользовательский ввод в SpEL.

### 18. Security Headers: CSP, X-Frame-Options, HSTS, Permissions-Policy

**Security Headers** — HTTP-заголовки, которые защищают браузер от атак (XSS, clickjacking, MITM).

**Content-Security-Policy (CSP)**:
- Ограничивает, **откуда** браузер может загружать ресурсы (scripts, styles, images, fonts).
- Защита от **XSS**: даже если злоумышленник внедрил `<script>` в DOM — браузер не выполнит его, если origin не в allowlist.
```
Content-Security-Policy: default-src 'self'; script-src 'self' https://cdn.example.com; img-src 'self' data:; style-src 'self' 'unsafe-inline'
```
- **`default-src`** — fallback для всех типов.
- **`script-src`** — откуда можно загружать скрипты.
- **`'unsafe-inline'`** — разрешить inline-скрипты (небезопасно, но часто нужно для Angular/React).
- **`'nonce-...'`** — разрешить конкретный inline-скрипт по nonce (лучше, чем `'unsafe-inline'`).

**X-Frame-Options**:
- Запрещает встраивание страницы в `<iframe>` (защита от **clickjacking**).
```
X-Frame-Options: DENY        // нельзя встраивать нигде
X-Frame-Options: SAMEORIGIN // можно только с того же origin
```
- **Альтернатива**: CSP `frame-ancestors 'none'` / `frame-ancestors https://trusted.com`.

**Strict-Transport-Security (HSTS)**:
- Принудительно **HTTPS** (браузер автоматически редиректит HTTP → HTTPS).
- Защита от **MITM** (man-in-the-middle) и **SSL stripping**.
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```
- **`max-age`** — сколько секунд помнить (1 год = 31536000).
- **`includeSubDomains`** — применять ко всем поддоменам.
- **`preload`** — добавить в HSTS preload list (браузеры знают заранее).

**Permissions-Policy**:
- Ограничивает **features** браузера (camera, microphone, geolocation, payment).
```
Permissions-Policy: camera=(), microphone=(), geolocation=(self "https://maps.example.com")
```

**В Spring Security 6**:
```java
http
    .headers(h -> h
        .contentSecurityPolicy(csp -> csp
            .policyDirectives("default-src 'self'; script-src 'self'; img-src 'self' data:"))
        .frameOptions(f -> f.deny())
        .httpStrictTransportSecurity(hsts -> hsts
            .maxAge(Duration.ofDays(365))
            .includeSubDomains(true))
        .permissionsPolicy(pp -> pp
            .policy("camera=()")
            .policy("microphone=()"))
    );
```

**Типовые ошибки**:
- **CSP без `script-src`** → inline-скрипты блокируются (React/Angular не работают).
- **HSTS на HTTP-only** → браузер не применит (HSTS только для HTTPS).
- **X-Frame-Options: DENY** → нельзя встроить в `<iframe>` (если нужно — `SAMEORIGIN` или CSP `frame-ancestors`).

### 19. mTLS в Spring Boot: настройка, certificate validation

**mTLS (mutual TLS)** — **взаимная** аутентификация: клиент и сервер **оба** предъявляют сертификаты. Используется для **service-to-service** (микросервисы в Kubernetes, service mesh).

**Отличие от обычного TLS**:
- **Обычный TLS**: клиент проверяет сертификат сервера, сервер **не** проверяет клиента.
- **mTLS**: клиент проверяет сертификат сервера, **и** сервер проверяет сертификат клиента.

**Настройка в Spring Boot (Tomcat)**:
```yaml
server:
  port: 8443
  ssl:
    key-store: classpath:keystore.p12
    key-store-password: changeit
    key-store-type: PKCS12
    key-alias: my-service
    client-auth: wanted  # или required
```
- **`client-auth: wanted`** — запросить клиентский сертификат, но **не требовать** (если нет — запрос без аутентификации).
- **`client-auth: required`** — **обязательно** (без сертификата → 400).

**Кастомная валидация сертификата**:
```java
@Bean
WebServerFactoryCustomizer<TomcatServletWebServerFactory> mTlsCustomizer() {
    return factory -> factory.addContextCustomizers(context -> {
        context.setProtocolHandler("http");
        // Custom trust manager: валидация по SAN, CN, CA
    });
}
```

**В Kubernetes (Service Mesh)**:
- **Istio/Linkerd** автоматически настраивают mTLS между подами (sidecar proxy).
- Приложение **не** видит TLS (sidecar перехватывает трафик).
- **Spring Boot** работает на **HTTP** (8080), sidecar делает **TLS** (15001).

**Проблемы**:
- **Сертификаты**: нужно генерировать и вращать (rotating) сертификаты для каждого сервиса. В Kubernetes — **cert-manager** + **Let's Encrypt** (или internal CA).
- **CA chain**: клиент должен доверять **CA**, который подписал сертификат сервера (и наоборот).
- **SAN (Subject Alternative Names)**: modern browsers/clients **не** проверяют `CN`, только `SAN`.

**Best practice**:
- **В Kubernetes**: использовать **service mesh** (Istio/Linkerd) — mTLS on by default, нет необходимости настраивать в приложении.
- **Вне Kubernetes**: настроить mTLS в Tomcat/Netty, использовать **cert-manager** для управления сертификатами.

### 20. OWASP Top 10: применение к Spring-приложениям

**OWASP Top 10** — список 10 самых критичных уязвимостей веб-приложений. Применение к Spring:

1. **Broken Access Control** (нарушение контроля доступа):
   - **Проблема**: пользователь A видит данные пользователя B (IDOR).
   - **Защита**: `@PreAuthorize("returnObject.ownerId == authentication.principal.id")`, URL-правила, **не** полагаться на frontend-скрытие.

2. **Cryptographic Failures** (криптографические сбои):
   - **Проблема**: передача/хранение чувствительных данных в открытом виде.
   - **Защита**: **HTTPS** (HSTS), **BCrypt/Argon2** для паролей, **AES-256** для данных, **не** логировать токены/пароли.

3. **Injection** (инъекции):
   - **Проблема**: SQL injection, NoSQL injection, command injection.
   - **Защита**: **Parameterized queries** (JPA `@Query` с `:param`), **не** конкатенация SQL, **input validation** (`@Valid`, `@Pattern`).

4. **Insecure Design** (ненадёжный дизайн):
   - **Проблема**: отсутствие rate limiting, отсутствие audit log, отсутствие MFA.
   - **Защита**: **Rate limiting** (Bucket4j, Redis), **audit log** (кто, что, когда), **MFA** для критичных операций.

5. **Security Misconfiguration** (ошибки конфигурации):
   - **Проблема**: открытые actuator endpoints, debug mode, default credentials.
   - **Защита**: **закрыть** `/actuator/**` (только `/health` публичный), **выключить** debug, **сменить** default passwords.

6. **Vulnerable Components** (уязвимые компоненты):
   - **Проблема**: использование библиотек с известными CVE.
   - **Защита**: **Dependabot/Renovate** (авто-обновление), **OWASP Dependency-Check** (CI), **Snyk**.

7. **Authentication Failures** (сбои аутентификации):
   - **Проблема**: weak password policy, отсутствие lockout, отсутствие MFA.
   - **Защита**: **BCrypt/Argon2**, **rate limiting** на `/login`, **MFA** (TOTP), **account lockout** после N попыток.

8. **Integrity Failures** (сбои целостности):
   - **Проблема**: unsafe deserialization, отсутствие CSRF.
   - **Защита**: **CSRF token** (Spring Security), **безопасная десериализация** (whitelist классов), **signed cookies**.

9. **Logging Failures** (сбои логирования):
   - **Проблема**: отсутствие audit log, отсутствие correlation ID.
   - **Защита**: **structured logging** (JSON), **MDC** (trace_id, user_id), **audit log** для критичных операций.

10. **SSRF (Server-Side Request Forgery)**:
    - **Проблема**: приложение делает запросы по URL из пользовательского ввода (внутренние сервисы).
    - **Защита**: **allowlist** доменов, **запрет** internal IP (10.x, 172.x, 192.168.x), **не** передавать пользовательский URL напрямую.

**В Spring Boot 3**:
```java
// Rate limiting (Bucket4j)
@Bean
public RequestRateLimiter rateLimiter() {
    return new RequestRateLimiter() {
        public Mono<Boolean> requestAllowed(String routeId, String id) {
            // Redis-based rate limiting
            return Mono.fromCallable(() -> redisRateLimiter.tryAcquire(routeId, id));
        }
    };
}

// Audit logging
@Aspect
@Component
public class AuditAspect {
    @Around("@annotation(Audited)")
    public Object audit(ProceedingJoinPoint pjp) throws Throwable {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        log.info("AUDIT: user={} action={} args={}", auth.getName(), pjp.getSignature(), pjp.getArgs());
        return pjp.proceed();
    }
}
```

### 21. Session fixation и session hijacking: защита

**Session Fixation**:
- **Атака**: злоумышленник **задаёт** session ID жертве (например, через URL `?JSESSIONID=ATTACKER_ID`), жертва логинится, злоумышленник получает доступ к сессии.
- **Защита**: **смена session ID** после логина (Spring Security делает это автоматически при `sessionFixation().migrateSession()`).

```java
http.sessionManagement(s -> s
    .sessionFixation(f -> f.migrateSession())  // смена ID после логина
    .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED));
```

**Session Hijacking**:
- **Атака**: злоумышленник **перехватывает** session ID (через XSS, MITM, sniffing) и использует его.
- **Защита**:
  - **HTTPS** (HSTS) — защита от MITM.
  - **HttpOnly** cookie — защита от XSS (`document.cookie` недоступен).
  - **Secure** flag — cookie только по HTTPS.
  - **Short TTL** — сессия живёт 30–60 мин, не 30 дней.
  - **IP binding** (опционально) — сессия привязана к IP (проблемно за NAT).

**В Spring Security 6**:
```java
http.sessionManagement(s -> s
    .sessionFixation(f -> f.migrateSession())
    .maximumSessions(1)  // одна сессия на пользователя (новая вытесняет старую)
    .sessionConcurrencyController(new MyConcurrencyController())
);

http.cookies(c -> c
    .session(s -> s
        .httpOnly(true)
        .secure(true)
        .sameSite("Lax"))
);
```

**SameSite cookie**:
- **`Strict`** — cookie **не** отправляется при cross-site запросах (максимальная защита от CSRF).
- **`Lax`** — cookie отправляется при **top-level navigation** (GET), но **не** при POST (баланс).
- **`None`** — cookie отправляется всегда (нужен `Secure` flag) — для cross-site API.

**Best practice**:
- **HttpOnly + Secure + SameSite=Lax** для session cookie.
- **Migrate session** после логина.
- **Maximum 1 session** на пользователя (опционально).
- **Short TTL** (30–60 мин) + **sliding expiration** (обновляется при активности).

### 22. Password storage: Argon2, SCrypt, rehash on login

**Argon2** (winner Password Hashing Competition 2015):
- **Параметры**: `memory` (KiB), `iterations`, `parallelism`.
- **Зачем**: **memory-hard** (занимает много RAM) → **не** атакуется на GPU/ASIC (в отличие от BCrypt, который **parallelizable**).
- **В Java**: `de.mkammerer:argon2-jvm` (JNI) или `org.bouncycastle:bcprov-jdk18on` (pure Java, медленнее).

```java
// Argon2 (Bouncy Castle)
Argon2Generator generator = new Argon2Generator(
    Argon2Generator.ARGON2_id,  // Argon2id (best)
    65536,  // memory 64 MiB
    3,      // iterations
    4,      // parallelism
    32);    // output length (bytes)

String hash = generator.generateHex("password123");
boolean matches = generator.matches("password123", hash);
```

**SCrypt**:
- **Параметры**: `N` (CPU/memory cost), `r` (block size), `p` (parallelism).
- **Зачем**: **memory-hard**, но **старее** Argon2 (2009).
- **В Java**: Bouncy Castle.

```java
SCrypt generator = new SCrypt(16384, 8, 1, 1, 32); // N=2^14, r=8, p=1
String hash = generator.generateHex("password123");
```

**Сравнение**:
| | BCrypt | SCrypt | Argon2 |
|---|---|---|---|
| Год | 1999 | 2009 | 2015 |
| Memory-hard | Нет | Да | Да |
| GPU-атака | Уязвим | Не уязвим | Не уязвим |
| В Spring | Встроен | Bouncy Castle | Bouncy Castle |
| Скорость | Средняя | Медленная | Настройка |

**Rehash on login**:
- При успешном логине: если **фактор стоимости** устарел (например, BCrypt cost=10, а сейчас 12) → **перехэшировать** и сохранить.
- **Почему**: позволяет **постепенно** повышать безопасность без **принудительной** смены паролей.

```java
// В AuthenticationProvider:
public Authentication authenticate(Authentication auth) {
    UserDetails user = userDetailsService.loadUserByUsername(auth.getName());
    boolean matches = passwordEncoder.matches(auth.getCredentials().toString(), user.getPassword());
    if (matches) {
        // Rehash if cost factor changed
        if (needsRehash(user.getPassword())) {
            String newHash = passwordEncoder.encode(auth.getCredentials().toString());
            userDetailsService.updatePassword(user.getUsername(), newHash);
        }
        return new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
    }
    throw new BadCredentialsException("Invalid password");
}

private boolean needsRehash(String hash) {
    // Parse cost factor from hash and compare with current
    return true; // example
}
```

**Best practice 2026**:
- **Argon2id** (memory=64MiB, iterations=3, parallelism=4) для **новых** записей.
- **BCrypt** (cost=12) для **существующих** (rehash on login).
- **DelegatingPasswordEncoder** (`{argon2}`, `{bcrypt}`) для смешивания форматов.
- **Rehash on login** для постепенной миграции.

### 23. Security events и аудит

**Security Events** — события, которые нужно **логировать** и **алертить**:
- **Login** (успех/неудача).
- **Logout**.
- **Password change**.
- **MFA** (успех/неудача).
- **Access denied** (403).
- **Privilege escalation** (смена роли).
- **Session creation/expiration**.
- **Token refresh**.

**Audit Log** (в отличие от **application log**):
- **Иммутабельный** (нельзя изменить/удалить).
- **Структурированный** (JSON: `timestamp`, `user`, `action`, `resource`, `result`, `ip`).
- **Долгоживущий** (1–7 лет, в зависимости от compliance).
- **Отдельное хранилище** (Elasticsearch, SIEM: Splunk, Sumo Logic).

**В Spring Security 6**:
```java
// 1. Listener для security events
@Component
public class SecurityAuditListener {
    @EventListener
    public void onAuthenticationSuccess(AuthenticationSuccessEvent event) {
        log.audit("LOGIN_SUCCESS", event.getAuthentication().getName(), 
            RequestContextHolder.currentRequestAttributes());
    }
    
    @EventListener
    public void onAuthenticationFailure(AuthenticationFailureBadCredentialsEvent event) {
        log.audit("LOGIN_FAILURE", event.getAuthentication().getName(),
            RequestContextHolder.currentRequestAttributes());
    }
    
    @EventListener
    public void onAccessDenied(AccessDeniedEvent event) {
        log.audit("ACCESS_DENIED", event.getAuthentication().getName(),
            event.getDeniedAuthority(),
            RequestContextHolder.currentRequestAttributes());
    }
}

// 2. Audit logger (отдельный appender в Logback)
// logback-spring.xml:
// <appender name="AUDIT" class="ch.qos.logback.core.rolling.RollingFileAppender">
//     <file>logs/audit.log</file>
//     <encoder><pattern>%d{ISO8601} %msg%n</pattern></encoder>
// </appender>
// <logger name="AUDIT" level="INFO" additivity="false">
//     <appender-ref ref="AUDIT"/>
// </logger>
```

**Compliance (GDPR, PCI-DSS, HIPAA)**:
- **GDPR**: логировать **доступ** к personal data, **retention** 1–7 лет.
- **PCI-DSS**: логировать **все** действия с **картами** (PAN, CVV), **retention** 1 год.
- **HIPAA**: логировать **доступ** к **медицинским** данным, **retention** 6 лет.

**Best practice**:
- **Audit log** для **всех** security events.
- **Separate storage** (не в application log).
- **Immutable** (append-only, no delete).
- **Alerting** на **anomalies** (много login failures, access denied из нового IP).

### 24. Как тестировать Spring Security (Unit и Integration)

Тестирование безопасности делится на проверку конфигурации и проверку бизнес-логики с учётом прав.

**1. Интеграционные тесты контроллеров (`@WebMvcTest`)**

```java
@WebMvcTest(OrderController.class)
@ImportTestConfiguration
class OrderControllerTest {

    @Autowired MockMvc mockMvc;

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void adminCanAccessOrders() throws Exception {
        mockMvc.perform(get("/api/orders"))
               .andExpect(status().isOk());
    }

    @Test
    void anonymousGets401() throws Exception {
        mockMvc.perform(get("/api/orders"))
               .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "user", roles = {"USER"})
    void userGets403OnAdminEndpoint() throws Exception {
        mockMvc.perform(get("/api/admin/orders"))
               .andExpect(status().isForbidden());
    }
}
```

**2. Тестирование CSRF-защиты**

```java
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;

@Test
@WithMockUser
void postWithCsrfSucceeds() throws Exception {
    mockMvc.perform(post("/api/orders")
            .with(csrf())
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
           .andExpect(status().isCreated());
}

@Test
@WithMockUser
void postWithoutCsrfFails() throws Exception {
    mockMvc.perform(post("/api/orders")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
           .andExpect(status().isForbidden());
}
```

**3. Тестирование кастомного JwtAuthFilter**

```java
@Test
void jwtFilterSetsAuthentication() throws Exception {
    mockMvc.perform(get("/api/me")
            .header("Authorization", "Bearer " + validJwtToken))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.username").value("testuser"));
}

@Test
void jwtFilterRejectsExpiredToken() throws Exception {
    mockMvc.perform(get("/api/me")
            .header("Authorization", "Bearer " + expiredJwtToken))
           .andExpect(status().isUnauthorized());
}
```

**Аннотации:**
- **`@WithMockUser`** — быстро, не требует `UserDetailsService`. Указывает username/roles/password.
- **`@WithUserDetails`** — загружает реального пользователя через `UserDetailsService` (нужен `@MockBean` для репозитория).
- **`@WithAnonymousUser`** — имитирует анонимный доступ.

**Trade-offs:**
- `@WithMockUser`: быстро, изолировано, но не проверяет реальную логику загрузки из БД.
- `@WithUserDetails`: точнее (реальные authorities из БД), но медленнее и требует моканых зависимостей.

**Follow-up:**
- «А как протестировать кастомный `JwtAuthFilter`?» → Напрямую вызвать `doFilter()` с моком `HttpServletRequest` (заголовок `Authorization: Bearer ...`) и проверить, что в `SecurityContextHolder` появился нужный `Authentication`.
- «Как тестировать OAuth2 login flow?» → `OAuth2AuthorizationRequestRedirectFilter` + mock `OAuth2AuthorizedClientService`; или `@SpringBootTest` + TestRestTemplate на реальную цепочку (wiremock для IdP).

### 25. Reactive Security (WebFlux)

В **WebFlux** (Project Reactor, non-blocking) Spring Security работает иначе:

| Servlet (Spring MVC) | Reactive (WebFlux) |
|---|---|
| `SecurityFilterChain` | `ServerSecurityFilterChain` |
| `HttpSecurity` | `ReactiveHttpSecurity` |
| `SecurityContextHolder` (ThreadLocal) | `ReactiveSecurityContextHolder` (Reactor Context) |
| `OncePerRequestFilter` | `WebFilter` / `WebFilterChain` |
| `@EnableWebSecurity` | `@EnableWebFluxSecurity` |

**Ключевое отличие**: `ReactiveSecurityContextHolder` **не** использует `ThreadLocal` — контекст передаётся через **Reactor Context** (иммутабельная цепочка `Mono`/`Flux`). Это значит:
- Контекст **не теряется** при `publishOn` / `subscribeOn` (в отличие от Servlet + `@Async`).
- Нет проблемы self-invocation с потоками.
- Но: **нельзя** просто вызвать `SecurityContextHolder.getContext()` — нужно `ReactiveSecurityContextHolder.getContext()`.

```java
@Configuration
@EnableWebFluxSecurity
public class ReactiveSecurityConfig {

    @Bean
    ServerSecurityFilterChain springSecurityFilterChain(ServerHttpSecurity http) {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeExchange(auth -> auth
                .pathMatchers("/api/public/**").permitAll()
                .pathMatchers("/api/admin/**").hasRole("ADMIN")
                .anyExchange().authenticated())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .oauth2ResourceServer(o -> o.jwt());
        return http.build();
    }
}

// Доступ к Authentication в reactive-коде:
Mono<String> currentUsername() {
    return ReactiveSecurityContextHolder.getContext()
        .map(ctx -> ctx.getAuthentication().getName());
}
```

**Когда использовать**: high-load API с non-blocking I/O (WebFlux + R2DBC), WebSocket, SSE. Для typical CRUD REST — Spring MVC + `@Async` достаточно.

**Trade-offs:**
- WebFlux: non-blocking, масштабируется на 10K+ concurrent connections с малым числом потоков. Но: сложнее отладка (stack trace через Mono/Flux), не все библиотеки reactive-ready.
- Spring MVC + virtual threads (Java 21): синхронный код, масштабируется как reactive, проще ментальная модель.

---

## Common Pitfalls (частые ошибки)

| # | Ошибка | Симптомы | Решение |
|---|--------|----------|---------|
| 1 | **CORS после Security Filter Chain** | Preflight OPTIONS → 403 | `CorsFilter` должен быть **первым** (Spring Security делает это автоматически через `.cors(withDefaults())`) |
| 2 | **Забыт `.csrf().disable()` для stateless REST** | 403 на все POST/PUT/DELETE | Для JWT Bearer-схемы CSRF невозможен → отключить |
| 3 | **`@PostFilter` на больших выборках** | OOM, медленный ответ | Фильтровать в БД (WHERE), не в памяти |
| 4 | **Хранение PII в JWT payload** | Утечка данных при перехвате | Payload — Base64, **не** шифрование. Только claims (sub, roles, exp) |
| 5 | **Self-invocation в Method Security** | `@PreAuthorize` игнорируется | Вынести в отдельный бин или `AopContext.currentProxy()` |
| 6 | **`hasAuthority("ADMIN")` вместо `hasRole("ADMIN")`** | 403 у ADMIN | `hasRole` добавляет `ROLE_` prefix; `hasAuthority` — точное совпадение |
| 7 | **`alg: none` в JWT** | Подделка токена | Проверять alg; `NimbusJwtDecoder` отклоняет по умолчанию |
| 8 | **Не проверять `iss` / `aud`** | Токен от другого провайдера принят | Валидировать issuer и audience в `JwtAuthenticationConverter` |
| 9 | **Session fixation** | Злоумышленник задаёт session ID | `sessionFixation().migrateSession()` (по умолчанию в Spring Security 6) |
| 10 | **Открытые actuator endpoints** | Утечка env, beans, mappings | `management.endpoints.web.exposure.include=health,info` |
