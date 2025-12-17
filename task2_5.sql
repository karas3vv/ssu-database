-- 1. Справочники

CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    contact_person TEXT,
    phone TEXT,
    email TEXT
);
COMMENT ON TABLE suppliers IS 'Поставщики';
COMMENT ON COLUMN suppliers.id IS 'Уникальный идентификатор поставщика';
COMMENT ON COLUMN suppliers.name IS 'Название поставщика';
COMMENT ON COLUMN suppliers.address IS 'Адрес поставщика';
COMMENT ON COLUMN suppliers.contact_person IS 'Контактное лицо';
COMMENT ON COLUMN suppliers.phone IS 'Телефон поставщика';
COMMENT ON COLUMN suppliers.email IS 'Электронная почта';

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    weight NUMERIC,
    expiry_date DATE,
    quantity NUMERIC,
    category TEXT
);
COMMENT ON TABLE products IS 'Продукты';
COMMENT ON COLUMN products.name IS 'Наименование продукта';
COMMENT ON COLUMN products.weight IS 'Масса единицы продукта';
COMMENT ON COLUMN products.expiry_date IS 'Срок годности';
COMMENT ON COLUMN products.quantity IS 'Количество продукта на складе';
COMMENT ON COLUMN products.category IS 'Категория продукта';

CREATE TABLE IF NOT EXISTS dishes (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    price NUMERIC NOT NULL,
    country_of_origin TEXT
);
COMMENT ON TABLE dishes IS 'Блюда';
COMMENT ON COLUMN dishes.name IS 'Наименование блюда';
COMMENT ON COLUMN dishes.category IS 'Категория блюда';
COMMENT ON COLUMN dishes.price IS 'Стоимость блюда';
COMMENT ON COLUMN dishes.country_of_origin IS 'Страна происхождения блюда';

CREATE TABLE IF NOT EXISTS tables (
    id SERIAL PRIMARY KEY,
    table_number INT NOT NULL,
    seats INT NOT NULL,
    status TEXT
);
COMMENT ON TABLE tables IS 'Столы в ресторане';
COMMENT ON COLUMN tables.table_number IS 'Номер стола';
COMMENT ON COLUMN tables.seats IS 'Количество мест';
COMMENT ON COLUMN tables.status IS 'Статус стола (свободен, занят, зарезервирован)';

CREATE TABLE IF NOT EXISTS waiters (
    id SERIAL PRIMARY KEY,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    middle_name TEXT,
    salary NUMERIC
);
COMMENT ON TABLE waiters IS 'Официанты';
COMMENT ON COLUMN waiters.last_name IS 'Фамилия официанта';
COMMENT ON COLUMN waiters.first_name IS 'Имя официанта';
COMMENT ON COLUMN waiters.middle_name IS 'Отчество официанта';
COMMENT ON COLUMN waiters.salary IS 'Оклад официанта';

CREATE TABLE IF NOT EXISTS guests (
    id SERIAL PRIMARY KEY,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    middle_name TEXT,
    birth_date DATE,
    total_orders NUMERIC,
    total_discount NUMERIC
);
COMMENT ON TABLE guests IS 'Гости ресторана';
COMMENT ON COLUMN guests.last_name IS 'Фамилия гостя';
COMMENT ON COLUMN guests.first_name IS 'Имя гостя';
COMMENT ON COLUMN guests.middle_name IS 'Отчество гостя';
COMMENT ON COLUMN guests.birth_date IS 'Дата рождения';
COMMENT ON COLUMN guests.total_orders IS 'Общая сумма заказов гостя';
COMMENT ON COLUMN guests.total_discount IS 'Сумма полученных скидок';

-- 2. Хранение и поставки

CREATE TABLE IF NOT EXISTS storage (
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    supplier_id INT REFERENCES suppliers(id) ON DELETE CASCADE,
    warehouse_number TEXT,
    production_date DATE,
    expiry_date DATE,
    PRIMARY KEY (product_id, supplier_id)
);
COMMENT ON TABLE storage IS 'Хранение продуктов на складе';
COMMENT ON COLUMN storage.warehouse_number IS 'Номер склада';
COMMENT ON COLUMN storage.production_date IS 'Дата производства';
COMMENT ON COLUMN storage.expiry_date IS 'Срок годности';

CREATE TABLE IF NOT EXISTS deliveries (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    supplier_id INT REFERENCES suppliers(id) ON DELETE CASCADE,
    delivery_date DATE,
    cost NUMERIC
);
COMMENT ON TABLE deliveries IS 'Поставки продуктов';
COMMENT ON COLUMN deliveries.delivery_date IS 'Дата поставки';
COMMENT ON COLUMN deliveries.cost IS 'Стоимость поставки';

CREATE TABLE IF NOT EXISTS delivery_items (
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    delivery_id INT REFERENCES deliveries(id) ON DELETE CASCADE,
    quantity NUMERIC,
    PRIMARY KEY (product_id, delivery_id)
);
COMMENT ON TABLE delivery_items IS 'Состав поставки';
COMMENT ON COLUMN delivery_items.quantity IS 'Количество продукта в поставке';

-- 3. Состав блюд

CREATE TABLE IF NOT EXISTS dishes_composition (
    dish_id INT REFERENCES dishes(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    quantity NUMERIC,
    unit TEXT,
    PRIMARY KEY (dish_id, product_id)
);
COMMENT ON TABLE dishes_composition IS 'Состав блюда (ингредиенты)';
COMMENT ON COLUMN dishes_composition.quantity IS 'Количество ингредиента';
COMMENT ON COLUMN dishes_composition.unit IS 'Единицы измерения';

-- 4. Бронирования и заказы

CREATE TABLE IF NOT EXISTS bookings (
    id SERIAL PRIMARY KEY,
    table_id INT REFERENCES tables(id) ON DELETE CASCADE,
    guest_id INT REFERENCES guests(id) ON DELETE CASCADE,
    booking_date DATE NOT NULL,
    guests_count INT,
    booking_start TIME,
    booking_end TIME
);
COMMENT ON TABLE bookings IS 'Бронирования столов';
COMMENT ON COLUMN bookings.booking_date IS 'Дата бронирования';
COMMENT ON COLUMN bookings.guests_count IS 'Количество гостей';
COMMENT ON COLUMN bookings.booking_start IS 'Время начала брони';
COMMENT ON COLUMN bookings.booking_end IS 'Время окончания брони';

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    guest_id INT REFERENCES guests(id) ON DELETE CASCADE,
    table_id INT REFERENCES tables(id) ON DELETE SET NULL,
    waiter_id INT REFERENCES waiters(id) ON DELETE SET NULL,
    order_time TIMESTAMP,
    total_amount NUMERIC,
    status TEXT,
    booking_id INT REFERENCES bookings(id) ON DELETE SET NULL
);
COMMENT ON TABLE orders IS 'Заказы гостей';
COMMENT ON COLUMN orders.order_time IS 'Время оформления заказа';
COMMENT ON COLUMN orders.total_amount IS 'Сумма заказа';
COMMENT ON COLUMN orders.status IS 'Статус заказа';

CREATE TABLE IF NOT EXISTS order_items (
    order_id INT REFERENCES orders(id) ON DELETE CASCADE,
    dish_id INT REFERENCES dishes(id) ON DELETE CASCADE,
    quantity INT,
    PRIMARY KEY (order_id, dish_id)
);
COMMENT ON TABLE order_items IS 'Состав заказа (блюда)';
COMMENT ON COLUMN order_items.quantity IS 'Количество блюд';

-- 5. Платежи и отзывы

CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) ON DELETE CASCADE,
    payment_time TIMESTAMP,
    amount NUMERIC
);
COMMENT ON TABLE payments IS 'Платежи по заказам';
COMMENT ON COLUMN payments.payment_time IS 'Время оплаты';
COMMENT ON COLUMN payments.amount IS 'Сумма платежа';

CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) ON DELETE CASCADE,
    guest_id INT REFERENCES guests(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 5)
);
COMMENT ON TABLE reviews IS 'Отзывы гостей о заказах';
COMMENT ON COLUMN reviews.rating IS 'Оценка (1-5)';


-- для интерфейса 
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    login TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL, 
    role TEXT NOT NULL CHECK (role IN ('admin', 'user'))
);

COMMENT ON TABLE users IS 'Пользователи системы';
COMMENT ON COLUMN users.login IS 'Логин для входа';
COMMENT ON COLUMN users.password_hash IS 'Хэш пароля';
COMMENT ON COLUMN users.role IS 'Роль пользователя (admin или user)';

INSERT INTO users (login, password_hash, role)
VALUES
  ('admin', 'admin', 'admin'),
  ('user1',  'user1',  'user')
ON CONFLICT (login) DO UPDATE
SET password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role;