-- =====================================================================
-- 06_validation_checks.sql  |  Reconcile the SQL results to the Excel workbook
-- Control totals come from Excel sheet  KPIs_Overall / Data_Quality.
-- Every row must say PASS. If a row says FAIL, re-run scripts 01 -> 02 in order.
-- =====================================================================
SELECT 'Orders' AS metric, 1000000.0 AS excel_value, orders AS sql_value,
       CASE WHEN ABS(orders - 1000000.0) < 0.5 THEN 'PASS' ELSE 'FAIL' END AS status FROM kpi_overall
UNION ALL
SELECT 'Gross revenue', 1005120741.96, gross_revenue,
       CASE WHEN ABS(gross_revenue - 1005120741.96) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Discounts', 125817233.319, discounts,
       CASE WHEN ABS(discounts - 125817233.319) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Net revenue', 879303508.641, net_revenue,
       CASE WHEN ABS(net_revenue - 879303508.641) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Tax collected', 87937785.235025, tax_collected,
       CASE WHEN ABS(tax_collected - 87937785.235025) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Returns loss', 92247205.6933136, returns_loss,
       CASE WHEN ABS(returns_loss - 92247205.6933136) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Shipping cost', 24985224.0, shipping_cost,
       CASE WHEN ABS(shipping_cost - 24985224.0) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'Contribution profit', 762071078.947686, contribution_profit,
       CASE WHEN ABS(contribution_profit - 762071078.947686) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall
UNION ALL
SELECT 'ds_analytical rows', 58050.0, (SELECT COUNT(*) FROM ds_analytical),
       CASE WHEN (SELECT COUNT(*) FROM ds_analytical) = 58050 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'ds_price_discount rows', 150.0, (SELECT COUNT(*) FROM ds_price_discount),
       CASE WHEN (SELECT COUNT(*) FROM ds_price_discount) = 150 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'Internal: profit = net - returns - shipping', 0.0,
       ABS(net_revenue - returns_loss - shipping_cost - contribution_profit),
       CASE WHEN ABS(net_revenue - returns_loss - shipping_cost - contribution_profit) < 1 THEN 'PASS' ELSE 'FAIL' END FROM kpi_overall;
