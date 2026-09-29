/*
===========================================================
PROJECT : Olist Brazilian E-Commerce Intelligence Platform
FILE    : EDA.sql
DATABASE: Naveenraj
PURPOSE : Exploratory Data Analysis of ALL 9 RAW TABLES

RAW TABLES:
1. olist_orders_dataset
2. olist_order_items_dataset
3. olist_products_dataset
4. olist_sellers_dataset
5. olist_order_reviews_dataset
6. product_category_name_translation
7. olist_order_payments_dataset
8. olist_customers_dataset
9. olist_geolocation_dataset

IMPORTANT:
- Run this file in SQL Server Management Studio (SSMS).
- This file only READS the raw tables.
- No UPDATE / DELETE / ALTER / DROP statements are used.
- Actual EDA findings should be recorded before cleaning.
===========================================================
*/

USE Naveenraj;
GO


/* =========================================================
   0. DATABASE / TABLE PROFILE
   ========================================================= */

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN
(
    'olist_orders_dataset',
    'olist_order_items_dataset',
    'olist_products_dataset',
    'olist_sellers_dataset',
    'olist_order_reviews_dataset',
    'product_category_name_translation',
    'olist_order_payments_dataset',
    'olist_customers_dataset',
    'olist_geolocation_dataset'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO


/* =========================================================
   1. ROW COUNTS - ALL 9 TABLES
   ========================================================= */

SELECT 'olist_orders_dataset' AS table_name, COUNT(*) AS row_count
FROM dbo.olist_orders_dataset
UNION ALL
SELECT 'olist_order_items_dataset', COUNT(*)
FROM dbo.olist_order_items_dataset
UNION ALL
SELECT 'olist_products_dataset', COUNT(*)
FROM dbo.olist_products_dataset
UNION ALL
SELECT 'olist_sellers_dataset', COUNT(*)
FROM dbo.olist_sellers_dataset
UNION ALL
SELECT 'olist_order_reviews_dataset', COUNT(*)
FROM dbo.olist_order_reviews_dataset
UNION ALL
SELECT 'product_category_name_translation', COUNT(*)
FROM dbo.product_category_name_translation
UNION ALL
SELECT 'olist_order_payments_dataset', COUNT(*)
FROM dbo.olist_order_payments_dataset
UNION ALL
SELECT 'olist_customers_dataset', COUNT(*)
FROM dbo.olist_customers_dataset
UNION ALL
SELECT 'olist_geolocation_dataset', COUNT(*)
FROM dbo.olist_geolocation_dataset;
GO


/* =========================================================
   2. ORDERS EDA
   ========================================================= */

-- 2.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM dbo.olist_orders_dataset;
GO

-- 2.2 Duplicate candidate primary key
SELECT
    order_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;
GO

-- 2.3 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_timestamp,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved_at,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_carrier_date,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_customer_delivery_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_delivery_date
FROM dbo.olist_orders_dataset;
GO

-- 2.4 Status distribution
SELECT
    order_status,
    COUNT(*) AS order_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2))
        AS percentage_of_orders
FROM dbo.olist_orders_dataset
GROUP BY order_status
ORDER BY order_count DESC;
GO

-- 2.5 Purchase date range
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM dbo.olist_orders_dataset;
GO

-- 2.6 Orders by year
SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    COUNT(*) AS order_count
FROM dbo.olist_orders_dataset
GROUP BY YEAR(order_purchase_timestamp)
ORDER BY order_year;
GO

-- 2.7 Orders by month
SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    MONTH(order_purchase_timestamp) AS order_month,
    COUNT(*) AS order_count
FROM dbo.olist_orders_dataset
GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
ORDER BY order_year, order_month;
GO

-- 2.8 Delivery time statistics
SELECT
    MIN(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date))
        AS minimum_delivery_days,
    MAX(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date))
        AS maximum_delivery_days,
    AVG(CAST(DATEDIFF(
        DAY, order_purchase_timestamp, order_delivered_customer_date
    ) AS DECIMAL(10,2))) AS average_delivery_days
FROM dbo.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;
GO

-- 2.9 Delivery status
SELECT
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(*) AS order_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2))
        AS percentage_of_orders
FROM dbo.olist_orders_dataset
GROUP BY
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END
ORDER BY order_count DESC;
GO


/* =========================================================
   3. ORDER ITEMS EDA
   ========================================================= */

-- 3.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM dbo.olist_order_items_dataset;
GO

-- 3.2 Items per order
SELECT
    order_id,
    COUNT(*) AS item_count
FROM dbo.olist_order_items_dataset
GROUP BY order_id
ORDER BY item_count DESC;
GO

-- 3.3 Candidate composite key
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;
GO

-- 3.4 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN shipping_limit_date IS NULL THEN 1 ELSE 0 END) AS null_shipping_limit_date,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS null_freight_value
FROM dbo.olist_order_items_dataset;
GO

-- 3.5 Price / freight statistics
SELECT
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price,
    AVG(price) AS average_price,
    SUM(price) AS product_revenue,
    MIN(freight_value) AS minimum_freight,
    MAX(freight_value) AS maximum_freight,
    AVG(freight_value) AS average_freight,
    SUM(freight_value) AS total_freight
FROM dbo.olist_order_items_dataset;
GO

-- 3.6 Total order-item value
SELECT
    SUM(price) AS product_revenue,
    SUM(freight_value) AS freight_value,
    SUM(price + freight_value) AS total_order_item_value
FROM dbo.olist_order_items_dataset;
GO


/* =========================================================
   4. PRODUCTS EDA
   ========================================================= */

-- 4.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_products
FROM dbo.olist_products_dataset;
GO

-- 4.2 Duplicate candidate PK
SELECT
    product_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_products_dataset
GROUP BY product_id
HAVING COUNT(*) > 1;
GO

-- 4.3 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END) AS null_product_name_length,
    SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END) AS null_description_length,
    SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END) AS null_photos_qty,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) AS null_weight_g,
    SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END) AS null_length_cm,
    SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END) AS null_height_cm,
    SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END) AS null_width_cm
FROM dbo.olist_products_dataset;
GO

-- 4.4 Category distribution
SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM dbo.olist_products_dataset
GROUP BY product_category_name
ORDER BY product_count DESC;
GO

-- 4.5 Physical attributes
SELECT
    MIN(product_weight_g) AS minimum_weight_g,
    MAX(product_weight_g) AS maximum_weight_g,
    AVG(product_weight_g) AS average_weight_g,
    MIN(product_length_cm) AS minimum_length_cm,
    MAX(product_length_cm) AS maximum_length_cm,
    AVG(product_length_cm) AS average_length_cm,
    MIN(product_height_cm) AS minimum_height_cm,
    MAX(product_height_cm) AS maximum_height_cm,
    AVG(product_height_cm) AS average_height_cm,
    MIN(product_width_cm) AS minimum_width_cm,
    MAX(product_width_cm) AS maximum_width_cm,
    AVG(product_width_cm) AS average_width_cm
FROM dbo.olist_products_dataset;
GO


/* =========================================================
   5. SELLERS EDA
   ========================================================= */

-- 5.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM dbo.olist_sellers_dataset;
GO

-- 5.2 Duplicate candidate PK
SELECT
    seller_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1;
GO

-- 5.3 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip_code,
    SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM dbo.olist_sellers_dataset;
GO

-- 5.4 Sellers by state
SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM dbo.olist_sellers_dataset
GROUP BY seller_state
ORDER BY seller_count DESC;
GO

-- 5.5 Sellers by city
SELECT
    seller_city,
    seller_state,
    COUNT(*) AS seller_count
FROM dbo.olist_sellers_dataset
GROUP BY seller_city, seller_state
ORDER BY seller_count DESC;
GO


/* =========================================================
   6. REVIEWS EDA
   ========================================================= */

-- 6.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS unique_reviews,
    COUNT(DISTINCT order_id) AS unique_orders_with_reviews
FROM dbo.olist_order_reviews_dataset;
GO

-- 6.2 Duplicate review_id
SELECT
    review_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1;
GO

-- 6.3 Multiple reviews per order
SELECT
    order_id,
    COUNT(*) AS review_count
FROM dbo.olist_order_reviews_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;
GO

-- 6.4 Candidate composite key
SELECT
    order_id,
    review_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_reviews_dataset
GROUP BY order_id, review_id
HAVING COUNT(*) > 1;
GO

-- 6.5 Review score distribution
SELECT
    review_score,
    COUNT(*) AS review_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2))
        AS percentage_of_reviews
FROM dbo.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;
GO

-- 6.6 Invalid review scores
SELECT
    review_score,
    COUNT(*) AS invalid_count
FROM dbo.olist_order_reviews_dataset
WHERE review_score NOT BETWEEN 1 AND 5
GROUP BY review_score
ORDER BY invalid_count DESC;
GO

-- 6.7 Average score
SELECT
    AVG(CAST(review_score AS DECIMAL(10,2))) AS average_review_score
FROM dbo.olist_order_reviews_dataset;
GO

-- 6.8 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END) AS null_review_id,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) AS null_review_score,
    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END) AS null_comment_title,
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) AS null_comment_message,
    SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END) AS null_creation_date,
    SUM(CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END) AS null_answer_timestamp
FROM dbo.olist_order_reviews_dataset;
GO

-- 6.9 Empty-string comments
SELECT
    SUM(CASE
        WHEN LTRIM(RTRIM(COALESCE(review_comment_title, ''))) = ''
        THEN 1 ELSE 0 END) AS empty_comment_titles,
    SUM(CASE
        WHEN LTRIM(RTRIM(COALESCE(review_comment_message, ''))) = ''
        THEN 1 ELSE 0 END) AS empty_comment_messages
FROM dbo.olist_order_reviews_dataset;
GO

-- 6.10 Review date range
SELECT
    MIN(review_creation_date) AS first_review_date,
    MAX(review_creation_date) AS last_review_date
FROM dbo.olist_order_reviews_dataset;
GO

-- 6.11 Average response time
SELECT
    AVG(CAST(DATEDIFF(
        HOUR,
        review_creation_date,
        review_answer_timestamp
    ) AS DECIMAL(10,2))) AS average_response_hours
FROM dbo.olist_order_reviews_dataset
WHERE review_creation_date IS NOT NULL
  AND review_answer_timestamp IS NOT NULL;
GO

-- 6.12 Invalid timestamp sequence
SELECT COUNT(*) AS invalid_timestamp_rows
FROM dbo.olist_order_reviews_dataset
WHERE review_creation_date IS NOT NULL
  AND review_answer_timestamp IS NOT NULL
  AND review_answer_timestamp < review_creation_date;
GO


/* =========================================================
   7. CATEGORY TRANSLATION EDA
   ========================================================= */

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS unique_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS unique_english_categories
FROM dbo.product_category_name_translation;
GO

-- Duplicate Portuguese categories
SELECT
    product_category_name,
    COUNT(*) AS occurrence_count
FROM dbo.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;
GO

-- Duplicate English categories
SELECT
    product_category_name_english,
    COUNT(*) AS occurrence_count
FROM dbo.product_category_name_translation
GROUP BY product_category_name_english
HAVING COUNT(*) > 1;
GO

-- NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END)
        AS null_portuguese_category,
    SUM(CASE WHEN product_category_name_english IS NULL THEN 1 ELSE 0 END)
        AS null_english_category
FROM dbo.product_category_name_translation;
GO


/* =========================================================
   8. ORDER PAYMENTS EDA
   ========================================================= */

-- 8.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT payment_type) AS unique_payment_types
FROM dbo.olist_order_payments_dataset;
GO

-- 8.2 Candidate composite key
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_payments_dataset
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;
GO

-- 8.3 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN payment_sequential IS NULL THEN 1 ELSE 0 END) AS null_payment_sequential,
    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END) AS null_payment_type,
    SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END) AS null_installments,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS null_payment_value
FROM dbo.olist_order_payments_dataset;
GO

-- 8.4 Payment type distribution
SELECT
    payment_type,
    COUNT(*) AS payment_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(10,2))
        AS percentage_of_payments
FROM dbo.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY payment_count DESC;
GO

-- 8.5 Payment statistics
SELECT
    MIN(payment_value) AS minimum_payment,
    MAX(payment_value) AS maximum_payment,
    AVG(payment_value) AS average_payment,
    SUM(payment_value) AS total_payment_value
FROM dbo.olist_order_payments_dataset;
GO

-- 8.6 Installment distribution
SELECT
    payment_installments,
    COUNT(*) AS payment_count
FROM dbo.olist_order_payments_dataset
GROUP BY payment_installments
ORDER BY payment_installments;
GO

-- 8.7 Multiple payment records per order
SELECT
    order_id,
    COUNT(*) AS payment_record_count
FROM dbo.olist_order_payments_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_record_count DESC;
GO


/* =========================================================
   9. CUSTOMERS EDA
   ========================================================= */

-- 9.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customer_unique_ids
FROM dbo.olist_customers_dataset;
GO

-- 9.2 Duplicate customer_id
SELECT
    customer_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_customers_dataset
GROUP BY customer_id
HAVING COUNT(*) > 1;
GO

-- 9.3 Customers with multiple order records
SELECT
    customer_unique_id,
    COUNT(*) AS customer_record_count
FROM dbo.olist_customers_dataset
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY customer_record_count DESC;
GO

-- 9.4 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_customer_unique_id,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip_code,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM dbo.olist_customers_dataset;
GO

-- 9.5 Customers by state
SELECT
    customer_state,
    COUNT(*) AS customer_count
FROM dbo.olist_customers_dataset
GROUP BY customer_state
ORDER BY customer_count DESC;
GO

-- 9.6 Customers by city
SELECT
    customer_city,
    customer_state,
    COUNT(*) AS customer_count
FROM dbo.olist_customers_dataset
GROUP BY customer_city, customer_state
ORDER BY customer_count DESC;
GO


/* =========================================================
   10. GEOLOCATION EDA
   ========================================================= */

-- 10.1 Cardinality
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_prefixes
FROM dbo.olist_geolocation_dataset;
GO

-- 10.2 Duplicate zip-prefix records
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS occurrence_count
FROM dbo.olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;
GO

-- 10.3 NULL profile
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN geolocation_zip_code_prefix IS NULL THEN 1 ELSE 0 END)
        AS null_zip_code,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END)
        AS null_latitude,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END)
        AS null_longitude,
    SUM(CASE WHEN geolocation_city IS NULL THEN 1 ELSE 0 END)
        AS null_city,
    SUM(CASE WHEN geolocation_state IS NULL THEN 1 ELSE 0 END)
        AS null_state
FROM dbo.olist_geolocation_dataset;
GO

-- 10.4 Latitude / longitude range
SELECT
    MIN(geolocation_lat) AS minimum_latitude,
    MAX(geolocation_lat) AS maximum_latitude,
    MIN(geolocation_lng) AS minimum_longitude,
    MAX(geolocation_lng) AS maximum_longitude
FROM dbo.olist_geolocation_dataset;
GO

-- 10.5 Geolocation records by state
SELECT
    geolocation_state,
    COUNT(*) AS location_count
FROM dbo.olist_geolocation_dataset
GROUP BY geolocation_state
ORDER BY location_count DESC;
GO

-- 10.6 Cities represented in geolocation
SELECT
    geolocation_city,
    geolocation_state,
    COUNT(*) AS location_count
FROM dbo.olist_geolocation_dataset
GROUP BY geolocation_city, geolocation_state
ORDER BY location_count DESC;
GO


/* =========================================================
   11. CROSS-TABLE RELATIONSHIP VALIDATION
   ========================================================= */

-- 11.1 Order items -> Orders
SELECT COUNT(*) AS orphan_order_items
FROM dbo.olist_order_items_dataset oi
LEFT JOIN dbo.olist_orders_dataset o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
GO

-- 11.2 Order items -> Products
SELECT COUNT(*) AS orphan_products
FROM dbo.olist_order_items_dataset oi
LEFT JOIN dbo.olist_products_dataset p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
GO

-- 11.3 Order items -> Sellers
SELECT COUNT(*) AS orphan_sellers
FROM dbo.olist_order_items_dataset oi
LEFT JOIN dbo.olist_sellers_dataset s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
GO

-- 11.4 Reviews -> Orders
SELECT COUNT(*) AS orphan_reviews
FROM dbo.olist_order_reviews_dataset r
LEFT JOIN dbo.olist_orders_dataset o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
GO

-- 11.5 Payments -> Orders
SELECT COUNT(*) AS orphan_payments
FROM dbo.olist_order_payments_dataset p
LEFT JOIN dbo.olist_orders_dataset o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;
GO

-- 11.6 Orders -> Customers
SELECT COUNT(*) AS orphan_orders
FROM dbo.olist_orders_dataset o
LEFT JOIN dbo.olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
GO

-- 11.7 Products -> Category translation
SELECT COUNT(*) AS untranslated_categories
FROM dbo.olist_products_dataset p
LEFT JOIN dbo.product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;
GO

-- 11.8 Customers -> Geolocation
SELECT COUNT(*) AS customers_without_geolocation
FROM dbo.olist_customers_dataset c
LEFT JOIN dbo.olist_geolocation_dataset g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;
GO

-- 11.9 Sellers -> Geolocation
SELECT COUNT(*) AS sellers_without_geolocation
FROM dbo.olist_sellers_dataset s
LEFT JOIN dbo.olist_geolocation_dataset g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;
GO


/* =========================================================
   12. RELATIONSHIP / CARDINALITY ANALYSIS
   ========================================================= */

-- Orders containing multiple items
SELECT COUNT(*) AS orders_with_multiple_items
FROM
(
    SELECT order_id
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;
GO

-- Orders containing multiple payment records
SELECT COUNT(*) AS orders_with_multiple_payments
FROM
(
    SELECT order_id
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;
GO

-- Orders containing multiple reviews
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM
(
    SELECT order_id
    FROM dbo.olist_order_reviews_dataset
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;
GO

-- Products appearing in multiple order-item rows
SELECT
    product_id,
    COUNT(*) AS item_rows
FROM dbo.olist_order_items_dataset
GROUP BY product_id
ORDER BY item_rows DESC;
GO

-- Sellers handling multiple order-item rows
SELECT
    seller_id,
    COUNT(*) AS item_rows
FROM dbo.olist_order_items_dataset
GROUP BY seller_id
ORDER BY item_rows DESC;
GO


/* =========================================================
   13. INITIAL BUSINESS ANALYSIS
   ========================================================= */

-- 13.1 Revenue by product category
SELECT
    p.product_category_name,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_value
FROM dbo.olist_order_items_dataset oi
JOIN dbo.olist_products_dataset p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_value DESC;
GO

-- 13.2 Revenue by seller
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_value
FROM dbo.olist_order_items_dataset oi
GROUP BY oi.seller_id
ORDER BY total_value DESC;
GO

-- 13.3 Top 20 products by revenue
SELECT TOP 20
    oi.product_id,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_value
FROM dbo.olist_order_items_dataset oi
GROUP BY oi.product_id
ORDER BY total_value DESC;
GO

-- 13.4 Average order value
WITH order_values AS
(
    SELECT
        order_id,
        SUM(price + freight_value) AS order_value
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_items,
    AVG(CAST(order_value AS DECIMAL(18,2))) AS average_order_value,
    MIN(order_value) AS minimum_order_value,
    MAX(order_value) AS maximum_order_value
FROM order_values;
GO

-- 13.5 Monthly revenue
SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_value
FROM dbo.olist_orders_dataset o
JOIN dbo.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;
GO

-- 13.6 Payment value by payment type
SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(payment_value) AS total_payment_value,
    AVG(payment_value) AS average_payment_value
FROM dbo.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_payment_value DESC;
GO

-- 13.7 Average review score by delivery status
SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(DISTINCT r.review_id) AS review_count,
    AVG(CAST(r.review_score AS DECIMAL(10,2))) AS average_review_score
FROM dbo.olist_orders_dataset o
JOIN dbo.olist_order_reviews_dataset r
    ON o.order_id = r.order_id
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END
ORDER BY average_review_score;
GO

-- 13.8 Customer order frequency
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM dbo.olist_customers_dataset c
JOIN dbo.olist_orders_dataset o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY order_count DESC;
GO

-- 13.9 Revenue by customer state
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.price + oi.freight_value) AS total_value
FROM dbo.olist_customers_dataset c
JOIN dbo.olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN dbo.olist_order_items_dataset oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY total_value DESC;
GO


/* =========================================================
   14. EDA FINDINGS TEMPLATE

   Fill this section manually after executing the queries.

   ORDERS
   - Total rows:99441
   - Unique order_id:99441
   - Duplicate order_id:0
   - NULL issues:There
   - Candidate PK:order_id
   - Main statuses:8
   - Delivery pattern:                ┌──→ CANCELED
                                      │
                          CREATED → APPROVED → PROCESSING → INVOICED → SHIPPED → DELIVERED
                                      │
                                      └──→ UNAVAILABLE

   ORDER ITEMS
   - Total rows:112650
   - Unique orders:98666
   - Unique products:32951
   - Unique sellers:3095
   - Duplicate (order_id, order_item_id):0
   - Orphan orders:0
   - Orphan products:0
   - Orphan sellers:0
   - Candidate composite PK:order_id, order_item_id

   PRODUCTS
   - Total rows:32951
   - Unique product_id:32951
   - Duplicate product_id:0
   - Important NULL columns:description_length,category
   - Main categories:74

   SELLERS
   - Total rows:3095
   - Unique seller_id:3095
   - Duplicate seller_id:0
   - Important NULL columns:Nill
   - Main states:23

   REVIEWS
   - Total rows:99224
   - Unique review_id:98410
   - Duplicate review_id:0
   - Multiple reviews per order:547
   - Average score:4.086420
   - Invalid scores:0
   - Orphan reviews:0
   - Average response time:75.078378 hrs

   CATEGORY TRANSLATION
   - Total rows:72
   - Duplicate Portuguese categories:0
   - Duplicate English categories:0
   - Untranslated categories:0

   ORDER PAYMENTS
   - Total rows:103886
   - Unique orders:99440
   - Payment types:5
   - Duplicate (order_id, payment_sequential):0
   - NULL issues:Nill
   - Multiple payment records per order:2961
   - Total payment value:16008872.1200548

   CUSTOMERS
   - Total rows:99441
   - Unique customer_id:99441
   - Unique customer_unique_id:96096
   - Duplicate customer_id:0
   - Customers with multiple records:2997
   - NULL issues:Nill
   - Main states:27

   GEOLOCATION
   - Total rows:1000163
   - Unique zip prefixes:19015
   - Duplicate zip-prefix records:0
   - NULL issues:There
   - Latitude/longitude range:-36.6053733825684	to -4.36737936979625E-05,-101.466766357422 to -4.9478235244751
   - Main states:27

   RELATIONSHIPS
   - Orders 1:M Order Items
   - Products 1:M Order Items
   - Sellers 1:M Order Items
   - Orders 1:M Reviews
   - Orders 1:M Payments
   - Customers 1:M Orders
   - Products M:1 Category Translation
   - Customer/Seller zip prefix -> Geolocation

   CANDIDATE KEYS
   - orders.order_id
   - order_items.(order_id, order_item_id)
   - products.product_id
   - sellers.seller_id
   - reviews.review_id
   - payments.(order_id, payment_sequential)
   - customers.customer_id
   - category_translation.product_category_name
   - geolocation requires further validation before choosing a PK

   NEXT:
   EDA -> DATA CLEANING -> NORMALIZATION -> PK/FK/CONSTRAINTS
   ========================================================= */
