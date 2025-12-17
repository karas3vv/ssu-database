import random
from datetime import datetime, timedelta

import psycopg2
from psycopg2.extras import execute_values
from faker import Faker


# --------------------
# CONFIG
# --------------------
DB = dict(
    dbname="restaurant",
    user="postgres",
    password="postgres",
    host="localhost",
)

SEED = 42

N_GUESTS = 5000
N_WAITERS = 200
N_TABLES = 100
N_DISHES = 300
N_ORDERS = 100000

N_SUPPLIERS = 12
N_DELIVERIES = 2000  # сколько записей в deliveries

DATE_START = datetime(2025, 11, 1, 8, 0, 0)
DATE_END = datetime(2025, 11, 30, 23, 59, 59)

ORDER_STATUSES = ["создан", "оплачен", "отменён"]
ORDER_STATUS_WEIGHTS = [0.25, 0.65, 0.10]

TABLE_STATUSES = ["свободен", "забронирован", "недоступен"]
TABLE_STATUS_WEIGHTS = [0.70, 0.20, 0.10]


# --------------------
# HELPERS
# --------------------
fake = Faker("ru_RU")
random.seed(SEED)
Faker.seed(SEED)


def random_dt(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


# --------------------
# DISHES DATA (RU)
# --------------------
CATEGORIES = {
    "Закуски": [
        "Брускетта", "Сырная тарелка", "Овощная нарезка", "Сельдь с картофелем",
        "Гренки чесночные", "Куриные крылышки", "Рулетики из баклажанов",
    ],
    "Салаты": [
        "Цезарь", "Греческий", "Оливье", "Салат с тунцом", "Салат с курицей",
        "Салат с креветками", "Салат овощной",
    ],
    "Супы": [
        "Борщ", "Солянка", "Крем-суп грибной", "Куриный суп", "Уха",
        "Суп-пюре тыквенный",
    ],
    "Горячее": [
        "Стейк", "Паста Карбонара", "Плов", "Курица в сливочном соусе",
        "Рыба на гриле", "Котлета по-киевски", "Свинина запечённая",
    ],
    "Гарниры": [
        "Картофель фри", "Картофельное пюре", "Рис", "Овощи гриль", "Гречка",
    ],
    "Десерты": [
        "Чизкейк", "Тирамису", "Медовик", "Блины с вареньем", "Мороженое",
        "Шарлотка",
    ],
    "Напитки": [
        "Чай", "Кофе", "Морс", "Лимонад", "Сок", "Вода", "Какао",
    ],
}

NAME_SUFFIXES = ["", " (домашний)", " (фирменный)", " с соусом", " с сыром", " с овощами"]
COUNTRIES_RU = ["Россия", "Италия", "Франция", "Грузия", "Япония", "Китай", "Турция", "США", "Испания"]


def gen_dish(cat: str) -> tuple[str, str, float, str]:
    base = random.choice(CATEGORIES[cat])
    name = (base + random.choice(NAME_SUFFIXES)).strip()

    if cat == "Напитки":
        price = round(random.uniform(80, 450), 2)
    elif cat in ("Закуски", "Супы", "Гарниры"):
        price = round(random.uniform(150, 900), 2)
    elif cat == "Десерты":
        price = round(random.uniform(180, 950), 2)
    else:
        price = round(random.uniform(350, 2500), 2)

    country = random.choice(COUNTRIES_RU)
    return (name, cat, price, country)


# --------------------
# SUPPLIERS / PRODUCTS DATA
# --------------------
SUPPLIERS = [
    'ООО "ФермерПоставка"', 'ООО "Мясной Дом"', 'ООО "Молочный Мир"', 'ООО "ОвощБаза"',
    'ООО "РыбТорг"', 'ООО "БакалеяОпт"', 'ООО "НапиткиПлюс"', 'ООО "Пекарня-Снабжение"',
    'ООО "Сыр&Ко"', 'ООО "Восток Специи"', 'ООО "Тепличный Комбинат"', 'ООО "СахарОпт"',
][:N_SUPPLIERS]

PRODUCT_CATEGORIES = {
    "Мясо": ["Курица", "Говядина", "Свинина", "Индейка"],
    "Рыба": ["Лосось", "Треска", "Минтай", "Тунец"],
    "Молочные": ["Молоко", "Сливки", "Сметана", "Творог", "Сыр", "Масло сливочное"],
    "Овощи": ["Картофель", "Лук", "Морковь", "Помидоры", "Огурцы", "Чеснок", "Перец болгарский"],
    "Фрукты": ["Лимон", "Яблоки", "Бананы"],
    "Бакалея": ["Рис", "Гречка", "Макароны", "Мука", "Сахар", "Соль"],
    "Специи": ["Перец чёрный", "Паприка", "Орегано", "Базилик"],
    "Напитки": ["Вода", "Сок", "Лимонад", "Чай", "Кофе"],
    "Прочее": ["Яйца", "Хлеб", "Шоколад", "Ваниль"],
}


def product_weight_grams(cat: str) -> float:
    if cat in ("Мясо", "Рыба"):
        return float(random.choice([500, 1000, 1500, 2000]))
    if cat in ("Овощи", "Фрукты"):
        return float(random.choice([200, 500, 1000]))
    if cat in ("Молочные", "Напитки"):
        return float(random.choice([250, 500, 1000]))
    if cat in ("Бакалея", "Специи"):
        return float(random.choice([50, 100, 200, 500, 1000]))
    return float(random.choice([100, 250, 500, 1000]))


# --------------------
# MAIN
# --------------------
def main():
    print("Подключаемся к БД...")
    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    cur = conn.cursor()

    print("0) Очищаем таблицы...")
    cur.execute("""
        TRUNCATE
          delivery_items, deliveries, storage, dishes_composition,
          payments, order_items, orders, bookings,
          dishes, products, suppliers,
          tables, waiters, guests, users
        RESTART IDENTITY CASCADE;
    """)
    conn.commit()
    print("   ✓ Таблицы очищены")

    print("0.1) Создаём пользователей интерфейса...")
    cur.execute("""
        INSERT INTO users (login, password_hash, role)
        VALUES
          ('admin', 'admin_hashed', 'admin'),
          ('user1', 'user1_hashed', 'user')
    """)
    conn.commit()
    print("   ✓ Пользователи созданы")

    # suppliers
    print(f"0.5) Генерируем поставщиков: {len(SUPPLIERS)} шт...")
    suppliers_rows = []
    for name in SUPPLIERS:
        suppliers_rows.append((
            name,
            fake.address().replace("\n", ", "),
            f"{fake.last_name()} {fake.first_name()}",
            fake.phone_number(),
            fake.email(),
        ))
    execute_values(
        cur,
        """
        INSERT INTO suppliers (name, address, contact_person, phone, email)
        VALUES %s
        """,
        suppliers_rows,
        page_size=1000,
    )
    conn.commit()
    print("   ✓ Поставщики вставлены")

    # products
    print("0.6) Генерируем продукты...")
    product_pairs = []
    for cat, names in PRODUCT_CATEGORIES.items():
        for n in names:
            product_pairs.append((n, cat))
    product_pairs = product_pairs[:200]

    products_rows = []
    for name, cat in product_pairs:
        qty = round(random.uniform(10, 500), 2)
        prod_date = random_dt(DATE_START - timedelta(days=60), DATE_END).date()
        exp_date = prod_date + timedelta(days=random.randint(7, 180))
        products_rows.append((
            name,
            product_weight_grams(cat),
            exp_date,
            qty,
            cat,
        ))

    execute_values(
        cur,
        """
        INSERT INTO products (name, weight, expiry_date, quantity, category)
        VALUES %s
        """,
        products_rows,
        page_size=5000,
    )
    conn.commit()
    n_products = len(products_rows)
    print(f"   ✓ Продукты вставлены: {n_products}")

    # storage
    print("0.7) Заполняем storage (хранение)...")
    storage_rows = []
    for product_id in range(1, n_products + 1):
        supplier_id = random.randint(1, len(SUPPLIERS))
        production_date = random_dt(DATE_START - timedelta(days=60), DATE_END).date()
        expiry_date = production_date + timedelta(days=random.randint(7, 180))
        warehouse_number = str(random.randint(1, 5))
        storage_rows.append((product_id, supplier_id, warehouse_number, production_date, expiry_date))

    execute_values(
        cur,
        """
        INSERT INTO storage (product_id, supplier_id, warehouse_number, production_date, expiry_date)
        VALUES %s
        """,
        storage_rows,
        page_size=10000,
    )
    conn.commit()
    print(f"   ✓ Storage записей: {len(storage_rows)}")

    # deliveries + delivery_items (FIXED)
    print(f"0.8) Генерируем поставки: deliveries={N_DELIVERIES} ...")
    deliveries_rows = []
    for _ in range(N_DELIVERIES):
        product_id = random.randint(1, n_products)
        supplier_id = random.randint(1, len(SUPPLIERS))
        delivery_date = random_dt(DATE_START - timedelta(days=60), DATE_END).date()
        cost = round(random.uniform(500, 50000), 2)
        deliveries_rows.append((product_id, supplier_id, delivery_date, cost))

    execute_values(
        cur,
        """
        INSERT INTO deliveries (product_id, supplier_id, delivery_date, cost)
        VALUES %s
        """,
        deliveries_rows,
        page_size=5000,
    )
    conn.commit()

    cur.execute("SELECT COALESCE(MAX(id), 0) FROM deliveries")
    max_delivery_id = cur.fetchone()[0]
    first_delivery_id = max_delivery_id - N_DELIVERIES + 1

    delivery_items_rows = []
    for delivery_id in range(first_delivery_id, max_delivery_id + 1):
        used_products = set()
        n_items = random.randint(1, 4)
        while len(used_products) < n_items:
            used_products.add(random.randint(1, n_products))
        for product_id in used_products:
            qty = round(random.uniform(1, 50), 2)
            delivery_items_rows.append((product_id, delivery_id, qty))

        if (delivery_id - first_delivery_id + 1) % 500 == 0:
            print(f"   ...подготовлены позиции поставок: {delivery_id - first_delivery_id + 1}/{N_DELIVERIES}")

    # Теперь ON CONFLICT не нужен, но можно оставить как “страховку”
    execute_values(
        cur,
        """
        INSERT INTO delivery_items (product_id, delivery_id, quantity)
        VALUES %s
        """,
        delivery_items_rows,
        page_size=10000,
    )
    conn.commit()
    print(f"   ✓ Deliveries: {N_DELIVERIES}, delivery_items строк: {len(delivery_items_rows)}")

    # guests
    print(f"1) Генерируем гостей: {N_GUESTS} шт...")
    guests = []
    for i in range(1, N_GUESTS + 1):
        guests.append((
            i,
            fake.last_name(),
            fake.first_name(),
            fake.middle_name(),
            fake.date_of_birth(minimum_age=18, maximum_age=75),
            0,
            0.0,
        ))
    execute_values(
        cur,
        """
        INSERT INTO guests (id, last_name, first_name, middle_name, birth_date, total_orders, total_discount)
        VALUES %s
        """,
        guests,
        page_size=5000,
    )
    conn.commit()
    print("   ✓ Гости вставлены")

    # waiters
    print(f"2) Генерируем официантов: {N_WAITERS} шт...")
    waiters = []
    for i in range(1, N_WAITERS + 1):
        waiters.append((
            i,
            fake.last_name(),
            fake.first_name(),
            fake.middle_name(),
            round(random.uniform(25000, 80000), 2),
        ))
    execute_values(
        cur,
        """
        INSERT INTO waiters (id, last_name, first_name, middle_name, salary)
        VALUES %s
        """,
        waiters,
        page_size=2000,
    )
    conn.commit()
    print("   ✓ Официанты вставлены")

    # tables
    print(f"3) Генерируем столы: {N_TABLES} шт...")
    tables_rows = []
    for i in range(1, N_TABLES + 1):
        tables_rows.append((
            i,
            i,
            random.choice([2, 4, 6, 8]),
            random.choices(TABLE_STATUSES, weights=TABLE_STATUS_WEIGHTS, k=1)[0],
        ))
    execute_values(
        cur,
        """
        INSERT INTO tables (id, table_number, seats, status)
        VALUES %s
        """,
        tables_rows,
        page_size=1000,
    )
    conn.commit()
    print("   ✓ Столы вставлены")

    # dishes
    print(f"4) Генерируем блюда: {N_DISHES} шт...")
    dish_rows = []
    cats = list(CATEGORIES.keys())
    for i in range(1, N_DISHES + 1):
        cat = random.choice(cats)
        name, category, price, country = gen_dish(cat)
        dish_rows.append((i, name, category, price, country))

    execute_values(
        cur,
        """
        INSERT INTO dishes (id, name, category, price, country_of_origin)
        VALUES %s
        """,
        dish_rows,
        page_size=2000,
    )
    conn.commit()
    print("   ✓ Блюда вставлены")

    # dishes_composition
    print("4.5) Генерируем состав блюд (dishes_composition)...")
    UNITS = ["г", "мл", "шт"]
    composition_rows = []
    for dish_id in range(1, N_DISHES + 1):
        used = set()
        n_ing = random.randint(3, 8)
        while len(used) < n_ing:
            used.add(random.randint(1, n_products))
        for product_id in used:
            unit = random.choice(UNITS)
            qty = round(random.uniform(10, 400), 2) if unit in ("г", "мл") else round(random.uniform(1, 5), 2)
            composition_rows.append((dish_id, product_id, qty, unit))

        if dish_id % 50 == 0:
            print(f"   ...состав сформирован для блюд: {dish_id}/{N_DISHES}")

    execute_values(
        cur,
        """
        INSERT INTO dishes_composition (dish_id, product_id, quantity, unit)
        VALUES %s
        """,
        composition_rows,
        page_size=20000,
    )
    conn.commit()
    print(f"   ✓ Ингредиентов в составах: {len(composition_rows)}")

    # цены блюд
    cur.execute("SELECT id, price FROM dishes")
    price_by_dish = dict(cur.fetchall())

    # orders
    print(f"5) Генерируем заказы: {N_ORDERS} шт за период {DATE_START.date()}–{DATE_END.date()}...")
    orders = []
    for order_id in range(1, N_ORDERS + 1):
        orders.append((
            order_id,
            random.randint(1, N_GUESTS),
            random.randint(1, N_TABLES),
            random.randint(1, N_WAITERS),
            random_dt(DATE_START, DATE_END),
            0.0,
            random.choices(ORDER_STATUSES, weights=ORDER_STATUS_WEIGHTS, k=1)[0],
            None,
        ))
        if order_id % 20000 == 0:
            print(f"   ...подготовлено заказов: {order_id}/{N_ORDERS}")

    for part in chunked(orders, 5000):
        execute_values(
            cur,
            """
            INSERT INTO orders (id, guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id)
            VALUES %s
            """,
            part,
            page_size=5000,
        )
        conn.commit()
    print("   ✓ Заказы вставлены")

    # order_items + totals
    print("6) Генерируем позиции заказов и считаем суммы...")
    items = []
    totals = [0.0] * (N_ORDERS + 1)

    for order_id in range(1, N_ORDERS + 1):
        used = set()
        n_items = random.randint(1, 6)
        while len(used) < n_items:
            used.add(random.randint(1, N_DISHES))
        for dish_id in used:
            qty = random.randint(1, 4)
            items.append((order_id, dish_id, qty))
            totals[order_id] += float(price_by_dish[dish_id]) * qty

        if order_id % 20000 == 0:
            print(f"   ...позиции подготовлены до заказа: {order_id}/{N_ORDERS}")

        if len(items) >= 200000:
            execute_values(
                cur,
                """
                INSERT INTO order_items (order_id, dish_id, quantity)
                VALUES %s
                """,
                items,
                page_size=10000,
            )
            conn.commit()
            items.clear()

    if items:
        execute_values(
            cur,
            """
            INSERT INTO order_items (order_id, dish_id, quantity)
            VALUES %s
            """,
            items,
            page_size=10000,
        )
        conn.commit()
    print("   ✓ Позиции заказов вставлены")

    print("   Обновляем суммы заказов...")
    order_totals = [(round(totals[oid], 2), oid) for oid in range(1, N_ORDERS + 1)]
    for part in chunked(order_totals, 10000):
        execute_values(
            cur,
            "UPDATE orders AS o SET total_amount = v.total FROM (VALUES %s) AS v(total, id) WHERE o.id = v.id",
            part,
            template="(%s, %s)",
            page_size=10000,
        )
        conn.commit()
    print("   ✓ Суммы заказов обновлены")

    # payments for 'оплачен'
    print("7) Генерируем платежи для оплаченных заказов...")
    cur.execute("SELECT id, order_time, total_amount FROM orders WHERE status = 'оплачен'")
    paid_orders = cur.fetchall()
    print(f"   Найдено оплаченных заказов: {len(paid_orders)}")

    payments = []
    for (order_id, order_time, total_amount) in paid_orders:
        payment_time = order_time + timedelta(minutes=random.randint(5, 120))
        payments.append((order_id, payment_time, total_amount))

    for part in chunked(payments, 20000):
        execute_values(
            cur,
            """
            INSERT INTO payments (order_id, payment_time, amount)
            VALUES %s
            """,
            part,
            page_size=20000,
        )
        conn.commit()
    print("   ✓ Платежи вставлены")

    # total_orders = count(*)
    print("8) Пересчитываем total_orders у гостей (кол-во заказов)...")
    cur.execute("""
        UPDATE guests g
        SET total_orders = x.cnt
        FROM (
            SELECT guest_id, COUNT(*) AS cnt
            FROM orders
            GROUP BY guest_id
        ) x
        WHERE x.guest_id = g.id
    """)
    conn.commit()
    print("   ✓ total_orders обновлён")

    cur.close()
    conn.close()
    print("✅ Готово: база заполнена.")


if __name__ == "__main__":
    main()
