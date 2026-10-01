/*====================================================================
    OLIST E-COMMERCE SQL PROJECT
    FILE: 01_EDA.sql

    PURPOSE:
    Dense exploratory analysis using minimum queries with maximum
    analytical coverage.

    Flow:
    RAW DATA
       ↓
    EDA
       ↓
    CLEANING
       ↓
    NORMALIZATION
       ↓
    CONDITIONS
       ↓
    VIEWS
       ↓
    INDEXING
       ↓
    BUSINESS ANALYSIS

    CATEGORY TRANSLATION:
        column1 = Portuguese category
        column2 = English category
====================================================================*/


/**********************************************************************
1. DATASET PROFILE
   Row count + unique keys + date range + major business measures
**********************************************************************/

SELECT
    'orders' AS dataset,
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS unique_keys,
    MIN(order_purchase_timestamp) AS first_date,
    MAX(order_purchase_timestamp) AS last_date
FROM dbo.olist_orders_dataset

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)),
    MIN(shipping_limit_date),
    MAX(shipping_limit_date)
FROM dbo.olist_order_items_dataset

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    NULL,
    NULL
FROM dbo.olist_products_dataset

UNION ALL

SELECT
    'customers',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    NULL,
    NULL
FROM dbo.olist_customers_dataset

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    NULL,
    NULL
FROM dbo.olist_sellers_dataset

UNION ALL

SELECT
    'payments',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential)),
    NULL,
    NULL
FROM dbo.olist_order_payments_dataset

UNION ALL

SELECT
    'reviews',
    COUNT(*),
    COUNT(DISTINCT review_id),
    MIN(review_creation_date),
    MAX(review_creation_date)
FROM dbo.olist_order_reviews_dataset;


/**********************************************************************
2. DATA QUALITY PROFILE
   Nulls + invalid values + duplicate business keys
**********************************************************************/

SELECT
    'orders' AS dataset,

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_key,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_status,

    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_keys,

    SUM(
        CASE
            WHEN order_purchase_timestamp IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_purchase_date

FROM dbo.olist_orders_dataset

UNION ALL

SELECT
    'products',

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END),

    COUNT(*) - COUNT(DISTINCT product_id),

    SUM(
        CASE
            WHEN product_length_cm IS NULL
              OR product_height_cm IS NULL
              OR product_width_cm IS NULL
            THEN 1 ELSE 0
        END
    )

FROM dbo.olist_products_dataset

UNION ALL

SELECT
    'order_items',

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END),

    COUNT(*) -
        COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)),

    SUM(
        CASE
            WHEN price < 0 OR freight_value < 0
            THEN 1 ELSE 0
        END
    )

FROM dbo.olist_order_items_dataset

UNION ALL

SELECT
    'payments',

    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END),

    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END),

    COUNT(*) -
        COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential)),

    SUM(
        CASE
            WHEN payment_value <= 0
              OR payment_installments < 1
            THEN 1 ELSE 0
        END
    )

FROM dbo.olist_order_payments_dataset;


/**********************************************************************
3. REFERENTIAL INTEGRITY
   Detect orphan records across the core transaction model
**********************************************************************/

SELECT
    relationship,
    orphan_rows
FROM
(
    SELECT
        'order -> customer' AS relationship,
        COUNT(*) AS orphan_rows
    FROM dbo.olist_orders_dataset o
    LEFT JOIN dbo.olist_customers_dataset c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL

    SELECT
        'item -> order',
        COUNT(*)
    FROM dbo.olist_order_items_dataset i
    LEFT JOIN dbo.olist_orders_dataset o
        ON i.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'item -> product',
        COUNT(*)
    FROM dbo.olist_order_items_dataset i
    LEFT JOIN dbo.olist_products_dataset p
        ON i.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'item -> seller',
        COUNT(*)
    FROM dbo.olist_order_items_dataset i
    LEFT JOIN dbo.olist_sellers_dataset s
        ON i.seller_id = s.seller_id
    WHERE s.seller_id IS NULL

    UNION ALL

    SELECT
        'payment -> order',
        COUNT(*)
    FROM dbo.olist_order_payments_dataset p
    LEFT JOIN dbo.olist_orders_dataset o
        ON p.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'review -> order',
        COUNT(*)
    FROM dbo.olist_order_reviews_dataset r
    LEFT JOIN dbo.olist_orders_dataset o
        ON r.order_id = o.order_id
    WHERE o.order_id IS NULL
) x;


/**********************************************************************
4. ORDER + REVENUE EDA
   Status, orders, customers, revenue, AOV and monthly trend
**********************************************************************/

WITH monthly AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        ) AS month_start,

        COUNT(DISTINCT o.order_id) AS orders,

        COUNT(DISTINCT o.customer_id) AS customers,

        SUM(i.price) AS product_revenue,

        SUM(i.freight_value) AS freight,

        SUM(i.price + i.freight_value) AS gross_sales

    FROM dbo.olist_orders_dataset o

    INNER JOIN dbo.olist_order_items_dataset i
        ON o.order_id = i.order_id

    WHERE o.order_purchase_timestamp IS NOT NULL

    GROUP BY
        DATEFROMPARTS(
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
    freight,
    gross_sales,

    gross_sales / NULLIF(orders, 0)
        AS average_order_value,

    LAG(gross_sales) OVER(
        ORDER BY month_start
    ) AS previous_month_sales,

    CAST(
        100.0 *
        (
            gross_sales -
            LAG(gross_sales) OVER(
                ORDER BY month_start
            )
        )
        / NULLIF(
            LAG(gross_sales) OVER(
                ORDER BY month_start
            ),
            0
        )
        AS DECIMAL(10,2)
    ) AS mom_growth_percentage

FROM monthly
ORDER BY month_start;


/**********************************************************************
5. ORDER STATUS + CUSTOMER BEHAVIOR
   Operational status + repeat customer analysis
**********************************************************************/

WITH customer_orders AS
(
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM dbo.olist_orders_dataset
    GROUP BY customer_id
)
SELECT
    'ORDER_STATUS' AS metric_type,
    order_status AS category,
    COUNT(*) AS value
FROM dbo.olist_orders_dataset
GROUP BY order_status

UNION ALL

SELECT
    'CUSTOMER_TYPE',
    CASE
        WHEN order_count = 1 THEN 'ONE_TIME'
        ELSE 'REPEAT'
    END,
    COUNT(*)
FROM customer_orders
GROUP BY
    CASE
        WHEN order_count = 1 THEN 'ONE_TIME'
        ELSE 'REPEAT'
    END;


/**********************************************************************
6. PRODUCT + CATEGORY PERFORMANCE
   Category translation + units + orders + revenue + AOV
**********************************************************************/

SELECT TOP 20

    COALESCE(
        t.column2,
        p.product_category_name,
        'unknown'
    ) AS category,

    COUNT(*) AS units_sold,

    COUNT(DISTINCT i.order_id) AS orders,

    COUNT(DISTINCT i.product_id) AS products,

    SUM(i.price) AS revenue,

    SUM(i.freight_value) AS freight,

    SUM(i.price + i.freight_value) AS gross_sales,

    AVG(i.price) AS average_item_price

FROM dbo.olist_order_items_dataset i

INNER JOIN dbo.olist_products_dataset p
    ON i.product_id = p.product_id

LEFT JOIN dbo.product_category_name_translation t
    ON p.product_category_name = t.column1

GROUP BY
    COALESCE(
        t.column2,
        p.product_category_name,
        'unknown'
    )

ORDER BY gross_sales DESC;


/**********************************************************************
7. CUSTOMER + SELLER GEOGRAPHY
   Revenue concentration by customer and seller state
**********************************************************************/

SELECT
    c.customer_state,

    COUNT(DISTINCT c.customer_unique_id)
        AS customers,

    COUNT(DISTINCT o.order_id)
        AS orders,

    SUM(i.price + i.freight_value)
        AS gross_sales

FROM dbo.olist_customers_dataset c

INNER JOIN dbo.olist_orders_dataset o
    ON c.customer_id = o.customer_id

INNER JOIN dbo.olist_order_items_dataset i
    ON o.order_id = i.order_id

GROUP BY c.customer_state

ORDER BY gross_sales DESC;


/**********************************************************************
8. SELLER PERFORMANCE
   Revenue concentration + product breadth + order volume
**********************************************************************/

SELECT TOP 20

    seller_id,

    COUNT(DISTINCT order_id) AS orders,

    COUNT(DISTINCT product_id) AS products,

    COUNT(*) AS units_sold,

    SUM(price) AS revenue,

    SUM(freight_value) AS freight,

    SUM(price + freight_value) AS gross_sales,

    AVG(price) AS average_price

FROM dbo.olist_order_items_dataset

GROUP BY seller_id

ORDER BY gross_sales DESC;


/**********************************************************************
9. DELIVERY + CUSTOMER EXPERIENCE
   Delivery speed, lateness and review relationship
**********************************************************************/

SELECT

    r.review_score,

    COUNT(DISTINCT o.order_id) AS orders,

    AVG(
        DATEDIFF(
            DAY,
            o.order_purchase_timestamp,
            o.order_delivered_customer_date
        ) * 1.0
    ) AS avg_delivery_days,

    AVG(
        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
            THEN 1.0
            ELSE 0.0
        END
    ) * 100 AS on_time_percentage

FROM dbo.olist_order_reviews_dataset r

INNER JOIN dbo.olist_orders_dataset o
    ON r.order_id = o.order_id

WHERE
    o.order_purchase_timestamp IS NOT NULL
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY r.review_score

ORDER BY r.review_score;


/**********************************************************************
10. PAYMENT + REVENUE QUALITY
    Payment mix + installments + payment/item reconciliation
**********************************************************************/

WITH item_value AS
(
    SELECT
        order_id,
        SUM(price + freight_value) AS item_value
    FROM dbo.olist_order_items_dataset
    GROUP BY order_id
),
payment_value AS
(
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM dbo.olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    p.payment_type,

    COUNT(*) AS payment_records,

    COUNT(DISTINCT p.order_id) AS orders,

    SUM(p.payment_value) AS payment_value,

    AVG(p.payment_value) AS average_payment,

    AVG(p.payment_installments * 1.0)
        AS average_installments,

    SUM(
        CASE
            WHEN i.item_value IS NOT NULL
             AND ABS(p.payment_value - i.item_value) > 0.01
            THEN 1 ELSE 0
        END
    ) AS value_mismatch_orders

FROM dbo.olist_order_payments_dataset p

LEFT JOIN item_value i
    ON p.order_id = i.order_id

GROUP BY p.payment_type

ORDER BY payment_value DESC;


/**********************************************************************
11. ANOMALY / OUTLIER PROFILE
    Price, freight, dimensions and timeline anomalies
**********************************************************************/

SELECT

    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)
        AS invalid_price,

    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END)
        AS invalid_freight,

    SUM(
        CASE
            WHEN price > 1000 THEN 1
            ELSE 0
        END
    ) AS high_price_items,

    SUM(
        CASE
            WHEN freight_value > price
            THEN 1 ELSE 0
        END
    ) AS freight_greater_than_price

FROM dbo.olist_order_items_dataset;


SELECT

    SUM(
        CASE
            WHEN product_weight_g <= 0
            THEN 1 ELSE 0
        END
    ) AS invalid_weight,

    SUM(
        CASE
            WHEN product_length_cm <= 0
              OR product_height_cm <= 0
              OR product_width_cm <= 0
            THEN 1 ELSE 0
        END
    ) AS invalid_dimensions

FROM dbo.olist_products_dataset;


SELECT

    SUM(
        CASE
            WHEN order_delivered_customer_date
                 < order_purchase_timestamp
            THEN 1 ELSE 0
        END
    ) AS invalid_delivery_sequence,

    SUM(
        CASE
            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
            THEN 1 ELSE 0
        END
    ) AS late_deliveries

FROM dbo.olist_orders_dataset;


/**********************************************************************
12. EXECUTIVE EDA SUMMARY
    One query for the major portfolio KPIs
**********************************************************************/

SELECT

    COUNT(DISTINCT o.order_id)
        AS total_orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS total_customers,

    COUNT(DISTINCT i.product_id)
        AS products_sold,

    COUNT(DISTINCT i.seller_id)
        AS active_sellers,

    SUM(i.price)
        AS product_revenue,

    SUM(i.freight_value)
        AS freight_revenue,

    SUM(i.price + i.freight_value)
        AS gross_sales,

    SUM(i.price + i.freight_value)
        / NULLIF(COUNT(DISTINCT o.order_id),0)
        AS average_order_value,

    AVG(r.review_score * 1.0)
        AS average_review_score,

    AVG(
        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
            THEN 1.0
            ELSE 0.0
        END
    ) * 100
        AS on_time_delivery_percentage

FROM dbo.olist_orders_dataset o

LEFT JOIN dbo.olist_customers_dataset c
    ON o.customer_id = c.customer_id

LEFT JOIN dbo.olist_order_items_dataset i
    ON o.order_id = i.order_id

LEFT JOIN dbo.olist_order_reviews_dataset r
    ON o.order_id = r.order_id;


/**********************************************************************
END OF EDA
**********************************************************************/
