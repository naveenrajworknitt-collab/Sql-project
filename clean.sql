/* =====================================================================
   OLIST E-COMMERCE | 04_clean.sql | Microsoft SQL Server
   Database: Naveenraj
   Input: 9 dbo raw tables; output: 9 clean tables in schema clean

   POLICY
   - Raw tables are NEVER updated or deleted.
   - All source rows are retained; duplicates are FLAGGED, not removed.
   - Empty optional text becomes NULL; missing dates/numbers remain NULL.
   - Invalid values are FLAGGED for review, not silently corrected.
   - Re-running replaces only the nine clean.* tables created here.
   - Run after all nine raw CSV tables have been imported into dbo.
   ===================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* 00. Prerequisite check: stop before changing any clean tables */
IF EXISTS (
 SELECT 1 FROM (VALUES
 ('olist_orders_dataset'),('olist_order_items_dataset'),
 ('olist_products_dataset'),('olist_sellers_dataset'),
 ('olist_order_reviews_dataset'),('product_category_name_translation'),
 ('olist_order_payments_dataset'),('olist_customers_dataset'),
 ('olist_geolocation_dataset')
 ) AS expected(table_name)
 WHERE OBJECT_ID('dbo.' + expected.table_name, 'U') IS NULL
)
    THROW 51000, 'Missing raw dbo table. Import all nine CSV tables before running clean.sql.', 1;
GO
IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
GO

/* 01. ORDERS: normalize status text and parse timestamps. Preserve missing
   dates because canceled/incomplete orders may legitimately lack them. */
DROP TABLE IF EXISTS clean.orders;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), order_id))), '') AS order_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), customer_id))), '') AS customer_id,
 LOWER(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(50), order_status))), '')) AS order_status,
 TRY_CONVERT(datetime2(0), order_purchase_timestamp) AS order_purchase_timestamp,
 TRY_CONVERT(datetime2(0), order_approved_at) AS order_approved_at,
 TRY_CONVERT(datetime2(0), order_delivered_carrier_date) AS order_delivered_carrier_date,
 TRY_CONVERT(datetime2(0), order_delivered_customer_date) AS order_delivered_customer_date,
 TRY_CONVERT(datetime2(0), order_estimated_delivery_date) AS order_estimated_delivery_date,
 CASE WHEN order_purchase_timestamp IS NOT NULL AND TRY_CONVERT(datetime2(0), order_purchase_timestamp) IS NULL
      THEN 1 ELSE 0 END AS invalid_purchase_timestamp,
 CASE WHEN order_delivered_customer_date IS NOT NULL AND TRY_CONVERT(datetime2(0), order_delivered_customer_date) IS NULL
      THEN 1 ELSE 0 END AS invalid_delivery_timestamp,
 CASE WHEN TRY_CONVERT(datetime2(0), order_delivered_customer_date) < TRY_CONVERT(datetime2(0), order_purchase_timestamp)
      THEN 1 ELSE 0 END AS delivery_before_purchase,
 CASE WHEN LOWER(LTRIM(RTRIM(CONVERT(nvarchar(50), order_status)))) = 'delivered'
           AND TRY_CONVERT(datetime2(0), order_delivered_customer_date) IS NULL
      THEN 1 ELSE 0 END AS delivered_without_date
INTO clean.orders
FROM dbo.olist_orders_dataset;
GO

/* 02. ORDER ITEMS: composite business key (order_id, order_item_id). */
DROP TABLE IF EXISTS clean.order_items;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), order_id))), '') AS order_id,
 TRY_CONVERT(int, order_item_id) AS order_item_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), product_id))), '') AS product_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), seller_id))), '') AS seller_id,
 TRY_CONVERT(datetime2(0), shipping_limit_date) AS shipping_limit_date,
 TRY_CONVERT(decimal(18,2), price) AS price,
 TRY_CONVERT(decimal(18,2), freight_value) AS freight_value,
 CASE WHEN TRY_CONVERT(decimal(18,2), price) < 0 OR
           (price IS NOT NULL AND TRY_CONVERT(decimal(18,2), price) IS NULL)
      THEN 1 ELSE 0 END AS invalid_price,
 CASE WHEN TRY_CONVERT(decimal(18,2), freight_value) < 0 OR
           (freight_value IS NOT NULL AND TRY_CONVERT(decimal(18,2), freight_value) IS NULL)
      THEN 1 ELSE 0 END AS invalid_freight
INTO clean.order_items
FROM dbo.olist_order_items_dataset;
GO

/* 03. PRODUCTS: preserve NULL dimensions; do not invent zeros. Retain
   original source spellings of 'lenght' for transparent traceability. */
DROP TABLE IF EXISTS clean.products;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), product_id))), '') AS product_id,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), product_category_name)))), '') AS product_category_name,
 TRY_CONVERT(int, product_name_lenght) AS product_name_lenght,
 TRY_CONVERT(int, product_description_lenght) AS product_description_lenght,
 TRY_CONVERT(int, product_photos_qty) AS product_photos_qty,
 TRY_CONVERT(decimal(18,3), product_weight_g) AS product_weight_g,
 TRY_CONVERT(decimal(18,3), product_length_cm) AS product_length_cm,
 TRY_CONVERT(decimal(18,3), product_height_cm) AS product_height_cm,
 TRY_CONVERT(decimal(18,3), product_width_cm) AS product_width_cm,
 CASE WHEN TRY_CONVERT(decimal(18,3), product_weight_g) <= 0 OR
           TRY_CONVERT(decimal(18,3), product_length_cm) <= 0 OR
           TRY_CONVERT(decimal(18,3), product_height_cm) <= 0 OR
           TRY_CONVERT(decimal(18,3), product_width_cm) <= 0
      THEN 1 ELSE 0 END AS nonpositive_dimension
INTO clean.products
FROM dbo.olist_products_dataset;
GO

/* 04. SELLERS */
DROP TABLE IF EXISTS clean.sellers;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), seller_id))), '') AS seller_id,
 TRY_CONVERT(int, seller_zip_code_prefix) AS seller_zip_code_prefix,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), seller_city)))), '') AS seller_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10), seller_state)))), '') AS seller_state
INTO clean.sellers
FROM dbo.olist_sellers_dataset;
GO

/* 05. REVIEWS: review_id repeats in Olist. Do NOT deduplicate on review_id;
   investigate (order_id, review_id) as the candidate composite key. */
DROP TABLE IF EXISTS clean.reviews;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), review_id))), '') AS review_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), order_id))), '') AS order_id,
 TRY_CONVERT(int, review_score) AS review_score,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(max), review_comment_title))), '') AS review_comment_title,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(max), review_comment_message))), '') AS review_comment_message,
 TRY_CONVERT(datetime2(0), review_creation_date) AS review_creation_date,
 TRY_CONVERT(datetime2(0), review_answer_timestamp) AS review_answer_timestamp,
 CASE WHEN TRY_CONVERT(int, review_score) NOT BETWEEN 1 AND 5 OR
           (review_score IS NOT NULL AND TRY_CONVERT(int, review_score) IS NULL)
      THEN 1 ELSE 0 END AS invalid_review_score,
 CASE WHEN TRY_CONVERT(datetime2(0), review_answer_timestamp) < TRY_CONVERT(datetime2(0), review_creation_date)
      THEN 1 ELSE 0 END AS answer_before_creation
INTO clean.reviews
FROM dbo.olist_order_reviews_dataset;
GO

/* 06. CATEGORY TRANSLATIONS: keep source mappings, including any
   category not referenced by products. */
DROP TABLE IF EXISTS clean.category_translation;
SELECT
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), product_category_name)))), '') AS product_category_name,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), product_category_name_english)))), '') AS product_category_name_english
INTO clean.category_translation
FROM dbo.product_category_name_translation;
GO

/* 07. PAYMENTS: multiple rows per order are legitimate. */
DROP TABLE IF EXISTS clean.payments;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), order_id))), '') AS order_id,
 TRY_CONVERT(int, payment_sequential) AS payment_sequential,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(50), payment_type)))), '') AS payment_type,
 TRY_CONVERT(int, payment_installments) AS payment_installments,
 TRY_CONVERT(decimal(18,2), payment_value) AS payment_value,
 CASE WHEN TRY_CONVERT(decimal(18,2), payment_value) < 0 OR
           (payment_value IS NOT NULL AND TRY_CONVERT(decimal(18,2), payment_value) IS NULL)
      THEN 1 ELSE 0 END AS invalid_payment_value,
 CASE WHEN TRY_CONVERT(int, payment_installments) < 0 OR
           (payment_installments IS NOT NULL AND TRY_CONVERT(int, payment_installments) IS NULL)
      THEN 1 ELSE 0 END AS invalid_installments
INTO clean.payments
FROM dbo.olist_order_payments_dataset;
GO

/* 08. CUSTOMERS: customer_id identifies the order-specific record;
   customer_unique_id identifies the person across records. */
DROP TABLE IF EXISTS clean.customers;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), customer_id))), '') AS customer_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100), customer_unique_id))), '') AS customer_unique_id,
 TRY_CONVERT(int, customer_zip_code_prefix) AS customer_zip_code_prefix,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), customer_city)))), '') AS customer_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10), customer_state)))), '') AS customer_state
INTO clean.customers
FROM dbo.olist_customers_dataset;
GO

/* 09. GEOLOCATION: intentionally retain all original points. A ZIP prefix
   is NOT unique; don't join the full geolocation table to orders for
   revenue aggregation, or order totals will be multiplied. */
DROP TABLE IF EXISTS clean.geolocation;
SELECT
 TRY_CONVERT(int, geolocation_zip_code_prefix) AS geolocation_zip_code_prefix,
 TRY_CONVERT(decimal(18,10), geolocation_lat) AS geolocation_lat,
 TRY_CONVERT(decimal(18,10), geolocation_lng) AS geolocation_lng,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255), geolocation_city)))), '') AS geolocation_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10), geolocation_state)))), '') AS geolocation_state,
 CASE WHEN TRY_CONVERT(float, geolocation_lat) NOT BETWEEN -90 AND 90 OR
           TRY_CONVERT(float, geolocation_lng) NOT BETWEEN -180 AND 180 OR
           (geolocation_lat IS NOT NULL AND TRY_CONVERT(float, geolocation_lat) IS NULL) OR
           (geolocation_lng IS NOT NULL AND TRY_CONVERT(float, geolocation_lng) IS NULL)
      THEN 1 ELSE 0 END AS invalid_coordinates
INTO clean.geolocation
FROM dbo.olist_geolocation_dataset;
GO

/* =====================================================================
   10. VALIDATION: confirm no rows were lost in cleaning.
   Every raw_count should equal clean_count.
   ===================================================================== */
SELECT 'orders' AS entity,
 (SELECT COUNT_BIG(*) FROM dbo.olist_orders_dataset) AS raw_count,
 (SELECT COUNT_BIG(*) FROM clean.orders) AS clean_count
UNION ALL SELECT 'order_items',
 (SELECT COUNT_BIG(*) FROM dbo.olist_order_items_dataset),
 (SELECT COUNT_BIG(*) FROM clean.order_items)
UNION ALL SELECT 'products',
 (SELECT COUNT_BIG(*) FROM dbo.olist_products_dataset),
 (SELECT COUNT_BIG(*) FROM clean.products)
UNION ALL SELECT 'sellers',
 (SELECT COUNT_BIG(*) FROM dbo.olist_sellers_dataset),
 (SELECT COUNT_BIG(*) FROM clean.sellers)
UNION ALL SELECT 'reviews',
 (SELECT COUNT_BIG(*) FROM dbo.olist_order_reviews_dataset),
 (SELECT COUNT_BIG(*) FROM clean.reviews)
UNION ALL SELECT 'category_translation',
 (SELECT COUNT_BIG(*) FROM dbo.product_category_name_translation),
 (SELECT COUNT_BIG(*) FROM clean.category_translation)
UNION ALL SELECT 'payments',
 (SELECT COUNT_BIG(*) FROM dbo.olist_order_payments_dataset),
 (SELECT COUNT_BIG(*) FROM clean.payments)
UNION ALL SELECT 'customers',
 (SELECT COUNT_BIG(*) FROM dbo.olist_customers_dataset),
 (SELECT COUNT_BIG(*) FROM clean.customers)
UNION ALL SELECT 'geolocation',
 (SELECT COUNT_BIG(*) FROM dbo.olist_geolocation_dataset),
 (SELECT COUNT_BIG(*) FROM clean.geolocation);
GO

/* 11. KEY DUPLICATE CHECKS: any returned row needs investigation. */
SELECT 'orders.order_id' AS key_name, COUNT_BIG(*) AS duplicate_groups FROM
 (SELECT order_id FROM clean.orders GROUP BY order_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'order_items.(order_id,order_item_id)', COUNT_BIG(*) FROM
 (SELECT order_id, order_item_id FROM clean.order_items GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'products.product_id', COUNT_BIG(*) FROM
 (SELECT product_id FROM clean.products GROUP BY product_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'sellers.seller_id', COUNT_BIG(*) FROM
 (SELECT seller_id FROM clean.sellers GROUP BY seller_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'reviews.(order_id,review_id)', COUNT_BIG(*) FROM
 (SELECT order_id, review_id FROM clean.reviews GROUP BY order_id, review_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'payments.(order_id,payment_sequential)', COUNT_BIG(*) FROM
 (SELECT order_id, payment_sequential FROM clean.payments GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) d
UNION ALL SELECT 'customers.customer_id', COUNT_BIG(*) FROM
 (SELECT customer_id FROM clean.customers GROUP BY customer_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'category_translation.product_category_name', COUNT_BIG(*) FROM
 (SELECT product_category_name FROM clean.category_translation GROUP BY product_category_name HAVING COUNT(*) > 1) d;
GO

/* 12. DATA QUALITY FLAGS */
SELECT 'orders: invalid purchase timestamp' AS issue, COUNT_BIG(*) AS affected_rows FROM clean.orders WHERE invalid_purchase_timestamp = 1
UNION ALL SELECT 'orders: invalid delivery timestamp', COUNT_BIG(*) FROM clean.orders WHERE invalid_delivery_timestamp = 1
UNION ALL SELECT 'orders: delivery before purchase', COUNT_BIG(*) FROM clean.orders WHERE delivery_before_purchase = 1
UNION ALL SELECT 'orders: delivered but missing delivery date', COUNT_BIG(*) FROM clean.orders WHERE delivered_without_date = 1
UNION ALL SELECT 'order_items: invalid price', COUNT_BIG(*) FROM clean.order_items WHERE invalid_price = 1
UNION ALL SELECT 'order_items: invalid freight', COUNT_BIG(*) FROM clean.order_items WHERE invalid_freight = 1
UNION ALL SELECT 'products: nonpositive dimension', COUNT_BIG(*) FROM clean.products WHERE nonpositive_dimension = 1
UNION ALL SELECT 'reviews: invalid score', COUNT_BIG(*) FROM clean.reviews WHERE invalid_review_score = 1
UNION ALL SELECT 'reviews: answer before creation', COUNT_BIG(*) FROM clean.reviews WHERE answer_before_creation = 1
UNION ALL SELECT 'payments: invalid value', COUNT_BIG(*) FROM clean.payments WHERE invalid_payment_value = 1
UNION ALL SELECT 'payments: invalid installments', COUNT_BIG(*) FROM clean.payments WHERE invalid_installments = 1
UNION ALL SELECT 'geolocation: invalid coordinates', COUNT_BIG(*) FROM clean.geolocation WHERE invalid_coordinates = 1;
GO

/* 13. ORPHAN CHECKS: zero is expected for most transactional links. */
SELECT 'items -> orders' AS relationship, COUNT_BIG(*) AS orphan_rows
FROM clean.order_items i LEFT JOIN clean.orders o ON i.order_id = o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'items -> products', COUNT_BIG(*)
FROM clean.order_items i LEFT JOIN clean.products p ON i.product_id = p.product_id WHERE p.product_id IS NULL
UNION ALL SELECT 'items -> sellers', COUNT_BIG(*)
FROM clean.order_items i LEFT JOIN clean.sellers s ON i.seller_id = s.seller_id WHERE s.seller_id IS NULL
UNION ALL SELECT 'reviews -> orders', COUNT_BIG(*)
FROM clean.reviews r LEFT JOIN clean.orders o ON r.order_id = o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'payments -> orders', COUNT_BIG(*)
FROM clean.payments p LEFT JOIN clean.orders o ON p.order_id = o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'orders -> customers', COUNT_BIG(*)
FROM clean.orders o LEFT JOIN clean.customers c ON o.customer_id = c.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'products -> translation (non-null category)', COUNT_BIG(*)
FROM clean.products p LEFT JOIN clean.category_translation t
 ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL;
GO

/* 14. REVIEW REPEATED IDS: count occurrences, not necessarily invalid rows */
SELECT review_id, COUNT_BIG(*) AS occurrences, COUNT(DISTINCT order_id) AS distinct_orders
FROM clean.reviews
GROUP BY review_id HAVING COUNT_BIG(*) > 1
ORDER BY occurrences DESC;
GO

/* 15. CATEGORY COVERAGE: show specific categories with no mapping */
SELECT p.product_category_name, COUNT_BIG(*) AS products_affected
FROM clean.products p LEFT JOIN clean.category_translation t
 ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL
GROUP BY p.product_category_name ORDER BY products_affected DESC;
GO

/* 16. GEOLOCATION ZIP MULTIPLICITY: do not treat repeated ZIP as an error */
SELECT TOP (20) geolocation_zip_code_prefix, COUNT_BIG(*) AS point_count,
 COUNT(DISTINCT geolocation_state) AS state_count
FROM clean.geolocation
GROUP BY geolocation_zip_code_prefix HAVING COUNT_BIG(*) > 1
ORDER BY point_count DESC;
GO

/* 17. Missing values are reported, not indiscriminately imputed. */
SELECT 'orders missing approval' AS metric, COUNT_BIG(*) AS affected_rows
FROM clean.orders WHERE order_approved_at IS NULL
UNION ALL SELECT 'orders missing delivery', COUNT_BIG(*)
FROM clean.orders WHERE order_delivered_customer_date IS NULL
UNION ALL SELECT 'products missing category', COUNT_BIG(*)
FROM clean.products WHERE product_category_name IS NULL
UNION ALL SELECT 'reviews missing title', COUNT_BIG(*)
FROM clean.reviews WHERE review_comment_title IS NULL
UNION ALL SELECT 'reviews missing message', COUNT_BIG(*)
FROM clean.reviews WHERE review_comment_message IS NULL
UNION ALL SELECT 'geolocation missing latitude', COUNT_BIG(*)
FROM clean.geolocation WHERE geolocation_lat IS NULL;
GO

/* =====================================================================
   REVIEW / DECISION LOG
   1. Review all validation result sets.
   2. Record observed exceptions in the EDA findings.
   3. Do NOT add PK/FK constraints until key/orphan checks pass.
   4. Do NOT assume geolocation ZIP is unique; design a ZIP lookup
      separately in normalization, with explicit choice of representative
      location if needed.
   5. Missing category translations should be resolved explicitly in
      normalization (e.g., UNKNOWN mapping), not invented here.
   6. Monetary measures: payment_value is not the same as item price;
      do not sum payments after joining to order items (fan-out risk).
   ===================================================================== */
