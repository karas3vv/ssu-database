-- Очистка данных
DELETE FROM reviews;
DELETE FROM payments;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM bookings;
DELETE FROM delivery_items;
DELETE FROM deliveries;
DELETE FROM storage;
DELETE FROM dishes_composition;
DELETE FROM guests;
DELETE FROM waiters;
DELETE FROM tables;
DELETE FROM dishes;
DELETE FROM products;
DELETE FROM suppliers;

-- 1. Заполнение справочников

-- Поставщики
INSERT INTO suppliers (name, address, contact_person, phone, email) VALUES
('ООО "Свежие продукты"', 'г. Москва, ул. Промышленная, 15', 'Иванов Петр Сергеевич', '+7-495-123-45-67', 'info@freshfood.ru'),
('ЗАО "Мясной двор"', 'г. Москва, ш. Энтузиастов, 89', 'Сидорова Мария Ивановна', '+7-495-234-56-78', 'meat@mdvor.ru'),
('ООО "Овощная база"', 'Московская обл., г. Люберцы, ул. Транспортная, 5', 'Петров Алексей Владимирович', '+7-495-345-67-89', 'ovoshi@base.ru'),
('ИП "Рыбный мир"', 'г. Москва, ул. Рыбная, 12', 'Козлов Дмитрий Николаевич', '+7-495-456-78-90', 'fish@world.com'),
('ООО "Молочные реки"', 'г. Москва, пр-т Мира, 156', 'Николаева Ольга Петровна', '+7-495-567-89-01', 'milk@rivers.ru');

-- Продукты
INSERT INTO products (name, weight, expiry_date, quantity, category) VALUES
('Картофель', 1.0, '2024-12-31', 500, 'Овощи'),
('Говядина', 1.0, '2024-02-15', 100, 'Мясо'),
('Лосось', 1.0, '2024-02-10', 50, 'Рыба'),
('Молоко', 1.0, '2024-02-05', 200, 'Молочные продукты'),
('Сыр пармезан', 0.5, '2024-03-20', 30, 'Молочные продукты'),
('Помидоры', 1.0, '2024-02-08', 150, 'Овощи'),
('Лук репчатый', 1.0, '2024-03-15', 80, 'Овощи'),
('Мука пшеничная', 1.0, '2024-06-30', 200, 'Бакалея'),
('Сливки 20%', 1.0, '2024-02-07', 60, 'Молочные продукты'),
('Зелень петрушки', 0.1, '2024-02-03', 20, 'Овощи');

-- Блюда
INSERT INTO dishes (name, category, price, country_of_origin) VALUES
('Стейк из говядины', 'Горячее', 1200, 'Россия'),
('Жареный лосось', 'Горячее', 950, 'Россия'),
('Картофель по-деревенски', 'Гарнир', 350, 'Россия'),
('Салат Цезарь', 'Салаты', 450, 'Италия'),
('Том Ям', 'Супы', 680, 'Тайланд'),
('Паста Карбонара', 'Горячее', 520, 'Италия'),
('Борщ', 'Супы', 320, 'Россия'),
('Тирамису', 'Десерты', 380, 'Италия');

-- Столы
INSERT INTO tables (table_number, seats, status) VALUES
(1, 2, 'свободен'),
(2, 4, 'занят'),
(3, 6, 'свободен'),
(4, 2, 'зарезервирован'),
(5, 8, 'свободен'),
(6, 4, 'занят'),
(7, 4, 'свободен'),
(8, 2, 'свободен');

-- Официанты
INSERT INTO waiters (last_name, first_name, middle_name, salary) VALUES
('Смирнов', 'Алексей', 'Владимирович', 45000),
('Ковалева', 'Елена', 'Сергеевна', 42000),
('Попов', 'Дмитрий', 'Игоревич', 47000),
('Федорова', 'Ольга', 'Александровна', 43000);

-- Гости
INSERT INTO guests (last_name, first_name, middle_name, birth_date, total_orders, total_discount) VALUES
('Петров', 'Иван', 'Сергеевич', '1985-03-15', 12500, 1250),
('Сидорова', 'Мария', 'Ивановна', '1990-07-22', 8700, 870),
('Козлов', 'Алексей', 'Петрович', '1978-11-03', 21000, 2100),
('Никитина', 'Екатерина', 'Владимировна', '1995-05-18', 4300, 430),
('Васильев', 'Дмитрий', 'Николаевич', '1982-09-30', 15600, 1560);

-- 2. Данные по хранению и поставкам

-- Хранение (используем реальные ID из только что созданных записей)
INSERT INTO storage (product_id, supplier_id, warehouse_number, production_date, expiry_date) 
SELECT 
    p.id as product_id,
    s.id as supplier_id,
    'WH-' || LPAD((row_number() over ())::text, 3, '0'),
    CASE 
        WHEN p.name = 'Картофель' THEN '2024-01-15'
        WHEN p.name = 'Говядина' THEN '2024-01-25'
        WHEN p.name = 'Лосось' THEN '2024-01-20'
        WHEN p.name = 'Молоко' THEN '2024-01-30'
        WHEN p.name = 'Сыр пармезан' THEN '2024-01-10'
        ELSE CURRENT_DATE - INTERVAL '10 days'
    END,
    p.expiry_date
FROM products p
CROSS JOIN suppliers s
WHERE (p.name = 'Картофель' AND s.name = 'ООО "Овощная база"')
   OR (p.name = 'Говядина' AND s.name = 'ЗАО "Мясной двор"')
   OR (p.name = 'Лосось' AND s.name = 'ИП "Рыбный мир"')
   OR (p.name = 'Молоко' AND s.name = 'ООО "Молочные реки"')
   OR (p.name = 'Сыр пармезан' AND s.name = 'ООО "Молочные реки"')
LIMIT 5;

-- Поставки
INSERT INTO deliveries (product_id, supplier_id, delivery_date, cost) 
SELECT 
    p.id as product_id,
    s.id as supplier_id,
    CASE 
        WHEN p.name = 'Картофель' THEN '2024-01-15'
        WHEN p.name = 'Говядина' THEN '2024-01-25'
        WHEN p.name = 'Лосось' THEN '2024-01-20'
        WHEN p.name = 'Молоко' THEN '2024-01-30'
        WHEN p.name = 'Помидоры' THEN '2024-01-28'
        ELSE CURRENT_DATE
    END,
    CASE 
        WHEN p.name = 'Картофель' THEN 5000
        WHEN p.name = 'Говядина' THEN 15000
        WHEN p.name = 'Лосось' THEN 12000
        WHEN p.name = 'Молоко' THEN 8000
        WHEN p.name = 'Помидоры' THEN 3000
        ELSE 1000
    END
FROM products p
CROSS JOIN suppliers s
WHERE (p.name = 'Картофель' AND s.name = 'ООО "Овощная база"')
   OR (p.name = 'Говядина' AND s.name = 'ЗАО "Мясной двор"')
   OR (p.name = 'Лосось' AND s.name = 'ИП "Рыбный мир"')
   OR (p.name = 'Молоко' AND s.name = 'ООО "Молочные реки"')
   OR (p.name = 'Помидоры' AND s.name = 'ООО "Овощная база"')
LIMIT 5;

-- Состав поставок
INSERT INTO delivery_items (product_id, delivery_id, quantity)
SELECT 
    p.id as product_id,
    d.id as delivery_id,
    CASE 
        WHEN p.name = 'Картофель' THEN 1000
        WHEN p.name = 'Говядина' THEN 200
        WHEN p.name = 'Лосось' THEN 100
        WHEN p.name = 'Молоко' THEN 400
        WHEN p.name = 'Помидоры' THEN 300
        ELSE 100
    END
FROM products p
CROSS JOIN deliveries d
WHERE (p.name = 'Картофель' AND d.cost = 5000)
   OR (p.name = 'Говядина' AND d.cost = 15000)
   OR (p.name = 'Лосось' AND d.cost = 12000)
   OR (p.name = 'Молоко' AND d.cost = 8000)
   OR (p.name = 'Помидоры' AND d.cost = 3000)
LIMIT 5;

-- 3. Состав блюд

INSERT INTO dishes_composition (dish_id, product_id, quantity, unit)
SELECT 
    d.id as dish_id,
    p.id as product_id,
    CASE 
        WHEN d.name = 'Стейк из говядины' AND p.name = 'Говядина' THEN 0.3
        WHEN d.name = 'Стейк из говядины' AND p.name = 'Помидоры' THEN 0.1
        WHEN d.name = 'Стейк из говядины' AND p.name = 'Лук репчатый' THEN 0.05
        WHEN d.name = 'Жареный лосось' AND p.name = 'Лосось' THEN 0.25
        WHEN d.name = 'Жареный лосось' AND p.name = 'Помидоры' THEN 0.08
        WHEN d.name = 'Картофель по-деревенски' AND p.name = 'Картофель' THEN 0.2
        WHEN d.name = 'Салат Цезарь' AND p.name = 'Сыр пармезан' THEN 0.05
        WHEN d.name = 'Салат Цезарь' AND p.name = 'Помидоры' THEN 0.1
        WHEN d.name = 'Салат Цезарь' AND p.name = 'Зелень петрушки' THEN 0.01
        ELSE 0.1
    END,
    'кг'
FROM dishes d
CROSS JOIN products p
WHERE (d.name = 'Стейк из говядины' AND p.name IN ('Говядина', 'Помидоры', 'Лук репчатый'))
   OR (d.name = 'Жареный лосось' AND p.name IN ('Лосось', 'Помидоры'))
   OR (d.name = 'Картофель по-деревенски' AND p.name = 'Картофель')
   OR (d.name = 'Салат Цезарь' AND p.name IN ('Сыр пармезан', 'Помидоры', 'Зелень петрушки'))
LIMIT 9;

-- 4. Бронирования и заказы

-- Бронирования
INSERT INTO bookings (table_id, guest_id, booking_date, guests_count, booking_start, booking_end)
SELECT 
    t.id as table_id,
    g.id as guest_id,
    '2024-02-01' as booking_date,
    CASE 
        WHEN g.last_name = 'Петров' THEN 2
        WHEN g.last_name = 'Козлов' THEN 4
        WHEN g.last_name = 'Сидорова' THEN 6
        ELSE 2
    END,
    CASE 
        WHEN g.last_name = 'Петров' THEN '19:00'::time
        WHEN g.last_name = 'Козлов' THEN '18:30'::time
        WHEN g.last_name = 'Сидорова' THEN '20:00'::time
        ELSE '19:00'::time
    END,
    CASE 
        WHEN g.last_name = 'Петров' THEN '21:00'::time
        WHEN g.last_name = 'Козлов' THEN '20:30'::time
        WHEN g.last_name = 'Сидорова' THEN '23:00'::time
        ELSE '21:00'::time
    END
FROM tables t
CROSS JOIN guests g
WHERE (g.last_name = 'Петров' AND t.table_number = 4)
   OR (g.last_name = 'Козлов' AND t.table_number = 2)
   OR (g.last_name = 'Сидорова' AND t.table_number = 5)
LIMIT 3;

-- Заказы
INSERT INTO orders (guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id)
SELECT 
    g.id as guest_id,
    t.id as table_id,
    w.id as waiter_id,
    CASE 
        WHEN g.last_name = 'Петров' THEN '2024-02-01 19:05:00'
        WHEN g.last_name = 'Козлов' THEN '2024-02-01 18:35:00'
        WHEN g.last_name = 'Сидорова' THEN '2024-02-01 20:10:00'
        WHEN g.last_name = 'Никитина' THEN '2024-02-01 19:30:00'
        ELSE NOW()
    END,
    CASE 
        WHEN g.last_name = 'Петров' THEN 2350
        WHEN g.last_name = 'Козлов' THEN 3120
        WHEN g.last_name = 'Сидорова' THEN 1850
        WHEN g.last_name = 'Никитина' THEN 950
        ELSE 1000
    END,
    CASE 
        WHEN g.last_name = 'Петров' THEN 'завершен'
        WHEN g.last_name = 'Козлов' THEN 'в процессе'
        WHEN g.last_name = 'Сидорова' THEN 'ожидает'
        WHEN g.last_name = 'Никитина' THEN 'завершен'
        ELSE 'ожидает'
    END,
    b.id as booking_id
FROM guests g
CROSS JOIN tables t
CROSS JOIN waiters w
LEFT JOIN bookings b ON g.id = b.guest_id
WHERE (g.last_name = 'Петров' AND t.table_number = 4 AND w.last_name = 'Смирнов')
   OR (g.last_name = 'Козлов' AND t.table_number = 2 AND w.last_name = 'Ковалева')
   OR (g.last_name = 'Сидорова' AND t.table_number = 5 AND w.last_name = 'Попов')
   OR (g.last_name = 'Никитина' AND t.table_number = 7 AND w.last_name = 'Федорoвa')
LIMIT 4;

-- Состав заказов
INSERT INTO order_items (order_id, dish_id, quantity)
SELECT 
    o.id as order_id,
    d.id as dish_id,
    CASE 
        WHEN o.total_amount = 2350 AND d.name = 'Стейк из говядины' THEN 1
        WHEN o.total_amount = 2350 AND d.name = 'Картофель по-деревенски' THEN 1
        WHEN o.total_amount = 2350 AND d.name = 'Салат Цезарь' THEN 1
        WHEN o.total_amount = 3120 AND d.name = 'Жареный лосось' THEN 2
        WHEN o.total_amount = 3120 AND d.name = 'Картофель по-деревенски' THEN 2
        WHEN o.total_amount = 3120 AND d.name = 'Борщ' THEN 1
        WHEN o.total_amount = 1850 AND d.name = 'Салат Цезарь' THEN 2
        WHEN o.total_amount = 1850 AND d.name = 'Паста Карбонара' THEN 1
        WHEN o.total_amount = 1850 AND d.name = 'Тирамису' THEN 1
        WHEN o.total_amount = 950 AND d.name = 'Жареный лосось' THEN 1
        ELSE 1
    END
FROM orders o
CROSS JOIN dishes d
WHERE (o.total_amount = 2350 AND d.name IN ('Стейк из говядины', 'Картофель по-деревенски', 'Салат Цезарь'))
   OR (o.total_amount = 3120 AND d.name IN ('Жареный лосось', 'Картофель по-деревенски', 'Борщ'))
   OR (o.total_amount = 1850 AND d.name IN ('Салат Цезарь', 'Паста Карбонара', 'Тирамису'))
   OR (o.total_amount = 950 AND d.name = 'Жареный лосось')
LIMIT 10;

-- 5. Платежи и отзывы

-- Платежи
INSERT INTO payments (order_id, payment_time, amount)
SELECT 
    o.id as order_id,
    CASE 
        WHEN o.total_amount = 2350 THEN '2024-02-01 21:00:00'
        WHEN o.total_amount = 950 THEN '2024-02-01 20:45:00'
        ELSE NOW()
    END,
    o.total_amount
FROM orders o
WHERE o.total_amount IN (2350, 950)
LIMIT 2;

-- Отзывы
INSERT INTO reviews (order_id, guest_id, rating)
SELECT 
    o.id as order_id,
    o.guest_id as guest_id,
    CASE 
        WHEN o.total_amount = 2350 THEN 5
        WHEN o.total_amount = 950 THEN 4
        ELSE 3
    END
FROM orders o
WHERE o.total_amount IN (2350, 950)
LIMIT 2;
