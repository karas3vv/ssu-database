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
SELECT *
FROM guests
WHERE birth_date <= CURRENT_DATE - INTERVAL '25 years';

-- для проверки 
SELECT * FROM v_adult_guests;

-- 2.2 LOCAL CHECK OPTION
CREATE OR REPLACE VIEW v_adult_guests_local AS
SELECT * FROM v_adult_guests
WITH LOCAL CHECK OPTION;

-- для проверки 
SELECT * FROM v_adult_guests_local;

-- 2.3 CASCADED CHECK OPTION
CREATE OR REPLACE VIEW v_adult_guests_cascaded AS
SELECT * FROM v_adult_guests
WITH CASCADED CHECK OPTION;

-- для проверки 
SELECT * FROM v_adult_guests_cascaded;

-- тесты 
-- Попытка вставить гостя, который младше 25 лет
INSERT INTO v_adult_guests_cascaded (id, first_name, last_name, birth_date)
VALUES (99901, 'Baby', 'Guest', CURRENT_DATE - INTERVAL '5 years');
-- Ожидаем ошибку

-- Попытка вставить гостя, который бы прошёл LOCAL, 
-- но НЕ ПРОХОДИТ v_adult_guests (то есть младше 25)
INSERT INTO v_adult_guests_cascaded (id, first_name, last_name, birth_date)
VALUES (99902, 'Test', 'Guest', CURRENT_DATE - INTERVAL '10 years');
-- Ожидаем ошибку

-- верная вставка
INSERT INTO v_adult_guests_cascaded (id, first_name, last_name, birth_date)
VALUES (99903, 'Senior', 'Guest', CURRENT_DATE - INTERVAL '55 years');

DELETE FROM v_adult_guests_cascaded
WHERE id = 99903;

-- для проверки 
SELECT * FROM v_adult_guests_cascaded WHERE id = 99903;



-- Задача 3. Создание индексированного представления 

-- 3.1 материализованное view по продажам блюд
DROP MATERIALIZED VIEW IF EXISTS mv_dish_sales;
CREATE MATERIALIZED VIEW mv_dish_sales AS
SELECT 
    d.id,
    d.name,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.quantity * d.price), 0) AS total_revenue
FROM dishes d
LEFT JOIN order_items oi ON d.id = oi.dish_id
GROUP BY d.id;

-- 3.2 индекс на материализованное представление
DROP INDEX IF EXISTS idx_mv_dish_sales_revenue;
CREATE INDEX idx_mv_dish_sales_revenue ON mv_dish_sales(total_revenue);