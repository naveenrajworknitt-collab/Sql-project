/* ================================================================
   OLIST E-COMMERCE PROJECT
   03_NORMALIZATION.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Convert the cleaned staging layer into a reusable analytical model.

   DESIGN
   ------
   Dimensions:
       dim_customer
       dim_product
       dim_category
       dim_seller
       dim_geolocation
       dim_date

   Facts:
       fact_order
       fact_order_item
       fact_payment
       fact_review

   IMPORTANT
   ---------
   1. Raw Olist tables are never modified.
   2. Staging tables are read only.
   3. The translation raw table physically contains column1/column2.
      The staging layer already renamed those to meaningful names.
   4. fact_order_item keeps item-level price/freight.
      Do NOT join order-level payment totals directly to item rows
      when calculating revenue, otherwise fan-out can double-count.
   5. fact_payment stores each payment record separately.
   6. fact_review stores each review record separately.

   PREREQUISITE
   ------------
   Run 02_CLEANING.sql successfully first.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '03 - NORMALIZATION START';
PRINT '===============================================================';


/* ================================================================
   01. DROP PREVIOUS ANALYTICAL OBJECTS
   Drop facts first, then dimensions because of foreign keys.
   ================================================================ */

DROP TABLE IF EXISTS dbo.fact_review;
DROP TABLE IF EXISTS dbo.fact_payment;
DROP TABLE IF EXISTS dbo.fact_order_item;
DROP TABLE IF EXISTS dbo.fact_order;

DROP TABLE IF EXISTS dbo.dim_date;
DROP TABLE IF EXISTS dbo.dim_geolocation;
DROP TABLE IF EXISTS dbo.dim_seller;
DROP TABLE IF EXISTS dbo.dim_product;
DROP TABLE IF EXISTS dbo.dim_category;
DROP TABLE IF EXISTS dbo.dim_customer;
GO


/* ================================================================
   02. DIM CUSTOMER
   One row per customer_id.

   customer_unique_id represents the underlying customer across
   potentially multiple order-specific customer IDs.
   ================================================================ */

CREATE TABLE dbo.dim_customer
(
    customer_key BIGINT IDENTITY(1,1) NOT NULL,
    customer_id VARCHAR(100) NOT NULL,
    customer_unique_id VARCHAR(100) NULL,
    customer_zip_code_prefix INT NULL,
    customer_city VARCHAR(150) NULL,
    customer_state VARCHAR(10) NULL,

    CONSTRAINT PK_dim_customer
        PRIMARY KEY CLUSTERED (customer_key),

    CONSTRAINT UQ_dim_customer_customer_id
        UNIQUE (customer_id)
);
GO

INSERT INTO dbo.dim_customer
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    MAX(customer_unique_id),
    MAX(customer_zip_code_prefix),
    MAX(customer_city),
    MAX(customer_state)
FROM dbo.stg_olist_customers
WHERE customer_id IS NOT NULL
GROUP BY customer_id;
GO


/* ================================================================
   03. DIM CATEGORY
   The staging table has already mapped:
       product_category_name
       product_category_name_english
   ================================================================ */

CREATE TABLE dbo.dim_category
(
    category_key INT IDENTITY(1,1) NOT NULL,
    product_category_name VARCHAR(150) NOT NULL,
    product_category_name_english VARCHAR(150) NULL,

    CONSTRAINT PK_dim_category
        PRIMARY KEY CLUSTERED (category_key),

    CONSTRAINT UQ_dim_category_name
        UNIQUE (product_category_name)
);
GO

INSERT INTO dbo.dim_category
(
    product_category_name,
    product_category_name_english
)
SELECT
    product_category_name,
    MAX(product_category_name_english)
FROM dbo.stg_product_category_translation
WHERE product_category_name IS NOT NULL
GROUP BY product_category_name;
GO

/* Add products whose category has no translation. */
INSERT INTO dbo.dim_category
(
    product_category_name,
    product_category_name_english
)
SELECT
    p.product_category_name,
    NULL
FROM dbo.stg_olist_products AS p
LEFT JOIN dbo.dim_category AS c
    ON p.product_category_name = c.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND c.category_key IS NULL
GROUP BY p.product_category_name;
GO


/* ================================================================
   04. DIM PRODUCT
   One row per product_id.
   ================================================================ */

CREATE TABLE dbo.dim_product
(
    product_key BIGINT IDENTITY(1,1) NOT NULL,
    product_id VARCHAR(100) NOT NULL,
    category_key INT NULL,
    product_category_name VARCHAR(150) NULL,
    product_category_name_english VARCHAR(150) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g DECIMAL(18,2) NULL,
    product_length_cm DECIMAL(18,2) NULL,
    product_height_cm DECIMAL(18,2) NULL,
    product_width_cm DECIMAL(18,2) NULL,

    CONSTRAINT PK_dim_product
        PRIMARY KEY CLUSTERED (product_key),

    CONSTRAINT UQ_dim_product_product_id
        UNIQUE (product_id),

    CONSTRAINT FK_dim_product_category
        FOREIGN KEY (category_key)
        REFERENCES dbo.dim_category(category_key)
);
GO

INSERT INTO dbo.dim_product
(
    product_id,
    category_key,
    product_category_name,
    product_category_name_english,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    c.category_key,
    p.product_category_name,
    c.product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM dbo.stg_olist_products AS p
LEFT JOIN dbo.dim_category AS c
    ON p.product_category_name = c.product_category_name
WHERE p.product_id IS NOT NULL;
GO


/* ================================================================
   05. DIM SELLER
   ================================================================ */

CREATE TABLE dbo.dim_seller
(
    seller_key BIGINT IDENTITY(1,1) NOT NULL,
    seller_id VARCHAR(100) NOT NULL,
    seller_zip_code_prefix INT NULL,
    seller_city VARCHAR(150) NULL,
    seller_state VARCHAR(10) NULL,

    CONSTRAINT PK_dim_seller
        PRIMARY KEY CLUSTERED (seller_key),

    CONSTRAINT UQ_dim_seller_seller_id
        UNIQUE (seller_id)
);
GO

INSERT INTO dbo.dim_seller
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    MAX(seller_zip_code_prefix),
    MAX(seller_city),
    MAX(seller_state)
FROM dbo.stg_olist_sellers
WHERE seller_id IS NOT NULL
GROUP BY seller_id;
GO


/* ================================================================
   06. DIM GEOLOCATION
   The raw geolocation dataset may contain multiple coordinates for
   the same ZIP prefix. We therefore create one analytical row per
   ZIP prefix + city + state using average coordinates.

   This avoids multiplying fact rows when joining geography.
   ================================================================ */

CREATE TABLE dbo.dim_geolocation
(
    geolocation_key BIGINT IDENTITY(1,1) NOT NULL,
    geolocation_zip_code_prefix INT NOT NULL,
    geolocation_city VARCHAR(150) NULL,
    geolocation_state VARCHAR(10) NULL,
    avg_latitude DECIMAL(12,8) NULL,
    avg_longitude DECIMAL(12,8) NULL,

    CONSTRAINT PK_dim_geolocation
        PRIMARY KEY CLUSTERED (geolocation_key)
);
GO

INSERT INTO dbo.dim_geolocation
(
    geolocation_zip_code_prefix,
    geolocation_city,
    geolocation_state,
    avg_latitude,
    avg_longitude
)
SELECT
    geolocation_zip_code_prefix,
    MAX(geolocation_city),
    MAX(geolocation_state),
    AVG(geolocation_lat),
    AVG(geolocation_lng)
FROM dbo.stg_olist_geolocation
WHERE geolocation_zip_code_prefix IS NOT NULL
GROUP BY geolocation_zip_code_prefix;
GO


/* ================================================================
   07. DIM DATE
   Covers the observed purchase-date range.

   The recursive CTE is avoided deliberately. A numbers CTE based on
   system row sources is used so DATE generation is independent of
   MAXRECURSION settings.
   ================================================================ */

CREATE TABLE dbo.dim_date
(
    date_key INT NOT NULL,
    full_date DATE NOT NULL,
    calendar_year INT NOT NULL,
    calendar_quarter INT NOT NULL,
    calendar_month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    week_of_year INT NOT NULL,
    day_of_month INT NOT NULL,
    day_of_week_number INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BIT NOT NULL,

    CONSTRAINT PK_dim_date
        PRIMARY KEY CLUSTERED (date_key),

    CONSTRAINT UQ_dim_date_full_date
        UNIQUE (full_date)
);
GO

DECLARE @min_date DATE;
DECLARE @max_date DATE;

SELECT
    @min_date = CAST(MIN(order_purchase_timestamp) AS DATE),
    @max_date = CAST(MAX(order_purchase_timestamp) AS DATE)
FROM dbo.stg_olist_orders
WHERE order_purchase_timestamp IS NOT NULL;

IF @min_date IS NOT NULL AND @max_date IS NOT NULL
BEGIN
    ;WITH
    E1(N) AS
    (
        SELECT 1
        FROM (VALUES
            (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)
        ) AS x(N)
    ),
    E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),
    E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),
    Nums(N) AS
    (
        SELECT TOP (DATEDIFF(DAY, @min_date, @max_date) + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
        FROM E4
    ),
    Dates AS
    (
        SELECT DATEADD(DAY, N, @min_date) AS full_date
        FROM Nums
    )
    INSERT INTO dbo.dim_date
    (
        date_key,
        full_date,
        calendar_year,
        calendar_quarter,
        calendar_month,
        month_name,
        week_of_year,
        day_of_month,
        day_of_week_number,
        day_name,
        is_weekend
    )
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), full_date, 112)) AS date_key,
        full_date,
        YEAR(full_date),
        DATEPART(QUARTER, full_date),
        MONTH(full_date),
        DATENAME(MONTH, full_date),
        DATEPART(ISO_WEEK, full_date),
        DAY(full_date),
        ((DATEDIFF(DAY, '19000101', full_date) % 7) + 1),
        DATENAME(WEEKDAY, full_date),
        CASE
            WHEN ((DATEDIFF(DAY, '19000101', full_date) % 7) + 1) IN (6,7)
                THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END
    FROM Dates;
END;
GO


/* ================================================================
   08. FACT ORDER
   Grain: one row per order_id.

   Revenue is intentionally NOT stored here. Order-item revenue lives
   at item grain; payment_value lives at payment grain.
   ================================================================ */

CREATE TABLE dbo.fact_order
(
    order_key BIGINT IDENTITY(1,1) NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    customer_key BIGINT NULL,
    purchase_date_key INT NULL,
    order_status VARCHAR(50) NULL,
    order_purchase_timestamp DATETIME2 NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NULL,

    CONSTRAINT PK_fact_order
        PRIMARY KEY CLUSTERED (order_key),

    CONSTRAINT UQ_fact_order_order_id
        UNIQUE (order_id),

    CONSTRAINT FK_fact_order_customer
        FOREIGN KEY (customer_key)
        REFERENCES dbo.dim_customer(customer_key),

    CONSTRAINT FK_fact_order_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES dbo.dim_date(date_key)
);
GO

INSERT INTO dbo.fact_order
(
    order_id,
    customer_key,
    purchase_date_key,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    o.order_id,
    c.customer_key,
    CASE
        WHEN o.order_purchase_timestamp IS NOT NULL
        THEN CONVERT(INT, CONVERT(CHAR(8),
             CAST(o.order_purchase_timestamp AS DATE), 112))
    END,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date
FROM dbo.stg_olist_orders AS o
LEFT JOIN dbo.dim_customer AS c
    ON o.customer_id = c.customer_id
WHERE o.order_id IS NOT NULL;
GO


/* ================================================================
   09. FACT ORDER ITEM
   Grain: one row per order_id + order_item_id.
   ================================================================ */

CREATE TABLE dbo.fact_order_item
(
    order_item_key BIGINT IDENTITY(1,1) NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    order_item_id INT NOT NULL,
    product_key BIGINT NULL,
    seller_key BIGINT NULL,
    shipping_limit_date DATETIME2 NULL,
    price DECIMAL(18,2) NULL,
    freight_value DECIMAL(18,2) NULL,
    item_gross_value AS
        (ISNULL(price,0) + ISNULL(freight_value,0)) PERSISTED,

    CONSTRAINT PK_fact_order_item
        PRIMARY KEY CLUSTERED (order_item_key),

    CONSTRAINT UQ_fact_order_item
        UNIQUE (order_id, order_item_id),

    CONSTRAINT FK_fact_order_item_product
        FOREIGN KEY (product_key)
        REFERENCES dbo.dim_product(product_key),

    CONSTRAINT FK_fact_order_item_seller
        FOREIGN KEY (seller_key)
        REFERENCES dbo.dim_seller(seller_key)
);
GO

INSERT INTO dbo.fact_order_item
(
    order_id,
    order_item_id,
    product_key,
    seller_key,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    oi.order_id,
    oi.order_item_id,
    p.product_key,
    s.seller_key,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value
FROM dbo.stg_olist_order_items AS oi
LEFT JOIN dbo.dim_product AS p
    ON oi.product_id = p.product_id
LEFT JOIN dbo.dim_seller AS s
    ON oi.seller_id = s.seller_id
WHERE oi.order_id IS NOT NULL
  AND oi.order_item_id IS NOT NULL;
GO


/* ================================================================
   10. FACT PAYMENT
   Grain: one row per order_id + payment_sequential.
   ================================================================ */

CREATE TABLE dbo.fact_payment
(
    payment_key BIGINT IDENTITY(1,1) NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50) NULL,
    payment_installments INT NULL,
    payment_value DECIMAL(18,2) NULL,

    CONSTRAINT PK_fact_payment
        PRIMARY KEY CLUSTERED (payment_key),

    CONSTRAINT UQ_fact_payment
        UNIQUE (order_id, payment_sequential)
);
GO

INSERT INTO dbo.fact_payment
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
FROM dbo.stg_olist_order_payments
WHERE order_id IS NOT NULL
  AND payment_sequential IS NOT NULL;
GO


/* ================================================================
   11. FACT REVIEW
   Grain: one row per review_id + order_id.

   Olist can have more than one review row associated with an order,
   therefore order_id alone is NOT used as the unique key.
   ================================================================ */

CREATE TABLE dbo.fact_review
(
    review_key BIGINT IDENTITY(1,1) NOT NULL,
    review_id VARCHAR(100) NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    review_score INT NULL,
    review_comment_title VARCHAR(1000) NULL,
    review_comment_message VARCHAR(4000) NULL,
    review_creation_date DATETIME2 NULL,
    review_answer_timestamp DATETIME2 NULL,

    CONSTRAINT PK_fact_review
        PRIMARY KEY CLUSTERED (review_key),

    CONSTRAINT UQ_fact_review
        UNIQUE (review_id, order_id)
);
GO

INSERT INTO dbo.fact_review
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM dbo.stg_olist_order_reviews
WHERE review_id IS NOT NULL
  AND order_id IS NOT NULL;
GO


/* ================================================================
   12. FOREIGN KEYS FOR FACT TABLES
   ================================================================ */

ALTER TABLE dbo.fact_order_item
ADD CONSTRAINT FK_fact_order_item_order
FOREIGN KEY (order_id)
REFERENCES dbo.fact_order(order_id);
GO

ALTER TABLE dbo.fact_payment
ADD CONSTRAINT FK_fact_payment_order
FOREIGN KEY (order_id)
REFERENCES dbo.fact_order(order_id);
GO

ALTER TABLE dbo.fact_review
ADD CONSTRAINT FK_fact_review_order
FOREIGN KEY (order_id)
REFERENCES dbo.fact_order(order_id);
GO


/* ================================================================
   13. NORMALIZATION VALIDATION
   ================================================================ */

PRINT '===============================================================';
PRINT 'NORMALIZED TABLE ROW COUNTS';
PRINT '===============================================================';

SELECT 'dim_customer' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.dim_customer
UNION ALL
SELECT 'dim_category', COUNT_BIG(*)
FROM dbo.dim_category
UNION ALL
SELECT 'dim_product', COUNT_BIG(*)
FROM dbo.dim_product
UNION ALL
SELECT 'dim_seller', COUNT_BIG(*)
FROM dbo.dim_seller
UNION ALL
SELECT 'dim_geolocation', COUNT_BIG(*)
FROM dbo.dim_geolocation
UNION ALL
SELECT 'dim_date', COUNT_BIG(*)
FROM dbo.dim_date
UNION ALL
SELECT 'fact_order', COUNT_BIG(*)
FROM dbo.fact_order
UNION ALL
SELECT 'fact_order_item', COUNT_BIG(*)
FROM dbo.fact_order_item
UNION ALL
SELECT 'fact_payment', COUNT_BIG(*)
FROM dbo.fact_payment
UNION ALL
SELECT 'fact_review', COUNT_BIG(*)
FROM dbo.fact_review
ORDER BY table_name;
GO


/* ================================================================
   14. DUPLICATE GRAIN CHECKS
   Every result should be zero.
   ================================================================ */

SELECT
    'fact_order_duplicate_order_id' AS check_name,
    COUNT_BIG(*) AS duplicate_groups
FROM
(
    SELECT order_id
    FROM dbo.fact_order
    GROUP BY order_id
    HAVING COUNT_BIG(*) > 1
) AS x

UNION ALL

SELECT
    'fact_order_item_duplicate_grain',
    COUNT_BIG(*)
FROM
(
    SELECT order_id, order_item_id
    FROM dbo.fact_order_item
    GROUP BY order_id, order_item_id
    HAVING COUNT_BIG(*) > 1
) AS x

UNION ALL

SELECT
    'fact_payment_duplicate_grain',
    COUNT_BIG(*)
FROM
(
    SELECT order_id, payment_sequential
    FROM dbo.fact_payment
    GROUP BY order_id, payment_sequential
    HAVING COUNT_BIG(*) > 1
) AS x

UNION ALL

SELECT
    'fact_review_duplicate_grain',
    COUNT_BIG(*)
FROM
(
    SELECT review_id, order_id
    FROM dbo.fact_review
    GROUP BY review_id, order_id
    HAVING COUNT_BIG(*) > 1
) AS x;
GO


/* ================================================================
   15. FOREIGN-KEY COVERAGE CHECK
   ================================================================ */

SELECT
    'orders_without_customer_dimension' AS check_name,
    COUNT_BIG(*) AS bad_rows
FROM dbo.fact_order
WHERE customer_key IS NULL

UNION ALL
SELECT
    'items_without_product_dimension',
    COUNT_BIG(*)
FROM dbo.fact_order_item
WHERE product_key IS NULL

UNION ALL
SELECT
    'items_without_seller_dimension',
    COUNT_BIG(*)
FROM dbo.fact_order_item
WHERE seller_key IS NULL

UNION ALL
SELECT
    'orders_without_purchase_date',
    COUNT_BIG(*)
FROM dbo.fact_order
WHERE purchase_date_key IS NULL;
GO


/* ================================================================
   16. FAN-OUT DEMONSTRATION / SAFE REVENUE CHECK
   These two independent measures must remain separate.

   Item revenue:
       SUM(price)

   Payment revenue:
       SUM(payment_value)

   They should not be combined in one raw multi-fact join.
   ================================================================ */

SELECT
    SUM(ISNULL(price,0)) AS item_price_total,
    SUM(ISNULL(freight_value,0)) AS freight_total,
    SUM(ISNULL(item_gross_value,0)) AS item_gross_total
FROM dbo.fact_order_item;
GO

SELECT
    SUM(ISNULL(payment_value,0)) AS payment_total
FROM dbo.fact_payment;
GO


/* ================================================================
   17. SAMPLE STAR-SCHEMA QUERY
   ================================================================ */

SELECT TOP (20)
    fo.order_id,
    dd.full_date,
    dd.calendar_year,
    dd.calendar_month,
    dc.customer_city,
    dc.customer_state,
    p.product_category_name_english,
    s.seller_city,
    s.seller_state,
    foi.price,
    foi.freight_value,
    foi.item_gross_value
FROM dbo.fact_order AS fo
LEFT JOIN dbo.dim_date AS dd
    ON fo.purchase_date_key = dd.date_key
LEFT JOIN dbo.dim_customer AS dc
    ON fo.customer_key = dc.customer_key
LEFT JOIN dbo.fact_order_item AS foi
    ON fo.order_id = foi.order_id
LEFT JOIN dbo.dim_product AS p
    ON foi.product_key = p.product_key
LEFT JOIN dbo.dim_seller AS s
    ON foi.seller_key = s.seller_key
ORDER BY fo.order_purchase_timestamp DESC;
GO


/* ================================================================
   18. FINISH
   ================================================================ */

PRINT '===============================================================';
PRINT '03 - NORMALIZATION COMPLETE';
PRINT '===============================================================';
PRINT 'Raw tables untouched.';
PRINT 'Staging tables used as the source.';
PRINT 'Dimension and fact grains were explicitly defined.';
PRINT 'Next layer: 04_CONDITIONS.sql';
PRINT '===============================================================';
GO
