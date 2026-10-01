/*====================================================================
    PROJECT : OLIST E-COMMERCE INTELLIGENCE PLATFORM
    FILE    : EDA.sql
    DATABASE: Naveenraj
    PLATFORM: Microsoft SQL Server

    PURPOSE
    ------------------------------------------------------------------
    RAW DATA
       ↓
    EDA
       ↓
    CLEANING
       ↓
    NORMALIZATION
       ↓
    CONDITIONS / BUSINESS RULES
       ↓
    VIEWS
       ↓
    INDEXING
       ↓
    BUSINESS ANALYSIS

    IMPORTANT
    ------------------------------------------------------------------
    This file ONLY reads raw tables.

    No UPDATE
    No DELETE
    No ALTER
    No DROP

    Verified source schema:
      Products:
        product_name_lenght
        product_description_lenght

      Category translation:
        Your uploaded CSV has:
          product_category_name
          product_category_name_english

        If imported into SQL Server as generic headers,
        your current table may have:
          column1
          column2

      Therefore this EDA handles the translation table dynamically.

====================================================================*/


USE Naveenraj;
GO


/*====================================================================
1. DATASET + SCHEMA PROFILE

   One query gives:
   - table availability
   - row counts
   - column counts
   - primary analytical tables
====================================================================*/

SELECT
    t.TABLE_NAME,
    COUNT(c.COLUMN_NAME) AS column_count,
    CASE t.TABLE_NAME

        WHEN 'olist_orders_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_orders_dataset)

        WHEN 'olist_order_items_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_order_items_dataset)

        WHEN 'olist_products_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_products_dataset)

        WHEN 'olist_sellers_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_sellers_dataset)

        WHEN 'olist_order_reviews_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_order_reviews_dataset)

        WHEN 'product_category_name_translation'
            THEN (SELECT COUNT(*)
                  FROM dbo.product_category_name_translation)

        WHEN 'olist_order_payments_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_order_payments_dataset)

        WHEN 'olist_customers_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_customers_dataset)

        WHEN 'olist_geolocation_dataset'
            THEN (SELECT COUNT(*)
                  FROM dbo.olist_geolocation_dataset)

    END AS row_count

FROM INFORMATION_SCHEMA.TABLES t

JOIN INFORMATION_SCHEMA.COLUMNS c
    ON t.TABLE_NAME = c.TABLE_NAME
   AND t.TABLE_SCHEMA = c.TABLE_SCHEMA

WHERE
    t.TABLE_SCHEMA = 'dbo'
    AND t.TABLE_NAME IN
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

GROUP BY
    t.TABLE_NAME

ORDER BY
    row_count DESC;

GO


/*====================================================================
2. KEY CARDINALITY + DUPLICATE PROFILE

   Identifies:
   - candidate primary keys
   - composite keys
   - duplicate business records

   IMPORTANT:
   Multiple order_id values in items/payments/reviews are NORMAL.
   Composite keys are therefore tested where appropriate.
====================================================================*/

SELECT
    'orders.order_id' AS key_name,
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS distinct_keys,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM dbo.olist_orders_dataset

UNION ALL

SELECT
    'customers.customer_id',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM dbo.olist_customers_dataset

UNION ALL

SELECT
    'products.product_id',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM dbo.olist_products_dataset

UNION ALL

SELECT
    'sellers.seller_id',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM dbo.olist_sellers_dataset

UNION ALL

SELECT
    'order_items.order_id + order_item_id',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '|', order_item_id)),
    COUNT(*) -
        COUNT(DISTINCT CONCAT(order_id, '|', order_item_id))
FROM dbo.olist_order_items_dataset

UNION ALL

SELECT
    'payments.order_id + payment_sequential',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '|', payment_sequential)),
    COUNT(*) -
        COUNT(DISTINCT CONCAT(order_id, '|', payment_sequential))
FROM dbo.olist_order_payments_dataset

UNION ALL

SELECT
    'reviews.review_id',
    COUNT(*),
    COUNT(DISTINCT review_id),
    COUNT(*) - COUNT(DISTINCT review_id)
FROM dbo.olist_order_reviews_dataset

UNION ALL

SELECT
    'geolocation.zip_prefix',
    COUNT(*),
    COUNT(DISTINCT geolocation_zip_code_prefix),
    COUNT(*) -
        COUNT(DISTINCT geolocation_zip_code_prefix)
FROM dbo.olist_geolocation_dataset;

GO


/*====================================================================
3. NULL + DATA QUALITY PROFILE

   Dense quality audit across the major transactional dimensions.
====================================================================*/

SELECT
    'ORDERS' AS dataset,

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
        AS null_key,

    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)
        AS null_customer,

    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END)
        AS null_status,

    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)
        AS null_approved,

    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END)
        AS null_carrier_date,

    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END)
        AS null_delivery_date

FROM dbo.olist_orders_dataset


UNION ALL


SELECT
    'PRODUCTS',

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_name_lenght IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_description_lenght IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END),

    SUM(CASE
            WHEN product_weight_g IS NULL
              OR product_length_cm IS NULL
              OR product_height_cm IS NULL
              OR product_width_cm IS NULL
            THEN 1
            ELSE 0
        END)

FROM dbo.olist_products_dataset


UNION ALL


SELECT
    'ORDER_ITEMS',

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END),

    SUM(CASE
            WHEN price < 0
              OR freight_value < 0
            THEN 1
            ELSE 0
        END)

FROM dbo.olist_order_items_dataset


UNION ALL


SELECT
    'PAYMENTS',

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_value <= 0 THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_installments < 1 THEN 1 ELSE 0 END)

FROM dbo.olist_order_payments_dataset


UNION ALL


SELECT
    'REVIEWS',

    SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END),

    SUM(
        CASE
            WHEN review_score NOT BETWEEN 1 AND 5
            THEN 1
            ELSE 0
        END
    )

FROM dbo.olist_order_reviews_dataset;

GO


/*====================================================================
4. REFERENTIAL INTEGRITY

   Finds orphan records before cleaning.

   This is extremely important for the later normalization phase.
====================================================================*/

SELECT
    relationship,
    orphan_rows

FROM
(
    SELECT
        'Orders -> Customers' AS relationship,
        COUNT(*) AS orphan_rows

    FROM dbo.olist_orders_dataset o

    LEFT JOIN dbo.olist_customers_dataset c
        ON o.customer_id = c.customer_id

    WHERE c.customer_id IS NULL


    UNION ALL


    SELECT
        'Items -> Orders',
        COUNT(*)

    FROM dbo.olist_order_items_dataset i

    LEFT JOIN dbo.olist_orders_dataset o
        ON i.order_id = o.order_id

    WHERE o.order_id IS NULL


    UNION ALL


    SELECT
        'Items -> Products',
        COUNT(*)

    FROM dbo.olist_order_items_dataset i

    LEFT JOIN dbo.olist_products_dataset p
        ON i.product_id = p.product_id

    WHERE p.product_id IS NULL


    UNION ALL


    SELECT
        'Items -> Sellers',
        COUNT(*)

    FROM dbo.olist_order_items_dataset i

    LEFT JOIN dbo.olist_sellers_dataset s
        ON i.seller_id = s.seller_id

    WHERE s.seller_id IS NULL


    UNION ALL


    SELECT
        'Payments -> Orders',
        COUNT(*)

    FROM dbo.olist_order_payments_dataset p

    LEFT JOIN dbo.olist_orders_dataset o
        ON p.order_id = o.order_id

    WHERE o.order_id IS NULL


    UNION ALL


    SELECT
        'Reviews -> Orders',
        COUNT(*)

    FROM dbo.olist_order_reviews_dataset r

    LEFT JOIN dbo.olist_orders_dataset o
        ON r.order_id = o.order_id

    WHERE o.order_id IS NULL

) integrity;

GO


/*====================================================================
5. ORDER + REVENUE + TIME-SERIES EDA

   One dense query:
   - monthly orders
   - customers
   - product revenue
   - freight
   - total sales
   - AOV
   - MoM growth
====================================================================*/

WITH monthly_sales AS
(
    SELECT

        DATEFROMPARTS
        (
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS month_start,

        COUNT(DISTINCT o.order_id)
            AS orders,

        COUNT(DISTINCT c.customer_unique_id)
            AS customers,

        SUM(i.price)
            AS product_revenue,

        SUM(i.freight_value)
            AS freight_value,

        SUM(i.price + i.freight_value)
            AS total_sales

    FROM dbo.olist_orders_dataset o

    INNER JOIN dbo.olist_order_items_dataset i
        ON o.order_id = i.order_id

    LEFT JOIN dbo.olist_customers_dataset c
        ON o.customer_id = c.customer_id

    WHERE o.order_purchase_timestamp IS NOT NULL

    GROUP BY
        DATEFROMPARTS
        (
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        )
)

SELECT

    month_start,

    orders,

    customers,

    product_revenue,

    freight_value,

    total_sales,

    CAST(
        total_sales / NULLIF(orders,0)
        AS DECIMAL(18,2)
    ) AS average_order_value,

    LAG(total_sales)
        OVER (ORDER BY month_start)
        AS previous_month_sales,

    CAST
    (
        100.0 *
        (
            total_sales -
            LAG(total_sales)
                OVER (ORDER BY month_start)
        )
        /
        NULLIF
        (
            LAG(total_sales)
                OVER (ORDER BY month_start),
            0
        )
        AS DECIMAL(10,2)
    ) AS mom_growth_percentage

FROM monthly_sales

ORDER BY month_start;

GO


/*====================================================================
6. PRODUCT + CATEGORY PERFORMANCE

   Uses the actual product schema:
       product_name_lenght
       product_description_lenght

   Translation table is handled dynamically because your imported
   SQL table may contain either:
       product_category_name / product_category_name_english
   OR:
       column1 / column2
====================================================================*/

DECLARE @category_join NVARCHAR(MAX);

IF EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME = 'product_category_name_translation'
      AND COLUMN_NAME = 'column1'
)
BEGIN

    SET @category_join = N'
        SELECT
            LOWER(LTRIM(RTRIM(column1))) AS category_pt,
            LOWER(LTRIM(RTRIM(column2))) AS category_en
        FROM dbo.product_category_name_translation
    ';

END

ELSE
BEGIN

    SET @category_join = N'
        SELECT
            LOWER(LTRIM(RTRIM(product_category_name))) AS category_pt,
            LOWER(LTRIM(RTRIM(product_category_name_english))) AS category_en
        FROM dbo.product_category_name_translation
    ';

END;


DECLARE @sql NVARCHAR(MAX);

SET @sql = N'

WITH category_map AS
(
    ' + @category_join + N'
),

category_sales AS
(
    SELECT

        COALESCE
        (
            cm.category_en,
            p.product_category_name,
            ''unknown''
        ) AS category,

        COUNT(DISTINCT p.product_id)
            AS products,

        COUNT(DISTINCT oi.order_id)
            AS orders,

        COUNT(*)
            AS units_sold,

        SUM(oi.price)
            AS product_revenue,

        SUM(oi.freight_value)
            AS freight_value,

        SUM(oi.price + oi.freight_value)
            AS total_sales

    FROM dbo.olist_order_items_dataset oi

    INNER JOIN dbo.olist_products_dataset p
        ON oi.product_id = p.product_id

    LEFT JOIN category_map cm
        ON LOWER(LTRIM(RTRIM(p.product_category_name)))
         = cm.category_pt

    GROUP BY

        COALESCE
        (
            cm.category_en,
            p.product_category_name,
            ''unknown''
        )
)

SELECT TOP 20

    category,

    products,

    orders,

    units_sold,

    product_revenue,

    freight_value,

    total_sales,

    CAST
    (
        total_sales / NULLIF(orders,0)
        AS DECIMAL(18,2)
    ) AS sales_per_order

FROM category_sales

ORDER BY total_sales DESC;
';

EXEC sp_executesql @sql;

GO


/*====================================================================
7. CUSTOMER + SELLER + GEOGRAPHIC EDA

   Combines:
   - customer states
   - orders
   - revenue
   - active sellers
   - customer repeat behavior

   Avoids producing separate low-value geographic queries.
====================================================================*/

WITH customer_behavior AS
(
    SELECT

        c.customer_unique_id,

        c.customer_state,

        COUNT(DISTINCT o.order_id)
            AS order_count,

        SUM
        (
            ISNULL(oi.price,0)
            +
            ISNULL(oi.freight_value,0)
        ) AS customer_sales

    FROM dbo.olist_customers_dataset c

    INNER JOIN dbo.olist_orders_dataset o
        ON c.customer_id = o.customer_id

    LEFT JOIN dbo.olist_order_items_dataset oi
        ON o.order_id = oi.order_id

    GROUP BY
        c.customer_unique_id,
        c.customer_state
),

state_summary AS
(
    SELECT

        customer_state,

        COUNT(*) AS customers,

        SUM
        (
            CASE
                WHEN order_count > 1
                THEN 1
                ELSE 0
            END
        ) AS repeat_customers,

        SUM(order_count) AS orders,

        SUM(customer_sales) AS sales

    FROM customer_behavior

    GROUP BY customer_state
)

SELECT

    customer_state,

    customers,

    repeat_customers,

    orders,

    sales,

    CAST
    (
        100.0 * repeat_customers
        / NULLIF(customers,0)
        AS DECIMAL(10,2)
    ) AS repeat_customer_percentage,

    CAST
    (
        sales / NULLIF(orders,0)
        AS DECIMAL(18,2)
    ) AS revenue_per_order

FROM state_summary

ORDER BY sales DESC;

GO


/*====================================================================
8. PAYMENTS + REVIEWS + DELIVERY EXPERIENCE

   Combines:
   - payment method
   - payment value
   - installments
   - delivery performance
   - customer review score

   Uses order-level delivery status to avoid item-level duplication.
====================================================================*/

WITH order_delivery AS
(
    SELECT

        order_id,

        CASE
            WHEN order_delivered_customer_date IS NULL
                THEN 'NOT_DELIVERED'

            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
                THEN 'LATE'

            ELSE 'ON_TIME'
        END AS delivery_status,

        CASE
            WHEN order_delivered_customer_date IS NOT NULL
            THEN DATEDIFF
            (
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        END AS delivery_days

    FROM dbo.olist_orders_dataset
),

order_reviews AS
(
    SELECT

        order_id,

        AVG
        (
            CAST(review_score AS DECIMAL(10,2))
        ) AS avg_review_score

    FROM dbo.olist_order_reviews_dataset

    GROUP BY order_id
),

payment_summary AS
(
    SELECT

        order_id,

        SUM(payment_value)
            AS payment_value,

        AVG
        (
            CAST(payment_installments AS DECIMAL(10,2))
        ) AS avg_installments,

        MAX(payment_type)
            AS payment_type

    FROM dbo.olist_order_payments_dataset

    GROUP BY order_id
)

SELECT

    od.delivery_status,

    ps.payment_type,

    COUNT(*) AS orders,

    CAST
    (
        AVG(ps.payment_value)
        AS DECIMAL(18,2)
    ) AS avg_payment,

    CAST
    (
        AVG(ps.avg_installments)
        AS DECIMAL(10,2)
    ) AS avg_installments,

    CAST
    (
        AVG(od.delivery_days * 1.0)
        AS DECIMAL(10,2)
    ) AS avg_delivery_days,

    CAST
    (
        AVG(orv.avg_review_score)
        AS DECIMAL(10,2)
    ) AS avg_review_score

FROM order_delivery od

LEFT JOIN payment_summary ps
    ON od.order_id = ps.order_id

LEFT JOIN order_reviews orv
    ON od.order_id = orv.order_id

GROUP BY

    od.delivery_status,
    ps.payment_type

ORDER BY

    od.delivery_status,
    avg_review_score;

GO


/*====================================================================
9. BUSINESS ANOMALIES

   Finds issues that will become explicit business conditions
   during the cleaning/conditions stage.
====================================================================*/

SELECT

    SUM
    (
        CASE
            WHEN price < 0
            THEN 1
            ELSE 0
        END
    ) AS negative_price,

    SUM
    (
        CASE
            WHEN freight_value < 0
            THEN 1
            ELSE 0
        END
    ) AS negative_freight,

    SUM
    (
        CASE
            WHEN freight_value > price
            THEN 1
            ELSE 0
        END
    ) AS freight_above_product_price,

    SUM
    (
        CASE
            WHEN price >= 1000
            THEN 1
            ELSE 0
        END
    ) AS high_value_items

FROM dbo.olist_order_items_dataset;

GO


SELECT

    SUM
    (
        CASE
            WHEN product_weight_g <= 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_weight,

    SUM
    (
        CASE
            WHEN product_length_cm <= 0
              OR product_height_cm <= 0
              OR product_width_cm <= 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_dimensions,

    SUM
    (
        CASE
            WHEN product_photos_qty < 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_photo_count

FROM dbo.olist_products_dataset;

GO


SELECT

    SUM
    (
        CASE
            WHEN order_approved_at < order_purchase_timestamp
            THEN 1
            ELSE 0
        END
    ) AS approval_before_purchase,

    SUM
    (
        CASE
            WHEN order_delivered_carrier_date
                 < order_purchase_timestamp
            THEN 1
            ELSE 0
        END
    ) AS carrier_before_purchase,

    SUM
    (
        CASE
            WHEN order_delivered_customer_date
                 < order_purchase_timestamp
            THEN 1
            ELSE 0
        END
    ) AS delivery_before_purchase,

    SUM
    (
        CASE
            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_deliveries

FROM dbo.olist_orders_dataset;

GO


/*====================================================================
10. EXECUTIVE EDA SUMMARY

   Single result containing the major project KPIs.
====================================================================*/

WITH order_value AS
(
    SELECT

        order_id,

        SUM(price + freight_value)
            AS order_value

    FROM dbo.olist_order_items_dataset

    GROUP BY order_id
),

customer_count AS
(
    SELECT
        COUNT(DISTINCT customer_unique_id)
            AS customers
    FROM dbo.olist_customers_dataset
),

delivery AS
(
    SELECT

        COUNT(*) AS delivered_orders,

        SUM
        (
            CASE
                WHEN order_delivered_customer_date
                     <= order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) AS on_time_orders

    FROM dbo.olist_orders_dataset

    WHERE order_delivered_customer_date IS NOT NULL
)

SELECT

    (SELECT COUNT(*)
     FROM dbo.olist_orders_dataset)
        AS total_orders,

    (SELECT customers
     FROM customer_count)
        AS unique_customers,

    (SELECT COUNT(*)
     FROM dbo.olist_products_dataset)
        AS total_products,

    (SELECT COUNT(*)
     FROM dbo.olist_sellers_dataset)
        AS total_sellers,

    (SELECT SUM(order_value)
     FROM order_value)
        AS total_sales,

    (SELECT AVG(order_value)
     FROM order_value)
        AS average_order_value,

    (SELECT AVG(CAST(review_score AS DECIMAL(10,2)))
     FROM dbo.olist_order_reviews_dataset)
        AS average_review_score,

    (SELECT delivered_orders
     FROM delivery)
        AS delivered_orders,

    (SELECT on_time_orders
     FROM delivery)
        AS on_time_orders,

    CAST
    (
        100.0 *
        (SELECT on_time_orders FROM delivery)
        /
        NULLIF
        (
            (SELECT delivered_orders FROM delivery),
            0
        )
        AS DECIMAL(10,2)
    )
        AS on_time_delivery_percentage;

GO


/*====================================================================
EDA COMPLETE
====================================================================*/
