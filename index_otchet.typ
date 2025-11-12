#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2cm, left: 2.5cm, right: 2.5cm)
)

#set heading(numbering: "1.")

#show heading: set block(above: 1.3em, below: 1em)
#show heading.where(level: 1): set text(16pt, weight: "bold")
#show heading.where(level: 2): set text(14pt, weight: "medium")

#set par(justify: true)
#set text(font: ("Times New Roman", "Liberation Serif"), size: 12pt)

= Отчет по тестированию индексов в PostgreSQL

== Введение

В данном отчете представлены результаты тестирования различных типов индексов в PostgreSQL на базе данных ресторана. Для каждого теста приведены: код запроса, план выполнения до создания индекса, SQL-код индекса и план выполнения после создания индекса.

== Простые индексы

=== Код запроса

```sql
SELECT last_name FROM guests WHERE last_name = 'Иванов';
```

=== Выполнение без индексов

// #image("explain_plan_no_index_1.svg")
// #image("п11(2).png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_guests_lastname;
CREATE INDEX idx_guests_lastname ON guests USING BTREE (last_name);
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_btree_1.svg")
// #image("п12(2).png")

=== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_guests_lastname_hash;
CREATE INDEX idx_guests_lastname_hash ON guests USING HASH (last_name);
```

=== Выполнение с индексами Hash

// #image("explain_plan_hash_1.svg")
// #image("п1_3.png")

== Уникальный индекс

=== Код запроса

```sql
SELECT table_number FROM tables WHERE table_number = 5;
```

=== Выполнение без индексов

// #image("explain_plan_no_index_2.svg")
// #image("п2_1(2).png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_tables_tablenumber_unique;
CREATE UNIQUE INDEX idx_tables_tablenumber_unique ON tables USING BTREE (table_number);
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_unique.svg")
// #image("п2_2.png")

== Составной индекс

=== Код запроса

```sql
SELECT guest_id, order_time FROM orders WHERE guest_id = 100 AND order_time >= '2025-11-01';
```

=== Выполнение без индексов

// #image("explain_plan_no_index_3.svg")
// #image("п3_1.png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_orders_guest_time;
CREATE INDEX idx_orders_guest_time ON orders USING BTREE (guest_id, order_time);
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_composite.svg")
// #image("п3_2.png")

== Индексы с использованием выражений

=== Код запроса

```sql
SELECT * FROM guests WHERE DATE_PART('year', birth_date) = 1990;
```

=== Выполнение без индексов

// #image("explain_plan_no_index_4.svg")
// #image("п4_1.png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_guests_birth_year;
CREATE INDEX idx_guests_birth_year ON guests USING BTREE (DATE_PART('year', birth_date));
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_expression_btree.svg")
// #image("п4_2.png")

=== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_guests_birth_year_hash;
CREATE INDEX idx_guests_birth_year_hash ON guests USING HASH (DATE_PART('year', birth_date));
```

=== Выполнение с индексами Hash

// #image("explain_plan_expression_hash.svg")
// #image("п4_3.png")

== Покрывающий индекс

=== Код запроса

```sql
SELECT name, price FROM dishes WHERE category = 'Main';
```

=== Выполнение без индексов

// #image("explain_plan_no_index_5.svg")
// #image("п5_1.png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_dishes_category_covering;
CREATE INDEX idx_dishes_category_covering ON dishes USING BTREE (category) 
INCLUDE (name, price, country_of_origin);
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_covering.svg")
// #image("п5_2.png")

== Частичный индекс

=== Код запроса

```sql
SELECT status, order_time FROM orders WHERE status = 'paid' AND order_time >= '2025-11-01';
```

=== Выполнение без индексов

// #image("explain_plan_no_index_6.svg")
// #image("п6_1.png")

=== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_orders_paid;
CREATE INDEX idx_orders_paid ON orders USING BTREE (order_time) 
WHERE status = 'paid';
```

=== Выполнение с индексами B-Tree

// #image("explain_plan_partial.svg")
// #image("п6_2.png")

=== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_orders_paid_status_hash;
CREATE INDEX idx_orders_paid_status_hash ON orders USING HASH (guest_id) 
WHERE status = 'paid';
```

=== Выполнение с индексами Hash

// #image("explain_plan_partial_hash.svg")
// #image("п6_3.png")

== Частичный покрывающий индекс

=== Код запроса

```sql
SELECT guest_id, table_id, total_amount FROM orders 
WHERE status = 'paid' AND order_time >= '2025-11-01';
```

=== Выполнение без индексов

// #image("explain_plan_no_index_7.svg")
// #image("п7_1.png")

=== Код индекса B-Tree (частичный)

```sql
DROP INDEX IF EXISTS idx_orders_paid_partial;
CREATE INDEX idx_orders_paid_partial ON orders (order_time) 
WHERE status = 'paid';
```

=== Выполнение с частичным индексом

// #image("explain_plan_partial_simple.svg")
// #image("п7_2.png")


=== Код индекса B-Tree (частичный покрывающий)

```sql
DROP INDEX IF EXISTS idx_orders_paid_partial_covering;
CREATE INDEX idx_orders_paid_partial_covering ON orders (order_time) 
INCLUDE (guest_id, table_id, total_amount) 
WHERE status = 'paid';
```

=== Выполнение с частичным покрывающим индексом

// #image("explain_plan_partial_covering.svg")
// #image("п7_3.png")


== Дополнительные типы запросов

=== Запросы с соединениями таблиц

==== JOIN с составным индексом

```sql
SELECT g.last_name, g.first_name, o.order_time, o.total_amount
FROM guests g
JOIN orders o ON g.id = o.guest_id
WHERE g.last_name = 'Иванов' AND o.order_time >= '2025-11-01';
```

// #image("explain_plan_join_1.svg")

==== JOIN с покрывающим индексом

```sql
SELECT d.name, d.price, oi.quantity
FROM dishes d
JOIN order_items oi ON d.id = oi.dish_id
WHERE d.category = 'Main';
```

// #image("explain_plan_join_2.svg")

=== Фильтрация с предикатами

==== EXISTS

```sql
SELECT guest_id, status FROM guests g
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.guest_id = g.id AND o.status = 'paid'
);
```

// #image("explain_plan_exists.svg")

==== IN

```sql
SELECT category FROM dishes
WHERE category IN ('Main', 'Dessert', 'Starter');
```

// #image("explain_plan_in.svg")

==== BETWEEN

```sql
SELECT order_time FROM orders
WHERE order_time BETWEEN '2025-11-01' AND '2025-11-30';
```


// #image("explain_plan_between.svg")

=== Функции для работы со строками

==== SUBSTRING

```sql
DROP INDEX IF EXISTS idx_dishes_name_substr;
CREATE INDEX idx_dishes_name_substr ON dishes (SUBSTRING(name, 1, 5));

SELECT name FROM dishes
WHERE SUBSTRING(name, 1, 5) = 'Цезар';
```

// #image("explain_plan_substring.svg")

=== Функции даты и времени

==== DATE_TRUNC с временной зоной

```sql
SELECT date_trunc('hour', order_time AT TIME ZONE 'Europe/Moscow') AS order_hour,
       COUNT(*) as orders_count
FROM orders
WHERE order_time >= '2025-11-01'
GROUP BY order_hour;
```

// #image("explain_plan_date_trunc.svg")

=== Агрегатные функции и GROUP BY

==== Агрегация с частичным покрывающим индексом

```sql 
SELECT guest_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
FROM orders
WHERE status = 'paid'
GROUP BY guest_id
HAVING SUM(total_amount) > 5000;
```

// #image("explain_plan_aggregate.svg")

=== Вложенные запросы

==== Коррелированный подзапрос

```sql
SELECT g.last_name, g.first_name,
       (SELECT COUNT(*) FROM orders o 
        WHERE o.guest_id = g.id AND o.status = 'paid') as paid_orders
FROM guests g
WHERE total_orders > 10;
```

// #image("explain_plan_subquery.svg")

=== UNION и INTERSECT

==== UNION с покрывающими индексами

```sql
SELECT name, price FROM dishes WHERE category = 'Main'
UNION
SELECT name, price FROM dishes WHERE category = 'Dessert';
```

// #image("explain_plan_union.svg")

==== INTERSECT с частичными индексами

```sql
SELECT guest_id FROM orders WHERE status = 'paid' AND order_time >= '2025-11-01'
INTERSECT
SELECT guest_id FROM orders WHERE status = 'paid' AND total_amount > 2000;
```

// #image("explain_plan_intersect.svg")

== Выводы

В ходе тестирования были продемонстрированы следующие типы индексов и их эффективность:

1. *Простые индексы* (B-Tree и Hash) - значительно ускоряют поиск по одному столбцу.

2. *Уникальные индексы* - обеспечивают уникальность данных и быстрый поиск.

3. *Составные индексы* - эффективны для запросов с условиями по нескольким столбцам.

4. *Индексы с выражениями* - позволяют индексировать результаты функций.

5. *Покрывающие индексы* - обеспечивают Index Only Scan, исключая обращения к таблице.

6. *Частичные индексы* - уменьшают размер индекса и ускоряют запросы с постоянным условием.

7. *Частичные покрывающие индексы* - комбинируют преимущества частичных и покрывающих индексов.

Все типы индексов показали значительное улучшение производительности по сравнению с последовательным сканированием таблиц.