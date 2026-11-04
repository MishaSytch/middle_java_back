-- 1. Очистка и создание таблиц
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    country_code CHAR(2) DEFAULT 'RU'
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    description TEXT
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'NEW', -- NEW, PAID, SHIPPED, CANCELLED
    total_amount DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    price_at_moment DECIMAL(10, 2) NOT NULL
);

-- 2. Генерация данных (Используем generate_series для скорости)

-- Вставляем 100,000 пользователей
INSERT INTO users (username, email, created_at, country_code)
SELECT 
    'user_' || g, 
    'user_' || g || '@example.com', 
    NOW() - (random() * INTERVAL '365 days'),
    CASE (g % 4) 
        WHEN 0 THEN 'RU' 
        WHEN 1 THEN 'US' 
        WHEN 2 THEN 'DE' 
        ELSE 'CN' 
    END
FROM generate_series(1, 100000) AS g;

-- Вставляем 50,000 товаров
INSERT INTO products (name, category, price, stock_quantity, description)
SELECT 
    'Product ' || g, 
    CASE (g % 5) 
        WHEN 0 THEN 'Electronics' 
        WHEN 1 THEN 'Books' 
        WHEN 2 THEN 'Clothing' 
        WHEN 3 THEN 'Home' 
        ELSE 'Toys' 
    END,
    (random() * 1000 + 10)::DECIMAL(10,2),
    (random() * 100)::INT,
    'Description for product ' || g
FROM generate_series(1, 50000) AS g;

-- Вставляем 500,000 заказов
-- Внимание: это может занять 10-30 секунд в зависимости от железа
INSERT INTO orders (user_id, status, total_amount, created_at)
SELECT 
    (random() * 99999 + 1)::INT, -- случайный user_id
    CASE (g % 4) 
        WHEN 0 THEN 'NEW' 
        WHEN 1 THEN 'PAID' 
        WHEN 2 THEN 'SHIPPED' 
        ELSE 'CANCELLED' 
    END,
    (random() * 5000 + 100)::DECIMAL(10,2),
    NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, 500000) AS g;

-- Вставляем ~1.5 миллиона позиций заказа (в среднем 3 товара на заказ)
INSERT INTO order_items (order_id, product_id, quantity, price_at_moment)
SELECT 
    o.id,
    (random() * 49999 + 1)::INT, -- случайный product_id
    (random() * 5 + 1)::INT,
    (random() * 1000 + 10)::DECIMAL(10,2)
FROM orders o
CROSS JOIN LATERAL generate_series(1, (random() * 2 + 1)::INT) AS item_num; -- 1-3 товара на заказ

-- 3. Обновление статистики для планировщика
ANALYZE;