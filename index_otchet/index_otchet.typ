#align(center + horizon)[
  #set text(font: ("Times New Roman", "Liberation Serif"))
  
  #v(2cm)
  
  #text(size: 16pt, weight: "bold")[
    ОТЧЕТ ПО ТЕСТИРОВАНИЮ
  ]
  #v(0.5cm)
  #text(size: 16pt, weight: "bold")[
    ИНДЕКСОВ В POSTGRESQL
  ]
  
  #v(4cm)
  
  #align(right)[
    #text(size: 14pt)[Выполнил:] \
    #text(size: 14pt, weight: "bold")[Карасев Вадим Дмитриевич]
    
    #v(0.8cm)
    
    #text(size: 14pt)[Группа:] \
    #text(size: 14pt, weight: "bold")[351]
    
    #v(0.8cm)
    
    #text(size: 14pt)[Проверил:] \
    #text(size: 14pt, weight: "bold")[М. И. Сафрончик]
  ]
  
  #v(5cm)
  
  #text(size: 14pt)[Саратов 2025]
]

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


= Простые индексы

== Код запроса

```sql
SELECT last_name FROM guests WHERE last_name = 'Иванов';
```

== Выполнение без индексов

#image("image1-1.png")
#image("image1-2.png")

== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_guests_lastname;
CREATE INDEX idx_guests_lastname ON guests USING BTREE (last_name);
```

== Выполнение с индексами B-Tree

#image("image2-1.png")
#image("image2-2.png")

== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_guests_lastname_hash;
CREATE INDEX idx_guests_lastname_hash ON guests USING HASH (last_name);
```

== Выполнение с индексами Hash

#image("image3-1.png")
#image("image3-2.png")

= Уникальный индекс

== Код запроса

```sql
SELECT id, first_name, last_name, birth_date 
FROM guests 
WHERE id = 100;
```

== Выполнение без индексов

#image("image4-1.png")
#image("image4-2.png")

== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_guests_id_unique;
CREATE UNIQUE INDEX idx_guests_id_unique 
ON guests USING BTREE (id)
INCLUDE (first_name, last_name, birth_date);
```

== Выполнение с индексами B-Tree

#image("image5-1.png")
#image("image5-2.png")

= Составной индекс

== Код запроса

```sql
SELECT guest_id, order_time FROM orders WHERE guest_id = 100 AND order_time >= '2025-11-01';
```

== Выполнение без индексов

#image("image6-1.png")
#image("image6-2.png")

== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_orders_guest_time;
CREATE INDEX idx_orders_guest_time ON orders USING BTREE (guest_id, order_time);
```

== Выполнение с индексами B-Tree

#image("image7-1.png")
#image("image7-2.png")

= Индексы с использованием выражений

== Код запроса

```sql
SELECT birth_date FROM guests WHERE DATE_PART('year', birth_date) = 1990;
```

== Выполнение без индексов

#image("image8-1.png")
#image("image8-2.png")

== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_guests_birth_year;
CREATE INDEX idx_guests_birth_year ON guests USING BTREE (DATE_PART('year', birth_date));
```

== Выполнение с индексами B-Tree

#image("image9-1.png")
#image("image9-2.png")

== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_guests_birth_year_hash;
CREATE INDEX idx_guests_birth_year_hash ON guests USING HASH (DATE_PART('year', birth_date));
```

== Выполнение с индексами Hash

#image("image10-1.png")
#image("image10-2.png")

= Покрывающий индекс

== Код запроса

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT * FROM orders WHERE order_time = '2025-11-01';
```

== Выполнение без индексов

#image("image11-1.png")
#image("image11-2.png")

== Код индекса B-Tree

```sql
CREATE INDEX idx_orders_time_covering ON orders USING BTREE (order_time) 
INCLUDE (guest_id, table_id, waiter_id, total_amount, status);
```

== Выполнение с индексами B-Tree

#image("image12-1.png")
#image("image12-2.png")

= Частичный индекс

== Код запроса

```sql
SELECT status, order_time FROM orders WHERE status = 'paid' AND guest_id = 100;
```

== Выполнение без индексов

#image("image13-1.png")
#image("image13-2.png")

== Код индекса B-Tree

```sql
DROP INDEX IF EXISTS idx_orders_paid;
CREATE INDEX idx_orders_paid ON orders USING BTREE (guest_id) 
WHERE status = 'paid' AND guest_id = 100;
```

== Выполнение с индексами B-Tree

#image("image14-1.png")
#image("image14-2.png")

== Код индекса Hash

```sql
DROP INDEX IF EXISTS idx_orders_paid_status_hash;
CREATE INDEX idx_orders_paid_status_hash ON orders USING HASH (guest_id) 
WHERE status = 'paid';
```

== Выполнение с индексами Hash

#image("image15-1.png")
#image("image15-2.png")

= Частичный покрывающий индекс

== Код запроса

```sql
SELECT guest_id, table_id, total_amount FROM orders 
WHERE status = 'paid' AND order_time >= '2025-11-01';
```

== Выполнение без индексов

#image("image16-1.png")
#image("image16-2.png")

== Код индекса B-Tree (частичный)

```sql
DROP INDEX IF EXISTS idx_orders_paid_partial;
CREATE INDEX idx_orders_paid_covering ON orders (order_time) 
INCLUDE (guest_id, table_id, total_amount) 
WHERE status = 'paid';
```

== Выполнение с частичным индексом

#image("image17-1.png")
#image("image17-2.png")


== Код индекса B-Tree (частичный покрывающий)

```sql
DROP INDEX IF EXISTS idx_orders_paid_partial_covering;
CREATE INDEX idx_orders_paid_partial_covering ON orders (order_time) 
INCLUDE (guest_id, table_id, total_amount) 
WHERE status = 'paid';
```

== Выполнение с частичным покрывающим индексом

#image("image18-1.png")
#image("image18-2.png")


// = Дополнительные типы запросов

// == Запросы с соединениями таблице

// === JOIN с составным индексом

// ```sql
// SELECT g.last_name, g.first_name, o.order_time, o.total_amount
// FROM guests g
// JOIN orders o ON g.id = o.guest_id
// WHERE g.last_name = 'Иванов' AND o.order_time >= '2025-11-01';
// ```

// #image("1.png")

// === JOIN с покрывающим индексом

// ```sql
// SELECT d.name, d.price, oi.quantity
// FROM dishes d
// JOIN order_items oi ON d.id = oi.dish_id
// WHERE d.category = 'Main';
// ```

// #image("2.png")

// == Фильтрация с предикатами

// === EXISTS

// ```sql
// SELECT guest_id, status FROM guests g
// WHERE EXISTS (
//     SELECT 1 FROM orders o 
//     WHERE o.guest_id = g.id AND o.status = 'paid'
// );
// ```

// #image("3.png")

// == IN

// ```sql
// SELECT category FROM dishes
// WHERE category IN ('Main', 'Dessert', 'Starter');
// ```

// #image("4.png")

// == BETWEEN

// ```sql
// SELECT order_time FROM orders
// WHERE order_time BETWEEN '2025-11-01' AND '2025-11-30';
// ```

// #image("5.png")


// = Функции для работы со строками

// == SUBSTRING

// ```sql
// DROP INDEX IF EXISTS idx_dishes_name_substr;
// CREATE INDEX idx_dishes_name_substr ON dishes (SUBSTRING(name, 1, 5));

// SELECT name FROM dishes
// WHERE SUBSTRING(name, 1, 5) = 'Цезар';
// ```

// #image("6.png")

// = Функции даты и времени

// == DATE_TRUNC с временной зоной

// ```sql
// SELECT date_trunc('hour', order_time AT TIME ZONE 'Europe/Moscow') AS order_hour,
//        COUNT(*) as orders_count
// FROM orders
// WHERE order_time >= '2025-11-01'
// GROUP BY order_hour;
// ```

// // #image("explain_plan_date_trunc.svg")

// = Агрегатные функции и GROUP BY

// == Агрегация с частичным покрывающим индексом

// ```sql 
// SELECT guest_id, COUNT(*) as order_count, SUM(total_amount) as total_spent
// FROM orders
// WHERE status = 'paid'
// GROUP BY guest_id
// HAVING SUM(total_amount) > 5000;
// ```

// // #image("explain_plan_aggregate.svg")

// = Вложенные запросы

// == Коррелированный подзапрос

// ```sql
// SELECT g.last_name, g.first_name,
//        (SELECT COUNT(*) FROM orders o 
//         WHERE o.guest_id = g.id AND o.status = 'paid') as paid_orders
// FROM guests g
// WHERE total_orders > 10;
// ```

// // #image("explain_plan_subquery.svg")

// = UNION и INTERSECT

// == UNION с покрывающими индексами

// ```sql
// SELECT name, price FROM dishes WHERE category = 'Main'
// UNION
// SELECT name, price FROM dishes WHERE category = 'Dessert';
// ```

// // #image("explain_plan_union.svg")

// == INTERSECT с частичными индексами

// ```sql
// SELECT guest_id FROM orders WHERE status = 'paid' AND order_time >= '2025-11-01'
// INTERSECT
// SELECT guest_id FROM orders WHERE status = 'paid' AND total_amount > 2000;
// ```

// // #image("explain_plan_intersect.svg")

= Выводы

В ходе тестирования были продемонстрированы следующие типы индексов и их эффективность:

1. *Простые индексы* (B-Tree и Hash) - значительно ускоряют поиск по одному столбцу.

2. *Уникальные индексы* - обеспечивают уникальность данных и быстрый поиск.

3. *Составные индексы* - эффективны для запросов с условиями по нескольким столбцам.

4. *Индексы с выражениями* - позволяют индексировать результаты функций.

5. *Покрывающие индексы* - обеспечивают Index Only Scan, исключая обращения к таблице.

6. *Частичные индексы* - уменьшают размер индекса и ускоряют запросы с постоянным условием.

7. *Частичные покрывающие индексы* - комбинируют преимущества частичных и покрывающих индексов.

Все типы индексов показали значительное улучшение производительности по сравнению с последовательным сканированием таблиц.