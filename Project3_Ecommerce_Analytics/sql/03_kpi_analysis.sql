-- =====================================================================
-- 03_kpi_analysis.sql  |  KPIs and performance by product, category, region, time
-- Input: fact_order_line + dimensions (02_analytical_dataset.sql)
-- Each block is a VIEW - run  SELECT * FROM <view_name>;  to see the result.
-- =====================================================================

-- 1. Overall executive KPIs -------------------------------------------
DROP VIEW IF EXISTS kpi_overall;
CREATE VIEW kpi_overall AS
SELECT COUNT(*)                                   AS orders,
       SUM(gross_revenue)                         AS gross_revenue,
       SUM(discount_amount)                       AS discounts,
       SUM(net_revenue)                           AS net_revenue,
       SUM(tax_amount)                            AS tax_collected,
       SUM(returns_loss)                          AS returns_loss,
       SUM(shipping_cost)                         AS shipping_cost,
       SUM(contribution_profit)                   AS contribution_profit,
       SUM(net_revenue) / COUNT(*)                AS aov_net,
       SUM(gross_revenue) / COUNT(*)              AS aov_gross,
       SUM(contribution_profit) / SUM(net_revenue) AS margin_pct,
       SUM(discount_amount) / SUM(gross_revenue)  AS discount_rate,
       SUM(returns_loss) / SUM(net_revenue)       AS returns_loss_pct,
       SUM(shipping_cost) / SUM(net_revenue)      AS shipping_pct
FROM fact_order_line;

-- 2. Performance by category -------------------------------------------
DROP VIEW IF EXISTS kpi_category;
CREATE VIEW kpi_category AS
SELECT p.category,
       COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) AS contribution_profit,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct,
       SUM(f.discount_amount) / SUM(f.gross_revenue)   AS discount_rate,
       SUM(f.returns_loss) / SUM(f.net_revenue)        AS returns_loss_pct,
       SUM(f.shipping_cost) / SUM(f.net_revenue)       AS shipping_pct,
       SUM(f.net_revenue) * 1.0 / (SELECT SUM(net_revenue) FROM fact_order_line) AS revenue_share
FROM fact_order_line f JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category ORDER BY net_revenue DESC;

-- 3. Performance by product (ranked) -----------------------------------
DROP VIEW IF EXISTS kpi_product;
CREATE VIEW kpi_product AS
SELECT p.category, p.product_name,
       COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) AS contribution_profit,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct,
       AVG(f.discount_pct) AS avg_discount_pct,
       SUM(f.returns_loss) / SUM(f.net_revenue) AS returns_loss_pct,
       SUM(f.shipping_cost) / SUM(f.net_revenue) AS shipping_pct,
       RANK() OVER (ORDER BY SUM(f.net_revenue) DESC) AS revenue_rank,
       RANK() OVER (ORDER BY SUM(f.contribution_profit) / SUM(f.net_revenue) DESC) AS margin_rank
FROM fact_order_line f JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category, p.product_name;

-- 4. Performance by region (customer location) --------------------------
DROP VIEW IF EXISTS kpi_region;
CREATE VIEW kpi_region AS
SELECT c.location, c.country,
       COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) AS contribution_profit,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct
FROM fact_order_line f JOIN dim_customer_profile c ON c.profile_key = f.profile_key
GROUP BY c.location, c.country ORDER BY net_revenue DESC;

-- 5. Time dimension = seasonality flag (source has no order date) --------
DROP VIEW IF EXISTS kpi_seasonality;
CREATE VIEW kpi_seasonality AS
SELECT z.season_label, COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct,
       AVG(f.popularity_index) AS avg_popularity
FROM fact_order_line f JOIN dim_season z ON z.season_key = f.season_key
GROUP BY z.season_label;

-- 6. Shipping method ----------------------------------------------------
DROP VIEW IF EXISTS kpi_shipping;
CREATE VIEW kpi_shipping AS
SELECT s.shipping_method, COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       AVG(f.shipping_cost) AS avg_shipping_cost,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct
FROM fact_order_line f JOIN dim_shipping s ON s.shipping_key = f.shipping_key
GROUP BY s.shipping_method;

-- 7. Customer-level metrics: age and gender -------------------------------
DROP VIEW IF EXISTS kpi_customer_age;
CREATE VIEW kpi_customer_age AS
SELECT c.age_group, COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct
FROM fact_order_line f JOIN dim_customer_profile c ON c.profile_key = f.profile_key
GROUP BY c.age_group ORDER BY c.age_group;

DROP VIEW IF EXISTS kpi_customer_gender;
CREATE VIEW kpi_customer_gender AS
SELECT c.gender, COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
       SUM(f.net_revenue) / COUNT(*) AS aov,
       SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct
FROM fact_order_line f JOIN dim_customer_profile c ON c.profile_key = f.profile_key
GROUP BY c.gender;

-- 8. Customer profile (Age x Gender x Location) with purchase-frequency band
--    No customer id exists, so a profile is the lowest customer level.
DROP VIEW IF EXISTS kpi_customer_profile;
CREATE VIEW kpi_customer_profile AS
WITH prof AS (
  SELECT c.customer_profile_key, c.age_group, c.gender, c.location,
         COUNT(*) AS orders, SUM(f.net_revenue) AS net_revenue,
         SUM(f.net_revenue) / COUNT(*) AS aov,
         SUM(f.contribution_profit) / SUM(f.net_revenue) AS margin_pct
  FROM fact_order_line f JOIN dim_customer_profile c ON c.profile_key = f.profile_key
  GROUP BY c.customer_profile_key, c.age_group, c.gender, c.location)
SELECT *,
       NTILE(4) OVER (ORDER BY orders, net_revenue)  AS frequency_quartile,   -- 4 = most frequent
       RANK()   OVER (ORDER BY net_revenue DESC)     AS revenue_rank
FROM prof;

-- Purchase-frequency bands summary
DROP VIEW IF EXISTS kpi_frequency_bands;
CREATE VIEW kpi_frequency_bands AS
SELECT frequency_quartile, COUNT(*) AS profiles, SUM(orders) AS orders,
       SUM(net_revenue) AS net_revenue, SUM(net_revenue) / SUM(orders) AS aov
FROM kpi_customer_profile GROUP BY frequency_quartile ORDER BY frequency_quartile;

-- Pareto: share of revenue from the top 20% of customer profiles
DROP VIEW IF EXISTS kpi_pareto;
CREATE VIEW kpi_pareto AS
SELECT ROUND(SUM(CASE WHEN revenue_rank <= (SELECT CAST(COUNT(*) * 0.2 AS INTEGER) FROM kpi_customer_profile)
                 THEN net_revenue ELSE 0 END) * 1.0 / SUM(net_revenue), 4) AS top20pct_profiles_revenue_share
FROM kpi_customer_profile;

-- 9. HIGH-REVENUE but LOW-PROFIT products -------------------------------
--    Rule: top 50% of products by net revenue AND margin below the portfolio average.
DROP VIEW IF EXISTS kpi_highrev_lowprofit;
CREATE VIEW kpi_highrev_lowprofit AS
WITH pr AS (SELECT * FROM kpi_product),
     tot AS (SELECT margin_pct AS portfolio_margin, returns_loss_pct AS portfolio_ret,
                    shipping_pct AS portfolio_ship, aov_net AS portfolio_aov FROM kpi_overall)
SELECT pr.category, pr.product_name, pr.net_revenue, pr.revenue_rank, pr.margin_rank,
       pr.margin_pct,
       (pr.margin_pct - tot.portfolio_margin) * 100        AS margin_gap_pts,
       (pr.returns_loss_pct - tot.portfolio_ret) * 100     AS return_loss_gap_pts,
       (pr.shipping_pct - tot.portfolio_ship) * 100        AS shipping_gap_pts,
       pr.avg_discount_pct, pr.aov, tot.portfolio_aov,
       CASE WHEN (pr.returns_loss_pct - tot.portfolio_ret) > 0
                 AND ABS(pr.returns_loss_pct - tot.portfolio_ret) >= ABS(pr.shipping_pct - tot.portfolio_ship)
                 THEN 'Returns'
            WHEN (pr.shipping_pct - tot.portfolio_ship) > 0 THEN 'Shipping cost vs low basket value'
            ELSE 'Mixed / minor' END AS main_driver
FROM pr, tot
WHERE pr.revenue_rank <= (SELECT COUNT(*) / 2 FROM pr)
  AND pr.margin_pct < tot.portfolio_margin
ORDER BY pr.margin_pct;

-- =====================================================================
-- VIEW THE RESULTS (run one line at a time: select the line, press Ctrl+Return)
-- SELECT * FROM kpi_overall;
-- SELECT * FROM kpi_category;
-- SELECT * FROM kpi_product ORDER BY revenue_rank;
-- SELECT * FROM kpi_region;
-- SELECT * FROM kpi_seasonality;
-- SELECT * FROM kpi_shipping;
-- SELECT * FROM kpi_customer_age;
-- SELECT * FROM kpi_customer_gender;
-- SELECT * FROM kpi_frequency_bands;
-- SELECT * FROM kpi_pareto;
-- SELECT * FROM kpi_highrev_lowprofit;
