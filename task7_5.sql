-- 1. проверка конфликтов бронирования (BEFORE INSERT/UPDATE ON bookings)
CREATE OR REPLACE FUNCTION fn_check_booking_conflict()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- проверка: table_id должен существовать
    IF NEW.table_id IS NULL THEN
        RAISE EXCEPTION 'booking must reference a table';
    END IF;

    -- проверка: временные интервалы валидны
    IF NEW.booking_start IS NULL OR NEW.booking_end IS NULL THEN
        RAISE EXCEPTION 'booking start and end times must be provided';
    END IF;
    IF NEW.booking_start >= NEW.booking_end THEN
        RAISE EXCEPTION 'booking start time (%) must be before end time (%)', NEW.booking_start, NEW.booking_end;
    END IF;

    -- ищем пересечения броней для того же стола и той же даты (exclude self if update)
    IF EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.table_id = NEW.table_id
          AND b.booking_date = NEW.booking_date
          AND ( (NEW.booking_start < b.booking_end) AND (NEW.booking_end > b.booking_start) )
          AND (TG_OP = 'INSERT' OR b.id <> NEW.id)
    ) THEN
        RAISE EXCEPTION 'booking conflict: table % already has a booking overlapping on % %-%', 
		NEW.table_id, 
		NEW.booking_date, 
		NEW.booking_start, 
		NEW.booking_end;
    END IF;

    -- проверка: стол не должен быть 'unavailable'
    PERFORM 1 FROM tables t WHERE t.id = NEW.table_id AND t.status = 'unavailable';
    IF FOUND THEN
        RAISE EXCEPTION 'cannot book table %: table is unavailable', NEW.table_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_booking_conflict_before
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_check_booking_conflict();


-- 2. после успешной брони пометить стол как 'reserved' (AFTER INSERT ON bookings)
CREATE OR REPLACE FUNCTION fn_after_booking_mark_table_reserved()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- если стол в состоянии unavailable — не меняем (ошибка должна была быть ранее)
    UPDATE tables
    SET status = 'reserved'
    WHERE id = NEW.table_id
      AND status <> 'unavailable';

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_after_booking_mark_table_reserved
AFTER INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_after_booking_mark_table_reserved();


-- 3. проверки при вставке заказа (BEFORE INSERT ON orders)
-- проверяет, что стол не unavailable; проверяет guest и waiter существуют

CREATE OR REPLACE FUNCTION fn_before_insert_order_checks()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    t_status TEXT;
BEGIN
    -- guest must exist
    IF NEW.guest_id IS NULL THEN
        RAISE EXCEPTION 'order must reference a guest';
    END IF;
    PERFORM 1 FROM guests WHERE id = NEW.guest_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'guest with id % does not exist', NEW.guest_id;
    END IF;

    -- table check
    IF NEW.table_id IS NOT NULL THEN
        SELECT status INTO t_status FROM tables WHERE id = NEW.table_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'table with id % does not exist', NEW.table_id;
        END IF;
        IF t_status = 'unavailable' THEN
            RAISE EXCEPTION 'cannot create order for table %: table is unavailable', NEW.table_id;
        END IF;
    END IF;

    -- waiter check (optional)
    IF NEW.waiter_id IS NOT NULL THEN
        PERFORM 1 FROM waiters WHERE id = NEW.waiter_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'waiter with id % does not exist', NEW.waiter_id;
        END IF;
    END IF;

    -- total_amount non-negative
    IF NEW.total_amount IS NOT NULL AND NEW.total_amount < 0 THEN
        RAISE EXCEPTION 'order total_amount must be non-negative';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_before_insert_order_checks
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_before_insert_order_checks();


-- 4. если вставлен order со статусом 'paid' — автоматически создаём payment 
-- (AFTER INSERT ON orders) — компенсирующее действие
CREATE OR REPLACE FUNCTION fn_after_insert_order_create_payment()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status IS NOT NULL AND lower(NEW.status) = 'paid' THEN
        -- Guard: если уже есть платеж для этого заказа — не создаём дубликат
        IF NOT EXISTS (SELECT 1 FROM payments WHERE order_id = NEW.id) THEN
            INSERT INTO payments(order_id, payment_time, amount)
            VALUES (NEW.id, COALESCE(NEW.order_time, now()), COALESCE(NEW.total_amount, 0));
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_after_insert_order_create_payment
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_after_insert_order_create_payment();


-- 5. order_items: проверка при вставке (BEFORE INSERT), чтобы quantity > 0 and dish exists
CREATE OR REPLACE FUNCTION fn_before_insert_order_item_checks()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.quantity IS NULL OR NEW.quantity <= 0 THEN
        RAISE EXCEPTION 'order_items.quantity must be positive';
    END IF;

    PERFORM 1 FROM dishes WHERE id = NEW.dish_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'dish with id % does not exist', NEW.dish_id;
    END IF;

    -- Проверка: заказ должен существовать
    PERFORM 1 FROM orders WHERE id = NEW.order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'order with id % does not exist', NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_before_insert_order_item_checks
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_before_insert_order_item_checks();


-- 6. AFTER INSERT on order_items: компенсирующее действие — обновляем orders.total_amount
CREATE OR REPLACE FUNCTION fn_after_insert_order_item_update_order_total()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    price_var NUMERIC;
    delta NUMERIC;
BEGIN
    SELECT d.price INTO price_var FROM dishes d WHERE d.id = NEW.dish_id;
    IF price_var IS NULL THEN
        price_var := 0;
    END IF;
    delta := NEW.quantity * price_var;

    UPDATE orders
    SET total_amount = COALESCE(total_amount, 0) + delta
    WHERE id = NEW.order_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_after_insert_order_item_update_order_total
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_after_insert_order_item_update_order_total();


-- 7. AFTER DELETE on order_items: компенсирующее действие — уменьшаем orders.total_amount
CREATE OR REPLACE FUNCTION fn_after_delete_order_item_update_order_total()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    price NUMERIC;
    delta NUMERIC;
BEGIN
    SELECT d.price INTO price
    FROM dishes d
    WHERE d.id = OLD.dish_id;

    IF price IS NULL THEN
        price := 0;
    END IF;

    delta := OLD.quantity * price;

    UPDATE orders
    SET total_amount = COALESCE(total_amount, 0) - delta
    WHERE id = OLD.order_id;

    RETURN OLD;
END;
$$;


CREATE TRIGGER trg_after_delete_order_item_update_order_total
AFTER DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_after_delete_order_item_update_order_total();


-- 8. AFTER UPDATE on order_items: скорректировать total_amount в заказе с учётом разницы
CREATE OR REPLACE FUNCTION fn_after_delete_order_item_update_order_total()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    price_var NUMERIC;
    delta NUMERIC;
BEGIN
    SELECT d.price INTO price_var
    FROM dishes d
    WHERE d.id = OLD.dish_id;

    IF price_var IS NULL THEN
        price_var := 0;
    END IF;

    delta := OLD.quantity * price_var;

    UPDATE orders
    SET total_amount = COALESCE(total_amount, 0) - delta
    WHERE id = OLD.order_id;

    RETURN OLD;
END;
$$;


CREATE TRIGGER trg_after_update_order_item_adjust_order_total
AFTER UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_after_update_order_item_adjust_order_total();


-- 9. INSTEAD OF INSERT на view: пример для демонстрации INSTEAD OF триггеров
--  создаем простое представление v_order_entry для вставки заказов через view
CREATE OR REPLACE VIEW v_order_entry AS
SELECT id, guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id
FROM orders;

CREATE OR REPLACE FUNCTION fn_instead_of_insert_v_order_entry()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    new_order_id INT;
BEGIN
    -- вставляем в базовую таблицу orders, возвращаем строку (для совместимости с view)
    INSERT INTO orders (guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id)
    VALUES (NEW.guest_id, NEW.table_id, NEW.waiter_id, NEW.order_time, NEW.total_amount, NEW.status, NEW.booking_id)
    RETURNING id INTO new_order_id;

    -- если статус = 'paid', то создаём платёж автоматически
    IF NEW.status IS NOT NULL AND lower(NEW.status) = 'paid' THEN
        INSERT INTO payments(order_id, payment_time, amount)
        VALUES (new_order_id, COALESCE(NEW.order_time, now()), COALESCE(NEW.total_amount, 0));
    END IF;

    -- возвращаем row как требование INSTEAD OF TRIGGER
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_instead_of_insert_v_order_entry
INSTEAD OF INSERT ON v_order_entry
FOR EACH ROW
EXECUTE FUNCTION fn_instead_of_insert_v_order_entry();


-- 10. AFTER DELETE на orders: компенсирующее действие — создаем запись в лог-таблице (audit)
CREATE TABLE IF NOT EXISTS orders_deletes_audit (
    deleted_order_id INT,
    deleted_by TEXT,
    deleted_at TIMESTAMP,
    details TEXT
);

CREATE OR REPLACE FUNCTION fn_after_delete_order_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO orders_deletes_audit (deleted_order_id, deleted_by, deleted_at, details)
    VALUES (OLD.id, current_user, now(), 'Order deleted, guest_id=' || OLD.guest_id || ', total_amount=' || COALESCE(OLD.total_amount::text,'0'));
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_after_delete_order_audit
AFTER DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_after_delete_order_audit();



-- примеры 

-- Добавим тестовый стол, гостя и официанта с уникально большими id
INSERT INTO tables (id, table_number, seats, status) VALUES (1001, 101, 4, 'free');
INSERT INTO guests (id, last_name, first_name, birth_date) VALUES (200001, 'Иванов', 'Иван', '1990-01-01');
INSERT INTO waiters (id, last_name, first_name, salary) VALUES (3001, 'Петров', 'Петр', 40000);

-- Проверим исходное состояние
SELECT * FROM tables WHERE id = 1001;
SELECT * FROM guests WHERE id = 200001;
SELECT * FROM waiters WHERE id = 3001;
SELECT * FROM bookings WHERE table_id = 1001;

-- Добавление тестового бронирования для стола 1001 и гостя 2001
INSERT INTO bookings (id, table_id, guest_id, booking_date, guests_count, booking_start, booking_end)
VALUES (5001, 1001, 2001, '2025-12-01', 2, '18:00', '19:00');

-- Проверка изменения статуса тестового стола
SELECT * FROM tables WHERE id = 1001; -- статус должен стать 'reserved'
SELECT * FROM bookings WHERE id = 5001; -- появилась бронь

-- Демонстрация работы триггера заказа для тестовых id
INSERT INTO orders (id, guest_id, table_id, waiter_id, order_time, total_amount, status)
VALUES (6001, 2001, 1001, 3001, '2025-12-01 18:10', 500, 'paid');
SELECT * FROM orders WHERE id = 6001; -- новый заказ
SELECT * FROM payments WHERE order_id = 6001; -- автоматически создан платёж

-- Работа триггера с блюдами заказа: добавим тестовое блюдо и позицию
INSERT INTO dishes (id, name, category, price) VALUES (4001, 'Салат', 'Закуска', 250);
INSERT INTO order_items (order_id, dish_id, quantity) VALUES (6001, 4001, 2);

SELECT * FROM order_items WHERE order_id = 6001;
SELECT * FROM orders WHERE id = 6001; -- сумма заказа обновится

-- AFTER DELETE on order_items: уменьшаем orders.total_amount

-- до удаления позиции: смотрим заказ и его позиции
SELECT * FROM orders WHERE id = 6001;
SELECT * FROM order_items WHERE order_id = 6001;

-- удаляем позицию заказа (сработает AFTER DELETE триггер)
DELETE FROM order_items WHERE order_id = 6001 AND dish_id = 4001;

-- после удаления: сумма заказа должна уменьшиться
SELECT * FROM orders WHERE id = 6001;

-- AFTER UPDATE on order_items: корректируем total_amount

-- Создадим ещё одну тестовую позицию
INSERT INTO dishes (id, name, category, price) VALUES (4002, 'Суп', 'Первое', 300);
INSERT INTO order_items (order_id, dish_id, quantity) VALUES (6001, 4002, 1);

-- До изменения количества
SELECT * FROM orders WHERE id = 6001;
SELECT * FROM order_items WHERE order_id = 6001;

-- Увеличиваем количество блюда 4002 (сработает AFTER UPDATE триггер)
UPDATE order_items
SET quantity = 3
WHERE order_id = 6001 AND dish_id = 4002;

-- После изменения: сумма заказа должна увеличиться
SELECT * FROM orders WHERE id = 6001;
SELECT * FROM order_items WHERE order_id = 6001;

-- INSTEAD OF INSERT на v_order_entry:
-- вставляем заказ через представление, автоматически создаётся payment

-- До вставки через view
SELECT * FROM orders WHERE id >= 7000;
SELECT * FROM payments WHERE order_id >= 7000;

-- Вставка через представление (сработает INSTEAD OF триггер)
INSERT INTO v_order_entry (guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id)
VALUES (200001, 1001, 3001, now(), 750, 'paid', 5001);

-- После: появился новый заказ и платёж к нему
SELECT * FROM orders ORDER BY id DESC LIMIT 3;
SELECT * FROM payments ORDER BY id DESC LIMIT 3;

-- AFTER DELETE на orders: запись в таблицу аудита

-- Создадим отдельный тестовый заказ для удаления
INSERT INTO orders (id, guest_id, table_id, waiter_id, order_time, total_amount, status)
VALUES (7001, 200001, 1001, 3001, now(), 1234, 'canceled');

-- До удаления: проверим orders и audit-таблицу
SELECT * FROM orders WHERE id = 7001;
SELECT * FROM orders_deletes_audit WHERE deleted_order_id = 7001;

-- Удаляем заказ (сработает AFTER DELETE триггер)
DELETE FROM orders WHERE id = 7001;

-- После удаления: запись должна появиться в orders_deletes_audit
SELECT * FROM orders_deletes_audit WHERE deleted_order_id = 7001;



-- отчистка тестовых данных 
DELETE FROM order_items WHERE order_id = 6001;
DELETE FROM orders WHERE id = 6001;
DELETE FROM bookings WHERE id = 5001;
DELETE FROM dishes WHERE id IN (4001, 4002);
DELETE FROM guests WHERE id = 200001;
DELETE FROM waiters WHERE id = 3001;
DELETE FROM tables WHERE id = 1001;
DELETE FROM payments WHERE order_id = 6001;


DELETE FROM payments WHERE order_id >= 7000;
DELETE FROM orders WHERE id >= 7000;

-- если создавался тестовый заказ 7001 для аудита
DELETE FROM orders_deletes_audit WHERE deleted_order_id = 7001;
DELETE FROM orders WHERE id = 7001;



-- очистка / удаление триггеров 
DROP TRIGGER IF EXISTS trg_check_booking_conflict_before ON bookings;
DROP TRIGGER IF EXISTS trg_after_booking_mark_table_reserved ON bookings;

DROP TRIGGER IF EXISTS trg_before_insert_order_checks ON orders;
DROP TRIGGER IF EXISTS trg_after_insert_order_create_payment ON orders;
DROP TRIGGER IF EXISTS trg_after_delete_order_audit ON orders;

DROP TRIGGER IF EXISTS trg_before_insert_order_item_checks ON order_items;
DROP TRIGGER IF EXISTS trg_after_insert_order_item_update_order_total ON order_items;
DROP TRIGGER IF EXISTS trg_after_delete_order_item_update_order_total ON order_items;
DROP TRIGGER IF EXISTS trg_after_update_order_item_adjust_order_total ON order_items;

DROP TRIGGER IF EXISTS trg_instead_of_insert_v_order_entry ON v_order_entry;
