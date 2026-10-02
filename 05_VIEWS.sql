/* ================================================================
   OLIST E-COMMERCE PROJECT
   05_VIEWS.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Build reusable reporting views on top of the normalized and
   condition layers.

   PREREQUISITE
   ------------
   03_NORMALIZATION.sql and 04_CONDITIONS.sql must complete successfully.

   IMPORTANT
   ---------
   - Raw Olist tables are never referenced.
   - Staging tables are never referenced.
   - The physical product translation columns column1/column2 are not
     referenced anywhere in this file.
   - Revenue measures are kept at their correct grains.
   - No profit is calculated because product cost is not supplied.
   ================================================================ */

USE [Sql_project];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '05 - REPORTING VIEWS START';
PRINT '===============================================================';


/* ================================================================
   01. ORDER REPORT VIEW
   Grain: one row per order.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_order_report;
GO

CREATE VIEW dbo.vw_order_report
AS
SELECT
    fo.order_key,
    fo.order_id,
    fo.customer_key,
    dd.date_key AS purchase_date_key,
    dd.full_date AS purchase_date,
    dd.calendar_year,
    dd.calendar_quarter,
    dd.calendar_month,
    dd.month_name,
    dd.is_weekend,

    fo.order_status,
    fo.order_purchase_timestamp,
    fo.order_approved_at,
    fo.order_delivered_carrier_date,
    fo.order_delivered_customer_date,
    fo.order_estimated_delivery_date,

    co.is_delivered,
    co.is_cancelled,
    co.is_unavailable,
    co.is_completed,
    co.delivery_days,
    co.approval_days,
    co.carrier_days,
    co.estimated_delivery_days,
    co.delivery_delay_days,
    co.is_delivery_late,
    co.is_delivery_on_time,

    dc.customer_id,
    dc.customer_unique_id,
    dc.customer_city,
    dc.customer_state,
    dc.customer_zip_code_prefix

FROM dbo.fact_order AS fo
LEFT JOIN dbo.dim_date AS dd
    ON fo.purchase_date_key = dd.date_key
LEFT JOIN dbo.cond_order AS co
    ON fo.order_key = co.order_key
LEFT JOIN dbo.dim_customer AS dc
    ON fo.customer_key = dc.customer_key;
GO


/* ================================================================
   02. ORDER ITEM REPORT VIEW
   Grain: one row per order item.

   Item revenue and freight are kept here because they belong to
   order-item grain.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_order_item_report;
GO

CREATE VIEW dbo.vw_order_item_report
AS
SELECT
    foi.order_item_key,
    foi.order_id,
    foi.order_item_id,

    foi.product_key,
    dp.product_id,
    dp.product_category_name,
    dp.product_category_name_english,

    dp.category_key,

    foi.seller_key,
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,

    foi.shipping_limit_date,
    foi.price,
    foi.freight_value,
    foi.item_gross_value,

    coi.item_value_band,
    coi.freight_band,
    coi.freight_ratio,

    cp.product_size_band,
    cp.product_weight_band,
    cp.photo_band,
    cp.description_length_band

FROM dbo.fact_order_item AS foi
LEFT JOIN dbo.dim_product AS dp
    ON foi.product_key = dp.product_key
LEFT JOIN dbo.dim_seller AS ds
    ON foi.seller_key = ds.seller_key
LEFT JOIN dbo.cond_order_item AS coi
    ON foi.order_item_key = coi.order_item_key
LEFT JOIN dbo.cond_product AS cp
    ON foi.product_key = cp.product_key;
GO


/* ================================================================
   03. PAYMENT REPORT VIEW
   Grain: one row per payment record.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_payment_report;
GO

CREATE VIEW dbo.vw_payment_report
AS
SELECT
    fp.payment_key,
    fp.order_id,
    fp.payment_sequential,
    fp.payment_type,
    fp.payment_installments,
    fp.payment_value,

    cp.payment_value_band,
    cp.installment_band,
    cp.is_high_installment

FROM dbo.fact_payment AS fp
LEFT JOIN dbo.cond_payment AS cp
    ON fp.payment_key = cp.payment_key;
GO


/* ================================================================
   04. REVIEW REPORT VIEW
   Grain: one row per review.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_review_report;
GO

CREATE VIEW dbo.vw_review_report
AS
SELECT
    fr.review_key,
    fr.review_id,
    fr.order_id,

    fr.review_score,
    cr.review_band,
    cr.is_positive_review,
    cr.is_neutral_review,
    cr.is_negative_review,

    cr.has_comment_title,
    cr.has_comment_message,
    cr.has_answer_timestamp,
    cr.answer_delay_days,

    fr.review_creation_date,
    fr.review_answer_timestamp

FROM dbo.fact_review AS fr
LEFT JOIN dbo.cond_review AS cr
    ON fr.review_key = cr.review_key;
GO


/* ================================================================
   05. CUSTOMER PERFORMANCE VIEW
   Grain: one row per customer.

   Customer totals are already aggregated safely in cond_customer.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_customer_performance;
GO

CREATE VIEW dbo.vw_customer_performance
AS
SELECT
    dc.customer_key,
    dc.customer_id,
    dc.customer_unique_id,

    dc.customer_city,
    dc.customer_state,
    dc.customer_zip_code_prefix,

    cc.order_count,
    cc.delivered_order_count,
    cc.cancelled_order_count,

    cc.total_item_value,
    cc.total_freight_value,

    cc.customer_activity_band

FROM dbo.dim_customer AS dc
LEFT JOIN dbo.cond_customer AS cc
    ON dc.customer_key = cc.customer_key;
GO


/* ================================================================
   06. SELLER PERFORMANCE VIEW
   Grain: one row per seller.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_seller_performance;
GO

CREATE VIEW dbo.vw_seller_performance
AS
SELECT
    ds.seller_key,
    ds.seller_id,
    ds.seller_city,
    ds.seller_state,
    ds.seller_zip_code_prefix,

    cs.item_count,
    cs.order_count,
    cs.total_item_value,
    cs.total_freight_value,
    cs.average_item_price,
    cs.seller_activity_band

FROM dbo.dim_seller AS ds
LEFT JOIN dbo.cond_seller AS cs
    ON ds.seller_key = cs.seller_key;
GO


/* ================================================================
   07. PRODUCT PERFORMANCE VIEW
   Grain: one row per product.

   Sales metrics are aggregated independently before joining to
   product dimension, preventing item duplication.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_product_performance;
GO

CREATE VIEW dbo.vw_product_performance
AS
WITH ProductSales AS
(
    SELECT
        foi.product_key,
        COUNT_BIG(*) AS item_count,
        COUNT(DISTINCT foi.order_id) AS order_count,
        SUM(ISNULL(foi.price,0)) AS item_value,
        SUM(ISNULL(foi.freight_value,0)) AS freight_value,
        AVG(CAST(foi.price AS DECIMAL(18,2))) AS average_item_price
    FROM dbo.fact_order_item AS foi
    GROUP BY foi.product_key
)
SELECT
    dp.product_key,
    dp.product_id,
    dp.category_key,
    dp.product_category_name,
    dp.product_category_name_english,

    dp.product_name_lenght,
    dp.product_description_lenght,
    dp.product_photos_qty,
    dp.product_weight_g,
    dp.product_length_cm,
    dp.product_height_cm,
    dp.product_width_cm,

    cp.product_size_band,
    cp.product_weight_band,
    cp.photo_band,
    cp.description_length_band,

    ISNULL(ps.item_count,0) AS item_count,
    ISNULL(ps.order_count,0) AS order_count,
    CAST(ISNULL(ps.item_value,0) AS DECIMAL(18,2)) AS item_value,
    CAST(ISNULL(ps.freight_value,0) AS DECIMAL(18,2)) AS freight_value,
    CAST(ps.average_item_price AS DECIMAL(18,2)) AS average_item_price

FROM dbo.dim_product AS dp
LEFT JOIN ProductSales AS ps
    ON dp.product_key = ps.product_key
LEFT JOIN dbo.cond_product AS cp
    ON dp.product_key = cp.product_key;
GO


/* ================================================================
   08. CATEGORY PERFORMANCE VIEW
   Grain: one row per category.

   Item metrics are aggregated at category level.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_category_performance;
GO

CREATE VIEW dbo.vw_category_performance
AS
WITH CategorySales AS
(
    SELECT
        dp.category_key,
        COUNT_BIG(*) AS item_count,
        COUNT(DISTINCT foi.order_id) AS order_count,
        COUNT(DISTINCT foi.product_key) AS product_count,
        SUM(ISNULL(foi.price,0)) AS item_value,
        SUM(ISNULL(foi.freight_value,0)) AS freight_value,
        AVG(CAST(foi.price AS DECIMAL(18,2))) AS average_item_price
    FROM dbo.fact_order_item AS foi
    INNER JOIN dbo.dim_product AS dp
        ON foi.product_key = dp.product_key
    WHERE dp.category_key IS NOT NULL
    GROUP BY dp.category_key
)
SELECT
    dc.category_key,
    dc.product_category_name,
    dc.product_category_name_english,

    ISNULL(cs.item_count,0) AS item_count,
    ISNULL(cs.order_count,0) AS order_count,
    ISNULL(cs.product_count,0) AS product_count,

    CAST(ISNULL(cs.item_value,0) AS DECIMAL(18,2)) AS item_value,
    CAST(ISNULL(cs.freight_value,0) AS DECIMAL(18,2)) AS freight_value,
    CAST(cs.average_item_price AS DECIMAL(18,2)) AS average_item_price

FROM dbo.dim_category AS dc
LEFT JOIN CategorySales AS cs
    ON dc.category_key = cs.category_key;
GO


/* ================================================================
   09. MONTHLY SALES VIEW
   Grain: one row per purchase month.

   Revenue proxy is item price, not payment_value, to avoid mixing
   payment grain with item grain.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_monthly_sales;
GO

CREATE VIEW dbo.vw_monthly_sales
AS
WITH MonthlyItems AS
(
    SELECT
        dd.calendar_year,
        dd.calendar_month,
        MIN(dd.full_date) AS month_start,
        COUNT_BIG(*) AS item_count,
        COUNT(DISTINCT foi.order_id) AS order_count,
        COUNT(DISTINCT fo.customer_key) AS customer_count,
        SUM(ISNULL(foi.price,0)) AS item_value,
        SUM(ISNULL(foi.freight_value,0)) AS freight_value
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.fact_order_item AS foi
        ON fo.order_id = foi.order_id
    INNER JOIN dbo.dim_date AS dd
        ON fo.purchase_date_key = dd.date_key
    GROUP BY
        dd.calendar_year,
        dd.calendar_month
)
SELECT
    calendar_year,
    calendar_month,
    month_start,
    item_count,
    order_count,
    customer_count,
    CAST(item_value AS DECIMAL(18,2)) AS item_value,
    CAST(freight_value AS DECIMAL(18,2)) AS freight_value,
    CAST(
        CASE
            WHEN order_count = 0 THEN NULL
            ELSE item_value / order_count
        END
        AS DECIMAL(18,2)
    ) AS item_value_per_order
FROM MonthlyItems;
GO


/* ================================================================
   10. STATE PERFORMANCE VIEW
   Grain: one row per customer state.

   Orders and item metrics are aggregated independently to avoid
   multiplying item rows by other fact tables.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_state_performance;
GO

CREATE VIEW dbo.vw_state_performance
AS
WITH OrderAgg AS
(
    SELECT
        dc.customer_state,
        COUNT_BIG(*) AS order_count,
        SUM(CASE WHEN co.is_delivered = 1 THEN 1 ELSE 0 END)
            AS delivered_order_count,
        SUM(CASE WHEN co.is_cancelled = 1 THEN 1 ELSE 0 END)
            AS cancelled_order_count,
        AVG(CAST(co.delivery_days AS DECIMAL(18,2)))
            AS average_delivery_days,
        AVG(CAST(co.delivery_delay_days AS DECIMAL(18,2)))
            AS average_delivery_delay_days
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.dim_customer AS dc
        ON fo.customer_key = dc.customer_key
    INNER JOIN dbo.cond_order AS co
        ON fo.order_key = co.order_key
    WHERE dc.customer_state IS NOT NULL
    GROUP BY dc.customer_state
),
ItemAgg AS
(
    SELECT
        dc.customer_state,
        COUNT_BIG(*) AS item_count,
        SUM(ISNULL(foi.price,0)) AS item_value,
        SUM(ISNULL(foi.freight_value,0)) AS freight_value
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.dim_customer AS dc
        ON fo.customer_key = dc.customer_key
    INNER JOIN dbo.fact_order_item AS foi
        ON fo.order_id = foi.order_id
    WHERE dc.customer_state IS NOT NULL
    GROUP BY dc.customer_state
)
SELECT
    oa.customer_state,
    oa.order_count,
    oa.delivered_order_count,
    oa.cancelled_order_count,
    ia.item_count,

    CAST(ISNULL(ia.item_value,0) AS DECIMAL(18,2)) AS item_value,
    CAST(ISNULL(ia.freight_value,0) AS DECIMAL(18,2)) AS freight_value,

    CAST(oa.average_delivery_days AS DECIMAL(18,2))
        AS average_delivery_days,

    CAST(oa.average_delivery_delay_days AS DECIMAL(18,2))
        AS average_delivery_delay_days

FROM OrderAgg AS oa
LEFT JOIN ItemAgg AS ia
    ON oa.customer_state = ia.customer_state;
GO


/* ================================================================
   11. REVIEW PERFORMANCE VIEW
   Grain: one row per review score.

   This is a reporting aggregation, not a fact table.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_review_performance;
GO

CREATE VIEW dbo.vw_review_performance
AS
SELECT
    cr.review_score,
    cr.review_band,
    COUNT_BIG(*) AS review_count,
    SUM(CASE WHEN cr.has_comment_message = 1 THEN 1 ELSE 0 END)
        AS reviews_with_message,
    AVG(CAST(cr.answer_delay_days AS DECIMAL(18,2)))
        AS average_answer_delay_days
FROM dbo.cond_review AS cr
WHERE cr.review_score IS NOT NULL
GROUP BY
    cr.review_score,
    cr.review_band;
GO


/* ================================================================
   12. PAYMENT PERFORMANCE VIEW
   Grain: one row per payment type.

   Payment value is intentionally kept separate from item_value.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_payment_performance;
GO

CREATE VIEW dbo.vw_payment_performance
AS
SELECT
    cp.payment_type,
    COUNT_BIG(*) AS payment_count,
    COUNT(DISTINCT cp.order_id) AS order_count,
    SUM(ISNULL(cp.payment_value,0)) AS payment_value,
    AVG(CAST(cp.payment_value AS DECIMAL(18,2)))
        AS average_payment_value,
    AVG(CAST(cp.payment_installments AS DECIMAL(18,2)))
        AS average_installments,
    SUM(CASE WHEN cp.is_high_installment = 1 THEN 1 ELSE 0 END)
        AS high_installment_payment_count
FROM dbo.cond_payment AS cp
GROUP BY cp.payment_type;
GO


/* ================================================================
   13. DELIVERY PERFORMANCE VIEW
   Grain: one row per purchase year/month.

   Only orders with known delivery outcome are included in the
   delivery averages.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_delivery_performance;
GO

CREATE VIEW dbo.vw_delivery_performance
AS
SELECT
    dd.calendar_year,
    dd.calendar_month,
    COUNT_BIG(*) AS delivered_order_count,

    SUM(CASE WHEN co.is_delivery_late = 1 THEN 1 ELSE 0 END)
        AS late_delivery_count,

    SUM(CASE WHEN co.is_delivery_on_time = 1 THEN 1 ELSE 0 END)
        AS on_time_delivery_count,

    AVG(CAST(co.delivery_days AS DECIMAL(18,2)))
        AS average_delivery_days,

    AVG(CAST(co.delivery_delay_days AS DECIMAL(18,2)))
        AS average_delivery_delay_days

FROM dbo.fact_order AS fo
INNER JOIN dbo.dim_date AS dd
    ON fo.purchase_date_key = dd.date_key
INNER JOIN dbo.cond_order AS co
    ON fo.order_key = co.order_key
WHERE co.is_delivered = 1
GROUP BY
    dd.calendar_year,
    dd.calendar_month;
GO


/* ================================================================
   14. EXECUTIVE KPI VIEW
   Grain: one row.

   Item value and payment value are intentionally displayed as
   separate measures. They should not be added together.
   ================================================================ */

DROP VIEW IF EXISTS dbo.vw_executive_kpis;
GO

CREATE VIEW dbo.vw_executive_kpis
AS
/* customer_key belongs to fact_order, not cond_order. */
WITH OrderKPI AS
(
    SELECT
        COUNT_BIG(*) AS total_orders,
        COUNT(DISTINCT customer_key) AS unique_customers,
        SUM(CASE WHEN co.is_delivered = 1 THEN 1 ELSE 0 END)
            AS delivered_orders,
        SUM(CASE WHEN co.is_cancelled = 1 THEN 1 ELSE 0 END)
            AS cancelled_orders,
        SUM(CASE WHEN co.is_delivery_late = 1 THEN 1 ELSE 0 END)
            AS late_deliveries
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.cond_order AS co
        ON fo.order_key = co.order_key
),
ItemKPI AS
(
    SELECT
        COUNT_BIG(*) AS total_order_items,
        SUM(ISNULL(price,0)) AS total_item_value,
        SUM(ISNULL(freight_value,0)) AS total_freight_value
    FROM dbo.fact_order_item
),
PaymentKPI AS
(
    SELECT
        SUM(ISNULL(payment_value,0)) AS total_payment_value
    FROM dbo.fact_payment
),
ReviewKPI AS
(
    SELECT
        COUNT_BIG(*) AS total_reviews,
        AVG(CAST(review_score AS DECIMAL(18,2))) AS average_review_score
    FROM dbo.fact_review
)
SELECT
    ok.total_orders,
    ok.unique_customers,
    ok.delivered_orders,
    ok.cancelled_orders,
    ok.late_deliveries,

    ik.total_order_items,
    CAST(ik.total_item_value AS DECIMAL(18,2)) AS total_item_value,
    CAST(ik.total_freight_value AS DECIMAL(18,2)) AS total_freight_value,

    CAST(pk.total_payment_value AS DECIMAL(18,2))
        AS total_payment_value,

    rk.total_reviews,
    rk.average_review_score

FROM OrderKPI AS ok
CROSS JOIN ItemKPI AS ik
CROSS JOIN PaymentKPI AS pk
CROSS JOIN ReviewKPI AS rk;
GO


/* ================================================================
   15. VIEW INVENTORY / OBJECT CHECK
   ================================================================ */

PRINT '===============================================================';
PRINT 'CREATED REPORTING VIEWS';
PRINT '===============================================================';

SELECT
    v.name AS view_name
FROM sys.views AS v
WHERE v.name LIKE 'vw[_]%'
ORDER BY v.name;
GO


/* ================================================================
   16. SAMPLE CHECKS
   ================================================================ */

SELECT TOP (20) *
FROM dbo.vw_monthly_sales
ORDER BY month_start;
GO

SELECT TOP (20) *
FROM dbo.vw_category_performance
ORDER BY item_value DESC;
GO

SELECT TOP (20) *
FROM dbo.vw_state_performance
ORDER BY item_value DESC;
GO

SELECT *
FROM dbo.vw_executive_kpis;
GO


/* ================================================================
   17. FINISH
   ================================================================ */

PRINT '===============================================================';
PRINT '05 - REPORTING VIEWS COMPLETE';
PRINT '===============================================================';
PRINT 'Next layer: 06_INDEXES.sql';
PRINT '===============================================================';
GO
