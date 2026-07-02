-- ============================================================
--   HCCB SUPPLY CHAIN & DISTRIBUTION INTELLIGENCE DASHBOARD
--   SQL KPI Queries — MySQL / SQL Server Compatible
--   Organized by Dashboard Page
-- ============================================================


-- ============================================================
-- PAGE 1: EXECUTIVE SUMMARY KPIs
-- ============================================================

-- 1.1  Total Orders & Total Order Value
SELECT
    COUNT(order_id)          AS total_orders,
    SUM(total_cost)          AS total_order_value,
    SUM(ordered_qty)         AS total_units_ordered,
    SUM(received_qty)        AS total_units_received
FROM fact_orders;


-- 1.2  Total Revenue (Sales Dispatch)
SELECT
    SUM(total_revenue)       AS total_revenue,
    SUM(dispatched_cases)    AS total_cases_dispatched
FROM fact_sales_dispatch;


-- 1.3  Overall On-Time Delivery % (Shipments)
SELECT
    COUNT(*)                                              AS total_shipments,
    SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) AS on_time_count,
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2)                                    AS on_time_delivery_pct
FROM fact_shipments;


-- 1.4  Inventory Health Score
--      (% of depot-product combos NOT in reorder alert)
SELECT
    COUNT(*)                                              AS total_records,
    SUM(CASE WHEN reorder_flag = 'YES' THEN 1 ELSE 0 END) AS reorder_alerts,
    ROUND(
        (1 - SUM(CASE WHEN reorder_flag = 'YES' THEN 1 ELSE 0 END) * 1.0
             / COUNT(*)) * 100, 2)                        AS inventory_health_score_pct
FROM fact_inventory;


-- 1.5  Monthly Trend — Orders vs Dispatch
SELECT
    fo.year,
    fo.month,
    COUNT(DISTINCT fo.order_id)      AS total_orders,
    SUM(fo.ordered_qty)              AS ordered_qty,
    SUM(sd.dispatched_cases)         AS dispatched_cases,
    SUM(sd.total_revenue)            AS monthly_revenue
FROM fact_orders fo
LEFT JOIN fact_sales_dispatch sd
    ON fo.depot_id = sd.depot_id
    AND fo.year    = sd.year
    AND fo.month   = sd.month
GROUP BY fo.year, fo.month
ORDER BY fo.year, fo.month;


-- 1.6  Region-wise Performance Summary
SELECT
    d.region,
    SUM(sd.total_revenue)    AS total_revenue,
    SUM(sd.dispatched_cases) AS total_cases,
    COUNT(DISTINCT sd.distributor_id) AS active_distributors
FROM fact_sales_dispatch sd
JOIN dim_depots d ON sd.depot_id = d.depot_id
GROUP BY d.region
ORDER BY total_revenue DESC;


-- 1.7  Top 5 SKUs by Volume Dispatched
SELECT
    p.product_name,
    p.brand,
    p.category,
    SUM(sd.dispatched_cases) AS total_cases,
    SUM(sd.total_revenue)    AS total_revenue
FROM fact_sales_dispatch sd
JOIN dim_products p ON sd.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.brand, p.category
ORDER BY total_cases DESC
LIMIT 5;


-- ============================================================
-- PAGE 2: INVENTORY MANAGEMENT
-- ============================================================

-- 2.1  Latest Closing Stock per Depot & Product
SELECT
    inv.depot_id,
    dep.depot_name,
    dep.city,
    dep.region,
    inv.product_id,
    p.product_name,
    p.brand,
    inv.closing_stock,
    inv.reorder_level,
    inv.reorder_flag,
    inv.date_id
FROM fact_inventory inv
JOIN dim_depots   dep ON inv.depot_id   = dep.depot_id
JOIN dim_products p   ON inv.product_id = p.product_id
WHERE inv.date_id = (
    SELECT MAX(date_id) FROM fact_inventory
);


-- 2.2  Reorder Alert Table — Products Below Reorder Level
SELECT
    dep.depot_name,
    dep.city,
    dep.region,
    p.product_name,
    p.brand,
    inv.closing_stock,
    inv.reorder_level,
    (inv.reorder_level - inv.closing_stock) AS shortage_units,
    inv.date_id
FROM fact_inventory inv
JOIN dim_depots   dep ON inv.depot_id   = dep.depot_id
JOIN dim_products p   ON inv.product_id = p.product_id
WHERE inv.reorder_flag = 'YES'
ORDER BY shortage_units DESC;


-- 2.3  ABC Classification of SKUs (by Dispatch Revenue)
WITH sku_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.brand,
        SUM(sd.total_revenue) AS sku_revenue,
        SUM(SUM(sd.total_revenue)) OVER () AS grand_total
    FROM fact_sales_dispatch sd
    JOIN dim_products p ON sd.product_id = p.product_id
    GROUP BY p.product_id, p.product_name, p.brand
),
sku_ranked AS (
    SELECT *,
        ROUND(sku_revenue * 100.0 / grand_total, 2) AS revenue_pct,
        SUM(sku_revenue * 100.0 / grand_total)
            OVER (ORDER BY sku_revenue DESC) AS cumulative_pct
    FROM sku_revenue
)
SELECT
    product_id,
    product_name,
    brand,
    sku_revenue,
    revenue_pct,
    cumulative_pct,
    CASE
        WHEN cumulative_pct <= 70  THEN 'A — High Value'
        WHEN cumulative_pct <= 90  THEN 'B — Medium Value'
        ELSE                            'C — Low Value'
    END AS abc_class
FROM sku_ranked
ORDER BY sku_revenue DESC;


-- 2.4  Stock-In vs Stock-Out Trend by Month
SELECT
    YEAR(date_id)                AS year,
    MONTH(date_id)               AS month,
    SUM(stock_received)          AS total_stock_in,
    SUM(stock_dispatched)        AS total_stock_out,
    SUM(closing_stock)           AS total_closing_stock
FROM fact_inventory
GROUP BY YEAR(date_id), MONTH(date_id)
ORDER BY year, month;


-- 2.5  Depot-wise Inventory Utilisation %
SELECT
    inv.depot_id,
    dep.depot_name,
    dep.depot_capacity_units,
    SUM(inv.closing_stock)        AS current_total_stock,
    ROUND(
        SUM(inv.closing_stock) * 100.0 / dep.depot_capacity_units, 2
    )                             AS utilisation_pct
FROM fact_inventory inv
JOIN dim_depots dep ON inv.depot_id = dep.depot_id
WHERE inv.date_id = (SELECT MAX(date_id) FROM fact_inventory)
GROUP BY inv.depot_id, dep.depot_name, dep.depot_capacity_units
ORDER BY utilisation_pct DESC;


-- ============================================================
-- PAGE 3: SUPPLIER PERFORMANCE
-- ============================================================

-- 3.1  Supplier Scorecard — Lead Time, Fill Rate, Rating
SELECT
    s.supplier_id,
    s.supplier_name,
    s.supplier_type,
    s.rating                                       AS supplier_rating,
    s.lead_time_days                               AS standard_lead_time,
    ROUND(AVG(fo.lead_time_actual), 1)             AS avg_actual_lead_time,
    COUNT(fo.order_id)                             AS total_orders,
    SUM(fo.ordered_qty)                            AS total_ordered,
    SUM(fo.received_qty)                           AS total_received,
    ROUND(
        SUM(fo.received_qty) * 100.0 / NULLIF(SUM(fo.ordered_qty), 0), 2
    )                                              AS fill_rate_pct
FROM dim_suppliers s
LEFT JOIN fact_orders fo ON s.supplier_id = fo.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.supplier_type,
         s.rating, s.lead_time_days
ORDER BY fill_rate_pct DESC;


-- 3.2  On-Time Delivery % by Supplier
SELECT
    s.supplier_name,
    s.supplier_type,
    COUNT(fo.order_id)                                     AS total_orders,
    SUM(CASE WHEN fo.order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN fo.order_status = 'Delayed'   THEN 1 ELSE 0 END) AS delayed,
    SUM(CASE WHEN fo.order_status = 'Pending'   THEN 1 ELSE 0 END) AS pending,
    ROUND(
        SUM(CASE WHEN fo.order_status = 'Delivered' THEN 1 ELSE 0 END) * 100.0
        / COUNT(fo.order_id), 2)                           AS on_time_pct
FROM dim_suppliers s
JOIN fact_orders fo ON s.supplier_id = fo.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.supplier_type
ORDER BY on_time_pct DESC;


-- 3.3  Order Fulfillment Rate (Received vs Ordered) by Supplier
SELECT
    s.supplier_name,
    p.product_name,
    SUM(fo.ordered_qty)  AS ordered,
    SUM(fo.received_qty) AS received,
    ROUND(
        SUM(fo.received_qty) * 100.0 / NULLIF(SUM(fo.ordered_qty), 0), 2
    )                    AS fulfillment_rate_pct
FROM fact_orders fo
JOIN dim_suppliers s ON fo.supplier_id = s.supplier_id
JOIN dim_products  p ON fo.product_id  = p.product_id
GROUP BY s.supplier_id, s.supplier_name, p.product_id, p.product_name
ORDER BY fulfillment_rate_pct ASC;   -- worst performers first


-- 3.4  Delayed Orders Drill-Through Table
SELECT
    fo.order_id,
    s.supplier_name,
    p.product_name,
    dep.depot_name,
    fo.order_date,
    fo.expected_date,
    fo.actual_date,
    fo.lead_time_actual,
    s.lead_time_days          AS standard_lead_time,
    (fo.lead_time_actual - s.lead_time_days) AS excess_days,
    fo.order_status
FROM fact_orders fo
JOIN dim_suppliers s ON fo.supplier_id = s.supplier_id
JOIN dim_products  p ON fo.product_id  = p.product_id
JOIN dim_depots  dep ON fo.depot_id    = dep.depot_id
WHERE fo.order_status = 'Delayed'
ORDER BY excess_days DESC;


-- ============================================================
-- PAGE 4: LOGISTICS & SHIPMENTS
-- ============================================================

-- 4.1  On-Time vs Delayed vs Partial Delivery Summary
SELECT
    delivery_status,
    COUNT(*)                            AS shipment_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_share
FROM fact_shipments
GROUP BY delivery_status;


-- 4.2  Average Delay Days by Transporter
SELECT
    transporter_name,
    COUNT(shipment_id)               AS total_shipments,
    SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) AS on_time,
    SUM(CASE WHEN delivery_status = 'Delayed' THEN 1 ELSE 0 END) AS delayed,
    ROUND(AVG(delay_days), 1)        AS avg_delay_days,
    ROUND(AVG(freight_cost), 2)      AS avg_freight_cost,
    ROUND(
        SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) * 100.0
        / COUNT(shipment_id), 2)     AS on_time_pct
FROM fact_shipments
GROUP BY transporter_name
ORDER BY avg_delay_days DESC;


-- 4.3  Freight Cost by Region
SELECT
    dep.region,
    COUNT(sh.shipment_id)       AS total_shipments,
    SUM(sh.freight_cost)        AS total_freight_cost,
    ROUND(AVG(sh.freight_cost), 2) AS avg_freight_per_shipment,
    SUM(sh.dispatched_qty)      AS total_qty_shipped,
    ROUND(
        SUM(sh.freight_cost) / NULLIF(SUM(sh.dispatched_qty), 0), 4
    )                           AS freight_cost_per_unit
FROM fact_shipments sh
JOIN dim_depots dep ON sh.depot_id = dep.depot_id
GROUP BY dep.region
ORDER BY total_freight_cost DESC;


-- 4.4  Distance vs Freight Cost (for Scatter Plot)
SELECT
    shipment_id,
    transporter_name,
    distance_km,
    freight_cost,
    delivery_status,
    delay_days,
    ROUND(freight_cost / NULLIF(distance_km, 0), 2) AS cost_per_km
FROM fact_shipments
ORDER BY distance_km;


-- 4.5  Monthly Shipment Volume & Avg Delay Trend
SELECT
    YEAR(shipment_date)          AS year,
    MONTH(shipment_date)         AS month,
    COUNT(shipment_id)           AS total_shipments,
    SUM(dispatched_qty)          AS total_qty,
    ROUND(AVG(delay_days), 1)    AS avg_delay_days,
    SUM(freight_cost)            AS total_freight_cost
FROM fact_shipments
GROUP BY YEAR(shipment_date), MONTH(shipment_date)
ORDER BY year, month;


-- ============================================================
-- PAGE 5: SALES DISPATCH & DISTRIBUTION
-- ============================================================

-- 5.1  Revenue by Sales Channel (GT vs MT vs HoReCa)
SELECT
    channel,
    COUNT(dispatch_id)          AS total_dispatches,
    SUM(dispatched_cases)       AS total_cases,
    SUM(total_revenue)          AS total_revenue,
    ROUND(
        SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER (), 2
    )                           AS revenue_share_pct
FROM fact_sales_dispatch
GROUP BY channel
ORDER BY total_revenue DESC;


-- 5.2  Distributor Performance Table
SELECT
    dr.distributor_name,
    dr.channel,
    dr.city,
    dr.state,
    dep.region,
    COUNT(sd.dispatch_id)        AS total_orders,
    SUM(sd.dispatched_cases)     AS total_cases,
    SUM(sd.total_revenue)        AS total_revenue,
    ROUND(AVG(sd.unit_price), 2) AS avg_unit_price
FROM fact_sales_dispatch sd
JOIN dim_distributors dr ON sd.distributor_id = dr.distributor_id
JOIN dim_depots       dep ON sd.depot_id       = dep.depot_id
GROUP BY dr.distributor_id, dr.distributor_name, dr.channel,
         dr.city, dr.state, dep.region
ORDER BY total_revenue DESC;


-- 5.3  Region-wise Dispatch Volume & Revenue
SELECT
    dep.region,
    SUM(sd.dispatched_cases) AS total_cases,
    SUM(sd.total_revenue)    AS total_revenue,
    COUNT(DISTINCT sd.distributor_id) AS distributors,
    COUNT(DISTINCT sd.product_id)     AS skus_sold
FROM fact_sales_dispatch sd
JOIN dim_depots dep ON sd.depot_id = dep.depot_id
GROUP BY dep.region
ORDER BY total_revenue DESC;


-- 5.4  Month-over-Month Revenue Growth %
WITH monthly AS (
    SELECT
        year,
        month,
        SUM(total_revenue) AS revenue
    FROM fact_sales_dispatch
    GROUP BY year, month
)
SELECT
    year,
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY year, month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY year, month)) * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY year, month), 0), 2
    )                                         AS mom_growth_pct
FROM monthly
ORDER BY year, month;


-- 5.5  Top Depot by Revenue (Bar Chart Source)
SELECT
    dep.depot_name,
    dep.city,
    dep.region,
    SUM(sd.total_revenue)    AS total_revenue,
    SUM(sd.dispatched_cases) AS total_cases
FROM fact_sales_dispatch sd
JOIN dim_depots dep ON sd.depot_id = dep.depot_id
GROUP BY dep.depot_id, dep.depot_name, dep.city, dep.region
ORDER BY total_revenue DESC;


-- ============================================================
-- BONUS: CROSS-PAGE KPIs (Great for Executive Cards)
-- ============================================================

-- B.1  Supply Chain Efficiency Score
--      = Fill Rate % × On-Time Delivery % / 100
SELECT
    ROUND(
        (SELECT SUM(received_qty)*100.0/SUM(ordered_qty) FROM fact_orders)
        *
        (SELECT SUM(CASE WHEN delivery_status='On Time' THEN 1 ELSE 0 END)*100.0/COUNT(*) FROM fact_shipments)
        / 100, 2
    ) AS supply_chain_efficiency_score;


-- B.2  Inventory Turnover Ratio (per Depot)
--      = Total Stock Dispatched / Average Closing Stock
SELECT
    inv.depot_id,
    dep.depot_name,
    SUM(inv.stock_dispatched)                       AS total_dispatched,
    ROUND(AVG(inv.closing_stock), 0)                AS avg_closing_stock,
    ROUND(
        SUM(inv.stock_dispatched) * 1.0
        / NULLIF(AVG(inv.closing_stock), 0), 2)     AS inventory_turnover_ratio
FROM fact_inventory inv
JOIN dim_depots dep ON inv.depot_id = dep.depot_id
GROUP BY inv.depot_id, dep.depot_name
ORDER BY inventory_turnover_ratio DESC;


-- B.3  Perfect Order Rate
--      Orders that were: Delivered on time + Fully received (received = ordered)
SELECT
    COUNT(*)                                              AS total_orders,
    SUM(CASE
            WHEN order_status = 'Delivered'
             AND received_qty = ordered_qty
            THEN 1 ELSE 0
        END)                                             AS perfect_orders,
    ROUND(
        SUM(CASE
                WHEN order_status = 'Delivered'
                 AND received_qty = ordered_qty
                THEN 1 ELSE 0
            END) * 100.0 / COUNT(*), 2)                 AS perfect_order_rate_pct
FROM fact_orders;


-- ============================================================
-- END OF FILE
-- ============================================================
