import random
from faker import Faker
import psycopg2
from datetime import datetime, timedelta

fake = Faker('ru_RU')

conn = psycopg2.connect(
    dbname="restaurant",
    user="postgres",
    password="postgres",
    host="localhost"
)
cur = conn.cursor()

# 0. Очистка всех таблиц
cur.execute("""
    TRUNCATE payments, order_items, orders, dishes, tables, waiters, guests RESTART IDENTITY CASCADE;
""")
conn.commit()

# 1. Гости
for i in range(1, 5001):
    cur.execute(
        """
        INSERT INTO guests (id, last_name, first_name, middle_name, birth_date, total_orders, total_discount)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            i,
            fake.last_name(),
            fake.first_name(),
            fake.middle_name(),
            fake.date_of_birth(minimum_age=18, maximum_age=75),
            random.randint(0, 100),
            round(random.uniform(0, 1000), 2)
        )
    )

# 2. Официанты
for i in range(1, 201):
    cur.execute(
        """
        INSERT INTO waiters (id, last_name, first_name, middle_name, salary)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            i,
            fake.last_name(),
            fake.first_name(),
            fake.middle_name(),
            round(random.uniform(25000, 80000), 2)
        )
    )

# 3. Столы
for i in range(1, 101):
    cur.execute(
        """
        INSERT INTO tables (id, table_number, seats, status)
        VALUES (%s, %s, %s, %s)
        """,
        (
            i,
            i,
            random.choice([2, 4, 6, 8]),
            random.choice(['available', 'reserved', 'unavailable'])
        )
    )

# 4. Блюда
for i in range(1, 301):
    cur.execute(
        """
        INSERT INTO dishes (id, name, category, price, country_of_origin)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            i,
            fake.word(),
            random.choice(['Starter', 'Main', 'Dessert', 'Drink']),
            round(random.uniform(200, 3000), 2),
            fake.country()
        )
    )

# 5. Заказы (ЗА НОЯБРЬ 2025 — 1 месяц)
start_date = datetime(2025, 11, 1)   # ← 1 ноября
end_date = datetime(2025, 11, 30)    # ← 30 ноября  
date_range_days = (end_date - start_date).days  # 30 дней

for i in range(1, 100001):
    days_offset = random.randint(0, date_range_days)
    order_time = start_date + timedelta(days=days_offset,
                                       hours=random.randint(8, 23),
                                       minutes=random.randint(0, 59))
    cur.execute(
        """
        INSERT INTO orders (id, guest_id, table_id, waiter_id, order_time, total_amount, status, booking_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (i, random.randint(1, 5000), random.randint(1, 100),
         random.randint(1, 200), order_time,  # ← равномерно за ноябрь
         round(random.uniform(300, 10000), 2),
         random.choice(['created', 'paid', 'cancelled']), None)
    )
    if i % 10000 == 0: print(f"🍽️ Заказы: {i}/100k")


# 6. Строки заказов (order_items)
# На каждый заказ добавим 1–5 случайных блюд
for order_id in range(1, 100001):
    num_items = random.randint(1, 5)
    for _ in range(num_items):
        dish_id = random.randint(1, 300)
        quantity = random.randint(1, 4)

        cur.execute(
            """
            INSERT INTO order_items (order_id, dish_id, quantity)
            VALUES (%s, %s, %s)
            ON CONFLICT (order_id, dish_id) DO UPDATE
                SET quantity = order_items.quantity + EXCLUDED.quantity
            """,
            (order_id, dish_id, quantity)
        )

# 7. Платежи
cur.execute("SELECT id, order_time FROM orders")
all_orders = cur.fetchall()
print(f"💳 Создаем {int(len(all_orders)*0.7)} платежей из {len(all_orders)} заказов")

for order_id, order_time in random.sample(all_orders, int(len(all_orders)*0.7)):
    payment_time = order_time + timedelta(minutes=random.randint(5, 120))
    cur.execute("""
        INSERT INTO payments (id, order_id, amount, payment_time)
        VALUES (nextval('payments_id_seq'), %s, %s, %s)
    """, (order_id, round(random.uniform(300, 10000), 2), payment_time))
print("✅ Платежи созданы!")



conn.commit()
cur.close()
conn.close()