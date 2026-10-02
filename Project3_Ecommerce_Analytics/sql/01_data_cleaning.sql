-- =====================================================================
-- Project 3 - E-Commerce Customer & Sales Analytics (Congorise Infotech)
-- 01_data_cleaning.sql   |  Engine: SQLite (DB Browser for SQLite)
-- Input : raw_ecommerce  (1,000,000 rows imported from the Excel/CSV file)
-- Output: clean_orders   (validated, typed, trimmed, de-duplicated)
-- =====================================================================
-- Expected raw columns (snake_case, order does not matter):
-- product_id, product_name, category, price, discount, tax_rate, stock_level,
-- supplier_id, customer_age_group, customer_gender, customer_location,
-- shipping_method, shipping_cost, return_rate, seasonality, popularity_index

-- ---------- STEP 1: AUDIT (ONE query - select it and press Ctrl+Return to see all results) ----------
-- Expected: raw rows 1,000,000 | all other checks 0 except product_id findings (ID is not a stable key)
SELECT 'raw_row_count' AS check_name, COUNT(*) AS result FROM raw_ecommerce
UNION ALL
SELECT 'rows_with_null_or_blank', COUNT(*) FROM raw_ecommerce
WHERE product_id IS NULL OR TRIM(CAST(product_id AS TEXT)) = ''
   OR product_name IS NULL OR TRIM(product_name) = ''
   OR category IS NULL OR TRIM(category) = ''
   OR price IS NULL OR discount IS NULL OR tax_rate IS NULL OR stock_level IS NULL
   OR supplier_id IS NULL
   OR customer_age_group IS NULL OR TRIM(customer_age_group) = ''
   OR customer_gender IS NULL OR TRIM(customer_gender) = ''
   OR customer_location IS NULL OR TRIM(customer_location) = ''
   OR shipping_method IS NULL OR TRIM(shipping_method) = ''
   OR shipping_cost IS NULL OR return_rate IS NULL
   OR seasonality IS NULL OR TRIM(seasonality) = ''
   OR popularity_index IS NULL
UNION ALL
SELECT 'duplicate_extra_copies',
       (SELECT COUNT(*) FROM raw_ecommerce) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM raw_ecommerce))
UNION ALL
SELECT 'invalid_numeric_ranges', COUNT(*) FROM raw_ecommerce
WHERE price <= 0 OR discount < 0 OR discount > 100 OR return_rate < 0 OR return_rate > 100
   OR tax_rate < 0 OR shipping_cost < 0 OR stock_level < 0
UNION ALL
SELECT 'text_with_stray_spaces', COUNT(*) FROM raw_ecommerce
WHERE product_name <> TRIM(product_name) OR category <> TRIM(category)
   OR customer_age_group <> TRIM(customer_age_group) OR customer_gender <> TRIM(customer_gender)
   OR customer_location <> TRIM(customer_location) OR shipping_method <> TRIM(shipping_method)
   OR seasonality <> TRIM(seasonality)
UNION ALL
SELECT 'product_name_in_many_categories', COUNT(*)
FROM (SELECT product_name FROM raw_ecommerce GROUP BY product_name HAVING COUNT(DISTINCT category) > 1)
UNION ALL
SELECT 'product_ids_with_many_names', COUNT(*)
FROM (SELECT product_id FROM raw_ecommerce GROUP BY product_id HAVING COUNT(DISTINCT product_name) > 1)
UNION ALL
SELECT 'product_ids_with_many_prices', COUNT(*)
FROM (SELECT product_id FROM raw_ecommerce GROUP BY product_id HAVING COUNT(DISTINCT price) > 1);

-- ---------- STEP 2: BUILD THE CLEAN TABLE ----------
DROP TABLE IF EXISTS clean_orders;
CREATE TABLE clean_orders AS
SELECT DISTINCT
    CAST(product_id AS TEXT)            AS product_id,
    TRIM(product_name)                  AS product_name,
    TRIM(category)                      AS category,
    CAST(price AS REAL)                 AS price,
    CAST(discount AS REAL)              AS discount_pct,
    CAST(tax_rate AS REAL)              AS tax_rate_pct,
    CAST(stock_level AS INTEGER)        AS stock_level,
    CAST(supplier_id AS TEXT)           AS supplier_id,
    TRIM(customer_age_group)            AS age_group,
    TRIM(customer_gender)               AS gender,
    TRIM(customer_location)             AS location,
    TRIM(shipping_method)               AS shipping_method,
    CAST(shipping_cost AS REAL)         AS shipping_cost,
    CAST(return_rate AS REAL)           AS return_rate_pct,
    TRIM(seasonality)                   AS seasonal_flag,
    CAST(popularity_index AS REAL)      AS popularity_index
FROM raw_ecommerce
WHERE price > 0
  AND discount BETWEEN 0 AND 100
  AND return_rate BETWEEN 0 AND 100
  AND tax_rate >= 0 AND shipping_cost >= 0 AND stock_level >= 0
  AND product_name IS NOT NULL AND TRIM(product_name) <> ''
  AND category IS NOT NULL AND customer_location IS NOT NULL;

-- ---------- STEP 3: CLEANING LOG ----------
SELECT 'clean_row_count' AS check_name, COUNT(*) AS result FROM clean_orders
UNION ALL
SELECT 'rows_removed_in_cleaning', (SELECT COUNT(*) FROM raw_ecommerce) - (SELECT COUNT(*) FROM clean_orders);

CREATE INDEX IF NOT EXISTS ix_clean_category ON clean_orders(category);
CREATE INDEX IF NOT EXISTS ix_clean_product  ON clean_orders(product_name);
