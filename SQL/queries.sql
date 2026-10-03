-- =====================================================================
-- Аналіз продажів піцерії (Нью-Джерсі, 2015 рік)
-- СУБД: SQLite
-- Таблиці: orders, order_details, pizzas, pizza_types
-- =====================================================================


-- 0. Огляд таблиць (перші 10 рядків)

SELECT * FROM orders        LIMIT 10;
SELECT * FROM order_details LIMIT 10;
SELECT * FROM pizzas        LIMIT 10;
SELECT * FROM pizza_types   LIMIT 10;

-- Кількість рядків у кожній таблиці
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'order_details', COUNT(*) FROM order_details
UNION ALL
SELECT 'pizzas', COUNT(*) FROM pizzas
UNION ALL
SELECT 'pizza_types', COUNT(*) FROM pizza_types;


-- 1. Загальні показники за рік: виручка, кількість замовлень, кількість
--    проданих піц, середній чек, середня кількість піц у замовленні.

SELECT
  ROUND(SUM(od.quantity * p.price), 2) AS total_revenue,
  COUNT(DISTINCT o.order_id) AS total_orders,
  SUM(od.quantity) AS total_pizzas_sold,
  ROUND(SUM(od.quantity * p.price) / COUNT(DISTINCT o.order_id), 2) AS avg_check,
  ROUND(CAST(SUM(od.quantity) AS REAL) / COUNT(DISTINCT o.order_id), 2) AS avg_pizzas_per_order
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id;


-- 2. Динаміка по місяцях: виручка, кількість замовлень та зміна виручки
--    до попереднього місяця у відсотках (для січня значення NULL).

WITH monthly_sales AS (
  SELECT
    strftime('%m', o.date) AS month,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
  FROM orders o
  JOIN order_details od ON o.order_id = od.order_id
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  GROUP BY month
)
SELECT
  month,
  revenue,
  total_orders,
  ROUND(
    (revenue - LAG(revenue, 1) OVER (ORDER BY month))
    / LAG(revenue, 1) OVER (ORDER BY month) * 100, 2
  ) AS revenue_growth_pct
FROM monthly_sales;


-- 3. Навантаження за днями тижня та годинами: коли пік, а коли тихо?

-- 3а. Середня кількість замовлень за один понеділок, вівторок і так далі
SELECT
  strftime('%w', o.date) AS weekday_num,
  CASE strftime('%w', o.date)
    WHEN '0' THEN 'Неділя'
    WHEN '1' THEN 'Понеділок'
    WHEN '2' THEN 'Вівторок'
    WHEN '3' THEN 'Середа'
    WHEN '4' THEN 'Четвер'
    WHEN '5' THEN 'П"ятниця'
    WHEN '6' THEN 'Субота'
  END AS weekday_name,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(DISTINCT o.date) AS total_days_count,
  ROUND(CAST(COUNT(DISTINCT o.order_id) AS REAL) / COUNT(DISTINCT o.date), 2) AS avg_orders_per_day
FROM orders o
GROUP BY weekday_num, weekday_name
ORDER BY weekday_num;

-- 3б. Замовлення за днем тижня та годиною (за рік)
SELECT
  strftime('%w', o.date) AS weekday_num,
  CASE strftime('%w', o.date)
    WHEN '0' THEN 'Неділя'
    WHEN '1' THEN 'Понеділок'
    WHEN '2' THEN 'Вівторок'
    WHEN '3' THEN 'Середа'
    WHEN '4' THEN 'Четвер'
    WHEN '5' THEN 'П"ятниця'
    WHEN '6' THEN 'Субота'
  END AS weekday_name,
  strftime('%H', o.time) AS order_hour,
  COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
GROUP BY weekday_num, order_hour
ORDER BY total_orders DESC;

-- 3в. Замовлення за годиною (перевірка робочих годин: 09, 10 і 23 майже порожні)
SELECT
  strftime('%H', time) AS hour,
  COUNT(DISTINCT order_id) AS orders
FROM orders
GROUP BY hour
ORDER BY hour;


-- 4. Бестселери та аутсайдери: топ-5 і останні 5 піц за виручкою та за
--    кількістю (на рівні назви піци, усі розміри разом).

-- 4а. Останні 5 за виручкою
SELECT
  pt.name AS pizza_name,
  ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_revenue ASC
LIMIT 5;

-- 4б. Останні 5 за кількістю
SELECT
  pt.name AS pizza_name,
  SUM(od.quantity) AS total_pizzas_sold
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_pizzas_sold ASC
LIMIT 5;

-- 4в. Топ-5 за виручкою
SELECT
  pt.name AS pizza_name,
  ROUND(SUM(od.quantity * p.price), 2) AS total_revenue
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_revenue DESC
LIMIT 5;

-- 4г. Топ-5 за кількістю
SELECT
  pt.name AS pizza_name,
  SUM(od.quantity) AS total_pizzas_sold
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name
ORDER BY total_pizzas_sold DESC
LIMIT 5;


-- 5. Категорії та розміри: частка виручки кожної категорії та розміру.

-- 5а. Частка виручки кожної категорії
WITH category_sales AS (
  SELECT
    pt.category,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue
  FROM order_details od
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
  GROUP BY pt.category
),
total_sales AS (
  SELECT SUM(revenue) AS total_rev
  FROM category_sales
)
SELECT
  cs.category,
  cs.revenue,
  ROUND((cs.revenue * 100.0 / ts.total_rev), 2) AS revenue_share_pct
FROM category_sales cs
CROSS JOIN total_sales AS ts
ORDER BY revenue_share_pct DESC;

-- 5б. Частка виручки кожного розміру
WITH size_sales AS (
  SELECT
    p.size,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue
  FROM order_details od
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  GROUP BY p.size
),
total_sales AS (
  SELECT SUM(revenue) AS total_rev
  FROM size_sales
)
SELECT
  ss.size,
  ss.revenue,
  ROUND((ss.revenue * 100.0 / ts.total_rev), 2) AS revenue_share_pct
FROM size_sales ss
CROSS JOIN total_sales AS ts
ORDER BY revenue_share_pct DESC;


-- 6. Кандидати на вилучення з меню: найменша виручка й найменші продажі.
--    ★ Накопичувальна частка виручки.

-- 6а. П'ять піц із найменшою виручкою: продажі, частка й накопичувальна частка
WITH pizza_stats AS (
  SELECT
    pt.name AS pizza_name,
    SUM(od.quantity) AS pizzas_sold,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue
  FROM order_details od
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
  GROUP BY pt.name
),
total AS (
  SELECT SUM(revenue) AS total_rev
  FROM pizza_stats
)
SELECT
  ps.pizza_name,
  ps.pizzas_sold,
  ps.revenue,
  ROUND(ps.revenue * 100.0 / t.total_rev, 2) AS share_pct,
  ROUND(SUM(ps.revenue) OVER (ORDER BY ps.revenue ASC) * 100.0 / t.total_rev, 2) AS cumulative_share_pct
FROM pizza_stats ps
CROSS JOIN total AS t
ORDER BY ps.revenue ASC
LIMIT 5;

-- 6б. Три піци, слабкі і за виручкою, і за кількістю (перетин списків 4а і 4б):
--     скільки виручки та продажів це зачіпає
WITH pizza_stats AS (
  SELECT
    pt.name AS pizza_name,
    SUM(od.quantity) AS pizzas_sold,
    ROUND(SUM(od.quantity * p.price), 2) AS revenue
  FROM order_details od
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
  GROUP BY pt.name
)
SELECT
  ROUND(SUM(revenue), 2) AS removed_revenue,
  ROUND(SUM(revenue) * 100.0 / (SELECT SUM(revenue) FROM pizza_stats), 2) AS removed_share_pct,
  SUM(pizzas_sold) AS removed_pizzas
FROM pizza_stats
WHERE pizza_name IN ('The Brie Carre Pizza', 'The Spinach Supreme Pizza', 'The Mediterranean Pizza');


-- 7. Великі замовлення: частка замовлень із 4 і більше піц (сума quantity)
--    та її частка у виручці.

WITH order_summary AS (
  SELECT
    od.order_id,
    SUM(od.quantity) AS total_qty,
    SUM(od.quantity * p.price) AS total_revenue
  FROM order_details AS od
  JOIN pizzas AS p ON od.pizza_id = p.pizza_id
  GROUP BY od.order_id
),
categorized_orders AS (
  SELECT
    order_id,
    total_revenue,
    CASE
      WHEN total_qty >= 4 THEN 'Large (4+)'
      ELSE 'Normal (<4)'
    END AS order_category
  FROM order_summary
)
SELECT
  order_category,
  COUNT(order_id) AS order_count,
  ROUND(SUM(total_revenue), 2) AS category_revenue,
  ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM categorized_orders), 2) AS orders_share_pct,
  ROUND(SUM(total_revenue) * 100.0 / (SELECT SUM(total_revenue) FROM categorized_orders), 2) AS revenue_share_pct
FROM categorized_orders
GROUP BY order_category;


-- 8. Акція: у які дні й години її запустити та який потенціал.

-- 8а. Найслабші вікна «день тижня + година» серед вікон із достатнім
--     обсягом (поріг: не менше 50 замовлень за рік, щоб відсікти
--     випадкові замовлення поза робочим часом)
WITH windows AS (
  SELECT
    strftime('%w', o.date) AS weekday_num,
    CASE strftime('%w', o.date)
      WHEN '0' THEN 'Неділя'
      WHEN '1' THEN 'Понеділок'
      WHEN '2' THEN 'Вівторок'
      WHEN '3' THEN 'Середа'
      WHEN '4' THEN 'Четвер'
      WHEN '5' THEN 'П"ятниця'
      WHEN '6' THEN 'Субота'
    END AS day_name,
    strftime('%H', o.time) AS hour_of_day,
    COUNT(DISTINCT o.order_id) AS orders_count,
    COUNT(DISTINCT o.date) AS days_count,
    ROUND(SUM(od.quantity * p.price), 2) AS window_revenue
  FROM orders o
  JOIN order_details od ON o.order_id = od.order_id
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  GROUP BY weekday_num, day_name, hour_of_day
)
SELECT
  day_name,
  hour_of_day,
  orders_count,
  days_count,
  window_revenue,
  ROUND(window_revenue * 0.10, 2) AS plus_10_pct_per_year,
  ROUND(window_revenue * 0.10 / days_count, 2) AS plus_10_pct_per_day
FROM windows
WHERE orders_count >= 50
ORDER BY window_revenue ASC
LIMIT 10;

-- 8б. Об'єднане вікно «неділя–четвер, 22:00»: поточна виручка й ефект +10%
SELECT
  COUNT(DISTINCT o.order_id) AS orders_count,
  ROUND(SUM(od.quantity * p.price), 2) AS window_revenue,
  ROUND(SUM(od.quantity * p.price) * 0.10, 2) AS plus_10_pct
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id
WHERE strftime('%w', o.date) IN ('0', '1', '2', '3', '4')
  AND strftime('%H', o.time) = '22';


-- 9. Об'єднання чотирьох таблиць (sales_lines) для Tableau

-- 9а. Перевірка: кількість рядків після з'єднання має дорівнювати
--     кількості рядків у order_details (48 620)
SELECT COUNT(*) AS total_rows
FROM (
  SELECT
    o.order_id,
    od.order_details_id
  FROM orders o
  JOIN order_details od ON o.order_id = od.order_id
  JOIN pizzas p ON od.pizza_id = p.pizza_id
  JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
) AS sales_lines;

-- 9б. Таблиця sales_lines (експортується в CSV для Tableau)
SELECT
  o.order_id,
  o.date,
  o.time,
  od.order_details_id,
  od.quantity,
  p.pizza_id,
  p.price,
  p.size,
  pt.pizza_type_id,
  pt.name AS pizza_name,
  pt.category
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id;
