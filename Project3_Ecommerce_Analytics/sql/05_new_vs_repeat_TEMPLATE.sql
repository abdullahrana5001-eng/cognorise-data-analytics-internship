-- =====================================================================
-- 05_new_vs_repeat_TEMPLATE.sql   (TEMPLATE - not runnable on the current source)
-- The current source file has NO customer_id and NO order_date, so a true
-- "new vs repeat customer" split cannot be computed without inventing data.
-- If a dataset WITH those two fields is used (e.g. the 1,000-row online retail sets on Kaggle),
-- load it as  orders(customer_id, order_id, order_date, net_revenue)  and run this.
-- =====================================================================
WITH first_order AS (
  SELECT customer_id, MIN(order_date) AS first_date FROM orders GROUP BY customer_id),
tagged AS (
  SELECT o.*, CASE WHEN o.order_date = f.first_date THEN 'New' ELSE 'Repeat' END AS customer_type
  FROM orders o JOIN first_order f USING (customer_id))
SELECT strftime('%Y-%m', order_date) AS month, customer_type,
       COUNT(DISTINCT customer_id) AS customers, COUNT(*) AS orders, SUM(net_revenue) AS net_revenue
FROM tagged GROUP BY 1, 2 ORDER BY 1, 2;

-- Purchase-frequency distribution
SELECT orders_per_customer, COUNT(*) AS customers
FROM (SELECT customer_id, COUNT(*) AS orders_per_customer FROM orders GROUP BY customer_id)
GROUP BY orders_per_customer ORDER BY 1;
