/* =========================================================
   04_NORMALIZATION.sql
   Olist E-Commerce SQL Project

   Source:
       clean schema

   Target:
       normalized schema

   Goal:
       1NF → 2NF → 3NF
       Primary Keys
       Foreign Keys
       Reduced redundancy
   ========================================================= */

USE Naveenraj;
GO


/* =========================================================
   1. CREATE NORMALIZED SCHEMA
   ========================================================= */

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'norm'
)
    EXEC('CREATE SCHEMA norm');
GO


/* =========================================================
   2. DROP EXISTING NORMALIZED TABLES
   Child tables first because of dependencies.
   ========================================================= */

DROP TABLE IF EXISTS norm.order_reviews;
DROP TABLE IF EXISTS norm.order_payments;
DROP TABLE IF EXISTS norm.order_items;
DROP TABLE IF EXISTS norm.orders;
DROP TABLE IF EXISTS norm.products;
DROP TABLE IF EXISTS norm.sellers;
DROP TABLE IF EXISTS norm.customers;
DROP TABLE IF EXISTS norm.categories;
DROP TABLE IF EXISTS norm.geolocation;
GO


/* =========================================================
   3. CATEGORIES
   ========================================================= */

CREATE TABLE norm.categories
(
    category_id INT IDENTITY(1,1) NOT NULL,
    category_name VARCHAR(150) NOT NULL,
    category_name_english VARCHAR(150) NULL,

    CONSTRAINT PK_categories
        PRIMARY KEY (category_id),

    CONSTRAINT UQ_categories_category_name
        UNIQUE (category_name)
);
GO

INSERT INTO norm.categories
(
    category_name,
    category_name_english
)
SELECT
    t.product_category_name,
    t.product_category_name_english
FROM clean.product_category_translation t;
GO


/* =========================================================
   4. PRODUCTS
   ========================================================= */

CREATE TABLE norm.products
(
    product_id VARCHAR(50) NOT NULL,
    category_id INT NULL,

    product_name_length INT NULL,
    product_description_length INT NULL,
    product_photos_qty INT NULL,

    product_weight_g DECIMAL(12,3) NULL,
    product_length_cm DECIMAL(12,3) NULL,
    product_height_cm DECIMAL(12,3) NULL,
    product_width_cm DECIMAL(12,3) NULL,

    CONSTRAINT PK_products
        PRIMARY KEY (product_id),

    CONSTRAINT FK_products_categories
        FOREIGN KEY (category_id)
        REFERENCES norm.categories(category_id)
);
GO

INSERT INTO norm.products
(
    product_id,
    category_id,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    c.category_id,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM clean.olist_products p
LEFT JOIN norm.categories c
    ON p.product_category_name = c.category_name;
GO


/* =========================================================
   5. GEOLOCATION
   IMPORTANT:
   ZIP PREFIX IS NOT THE PRIMARY KEY.

   Multiple records can represent the same ZIP prefix.
   Therefore we create a surrogate key.
   ========================================================= */

CREATE TABLE norm.geolocation
(
    geolocation_id BIGINT IDENTITY(1,1) NOT NULL,

    zip_code_prefix INT NULL,
    latitude DECIMAL(12,8) NULL,
    longitude DECIMAL(12,8) NULL,
    city VARCHAR(100) NULL,
    state CHAR(2) NULL,

    CONSTRAINT PK_geolocation
        PRIMARY KEY (geolocation_id)
);
GO

INSERT INTO norm.geolocation
(
    zip_code_prefix,
    latitude,
    longitude,
    city,
    state
)
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM clean.olist_geolocation;
GO


/* =========================================================
   6. CUSTOMERS
   ========================================================= */

CREATE TABLE norm.customers
(
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,

    customer_zip_code_prefix INT NULL,
    customer_city VARCHAR(100) NULL,
    customer_state CHAR(2) NULL,

    CONSTRAINT PK_customers
        PRIMARY KEY (customer_id)
);
GO

INSERT INTO norm.customers
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM clean.olist_customers;
GO


/* =========================================================
   7. SELLERS
   ========================================================= */

CREATE TABLE norm.sellers
(
    seller_id VARCHAR(50) NOT NULL,

    seller_zip_code_prefix INT NULL,
    seller_city VARCHAR(100) NULL,
    seller_state CHAR(2) NULL,

    CONSTRAINT PK_sellers
        PRIMARY KEY (seller_id)
);
GO

INSERT INTO norm.sellers
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM clean.olist_sellers;
GO


/* =========================================================
   8. ORDERS
   ========================================================= */

CREATE TABLE norm.orders
(
    order_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,

    order_status VARCHAR(30) NOT NULL,

    order_purchase_timestamp DATETIME2 NOT NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NULL,

    CONSTRAINT PK_orders
        PRIMARY KEY (order_id),

    CONSTRAINT FK_orders_customers
        FOREIGN KEY (customer_id)
        REFERENCES norm.customers(customer_id)
);
GO

INSERT INTO norm.orders
(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM clean.olist_orders;
GO


/* =========================================================
   9. ORDER ITEMS
   Composite PK:
       (order_id, order_item_id)

   This represents an individual product line within an order.
   ========================================================= */

CREATE TABLE norm.order_items
(
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,

    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,

    shipping_limit_date DATETIME2 NULL,

    price DECIMAL(12,2) NULL,
    freight_value DECIMAL(12,2) NULL,

    CONSTRAINT PK_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT FK_order_items_orders
        FOREIGN KEY (order_id)
        REFERENCES norm.orders(order_id),

    CONSTRAINT FK_order_items_products
        FOREIGN KEY (product_id)
        REFERENCES norm.products(product_id),

    CONSTRAINT FK_order_items_sellers
        FOREIGN KEY (seller_id)
        REFERENCES norm.sellers(seller_id)
);
GO

INSERT INTO norm.order_items
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM clean.olist_order_items;
GO


/* =========================================================
   10. ORDER PAYMENTS
   Composite PK:
       (order_id, payment_sequential)
   ========================================================= */

CREATE TABLE norm.order_payments
(
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,

    payment_type VARCHAR(30) NULL,
    payment_installments INT NULL,
    payment_value DECIMAL(14,2) NULL,

    CONSTRAINT PK_order_payments
        PRIMARY KEY
        (
            order_id,
            payment_sequential
        ),

    CONSTRAINT FK_order_payments_orders
        FOREIGN KEY (order_id)
        REFERENCES norm.orders(order_id)
);
GO

INSERT INTO norm.order_payments
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM clean.olist_order_payments;
GO


/* =========================================================
   11. ORDER REVIEWS
   Composite PK:
       (order_id, review_id)

   review_id alone was not unique in EDA.
   ========================================================= */

CREATE TABLE norm.order_reviews
(
    order_id VARCHAR(50) NOT NULL,
    review_id VARCHAR(50) NOT NULL,

    review_score INT NULL,

    review_comment_title VARCHAR(500) NULL,
    review_comment_message VARCHAR(5000) NULL,

    review_creation_date DATETIME2 NULL,
    review_answer_timestamp DATETIME2 NULL,

    CONSTRAINT PK_order_reviews
        PRIMARY KEY
        (
            order_id,
            review_id
        ),

    CONSTRAINT FK_order_reviews_orders
        FOREIGN KEY (order_id)
        REFERENCES norm.orders(order_id),

    CONSTRAINT CK_order_reviews_score
        CHECK
        (
            review_score IS NULL
            OR review_score BETWEEN 1 AND 5
        )
);
GO

INSERT INTO norm.order_reviews
(
    order_id,
    review_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    order_id,
    review_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM clean.olist_order_reviews;
GO


/* =========================================================
   12. VALIDATION
   ========================================================= */


/* ---------------------------------------------------------
   Customers
--------------------------------------------------------- */

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_real_customers
FROM norm.customers;
GO


/* ---------------------------------------------------------
   Orders
--------------------------------------------------------- */

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS unique_orders
FROM norm.orders;
GO


/* ---------------------------------------------------------
   Order Items
--------------------------------------------------------- */

SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT order_id) AS orders_with_items,
    COUNT(DISTINCT product_id) AS products_used,
    COUNT(DISTINCT seller_id) AS sellers_used
FROM norm.order_items;
GO


/* ---------------------------------------------------------
   Payments
--------------------------------------------------------- */

SELECT
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders_with_payments,
    SUM(payment_value) AS total_payment_value
FROM norm.order_payments;
GO


/* ---------------------------------------------------------
   Reviews
--------------------------------------------------------- */

SELECT
    COUNT(*) AS review_records,
    COUNT(DISTINCT review_id) AS review_ids,
    AVG(CAST(review_score AS DECIMAL(10,4))) AS average_review_score
FROM norm.order_reviews;
GO


/* =========================================================
   13. ORPHAN VALIDATION
   ========================================================= */

-- Orders without customers
SELECT COUNT(*) AS orphan_orders
FROM norm.orders o
LEFT JOIN norm.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
GO


-- Order items without orders
SELECT COUNT(*) AS orphan_order_items
FROM norm.order_items oi
LEFT JOIN norm.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


-- Order items without products
SELECT COUNT(*) AS orphan_product_items
FROM norm.order_items oi
LEFT JOIN norm.products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
GO


-- Order items without sellers
SELECT COUNT(*) AS orphan_seller_items
FROM norm.order_items oi
LEFT JOIN norm.sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
GO


-- Payments without orders
SELECT COUNT(*) AS orphan_payments
FROM norm.order_payments p
LEFT JOIN norm.orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


-- Reviews without orders
SELECT COUNT(*) AS orphan_reviews
FROM norm.order_reviews r
LEFT JOIN norm.orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


/* =========================================================
   14. NORMALIZATION SUMMARY
   =========================================================

   1NF
   - Each column contains atomic values.
   - No repeating groups.
   - Individual order items are represented as rows.

   2NF
   - Order-item attributes depend on the complete composite key:
         (order_id, order_item_id)
   - Payment attributes depend on:
         (order_id, payment_sequential)

   3NF
   - Product attributes are stored with products.
   - Seller attributes are stored with sellers.
   - Customer attributes are stored with customers.
   - Category information is separated from products.
   - Order information is separated from order items.
   - Payment information is separated from orders.
   - Review information is separated from orders.

   RESULT:

   customers
        ↓
      orders
        ↓
   order_items
      ↙   ↘
 products sellers
      ↓
  categories

   orders → payments
   orders → reviews

   ========================================================= */
