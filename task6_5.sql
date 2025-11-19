-- Задача 1. Создание представлений

-- 1.1 доходы по официантам
CREATE OR REPLACE VIEW v_waiters_income AS
SELECT 
    w.id,
    w.last_name,
    w.first_name,
    COUNT(o.id) AS orders_count,
    COALESCE(SUM(o.total_amount), 0) AS total_income,
    AVG(o.total_amount) AS avg_order_amount
FROM waiters w
LEFT JOIN orders o ON w.id = o.waiter_id
GROUP BY w.id;

-- для проверки
SELECT * FROM v_waiters_income;

-- 1.2 популярность блюд 
CREATE OR REPLACE VIEW v_dish_popularity AS
SELECT 
    d.id,
    d.name,
    COALESCE(SUM(oi.quantity), 0) AS total_ordered
FROM dishes d
LEFT JOIN order_items oi ON d.id = oi.dish_id
GROUP BY d.id;

-- для проверки 
SELECT * FROM v_dish_popularity ORDER BY total_ordered DESC;

-- 1.3 траты гостей 
CREATE OR REPLACE VIEW v_guests_expenses AS
SELECT 
    g.id,
    g.last_name,
    g.first_name,
    COALESCE(SUM(o.total_amount), 0) AS total_spent,
    COUNT(o.id) AS orders_count
FROM guests g
LEFT JOIN orders o ON g.id = o.guest_id
GROUP BY g.id;

-- для проверки 
SELECT * FROM v_guests_expenses ORDER BY total_spent DESC;



-- Задача 2. Создание обновляемого представления

-- 2.1 основное view (гости старше 25 лет)
CREATE OR REPLACE VIEW v_adult_guests AS
SELECT * FROM guests
WHERE birth_date <= (CURRENT_DATE - INTERVAL '25 years');

-- для проверки 
SELECT * FROM v_adult_guests;

-- 2.2 LOCAL CHECK OPTION (гости моложе 60 лет)
CREATE OR REPLACE VIEW v_adult_guests_local AS
SELECT * FROM v_adult_guests
WHERE birth_date >= (CURRENT_DATE - INTERVAL '60 years')
WITH LOCAL CHECK OPTION;

-- тесты 
-- успешно - проходит проверку v_adult_guests_local (возраст между 25 и 60)
INSERT INTO v_adult_guests_local (id, first_name, last_name, birth_date)
VALUES (99901, 'Иван', 'Петров', CURRENT_DATE - INTERVAL '30 years');

-- должен ОШИБИТЬСЯ (ибо возраст 20 лет - младше 25)
-- LOCAL проверяет только "младше 60", но базовое представление отфильтрует эту запись
-- однако с LOCAL CHECK OPTION эта вставка МОЖЕТ пройти
INSERT INTO v_adult_guests_local (id, first_name, last_name, birth_date)
VALUES (99902, 'Мария', 'Иванова', CURRENT_DATE - INTERVAL '20 years');

-- ошибка - НЕ проходит проверку v_adult_guests_local (старше 60 лет)
INSERT INTO v_adult_guests_local (id, first_name, last_name, birth_date)
VALUES (99903, 'Сергей', 'Сидоров', CURRENT_DATE - INTERVAL '65 years');

-- для проверки
SELECT * FROM v_adult_guests_local WHERE id BETWEEN 99901 AND 99905;
SELECT * FROM guests WHERE id = 99902;


-- 2.3 CASCADED CHECK OPTION (гости старше 25 лет с каскадной проверкой)
CREATE OR REPLACE VIEW v_adult_guests_cascaded AS
SELECT * FROM v_adult_guests
WHERE birth_date >= (CURRENT_DATE - INTERVAL '60 years')
WITH CASCADED CHECK OPTION;

-- тесты
-- ошибка - НЕ проходит проверку базового представления v_adult_guests (старше 60 лет)
INSERT INTO v_adult_guests_cascaded (id, first_name, last_name, birth_date)
VALUES (99904, 'Дмитрий', 'Волков', CURRENT_DATE - INTERVAL '65 years');

-- успешно - проходит все проверки (возраст между 25 и 60 лет)
INSERT INTO v_adult_guests_cascaded (id, first_name, last_name, birth_date)
VALUES (99905, 'Андрей', 'Морозов', CURRENT_DATE - INTERVAL '45 years');

-- для проверки 
SELECT * FROM v_adult_guests_cascaded WHERE id BETWEEN 99901 AND 99905;

-- очистка тестовых данных
DELETE FROM guests WHERE id BETWEEN 99901 AND 99905;
DROP VIEW v_adult_guests_cascaded;
DROP VIEW v_adult_guests_local;



-- Задача 3. Создание индексированного представления 

-- 3.1 материализованное view по продажам блюд
DROP MATERIALIZED VIEW IF EXISTS mv_dish_sales;
CREATE MATERIALIZED VIEW mv_dish_sales AS
SELECT 
    d.id, d.name,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.quantity * d.price), 0) AS total_revenue
FROM dishes d
LEFT JOIN order_items oi ON d.id = oi.dish_id
GROUP BY d.id;

-- 3.2 индекс на материализованное представление
DROP INDEX IF EXISTS idx_mv_dish_sales_revenue;
CREATE INDEX idx_mv_dish_sales_revenue ON mv_dish_sales(total_revenue);

SET enable_seqscan = OFF;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM mv_dish_sales
WHERE total_revenue > 10000
ORDER BY total_revenue DESC;
