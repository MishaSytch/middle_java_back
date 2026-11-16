# Паттерны проектирования

### 1. Что такое паттерны проектирования

Паттерны проектирования (design patterns) — это **повторно используемые, проверенные решения** типичных проблем, возникающих при проектировании программного обеспечения. Паттерн не является готовым кодом — это **шаблон, описание подхода**, который можно адаптировать к конкретной задаче. Паттерны помогают разработчикам общаться на общем языке («здесь нужен Strategy»), делают архитектуру более понятной, гибкой и поддерживаемой. Впервые систематизированы «бандой четырёх» (GoF — Gamma, Helm, Johnson, Vlissides) в книге 1994 года.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    P[Паттерн проектирования]
    P --> C[Порождающие<br/>Creational]
    P --> S[Структурные<br/>Structural]
    P --> B[Поведенческие<br/>Behavioral]
    classDef n0 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class P n0
    class C n1
    class S n2
    class B n3
```

### 2. Какие категории паттернов существуют

Классическая классификация GoF делит паттерны на три категории:
- **Порождающие (Creational)**: отвечают за механизмы создания объектов, скрывая логику инстанцирования. Примеры: Singleton, Factory Method, Abstract Factory, Builder, Prototype.
- **Структурные (Structural)**: описывают способы композиции классов и объектов для образования более крупных структур. Примеры: Adapter, Decorator, Facade, Composite, Proxy, Bridge, Flyweight.
- **Поведенческие (Behavioral)**: определяют взаимодействие между объектами и распределение обязанностей. Примеры: Strategy, Observer, Command, State, Template Method, Iterator, Chain of Responsibility, Mediator, Visitor, Memento.

Отдельно выделяют **архитектурные паттерны** (MVC, CQRS, Event Sourcing, Saga) и **антипаттерны**.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TB
    subgraph C[Порождающие]
        C1[Singleton]
        C2[Factory Method]
        C3[Abstract Factory]
        C4[Builder]
        C5[Prototype]
    end
    subgraph S[Структурные]
        S1[Adapter]
        S2[Decorator]
        S3[Facade]
        S4[Composite]
        S5[Proxy]
        S6[Bridge]
        S7[Flyweight]
    end
    subgraph B[Поведенческие]
        B1[Strategy]
        B2[Observer]
        B3[Command]
        B4[State]
        B5[Template Method]
        B6[Iterator]
        B7[Chain of Responsibility]
        B8[Mediator]
        B9[Visitor]
        B10[Memento]
    end
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class C n4
    class C1 n0
    class C2 n0
    class C3 n0
    class C4 n0
    class C5 n0
    class S n4
    class S1 n1
    class S2 n1
    class S3 n1
    class S4 n1
    class S5 n1
    class S6 n1
    class S7 n1
    class B n4
    class B1 n2
    class B2 n2
    class B3 n2
    class B4 n2
    class B5 n2
    class B6 n2
    class B7 n2
    class B8 n2
    class B9 n2
    class B10 n2
```

### 3. Что такое Singleton

**Singleton (Одиночка)** — порождающий паттерн, гарантирующий, что у класса есть **ровно один экземпляр**, и предоставляющий **глобальную точку доступа** к нему. Реализуется через приватный конструктор, статическое поле для хранения экземпляра и статический метод `getInstance()`. Используется для ресурсов, которые должны быть единственными в системе: конфигурации, пулы соединений, кэши, логгеры.

**В Spring:** все бины по умолчанию являются синглтонами (`scope="singleton"`). Контейнер сам управляет единственным экземпляром и решает проблемы потокобезопасности, поэтому вручную реализовывать Singleton не нужно.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    C[Клиент] -->|getInstance| S[Singleton]
    S --> I[Единственный экземпляр]
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class C n0
    class S n1
    class I n2
```

### 4. Как реализовать потокобезопасный Singleton

Несколько способов:
- **Eager initialization** (жадная инициализация): статическое `final`-поле инициализируется при загрузке класса. Потокобезопасно, но экземпляр создаётся даже если не нужен.
- **Synchronized `getInstance()`**: просто, но синхронизация на каждом вызове — накладно.
- **Double-checked locking** с `volatile`: эффективно, но требует аккуратности.
- **Bill Pugh (holder class)**: статический вложенный класс-держатель — ленивая и потокобезопасная инициализация за счёт гарантий загрузки классов JVM. Один из лучших подходов.
- **Enum Singleton**: самый надёжный — защищён от рефлексии, сериализации, потокобезопасен «из коробки». Рекомендуется Джошуа Блохом.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    A[Eager initialization] --> S[Потокобезопасный Singleton]
    B[Synchronized getInstance] --> S
    C[Double-checked locking с volatile] --> S
    D[Holder class — Bill Pugh] --> S
    E[Enum Singleton] --> S
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n5 fill:#d9f99d,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class A n0
    class B n1
    class C n2
    class D n3
    class E n4
    class S n5
```

### 5. Что такое double-checked locking

**Double-checked locking (DCL)** — идиома для ленивой потокобезопасной инициализации Singleton с минимальными накладными расходами:
```java
private static volatile Singleton instance;
public static Singleton getInstance() {
    if (instance == null) {              // первая проверка (без блокировки)
        synchronized (Singleton.class) {
            if (instance == null) {      // вторая проверка (под блокировкой)
                instance = new Singleton();
            }
        }
    }
    return instance;
}
```
Первая проверка избегает синхронизации в «горячем» пути, вторая — гонки при инициализации. **Критически важно** поле `volatile`: без него возможна публикация частично сконструированного объекта из-за переупорядочивания инструкций (до Java 5 DCL был сломан).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TD
    A[getInstance] --> B{instance == null?}
    B -->|нет| R[return instance]
    B -->|да| C[synchronized Singleton class]
    C --> D{instance == null?}
    D -->|нет| R
    D -->|да| E[создать Singleton]
    E --> R
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n5 fill:#d9f99d,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class A n0
    class B n1
    class C n2
    class D n3
    class E n4
    class R n5
```

### 6. Каковы проблемы с Singleton

- **Глобальное состояние**: Singleton — это по сути глобальная переменная, что усложняет понимание зависимостей и приводит к скрытой связанности.
- **Сложность тестирования**: из-за глобального состояния и приватного конструктора трудно подменить реализацию моком; тесты могут влиять друг на друга через общее состояние.
- **Нарушение SRP**: класс отвечает и за свою бизнес-логику, и за управление своим единственным экземпляром.
- **Проблемы в многопоточности и распределённых системах**: «единственный» экземпляр — только в рамках одной JVM; в кластере их будет несколько.
- **Скрытые зависимости**: классы, использующие Singleton, не декларируют зависимость в конструкторе, что затрудняет понимание архитектуры.
- **Проблемы с сериализацией и рефлексией**: обычный Singleton можно «взломать» через рефлексию или десериализацию (кроме enum-реализации).

Современная рекомендация: вместо Singleton использовать **Dependency Injection** — контейнер сам управляет единственным экземпляром, а зависимости явно декларируются.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    G[Глобальное состояние] --> P[Проблемы Singleton]
    T[Сложность тестирования] --> P
    S[Nарушение SRP] --> P
    D[Скрытые зависимости] --> P
    P --> R[Решение — Dependency Injection]
    classDef n0 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n1 fill:#fdf9e8,stroke:#d4c38a,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#d9f99d,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class G n0
    class T n0
    class S n0
    class D n0
    class P n1
    class R n3
```

### 7. В чём разница между Factory Method и Abstract Factory

- **Factory Method** — порождающий паттерн, определяющий **интерфейс для создания объекта**, но позволяющий **подклассам** решать, какой конкретный класс инстанцировать. Один метод создаёт **один продукт**; выбор реализации — через наследование.
- **Abstract Factory** — порождающий паттерн, предоставляющий **интерфейс для создания целого семейства связанных объектов** без указания их конкретных классов. Одна фабрика создаёт **несколько взаимосвязанных продуктов** (например, `Button` и `Checkbox` для одной ОС); выбор семейства — через композицию (передачу конкретной фабрики).

Кратко: Factory Method — «один продукт, наследование», Abstract Factory — «семейство продуктов, композиция». Abstract Factory часто реализуется через несколько Factory Method.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TB
    subgraph FM[Factory Method — один продукт]
        C[Client] --> A[Product]
        A --> A1[ConcreteProductA]
        A --> A2[ConcreteProductB]
        C -->|new| M[Creator createProduct]
    end
    subgraph AF[Abstract Factory — семейство]
        AC[Client] --> AFa[AbstractFactory]
        AFa --> F1[createButton]
        AFa --> F2[createCheckbox]
        AFa --> CF1[WinFactory]
        AFa --> CF2[MacFactory]
    end
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n5 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n6 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n7 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n8 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class C n0
    class A n1
    class A1 n2
    class A2 n2
    class M n3
    class FM n8
    class AC n4
    class AFa n5
    class F1 n6
    class F2 n6
    class CF1 n7
    class CF2 n7
    class AF n8
```

### 8. Когда использовать Builder

Паттерн **Builder** стоит использовать, когда:
- У объекта **много параметров** (особенно опциональных), и телескопические конструкторы становятся нечитаемыми.
- Нужно строить объект **пошагово**, с возможностью проверить инварианты перед созданием.
- Требуется создавать **неизменяемые (immutable)** объекты со множеством полей: Builder накапливает значения, а `build()` создаёт финальный объект.
- Один и тот же процесс конструирования должен порождать **разные представления** объекта.
- Нужна **читаемость** кода создания: `new Pizza.Builder().size(LARGE).cheese(true).build()`.

Не стоит использовать Builder для простых объектов с 1–3 полями — это избыточно.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    D[Director] --> B[Builder]
    B -->|size cheese| P[Pizza]
    B -->|build| P
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class D n0
    class B n1
    class P n2
```

### 9. Что такое Prototype pattern

**Prototype (Прототип)** — порождающий паттерн, при котором создание новых объектов происходит **путём клонирования существующего экземпляра (прототипа)**, а не через `new`. В Java реализуется через интерфейс `Cloneable` и метод `clone()` (или через конструктор копирования / фабрику копий). Полезен, когда:
- Создание объекта «с нуля» дорого (много вычислений, обращений к БД).
- Нужно создать объект, повторяющий состояние существующего, с небольшими изменениями.
- Система должна быть независима от способа создания своих объектов.

Важно различать **shallow copy** (по умолчанию `Object.clone()`) и **deep copy** (требует ручной реализации для вложенных объектов).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    P[Prototype] -->|clone| C1[Копия 1]
    P -->|clone| C2[Копия 2]
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    class P n0
    class C1 n1
    class C2 n1
```

### 10. Когда использовать Strategy

Паттерн **Strategy** стоит использовать, когда:
- Есть **несколько взаимозаменяемых алгоритмов** решения одной задачи, и нужно выбирать один во время выполнения.
- Нужно избавиться от большого `if/else` или `switch` по типу поведения.
- Требуется **инкапсулировать** алгоритмы в отдельные классы, чтобы их можно было независимо тестировать и развивать.
- Нужно менять поведение объекта **динамически** без изменения его класса.

Пример: различные стратегии скидок, алгоритмы сортировки, способы оплаты. В Java часто реализуется через интерфейс + несколько реализаций, которые внедряются через конструктор (композиция).

**Как реализовать Strategy в Spring без if/else (Map Injection):**

Классическая проблема Strategy: как выбрать нужную стратегию без длинного `if/else` или `switch`? В Spring это элегантно решается внедрением коллекции или Map стратегий.

```java
public interface PaymentStrategy {
    boolean supports(String type);
    void pay(BigDecimal amount);
}

@Component
public class CreditCardPaymentStrategy implements PaymentStrategy {
    public boolean supports(String type) { return "CREDIT_CARD".equals(type); }
    public void pay(BigDecimal amount) { /* ... */ }
}

@Component
public class CryptoPaymentStrategy implements PaymentStrategy {
    public boolean supports(String type) { return "CRYPTO".equals(type); }
    public void pay(BigDecimal amount) { /* ... */ }
}

@Service
public class PaymentService {
    private final List<PaymentStrategy> strategies;

    // Spring автоматически внедрит ВСЕ бины, реализующие PaymentStrategy
    public PaymentService(List<PaymentStrategy> strategies) {
        this.strategies = strategies;
    }

    public void processPayment(String type, BigDecimal amount) {
        strategies.stream()
            .filter(strategy -> strategy.supports(type))
            .findFirst()
            .orElseThrow(() -> new IllegalArgumentException("Unsupported type"))
            .pay(amount);
    }
}
```

**Преимущество:** добавление новой стратегии требует только создания нового класса с `@Component`. Класс `PaymentService` изменять не нужно (принцип Open-Closed).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    C[Context] --> S[Strategy]
    S --> S1[ConcreteStrategyA]
    S --> S2[ConcreteStrategyB]
    S --> S3[ConcreteStrategyC]
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    class C n0
    class S n1
    class S1 n2
    class S2 n2
    class S3 n2
```

### 11. Как реализован Observer в Java

Паттерн **Observer** реализован в Java несколькими способами:
- **Классический (устаревший)**: класс `java.util.Observable` и интерфейс `java.util.Observer` (deprecated с Java 9).
- **События и слушатели (Listener)**: стандартный подход в Swing/AWT (`ActionListener`, `MouseListener` и т.д.) — субъект хранит список слушателей и вызывает их методы при событии.
- **`java.beans.PropertyChangeListener` / `PropertyChangeSupport`**: для уведомления об изменении свойств бина.
- **Реактивные библиотеки**: RxJava (`Observable`, `Flowable`), Project Reactor (`Flux`, `Mono`), `java.util.concurrent.Flow` (Java 9+, Reactive Streams) — современные реализации с поддержкой backpressure.

**В Spring:** Observer реализован через `ApplicationEventPublisher` и `@EventListener`. Это позволяет публиковать события внутри приложения и обрабатывать их в отдельных слушателях, не создавая жёсткой связи между компонентами.

Суть одна: субъект (subject) хранит коллекцию наблюдателей (observers) и при изменении состояния уведомляет их, вызывая общий метод.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    S[Subject] -->|notify| O1[Observer 1]
    S -->|notify| O2[Observer 2]
    S -->|notify| O3[Observer 3]
    classDef n0 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    class S n0
    class O1 n1
    class O2 n1
    class O3 n1
```

### 12. В чём преимущество Decorator перед наследованием

**Decorator** оборачивает объект в другой объект того же интерфейса, добавляя поведение **динамически, во время выполнения**, путём композиции. Преимущества перед наследованием:
- **Гибкость во время выполнения**: можно комбинировать декораторы в любом порядке и количестве, а наследование фиксируется на этапе компиляции.
- **Избежание «взрыва классов»**: для N независимых расширений наследование требует до 2^N подклассов; декораторы комбинируются.
- **Соблюдение SRP и OCP**: каждое расширение — отдельный класс, не затрагивающий другие.
- **Отсутствие жёсткой связи** с конкретным родителем.

Классический пример в Java — потоки ввода-вывода: `new BufferedReader(new InputStreamReader(new FileInputStream(...)))`.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    C[Client] --> D2[Decorator B]
    D2 --> D1[Decorator A]
    D1 --> C1[ConcreteComponent]
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    class C n0
    class D2 n1
    class D1 n2
    class C1 n3
```

### 13. В чём разница между State и Strategy

Структурно паттерны очень похожи (интерфейс + несколько реализаций, делегирование), но **намерения разные**:
- **Strategy**: клиент **явно выбирает** алгоритм и передаёт его объекту. Стратегии **не знают друг о друге** и обычно **не меняют себя** — выбор делает внешний код. Цель — взаимозаменяемость алгоритмов.
- **State**: объект **сам меняет своё поведение** при изменении внутреннего состояния, переключаясь между реализациями. Состояния **знают друг о друге** и могут инициировать переходы (`context.setState(new NextState())`). Цель — моделирование конечного автомата.

Кратко: в Strategy переходы управляются извне, в State — изнутри (самими состояниями).

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart TB
    subgraph STR[Strategy — выбор извне]
        SC[Client] -->|выбирает| SS[Strategy]
        SS --> SA[Alg A]
        SS --> SB[Alg B]
    end
    subgraph ST[State — переходы изнутри]
        CT[Context] --> S1[State A]
        S1 -->|setState| S2[State B]
        S2 -->|setState| S3[State C]
    end
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n3 fill:#f0f9ef,stroke:#9dc49a,stroke-width:2px,color:#1f2937
    classDef n4 fill:#ffffff,stroke:#d1d5db,stroke-width:2px,color:#1f2937
    class SC n0
    class SS n1
    class SA n2
    class SB n2
    class CT n0
    class S1 n3
    class S2 n3
    class S3 n3
    class STR n4
    class ST n4
```

### 14. Какие типы Proxy существуют

**Proxy (Заместитель)** — структурный паттерн, предоставляющий объект-заместитель, контролирующий доступ к исходному объекту. Типы:
- **Virtual Proxy (виртуальный)**: откладывает создание «тяжёлого» объекта до первого обращения (ленивая инициализация).
- **Remote Proxy (удалённый)**: представляет объект, находящийся в другом адресном пространстве (RMI, gRPC-стабы).
- **Protection Proxy (защитный)**: контролирует доступ на основе прав (проверка авторизации перед вызовом).
- **Smart Reference / Caching Proxy**: добавляет дополнительную логику при обращении (кэширование, подсчёт ссылок, логирование).
- **Copy-on-Write Proxy**: откладывает копирование до момента записи.
- **Logging Proxy**: логирует вызовы.
- **Firewall Proxy**: фильтрует запросы.

В Java Proxy реализуется через **JDK Dynamic Proxy** (для интерфейсов) или **CGLIB** (для классов); Spring AOP использует оба механизма.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    C[Client] --> P[Proxy]
    P --> R[RealSubject]
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    class C n0
    class P n1
    class R n2
```

### 15. Что такое Iterator pattern

**Iterator (Итератор)** — поведенческий паттерн, предоставляющий **способ последовательного обхода элементов коллекции** без раскрытия её внутреннего представления. Выносит логику обхода в отдельный объект-итератор с методами `hasNext()` и `next()` (и опционально `remove()`). Позволяет:
- Обходить разные структуры данных единообразно.
- Иметь **несколько независимых итераторов** для одной коллекции.
- Менять внутреннюю реализацию коллекции, не затрагивая клиентский код.

В Java это интерфейсы `java.util.Iterator` и `java.lang.Iterable`; все коллекции Collection Framework поддерживают итерацию, в том числе через `for-each`.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    C[Client] -->|createIterator| I[Iterator]
    C -->|hasNext next| I
    I --> A[Aggregate Collection]
    classDef n0 fill:#eaf5fd,stroke:#94bcd8,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    classDef n2 fill:#eef4ff,stroke:#93a8d4,stroke-width:2px,color:#1f2937
    class C n0
    class I n1
    class A n2
```

### 16. Какие антипаттерны вы знаете

**Антипаттерн** — это распространённое, но **ошибочное** решение, которое выглядит как паттерн, но приводит к проблемам. Основные:
- **God Object (Божественный объект)**: класс, который «знает и делает всё», нарушает SRP.
- **Spaghetti Code**: запутанный код без структуры, с запутанными переходами и зависимостями.
- **Copy-Paste Programming**: дублирование кода вместо переиспользования; нарушает DRY.
- **Magic Numbers / Strings**: «магические» константы без объяснения.
- **Anemic Domain Model**: классы данных без логики, вся логика вынесена в сервисы — нарушает инкапсуляцию.
- **Singleton (как антипаттерн)**: при чрезмерном использовании превращается в глобальное состояние.
- **Golden Hammer**: применение одного любимого инструмента/подхода ко всем задачам.
- **Premature Optimization**: оптимизация до профилирования, в ущерб читаемости.
- **Big Ball of Mud**: система без чёткой архитектуры, всё связано со всем.
- **Lava Flow**: мёртвый/устаревший код, который боятся удалить.
- **Cargo Cult Programming**: копирование кода/ритуалов без понимания, зачем они нужны.
- **Shotgun Surgery**: одно изменение требует правок во множестве мест (признак плохой связанности).
- **Feature Envy**: метод больше интересуется данными другого класса, чем своего.

```mermaid
%%{init: { 'theme': 'neutral', 'themeVariables': { 'primaryColor': '#ffffff', 'primaryTextColor': '#1f2937', 'lineColor': '#6b7280', 'primaryBorderColor': '#d1d5db', 'secondaryColor': '#f3f4f6', 'tertiaryColor': '#e5e7eb' } } }%%
flowchart LR
    AP[Антипаттерн] --> G[God Object]
    AP --> S[Spaghetti Code]
    AP --> CP[Copy-Paste]
    AP --> AN[Anemic Domain Model]
    AP --> BB[Big Ball of Mud]
    AP --> SS[Shotgun Surgery]
    AP --> FE[Feature Envy]
    classDef n0 fill:#fdeef0,stroke:#d49a9c,stroke-width:2px,color:#1f2937
    classDef n1 fill:#f6eefa,stroke:#bb9ed4,stroke-width:2px,color:#1f2937
    class AP n1
    class G n0
    class S n0
    class CP n0
    class AN n0
    class BB n0
    class SS n0
    class FE n0
```


### 17. Что такое CQRS (Command Query Responsibility Segregation)

**Проблема:** одна модель для чтения и записи приводит к аномалиям и сложностям оптимизации.

**Решение:**
- **Command** — запись (CommandHandler)
- **Query** — чтение (QueryHandler)
- **Разные модели** — Command model и Query model

**Важно:** CQRS **не обязательно** подразумевает Event Sourcing или разные базы данных. Это может быть просто разделение моделей чтения и записи в рамках одного монолита для оптимизации запросов. Например, Command Model — нормализованная схема для записи, Query Model — денормализованная схема для чтения.

```java
// Command:
public class CreateOrderCommand {
    private Long userId;
    private List<OrderItem> items;
}

public class CreateOrderHandler {
    public void handle(CreateOrderCommand command) {
        // Write to OrderStore
    }
}

// Query:
public class GetOrdersQuery {
    private Long userId;
}

public class GetOrdersHandler {
    public List<OrderDto> handle(GetOrdersQuery query) {
        // Read from OrderReadModel
    }
}
```

**Когда использовать:**
- **Разная нагрузка** на чтение и запись
- **Разные модели** для чтения и записи
- **Event sourcing** (часто в паре)

### 18. Что такое Event Sourcing

**Проблема:** традиционное хранение состояния (CRUD) перезаписывает данные, теряя историю изменений. Невозможно точно узнать, *почему* и *как* объект пришёл к текущему состоянию.

**Решение:** Event Sourcing (источник событий) хранит не текущее состояние, а **неизменяемую последовательность всех событий** (Domain Events), которые произошли с объектом. Текущее состояние вычисляется путём последовательного применения всех событий к пустому агрегату (`state = apply(events)`).

**Преимущества:**
- **Полный аудит**: видно каждое действие, кто его совершил и когда.
- **Временные срезы (Time Travel)**: можно восстановить состояние системы на любой момент в прошлом.
- **Гибкость чтения**: можно создавать новые проекции (Read Models) из истории событий постфактум.

**Критическая проблема производительности и её решение:**
Если у агрегата 10 000 событий, восстановление его состояния при каждом запросе убьёт производительность.
**Решение — Snapshots (снимки состояния):**
- Периодически (например, каждые 100 событий) система сохраняет сериализованное текущее состояние агрегата как Snapshot.
- При восстановлении состояния загружается последний Snapshot, и события применяются только начиная с него, а не с нуля.

```java
// Event:
public class OrderCreatedEvent {
    private String orderId;
    private BigDecimal amount;
    private Instant createdAt;
}

// Event store:
public interface EventStore {
    void appendEvent(OrderCreatedEvent event);
    List<OrderCreatedEvent> getEvents(String orderId);
}

// State:
public class OrderState {
    private String orderId;
    private BigDecimal amount;
    
    public void apply(OrderCreatedEvent event) {
        this.orderId = event.getOrderId();
        this.amount = event.getAmount();
    }
}
```

**Плюсы:**
- **История** — полная история изменений
- **Аудит** — кто, что, когда
- **Debug** — воспроизвести состояние
- **Time travel** — состояние на любой момент

**Минусы:**
- **Сложность** — event handling
- **Хранение** — много событий
- **Query** — сложный query (read model)

### 19. Что такое Saga pattern

**Проблема:** В микросервисной архитектуре нельзя использовать распределённые транзакции (2PC/XA) из-за блокировок и низкой доступности. Как гарантировать, что цепочка локальных транзакций в разных сервисах либо выполнится полностью, либо будет отменена?

**Решение:** Saga — это последовательность локальных транзакций, где каждая следующая запускается после успешного завершения предыдущей. Если один из шагов завершается ошибкой, Saga выполняет **компенсационные транзакции** (compensating transactions) в обратном порядке, чтобы отменить эффекты предыдущих шагов.

**Два подхода к реализации:**

1. **Хореография (Choreography):**
   - Сервисы общаются исключительно через события (например, Kafka). Нет центрального координатора.
   - *Плюсы:* Высокая автономность сервисов, нет единой точки отказа (SPOF).
   - *Минусы:* Сложно отследить общий статус Saga, риск циклических зависимостей, сложно отлаживать.
   - *Когда использовать:* Простые Saga с 2–3 участниками.

2. **Оркестрация (Orchestration):**
   - Есть центральный сервис-координатор (Orchestrator), который знает весь маршрут. Он отправляет команды участникам и слушает ответы.
   - *Плюсы:* Проще управлять логикой, легко добавить новый шаг, централизованный мониторинг и обработка ошибок.
   - *Минусы:* Orchestrator становится потенциальной единой точкой отказа и может стать "God Object".
   - *Когда использовать:* Сложные бизнес-процессы с 4+ участниками (например, оформление заказа: резерв склада → списание денег → доставка → уведомление).

**Важный нюанс:** Компенсационная транзакция не всегда является технической откаткой (rollback). Если на шаге "Отправка email" уже ушло письмо, компенсацией будет не "удаление письма из ящика", а "отправка письма с извинениями".

```java
// Saga:
public class OrderSaga {
    public void execute(Order order) {
        // 1. Reserve inventory
        inventoryService.reserve(order.getItems());
        
        // 2. Process payment
        paymentService.charge(order.getAmount());
        
        // 3. Ship order
        shippingService.ship(order);
        
        // Compensating (if step 3 fails):
        // - Refund payment
        // - Release inventory
    }
}
```

**Оркестрация:**
- **Orchestrator** — координирует saga
- **Participants** — сервисы

**Хореография:**
- **Events** — сервисы реагируют на события
- **No orchestrator** — distributed

### 20. Какие новые паттерны появились с микросервисами
**Паттерны:**
1. **API Gateway** — единая точка входа
2. **Circuit Breaker** — защита от cascade failure
3. **Saga** — distributed transaction
4. **Event Sourcing** — история изменений
5. **CQRS** — разделение чтения и записи
6. **Service Discovery** — поиск сервисов
7. **Load Balancer** — балансировка нагрузки
8. **Rate Limiter** — ограничение запросов
9. **Retry** — повторная попытка
10. **Bulkhead** — изоляция ресурсов

**Когда использовать:**
- **API Gateway** — multiple services
- **Circuit Breaker** — dependency failure
- **Saga** — distributed transaction
- **Event Sourcing** — audit, history
- **CQRS** — different read/write models

### 21. Что такое Chain of Responsibility и где он используется в Spring

**Chain of Responsibility (Цепочка обязанностей)** — поведенческий паттерн, позволяющий передавать запрос последовательно по цепочке обработчиков. Каждый обработчик решает, может ли он обработать запрос, и если да — обрабатывает, либо передаёт следующему.

**Где используется в Spring / Java:**
1. **Spring Security Filter Chain**: `SecurityFilterChain` — это классическая цепочка фильтров (`CorsFilter`, `CsrfFilter`, `UsernamePasswordAuthenticationFilter`, `AuthorizationFilter`). Запрос проходит через них по порядку.
2. **Servlet Filters**: стандартный механизм Java EE для предварительной и последующей обработки HTTP-запросов.
3. **Exception Handling**: цепочка `HandlerExceptionResolver` в Spring MVC пытается найти обработчик для выброшенного исключения.

**Преимущества:**
- Разделение ответственности: каждый обработчик делает одну вещь.
- Гибкость: можно динамически добавлять, удалять или менять порядок обработчиков (например, через `@Order` в Spring).

**Недостатки:**
- Запрос может остаться необработанным, если ни один обработчик его не примет.
- Сложность отладки длинных цепочек.
