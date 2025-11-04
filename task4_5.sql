-- 1. Соединения (JOINS)


-- 1.1 INNER JOIN: показать позиции заказов с названиями блюд и суммой по позиции
SELECT oi.order_id,
       d.name AS dish_name,
       oi.quantity,
       d.price,
       (oi.quantity * d.price) AS line_total
FROM order_items oi
INNER JOIN dishes d ON oi.dish_id = d.id
ORDER BY oi.order_id, d.name;

-- 1.2 LEFT JOIN: все заказы + имя гостя (если гость удалён, показать NULL)
SELECT o.id AS order_id,
       g.last_name || ' ' || g.first_name AS guest_name,
       o.total_amount
FROM orders o
LEFT JOIN guests g ON o.guest_id = g.id
ORDER BY o.id;

-- 1.3 RIGHT JOIN: показать всех официантов и их заказы (если у официанта нет заказов, показать NULL)
SELECT w.id AS waiter_id,
       w.last_name || ' ' || w.first_name AS waiter_name,
       o.id AS order_id,
       o.total_amount
FROM orders o
RIGHT JOIN waiters w ON o.waiter_id = w.id
ORDER BY w.id;

-- 1.4 FULL JOIN: объединить поставки и хранения (показывает записи, которые есть в одной из таблиц)
SELECT COALESCE(d.id, s.id) AS rec_id,
       d.delivery_date,
       s.warehouse_number,
       d.supplier_id AS delivery_supplier,
       s.supplier_id AS storage_supplier
FROM deliveries d
FULL JOIN storage s ON d.product_id = s.product_id
LIMIT 50;

-- 1.5 CROSS JOIN: сочетаем 2 таблицы для генерации возможных пар
-- Пример: все сочетания блюд и столов (полезно для моделирования размещения блюд/подачи)
SELECT d.id AS dish_id, d.name AS dish_name, t.id AS table_id, t.table_number
FROM dishes d
CROSS JOIN tables t
ORDER BY d.id, t.table_number
LIMIT 50;

-- 1.6 CROSS JOIN LATERAL: для каждого заказа вернуть одну «первую» позицию (если есть)
SELECT o.id AS order_id,
       o.order_time,
       fi.dish_name,
       fi.qty
FROM orders o
CROSS JOIN LATERAL (
    SELECT d.name AS dish_name, oi.quantity AS qty
    FROM order_items oi
    JOIN dishes d ON oi.dish_id = d.id
    WHERE oi.order_id = o.id
    ORDER BY oi.quantity DESC NULLS LAST
    LIMIT 1
) fi
ORDER BY o.id;

-- 1.7 Самосоединение (self-join): найти пары гостей с одинаковой фамилией (возможные родственники)
SELECT g1.id AS guest1_id, g1.last_name, g1.first_name AS guest1_first,
       g2.id AS guest2_id, g2.first_name AS guest2_first
FROM guests g1
JOIN guests g2 ON g1.last_name = g2.last_name AND g1.id < g2.id
ORDER BY g1.last_name;


-- 2. Операции над множествами


-- 2.1 UNION: список уникальных имён поставщиков и гостей (без дубликатов)
SELECT name AS person_or_supplier FROM suppliers
UNIONECT oi.order_id,
       d.name AS dish_name,
       oi.quantity,
       d.price,
       (oi.quantity * d.price) AS line_total
FROM order_items oi
SELECT last_name || ' ' || first_name FROM guests;

-- 2.2 UNION ALL: тот же список, но с сохранением дубликатов
SELECT name AS person_or_supplier FROM suppliers
UNION ALL
SELECT last_name || ' ' || first_name FROM guests;

-- 2.3 EXCEPT: продукты, которые есть в products, но никогда использовались в блюдах (products \ dishes_composition)
SELECT p.id, p.name
FROM products p
EXCEPT
SELECT p2.id, p2.name
FROM products p2
JOIN dishes_composition dc ON dc.product_id = p2.id;

-- 2.4 INTERSECT: продукты, которые были поставлены и использованы в рецептах (пересечение deliveries и dishes_composition по product_id)
SELECT DISTINCT product_id FROM delivery_items
INTERSECT
SELECT DISTINCT product_id FROM dishes_composition;


-- 3. Предикаты / фильтры


-- 3.1 EXISTS: найти заказы, по которым есть платеж
SELECT o.id, o.order_time, o.total_amount
FROM orders o
WHERE EXISTS (
    SELECT 1 FROM payments p WHERE p.order_id = o.id
);

-- 3.2 IN: блюда, которые встречаются в конкретном наборе категорий
SELECT * FROM dishes
WHERE category IN ('Горячее', 'Салат');

-- 3.3 ALL / ANY (SOME): примеры сравнения цен
-- Найти блюда дороже, чем любые десерты (если есть десерты)
SELECT d.* FROM dishes d
WHERE d.price > ALL (SELECT price FROM dishes WHERE category = 'Десерт');

-- Найти блюда, цена которых больше, чем цена какого-либо блюда категории 'Салат'
SELECT d.* FROM dishes d
WHERE d.price > ANY (SELECT price FROM dishes WHERE category = 'Салат');

-- 3.4 BETWEEN: бронирования в диапазоне дат
SELECT * FROM bookings
WHERE booking_date BETWEEN '2024-01-01' AND '2024-02-01';

-- 3.5 LIKE и ILIKE: поиск блюд по шаблону (чувствительный и нечувствительный к регистру)
SELECT * FROM dishes WHERE name ILIKE '%паста%' OR name ILIKE '%салат%';
SELECT * FROM dishes WHERE name LIKE '%борщ%' OR name ILIKE '%том%';


-- 4. CASE выражения


-- 4.1 CASE: категоризация суммы заказа
SELECT id AS order_id,
       total_amount,
       CASE
           WHEN total_amount IS NULL THEN 'no amount'
           WHEN total_amount < 500 THEN 'small'
           WHEN total_amount BETWEEN 500 AND 1000 THEN 'medium'
           ELSE 'large'
       END AS amount_category
FROM orders
ORDER BY total_amount NULLS LAST;


-- 5. Встроенные функции (CAST, COALESCE, NULLIF, GREATEST, LEAST)


-- 5.1 CAST / :: — показать amount как текст и обратно
SELECT id AS payment_id,
       amount,
       amount::text AS amount_text,
       CAST(amount AS numeric(10,2)) AS amount_2dec
FROM payments;

-- 5.2 COALESCE и NULLIF — показать фамилию гостя, если middle_name пустое, подставить '-'
SELECT id, last_name, first_name,
       COALESCE(NULLIF(middle_name, ''), '-') AS middle_or_dash
FROM guests;

-- 5.3 GREATEST / LEAST — сравнить сумму заказа и сумму платежа (если есть)
-- используем LEFT JOIN, чтобы учесть заказы без платежа
SELECT o.id AS order_id,
       o.total_amount,
       p.amount AS payment_amount,
       GREATEST(COALESCE(o.total_amount,0), COALESCE(p.amount,0)) AS max_amount,
       LEAST(COALESCE(o.total_amount,0), COALESCE(p.amount,0)) AS min_amount
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
ORDER BY o.id;


-- 6. Функции для работы со строками


-- 6.1 LENGTH, LOWER, UPPER, BTRIM, LTRIM
SELECT name,
       LENGTH(name) AS name_len,
       LOWER(name) AS name_lower,
       UPPER(name) AS name_upper,
       BTRIM(name) AS name_trimmed
FROM dishes
LIMIT 10;

-- 6.2 CHR(n) — получить символ по коду (пример: 65 -> 'A')
SELECT CHR(65) AS letter_A;

-- 6.3 STRPOS / POSITION — найти позицию подстроки
SELECT name, STRPOS(name, 'лор') AS strpos_example, POSITION('ца' IN name) AS position_example
FROM dishes
LIMIT 10;

-- 6.4 SUBSTRING
SELECT name, SUBSTRING(name FROM 1 FOR 6) AS first_6_chars FROM dishes;

-- 6.5 OVERLAY (аналог STUFF в SQL Server) — заменить часть строки
-- Пример: заменить первые 5 символов названия блюда на 'XX'
SELECT name,
       OVERLAY(name PLACING 'XX' FROM 1 FOR 5) AS name_with_overlay
FROM dishes;

-- 6.6 REPLACE — заменить подстроку
SELECT name, REPLACE(name, 'Пицца', 'Pizza') AS replaced_name FROM dishes;

-- 6.7 Эмуляция STUFF (вставка/удаление) через OVERLAY: вставить 'NEW' в позицию 3, удаляя 2 символа
-- (STUFF(name,3,2,'NEW') эквивалент)
SELECT name,
       OVERLAY(name PLACING 'NEW' FROM 3 FOR 2) AS stuff_emulation
FROM dishes;


-- 7. Функции даты/времени


-- 7.1 NOW, CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP, LOCALTIMESTAMP
SELECT NOW() AS now_full,
       CURRENT_DATE AS today,
       CURRENT_TIME AS cur_time,
       CURRENT_TIMESTAMP AS cur_ts,
       LOCALTIMESTAMP AS local_ts;

-- 7.2 AGE() и DATE_PART/EXTRACT
-- Возраст гостя (years)
SELECT id, last_name, first_name,
       birth_date,
       AGE(CURRENT_DATE, birth_date) AS age_interval,
       DATE_PART('year', AGE(CURRENT_DATE, birth_date)) AS age_years
FROM guests;

-- 7.3 EXTRACT с timestamp из orders
SELECT id AS order_id, order_time,
       EXTRACT(YEAR FROM order_time) AS order_year,
       EXTRACT(MONTH FROM order_time) AS order_month
FROM orders
WHERE order_time IS NOT NULL
LIMIT 20;


-- 8. Агрегаты, GROUP BY, HAVING


-- 8.1 Общая выручка по официантам (sum), средняя сумма заказа и количество заказов
SELECT w.id AS waiter_id,
       w.last_name || ' ' || w.first_name AS waiter_name,
       COUNT(o.id) AS orders_count,
       SUM(o.total_amount) AS total_sales,
       AVG(o.total_amount) AS avg_order
FROM waiters w
LEFT JOIN orders o ON o.waiter_id = w.id
GROUP BY w.id, waiter_name
ORDER BY total_sales DESC NULLS LAST;

-- 8.2 HAVING: официанты с общей выручкой больше 1000

SELECT w.id, w.last_name || ' ' || w.first_name AS waiter_name, SUM(o.total_amount) AS total_sales
FROM waiters w
JOIN orders o ON o.waiter_id = w.id
GROUP BY w.id, waiter_name
HAVING SUM(o.total_amount) > 1000
ORDER BY total_sales DESC;

-- 8.3 Агрегат по блюдам: сколько раз каждое блюдо заказывали
SELECT d.id AS dish_id, d.name, COUNT(oi.order_id) AS times_ordered, SUM(oi.quantity) AS total_qty
FROM dishes d
LEFT JOIN order_items oi ON oi.dish_id = d.id
GROUP BY d.id, d.name
ORDER BY total_qty DESC NULLS LAST;