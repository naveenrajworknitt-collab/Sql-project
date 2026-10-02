/* ================================================================
   OLIST E-COMMERCE PROJECT
   EDA.SQL
   SQL Server / SSMS
   Database shown in the user's SSMS screenshot: Sql_project

   IMPORTANT:
   - This script uses the exact Olist source-table names shown in SSMS.
   - dbo.product_category_name_translation has physical columns column1 and column2;
     column1 contains the source category name and column2 contains the English category.
   - product_name_lenght and product_description_lenght deliberately
     keep the original Olist spelling ("lenght").
   - No ALTER/UPDATE/DELETE statements are used.
   - Run this script in the Sql_project database.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

/* ================================================================
   00. SCHEMA / TABLE PREFLIGHT
   ================================================================ */

PRINT '===============================================================';
PRINT '00 - TABLE PREFLIGHT';
PRINT '===============================================================';

DECLARE @ExpectedTables TABLE
(
    table_name sysname NOT NULL PRIMARY KEY
);

INSERT INTO @ExpectedTables(table_name)
VALUES
('olist_customers_dataset'),
('olist_geolocation_dataset'),
('olist_order_items_dataset'),
('olist_order_payments_dataset'),
('olist_order_reviews_dataset'),
('olist_orders_dataset'),
('olist_products_dataset'),
('olist_sellers_dataset'),
('product_category_name_translation');

SELECT
    e.table_name,
    CASE
        WHEN t.object_id IS NULL THEN 'MISSING'
        ELSE 'OK'
    END AS table_status
FROM @ExpectedTables AS e
LEFT JOIN sys.tables AS t
    ON t.name = e.table_name
LEFT JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
   AND s.name = 'dbo'
ORDER BY e.table_name;
GO

/* ================================================================
   01. TABLE ROW COUNTS
   ================================================================ */

PRINT '===============================================================';
PRINT '01 - ROW COUNTS';
PRINT '===============================================================';

SELECT 'olist_customers_dataset' AS table_name,
       COUNT_BIG(*) AS row_count
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'olist_geolocation_dataset',
       COUNT_BIG(*)
FROM dbo.olist_geolocation_dataset
UNION ALL
SELECT 'olist_order_items_dataset',
       COUNT_BIG(*)
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'olist_order_payments_dataset',
       COUNT_BIG(*)
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'olist_order_reviews_dataset',
       COUNT_BIG(*)
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'olist_orders_dataset',
       COUNT_BIG(*)
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'olist_products_dataset',
       COUNT_BIG(*)
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'olist_sellers_dataset',
       COUNT_BIG(*)
FROM dbo.olist_sellers_dataset
UNION ALL
SELECT 'product_category_name_translation',
       COUNT_BIG(*)
FROM dbo.product_category_name_translation
ORDER BY table_name;
GO

/* ================================================================
   02. EXACT COLUMN INVENTORY
   ================================================================ */

PRINT '===============================================================';
PRINT '02 - COLUMN INVENTORY';
PRINT '===============================================================';

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE s.name = 'dbo'
  AND t.name IN
  (
      'olist_customers_dataset',
      'olist_geolocation_dataset',
      'olist_order_items_dataset',
      'olist_order_payments_dataset',
      'olist_order_reviews_dataset',
      'olist_orders_dataset',
      'olist_products_dataset',
      'olist_sellers_dataset',
      'product_category_name_translation'
  )
ORDER BY t.name, c.column_id;
GO

/* ================================================================
   03. NULL PROFILE
   ================================================================ */

PRINT '===============================================================';
PRINT '03 - NULL PROFILE';
PRINT '===============================================================';

SELECT 'customers' AS table_name, 'customer_id' AS column_name,
       COUNT_BIG(*) AS total_rows,
       SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_rows,
       CAST(100.0 * SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2)) AS null_pct
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'customers','customer_unique_id',COUNT_BIG(*),
       SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'customers','customer_zip_code_prefix',COUNT_BIG(*),
       SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'customers','customer_city',COUNT_BIG(*),
       SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'customers','customer_state',COUNT_BIG(*),
       SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_customers_dataset

UNION ALL
SELECT 'orders','order_id',COUNT_BIG(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','customer_id',COUNT_BIG(*),
       SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_status',COUNT_BIG(*),
       SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_purchase_timestamp',COUNT_BIG(*),
       SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_approved_at',COUNT_BIG(*),
       SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_delivered_carrier_date',COUNT_BIG(*),
       SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_delivered_customer_date',COUNT_BIG(*),
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'orders','order_estimated_delivery_date',COUNT_BIG(*),
       SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_orders_dataset

UNION ALL
SELECT 'order_items','order_id',COUNT_BIG(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','order_item_id',COUNT_BIG(*),
       SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','product_id',COUNT_BIG(*),
       SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','seller_id',COUNT_BIG(*),
       SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','shipping_limit_date',COUNT_BIG(*),
       SUM(CASE WHEN shipping_limit_date IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN shipping_limit_date IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','price',COUNT_BIG(*),
       SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'order_items','freight_value',COUNT_BIG(*),
       SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_items_dataset

UNION ALL
SELECT 'payments','order_id',COUNT_BIG(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'payments','payment_sequential',COUNT_BIG(*),
       SUM(CASE WHEN payment_sequential IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN payment_sequential IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'payments','payment_type',COUNT_BIG(*),
       SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'payments','payment_installments',COUNT_BIG(*),
       SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'payments','payment_value',COUNT_BIG(*),
       SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_payments_dataset

UNION ALL
SELECT 'reviews','review_id',COUNT_BIG(*),
       SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','order_id',COUNT_BIG(*),
       SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','review_score',COUNT_BIG(*),
       SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','review_comment_title',COUNT_BIG(*),
       SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','review_comment_message',COUNT_BIG(*),
       SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','review_creation_date',COUNT_BIG(*),
       SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'reviews','review_answer_timestamp',COUNT_BIG(*),
       SUM(CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_order_reviews_dataset

UNION ALL
SELECT 'products','product_id',COUNT_BIG(*),
       SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_category_name',COUNT_BIG(*),
       SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_name_lenght',COUNT_BIG(*),
       SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_description_lenght',COUNT_BIG(*),
       SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_photos_qty',COUNT_BIG(*),
       SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_weight_g',COUNT_BIG(*),
       SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_length_cm',COUNT_BIG(*),
       SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_height_cm',COUNT_BIG(*),
       SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'products','product_width_cm',COUNT_BIG(*),
       SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_products_dataset

UNION ALL
SELECT 'sellers','seller_id',COUNT_BIG(*),
       SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_sellers_dataset
UNION ALL
SELECT 'sellers','seller_zip_code_prefix',COUNT_BIG(*),
       SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_sellers_dataset
UNION ALL
SELECT 'sellers','seller_city',COUNT_BIG(*),
       SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_sellers_dataset
UNION ALL
SELECT 'sellers','seller_state',COUNT_BIG(*),
       SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.olist_sellers_dataset

UNION ALL
SELECT 'translation','column1',COUNT_BIG(*),
       SUM(CASE WHEN column1 IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN column1 IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.product_category_name_translation
UNION ALL
SELECT 'translation','column2',COUNT_BIG(*),
       SUM(CASE WHEN column2 IS NULL THEN 1 ELSE 0 END),
       CAST(100.0 * SUM(CASE WHEN column2 IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT_BIG(*),0) AS decimal(9,2))
FROM dbo.product_category_name_translation;
GO

/* ================================================================
   04. DUPLICATE / KEY ANALYSIS
   ================================================================ */

PRINT '===============================================================';
PRINT '04 - KEY / DUPLICATE ANALYSIS';
PRINT '===============================================================';

-- Orders: expected one row per order_id
SELECT
    'orders.order_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT order_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT order_id) AS duplicate_excess_rows
FROM dbo.olist_orders_dataset;

-- Customers: customer_id should be unique; customer_unique_id can repeat
SELECT
    'customers.customer_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT customer_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT customer_id) AS duplicate_excess_rows
FROM dbo.olist_customers_dataset;

SELECT
    'customers.customer_unique_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT customer_unique_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT customer_unique_id) AS repeat_excess_rows
FROM dbo.olist_customers_dataset;

-- Products
SELECT
    'products.product_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT product_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT product_id) AS duplicate_excess_rows
FROM dbo.olist_products_dataset;

-- Sellers
SELECT
    'sellers.seller_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT seller_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT seller_id) AS duplicate_excess_rows
FROM dbo.olist_sellers_dataset;

-- Translation
SELECT
    'translation.column1' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT column1) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT column1) AS duplicate_excess_rows
FROM dbo.product_category_name_translation;

-- Order item grain: order_id + order_item_id
SELECT
    'order_items.(order_id,order_item_id)' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT CONCAT(order_id,'|',CONVERT(varchar(20),order_item_id))) AS distinct_keys
FROM dbo.olist_order_items_dataset;

-- Payments: order_id + payment_sequential
SELECT
    'payments.(order_id,payment_sequential)' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT CONCAT(order_id,'|',CONVERT(varchar(20),payment_sequential))) AS distinct_keys
FROM dbo.olist_order_payments_dataset;

-- Review rows are not assumed to be one-per-order.
SELECT
    'reviews.review_id' AS key_name,
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT review_id) AS distinct_keys,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT review_id) AS duplicate_excess_rows
FROM dbo.olist_order_reviews_dataset;
GO

/* Actual duplicate records */
SELECT order_id, COUNT_BIG(*) AS row_count
FROM dbo.olist_orders_dataset
GROUP BY order_id
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;

SELECT customer_id, COUNT_BIG(*) AS row_count
FROM dbo.olist_customers_dataset
GROUP BY customer_id
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;

SELECT product_id, COUNT_BIG(*) AS row_count
FROM dbo.olist_products_dataset
GROUP BY product_id
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;

SELECT seller_id, COUNT_BIG(*) AS row_count
FROM dbo.olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;

SELECT column1, COUNT_BIG(*) AS row_count
FROM dbo.product_category_name_translation
GROUP BY column1
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;
GO

/* ================================================================
   05. DISTINCT / CATEGORICAL EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '05 - CATEGORICAL DISTRIBUTIONS';
PRINT '===============================================================';

SELECT order_status, COUNT_BIG(*) AS orders
FROM dbo.olist_orders_dataset
GROUP BY order_status
ORDER BY orders DESC;

SELECT payment_type, COUNT_BIG(*) AS payment_rows,
       SUM(payment_value) AS total_payment_value
FROM dbo.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_payment_value DESC;

SELECT review_score, COUNT_BIG(*) AS review_count,
       CAST(100.0 * COUNT_BIG(*) /
            NULLIF(SUM(COUNT_BIG(*)) OVER(),0) AS decimal(9,2)) AS pct_reviews
FROM dbo.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;

SELECT seller_state, COUNT_BIG(*) AS sellers
FROM dbo.olist_sellers_dataset
GROUP BY seller_state
ORDER BY sellers DESC;

SELECT customer_state, COUNT_BIG(*) AS customers
FROM dbo.olist_customers_dataset
GROUP BY customer_state
ORDER BY customers DESC;

SELECT product_category_name, COUNT_BIG(*) AS products
FROM dbo.olist_products_dataset
GROUP BY product_category_name
ORDER BY products DESC;
GO

/* ================================================================
   06. DATE RANGE / TEMPORAL EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '06 - DATE RANGE';
PRINT '===============================================================';

SELECT
    MIN(order_purchase_timestamp) AS first_purchase,
    MAX(order_purchase_timestamp) AS last_purchase,
    DATEDIFF(DAY,
             MIN(order_purchase_timestamp),
             MAX(order_purchase_timestamp)) AS days_covered
FROM dbo.olist_orders_dataset;

SELECT
    MIN(order_approved_at) AS first_approval,
    MAX(order_approved_at) AS last_approval
FROM dbo.olist_orders_dataset
WHERE order_approved_at IS NOT NULL;

SELECT
    MIN(order_delivered_customer_date) AS first_customer_delivery,
    MAX(order_delivered_customer_date) AS last_customer_delivery
FROM dbo.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;

-- Orders by year/month
SELECT
    YEAR(order_purchase_timestamp) AS purchase_year,
    MONTH(order_purchase_timestamp) AS purchase_month,
    COUNT_BIG(*) AS orders
FROM dbo.olist_orders_dataset
GROUP BY
    YEAR(order_purchase_timestamp),
    MONTH(order_purchase_timestamp)
ORDER BY purchase_year, purchase_month;

-- Orders by weekday
SELECT
    DATENAME(WEEKDAY, order_purchase_timestamp) AS weekday_name,
    DATEPART(WEEKDAY, order_purchase_timestamp) AS weekday_number,
    COUNT_BIG(*) AS orders
FROM dbo.olist_orders_dataset
GROUP BY
    DATENAME(WEEKDAY, order_purchase_timestamp),
    DATEPART(WEEKDAY, order_purchase_timestamp)
ORDER BY orders DESC;

-- Orders by hour
SELECT
    DATEPART(HOUR, order_purchase_timestamp) AS purchase_hour,
    COUNT_BIG(*) AS orders
FROM dbo.olist_orders_dataset
GROUP BY DATEPART(HOUR, order_purchase_timestamp)
ORDER BY purchase_hour;
GO

/* ================================================================
   07. DATA QUALITY / RANGE CHECKS
   ================================================================ */

PRINT '===============================================================';
PRINT '07 - DATA QUALITY CHECKS';
PRINT '===============================================================';

-- Negative/zero product prices
SELECT
    COUNT_BIG(*) AS invalid_price_rows
FROM dbo.olist_order_items_dataset
WHERE price <= 0;

-- Negative freight
SELECT
    COUNT_BIG(*) AS invalid_freight_rows
FROM dbo.olist_order_items_dataset
WHERE freight_value < 0;

-- Invalid payment values
SELECT
    COUNT_BIG(*) AS invalid_payment_rows
FROM dbo.olist_order_payments_dataset
WHERE payment_value < 0;

-- Invalid payment installments
SELECT
    COUNT_BIG(*) AS invalid_installment_rows
FROM dbo.olist_order_payments_dataset
WHERE payment_installments <= 0;

-- Invalid review score
SELECT
    COUNT_BIG(*) AS invalid_review_score_rows
FROM dbo.olist_order_reviews_dataset
WHERE review_score NOT BETWEEN 1 AND 5;

-- Invalid product dimensions
SELECT
    COUNT_BIG(*) AS invalid_product_dimension_rows
FROM dbo.olist_products_dataset
WHERE product_weight_g < 0
   OR product_length_cm < 0
   OR product_height_cm < 0
   OR product_width_cm < 0;

-- Impossible order chronology
SELECT
    COUNT_BIG(*) AS invalid_order_sequence_rows
FROM dbo.olist_orders_dataset
WHERE
    (order_approved_at IS NOT NULL
     AND order_approved_at < order_purchase_timestamp)
 OR (order_delivered_carrier_date IS NOT NULL
     AND order_delivered_carrier_date < order_purchase_timestamp)
 OR (order_delivered_customer_date IS NOT NULL
     AND order_delivered_customer_date < order_purchase_timestamp)
 OR (order_delivered_customer_date IS NOT NULL
     AND order_delivered_carrier_date IS NOT NULL
     AND order_delivered_customer_date < order_delivered_carrier_date);

-- Delivery later than estimated date
SELECT
    COUNT_BIG(*) AS delivered_late_rows
FROM dbo.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date > order_estimated_delivery_date;
GO

/* ================================================================
   08. ORPHAN / REFERENTIAL INTEGRITY ANALYSIS
   ================================================================ */

PRINT '===============================================================';
PRINT '08 - ORPHAN RECORDS';
PRINT '===============================================================';

-- Orders -> customers
SELECT COUNT_BIG(*) AS orders_without_customer
FROM dbo.olist_orders_dataset AS o
LEFT JOIN dbo.olist_customers_dataset AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items -> orders
SELECT COUNT_BIG(*) AS items_without_order
FROM dbo.olist_order_items_dataset AS oi
LEFT JOIN dbo.olist_orders_dataset AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items -> products
SELECT COUNT_BIG(*) AS items_without_product
FROM dbo.olist_order_items_dataset AS oi
LEFT JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items -> sellers
SELECT COUNT_BIG(*) AS items_without_seller
FROM dbo.olist_order_items_dataset AS oi
LEFT JOIN dbo.olist_sellers_dataset AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments -> orders
SELECT COUNT_BIG(*) AS payments_without_order
FROM dbo.olist_order_payments_dataset AS pay
LEFT JOIN dbo.olist_orders_dataset AS o
    ON pay.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews -> orders
SELECT COUNT_BIG(*) AS reviews_without_order
FROM dbo.olist_order_reviews_dataset AS r
LEFT JOIN dbo.olist_orders_dataset AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Products -> translation
SELECT COUNT_BIG(*) AS products_without_english_category
FROM dbo.olist_products_dataset AS p
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
WHERE p.product_category_name IS NOT NULL
  AND t.column1 IS NULL;
GO

/* ================================================================
   09. PRODUCT CATEGORY TRANSLATION ANALYSIS
   ================================================================ */

PRINT '===============================================================';
PRINT '09 - CATEGORY TRANSLATION';
PRINT '===============================================================';

-- IMPORTANT:
-- The translation table has physical columns column1 and column2.
-- column1 is joined to products.product_category_name;
-- column2 is the English category name.

SELECT
    p.product_category_name,
    t.column2,
    COUNT_BIG(*) AS product_count
FROM dbo.olist_products_dataset AS p
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    p.product_category_name,
    t.column2
ORDER BY product_count DESC;

SELECT
    COUNT_BIG(*) AS products_with_translation
FROM dbo.olist_products_dataset AS p
INNER JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1;

SELECT
    COUNT_BIG(*) AS products_without_translation
FROM dbo.olist_products_dataset AS p
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
WHERE p.product_category_name IS NOT NULL
  AND t.column1 IS NULL;
GO

/* ================================================================
   10. ORDER-LEVEL COMMERCIAL EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '10 - ORDER COMMERCIAL EDA';
PRINT '===============================================================';

-- Order item value and freight by order.
-- This aggregation is important because an order can have multiple items.
SELECT
    oi.order_id,
    COUNT_BIG(*) AS item_rows,
    SUM(oi.price) AS merchandise_value,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS item_plus_freight_value
FROM dbo.olist_order_items_dataset AS oi
GROUP BY oi.order_id
ORDER BY item_plus_freight_value DESC;

-- Overall item revenue
SELECT
    SUM(price) AS merchandise_revenue,
    SUM(freight_value) AS freight_revenue,
    SUM(price + freight_value) AS merchandise_plus_freight
FROM dbo.olist_order_items_dataset;

-- Payment totals
SELECT
    SUM(payment_value) AS total_payment_value,
    AVG(payment_value) AS avg_payment_row_value,
    MIN(payment_value) AS min_payment_row_value,
    MAX(payment_value) AS max_payment_row_value
FROM dbo.olist_order_payments_dataset;

-- Orders with multiple payment records
SELECT
    order_id,
    COUNT_BIG(*) AS payment_count,
    SUM(payment_value) AS total_payment
FROM dbo.olist_order_payments_dataset
GROUP BY order_id
HAVING COUNT_BIG(*) > 1
ORDER BY payment_count DESC, total_payment DESC;
GO

/* ================================================================
   11. CUSTOMER EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '11 - CUSTOMER EDA';
PRINT '===============================================================';

-- One customer_unique_id can have multiple customer_id values.
SELECT
    customer_unique_id,
    COUNT_BIG(*) AS customer_id_count
FROM dbo.olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT_BIG(*) > 1
ORDER BY customer_id_count DESC;

-- Customer order frequency
SELECT
    c.customer_unique_id,
    COUNT_BIG(o.order_id) AS order_count
FROM dbo.olist_customers_dataset AS c
INNER JOIN dbo.olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY order_count DESC;

-- Customer acquisition / repeat behavior
WITH customer_orders AS
(
    SELECT
        c.customer_unique_id,
        COUNT_BIG(o.order_id) AS order_count
    FROM dbo.olist_customers_dataset AS c
    INNER JOIN dbo.olist_orders_dataset AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time'
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'No order'
    END AS customer_type,
    COUNT_BIG(*) AS customers
FROM customer_orders
GROUP BY
    CASE
        WHEN order_count = 1 THEN 'One-time'
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'No order'
    END
ORDER BY customers DESC;
GO

/* ================================================================
   12. DELIVERY PERFORMANCE
   ================================================================ */

PRINT '===============================================================';
PRINT '12 - DELIVERY PERFORMANCE';
PRINT '===============================================================';

SELECT
    AVG(CAST(DATEDIFF(DAY,
        order_purchase_timestamp,
        order_delivered_customer_date) AS decimal(18,2))) AS avg_purchase_to_delivery_days,
    MIN(DATEDIFF(DAY,
        order_purchase_timestamp,
        order_delivered_customer_date)) AS min_purchase_to_delivery_days,
    MAX(DATEDIFF(DAY,
        order_purchase_timestamp,
        order_delivered_customer_date)) AS max_purchase_to_delivery_days
FROM dbo.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;

SELECT
    AVG(CAST(DATEDIFF(DAY,
        order_approved_at,
        order_delivered_carrier_date) AS decimal(18,2))) AS avg_approval_to_carrier_days,
    AVG(CAST(DATEDIFF(DAY,
        order_delivered_carrier_date,
        order_delivered_customer_date) AS decimal(18,2))) AS avg_carrier_to_customer_days
FROM dbo.olist_orders_dataset
WHERE order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- Late / on-time delivery classification
SELECT
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END AS delivery_status,
    COUNT_BIG(*) AS orders
FROM dbo.olist_orders_dataset
GROUP BY
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END
ORDER BY orders DESC;

-- Average delay for delivered orders
SELECT
    AVG(CAST(DATEDIFF(DAY,
        order_estimated_delivery_date,
        order_delivered_customer_date) AS decimal(18,2))) AS avg_delivery_delay_days,
    MAX(DATEDIFF(DAY,
        order_estimated_delivery_date,
        order_delivered_customer_date)) AS max_delivery_delay_days
FROM dbo.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;
GO

/* ================================================================
   13. REVIEW / CUSTOMER SATISFACTION EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '13 - REVIEW EDA';
PRINT '===============================================================';

SELECT
    review_score,
    COUNT_BIG(*) AS reviews,
    AVG(CAST(review_score AS decimal(10,2))) AS score
FROM dbo.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;

-- Review score by delivery status
SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END AS delivery_status,
    COUNT_BIG(r.review_id) AS review_count,
    AVG(CAST(r.review_score AS decimal(10,2))) AS avg_review_score
FROM dbo.olist_order_reviews_dataset AS r
INNER JOIN dbo.olist_orders_dataset AS o
    ON r.order_id = o.order_id
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END
ORDER BY avg_review_score;

-- Reviews with comments
SELECT
    COUNT_BIG(*) AS total_reviews,
    SUM(CASE WHEN review_comment_message IS NOT NULL
                  AND LTRIM(RTRIM(review_comment_message)) <> ''
             THEN 1 ELSE 0 END) AS reviews_with_message,
    SUM(CASE WHEN review_comment_title IS NOT NULL
                  AND LTRIM(RTRIM(review_comment_title)) <> ''
             THEN 1 ELSE 0 END) AS reviews_with_title
FROM dbo.olist_order_reviews_dataset;
GO

/* ================================================================
   14. PRODUCT EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '14 - PRODUCT EDA';
PRINT '===============================================================';

SELECT
    COUNT_BIG(*) AS products,
    AVG(CAST(product_name_lenght AS decimal(18,2))) AS avg_name_length,
    AVG(CAST(product_description_lenght AS decimal(18,2))) AS avg_description_length,
    AVG(CAST(product_photos_qty AS decimal(18,2))) AS avg_photo_count,
    AVG(CAST(product_weight_g AS decimal(18,2))) AS avg_weight_g,
    AVG(CAST(product_length_cm AS decimal(18,2))) AS avg_length_cm,
    AVG(CAST(product_height_cm AS decimal(18,2))) AS avg_height_cm,
    AVG(CAST(product_width_cm AS decimal(18,2))) AS avg_width_cm
FROM dbo.olist_products_dataset;

-- Product categories by product count
SELECT
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    COUNT_BIG(*) AS product_count
FROM dbo.olist_products_dataset AS p
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
ORDER BY product_count DESC;

-- Product dimensions / weight descriptive statistics
SELECT
    MIN(product_weight_g) AS min_weight_g,
    AVG(CAST(product_weight_g AS decimal(18,2))) AS avg_weight_g,
    MAX(product_weight_g) AS max_weight_g,
    MIN(product_length_cm) AS min_length_cm,
    AVG(CAST(product_length_cm AS decimal(18,2))) AS avg_length_cm,
    MAX(product_length_cm) AS max_length_cm,
    MIN(product_height_cm) AS min_height_cm,
    AVG(CAST(product_height_cm AS decimal(18,2))) AS avg_height_cm,
    MAX(product_height_cm) AS max_height_cm,
    MIN(product_width_cm) AS min_width_cm,
    AVG(CAST(product_width_cm AS decimal(18,2))) AS avg_width_cm,
    MAX(product_width_cm) AS max_width_cm
FROM dbo.olist_products_dataset;
GO

/* ================================================================
   15. SELLER EDA
   ================================================================ */

PRINT '===============================================================';
PRINT '15 - SELLER EDA';
PRINT '===============================================================';

SELECT
    s.seller_id,
    s.seller_state,
    COUNT_BIG(oi.order_id) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS orders_served,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_sales
FROM dbo.olist_sellers_dataset AS s
LEFT JOIN dbo.olist_order_items_dataset AS oi
    ON s.seller_id = oi.seller_id
GROUP BY
    s.seller_id,
    s.seller_state
ORDER BY merchandise_sales DESC;

SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS sellers,
    COUNT_BIG(oi.order_id) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS orders_served,
    SUM(oi.price) AS merchandise_sales
FROM dbo.olist_sellers_dataset AS s
LEFT JOIN dbo.olist_order_items_dataset AS oi
    ON s.seller_id = oi.seller_id
GROUP BY s.seller_state
ORDER BY merchandise_sales DESC;
GO

/* ================================================================
   16. CATEGORY SALES EDA
   IMPORTANT: Aggregate order items BEFORE joining to payments/reviews
   to avoid fan-out and inflated revenue.
   ================================================================ */

PRINT '===============================================================';
PRINT '16 - CATEGORY SALES';
PRINT '===============================================================';

SELECT
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    COUNT_BIG(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS orders,
    COUNT(DISTINCT oi.product_id) AS products,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS item_plus_freight
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
ORDER BY merchandise_sales DESC;
GO

/* ================================================================
   17. PAYMENT VS ORDER VALUE
   ================================================================ */

PRINT '===============================================================';
PRINT '17 - PAYMENT RECONCILIATION';
PRINT '===============================================================';

WITH item_totals AS
(
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS item_plus_freight
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS
(
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    COUNT_BIG(*) AS comparable_orders,
    AVG(CAST(p.payment_value - i.item_plus_freight AS decimal(18,2)))
        AS avg_payment_minus_item_value,
    SUM(CASE
            WHEN ABS(p.payment_value - i.item_plus_freight) <= 0.01
            THEN 1 ELSE 0
        END) AS approximately_equal_orders,
    SUM(CASE
            WHEN p.payment_value > i.item_plus_freight + 0.01
            THEN 1 ELSE 0
        END) AS payment_above_item_value,
    SUM(CASE
            WHEN p.payment_value < i.item_plus_freight - 0.01
            THEN 1 ELSE 0
        END) AS payment_below_item_value
FROM item_totals AS i
INNER JOIN payment_totals AS p
    ON i.order_id = p.order_id;

-- Largest reconciliation differences
WITH item_totals AS
(
    SELECT
        order_id,
        SUM(price + freight_value) AS item_plus_freight
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS
(
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
)
SELECT TOP (100)
    i.order_id,
    i.item_plus_freight,
    p.payment_value,
    p.payment_value - i.item_plus_freight AS difference
FROM item_totals AS i
INNER JOIN payment_totals AS p
    ON i.order_id = p.order_id
ORDER BY ABS(p.payment_value - i.item_plus_freight) DESC;
GO

/* ================================================================
   18. MONTHLY BUSINESS KPI
   ================================================================ */

PRINT '===============================================================';
PRINT '18 - MONTHLY KPI';
PRINT '===============================================================';

WITH monthly_orders AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(order_purchase_timestamp),
            MONTH(order_purchase_timestamp),
            1
        ) AS month_start,
        COUNT_BIG(*) AS orders
    FROM dbo.olist_orders_dataset
    GROUP BY
        DATEFROMPARTS(
            YEAR(order_purchase_timestamp),
            MONTH(order_purchase_timestamp),
            1
        )
),
monthly_sales AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS month_start,
        SUM(oi.price) AS merchandise_sales,
        SUM(oi.freight_value) AS freight_value
    FROM dbo.olist_orders_dataset AS o
    INNER JOIN dbo.olist_order_items_dataset AS oi
        ON o.order_id = oi.order_id
    GROUP BY
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        )
)
SELECT
    mo.month_start,
    mo.orders,
    ms.merchandise_sales,
    ms.freight_value,
    ms.merchandise_sales + ms.freight_value AS merchandise_plus_freight,
    CAST(ms.merchandise_sales / NULLIF(CAST(mo.orders AS decimal(18,2)),0)
         AS decimal(18,2)) AS merchandise_sales_per_order
FROM monthly_orders AS mo
LEFT JOIN monthly_sales AS ms
    ON mo.month_start = ms.month_start
ORDER BY mo.month_start;
GO

/* ================================================================
   19. TOP PRODUCTS
   ================================================================ */

PRINT '===============================================================';
PRINT '19 - TOP PRODUCTS';
PRINT '===============================================================';

SELECT TOP (100)
    p.product_id,
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    COUNT_BIG(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_value
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    p.product_id,
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
ORDER BY merchandise_sales DESC;
GO

/* ================================================================
   20. TOP CUSTOMERS BY MERCHANDISE VALUE
   ================================================================ */

PRINT '===============================================================';
PRINT '20 - TOP CUSTOMERS';
PRINT '===============================================================';

SELECT TOP (100)
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_item_value
FROM dbo.olist_customers_dataset AS c
INNER JOIN dbo.olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
INNER JOIN dbo.olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
GROUP BY
    c.customer_unique_id,
    c.customer_state
ORDER BY merchandise_sales DESC;
GO

/* ================================================================
   21. HIGH-VALUE BUSINESS QUESTIONS
   ================================================================ */

PRINT '===============================================================';
PRINT '21 - BUSINESS QUESTIONS';
PRINT '===============================================================';

-- Q1. Which states generate the most merchandise sales?
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.price) AS merchandise_sales,
    AVG(CAST(oi.price AS decimal(18,2))) AS avg_item_price
FROM dbo.olist_customers_dataset AS c
INNER JOIN dbo.olist_orders_dataset AS o
    ON c.customer_id = o.customer_id
INNER JOIN dbo.olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY merchandise_sales DESC;

-- Q2. Which categories have the highest average item price?
SELECT TOP (50)
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    COUNT_BIG(*) AS item_rows,
    AVG(CAST(oi.price AS decimal(18,2))) AS avg_item_price,
    SUM(oi.price) AS merchandise_sales
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
HAVING COUNT_BIG(*) >= 20
ORDER BY avg_item_price DESC;

-- Q3. Which sellers generate the highest sales?
SELECT TOP (50)
    oi.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_value
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_sellers_dataset AS s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_state
ORDER BY merchandise_sales DESC;

-- Q4. Is late delivery associated with lower review scores?
SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END AS delivery_status,
    COUNT_BIG(*) AS reviews,
    AVG(CAST(r.review_score AS decimal(10,2))) AS avg_review_score
FROM dbo.olist_order_reviews_dataset AS r
INNER JOIN dbo.olist_orders_dataset AS o
    ON r.order_id = o.order_id
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'On time'
    END
ORDER BY avg_review_score;

-- Q5. What payment methods are used most?
SELECT
    payment_type,
    COUNT_BIG(*) AS payment_transactions,
    COUNT(DISTINCT order_id) AS orders,
    SUM(payment_value) AS payment_value,
    AVG(CAST(payment_value AS decimal(18,2))) AS avg_payment
FROM dbo.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY payment_value DESC;

-- Q6. Which categories have the highest freight burden?
SELECT TOP (50)
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    SUM(oi.price) AS merchandise_sales,
    SUM(oi.freight_value) AS freight_value,
    CAST(100.0 * SUM(oi.freight_value)
         / NULLIF(SUM(oi.price),0) AS decimal(10,2)) AS freight_pct_of_merchandise
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
GROUP BY
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
HAVING SUM(oi.price) > 0
ORDER BY freight_pct_of_merchandise DESC;

-- Q7. Which products/categories have many orders but low review scores?
SELECT TOP (50)
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]') AS category,
    COUNT(DISTINCT o.order_id) AS orders,
    AVG(CAST(r.review_score AS decimal(10,2))) AS avg_review_score
FROM dbo.olist_order_items_dataset AS oi
INNER JOIN dbo.olist_orders_dataset AS o
    ON oi.order_id = o.order_id
INNER JOIN dbo.olist_products_dataset AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.product_category_name_translation AS t
    ON p.product_category_name = t.column1
LEFT JOIN dbo.olist_order_reviews_dataset AS r
    ON o.order_id = r.order_id
GROUP BY
    COALESCE(t.column2,
             p.product_category_name,
             '[NO CATEGORY]')
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY avg_review_score ASC;
GO

/* ================================================================
   22. FAN-OUT SAFETY DEMONSTRATION
   Never directly join raw items + raw payments + raw reviews and
   then SUM(price/payment_value). Their grains are different.

   Correct pattern:
     1. Aggregate each fact table to order_id.
     2. Join the aggregated results.
   ================================================================ */

PRINT '===============================================================';
PRINT '22 - GRAIN / FAN-OUT CHECK';
PRINT '===============================================================';

WITH item_by_order AS
(
    SELECT
        order_id,
        SUM(price) AS item_sales,
        SUM(freight_value) AS freight
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
),
payment_by_order AS
(
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
),
review_by_order AS
(
    SELECT
        order_id,
        AVG(CAST(review_score AS decimal(10,2))) AS avg_review_score,
        COUNT_BIG(*) AS review_count
    FROM dbo.olist_order_reviews_dataset
    GROUP BY order_id
)
SELECT TOP (100)
    o.order_id,
    i.item_sales,
    i.freight,
    p.payment_value,
    r.avg_review_score,
    r.review_count
FROM dbo.olist_orders_dataset AS o
LEFT JOIN item_by_order AS i
    ON o.order_id = i.order_id
LEFT JOIN payment_by_order AS p
    ON o.order_id = p.order_id
LEFT JOIN review_by_order AS r
    ON o.order_id = r.order_id
ORDER BY i.item_sales DESC;
GO

/* ================================================================
   23. EDA COMPLETION
   ================================================================ */

PRINT '===============================================================';
PRINT 'EDA COMPLETE';
PRINT '===============================================================';
PRINT 'Next project layers should be built only after reviewing:';
PRINT '1. Row counts';
PRINT '2. NULL profile';
PRINT '3. Duplicate/key results';
PRINT '4. Orphan results';
PRINT '5. Data-quality results';
PRINT '6. Category translation coverage';
PRINT '7. Fan-out-safe revenue results';
PRINT '===============================================================';
