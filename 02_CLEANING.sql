/* ================================================================
   OLIST E-COMMERCE PROJECT
   02_CLEANING.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Build a clean staging layer WITHOUT changing the raw Olist tables.

   RAW TABLES ARE NEVER UPDATED / DELETED.

   IMPORTANT ACTUAL SCHEMA
   -----------------------
   dbo.product_category_name_translation:
       column1 = source Portuguese category
       column2 = English category

   This script standardizes:
       - blank strings -> NULL
       - leading/trailing whitespace
       - date/time columns with TRY_CONVERT
       - numeric columns with TRY_CONVERT
       - category translation into meaningful staging aliases

   OUTPUT
   ------
       stg_olist_customers
       stg_olist_geolocation
       stg_olist_order_items
       stg_olist_order_payments
       stg_olist_order_reviews
       stg_olist_orders
       stg_olist_products
       stg_olist_sellers
       stg_product_category_translation

   NOTE
   ----
   Run after 01_EDA.sql has completed successfully.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '02 - CLEANING / STAGING START';
PRINT '===============================================================';


/* ================================================================
   01. REMOVE PREVIOUS STAGING OBJECTS
   ================================================================ */

DROP TABLE IF EXISTS dbo.stg_olist_customers;
DROP TABLE IF EXISTS dbo.stg_olist_geolocation;
DROP TABLE IF EXISTS dbo.stg_olist_order_items;
DROP TABLE IF EXISTS dbo.stg_olist_order_payments;
DROP TABLE IF EXISTS dbo.stg_olist_order_reviews;
DROP TABLE IF EXISTS dbo.stg_olist_orders;
DROP TABLE IF EXISTS dbo.stg_olist_products;
DROP TABLE IF EXISTS dbo.stg_olist_sellers;
DROP TABLE IF EXISTS dbo.stg_product_category_translation;
GO


/* ================================================================
   02. CUSTOMERS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(customer_id)), '') AS customer_id,
    NULLIF(LTRIM(RTRIM(customer_unique_id)), '') AS customer_unique_id,
    TRY_CONVERT(int, customer_zip_code_prefix) AS customer_zip_code_prefix,
    NULLIF(LTRIM(RTRIM(customer_city)), '') AS customer_city,
    NULLIF(LTRIM(RTRIM(customer_state)), '') AS customer_state
INTO dbo.stg_olist_customers
FROM dbo.olist_customers_dataset;
GO


/* ================================================================
   03. GEOLOCATION
   ================================================================ */

SELECT
    TRY_CONVERT(int, geolocation_zip_code_prefix) AS geolocation_zip_code_prefix,
    TRY_CONVERT(decimal(12,8), geolocation_lat) AS geolocation_lat,
    TRY_CONVERT(decimal(12,8), geolocation_lng) AS geolocation_lng,
    NULLIF(LTRIM(RTRIM(geolocation_city)), '') AS geolocation_city,
    NULLIF(LTRIM(RTRIM(geolocation_state)), '') AS geolocation_state
INTO dbo.stg_olist_geolocation
FROM dbo.olist_geolocation_dataset;
GO


/* ================================================================
   04. ORDER ITEMS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(order_id)), '') AS order_id,
    TRY_CONVERT(int, order_item_id) AS order_item_id,
    NULLIF(LTRIM(RTRIM(product_id)), '') AS product_id,
    NULLIF(LTRIM(RTRIM(seller_id)), '') AS seller_id,
    TRY_CONVERT(datetime2, shipping_limit_date) AS shipping_limit_date,
    TRY_CONVERT(decimal(18,2), price) AS price,
    TRY_CONVERT(decimal(18,2), freight_value) AS freight_value
INTO dbo.stg_olist_order_items
FROM dbo.olist_order_items_dataset;
GO


/* ================================================================
   05. ORDER PAYMENTS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(order_id)), '') AS order_id,
    TRY_CONVERT(int, payment_sequential) AS payment_sequential,
    NULLIF(LTRIM(RTRIM(payment_type)), '') AS payment_type,
    TRY_CONVERT(int, payment_installments) AS payment_installments,
    TRY_CONVERT(decimal(18,2), payment_value) AS payment_value
INTO dbo.stg_olist_order_payments
FROM dbo.olist_order_payments_dataset;
GO


/* ================================================================
   06. ORDER REVIEWS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(review_id)), '') AS review_id,
    NULLIF(LTRIM(RTRIM(order_id)), '') AS order_id,
    TRY_CONVERT(int, review_score) AS review_score,
    NULLIF(LTRIM(RTRIM(review_comment_title)), '') AS review_comment_title,
    NULLIF(LTRIM(RTRIM(review_comment_message)), '') AS review_comment_message,
    TRY_CONVERT(datetime2, review_creation_date) AS review_creation_date,
    TRY_CONVERT(datetime2, review_answer_timestamp) AS review_answer_timestamp
INTO dbo.stg_olist_order_reviews
FROM dbo.olist_order_reviews_dataset;
GO


/* ================================================================
   07. ORDERS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(order_id)), '') AS order_id,
    NULLIF(LTRIM(RTRIM(customer_id)), '') AS customer_id,
    NULLIF(LTRIM(RTRIM(order_status)), '') AS order_status,
    TRY_CONVERT(datetime2, order_purchase_timestamp) AS order_purchase_timestamp,
    TRY_CONVERT(datetime2, order_approved_at) AS order_approved_at,
    TRY_CONVERT(datetime2, order_delivered_carrier_date) AS order_delivered_carrier_date,
    TRY_CONVERT(datetime2, order_delivered_customer_date) AS order_delivered_customer_date,
    TRY_CONVERT(datetime2, order_estimated_delivery_date) AS order_estimated_delivery_date
INTO dbo.stg_olist_orders
FROM dbo.olist_orders_dataset;
GO


/* ================================================================
   08. PRODUCTS
   IMPORTANT: preserve original Olist spelling "lenght".
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(product_id)), '') AS product_id,
    NULLIF(LTRIM(RTRIM(product_category_name)), '') AS product_category_name,
    TRY_CONVERT(int, product_name_lenght) AS product_name_lenght,
    TRY_CONVERT(int, product_description_lenght) AS product_description_lenght,
    TRY_CONVERT(int, product_photos_qty) AS product_photos_qty,
    TRY_CONVERT(decimal(18,2), product_weight_g) AS product_weight_g,
    TRY_CONVERT(decimal(18,2), product_length_cm) AS product_length_cm,
    TRY_CONVERT(decimal(18,2), product_height_cm) AS product_height_cm,
    TRY_CONVERT(decimal(18,2), product_width_cm) AS product_width_cm
INTO dbo.stg_olist_products
FROM dbo.olist_products_dataset;
GO


/* ================================================================
   09. SELLERS
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(seller_id)), '') AS seller_id,
    TRY_CONVERT(int, seller_zip_code_prefix) AS seller_zip_code_prefix,
    NULLIF(LTRIM(RTRIM(seller_city)), '') AS seller_city,
    NULLIF(LTRIM(RTRIM(seller_state)), '') AS seller_state
INTO dbo.stg_olist_sellers
FROM dbo.olist_sellers_dataset;
GO


/* ================================================================
   10. CATEGORY TRANSLATION
   ACTUAL PHYSICAL COLUMNS:
       column1
       column2

   We rename them ONLY in the staging layer:
       product_category_name
       product_category_name_english
   ================================================================ */

SELECT
    NULLIF(LTRIM(RTRIM(column1)), '') AS product_category_name,
    NULLIF(LTRIM(RTRIM(column2)), '') AS product_category_name_english
INTO dbo.stg_product_category_translation
FROM dbo.product_category_name_translation;
GO


/* ================================================================
   11. STAGING ROW-COUNT VALIDATION
   ================================================================ */

PRINT '===============================================================';
PRINT 'STAGING ROW COUNTS';
PRINT '===============================================================';

SELECT 'stg_olist_customers' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.stg_olist_customers
UNION ALL
SELECT 'stg_olist_geolocation', COUNT_BIG(*)
FROM dbo.stg_olist_geolocation
UNION ALL
SELECT 'stg_olist_order_items', COUNT_BIG(*)
FROM dbo.stg_olist_order_items
UNION ALL
SELECT 'stg_olist_order_payments', COUNT_BIG(*)
FROM dbo.stg_olist_order_payments
UNION ALL
SELECT 'stg_olist_order_reviews', COUNT_BIG(*)
FROM dbo.stg_olist_order_reviews
UNION ALL
SELECT 'stg_olist_orders', COUNT_BIG(*)
FROM dbo.stg_olist_orders
UNION ALL
SELECT 'stg_olist_products', COUNT_BIG(*)
FROM dbo.stg_olist_products
UNION ALL
SELECT 'stg_olist_sellers', COUNT_BIG(*)
FROM dbo.stg_olist_sellers
UNION ALL
SELECT 'stg_product_category_translation', COUNT_BIG(*)
FROM dbo.stg_product_category_translation
ORDER BY table_name;
GO


/* ================================================================
   12. CLEANING QUALITY CHECKS
   ================================================================ */

PRINT '===============================================================';
PRINT 'CLEANING QUALITY CHECKS';
PRINT '===============================================================';

-- Blank/null business keys after cleaning
SELECT
    'customers.customer_id' AS check_name,
    COUNT_BIG(*) AS bad_rows
FROM dbo.stg_olist_customers
WHERE customer_id IS NULL

UNION ALL
SELECT
    'customers.customer_unique_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_customers
WHERE customer_unique_id IS NULL

UNION ALL
SELECT
    'orders.order_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_orders
WHERE order_id IS NULL

UNION ALL
SELECT
    'orders.customer_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_orders
WHERE customer_id IS NULL

UNION ALL
SELECT
    'order_items.order_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items
WHERE order_id IS NULL

UNION ALL
SELECT
    'order_items.product_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items
WHERE product_id IS NULL

UNION ALL
SELECT
    'order_items.seller_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items
WHERE seller_id IS NULL

UNION ALL
SELECT
    'products.product_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_products
WHERE product_id IS NULL

UNION ALL
SELECT
    'sellers.seller_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_sellers
WHERE seller_id IS NULL

UNION ALL
SELECT
    'payments.order_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_payments
WHERE order_id IS NULL

UNION ALL
SELECT
    'reviews.order_id',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_reviews
WHERE order_id IS NULL;
GO


/* ================================================================
   13. NUMERIC QUALITY
   ================================================================ */

SELECT
    'negative_price' AS check_name,
    COUNT_BIG(*) AS bad_rows
FROM dbo.stg_olist_order_items
WHERE price < 0

UNION ALL
SELECT
    'negative_freight',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items
WHERE freight_value < 0

UNION ALL
SELECT
    'negative_payment',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_payments
WHERE payment_value < 0

UNION ALL
SELECT
    'invalid_payment_installments',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_payments
WHERE payment_installments <= 0

UNION ALL
SELECT
    'invalid_review_score',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5

UNION ALL
SELECT
    'negative_product_weight',
    COUNT_BIG(*)
FROM dbo.stg_olist_products
WHERE product_weight_g < 0

UNION ALL
SELECT
    'negative_product_length',
    COUNT_BIG(*)
FROM dbo.stg_olist_products
WHERE product_length_cm < 0

UNION ALL
SELECT
    'negative_product_height',
    COUNT_BIG(*)
FROM dbo.stg_olist_products
WHERE product_height_cm < 0

UNION ALL
SELECT
    'negative_product_width',
    COUNT_BIG(*)
FROM dbo.stg_olist_products
WHERE product_width_cm < 0;
GO


/* ================================================================
   14. DATE / CHRONOLOGY QUALITY
   ================================================================ */

SELECT
    'approval_before_purchase' AS check_name,
    COUNT_BIG(*) AS bad_rows
FROM dbo.stg_olist_orders
WHERE order_approved_at IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at < order_purchase_timestamp

UNION ALL
SELECT
    'carrier_before_purchase',
    COUNT_BIG(*)
FROM dbo.stg_olist_orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_carrier_date < order_purchase_timestamp

UNION ALL
SELECT
    'customer_delivery_before_purchase',
    COUNT_BIG(*)
FROM dbo.stg_olist_orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp

UNION ALL
SELECT
    'customer_delivery_before_carrier',
    COUNT_BIG(*)
FROM dbo.stg_olist_orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date < order_delivered_carrier_date;
GO


/* ================================================================
   15. CATEGORY TRANSLATION VALIDATION
   ================================================================ */

SELECT TOP (100)
    p.product_category_name,
    t.product_category_name_english,
    COUNT_BIG(*) AS product_count
FROM dbo.stg_olist_products AS p
LEFT JOIN dbo.stg_product_category_translation AS t
    ON p.product_category_name = t.product_category_name
GROUP BY
    p.product_category_name,
    t.product_category_name_english
ORDER BY product_count DESC;
GO


/* ================================================================
   16. ORPHAN CHECKS ON CLEAN STAGING
   ================================================================ */

SELECT
    'orders_without_customer' AS check_name,
    COUNT_BIG(*) AS orphan_rows
FROM dbo.stg_olist_orders AS o
LEFT JOIN dbo.stg_olist_customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL
SELECT
    'items_without_order',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items AS oi
LEFT JOIN dbo.stg_olist_orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'items_without_product',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items AS oi
LEFT JOIN dbo.stg_olist_products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL
SELECT
    'items_without_seller',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_items AS oi
LEFT JOIN dbo.stg_olist_sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL
SELECT
    'payments_without_order',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_payments AS pay
LEFT JOIN dbo.stg_olist_orders AS o
    ON pay.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'reviews_without_order',
    COUNT_BIG(*)
FROM dbo.stg_olist_order_reviews AS r
LEFT JOIN dbo.stg_olist_orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


/* ================================================================
   17. CLEANING SUMMARY
   ================================================================ */

PRINT '===============================================================';
PRINT '02 - CLEANING / STAGING COMPLETE';
PRINT '===============================================================';
PRINT 'Raw Olist tables were not modified.';
PRINT 'Staging tables were rebuilt from the raw tables.';
PRINT 'Translation physical columns column1/column2 were mapped to';
PRINT 'meaningful staging aliases product_category_name and';
PRINT 'product_category_name_english.';
PRINT 'Next layer: 03_NORMALIZATION.sql';
PRINT '===============================================================';
GO
