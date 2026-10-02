/* ================================================================
   OLIST E-COMMERCE PROJECT
   07_BUSINESS_ANALYSIS.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Answer stakeholder-facing business questions using the normalized
   Olist model and reporting views.

   IMPORTANT GRAIN RULES
   ---------------------
   1. Order metrics come from order grain.
   2. Item metrics come from order-item grain.
   3. Payment metrics come from payment grain.
   4. Review metrics come from review grain.
   5. Never join payment/review/item facts together and then SUM them
      without first aggregating each fact to the required grain.
   6. "Item value" means SUM(price) from fact_order_item.
      It is not profit, because product cost is unavailable.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '07 - BUSINESS ANALYSIS START';
PRINT '===============================================================';


/* ================================================================
   SECTION A - EXECUTIVE KPI SNAPSHOT
   ================================================================ */

PRINT 'A. EXECUTIVE KPI SNAPSHOT';

SELECT
    total_orders,
    unique_customers,
    delivered_orders,
    cancelled_orders,
    late_deliveries,
    total_order_items,
    total_item_value,
    total_freight_value,
    total_payment_value,
    total_reviews,
    average_review_score
FROM dbo.vw_executive_kpis;
GO


/* ================================================================
   SECTION B - ORDER STATUS DISTRIBUTION
   ================================================================ */

PRINT 'B. ORDER STATUS DISTRIBUTION';

SELECT
    order_status,
    COUNT_BIG(*) AS order_count,
    CAST(
        100.0 * COUNT_BIG(*) /
        NULLIF(SUM(COUNT_BIG(*)) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS order_percentage
FROM dbo.vw_order_report
GROUP BY order_status
ORDER BY order_count DESC;
GO


/* ================================================================
   SECTION C - MONTHLY SALES TREND
   ================================================================ */

PRINT 'C. MONTHLY SALES TREND';

SELECT
    month_start,
    calendar_year,
    calendar_month,
    order_count,
    customer_count,
    item_count,
    item_value,
    freight_value,
    item_value_per_order
FROM dbo.vw_monthly_sales
ORDER BY month_start;
GO


/* ================================================================
   SECTION D - YEAR-OVER-YEAR MONTHLY COMPARISON
   ================================================================ */

PRINT 'D. YEAR-OVER-YEAR MONTHLY COMPARISON';

WITH Monthly AS
(
    SELECT
        calendar_year,
        calendar_month,
        item_value,
        order_count
    FROM dbo.vw_monthly_sales
),
WithPreviousYear AS
(
    SELECT
        calendar_year,
        calendar_month,
        item_value,
        order_count,
        LAG(item_value, 12) OVER
        (
            ORDER BY calendar_year, calendar_month
        ) AS previous_year_item_value
    FROM Monthly
)
SELECT
    calendar_year,
    calendar_month,
    item_value,
    order_count,
    previous_year_item_value,
    CAST(
        CASE
            WHEN previous_year_item_value IS NULL
                 OR previous_year_item_value = 0
            THEN NULL
            ELSE
                100.0 *
                (item_value - previous_year_item_value)
                / previous_year_item_value
        END
        AS DECIMAL(10,2)
    ) AS yoy_item_value_growth_pct
FROM WithPreviousYear
ORDER BY calendar_year, calendar_month;
GO


/* ================================================================
   SECTION E - TOP PRODUCT CATEGORIES
   ================================================================ */

PRINT 'E. TOP PRODUCT CATEGORIES';

SELECT TOP (20)
    category_key,
    product_category_name,
    product_category_name_english,
    item_count,
    order_count,
    product_count,
    item_value,
    freight_value,
    average_item_price
FROM dbo.vw_category_performance
ORDER BY item_value DESC;
GO


/* ================================================================
   SECTION F - CATEGORY FREIGHT BURDEN
   ================================================================ */

PRINT 'F. CATEGORY FREIGHT BURDEN';

SELECT TOP (20)
    product_category_name,
    product_category_name_english,
    item_value,
    freight_value,
    CAST(
        CASE
            WHEN item_value = 0 THEN NULL
            ELSE 100.0 * freight_value / item_value
        END
        AS DECIMAL(10,2)
    ) AS freight_to_item_value_pct
FROM dbo.vw_category_performance
WHERE item_value > 0
ORDER BY freight_to_item_value_pct DESC;
GO


/* ================================================================
   SECTION G - STATE PERFORMANCE
   ================================================================ */

PRINT 'G. STATE PERFORMANCE';

SELECT
    customer_state,
    order_count,
    delivered_order_count,
    cancelled_order_count,
    item_count,
    item_value,
    freight_value,
    average_delivery_days,
    average_delivery_delay_days,
    CAST(
        100.0 * delivered_order_count /
        NULLIF(order_count, 0)
        AS DECIMAL(10,2)
    ) AS delivery_rate_pct,
    CAST(
        100.0 * cancelled_order_count /
        NULLIF(order_count, 0)
        AS DECIMAL(10,2)
    ) AS cancellation_rate_pct
FROM dbo.vw_state_performance
ORDER BY item_value DESC;
GO


/* ================================================================
   SECTION H - DELIVERY PERFORMANCE
   ================================================================ */

PRINT 'H. DELIVERY PERFORMANCE';

SELECT
    calendar_year,
    calendar_month,
    delivered_order_count,
    late_delivery_count,
    on_time_delivery_count,
    average_delivery_days,
    average_delivery_delay_days,
    CAST(
        100.0 * late_delivery_count /
        NULLIF(delivered_order_count, 0)
        AS DECIMAL(10,2)
    ) AS late_delivery_rate_pct
FROM dbo.vw_delivery_performance
ORDER BY calendar_year, calendar_month;
GO


/* ================================================================
   SECTION I - SELLER PERFORMANCE
   ================================================================ */

PRINT 'I. SELLER PERFORMANCE';

SELECT TOP (25)
    seller_id,
    seller_city,
    seller_state,
    item_count,
    order_count,
    total_item_value,
    total_freight_value,
    average_item_price,
    seller_activity_band
FROM dbo.vw_seller_performance
ORDER BY total_item_value DESC;
GO


/* ================================================================
   SECTION J - CUSTOMER VALUE DISTRIBUTION
   ================================================================ */

PRINT 'J. CUSTOMER VALUE DISTRIBUTION';

SELECT
    customer_activity_band,
    COUNT_BIG(*) AS customer_count,
    SUM(order_count) AS total_orders,
    SUM(delivered_order_count) AS delivered_orders,
    SUM(cancelled_order_count) AS cancelled_orders,
    SUM(total_item_value) AS total_item_value,
    SUM(total_freight_value) AS total_freight_value
FROM dbo.vw_customer_performance
GROUP BY customer_activity_band
ORDER BY total_item_value DESC;
GO


/* ================================================================
   SECTION K - REPEAT CUSTOMER ANALYSIS
   ================================================================ */

PRINT 'K. REPEAT CUSTOMER ANALYSIS';

SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time customer'
        WHEN order_count BETWEEN 2 AND 3 THEN 'Repeat customer'
        WHEN order_count BETWEEN 4 AND 5 THEN 'High-repeat customer'
        ELSE 'Very-high-repeat customer'
    END AS customer_segment,
    COUNT_BIG(*) AS customer_count,
    SUM(order_count) AS total_orders,
    SUM(total_item_value) AS total_item_value,
    CAST(
        AVG(CAST(total_item_value AS DECIMAL(18,2)))
        AS DECIMAL(18,2)
    ) AS average_customer_item_value
FROM dbo.vw_customer_performance
GROUP BY
    CASE
        WHEN order_count = 1 THEN 'One-time customer'
        WHEN order_count BETWEEN 2 AND 3 THEN 'Repeat customer'
        WHEN order_count BETWEEN 4 AND 5 THEN 'High-repeat customer'
        ELSE 'Very-high-repeat customer'
    END
ORDER BY total_item_value DESC;
GO


/* ================================================================
   SECTION L - PAYMENT METHOD ANALYSIS
   ================================================================ */

PRINT 'L. PAYMENT METHOD ANALYSIS';

SELECT
    payment_type,
    payment_count,
    order_count,
    payment_value,
    average_payment_value,
    average_installments,
    high_installment_payment_count,
    CAST(
        100.0 * payment_value /
        NULLIF(SUM(payment_value) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS payment_value_share_pct
FROM dbo.vw_payment_performance
ORDER BY payment_value DESC;
GO


/* ================================================================
   SECTION M - REVIEW PERFORMANCE
   ================================================================ */

PRINT 'M. REVIEW PERFORMANCE';

SELECT
    review_score,
    review_band,
    review_count,
    reviews_with_message,
    average_answer_delay_days,
    CAST(
        100.0 * review_count /
        NULLIF(SUM(review_count) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS review_share_pct
FROM dbo.vw_review_performance
ORDER BY review_score;
GO


/* ================================================================
   SECTION N - PRODUCT PERFORMANCE
   ================================================================ */

PRINT 'N. PRODUCT PERFORMANCE';

SELECT TOP (50)
    product_id,
    product_category_name,
    product_category_name_english,
    item_count,
    order_count,
    item_value,
    freight_value,
    average_item_price,
    product_size_band,
    product_weight_band,
    photo_band,
    description_length_band
FROM dbo.vw_product_performance
ORDER BY item_value DESC;
GO


/* ================================================================
   SECTION O - HIGH-FREIGHT PRODUCTS
   ================================================================ */

PRINT 'O. HIGH-FREIGHT PRODUCTS';

SELECT TOP (50)
    product_id,
    product_category_name,
    product_category_name_english,
    item_value,
    freight_value,
    CAST(
        CASE
            WHEN item_value = 0 THEN NULL
            ELSE 100.0 * freight_value / item_value
        END
        AS DECIMAL(10,2)
    ) AS freight_to_item_value_pct,
    average_item_price
FROM dbo.vw_product_performance
WHERE item_value > 0
ORDER BY freight_to_item_value_pct DESC;
GO


/* ================================================================
   SECTION P - DELIVERY DELAY INVESTIGATION
   ================================================================ */

PRINT 'P. DELIVERY DELAY INVESTIGATION';

SELECT TOP (50)
    order_id,
    customer_id,
    customer_state,
    order_status,
    delivery_days,
    estimated_delivery_days,
    delivery_delay_days,
    is_delivery_late
FROM dbo.vw_order_report
WHERE is_delivered = 1
ORDER BY delivery_delay_days DESC;
GO


/* ================================================================
   SECTION Q - LATE DELIVERY BY STATE
   ================================================================ */

PRINT 'Q. LATE DELIVERY BY STATE';

WITH StateDelivery AS
(
    SELECT
        customer_state,
        COUNT_BIG(*) AS delivered_orders,
        SUM(CASE WHEN is_delivery_late = 1 THEN 1 ELSE 0 END)
            AS late_orders
    FROM dbo.vw_order_report
    WHERE is_delivered = 1
      AND customer_state IS NOT NULL
    GROUP BY customer_state
)
SELECT
    customer_state,
    delivered_orders,
    late_orders,
    CAST(
        100.0 * late_orders /
        NULLIF(delivered_orders, 0)
        AS DECIMAL(10,2)
    ) AS late_delivery_rate_pct
FROM StateDelivery
ORDER BY late_delivery_rate_pct DESC;
GO


/* ================================================================
   SECTION R - CATEGORY + REVIEW CONNECTION
   Grain protection:
   reviews are aggregated by order before joining to item/category
   data. This avoids multiplying review rows by item rows.
   ================================================================ */

PRINT 'R. CATEGORY + REVIEW ANALYSIS';

WITH OrderReview AS
(
    SELECT
        fr.order_id,
        AVG(CAST(fr.review_score AS DECIMAL(10,2)))
            AS average_review_score
    FROM dbo.fact_review AS fr
    WHERE fr.review_score IS NOT NULL
    GROUP BY fr.order_id
),
CategoryReview AS
(
    SELECT
        dp.category_key,
        dp.product_category_name,
        dp.product_category_name_english,
        foi.order_id,
        foi.item_gross_value,
        orv.average_review_score
    FROM dbo.fact_order_item AS foi
    INNER JOIN dbo.dim_product AS dp
        ON foi.product_key = dp.product_key
    LEFT JOIN OrderReview AS orv
        ON foi.order_id = orv.order_id
    WHERE dp.category_key IS NOT NULL
)
SELECT
    category_key,
    product_category_name,
    product_category_name_english,
    COUNT_BIG(*) AS item_count,
    SUM(item_gross_value) AS item_value,
    COUNT_BIG(
        CASE WHEN average_review_score IS NOT NULL THEN 1 END
    ) AS reviewed_item_count,
    CAST(
        AVG(average_review_score)
        AS DECIMAL(10,2)
    ) AS average_review_score
FROM CategoryReview
GROUP BY
    category_key,
    product_category_name,
    product_category_name_english
ORDER BY item_value DESC;
GO


/* ================================================================
   SECTION S - SELLER DELIVERY EXPOSURE
   ================================================================ */

PRINT 'S. SELLER DELIVERY EXPOSURE';

WITH SellerOrders AS
(
    SELECT
        foi.seller_key,
        fo.order_key,
        co.is_delivered,
        co.is_delivery_late,
        co.delivery_days
    FROM dbo.fact_order_item AS foi
    INNER JOIN dbo.fact_order AS fo
        ON foi.order_id = fo.order_id
    INNER JOIN dbo.cond_order AS co
        ON fo.order_key = co.order_key
),
SellerAgg AS
(
    SELECT
        seller_key,
        COUNT(DISTINCT order_key) AS order_count,
        SUM(CASE WHEN is_delivered = 1 THEN 1 ELSE 0 END)
            AS delivered_order_count,
        SUM(CASE WHEN is_delivery_late = 1 THEN 1 ELSE 0 END)
            AS late_order_count,
        AVG(
            CASE
                WHEN is_delivered = 1
                THEN CAST(delivery_days AS DECIMAL(18,2))
            END
        ) AS average_delivery_days
    FROM SellerOrders
    GROUP BY seller_key
)
SELECT TOP (50)
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    sa.order_count,
    sa.delivered_order_count,
    sa.late_order_count,
    CAST(
        100.0 * sa.late_order_count /
        NULLIF(sa.delivered_order_count, 0)
        AS DECIMAL(10,2)
    ) AS late_delivery_rate_pct,
    CAST(sa.average_delivery_days AS DECIMAL(18,2))
        AS average_delivery_days
FROM SellerAgg AS sa
INNER JOIN dbo.dim_seller AS ds
    ON sa.seller_key = ds.seller_key
ORDER BY late_delivery_rate_pct DESC;
GO


/* ================================================================
   SECTION T - DATA QUALITY BUSINESS CHECKS
   ================================================================ */

PRINT 'T. DATA QUALITY BUSINESS CHECKS';

SELECT
    'Orders with negative delivery days' AS check_name,
    COUNT_BIG(*) AS issue_count
FROM dbo.vw_order_report
WHERE delivery_days < 0

UNION ALL

SELECT
    'Orders with negative delivery delay',
    COUNT_BIG(*)
FROM dbo.vw_order_report
WHERE delivery_delay_days < 0

UNION ALL

SELECT
    'Order items with negative price',
    COUNT_BIG(*)
FROM dbo.vw_order_item_report
WHERE price < 0

UNION ALL

SELECT
    'Order items with negative freight',
    COUNT_BIG(*)
FROM dbo.vw_order_item_report
WHERE freight_value < 0

UNION ALL

SELECT
    'Payments with non-positive value',
    COUNT_BIG(*)
FROM dbo.vw_payment_report
WHERE payment_value <= 0

UNION ALL

SELECT
    'Reviews outside 1-5 score range',
    COUNT_BIG(*)
FROM dbo.vw_review_report
WHERE review_score IS NOT NULL
  AND review_score NOT BETWEEN 1 AND 5;
GO


/* ================================================================
   SECTION U - MANAGEMENT SUMMARY TABLE
   A compact output for Power BI / stakeholder review.
   ================================================================ */

PRINT 'U. MANAGEMENT SUMMARY';

SELECT
    'Orders' AS metric_name,
    CAST(total_orders AS DECIMAL(18,2)) AS metric_value
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Unique Customers',
    CAST(unique_customers AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Delivered Orders',
    CAST(delivered_orders AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Cancelled Orders',
    CAST(cancelled_orders AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Order Items',
    CAST(total_order_items AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Item Value',
    CAST(total_item_value AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Freight Value',
    CAST(total_freight_value AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Payment Value',
    CAST(total_payment_value AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Reviews',
    CAST(total_reviews AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis

UNION ALL

SELECT
    'Average Review Score',
    CAST(average_review_score AS DECIMAL(18,2))
FROM dbo.vw_executive_kpis;
GO


PRINT '===============================================================';
PRINT '07 - BUSINESS ANALYSIS COMPLETE';
PRINT '===============================================================';
PRINT 'Next layer: 08_VALIDATION.sql';
PRINT '===============================================================';
GO
