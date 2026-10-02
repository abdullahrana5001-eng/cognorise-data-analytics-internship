-- =====================================================================
-- 04_additional_analysis.sql  |  Profit drivers, discount economics, loss-making orders
-- Input: ds_price_discount, ds_analytical (02_analytical_dataset.sql)
-- =====================================================================

-- 1. Price-band economics (where does margin break?) ---------------------
DROP VIEW IF EXISTS drv_price_band;
CREATE VIEW drv_price_band AS
SELECT price_band,
       SUM(orders) AS orders, SUM(net_revenue) AS net_revenue,
       SUM(net_revenue) / SUM(orders) AS aov,
       SUM(contribution_profit) / SUM(net_revenue) AS margin_pct,
       SUM(shipping_cost) / SUM(net_revenue)       AS shipping_pct,
       SUM(returns_loss)  / SUM(net_revenue)       AS returns_loss_pct,
       SUM(loss_making_orders) * 1.0 / SUM(orders) AS pct_loss_making_orders
FROM ds_price_discount GROUP BY price_band ORDER BY price_band;

-- 2. Discount-tier economics ---------------------------------------------
DROP VIEW IF EXISTS drv_discount_tier;
CREATE VIEW drv_discount_tier AS
SELECT discount_pct, SUM(orders) AS orders, SUM(net_revenue) AS net_revenue,
       SUM(contribution_profit) / SUM(orders) AS profit_per_order,
       SUM(contribution_profit) / SUM(net_revenue) AS margin_pct,
       SUM(discount_amount) AS discount_cost
FROM ds_price_discount GROUP BY discount_pct ORDER BY discount_pct;

-- 3. Break-even volume uplift: extra orders a discount needs to match the
--    profit of a full-price (0%) order.
DROP VIEW IF EXISTS drv_breakeven_uplift;
CREATE VIEW drv_breakeven_uplift AS
WITH t AS (SELECT discount_pct, profit_per_order FROM drv_discount_tier),
     base AS (SELECT profit_per_order AS p0 FROM t WHERE discount_pct = 0)
SELECT t.discount_pct,
       ROUND(t.profit_per_order, 2) AS profit_per_order,
       ROUND(base.p0 / t.profit_per_order - 1, 4) AS breakeven_volume_uplift
FROM t, base ORDER BY t.discount_pct;

-- 4. Loss-making orders by price band -------------------------------------
DROP VIEW IF EXISTS drv_loss_making;
CREATE VIEW drv_loss_making AS
SELECT price_band, SUM(loss_making_orders) AS loss_making_orders,
       SUM(loss_total) AS total_loss, SUM(loss_ship) AS shipping_on_loss_orders,
       SUM(loss_gross) AS list_value_of_loss_orders
FROM ds_price_discount GROUP BY price_band ORDER BY price_band;

-- 5. What-if levers (profit uplift, upper bounds - levers overlap, do NOT add) ----
DROP VIEW IF EXISTS scn_levers;
CREATE VIEW scn_levers AS
SELECT 'Cut return rate by 1 pt'                 AS lever, SUM(net_revenue) * 0.01 AS profit_uplift FROM ds_price_discount
UNION ALL
SELECT 'Cap discount at 15% (no volume change)', SUM(CASE WHEN discount_pct > 15 THEN (discount_pct - 15) / 100.0 * gross_keep ELSE 0 END) FROM ds_price_discount
UNION ALL
SELECT 'Recover 50% of shipping cost on orders < 250', 0.5 * SUM(shipping_cost) FROM ds_price_discount WHERE price_band = '1: <250'
UNION ALL
SELECT 'Eliminate loss-making orders (min. basket rule)', -SUM(loss_total) FROM ds_price_discount;

-- 6. Product x category share check: orders per product (assortment effect) ------
DROP VIEW IF EXISTS drv_orders_per_product;
CREATE VIEW drv_orders_per_product AS
SELECT category, COUNT(DISTINCT product_name) AS products, SUM(orders) AS orders,
       ROUND(SUM(orders) * 1.0 / COUNT(DISTINCT product_name), 0) AS orders_per_product
FROM ds_analytical GROUP BY category ORDER BY orders_per_product DESC;

-- =====================================================================
-- VIEW THE RESULTS (run one line at a time: select the line, press Ctrl+Return)
-- SELECT * FROM drv_price_band;
-- SELECT * FROM drv_discount_tier;
-- SELECT * FROM drv_breakeven_uplift;
-- SELECT * FROM drv_loss_making;
-- SELECT * FROM scn_levers;
-- SELECT * FROM drv_orders_per_product;
