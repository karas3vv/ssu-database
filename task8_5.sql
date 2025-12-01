-- 1. функция расчета выручки за период
-- возвращает общий доход ресторана за даты.
CREATE OR REPLACE FUNCTION get_revenue(
    date_from DATE,
    date_to DATE
)
RETURNS NUMERIC AS $$
    SELECT COALESCE(SUM(amount), 0)
    FROM payments
    WHERE payment_time::date BETWEEN date_from AND date_to;
$$ LANGUAGE SQL;

-- 2. функция поулчения всех заказов гостя
-- возвращает множество записей SETOF orders.
CREATE OR REPLACE FUNCTION guest_orders(
    p_guest_id INT
)
RETURNS SETOF orders AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM orders
    WHERE guest_id = p_guest_id
    ORDER BY order_time;
END;
$$ LANGUAGE plpgsql;

-- 3. ФУНКЦИЯ СТАТИСТИКИ ПРОДАЖ БЛЮД
-- Возвращает таблицу dish_name / total_sold.
CREATE OR REPLACE FUNCTION dishes_sales()
RETURNS TABLE (
    dish_name text,
    total_sold bigint
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.name,
        COALESCE(SUM(oi.quantity), 0)
    FROM dishes d
    LEFT JOIN order_items oi ON d.id = oi.dish_id
    GROUP BY d.name
    ORDER BY total_sold DESC;
END;
$$;

-- 4. функция списания продуктов по заказу
-- использует цикл по order_items и вложенный цикл по составу блюда.
CREATE OR REPLACE FUNCTION consume_products(
    p_order_id INT
)
RETURNS TEXT AS $$
DECLARE
    item RECORD;
    comp RECORD;
BEGIN
    -- проходим по всем позициям заказа
    FOR item IN
        SELECT * FROM order_items WHERE order_id = p_order_id
    LOOP
        -- для каждой позиции находим её ингредиенты
        FOR comp IN
            SELECT * FROM dishes_composition WHERE dish_id = item.dish_id
        LOOP
            -- списание продуктов со склада
            UPDATE products
            SET quantity = quantity - comp.quantity * item.quantity
            WHERE id = comp.product_id;
            -- если продукт не найден — выводим предупреждение
            IF NOT FOUND THEN
                RAISE NOTICE 'Product % not found during consumption', comp.product_id;
            END IF;
        END LOOP;
    END LOOP;
    RETURN 'Products consumed successfully';
END;
$$ LANGUAGE plpgsql;

-- 5. функция поиска свободных столов на время
-- возвращает SETOF tables.
CREATE OR REPLACE FUNCTION free_tables(
    p_date DATE,
    p_start TIME,
    p_end TIME,
    p_guests INT
)
RETURNS SETOF tables AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM tables t
    WHERE t.seats >= p_guests
      AND t.id NOT IN (
          SELECT table_id
          FROM bookings
          WHERE booking_date = p_date
            AND (booking_start, booking_end)
                OVERLAPS (p_start, p_end)
      );
END;
$$ LANGUAGE plpgsql;

-- примеры вызовов

-- 1. выручка за месяц
SELECT get_revenue('2025-01-01', '2025-01-31');

-- 2. все заказы конкретного гостя
SELECT * FROM guest_orders(42);

-- 3. статистика продаж
SELECT * FROM dishes_sales();

-- 4. списание ингредиентов
SELECT consume_products(150);

-- 5. свободные столы
SELECT * FROM free_tables('2025-02-15', '18:00', '20:00', 4);



DROP FUNCTION IF EXISTS calculate_booking_profit(date, date);
DROP FUNCTION IF EXISTS guest_bookings(int);
DROP FUNCTION IF EXISTS dishes_sales();
DROP FUNCTION IF EXISTS popular_dishes_limit(int);
DROP FUNCTION IF EXISTS repeat_guest_discount(int);