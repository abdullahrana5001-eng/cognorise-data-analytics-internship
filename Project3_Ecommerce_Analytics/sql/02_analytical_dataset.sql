-- =====================================================================
-- 02_analytical_dataset.sql  |  Star schema + the two Power BI datasets
-- Input : clean_orders (from 01_data_cleaning.sql)
-- Output: dim_product, dim_customer_profile, dim_shipping, dim_season,
--         fact_order_line, ds_analytical (58,050 rows), ds_price_discount (150 rows)
-- Business definitions
--   gross revenue      = list price
--   discount amount    = price x discount%
--   net revenue        = price x (1 - discount%)          (tax excluded, pass-through)
--   returns loss       = net revenue x return rate%       (expected refunded value)
--   contribution profit= net revenue - returns loss - shipping cost
--                        (PROXY: the source has no unit cost / COGS)
-- Grain: 1 row = 1 order line = 1 order (source has no order id)
-- =====================================================================

-- ---------- Dimensions ----------
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product AS
SELECT ROW_NUMBER() OVER (ORDER BY category, product_name) AS product_key,
       category, product_name
FROM (SELECT DISTINCT category, product_name FROM clean_orders);

DROP TABLE IF EXISTS dim_customer_profile;
CREATE TABLE dim_customer_profile AS
SELECT ROW_NUMBER() OVER (ORDER BY location, age_group, gender) AS profile_key,
       age_group, gender, location,
       TRIM(SUBSTR(location, 1, INSTR(location, ',') - 1)) AS city,
       TRIM(SUBSTR(location, INSTR(location, ',') + 1))    AS country,
       age_group || ' | ' || gender || ' | ' || location   AS customer_profile_key
FROM (SELECT DISTINCT age_group, gender, location FROM clean_orders);

DROP TABLE IF EXISTS dim_shipping;
CREATE TABLE dim_shipping AS
SELECT ROW_NUMBER() OVER (ORDER BY shipping_method) AS shipping_key, shipping_method
FROM (SELECT DISTINCT shipping_method FROM clean_orders);

DROP TABLE IF EXISTS dim_season;
CREATE TABLE dim_season AS
SELECT ROW_NUMBER() OVER (ORDER BY seasonal_flag) AS season_key, seasonal_flag,
       CASE WHEN seasonal_flag = 'Yes' THEN 'Seasonal product' ELSE 'Non-seasonal product' END AS season_label
FROM (SELECT DISTINCT seasonal_flag FROM clean_orders);

-- ---------- Fact table (one row per order) ----------
DROP TABLE IF EXISTS fact_order_line;
CREATE TABLE fact_order_line AS
SELECT ROW_NUMBER() OVER ()                                   AS order_id,
       p.product_key, c.profile_key, s.shipping_key, z.season_key,
       o.price                                                AS gross_revenue,
       o.price * o.discount_pct / 100.0                       AS discount_amount,
       o.price * (1 - o.discount_pct / 100.0)                 AS net_revenue,
       o.price * (1 - o.discount_pct / 100.0) * o.tax_rate_pct / 100.0 AS tax_amount,
       o.price * (1 - o.discount_pct / 100.0) * o.return_rate_pct / 100.0 AS returns_loss,
       o.shipping_cost,
       o.price * (1 - o.discount_pct / 100.0) * (1 - o.return_rate_pct / 100.0) - o.shipping_cost AS contribution_profit,
       o.discount_pct, o.return_rate_pct, o.popularity_index, o.stock_level
FROM clean_orders o
JOIN dim_product p          ON p.category = o.category AND p.product_name = o.product_name
JOIN dim_customer_profile c ON c.age_group = o.age_group AND c.gender = o.gender AND c.location = o.location
JOIN dim_shipping s         ON s.shipping_method = o.shipping_method
JOIN dim_season z           ON z.seasonal_flag = o.seasonal_flag;

-- ---------- Power BI dataset 1: ds_analytical (additive groups) ----------
DROP TABLE IF EXISTS ds_analytical;
CREATE TABLE ds_analytical AS
SELECT category, product_name, age_group, gender, location,
       TRIM(SUBSTR(location, 1, INSTR(location, ',') - 1)) AS city,
       TRIM(SUBSTR(location, INSTR(location, ',') + 1))    AS country,
       age_group || ' | ' || gender || ' | ' || location   AS customer_profile_key,
       shipping_method, seasonal_flag,
       COUNT(*)                                            AS orders,
       SUM(price)                                          AS gross_revenue,
       SUM(price * discount_pct / 100.0)                   AS discount_amount,
       SUM(price * (1 - discount_pct / 100.0))             AS net_revenue,
       SUM(price * (1 - discount_pct / 100.0) * tax_rate_pct / 100.0)    AS tax_amount,
       SUM(price * (1 - discount_pct / 100.0) * return_rate_pct / 100.0) AS returns_loss,
       SUM(shipping_cost)                                  AS shipping_cost,
       SUM(price * (1 - discount_pct / 100.0) * (1 - return_rate_pct / 100.0) - shipping_cost) AS contribution_profit,
       SUM(return_rate_pct)                                AS sum_return_rate_pct,
       SUM(discount_pct)                                   AS sum_discount_pct,
       SUM(popularity_index)                               AS sum_popularity_index,
       SUM((price * (1 - discount_pct / 100.0) * (1 - return_rate_pct / 100.0) - shipping_cost) *
           (price * (1 - discount_pct / 100.0) * (1 - return_rate_pct / 100.0) - shipping_cost)) AS sum_profit_sq
FROM clean_orders
GROUP BY category, product_name, age_group, gender, location, shipping_method, seasonal_flag;

-- ---------- Power BI dataset 2: ds_price_discount (price band x discount tier) ----------
DROP TABLE IF EXISTS ds_price_discount;
CREATE TABLE ds_price_discount AS
WITH o AS (
  SELECT category,
         CASE WHEN price < 250  THEN '1: <250'
              WHEN price < 500  THEN '2: 250-499'
              WHEN price < 1000 THEN '3: 500-999'
              WHEN price < 1500 THEN '4: 1000-1499'
              ELSE '5: 1500+' END AS price_band,
         discount_pct, price, return_rate_pct, shipping_cost,
         price * (1 - discount_pct / 100.0)                                   AS net,
         price * (1 - discount_pct / 100.0) * return_rate_pct / 100.0          AS ret_loss,
         price * (1 - discount_pct / 100.0) * (1 - return_rate_pct / 100.0) - shipping_cost AS profit
  FROM clean_orders)
SELECT category, price_band, discount_pct,
       COUNT(*)                                   AS orders,
       SUM(price)                                 AS gross_revenue,
       SUM(price - net)                           AS discount_amount,
       SUM(net)                                   AS net_revenue,
       SUM(ret_loss)                              AS returns_loss,
       SUM(shipping_cost)                         AS shipping_cost,
       SUM(profit)                                AS contribution_profit,
       SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END)                AS loss_making_orders,
       SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END)           AS loss_total,
       SUM(CASE WHEN profit < 0 THEN price ELSE 0 END)            AS loss_gross,
       SUM(CASE WHEN profit < 0 THEN shipping_cost ELSE 0 END)    AS loss_ship,
       SUM(CASE WHEN profit < 0 THEN return_rate_pct ELSE 0 END)  AS loss_retpct,
       SUM(CASE WHEN profit < 0 THEN discount_pct ELSE 0 END)     AS loss_discpct,
       SUM(price * (1 - return_rate_pct / 100.0))                 AS gross_keep
FROM o
GROUP BY category, price_band, discount_pct;

CREATE INDEX IF NOT EXISTS ix_fact_product ON fact_order_line(product_key);
CREATE INDEX IF NOT EXISTS ix_fact_profile ON fact_order_line(profile_key);

SELECT 'ds_analytical rows' AS item, COUNT(*) AS n FROM ds_analytical
UNION ALL SELECT 'ds_price_discount rows', COUNT(*) FROM ds_price_discount
UNION ALL SELECT 'fact_order_line rows', COUNT(*) FROM fact_order_line;
