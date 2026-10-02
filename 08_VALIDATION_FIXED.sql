/* ================================================================
   OLIST E-COMMERCE PROJECT
   08_VALIDATION.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Validate the actual normalized schema and reporting views.

   IMPORTANT
   ----------
   This version uses the verified column names supplied from the
   user's INFORMATION_SCHEMA output. It does not assume generic
   category_name/item_value names where they are not present.
   Read-only: no INSERT/UPDATE/DELETE/DROP/ALTER operations.
   ================================================================ */

USE [Sql_project];
GO
SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '08 - VALIDATION START';
PRINT '===============================================================';


/* ================================================================
   A. REQUIRED TABLES
   ================================================================ */

PRINT 'A. REQUIRED TABLE CHECK';

DECLARE @RequiredTables TABLE (table_name SYSNAME NOT NULL);

INSERT INTO @RequiredTables(table_name)
VALUES
('fact_order'),
('fact_order_item'),
('fact_payment'),
('fact_review'),
('dim_customer'),
('dim_product'),
('dim_seller'),
('dim_geolocation'),
('dim_date'),
('dim_category'),
('cond_order'),
('cond_order_item'),
('cond_customer'),
('cond_seller'),
('cond_product'),
('cond_payment'),
('cond_review');

SELECT
    table_name,
    CASE WHEN OBJECT_ID('dbo.' + table_name, 'U') IS NOT NULL
         THEN 'PRESENT' ELSE 'MISSING' END AS validation_status
FROM @RequiredTables
ORDER BY table_name;
GO


/* ================================================================
   B. REQUIRED VIEWS
   ================================================================ */

PRINT 'B. REQUIRED VIEW CHECK';

DECLARE @RequiredViews TABLE (view_name SYSNAME NOT NULL);

INSERT INTO @RequiredViews(view_name)
VALUES
('vw_order_report'),
('vw_order_item_report'),
('vw_payment_report'),
('vw_review_report'),
('vw_customer_performance'),
('vw_seller_performance'),
('vw_product_performance'),
('vw_category_performance'),
('vw_monthly_sales'),
('vw_state_performance'),
('vw_review_performance'),
('vw_payment_performance'),
('vw_delivery_performance'),
('vw_executive_kpis');

SELECT
    view_name,
    CASE WHEN OBJECT_ID('dbo.' + view_name, 'V') IS NOT NULL
         THEN 'PRESENT' ELSE 'MISSING' END AS validation_status
FROM @RequiredViews
ORDER BY view_name;
GO


/* ================================================================
   C. ROW COUNTS
   ================================================================ */

PRINT 'C. NORMALIZED TABLE ROW COUNTS';

SELECT 'fact_order' AS object_name, COUNT_BIG(*) AS row_count FROM dbo.fact_order
UNION ALL SELECT 'fact_order_item', COUNT_BIG(*) FROM dbo.fact_order_item
UNION ALL SELECT 'fact_payment', COUNT_BIG(*) FROM dbo.fact_payment
UNION ALL SELECT 'fact_review', COUNT_BIG(*) FROM dbo.fact_review
UNION ALL SELECT 'dim_customer', COUNT_BIG(*) FROM dbo.dim_customer
UNION ALL SELECT 'dim_product', COUNT_BIG(*) FROM dbo.dim_product
UNION ALL SELECT 'dim_seller', COUNT_BIG(*) FROM dbo.dim_seller
UNION ALL SELECT 'dim_geolocation', COUNT_BIG(*) FROM dbo.dim_geolocation
UNION ALL SELECT 'dim_date', COUNT_BIG(*) FROM dbo.dim_date
UNION ALL SELECT 'dim_category', COUNT_BIG(*) FROM dbo.dim_category
UNION ALL SELECT 'cond_order', COUNT_BIG(*) FROM dbo.cond_order
UNION ALL SELECT 'cond_order_item', COUNT_BIG(*) FROM dbo.cond_order_item
UNION ALL SELECT 'cond_customer', COUNT_BIG(*) FROM dbo.cond_customer
UNION ALL SELECT 'cond_seller', COUNT_BIG(*) FROM dbo.cond_seller
UNION ALL SELECT 'cond_product', COUNT_BIG(*) FROM dbo.cond_product
UNION ALL SELECT 'cond_payment', COUNT_BIG(*) FROM dbo.cond_payment
UNION ALL SELECT 'cond_review', COUNT_BIG(*) FROM dbo.cond_review
ORDER BY object_name;
GO


/* ================================================================
   D. PRIMARY-GRAIN DUPLICATE CHECKS
   ================================================================ */

PRINT 'D. PRIMARY GRAIN DUPLICATE CHECKS';

SELECT
    'fact_order.order_id' AS grain_name,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT order_id) AS duplicate_excess_rows
FROM dbo.fact_order

UNION ALL

SELECT
    'fact_order_item.(order_id,order_item_id)',
    COUNT_BIG(*) -
    COUNT_BIG(DISTINCT CONCAT(order_id, '|', CONVERT(varchar(20),order_item_id)))
FROM dbo.fact_order_item

UNION ALL

SELECT
    'fact_payment.(order_id,payment_sequential)',
    COUNT_BIG(*) -
    COUNT_BIG(DISTINCT CONCAT(order_id, '|', CONVERT(varchar(20),payment_sequential)))
FROM dbo.fact_payment

UNION ALL

SELECT
    'fact_review.review_id',
    COUNT_BIG(*) - COUNT_BIG(DISTINCT review_id)
FROM dbo.fact_review;
GO


/* ================================================================
   E. FACT -> DIM REFERENTIAL INTEGRITY
   ================================================================ */

PRINT 'E. FACT TO DIM REFERENTIAL INTEGRITY';

SELECT
    'fact_order.customer_key -> dim_customer' AS relationship_name,
    COUNT_BIG(*) AS orphan_rows
FROM dbo.fact_order fo
LEFT JOIN dbo.dim_customer dc
    ON fo.customer_key = dc.customer_key
WHERE fo.customer_key IS NOT NULL
  AND dc.customer_key IS NULL

UNION ALL

SELECT
    'fact_order.purchase_date_key -> dim_date',
    COUNT_BIG(*)
FROM dbo.fact_order fo
LEFT JOIN dbo.dim_date dd
    ON fo.purchase_date_key = dd.date_key
WHERE fo.purchase_date_key IS NOT NULL
  AND dd.date_key IS NULL

UNION ALL

SELECT
    'fact_order_item.product_key -> dim_product',
    COUNT_BIG(*)
FROM dbo.fact_order_item foi
LEFT JOIN dbo.dim_product dp
    ON foi.product_key = dp.product_key
WHERE foi.product_key IS NOT NULL
  AND dp.product_key IS NULL

UNION ALL

SELECT
    'fact_order_item.seller_key -> dim_seller',
    COUNT_BIG(*)
FROM dbo.fact_order_item foi
LEFT JOIN dbo.dim_seller ds
    ON foi.seller_key = ds.seller_key
WHERE foi.seller_key IS NOT NULL
  AND ds.seller_key IS NULL

UNION ALL

SELECT
    'fact_order_item.order_id -> fact_order',
    COUNT_BIG(*)
FROM dbo.fact_order_item foi
LEFT JOIN dbo.fact_order fo
    ON foi.order_id = fo.order_id
WHERE fo.order_id IS NULL

UNION ALL

SELECT
    'fact_payment.order_id -> fact_order',
    COUNT_BIG(*)
FROM dbo.fact_payment fp
LEFT JOIN dbo.fact_order fo
    ON fp.order_id = fo.order_id
WHERE fo.order_id IS NULL

UNION ALL

SELECT
    'fact_review.order_id -> fact_order',
    COUNT_BIG(*)
FROM dbo.fact_review fr
LEFT JOIN dbo.fact_order fo
    ON fr.order_id = fo.order_id
WHERE fo.order_id IS NULL;
GO


/* ================================================================
   F. CONDITION-LAYER COVERAGE
   ================================================================ */

PRINT 'F. CONDITION TABLE COVERAGE';

SELECT
    'cond_order vs fact_order' AS relationship_name,
    (SELECT COUNT_BIG(*) FROM dbo.fact_order) AS base_rows,
    (SELECT COUNT_BIG(*) FROM dbo.cond_order) AS condition_rows,
    (SELECT COUNT_BIG(*) FROM dbo.fact_order) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_order) AS row_difference

UNION ALL
SELECT
    'cond_order_item vs fact_order_item',
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item),
    (SELECT COUNT_BIG(*) FROM dbo.cond_order_item),
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_order_item)

UNION ALL
SELECT
    'cond_customer vs dim_customer',
    (SELECT COUNT_BIG(*) FROM dbo.dim_customer),
    (SELECT COUNT_BIG(*) FROM dbo.cond_customer),
    (SELECT COUNT_BIG(*) FROM dbo.dim_customer) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_customer)

UNION ALL
SELECT
    'cond_seller vs dim_seller',
    (SELECT COUNT_BIG(*) FROM dbo.dim_seller),
    (SELECT COUNT_BIG(*) FROM dbo.cond_seller),
    (SELECT COUNT_BIG(*) FROM dbo.dim_seller) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_seller)

UNION ALL
SELECT
    'cond_product vs dim_product',
    (SELECT COUNT_BIG(*) FROM dbo.dim_product),
    (SELECT COUNT_BIG(*) FROM dbo.cond_product),
    (SELECT COUNT_BIG(*) FROM dbo.dim_product) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_product)

UNION ALL
SELECT
    'cond_payment vs fact_payment',
    (SELECT COUNT_BIG(*) FROM dbo.fact_payment),
    (SELECT COUNT_BIG(*) FROM dbo.cond_payment),
    (SELECT COUNT_BIG(*) FROM dbo.fact_payment) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_payment)

UNION ALL
SELECT
    'cond_review vs fact_review',
    (SELECT COUNT_BIG(*) FROM dbo.fact_review),
    (SELECT COUNT_BIG(*) FROM dbo.cond_review),
    (SELECT COUNT_BIG(*) FROM dbo.fact_review) -
    (SELECT COUNT_BIG(*) FROM dbo.cond_review);
GO


/* ================================================================
   G. CRITICAL NULL CHECKS
   ================================================================ */

PRINT 'G. CRITICAL NULL CHECKS';

SELECT 'fact_order.order_id' AS column_name, COUNT_BIG(*) AS null_count
FROM dbo.fact_order WHERE order_id IS NULL
UNION ALL
SELECT 'fact_order.customer_key', COUNT_BIG(*)
FROM dbo.fact_order WHERE customer_key IS NULL
UNION ALL
SELECT 'fact_order.purchase_date_key', COUNT_BIG(*)
FROM dbo.fact_order WHERE purchase_date_key IS NULL
UNION ALL
SELECT 'fact_order_item.order_id', COUNT_BIG(*)
FROM dbo.fact_order_item WHERE order_id IS NULL
UNION ALL
SELECT 'fact_order_item.product_key', COUNT_BIG(*)
FROM dbo.fact_order_item WHERE product_key IS NULL
UNION ALL
SELECT 'fact_order_item.seller_key', COUNT_BIG(*)
FROM dbo.fact_order_item WHERE seller_key IS NULL
UNION ALL
SELECT 'fact_payment.order_id', COUNT_BIG(*)
FROM dbo.fact_payment WHERE order_id IS NULL
UNION ALL
SELECT 'fact_review.order_id', COUNT_BIG(*)
FROM dbo.fact_review WHERE order_id IS NULL;
GO


/* ================================================================
   H. DOMAIN VALIDATION
   ================================================================ */

PRINT 'H. DOMAIN VALIDATION';

SELECT 'Invalid review scores' AS check_name, COUNT_BIG(*) AS issue_count
FROM dbo.fact_review
WHERE review_score IS NOT NULL AND review_score NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'Negative item prices', COUNT_BIG(*)
FROM dbo.fact_order_item WHERE price < 0
UNION ALL
SELECT 'Negative freight values', COUNT_BIG(*)
FROM dbo.fact_order_item WHERE freight_value < 0
UNION ALL
SELECT 'Non-positive payment values', COUNT_BIG(*)
FROM dbo.fact_payment WHERE payment_value <= 0
UNION ALL
SELECT 'Negative product weight', COUNT_BIG(*)
FROM dbo.dim_product
WHERE product_weight_g IS NOT NULL AND product_weight_g < 0
UNION ALL
SELECT 'Negative product length', COUNT_BIG(*)
FROM dbo.dim_product
WHERE product_length_cm IS NOT NULL AND product_length_cm < 0
UNION ALL
SELECT 'Negative product height', COUNT_BIG(*)
FROM dbo.dim_product
WHERE product_height_cm IS NOT NULL AND product_height_cm < 0
UNION ALL
SELECT 'Negative product width', COUNT_BIG(*)
FROM dbo.dim_product
WHERE product_width_cm IS NOT NULL AND product_width_cm < 0;
GO


/* ================================================================
   I. CONDITION FLAG DOMAIN CHECK
   ================================================================ */

PRINT 'I. CONDITION FLAG DOMAIN CHECK';

SELECT 'cond_order.is_delivered' AS column_name, COUNT_BIG(*) AS invalid_rows
FROM dbo.cond_order WHERE is_delivered NOT IN (0,1)
UNION ALL
SELECT 'cond_order.is_cancelled', COUNT_BIG(*)
FROM dbo.cond_order WHERE is_cancelled NOT IN (0,1)
UNION ALL
SELECT 'cond_order.is_delivery_late', COUNT_BIG(*)
FROM dbo.cond_order WHERE is_delivery_late NOT IN (0,1)
UNION ALL
SELECT 'cond_payment.is_high_installment', COUNT_BIG(*)
FROM dbo.cond_payment WHERE is_high_installment NOT IN (0,1)
UNION ALL
SELECT 'cond_review.has_comment_message', COUNT_BIG(*)
FROM dbo.cond_review WHERE has_comment_message NOT IN (0,1);
GO


/* ================================================================
   J. VERIFIED CATEGORY DIMENSION CHECK
   Uses the ACTUAL names:
       product_category_name
       product_category_name_english
   ================================================================ */

PRINT 'J. CATEGORY DIMENSION CHECK';

SELECT
    COUNT_BIG(*) AS category_rows,
    COUNT_BIG(DISTINCT product_category_name) AS distinct_portuguese_names,
    COUNT_BIG(DISTINCT product_category_name_english) AS distinct_english_names
FROM dbo.dim_category;
GO

SELECT TOP (20)
    category_key,
    product_category_name,
    product_category_name_english
FROM dbo.dim_category
ORDER BY category_key;
GO


/* ================================================================
   K. VERIFIED FACT-LEVEL BUSINESS RECONCILIATION
   No guessed view aliases.
   ================================================================ */

PRINT 'K. FACT-LEVEL BUSINESS RECONCILIATION';

SELECT
    'fact_order_item.item_gross_value' AS check_name,
    CAST(SUM(item_gross_value) AS DECIMAL(18,2)) AS total_value
FROM dbo.fact_order_item

UNION ALL

SELECT
    'fact_order_item.freight_value',
    CAST(SUM(freight_value) AS DECIMAL(18,2))
FROM dbo.fact_order_item

UNION ALL

SELECT
    'fact_payment.payment_value',
    CAST(SUM(payment_value) AS DECIMAL(18,2))
FROM dbo.fact_payment;
GO


/* ================================================================
   L. VERIFIED VIEW RECONCILIATION
   Uses ONLY columns confirmed by INFORMATION_SCHEMA.
   ================================================================ */

PRINT 'L. VIEW RECONCILIATION';

SELECT
    'Order item count: fact vs view' AS check_name,
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item) AS fact_rows,
    (SELECT COUNT_BIG(*) FROM dbo.vw_order_item_report) AS view_rows,
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item)
      - (SELECT COUNT_BIG(*) FROM dbo.vw_order_item_report) AS difference

UNION ALL

SELECT
    'Order item gross value: fact vs view',
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item),
    (SELECT COUNT_BIG(*) FROM dbo.vw_order_item_report),
    NULL;
GO

SELECT
    'Order item gross value',
    CAST((SELECT SUM(item_gross_value)
          FROM dbo.fact_order_item) AS DECIMAL(18,2)) AS fact_value,
    CAST((SELECT SUM(item_gross_value)
          FROM dbo.vw_order_item_report) AS DECIMAL(18,2)) AS view_value,
    CAST(
        (SELECT SUM(item_gross_value) FROM dbo.fact_order_item)
        -
        (SELECT SUM(item_gross_value) FROM dbo.vw_order_item_report)
        AS DECIMAL(18,2)
    ) AS difference

UNION ALL

SELECT
    'Freight value',
    CAST((SELECT SUM(freight_value)
          FROM dbo.fact_order_item) AS DECIMAL(18,2)),
    CAST((SELECT SUM(freight_value)
          FROM dbo.vw_order_item_report) AS DECIMAL(18,2)),
    CAST(
        (SELECT SUM(freight_value) FROM dbo.fact_order_item)
        -
        (SELECT SUM(freight_value) FROM dbo.vw_order_item_report)
        AS DECIMAL(18,2)
    );
GO

SELECT
    'Payment count: fact vs view' AS check_name,
    (SELECT COUNT_BIG(*) FROM dbo.fact_payment) AS fact_rows,
    (SELECT COUNT_BIG(*) FROM dbo.vw_payment_report) AS view_rows,
    (SELECT COUNT_BIG(*) FROM dbo.fact_payment)
      - (SELECT COUNT_BIG(*) FROM dbo.vw_payment_report) AS difference

UNION ALL

SELECT
    'Payment value: fact vs view',
    (SELECT SUM(payment_value) FROM dbo.fact_payment),
    (SELECT SUM(payment_value) FROM dbo.vw_payment_report),
    (SELECT SUM(payment_value) FROM dbo.fact_payment)
      - (SELECT SUM(payment_value) FROM dbo.vw_payment_report);
GO

SELECT
    'Review count: fact vs view' AS check_name,
    (SELECT COUNT_BIG(*) FROM dbo.fact_review) AS fact_rows,
    (SELECT COUNT_BIG(*) FROM dbo.vw_review_report) AS view_rows,
    (SELECT COUNT_BIG(*) FROM dbo.fact_review)
      - (SELECT COUNT_BIG(*) FROM dbo.vw_review_report) AS difference;
GO


/* ================================================================
   M. DELIVERY LOGIC CHECK
   ================================================================ */

PRINT 'M. DELIVERY LOGIC CHECK';

SELECT
    'Delivered order missing delivery date' AS check_name,
    COUNT_BIG(*) AS issue_count
FROM dbo.fact_order
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL

UNION ALL

SELECT
    'Non-delivered order has delivered date',
    COUNT_BIG(*)
FROM dbo.fact_order
WHERE order_status <> 'delivered'
  AND order_delivered_customer_date IS NOT NULL

UNION ALL

SELECT
    'Delivery date before purchase date',
    COUNT_BIG(*)
FROM dbo.fact_order
WHERE order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp

UNION ALL

SELECT
    'Estimated date before purchase date',
    COUNT_BIG(*)
FROM dbo.fact_order
WHERE order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_estimated_delivery_date < order_purchase_timestamp;
GO


/* ================================================================
   N. PROJECT INDEX CHECK
   ================================================================ */

PRINT 'N. PROJECT INDEX CHECK';

SELECT COUNT(*) AS project_index_count
FROM sys.indexes
WHERE name LIKE 'IX[_]fact[_]%'
   OR name LIKE 'IX[_]dim[_]%'
   OR name LIKE 'IX[_]cond[_]%';
GO


/* ================================================================
   O. FINAL VALIDATION SUMMARY
   ================================================================ */

PRINT 'O. FINAL VALIDATION SUMMARY';

DECLARE
    @orphan_count BIGINT = 0,
    @duplicate_count BIGINT = 0,
    @domain_issue_count BIGINT = 0,
    @critical_null_count BIGINT = 0;

SELECT @orphan_count =
    (SELECT COUNT_BIG(*)
     FROM dbo.fact_order_item foi
     LEFT JOIN dbo.fact_order fo ON foi.order_id = fo.order_id
     WHERE fo.order_id IS NULL)
    +
    (SELECT COUNT_BIG(*)
     FROM dbo.fact_payment fp
     LEFT JOIN dbo.fact_order fo ON fp.order_id = fo.order_id
     WHERE fo.order_id IS NULL)
    +
    (SELECT COUNT_BIG(*)
     FROM dbo.fact_review fr
     LEFT JOIN dbo.fact_order fo ON fr.order_id = fo.order_id
     WHERE fo.order_id IS NULL);

SELECT @duplicate_count =
    (SELECT COUNT_BIG(*)
     FROM (
         SELECT order_id
         FROM dbo.fact_order
         GROUP BY order_id
         HAVING COUNT_BIG(*) > 1
     ) x);

SELECT @domain_issue_count =
    (SELECT COUNT_BIG(*) FROM dbo.fact_review
     WHERE review_score IS NOT NULL AND review_score NOT BETWEEN 1 AND 5)
    +
    (SELECT COUNT_BIG(*) FROM dbo.fact_order_item
     WHERE price < 0 OR freight_value < 0)
    +
    (SELECT COUNT_BIG(*) FROM dbo.fact_payment
     WHERE payment_value <= 0);

SELECT @critical_null_count =
    (SELECT COUNT_BIG(*) FROM dbo.fact_order
     WHERE order_id IS NULL OR customer_key IS NULL);

SELECT
    @orphan_count AS orphan_rows,
    @duplicate_count AS duplicate_order_ids,
    @domain_issue_count AS domain_issues,
    @critical_null_count AS critical_nulls,
    CASE
        WHEN @orphan_count = 0
         AND @duplicate_count = 0
         AND @domain_issue_count = 0
         AND @critical_null_count = 0
        THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END AS validation_status;
GO

PRINT '===============================================================';
PRINT '08 - VALIDATION COMPLETE';
PRINT '===============================================================';
PRINT 'Next layer: 09_PERFORMANCE_TEST.sql';
PRINT '===============================================================';
GO
