/* =========================================================
   02_CLEAN.sql
   OLIST E-COMMERCE
   Creates exactly these 9 clean tables:
     clean.orders
     clean.order_items
     clean.products
     clean.sellers
     clean.reviews
     clean.category_translation
     clean.payments
     clean.customers
     clean.geolocation
   ========================================================= */

USE Naveenraj;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
GO

/* Orders */
DROP TABLE IF EXISTS clean.orders;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),order_id))),'') AS order_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),customer_id))),'') AS customer_id,
 LOWER(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(50),order_status))),''))
   AS order_status,
 TRY_CONVERT(datetime2(0),order_purchase_timestamp) AS order_purchase_timestamp,
 TRY_CONVERT(datetime2(0),order_approved_at) AS order_approved_at,
 TRY_CONVERT(datetime2(0),order_delivered_carrier_date) AS order_delivered_carrier_date,
 TRY_CONVERT(datetime2(0),order_delivered_customer_date) AS order_delivered_customer_date,
 TRY_CONVERT(datetime2(0),order_estimated_delivery_date) AS order_estimated_delivery_date,
 CASE WHEN order_purchase_timestamp IS NOT NULL
           AND TRY_CONVERT(datetime2(0),order_purchase_timestamp) IS NULL THEN 1 ELSE 0 END
   AS invalid_purchase_timestamp,
 CASE WHEN order_delivered_customer_date IS NOT NULL
           AND TRY_CONVERT(datetime2(0),order_delivered_customer_date) IS NULL THEN 1 ELSE 0 END
   AS invalid_delivery_timestamp,
 CASE WHEN TRY_CONVERT(datetime2(0),order_delivered_customer_date)
           < TRY_CONVERT(datetime2(0),order_purchase_timestamp) THEN 1 ELSE 0 END
   AS delivery_before_purchase,
 CASE WHEN LOWER(LTRIM(RTRIM(CONVERT(nvarchar(50),order_status))))='delivered'
           AND TRY_CONVERT(datetime2(0),order_delivered_customer_date) IS NULL THEN 1 ELSE 0 END
   AS delivered_without_date
INTO clean.orders
FROM dbo.olist_orders_dataset;
GO

/* Order items */
DROP TABLE IF EXISTS clean.order_items;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),order_id))),'') AS order_id,
 TRY_CONVERT(int,order_item_id) AS order_item_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),product_id))),'') AS product_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),seller_id))),'') AS seller_id,
 TRY_CONVERT(datetime2(0),shipping_limit_date) AS shipping_limit_date,
 TRY_CONVERT(decimal(18,2),price) AS price,
 TRY_CONVERT(decimal(18,2),freight_value) AS freight_value,
 CASE WHEN TRY_CONVERT(decimal(18,2),price)<0
           OR (price IS NOT NULL AND TRY_CONVERT(decimal(18,2),price) IS NULL) THEN 1 ELSE 0 END
   AS invalid_price,
 CASE WHEN TRY_CONVERT(decimal(18,2),freight_value)<0
           OR (freight_value IS NOT NULL AND TRY_CONVERT(decimal(18,2),freight_value) IS NULL) THEN 1 ELSE 0 END
   AS invalid_freight
INTO clean.order_items
FROM dbo.olist_order_items_dataset;
GO

/* Products */
DROP TABLE IF EXISTS clean.products;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),product_id))),'') AS product_id,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),product_category_name)))),'')
   AS product_category_name,
 TRY_CONVERT(int,product_name_lenght) AS product_name_lenght,
 TRY_CONVERT(int,product_description_lenght) AS product_description_lenght,
 TRY_CONVERT(int,product_photos_qty) AS product_photos_qty,
 TRY_CONVERT(decimal(18,3),product_weight_g) AS product_weight_g,
 TRY_CONVERT(decimal(18,3),product_length_cm) AS product_length_cm,
 TRY_CONVERT(decimal(18,3),product_height_cm) AS product_height_cm,
 TRY_CONVERT(decimal(18,3),product_width_cm) AS product_width_cm,
 CASE WHEN TRY_CONVERT(decimal(18,3),product_weight_g)<=0
           OR TRY_CONVERT(decimal(18,3),product_length_cm)<=0
           OR TRY_CONVERT(decimal(18,3),product_height_cm)<=0
           OR TRY_CONVERT(decimal(18,3),product_width_cm)<=0 THEN 1 ELSE 0 END
   AS nonpositive_dimension
INTO clean.products
FROM dbo.olist_products_dataset;
GO

/* Sellers */
DROP TABLE IF EXISTS clean.sellers;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),seller_id))),'') AS seller_id,
 TRY_CONVERT(int,seller_zip_code_prefix) AS seller_zip_code_prefix,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),seller_city)))),'') AS seller_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10),seller_state)))),'') AS seller_state
INTO clean.sellers
FROM dbo.olist_sellers_dataset;
GO

/* Reviews */
DROP TABLE IF EXISTS clean.reviews;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),review_id))),'') AS review_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),order_id))),'') AS order_id,
 TRY_CONVERT(int,review_score) AS review_score,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(max),review_comment_title))),'') AS review_comment_title,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(max),review_comment_message))),'') AS review_comment_message,
 TRY_CONVERT(datetime2(0),review_creation_date) AS review_creation_date,
 TRY_CONVERT(datetime2(0),review_answer_timestamp) AS review_answer_timestamp,
 CASE WHEN TRY_CONVERT(int,review_score) NOT BETWEEN 1 AND 5
           OR (review_score IS NOT NULL AND TRY_CONVERT(int,review_score) IS NULL) THEN 1 ELSE 0 END
   AS invalid_review_score,
 CASE WHEN TRY_CONVERT(datetime2(0),review_answer_timestamp)
           < TRY_CONVERT(datetime2(0),review_creation_date) THEN 1 ELSE 0 END
   AS answer_before_creation
INTO clean.reviews
FROM dbo.olist_order_reviews_dataset;
GO

/* Category translation */
DROP TABLE IF EXISTS clean.category_translation;
SELECT
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),product_category_name))),'') AS product_category_name,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),product_category_name_english)))),'') AS product_category_name_english
INTO clean.category_translation
FROM dbo.product_category_name_translation;
GO

/* Payments */
DROP TABLE IF EXISTS clean.payments;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),order_id))),'') AS order_id,
 TRY_CONVERT(int,payment_sequential) AS payment_sequential,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(50),payment_type)))),'') AS payment_type,
 TRY_CONVERT(int,payment_installments) AS payment_installments,
 TRY_CONVERT(decimal(18,2),payment_value) AS payment_value,
 CASE WHEN TRY_CONVERT(decimal(18,2),payment_value)<0
           OR (payment_value IS NOT NULL AND TRY_CONVERT(decimal(18,2),payment_value) IS NULL) THEN 1 ELSE 0 END
   AS invalid_payment_value,
 CASE WHEN TRY_CONVERT(int,payment_installments)<0
           OR (payment_installments IS NOT NULL AND TRY_CONVERT(int,payment_installments) IS NULL) THEN 1 ELSE 0 END
   AS invalid_installments
INTO clean.payments
FROM dbo.olist_order_payments_dataset;
GO

/* Customers */
DROP TABLE IF EXISTS clean.customers;
SELECT
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),customer_id))),'') AS customer_id,
 NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(100),customer_unique_id))),'') AS customer_unique_id,
 TRY_CONVERT(int,customer_zip_code_prefix) AS customer_zip_code_prefix,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),customer_city)))),'') AS customer_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10),customer_state)))),'') AS customer_state
INTO clean.customers
FROM dbo.olist_customers_dataset;
GO

/* Geolocation */
DROP TABLE IF EXISTS clean.geolocation;
SELECT
 TRY_CONVERT(int,geolocation_zip_code_prefix) AS geolocation_zip_code_prefix,
 TRY_CONVERT(decimal(18,10),geolocation_lat) AS geolocation_lat,
 TRY_CONVERT(decimal(18,10),geolocation_lng) AS geolocation_lng,
 NULLIF(LOWER(LTRIM(RTRIM(CONVERT(nvarchar(255),geolocation_city)))),'') AS geolocation_city,
 NULLIF(UPPER(LTRIM(RTRIM(CONVERT(nvarchar(10),geolocation_state)))),'') AS geolocation_state,
 CASE WHEN TRY_CONVERT(float,geolocation_lat) NOT BETWEEN -90 AND 90
           OR TRY_CONVERT(float,geolocation_lng) NOT BETWEEN -180 AND 180
           OR (geolocation_lat IS NOT NULL AND TRY_CONVERT(float,geolocation_lat) IS NULL)
           OR (geolocation_lng IS NOT NULL AND TRY_CONVERT(float,geolocation_lng) IS NULL)
      THEN 1 ELSE 0 END AS invalid_coordinates
INTO clean.geolocation
FROM dbo.olist_geolocation_dataset;
GO

/* Row-count validation */
SELECT 'orders' AS entity,
       (SELECT COUNT_BIG(*) FROM dbo.olist_orders_dataset) AS raw_count,
       (SELECT COUNT_BIG(*) FROM clean.orders) AS clean_count
UNION ALL SELECT 'order_items',(SELECT COUNT_BIG(*) FROM dbo.olist_order_items_dataset),(SELECT COUNT_BIG(*) FROM clean.order_items)
UNION ALL SELECT 'products',(SELECT COUNT_BIG(*) FROM dbo.olist_products_dataset),(SELECT COUNT_BIG(*) FROM clean.products)
UNION ALL SELECT 'sellers',(SELECT COUNT_BIG(*) FROM dbo.olist_sellers_dataset),(SELECT COUNT_BIG(*) FROM clean.sellers)
UNION ALL SELECT 'reviews',(SELECT COUNT_BIG(*) FROM dbo.olist_order_reviews_dataset),(SELECT COUNT_BIG(*) FROM clean.reviews)
UNION ALL SELECT 'category_translation',(SELECT COUNT_BIG(*) FROM dbo.product_category_name_translation),(SELECT COUNT_BIG(*) FROM clean.category_translation)
UNION ALL SELECT 'payments',(SELECT COUNT_BIG(*) FROM dbo.olist_order_payments_dataset),(SELECT COUNT_BIG(*) FROM clean.payments)
UNION ALL SELECT 'customers',(SELECT COUNT_BIG(*) FROM dbo.olist_customers_dataset),(SELECT COUNT_BIG(*) FROM clean.customers)
UNION ALL SELECT 'geolocation',(SELECT COUNT_BIG(*) FROM dbo.olist_geolocation_dataset),(SELECT COUNT_BIG(*) FROM clean.geolocation);
GO
