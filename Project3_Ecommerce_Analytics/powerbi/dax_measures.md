# DAX measures - Project 3 Power BI dashboard

Tables loaded from `data/ds_analytical.csv` (table name **ds_analytical**) and
`data/ds_price_discount.csv` (table name **ds_price_discount**).
Create each measure with **Home -> New measure** (select the table ds_analytical first).

```DAX
Orders            = SUM ( ds_analytical[orders] )
Gross Revenue     = SUM ( ds_analytical[gross_revenue] )
Discounts         = SUM ( ds_analytical[discount_amount] )
Net Revenue       = SUM ( ds_analytical[net_revenue] )
Returns Loss      = SUM ( ds_analytical[returns_loss] )
Shipping Cost     = SUM ( ds_analytical[shipping_cost] )
Contribution Profit = SUM ( ds_analytical[contribution_profit] )

AOV (Net)         = DIVIDE ( [Net Revenue], [Orders] )
Margin %          = DIVIDE ( [Contribution Profit], [Net Revenue] )
Discount Rate %   = DIVIDE ( [Discounts], [Gross Revenue] )
Returns Loss %    = DIVIDE ( [Returns Loss], [Net Revenue] )
Shipping %        = DIVIDE ( [Shipping Cost], [Net Revenue] )
Revenue Share %   = DIVIDE ( [Net Revenue], CALCULATE ( [Net Revenue], ALL ( ds_analytical ) ) )
Avg Discount %    = DIVIDE ( SUM ( ds_analytical[sum_discount_pct] ), [Orders] )
Avg Return Rate % = DIVIDE ( SUM ( ds_analytical[sum_return_rate_pct] ), [Orders] )
```

Measures for the **ds_price_discount** table (select that table before creating):

```DAX
PD Orders        = SUM ( ds_price_discount[orders] )
PD Net Revenue   = SUM ( ds_price_discount[net_revenue] )
PD Profit        = SUM ( ds_price_discount[contribution_profit] )
PD Margin %      = DIVIDE ( [PD Profit], [PD Net Revenue] )
PD Shipping %    = DIVIDE ( SUM ( ds_price_discount[shipping_cost] ), [PD Net Revenue] )
Profit per Order = DIVIDE ( [PD Profit], [PD Orders] )
Loss-making Orders = SUM ( ds_price_discount[loss_making_orders] )
Loss-making % of Orders = DIVIDE ( [Loss-making Orders], [PD Orders] )
```

Flag for high-revenue / low-profit products (use in the product table):

```DAX
HighRev LowProfit =
VAR _rankRev =
    RANKX ( ALLSELECTED ( ds_analytical[product_name] ), [Net Revenue], , DESC, DENSE )
VAR _nProducts = DISTINCTCOUNT ( ds_analytical[product_name] )
RETURN
    IF ( _rankRev <= INT ( _nProducts / 2 )
         && [Margin %] < CALCULATE ( [Margin %], ALL ( ds_analytical ) ),
         "Yes", "No" )
```

## Expected card values (must match Excel and SQL)
Orders 1,000,000 | Net revenue $879.30M | AOV $879.30 | Contribution profit $762.07M |
Margin 86.7% | Discount rate 12.5% | Returns loss 10.5% | Shipping 2.8%
