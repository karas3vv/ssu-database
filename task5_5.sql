-- =============================================
-- ПОСТРОЕНИЕ И ТЕСТИРОВАНИЕ ИНДЕКСОВ ДЛЯ БАЗЫ ДАННЫХ РЕСТОРАНА
-- =============================================

-- Очистка существующих индексов (для чистоты тестирования)
DROP INDEX IF EXISTS idx_dishes_category;
DROP INDEX IF EXISTS idx_tables_table_number_unique;
DROP INDEX IF EXISTS idx_orders_guest_status;
DROP INDEX IF EXISTS idx_suppliers_lower_email;
DROP INDEX IF EXISTS idx_products_covering;
DROP INDEX IF EXISTS idx_orders_active;
DROP INDEX IF EXISTS idx_orders_completed_covering;
DROP INDEX IF EXISTS idx_suppliers_email_hash;
DROP INDEX IF EXISTS idx_orders_status_time;
DROP INDEX IF EXISTS idx_products_category_quantity;
DROP INDEX IF EXISTS idx_products_expiry_date;
DROP INDEX IF EXISTS idx_deliveries_supplier_cost;
DROP INDEX IF EXISTS idx_guests_total_orders;
DROP INDEX IF EXISTS idx_products_expiry_quantity;
DROP INDEX IF EXISTS idx_order_items_dish_quantity;
DROP INDEX IF EXISTS idx_suppliers_phone_func;
DROP INDEX IF EXISTS idx_orders_time_analysis;
DROP INDEX IF EXISTS idx_orders_date_part;
DROP INDEX IF EXISTS idx_suppliers_id_name;
DROP INDEX IF EXISTS idx_orders_guest_status_completed;
DROP INDEX IF EXISTS idx_delivery_items_quantity;
DROP INDEX IF EXISTS idx_dishes_composition_quantity;
DROP INDEX IF EXISTS idx_bookings_date_guest;
DROP INDEX IF EXISTS idx_orders_date_guest;
DROP INDEX IF EXISTS idx_products_name_pattern;
DROP INDEX IF EXISTS idx_guests_id;
DROP INDEX IF EXISTS idx_waiters_id;
DROP INDEX IF EXISTS idx_tables_id;

-- =============================================
-- 1. B-TREE ИНДЕКСЫ
-- =============================================

-- 1.1 Простой B-Tree индекс
CREATE INDEX idx_dishes_category ON dishes(category);

-- Тестирование простого B-Tree индекса
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM dishes WHERE category = 'Горячее';

-- 1.2 Уникальный B-Tree индекс
CREATE UNIQUE INDEX idx_tables_table_number_unique ON tables(table_number);

-- Тестирование уникального B-Tree индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM tables WHERE table_number = 5;

-- 1.3 Составной B-Tree индекс
CREATE INDEX idx_orders_guest_status ON orders(guest_id, status);

-- Тестирование составного B-Tree индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders 
WHERE guest_id = 1 AND status = 'завершен';

-- 1.4 Индекс с использованием выражений
CREATE INDEX idx_suppliers_lower_email ON suppliers(LOWER(email));

-- Тестирование индекса с выражениями
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM suppliers 
WHERE LOWER(email) = 'info@freshfood.ru';

-- 1.5 Покрывающий индекс
CREATE INDEX idx_products_covering ON products(category) 
INCLUDE (name, weight, quantity);

-- Тестирование покрывающего индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT name, weight, quantity FROM products 
WHERE category = 'Овощи';

-- 1.6 Частичный индекс
CREATE INDEX idx_orders_active ON orders(guest_id) 
WHERE status = 'в процессе';

-- Тестирование частичного индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders 
WHERE status = 'в процессе' AND guest_id = 3;

-- 1.7 Частичный покрывающий индекс
CREATE INDEX idx_orders_completed_covering ON orders(status) 
INCLUDE (guest_id, total_amount)
WHERE status = 'завершен';

-- Тестирование частичного покрывающего индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, guest_id, total_amount FROM orders 
WHERE status = 'завершен';

-- =============================================
-- 2. HASH ИНДЕКСЫ
-- =============================================

-- 2.1 Простой Hash индекс
CREATE INDEX idx_suppliers_email_hash ON suppliers USING HASH (email);

-- Тестирование Hash индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM suppliers WHERE email = 'info@freshfood.ru';

-- =============================================
-- 3. ТЕСТИРОВАНИЕ ДЛЯ РАЗЛИЧНЫХ ТИПОВ ЗАПРОСОВ
-- =============================================

-- 3.1 Запросы с соединениями таблиц
CREATE INDEX idx_orders_status_time ON orders(status, order_time);
CREATE INDEX idx_guests_id ON guests(id);
CREATE INDEX idx_waiters_id ON waiters(id);
CREATE INDEX idx_tables_id ON tables(id);

-- Тестирование JOIN запросов
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    o.id as order_id,
    g.last_name as guest_name,
    w.last_name as waiter_name,
    t.table_number,
    o.total_amount
FROM orders o
INNER JOIN guests g ON o.guest_id = g.id
INNER JOIN waiters w ON o.waiter_id = w.id
INNER JOIN tables t ON o.table_id = t.id
WHERE o.status = 'завершен'
  AND o.order_time >= '2024-02-01';

-- 3.2 Фильтрация с предикатами
CREATE INDEX idx_products_category_quantity ON products(category, quantity);
CREATE INDEX idx_products_expiry_date ON products(expiry_date);
CREATE INDEX idx_products_name_pattern ON products(name);

-- Тестирование фильтрации с предикатами
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM products 
WHERE category IN ('Овощи', 'Молочные продукты')
  AND quantity BETWEEN 50 AND 200
  AND expiry_date BETWEEN '2024-02-01' AND '2024-03-01'
  AND name LIKE 'К%';

-- 3.3 Функции для работы со строками
CREATE INDEX idx_suppliers_phone_func ON suppliers 
(OVERLAY(phone PLACING 'XXX' FROM 1 FOR 7));

-- Тестирование строковых функций
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    last_name,
    first_name,
    REPLACE(phone, '+7-495-', '') as short_phone,
    SUBSTRING(email FROM '@(.*)$') as domain
FROM suppliers 
WHERE OVERLAY(phone PLACING 'XXX' FROM 1 FOR 7) LIKE '%123%';

-- 3.4 Функции даты и времени
CREATE INDEX idx_orders_time_analysis ON orders(order_time);
CREATE INDEX idx_orders_date_part ON orders(DATE_PART('dow', order_time));

-- Тестирование функций даты и времени
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    DATE_PART('hour', order_time) as order_hour,
    COUNT(*) as orders_count,
    AVG(total_amount) as avg_amount
FROM orders 
WHERE order_time >= CURRENT_DATE - INTERVAL '7 days'
  AND DATE_PART('dow', order_time) IN (5, 6)
GROUP BY DATE_PART('hour', order_time)
HAVING COUNT(*) > 1;

-- 3.5 Агрегатные функции и GROUP BY
CREATE INDEX idx_deliveries_supplier_cost ON deliveries(supplier_id, cost);
CREATE INDEX idx_suppliers_id_name ON suppliers(id, name);

-- Тестирование агрегатных функций
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    s.name as supplier_name,
    COUNT(d.id) as delivery_count,
    SUM(d.cost) as total_cost,
    AVG(d.cost) as avg_delivery_cost
FROM suppliers s
INNER JOIN deliveries d ON s.id = d.supplier_id
GROUP BY s.id, s.name
HAVING SUM(d.cost) > 10000 AND COUNT(d.id) >= 2;

-- 3.6 Вложенные запросы
CREATE INDEX idx_guests_total_orders ON guests(total_orders);
CREATE INDEX idx_orders_guest_status_completed ON orders(guest_id) 
WHERE status = 'завершен';

-- Тестирование вложенных запросов
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    last_name,
    first_name,
    total_orders
FROM guests g
WHERE total_orders > (
    SELECT AVG(total_orders) 
    FROM guests 
    WHERE total_orders IS NOT NULL
)
AND EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.guest_id = g.id AND o.status = 'завершен'
);

-- 3.7 UNION и INTERSECT
CREATE INDEX idx_delivery_items_quantity ON delivery_items(quantity);
CREATE INDEX idx_dishes_composition_quantity ON dishes_composition(quantity);
CREATE INDEX idx_bookings_date_guest ON bookings(booking_date, guest_id);
CREATE INDEX idx_orders_date_guest ON orders((order_time::DATE), guest_id);

-- Тестирование UNION
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id FROM delivery_items
WHERE quantity > 100
UNION
SELECT product_id FROM dishes_composition
WHERE quantity > 0.1;

-- Тестирование INTERSECT
EXPLAIN (ANALYZE, BUFFERS)
SELECT guest_id FROM bookings
WHERE booking_date = '2024-02-01'
INTERSECT
SELECT guest_id FROM orders
WHERE order_time::DATE = '2024-02-01';

-- =============================================
-- 4. ДОПОЛНИТЕЛЬНЫЕ СПЕЦИАЛИЗИРОВАННЫЕ ИНДЕКСЫ
-- =============================================

-- 4.1 Индекс для поиска просроченных продуктов
CREATE INDEX idx_products_expiry_quantity ON products(expiry_date, quantity) 
WHERE quantity > 0;

-- Тестирование поиска просроченных продуктов
EXPLAIN (ANALYZE, BUFFERS)
SELECT name, expiry_date, quantity
FROM products 
WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
  AND quantity > 0;

-- 4.2 Индекс для анализа популярности блюд
CREATE INDEX idx_order_items_dish_quantity ON order_items(dish_id, quantity);

-- Тестирование анализа популярности блюд
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    d.name,
    d.category,
    SUM(oi.quantity) as total_ordered,
    COUNT(DISTINCT o.id) as order_count
FROM dishes d
INNER JOIN order_items oi ON d.id = oi.dish_id
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.order_time >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.id, d.name, d.category
HAVING SUM(oi.quantity) > 5
ORDER BY total_ordered DESC;

-- =============================================
-- 5. СВОДКА СОЗДАННЫХ ИНДЕКСОВ
-- =============================================

SELECT 
    schemaname,
    indexname,
    tablename,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- =============================================
-- 6. АНАЛИЗ ЭФФЕКТИВНОСТИ ИНДЕКСОВ
-- =============================================

-- Статистика использования индексов
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_all_indexes 
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY idx_scan DESC;

-- Размеры индексов
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(schemaname||'.'||indexname)) as index_size
FROM pg_indexes 
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY pg_relation_size(schemaname||'.'||indexname) DESC;

-- =============================================
-- 7. РЕКОМЕНДАЦИИ ПО ОПТИМИЗАЦИИ
-- =============================================

/*
РЕКОМЕНДАЦИИ:

1. ДЛЯ ЧАСТЫХ ПОИСКОВ: B-Tree индексы на часто фильтруемых полях
   - category в dishes и products
   - status в orders
   - expiry_date в products

2. ДЛЯ ТОЧЕЧНЫХ ПОИСКОВ: Hash индексы на уникальных полях
   - email в suppliers
   - table_number в tables

3. СОСТАВНЫЕ ИНДЕКСЫ: Для сложных запросов с несколькими условиями
   - guest_id + status в orders
   - category + quantity в products

4. ПОКРЫВАЮЩИЕ ИНДЕКСЫ: Для запросов, выбирающих ограниченный набор полей
   - INCLUDE clause для часто запрашиваемых полей

5. ЧАСТИЧНЫЕ ИНДЕКСЫ: Для работы с подмножествами данных
   - WHERE clause для фильтрации по статусам

6. МОНИТОРИНГ: Регулярно проверяйте pg_stat_all_indexes для анализа использования
*/

-- Проверка существующих индексов (финальная проверка)
SELECT 
    'Всего создано индексов: ' || COUNT(*) as summary
FROM pg_indexes 
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%';