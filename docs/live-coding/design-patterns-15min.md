# Паттерны проектирования за 15 минут

> Что проверяют: не «расскажи про паттерн», а «примени здесь». Решения на современных средствах Java (enum, record, лямбды) ценятся выше громоздких GoF-классов.

<a id="r20-t1"></a>
**1. [Дизайн] Strategy: способы оплаты**
```java
enum PaymentType { CARD, CASH, CRYPTO }

// классика через интерфейс:
interface PaymentStrategy { Receipt pay(Order o); }
class CardPayment implements PaymentStrategy { /* ... */ }

// современно — Map стратегий (ламбды/ссылки на методы):
Map<PaymentType, Function<Order, Receipt>> strategies = Map.of(
    PaymentType.CARD,   order -> cardGateway.charge(order),
    PaymentType.CASH,   order -> Receipt.cash(order),
    PaymentType.CRYPTO, order -> cryptoWallet.transfer(order));

Receipt pay(PaymentType type, Order order) {
    Function<Order, Receipt> s = strategies.get(type);
    if (s == null) throw new IllegalArgumentException("нет стратегии для " + type);
    return s.apply(order);
}
```
Map вместо switch: добавление способа = одна строка без правки логики. Открытость для расширения при закрытости для изменения — проговорить определение OCP именно так.

<a id="r20-t2"></a>
**2. [Дизайн] Observer: шина событий**
```java
interface Listener<E> { void onEvent(E e); }

class EventBus<E> {
    private final List<Listener<E>> listeners = new CopyOnWriteArrayList<>(); // подписки редкие, события частые
    public void subscribe(Listener<E> l)   { listeners.add(l); }
    public void unsubscribe(Listener<E> l) { listeners.remove(l); }
    public void publish(E e)              { listeners.forEach(l -> l.onEvent(e)); }
}
// listener с ошибкой уронит publish — обернуть try/catch в цикле, если критично
```
CopyOnWriteArrayList — обоснование выбора: мутации при подписке редки, чтение без лаков. Фоллоу-ап: синхронная доставка против очереди.

<a id="r20-t3"></a>
**3. [Дизайн] Decorator: кофе с добавками**
```java
interface Coffee { String description(); BigDecimal price(); }

record SimpleCoffee(String description, BigDecimal price) implements Coffee { }

abstract class CoffeeDecorator implements Coffee {
    protected final Coffee delegate;
    CoffeeDecorator(Coffee delegate) { this.delegate = delegate; }
    @Override public String description() { return delegate.description(); }
    @Override public BigDecimal price()    { return delegate.price(); }
}
class WithMilk extends CoffeeDecorator {
    WithMilk(Coffee c) { super(c); }
    @Override public String description() { return delegate.description() + ", молоко"; }
    @Override public BigDecimal price()    { return delegate.price().add(new BigDecimal("0.50")); }
}
// Coffee order = new WithMilk(new WithMilk(new SimpleCoffee("лунго", new BigDecimal("2.00"))));
```
Вложенная «матрёшка» — каждый слой добавляет поведение поверх любого Coffee. Прямая аналогия с java.io (BufferedReader поверх FileReader) — упомянуть, интервьюеры любят.

<a id="r20-t4"></a>
**4. [Дизайн] Фабрика уведомлений**
```java
interface NotificationSender { void send(String to, String text); }
class EmailSender implements NotificationSender { /* smtp ... */ }
class SmsSender   implements NotificationSender { /* шлюз ... */ }
class PushSender  implements NotificationSender { /* firebase ... */ }

class NotificationFactory {
    public static NotificationSender of(String channel) {
        return switch (channel) {
            case "email" -> new EmailSender();
            case "sms"   -> new SmsSender();
            case "push"  -> new PushSender();
            default      -> throw new IllegalArgumentException("неизвестный канал: " + channel);
        };
    }
}
```
Фабричный метод: вызывающий код не знает конкретных классов. Фоллоу-ап: почему фабрика + map-стратегия часто лучше switch-фабрики (регистрация без правок); DI-контейнер как «фабрика на максималках».

<a id="r20-t5"></a>
**5. [Дизайн] Proxy: кэширующая обёртка**
```java
interface UserService { User load(long id); }

class CachingUserService implements UserService {
    private final UserService delegate;
    private final Map<Long, Optional<User>> cache = new ConcurrentHashMap<>(); // кэшируем и «нет такого»

    CachingUserService(UserService delegate) { this.delegate = delegate; }

    @Override
    public User load(long id) {
        return cache.computeIfAbsent(id, k -> Optional.ofNullable(delegate.load(k)))
                    .orElseThrow(() -> new NoSuchElementException("user " + id));
    }
}
```
Кэширование Optional.empty — «негативный кэш»: повторные запросы несуществующих id не бьют в БД. Фоллоу-ап: TTL и вытеснение — поверх Caffeine, а не руками.

<a id="r20-t6"></a>
**6. [Дизайн|hard] Chain of Responsibility: пайплайн middleware**
```java
record Request(String token, String path) { }
record Response(int code, String body) { }
@FunctionalInterface
interface Handler { Response handle(Request r); }

class Middleware {
    private final List<Function<Handler, Handler>> layers = new ArrayList<>();

    public Middleware use(Function<Handler, Handler> layer) {   // слой = обёртка над следующим
        layers.add(layer);
        return this;
    }
    public Response run(Request req) {
        Handler pipeline = r -> new Response(200, "ok");        // финальный обработчик
        for (int i = layers.size() - 1; i >= 0; i--)            // собираем «матрёшку» изнутри
            pipeline = layers.get(i).apply(pipeline);
        return pipeline.handle(req);
    }
}
// использование:
Middleware mw = new Middleware();
mw.use(next -> r -> r.token() == null
    ? new Response(401, "unauthorized")
    : next.handle(r));
mw.use(next -> r -> {
    log.info(r.path());
    return next.handle(r);
});
Response resp = mw.run(new Request("jwt...", "/api/orders"));
```
Каждый слой решает: обработать самому или передать дальше. Сборка с хвоста — чтобы первый `use` оказался внешним. Прямая отсылка к фильтрам Servlet/Spring — проговорить.

---
<a id="razdel-21"></a>
