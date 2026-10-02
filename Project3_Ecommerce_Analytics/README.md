# Project 3 - E-Commerce Customer & Sales Analytics

**Congorise Infotech Data Analytics Internship | Intermediate project | SQL + Excel + Power BI**

## 1. Business problem
Management wants to know where an e-commerce business earns and loses money: which products, categories,
regions and customer groups drive revenue, which products have high revenue but low profit and why, and
what strategies would improve revenue and profitability.

## 2. Data
`diversified_ecommerce_dataset.xlsx` - 1,000,000 rows x 16 columns (product, price, discount, tax rate, stock,
supplier, customer age group / gender / location, shipping method and cost, return rate, seasonality, popularity).
The raw file is **not** stored in this repository (size). Same family as the Kaggle E-Commerce Dataset suggested in the brief.

**Source limitations (documented, handled with proxies):** no order id, no customer id, no order date, no unit cost.
- Grain: 1 row = 1 order. Customer level = *customer profile* (Age group x Gender x Location, 225 profiles).
- Time analysis uses the Seasonality flag (no date column).
- Profit = *contribution profit before COGS* = net revenue - expected returns loss - shipping cost.

## 3. Pipeline
```
Excel/CSV -> SQLite raw_ecommerce -> 01 cleaning -> clean_orders
          -> 02 star schema + analytical datasets (ds_analytical, ds_price_discount)
          -> 03 KPI views -> 04 driver/scenario views -> 06 validation vs Excel
          -> Excel workbook (formulas) + Power BI dashboard
```

## 4. Repository structure
| Path | Content |
|---|---|
| `sql/01_data_cleaning.sql` | Audit (nulls, duplicates, ranges, keys) and clean table |
| `sql/02_analytical_dataset.sql` | Star schema (dim_product, dim_customer_profile, dim_shipping, dim_season, fact_order_line) + Power BI datasets |
| `sql/03_kpi_analysis.sql` | Revenue, orders, AOV, customer-level metrics; product / category / region / time; high-revenue-low-profit |
| `sql/04_additional_analysis.sql` | Price-band and discount economics, break-even uplift, loss-making orders, what-if levers |
| `sql/05_new_vs_repeat_TEMPLATE.sql` | New vs repeat template (needs customer_id + order_date, absent in this source) |
| `sql/06_validation_checks.sql` | Reconciles SQL totals to the Excel workbook (all PASS) |
| `data/ds_analytical.csv`, `data/ds_price_discount.csv` | SQL analytical datasets used by Power BI |
| `excel/Project3_Ecommerce_Analytics.xlsx` | Formula-driven workbook: KPIs, analysis sheets, dashboard, insights |
| `powerbi/` | `.pbix` dashboard, `dax_measures.md`, dashboard screenshots / PDF |
| `docs/` | Findings summary, SQL run log, validation results |
| `run_pipeline.py`, `notebooks/` | One-command / browser (Colab) runner for the SQL scripts |

## 5. How to reproduce
**Option A - no installation (Google Colab, runs in the browser):** open `notebooks/Run_SQL_Pipeline.ipynb` in Google Colab,
upload the raw file and run the cells. It executes `sql/01` -> `02` -> `03` -> `04` -> `06` and exports the two Power BI datasets.

**Option B - any machine with Python 3:** `python run_pipeline.py --input <raw .csv or .xlsx>`

**Option C - desktop SQL tool:** install DB Browser for SQLite, import the source CSV as table `raw_ecommerce`
(snake_case headers, see `sql/01_data_cleaning.sql`) and run the scripts in order (all rows in 06 must read PASS).

Then export `ds_analytical` and `ds_price_discount` as CSV (or use the copies in `data/`) and open `powerbi/*.pbix`,
or build the report from the CSVs using `powerbi/dax_measures.md`.
`run_pipeline.py` also writes `docs/sql_run_log.txt` and `docs/validation_results.csv` as proof of the run.

## 6. Key results (1,000,000 orders)
| KPI | Value |
|---|---|
| Net revenue | $879.3M |
| AOV (net) | $879.30 |
| Contribution profit (before COGS) | $762.1M (86.7% margin) |
| Discounts | $125.8M (12.5% of gross) |
| Expected returns loss | $92.2M (10.5% of net) |
| Shipping cost | $25.0M (2.8% of net) |

## 7. Key insights
1. **Balanced portfolio** - categories each hold 19.9-20.1% of revenue; the top 20% of customer profiles give only 20.5% of revenue, so profile targeting is not supported by the data.
2. **Product ranking = assortment size** - Books and Home Appliances have fewer SKUs, so each SKU gets ~13% more orders.
3. **High-revenue / low-profit products are statistical noise** - 12 products flagged on paper (worst: Toaster, -0.11 pts margin); 0 of 43 significant after Bonferroni correction.
4. **Discounts are the largest controllable leakage** - a 25% discount needs +34.5% orders to match full-price profit; order counts do not rise with deeper discounts.
5. **Returns cost 3.7x more than shipping** - each 1-pt return-rate cut is worth ~$8.8M.
6. **Low-ticket orders (< $250) break margin** - 12% of orders, 1.6% of revenue, shipping eats 22% of their revenue, all 11,639 loss-making orders sit here.
7. **Shipping method and seasonality do not change economics.**

## 8. Recommendations
R1 returns-reduction programme | R2 discount governance (cap 15%, A/B test) | R3 free-shipping threshold / minimum basket for < $250 |
R4 rebalance assortment, not single products | R5 price shipping speed | R6 capture customer_id, order_id, order_date, unit cost.

## 9. Limitations
No customer id / order date / unit cost in the source: new-vs-repeat and monthly trends cannot be computed without inventing data,
and absolute margins are overstated (profit is before product cost). Comparisons between segments remain valid.
