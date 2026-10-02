/* ================================================================
   OLIST E-COMMERCE PROJECT
   04_CONDITIONS.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Create reusable business-condition tables from the normalized
   star-schema layer.

   PREREQUISITE
   ------------
   03_NORMALIZATION.sql must complete successfully.

   IMPORTANT
   ---------
   - No raw Olist table is modified.
   - No staging table is modified.
   - No unsupported "profit" metric is invented because the Olist
     dataset does not contain product cost.
   - Delivery lateness is measured against the estimated delivery date.
   - Revenue from items and payments remains at separate grains.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '04 - BUSINESS CONDITIONS START';
PRINT '===============================================================';


/* ================================================================
   01. CLEAN PREVIOUS CONDITION TABLES
   ================================================================ */

DROP TABLE IF EXISTS dbo.cond_order;
DROP TABLE IF EXISTS dbo.cond_order_item;
DROP TABLE IF EXISTS dbo.cond_customer;
DROP TABLE IF EXISTS dbo.cond_seller;
DROP TABLE IF EXISTS dbo.cond_product;
DROP TABLE IF EXISTS dbo.cond_payment;
DROP TABLE IF EXISTS dbo.cond_review;
GO


/* ================================================================
   02. ORDER CONDITIONS
   Grain: one row per order.

   Business flags:
       delivered
       cancelled
       unavailable
       completed
       delivery_late
       delivery_on_time
       delivery_days
       approval_days
       carrier_days
       estimated_delivery_days

   Date difference calculations are only produced when the required
   timestamps exist.
   ================================================================ */

CREATE TABLE dbo.cond_order
(
    order_key BIGINT NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    order_status VARCHAR(50) NULL,

    is_delivered BIT NOT NULL,
    is_cancelled BIT NOT NULL,
    is_unavailable BIT NOT NULL,
    is_completed BIT NOT NULL,

    delivery_days INT NULL,
    approval_days INT NULL,
    carrier_days INT NULL,
    estimated_delivery_days INT NULL,

    delivery_delay_days INT NULL,
    is_delivery_late BIT NULL,
    is_delivery_on_time BIT NULL,

    has_purchase_timestamp BIT NOT NULL,
    has_approval_timestamp BIT NOT NULL,
    has_carrier_timestamp BIT NOT NULL,
    has_customer_delivery_timestamp BIT NOT NULL,
    has_estimated_delivery_timestamp BIT NOT NULL,

    CONSTRAINT PK_cond_order
        PRIMARY KEY CLUSTERED (order_key),

    CONSTRAINT UQ_cond_order_order_id
        UNIQUE (order_id),

    CONSTRAINT FK_cond_order_order
        FOREIGN KEY (order_key)
        REFERENCES dbo.fact_order(order_key)
);
GO

INSERT INTO dbo.cond_order
(
    order_key,
    order_id,
    order_status,
    is_delivered,
    is_cancelled,
    is_unavailable,
    is_completed,
    delivery_days,
    approval_days,
    carrier_days,
    estimated_delivery_days,
    delivery_delay_days,
    is_delivery_late,
    is_delivery_on_time,
    has_purchase_timestamp,
    has_approval_timestamp,
    has_carrier_timestamp,
    has_customer_delivery_timestamp,
    has_estimated_delivery_timestamp
)
SELECT
    fo.order_key,
    fo.order_id,
    fo.order_status,

    CASE WHEN fo.order_status = 'delivered'
         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,

    CASE WHEN fo.order_status = 'canceled'
         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,

    CASE WHEN fo.order_status = 'unavailable'
         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,

    CASE WHEN fo.order_status = 'delivered'
         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,

    CASE
        WHEN fo.order_purchase_timestamp IS NOT NULL
         AND fo.order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fo.order_purchase_timestamp AS DATE),
                      CAST(fo.order_delivered_customer_date AS DATE))
    END,

    CASE
        WHEN fo.order_purchase_timestamp IS NOT NULL
         AND fo.order_approved_at IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fo.order_purchase_timestamp AS DATE),
                      CAST(fo.order_approved_at AS DATE))
    END,

    CASE
        WHEN fo.order_delivered_carrier_date IS NOT NULL
         AND fo.order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fo.order_delivered_carrier_date AS DATE),
                      CAST(fo.order_delivered_customer_date AS DATE))
    END,

    CASE
        WHEN fo.order_purchase_timestamp IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fo.order_purchase_timestamp AS DATE),
                      CAST(fo.order_estimated_delivery_date AS DATE))
    END,

    CASE
        WHEN fo.order_delivered_customer_date IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fo.order_estimated_delivery_date AS DATE),
                      CAST(fo.order_delivered_customer_date AS DATE))
    END,

    CASE
        WHEN fo.order_delivered_customer_date IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
         AND fo.order_delivered_customer_date >
             fo.order_estimated_delivery_date
        THEN CAST(1 AS BIT)
        WHEN fo.order_delivered_customer_date IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
        THEN CAST(0 AS BIT)
        ELSE NULL
    END,

    CASE
        WHEN fo.order_delivered_customer_date IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
         AND fo.order_delivered_customer_date <=
             fo.order_estimated_delivery_date
        THEN CAST(1 AS BIT)
        WHEN fo.order_delivered_customer_date IS NOT NULL
         AND fo.order_estimated_delivery_date IS NOT NULL
        THEN CAST(0 AS BIT)
        ELSE NULL
    END,

    CASE WHEN fo.order_purchase_timestamp IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fo.order_approved_at IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fo.order_delivered_carrier_date IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fo.order_delivered_customer_date IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fo.order_estimated_delivery_date IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END

FROM dbo.fact_order AS fo;
GO


/* ================================================================
   03. ORDER-ITEM CONDITIONS
   Grain: one row per order item.

   Includes freight ratio and price bands.
   These are descriptive metrics, not profit.
   ================================================================ */

CREATE TABLE dbo.cond_order_item
(
    order_item_key BIGINT NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    order_item_id INT NOT NULL,

    item_value_band VARCHAR(30) NULL,
    freight_band VARCHAR(30) NULL,

    freight_ratio DECIMAL(18,6) NULL,
    has_price BIT NOT NULL,
    has_freight BIT NOT NULL,

    CONSTRAINT PK_cond_order_item
        PRIMARY KEY CLUSTERED (order_item_key),

    CONSTRAINT FK_cond_order_item
        FOREIGN KEY (order_item_key)
        REFERENCES dbo.fact_order_item(order_item_key)
);
GO

INSERT INTO dbo.cond_order_item
(
    order_item_key,
    order_id,
    order_item_id,
    item_value_band,
    freight_band,
    freight_ratio,
    has_price,
    has_freight
)
SELECT
    foi.order_item_key,
    foi.order_id,
    foi.order_item_id,

    CASE
        WHEN foi.price IS NULL THEN 'Unknown'
        WHEN foi.price < 50 THEN 'Under 50'
        WHEN foi.price < 100 THEN '50-99'
        WHEN foi.price < 250 THEN '100-249'
        WHEN foi.price < 500 THEN '250-499'
        ELSE '500+'
    END,

    CASE
        WHEN foi.freight_value IS NULL THEN 'Unknown'
        WHEN foi.freight_value < 10 THEN 'Under 10'
        WHEN foi.freight_value < 25 THEN '10-24'
        WHEN foi.freight_value < 50 THEN '25-49'
        ELSE '50+'
    END,

    CASE
        WHEN foi.price IS NOT NULL
         AND foi.price > 0
         AND foi.freight_value IS NOT NULL
        THEN CAST(foi.freight_value / foi.price AS DECIMAL(18,6))
        ELSE NULL
    END,

    CASE WHEN foi.price IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN foi.freight_value IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END

FROM dbo.fact_order_item AS foi;
GO


/* ================================================================
   04. CUSTOMER CONDITIONS
   Grain: one row per customer dimension record.

   Metrics are based on orders and item values aggregated independently
   before joining, avoiding order-item multiplication.
   ================================================================ */

CREATE TABLE dbo.cond_customer
(
    customer_key BIGINT NOT NULL,
    customer_id VARCHAR(100) NOT NULL,
    order_count INT NOT NULL,
    delivered_order_count INT NOT NULL,
    cancelled_order_count INT NOT NULL,
    total_item_value DECIMAL(18,2) NOT NULL,
    total_freight_value DECIMAL(18,2) NOT NULL,

    customer_activity_band VARCHAR(30) NOT NULL,

    CONSTRAINT PK_cond_customer
        PRIMARY KEY CLUSTERED (customer_key),

    CONSTRAINT UQ_cond_customer_id
        UNIQUE (customer_id),

    CONSTRAINT FK_cond_customer
        FOREIGN KEY (customer_key)
        REFERENCES dbo.dim_customer(customer_key)
);
GO

;WITH OrderAgg AS
(
    SELECT
        fo.customer_key,
        COUNT_BIG(*) AS order_count,
        SUM(CASE WHEN co.is_delivered = 1 THEN 1 ELSE 0 END)
            AS delivered_order_count,
        SUM(CASE WHEN co.is_cancelled = 1 THEN 1 ELSE 0 END)
            AS cancelled_order_count
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.cond_order AS co
        ON fo.order_key = co.order_key
    WHERE fo.customer_key IS NOT NULL
    GROUP BY fo.customer_key
),
ItemAgg AS
(
    SELECT
        fo.customer_key,
        SUM(ISNULL(foi.price,0)) AS total_item_value,
        SUM(ISNULL(foi.freight_value,0)) AS total_freight_value
    FROM dbo.fact_order AS fo
    INNER JOIN dbo.fact_order_item AS foi
        ON fo.order_id = foi.order_id
    WHERE fo.customer_key IS NOT NULL
    GROUP BY fo.customer_key
)
INSERT INTO dbo.cond_customer
(
    customer_key,
    customer_id,
    order_count,
    delivered_order_count,
    cancelled_order_count,
    total_item_value,
    total_freight_value,
    customer_activity_band
)
SELECT
    dc.customer_key,
    dc.customer_id,

    ISNULL(CAST(oa.order_count AS INT),0),
    ISNULL(CAST(oa.delivered_order_count AS INT),0),
    ISNULL(CAST(oa.cancelled_order_count AS INT),0),

    CAST(ISNULL(ia.total_item_value,0) AS DECIMAL(18,2)),
    CAST(ISNULL(ia.total_freight_value,0) AS DECIMAL(18,2)),

    CASE
        WHEN ISNULL(oa.order_count,0) = 0 THEN 'No Orders'
        WHEN oa.order_count = 1 THEN 'One Order'
        WHEN oa.order_count <= 3 THEN '2-3 Orders'
        ELSE '4+ Orders'
    END

FROM dbo.dim_customer AS dc
LEFT JOIN OrderAgg AS oa
    ON dc.customer_key = oa.customer_key
LEFT JOIN ItemAgg AS ia
    ON dc.customer_key = ia.customer_key;
GO


/* ================================================================
   05. SELLER CONDITIONS
   Grain: one row per seller.

   Item-level metrics are aggregated before any other join.
   ================================================================ */

CREATE TABLE dbo.cond_seller
(
    seller_key BIGINT NOT NULL,
    seller_id VARCHAR(100) NOT NULL,
    item_count INT NOT NULL,
    order_count INT NOT NULL,
    total_item_value DECIMAL(18,2) NOT NULL,
    total_freight_value DECIMAL(18,2) NOT NULL,
    average_item_price DECIMAL(18,2) NULL,
    seller_activity_band VARCHAR(30) NOT NULL,

    CONSTRAINT PK_cond_seller
        PRIMARY KEY CLUSTERED (seller_key),

    CONSTRAINT UQ_cond_seller_id
        UNIQUE (seller_id),

    CONSTRAINT FK_cond_seller
        FOREIGN KEY (seller_key)
        REFERENCES dbo.dim_seller(seller_key)
);
GO

;WITH SellerAgg AS
(
    SELECT
        foi.seller_key,
        COUNT_BIG(*) AS item_count,
        COUNT(DISTINCT foi.order_id) AS order_count,
        SUM(ISNULL(foi.price,0)) AS total_item_value,
        SUM(ISNULL(foi.freight_value,0)) AS total_freight_value,
        AVG(CAST(foi.price AS DECIMAL(18,2))) AS average_item_price
    FROM dbo.fact_order_item AS foi
    WHERE foi.seller_key IS NOT NULL
    GROUP BY foi.seller_key
)
INSERT INTO dbo.cond_seller
(
    seller_key,
    seller_id,
    item_count,
    order_count,
    total_item_value,
    total_freight_value,
    average_item_price,
    seller_activity_band
)
SELECT
    ds.seller_key,
    ds.seller_id,
    ISNULL(CAST(sa.item_count AS INT),0),
    ISNULL(CAST(sa.order_count AS INT),0),
    CAST(ISNULL(sa.total_item_value,0) AS DECIMAL(18,2)),
    CAST(ISNULL(sa.total_freight_value,0) AS DECIMAL(18,2)),
    CAST(sa.average_item_price AS DECIMAL(18,2)),
    CASE
        WHEN ISNULL(sa.item_count,0) = 0 THEN 'No Items'
        WHEN sa.item_count <= 10 THEN 'Low Volume'
        WHEN sa.item_count <= 100 THEN 'Medium Volume'
        ELSE 'High Volume'
    END
FROM dbo.dim_seller AS ds
LEFT JOIN SellerAgg AS sa
    ON ds.seller_key = sa.seller_key;
GO


/* ================================================================
   06. PRODUCT CONDITIONS
   Grain: one row per product.

   Product attributes are descriptive. No inventory metric is inferred
   because the Olist product dataset does not provide stock quantity.
   ================================================================ */

CREATE TABLE dbo.cond_product
(
    product_key BIGINT NOT NULL,
    product_id VARCHAR(100) NOT NULL,

    product_size_band VARCHAR(30) NULL,
    product_weight_band VARCHAR(30) NULL,
    photo_band VARCHAR(30) NULL,
    description_length_band VARCHAR(30) NULL,

    CONSTRAINT PK_cond_product
        PRIMARY KEY CLUSTERED (product_key),

    CONSTRAINT UQ_cond_product_id
        UNIQUE (product_id),

    CONSTRAINT FK_cond_product
        FOREIGN KEY (product_key)
        REFERENCES dbo.dim_product(product_key)
);
GO

INSERT INTO dbo.cond_product
(
    product_key,
    product_id,
    product_size_band,
    product_weight_band,
    photo_band,
    description_length_band
)
SELECT
    dp.product_key,
    dp.product_id,

    CASE
        WHEN dp.product_length_cm IS NULL
          OR dp.product_height_cm IS NULL
          OR dp.product_width_cm IS NULL
            THEN 'Unknown'
        WHEN dp.product_length_cm
           * dp.product_height_cm
           * dp.product_width_cm < 1000
            THEN 'Small'
        WHEN dp.product_length_cm
           * dp.product_height_cm
           * dp.product_width_cm < 10000
            THEN 'Medium'
        ELSE 'Large'
    END,

    CASE
        WHEN dp.product_weight_g IS NULL THEN 'Unknown'
        WHEN dp.product_weight_g < 1000 THEN 'Under 1kg'
        WHEN dp.product_weight_g < 5000 THEN '1-5kg'
        WHEN dp.product_weight_g < 10000 THEN '5-10kg'
        ELSE '10kg+'
    END,

    CASE
        WHEN dp.product_photos_qty IS NULL THEN 'Unknown'
        WHEN dp.product_photos_qty = 0 THEN 'No Photos'
        WHEN dp.product_photos_qty <= 3 THEN '1-3 Photos'
        WHEN dp.product_photos_qty <= 6 THEN '4-6 Photos'
        ELSE '7+ Photos'
    END,

    CASE
        WHEN dp.product_description_lenght IS NULL THEN 'Unknown'
        WHEN dp.product_description_lenght < 100 THEN 'Short'
        WHEN dp.product_description_lenght < 500 THEN 'Medium'
        ELSE 'Long'
    END

FROM dbo.dim_product AS dp;
GO


/* ================================================================
   07. PAYMENT CONDITIONS
   Grain: one row per payment record.
   ================================================================ */

CREATE TABLE dbo.cond_payment
(
    payment_key BIGINT NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    payment_type VARCHAR(50) NULL,
    payment_installments INT NULL,
    payment_value DECIMAL(18,2) NULL,

    payment_value_band VARCHAR(30) NULL,
    installment_band VARCHAR(30) NULL,

    is_high_installment BIT NOT NULL,

    CONSTRAINT PK_cond_payment
        PRIMARY KEY CLUSTERED (payment_key),

    CONSTRAINT FK_cond_payment
        FOREIGN KEY (payment_key)
        REFERENCES dbo.fact_payment(payment_key)
);
GO

INSERT INTO dbo.cond_payment
(
    payment_key,
    order_id,
    payment_type,
    payment_installments,
    payment_value,
    payment_value_band,
    installment_band,
    is_high_installment
)
SELECT
    fp.payment_key,
    fp.order_id,
    fp.payment_type,
    fp.payment_installments,
    fp.payment_value,

    CASE
        WHEN fp.payment_value IS NULL THEN 'Unknown'
        WHEN fp.payment_value < 50 THEN 'Under 50'
        WHEN fp.payment_value < 100 THEN '50-99'
        WHEN fp.payment_value < 250 THEN '100-249'
        WHEN fp.payment_value < 500 THEN '250-499'
        ELSE '500+'
    END,

    CASE
        WHEN fp.payment_installments IS NULL THEN 'Unknown'
        WHEN fp.payment_installments = 1 THEN '1'
        WHEN fp.payment_installments <= 3 THEN '2-3'
        WHEN fp.payment_installments <= 6 THEN '4-6'
        WHEN fp.payment_installments <= 12 THEN '7-12'
        ELSE '13+'
    END,

    CASE
        WHEN fp.payment_installments > 6
            THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END

FROM dbo.fact_payment AS fp;
GO


/* ================================================================
   08. REVIEW CONDITIONS
   Grain: one row per review.

   Sentiment is NOT inferred from free text here. We use the explicit
   numeric review score supplied by the dataset.
   ================================================================ */

CREATE TABLE dbo.cond_review
(
    review_key BIGINT NOT NULL,
    review_id VARCHAR(100) NOT NULL,
    order_id VARCHAR(100) NOT NULL,

    review_score INT NULL,
    review_band VARCHAR(30) NULL,
    is_positive_review BIT NULL,
    is_neutral_review BIT NULL,
    is_negative_review BIT NULL,

    has_comment_title BIT NOT NULL,
    has_comment_message BIT NOT NULL,
    has_answer_timestamp BIT NOT NULL,

    answer_delay_days INT NULL,

    CONSTRAINT PK_cond_review
        PRIMARY KEY CLUSTERED (review_key),

    CONSTRAINT FK_cond_review
        FOREIGN KEY (review_key)
        REFERENCES dbo.fact_review(review_key)
);
GO

INSERT INTO dbo.cond_review
(
    review_key,
    review_id,
    order_id,
    review_score,
    review_band,
    is_positive_review,
    is_neutral_review,
    is_negative_review,
    has_comment_title,
    has_comment_message,
    has_answer_timestamp,
    answer_delay_days
)
SELECT
    fr.review_key,
    fr.review_id,
    fr.order_id,
    fr.review_score,

    CASE
        WHEN fr.review_score IS NULL THEN 'Unknown'
        WHEN fr.review_score IN (1,2) THEN 'Negative'
        WHEN fr.review_score = 3 THEN 'Neutral'
        WHEN fr.review_score IN (4,5) THEN 'Positive'
        ELSE 'Invalid'
    END,

    CASE
        WHEN fr.review_score IN (4,5) THEN CAST(1 AS BIT)
        WHEN fr.review_score IS NULL THEN NULL
        ELSE CAST(0 AS BIT)
    END,

    CASE
        WHEN fr.review_score = 3 THEN CAST(1 AS BIT)
        WHEN fr.review_score IS NULL THEN NULL
        ELSE CAST(0 AS BIT)
    END,

    CASE
        WHEN fr.review_score IN (1,2) THEN CAST(1 AS BIT)
        WHEN fr.review_score IS NULL THEN NULL
        ELSE CAST(0 AS BIT)
    END,

    CASE WHEN fr.review_comment_title IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fr.review_comment_message IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE WHEN fr.review_answer_timestamp IS NULL
         THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END,

    CASE
        WHEN fr.review_creation_date IS NOT NULL
         AND fr.review_answer_timestamp IS NOT NULL
        THEN DATEDIFF(DAY,
                      CAST(fr.review_creation_date AS DATE),
                      CAST(fr.review_answer_timestamp AS DATE))
        ELSE NULL
    END

FROM dbo.fact_review AS fr;
GO


/* ================================================================
   09. CONDITION TABLE COUNTS
   ================================================================ */

PRINT '===============================================================';
PRINT 'CONDITION TABLE ROW COUNTS';
PRINT '===============================================================';

SELECT 'cond_order' AS table_name, COUNT_BIG(*) AS row_count
FROM dbo.cond_order
UNION ALL
SELECT 'cond_order_item', COUNT_BIG(*)
FROM dbo.cond_order_item
UNION ALL
SELECT 'cond_customer', COUNT_BIG(*)
FROM dbo.cond_customer
UNION ALL
SELECT 'cond_seller', COUNT_BIG(*)
FROM dbo.cond_seller
UNION ALL
SELECT 'cond_product', COUNT_BIG(*)
FROM dbo.cond_product
UNION ALL
SELECT 'cond_payment', COUNT_BIG(*)
FROM dbo.cond_payment
UNION ALL
SELECT 'cond_review', COUNT_BIG(*)
FROM dbo.cond_review
ORDER BY table_name;
GO


/* ================================================================
   10. CONDITION DISTRIBUTIONS
   ================================================================ */

SELECT
    order_status,
    is_delivered,
    is_cancelled,
    is_delivery_late,
    COUNT_BIG(*) AS order_count
FROM dbo.cond_order
GROUP BY
    order_status,
    is_delivered,
    is_cancelled,
    is_delivery_late
ORDER BY order_count DESC;
GO

SELECT
    item_value_band,
    COUNT_BIG(*) AS item_count,
    SUM(ISNULL(f.price,0)) AS item_value
FROM dbo.cond_order_item AS c
INNER JOIN dbo.fact_order_item AS f
    ON c.order_item_key = f.order_item_key
GROUP BY item_value_band
ORDER BY item_count DESC;
GO

SELECT
    review_band,
    COUNT_BIG(*) AS review_count
FROM dbo.cond_review
GROUP BY review_band
ORDER BY review_count DESC;
GO

SELECT
    payment_type,
    payment_value_band,
    COUNT_BIG(*) AS payment_count,
    SUM(ISNULL(payment_value,0)) AS payment_value
FROM dbo.cond_payment
GROUP BY
    payment_type,
    payment_value_band
ORDER BY payment_value DESC;
GO


/* ================================================================
   11. CORE BUSINESS CONDITION SUMMARY
   ================================================================ */

SELECT
    COUNT_BIG(*) AS total_orders,
    SUM(CASE WHEN is_delivered = 1 THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN is_unavailable = 1 THEN 1 ELSE 0 END) AS unavailable_orders,
    SUM(CASE WHEN is_delivery_late = 1 THEN 1 ELSE 0 END) AS late_deliveries,
    AVG(CAST(delivery_days AS DECIMAL(18,2))) AS avg_delivery_days,
    AVG(CAST(delivery_delay_days AS DECIMAL(18,2))) AS avg_delivery_delay_days
FROM dbo.cond_order;
GO


/* ================================================================
   12. VALIDATION
   ================================================================ */

SELECT
    'cond_order grain' AS check_name,
    COUNT_BIG(*) - COUNT_BIG(DISTINCT order_id) AS duplicate_excess
FROM dbo.cond_order

UNION ALL

SELECT
    'cond_order_item grain',
    COUNT_BIG(*) -
    (
        SELECT COUNT_BIG(*)
        FROM
        (
            SELECT order_id, order_item_id
            FROM dbo.cond_order_item
            GROUP BY order_id, order_item_id
        ) AS x
    )

UNION ALL

SELECT
    'cond_customer grain',
    COUNT_BIG(*) - COUNT_BIG(DISTINCT customer_id)
FROM dbo.cond_customer

UNION ALL

SELECT
    'cond_seller grain',
    COUNT_BIG(*) - COUNT_BIG(DISTINCT seller_id)
FROM dbo.cond_seller

UNION ALL

SELECT
    'cond_product grain',
    COUNT_BIG(*) - COUNT_BIG(DISTINCT product_id)
FROM dbo.cond_product

UNION ALL

SELECT
    'cond_payment grain',
    COUNT_BIG(*) -
    (
        SELECT COUNT_BIG(*)
        FROM
        (
            SELECT order_id, payment_key
            FROM dbo.cond_payment
            GROUP BY order_id, payment_key
        ) AS x
    )

UNION ALL

SELECT
    'cond_review grain',
    COUNT_BIG(*) -
    (
        SELECT COUNT_BIG(*)
        FROM
        (
            SELECT review_id, order_id
            FROM dbo.cond_review
            GROUP BY review_id, order_id
        ) AS x
    );
GO


/* ================================================================
   13. FINISH
   ================================================================ */

PRINT '===============================================================';
PRINT '04 - BUSINESS CONDITIONS COMPLETE';
PRINT '===============================================================';
PRINT 'Next layer: 05_VIEWS.sql';
PRINT '===============================================================';
GO
