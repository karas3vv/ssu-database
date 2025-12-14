import random
from datetime import datetime, timedelta

import psycopg2
from psycopg2.extras import execute_values
from faker import Faker

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

DATE_START = datetime(2025, 11, 1, 8, 0, 0)
DATE_END = datetime(2025, 11, 30, 23, 59, 59)

ORDER_STATUSES = ["создан", "оплачен", "отменён"]
ORDER_STATUS_WEIGHTS = [0.25, 0.65, 0.10]

TABLE_STATUSES = ["свободен", "забронирован", "недоступен"]
TABLE_STATUS_WEIGHTS = [0.70, 0.20, 0.10]

# HELPERS
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


# MENU DATA (RU)
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
    else:  # Горячее, Салаты
        price = round(random.uniform(350, 2500), 2)

    country = random.choice(COUNTRIES_RU)
    return (name, cat, price, country)


# MAIN
def main():
    print("Подключаемся к БД...")
    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    cur = conn.cursor()

    print("0) Очищаем таблицы...")
    cur.execute("""
        TRUNCATE payments, order_items, orders, dishes, tables, waiters, guests
        RESTART IDENTITY CASCADE;
    """)
    conn.commit()
    print("   ✓ Таблицы очищены")

    # 1) guests
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

    # 2) waiters
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

    # 3) tables
    print(f"3) Генерируем столы: {N_TABLES} шт...")
    tables = []
    for i in range(1, N_TABLES + 1):
        tables.append((
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
        tables,
        page_size=1000,
    )
    conn.commit()
    print("   ✓ Столы вставлены")

    # 4) dishes
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

    # цены в dict
    cur.execute("SELECT id, price FROM dishes")
    price_by_dish = dict(cur.fetchall())

    # 5) orders
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

    # 6) order_items + totals
    print("6) Генерируем позиции заказов и считаем суммы...")
    items = []
    totals = [0.0] * (N_ORDERS + 1)

    for order_id in range(1, N_ORDERS + 1):
        n_items = random.randint(1, 6)
        used = set()
        for _ in range(n_items):
            dish_id = random.randint(1, N_DISHES)
            if dish_id in used:
                continue
            used.add(dish_id)

            qty = random.randint(1, 4)
            items.append((order_id, dish_id, qty))
            totals[order_id] += float(price_by_dish[dish_id]) * qty

        if order_id % 20000 == 0:
            print(f"   ...подготовлены позиции для заказов до #{order_id}")

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

    # 7) payments
    print("7) Генерируем платежи для оплаченных заказов...")
    cur.execute("SELECT id, order_time, total_amount FROM orders WHERE status = 'оплачен'")
    paid_orders = cur.fetchall()
    print(f"   Найдено оплаченных заказов: {len(paid_orders)}")

    payments = []
    for (order_id, order_time, total_amount) in paid_orders:
        payment_time = order_time + timedelta(minutes=random.randint(5, 120))
        payments.append((order_id, total_amount, payment_time))

    for part in chunked(payments, 20000):
        execute_values(
            cur,
            """
            INSERT INTO payments (order_id, amount, payment_time)
            VALUES %s
            """,
            part,
            page_size=20000,
        )
        conn.commit()
    print("   ✓ Платежи вставлены")

    print("8) Пересчитываем total_orders у гостей...")
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
