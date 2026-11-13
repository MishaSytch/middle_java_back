# Глава 22. JWT, OAuth2 и OIDC: resource server, login, свой токен-сервис

> **Уровень:** middle → middle+
> **Время:** 4 часа
> **Цель:** уметь встраивать приложение в корпоративную SSO, правильно валидировать JWT и понимать, когда «свой JWT» — нормальное решение, а когда — источник дыр.

## 22.1. Роли и потоки OAuth2 / OIDC

| Роль | Кто это |
|---|---|
| Resource Owner | пользователь |
| Client | приложение, которое хочет доступ |
| Authorization Server (IdP) | Keycloak, Auth0, Okta, Spring Authorization Server |
| Resource Server | **ваше API**, проверяет access-токен |

**OAuth2** — про *авторизацию* (доступ), **OIDC** — надстройка про *аутентификацию* (`id_token`, `/userinfo`).

| Поток | Когда |
|---|---|
| Authorization Code + **PKCE** | веб/мобильные/SPA — **всегда этот** |
| Client Credentials | сервис-сервис (без пользователя) |
| Refresh Token | продление сессии |
| Implicit / Password (ROPC) | ❌ устарели, не использовать |

Токены:
* **access** — короткий (5–15 мин), несёт `scope`/`roles`, предъявляется API;
* **refresh** — долгий, хранится только у клиента/IdP, обновляет access;
* **id_token** — JWT о пользователе, для клиента (не для API!).

🪤 Отправлять `id_token` в API вместо access — типичная ошибка. API должно валидировать **access**.

## 22.2. JWT: что внутри и что проверять

```text
header.payload.signature   (Base64URL, точки-разделители)

header:  {"alg":"RS256","kid":"key-1","typ":"JWT"}
payload: {"iss":"https://idp/realms/app","sub":"user-uuid","aud":"taskflow-api",
          "exp":1763000000,"iat":1762999100,"scope":"tasks.read tasks.write",
          "realm_access":{"roles":["USER"]}}
```

**Обязательные проверки (все, не только подпись):**
1. Подпись по JWKS (`kid` → ключ), алгоритм из whitelist (**никогда** не доверять `alg` из токена — атака `alg:none`/HS256-with-public-key).
2. `iss` — точное совпадение с ожидаемым издателем.
3. `aud` — ваш API.
4. `exp`/`nbf`/`iat` с допуском на clock skew (≤ 60 с).
5. `scope`/`roles` — для авторизации.
6. Тип токена (`typ`, `token_use`) — не id_token вместо access.

```java
@Bean
JwtDecoder jwtDecoder(@Value("${app.security.issuer}") String issuer,
                      @Value("${app.security.audience}") String audience) {
    var decoder = JwtDecoders.fromIssuerLocation(issuer);   // тянет /.well-known/openid-configuration → jwks
    var withIssuer = JwtValidators.createDefaultWithIssuer(issuer);
    var audienceValidator = new JwtClaimValidator<List<String>>("aud", aud -> aud != null && aud.contains(audience));
    ((JwtDecoder) decoder).setJwtValidator(new DelegatingOAuth2TokenValidator<>(withIssuer, audienceValidator));
    return decoder;
}
```
🎯 **Проверка `aud` — та, которую забывают чаще всего.** Без неё токен, выданный для другого API того же IdP, будет принят вашим.

## 22.3. Resource server в Boot

**[4.x]**
```xml
<dependency><groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security-oauth2-resource-server</artifactId></dependency>
```
**[3.5]** `spring-boot-starter-oauth2-resource-server`.

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://idp.corp.local/realms/taskflow
          # jwk-set-uri: ... (если нет .well-known)
          audiences: taskflow-api        # поддерживается в новых версиях
```
```java
@Bean
SecurityFilterChain api(HttpSecurity http) throws Exception {
    http.securityMatcher("/api/**")
        .csrf(c -> c.disable())
        .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
        .authorizeHttpRequests(a -> a
            .requestMatchers(HttpMethod.GET, "/api/tasks/**").hasAuthority("SCOPE_tasks.read")
            .requestMatchers(HttpMethod.POST, "/api/tasks/**").hasAuthority("SCOPE_tasks.write")
            .anyRequest().authenticated())
        .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(converter())));
    return http.build();
}
```

Маппинг ролей из клеймов Keycloak:
```java
@Bean
JwtAuthenticationConverter converter() {
    var granted = new JwtGrantedAuthoritiesConverter();     // по умолчанию берёт scope/scp → SCOPE_*
    var conv = new JwtAuthenticationConverter();
    conv.setJwtGrantedAuthoritiesConverter(jwt -> {
        var authorities = new ArrayList<GrantedAuthority>(granted.convert(jwt));
        Map<String, Object> realm = jwt.getClaimAsMap("realm_access");
        if (realm != null && realm.get("roles") instanceof Collection<?> roles) {
            roles.forEach(r -> authorities.add(new SimpleGrantedAuthority("ROLE_" + r)));
        }
        return authorities;
    });
    conv.setPrincipalClaimName("sub");
    return conv;
}
```

**Opaque-токены** (когда IdP выдаёт непрозрачные строки) — introspection:
```yaml
spring.security.oauth2.resourceserver.opaquetoken:
  introspection-uri: https://idp/oauth2/introspect
  client-id: taskflow-api
  client-secret: ${API_SECRET}
```
Плюс: мгновенный отзыв. Минус: сетевой вызов на каждый запрос (кэшируйте результат на 30–60 с).

**Несколько издателей (мультитенантность):** `JwtIssuerAuthenticationManagerResolver` — выбирает `AuthenticationManager` по `iss`. Никогда не делайте «доверяем любому iss из токена».

## 22.4. Свой токен-сервис: когда и как

Оправдано, если: нет корпоративного IdP, простой продукт, монолит с одним фронтом. **Не оправдано**, если нужны SSO, MFA, федерация, аудит — берите Keycloak/облачный IdP.

Минимальная правильная схема:
```text
POST /auth/login  (email+password) → access JWT (10 мин) + refresh (opaque, 30 дней, в БД)
POST /auth/refresh (refresh)       → новый access + РОТАЦИЯ refresh (старый инвалидируется)
POST /auth/logout (refresh)        → отзыв refresh
```
```java
@Service
@RequiredArgsConstructor
class TokenService {
    private final JwtEncoder encoder;          // NimbusJwtEncoder с RSA/EC ключом
    private final RefreshTokenRepository refreshRepo;

    public TokenPair issue(User u) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder()
                .issuer("https://api.taskflow.dev")
                .subject(u.id().toString())
                .audience(List.of("taskflow-api"))
                .issuedAt(now).expiresAt(now.plus(Duration.ofMinutes(10)))
                .claim("scope", String.join(" ", u.scopes()))
                .id(UUID.randomUUID().toString())
                .build();
        var access = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(SignatureAlgorithm.RS256).build(), claims)).getTokenValue();
        var refresh = refreshRepo.create(u.id(), Duration.ofDays(30));   // храним ХЭШ токена, не сам токен
        return new TokenPair(access, refresh.raw(), 600);
    }
}
```

Правила, без которых «свой JWT» становится дырой:
* Асимметричная подпись (RS256/ES256), приватный ключ — в secret-хранилище, ротация через `kid` + JWKS.
* Access — короткий; **отзыв** решается коротким TTL, а не «blacklist на каждый запрос».
* Refresh — **opaque**, хранится хэшем в БД, **ротируется** и детектирует повторное использование (reuse → отзыв всей семьи токенов).
* Никаких секретов/персональных данных в payload (JWT — это подписанный, но **не** зашифрованный токен).
* `jti` + короткий denylist — если нужен мгновенный отзыв конкретных access.
* Проверяйте `aud`, `iss`, `exp`, алгоритм — даже свои токены.

🎯 **«JWT нельзя отозвать» — миф наполовину.** Отозвать можно: короткий TTL + отзыв refresh + denylist по `jti` для критичных случаев. Ответ на собеседовании должен включать этот trade-off, а не категоричное «нельзя».

## 22.5. OAuth2 Login и Client (когда вы — клиент)

```xml
<dependency><groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security-oauth2-client</artifactId></dependency>
```
```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: taskflow-web
            client-secret: ${OIDC_SECRET}
            authorization-grant-type: authorization_code
            scope: openid,profile,tasks.read
            redirect-uri: "{baseUrl}/login/oauth2/code/{registrationId}"
        provider:
          keycloak:
            issuer-uri: https://idp.corp.local/realms/taskflow
```
```java
http.oauth2Login(o -> o.defaultSuccessUrl("/", true))
    .logout(l -> l.logoutSuccessHandler(oidcLogoutSuccessHandler()));   // RP-initiated logout
```

Вызов другого API от имени пользователя:
```java
@Bean
RestClient crmClient(RestClient.Builder builder, OAuth2AuthorizedClientManager manager) {
    var interceptor = new OAuth2ClientHttpRequestInterceptor(manager);
    interceptor.setClientRegistrationIdResolver(request -> "keycloak");
    return builder.baseUrl("https://crm").requestInterceptor(interceptor).build();
}
```
Для сервис-сервис — `client_credentials` registration + `AuthorizedClientServiceOAuth2AuthorizedClientManager`.

## 22.6. Где хранить токены в браузере (важный практический вопрос)

| Вариант | Плюсы | Минусы |
|---|---|---|
| `localStorage` | просто | уязвим к XSS (кража токена) |
| JS-память + refresh в httpOnly cookie | лучше | сложнее, нужен refresh-эндпоинт |
| **BFF (backend-for-frontend)**: сессия в httpOnly Secure SameSite cookie, токены только на сервере | **самый безопасный** | нужен серверный слой + CSRF-защита |

🎯 Рекомендация 2026 для веб-приложений: **BFF + cookie-сессия**, токены не покидают сервер. Для мобильных — access в памяти, refresh в secure storage.

## 22.7. Spring Authorization Server (теперь часть Security 7)

Нужен, если вы **сами** IdP (мультипродуктовая SSO, партнёрские интеграции).
```java
@Bean @Order(1)
SecurityFilterChain authServer(HttpSecurity http) throws Exception {
    var settings = AuthorizationServerSettings.builder().issuer("https://auth.taskflow.dev").build();
    http.with(OAuth2AuthorizationServerConfigurer.authorizationServer(), Customizer.withDefaults())
        .authorizeHttpRequests(a -> a.anyRequest().authenticated())
        .exceptionHandling(e -> e.defaultAuthenticationEntryPointFor(
                new LoginUrlAuthenticationEntryPoint("/login"), new MediaTypeRequestMatcher(MediaType.TEXT_HTML)));
    return http.build();
}
```
Это отдельная большая тема; в монолите обычно **не нужен** — берите готовый IdP.

## 22.8. Тестирование

```java
@Test
void acceptsValidJwt() throws Exception {
    mvc.perform(get("/api/tasks/1").with(jwt()
            .jwt(j -> j.claim("scope", "tasks.read").claim("aud", List.of("taskflow-api")))
            .authorities(new SimpleGrantedAuthority("SCOPE_tasks.read"))))
       .andExpect(status().isOk());
}

@Test void rejectsWrongAudience() throws Exception {
    mvc.perform(get("/api/tasks/1").with(jwt().jwt(j -> j.claim("aud", "other-api"))))
       .andExpect(status().isUnauthorized());
}
```
Полноценный интеграционный тест — Keycloak в Testcontainers (`@ServiceConnection` поддерживается для Keycloak-контейнера в новых версиях) или WireMock, отдающий `.well-known` + JWKS.

🎯 Обязательно тестируйте **негативные** кейсы: истёкший токен, чужой `iss`, чужой `aud`, отсутствующая подпись, `alg: none`.

## 22.9. 🪤 Топ-10 граблей JWT/OAuth2

1. Не проверяется `aud`.
2. Доверие `alg` из заголовка.
3ate. `id_token` используется как access.
4. Долгий access (часы) без механизма отзыва.
5. Refresh не ротируется, хранится в открытом виде.
6. Секреты/PII в payload.
7. HS256 с публичным ключом (атака подмены алгоритма).
8. `permitAll` на JWKS-эндпоинт с раскрытием приватного ключа (шутка, но конфиги бывают страшные).
9. Токен в `localStorage` при наличии XSS.
10. Clock skew не настроен → случайные 401 при рассинхроне времени.

## 22.10. Чек-лист безопасности API

- [ ] Валидируются подпись, `iss`, `aud`, `exp`, алгоритм.
- [ ] Access короткий; refresh ротируется и хранится хэшем.
- [ ] Авторизация проверяет и scope, и владение ресурсом.
- [ ] Токены не в логах; `Authorization` маскируется.
- [ ] HTTPS везде, HSTS включён.
- [ ] Есть тесты на негативные токены.
- [ ] Секреты и ключи — во внешнем хранилище, есть план ротации.

## 22.11. 🧪 Практика

1. Поднимите Keycloak в Docker, настройте realm/client/роли, подключите resource server.
2. Добавьте проверку `aud` и тест, который её ломает.
3. Смапьте роли из `realm_access` и проверьте `hasRole`.
4. Реализуйте свой login/refresh/logout с ротацией и детектом reuse.
5. Напишите тест на истёкший токен и на `alg: none`.

## 22.12. Вопросы

1) Чем OAuth2 отличается от OIDC? 2) Почему PKCE обязателен для SPA? 3) Какие клеймы проверяете и почему `aud` критичен? 4) Access vs refresh: TTL, хранение, отзыв. 5) Как отозвать JWT? 6) Opaque vs JWT — trade-offs? 7) Что такое BFF и зачем он? 8) Почему нельзя доверять `alg`?

---

**Назад:** [Глава 21](21-security-osnovy.md) · **Дальше:** [Глава 23. Тестирование →](../05-engineering/23-testirovanie.md)