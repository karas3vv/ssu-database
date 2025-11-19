-- 1. B-TREE ИНДЕКСЫ

-- 1.1 Простой индекс
-- Для поиска гостей по фамилии
DROP INDEX IF EXISTS idx_guests_lastname;
CREATE INDEX idx_guests_lastname ON guests USING BTREE (last_name);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT last_name FROM guests WHERE last_name = 'Иванов';


-- 1.2 Уникальный индекс
-- Поиск гостя по id 
DROP INDEX IF EXISTS idx_guests_id_unique;
CREATE UNIQUE INDEX idx_guests_id_unique 
ON guests USING BTREE (id)
INCLUDE (first_name, last_name, birth_date);

SET enable_indexscan = ON;
SET enable_bitmapscan = ON;
SET enable_indexonlyscan = ON;
SET enable_seqscan = OFF;



EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT id, first_name, last_name, birth_date 
FROM guests 
WHERE id = 100;


-- 1.3 Составной индекс
-- Для поиска заказов по гостю и времени
DROP INDEX IF EXISTS idx_orders_guest_time;
CREATE INDEX idx_orders_guest_time ON orders USING BTREE (guest_id, order_time);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, order_time FROM orders WHERE guest_id = 100 AND order_time >= '2025-11-01';


-- 1.4 Индекс с выражением
-- Извлечение года из даты рождения гостя
DROP INDEX IF EXISTS idx_guests_birth_year;
CREATE INDEX idx_guests_birth_year ON guests USING BTREE (DATE_PART('year', birth_date));

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT birth_date FROM guests WHERE DATE_PART('year', birth_date) = 1990;


-- 1.5 Покрывающий индекс (INCLUDE)
-- Покрывает: SELECT guest_id, total_amount FROM orders WHERE order_time >= ... AND order_time < ...
DROP INDEX IF EXISTS idx_orders_time_covering;
CREATE INDEX idx_orders_time_covering ON orders USING BTREE (order_time) 
INCLUDE (guest_id, table_id, waiter_id, total_amount, status);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM orders WHERE order_time >= '2025-11-01' AND order_time < '2025-12-01';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM orders WHERE order_time = '2025-11-01';


-- 1.6 Частичный индекс
-- Только оплаченные заказы
DROP INDEX IF EXISTS idx_orders_paid;
CREATE INDEX idx_orders_paid ON orders USING BTREE (guest_id) 
WHERE status = 'paid'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM orders WHERE status = 'paid' AND guest_id = 100;


-- 1.7 Частичный покрывающий индекс
-- Покрывает запросы по оплаченным заказам с полной информацией
DROP INDEX IF EXISTS idx_orders_paid_partial;
CREATE INDEX idx_orders_paid_covering ON orders (order_time) 
INCLUDE (guest_id, table_id, total_amount) 
WHERE status = 'paid';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, table_id, order_time, total_amount 
FROM orders 
WHERE status = 'paid' AND order_time >= '2025-10-01' AND order_time < '2025-10-15';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, table_id, order_time, total_amount 
FROM orders 
WHERE status = 'paid' AND order_time = '2025-10-01';

-- 2. HASH ИНДЕКСЫ

-- 2.1 Простой Hash индекс
-- Для точного поиска по фамилии
DROP INDEX IF EXISTS idx_guests_lastname_hash;
CREATE INDEX idx_guests_lastname_hash ON guests USING HASH (last_name);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT last_name FROM guests WHERE last_name = 'Петров';

-- Для поиска по статусу заказа
SET enable_seqscan = OFF;
DROP INDEX IF EXISTS idx_orders_status_hash;
CREATE INDEX idx_orders_status_hash ON orders USING HASH (status);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT status FROM orders WHERE status = 'paid';

-- 2.2 Индекс Hash с выражением
-- Поиск по году рождения гостя
DROP INDEX IF EXISTS idx_guests_birth_year_hash;
CREATE INDEX idx_guests_birth_year_hash ON guests USING HASH (DATE_PART('year', birth_date));

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT birth_date FROM guests WHERE DATE_PART('year', birth_date) = 1990;

-- 2.3 Частичный Hash индекс
-- Hash индекс только для оплаченных заказов
DROP INDEX IF EXISTS idx_orders_paid_status_hash;
CREATE INDEX idx_orders_paid_status_hash ON orders USING HASH (guest_id) 
WHERE status = 'paid';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT status, guest_id FROM orders WHERE status = 'paid' AND guest_id = 100;

-- Hash индекс для доступных столов
DROP INDEX IF EXISTS idx_tables_available_hash;
CREATE INDEX idx_tables_available_hash ON tables USING HASH (table_number) 
WHERE status = 'available';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT status, table_number FROM tables WHERE status = 'available' AND table_number = 5;

-- ЗАПРОСЫ ДЛЯ ДЕМОНСТРАЦИИ ИНДЕКСОВ

-- 1. Запросы с соединениями таблиц
-- JOIN с использованием составного индекса
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT g.last_name, g.first_name, o.order_time, o.total_amount
FROM guests g
JOIN orders o ON g.id = o.guest_id
WHERE g.last_name = 'Иванов' AND o.order_time >= '2025-11-01';
-- Использует: idx_guests_lastname, idx_orders_guest_time

-- JOIN с покрывающим индексом
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT d.name, d.price, oi.quantity
FROM dishes d
JOIN order_items oi ON d.id = oi.dish_id
WHERE d.category = 'Main';
-- Использует: idx_dishes_category_covering


-- 2. Фильтрация с предикатами
-- EXISTS
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, status FROM guests g
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.guest_id = g.id AND o.status = 'paid'
);
-- Использует: idx_orders_paid_status_hash

-- IN
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT category FROM dishes
WHERE category IN ('Main', 'Dessert', 'Starter');
-- Использует: idx_dishes_category_covering

-- BETWEEN
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT order_time FROM orders
WHERE order_time BETWEEN '2025-11-01' AND '2025-11-30';
-- Использует: idx_orders_time_covering

-- LIKE / ILIKE
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT name FROM dishes
WHERE LOWER(name) LIKE '%салат%';
-- Использует: idx_dishes_name_lower

-- ALL / ANY
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT price, category FROM dishes
WHERE price > ALL (SELECT price FROM dishes WHERE category = 'Starter');

-- SOME/ANY
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT price, category FROM dishes
WHERE price > ANY (SELECT price FROM dishes WHERE category = 'Dessert');


-- 3. Функции для работы со строками
-- REPLACE
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT id, REPLACE(name, 'Салат', 'Блюдо') AS modified_name
FROM dishes
WHERE LOWER(name) LIKE '%салат%';
-- Использует: idx_dishes_name_lower

-- SUBSTRING
DROP INDEX IF EXISTS idx_dishes_name_substr;
CREATE INDEX idx_dishes_name_substr ON dishes (SUBSTRING(name, 1, 5));

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT name FROM dishes
WHERE SUBSTRING(name, 1, 5) = 'Цезар';
-- Использует: idx_dishes_name_substr

-- OVERLAY
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT id, OVERLAY(name PLACING '***' FROM 1 FOR 3) AS masked_name
FROM dishes
WHERE category = 'Main';
-- Использует: idx_dishes_category_covering


-- 4. Функции даты и времени
-- DATE_PART
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT birth_date FROM guests
WHERE DATE_PART('year', birth_date) = 1990;
-- Использует: idx_guests_birth_year или idx_guests_birth_year_hash

-- Арифметические операции с датами
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT order_time FROM orders
WHERE order_time >= CURRENT_TIMESTAMP - INTERVAL '7 days';
-- Использует: idx_orders_time_covering

-- DATE_TRUNC с временной зоной
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT date_trunc('hour', order_time AT TIME ZONE 'Europe/Moscow') AS order_hour,
       COUNT(*) as orders_count
FROM orders
WHERE order_time >= '2025-11-01'
GROUP BY order_hour;
-- Использует: idx_orders_ordertime_hour

-- CURRENT_TIMESTAMP с уточнением временной зоны
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT order_time FROM orders
WHERE order_time >= CURRENT_TIMESTAMP AT TIME ZONE 'UTC' - INTERVAL '1 day';


-- 5. Агрегатные функции и GROUP BY
-- Агрегация с частичным покрывающим индексом
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
FROM orders
WHERE status = 'paid'
GROUP BY guest_id
HAVING SUM(total_amount) > 5000;
-- Использует: idx_orders_paid_covering

-- GROUP BY с DATE_TRUNC
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT date_trunc('day', order_time) as order_day,
       AVG(total_amount) as avg_amount
FROM orders
WHERE order_time >= '2025-11-01'
GROUP BY order_day
HAVING AVG(total_amount) > 1000;
-- Использует: idx_orders_time_covering


-- 6. Вложенные запросы
-- Подзапрос с частичным индексом
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT id, guest_id, status, total_amount FROM guests
WHERE id IN (
    SELECT DISTINCT guest_id 
    FROM orders 
    WHERE status = 'paid' AND total_amount > 3000
);
-- Использует: idx_orders_paid_covering

-- Коррелированный подзапрос
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT g.last_name, g.first_name,
       (SELECT COUNT(*) FROM orders o 
        WHERE o.guest_id = g.id AND o.status = 'paid') as paid_orders
FROM guests g
WHERE total_orders > 10;
-- Использует: idx_orders_paid_status_hash


-- 7. UNION и INTERSECT
-- UNION с покрывающими индексами
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT name, price FROM dishes WHERE category = 'Main'
UNION
SELECT name, price FROM dishes WHERE category = 'Dessert';
-- Использует: idx_dishes_category_covering

-- INTERSECT с частичными индексами
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id FROM orders WHERE status = 'paid' AND order_time >= '2025-11-01'
INTERSECT
SELECT guest_id FROM orders WHERE status = 'paid' AND total_amount > 2000;
-- Использует: idx_orders_paid_covering

-- СРАВНЕНИЕ: ЧАСТИЧНЫЙ И ЧАСТИЧНЫЙ ПОКРЫВАЮЩИЙ

-- 1. Частичный индекс (только индексирует условие)
DROP INDEX IF EXISTS idx_orders_paid_partial;
CREATE INDEX idx_orders_paid_partial ON orders (order_time) 
WHERE status = 'paid';

-- Запрос потребует обращения к таблице для получения других полей
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, total_amount FROM orders 
WHERE status = 'paid' AND order_time >= '2025-11-01';
-- План: Index Scan + обращение к таблице (heap fetch)
-- Обратите внимание на "Heap Fetches" > 0

-- 2. Частичный покрывающий индекс
DROP INDEX IF EXISTS idx_orders_paid_partial;
DROP INDEX IF EXISTS idx_orders_paid_partial_covering;
CREATE INDEX idx_orders_paid_partial_covering ON orders (order_time) 
INCLUDE (guest_id, total_amount) 
WHERE status = 'paid';

-- Тот же запрос будет выполнен ТОЛЬКО по индексу (Index Only Scan)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT guest_id, total_amount FROM orders 
WHERE status = 'paid' AND order_time >= '2025-11-01';
-- План: Index Only Scan (без обращения к таблице!)
-- "Heap Fetches": 0 или минимальное значение
