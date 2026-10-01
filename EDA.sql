/*
====================================================================
PROJECT  : OLIST E-COMMERCE SQL ANALYTICS PROJECT
DATABASE  : MICROSOFT SQL SERVER
FILE      : 01_EDA.sql

FLOW
----
01 EDA
02 CLEANING
03 NORMALIZATION
04 CONDITIONS
05 VIEWS
06 INDEXES
07 BUSINESS ANALYSIS
08 VALIDATION

PURPOSE
-------
Explore and profile the raw Olist dataset before cleaning.

IMPORTANT
---------
This file DOES NOT modify the raw data.

Your category translation table currently contains:

    column1
    column2

Therefore this script uses:

    column1 = Portuguese category
    column2 = English category

Do NOT rename the raw columns in this EDA file.

====================================================================
*/


/********************************************************************
1. TABLE INVENTORY
********************************************************************/

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY
    TABLE_SCHEMA,
    TABLE_NAME;


/********************************************************************
2. ROW COUNT OF ALL OLIST TABLES
********************************************************************/

SELECT
    'olist_orders_dataset' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.olist_orders_dataset

UNION ALL

SELECT
    'olist_order_items_dataset',
    COUNT_BIG(*)
FROM dbo.olist_order_items_dataset

UNION ALL

SELECT
    'olist_products_dataset',
    COUNT_BIG(*)
FROM dbo.olist_products_dataset

UNION ALL

SELECT
    'olist_sellers_dataset',
    COUNT_BIG(*)
FROM dbo.olist_sellers_dataset

UNION ALL

SELECT
    'olist_order_reviews_dataset',
    COUNT_BIG(*)
FROM dbo.olist_order_reviews_dataset

UNION ALL

SELECT
    'product_category_name_translation',
    COUNT_BIG(*)
FROM dbo.product_category_name_translation

UNION ALL

SELECT
    'olist_order_payments_dataset',
    COUNT_BIG(*)
FROM dbo.olist_order_payments_dataset

UNION ALL

SELECT
    'olist_customers_dataset',
    COUNT_BIG(*)
FROM dbo.olist_customers_dataset

UNION ALL

SELECT
    'olist_geolocation_dataset',
    COUNT_BIG(*)
FROM dbo.olist_geolocation_dataset;


/********************************************************************
3. COLUMN INFORMATION
********************************************************************/

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
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;


/********************************************************************
4. SAMPLE RECORDS
********************************************************************/

SELECT TOP (10) *
FROM dbo.olist_orders_dataset;

SELECT TOP (10) *
FROM dbo.olist_order_items_dataset;

SELECT TOP (10) *
FROM dbo.olist_products_dataset;

SELECT TOP (10) *
FROM dbo.olist_sellers_dataset;

SELECT TOP (10) *
FROM dbo.olist_order_reviews_dataset;

SELECT TOP (10) *
FROM dbo.product_category_name_translation;

SELECT TOP (10) *
FROM dbo.olist_order_payments_dataset;

SELECT TOP (10) *
FROM dbo.olist_customers_dataset;

SELECT TOP (10) *
FROM dbo.olist_geolocation_dataset;


/********************************************************************
5. ORDER PRIMARY KEY ANALYSIS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_occurrences
FROM dbo.olist_orders_dataset;


/* Actual duplicate order IDs */

SELECT
    order_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_orders_dataset
GROUP BY
    order_id
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/********************************************************************
6. ORDER ITEMS KEY ANALYSIS

Expected business key:

(order_id, order_item_id)
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(order_id, '|', order_item_id))
        AS distinct_business_keys
FROM dbo.olist_order_items_dataset;


SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_items_dataset
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/********************************************************************
7. PRODUCT KEY ANALYSIS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(product_id) AS non_null_product_ids,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM dbo.olist_products_dataset;


SELECT
    product_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_products_dataset
GROUP BY
    product_id
HAVING COUNT(*) > 1;


/********************************************************************
8. SELLER KEY ANALYSIS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(seller_id) AS non_null_seller_ids,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM dbo.olist_sellers_dataset;


SELECT
    seller_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_sellers_dataset
GROUP BY
    seller_id
HAVING COUNT(*) > 1;


/********************************************************************
9. CUSTOMER KEY ANALYSIS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_null_customer_ids,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_ids
FROM dbo.olist_customers_dataset;


/* Customer ID duplicates */

SELECT
    customer_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_customers_dataset
GROUP BY
    customer_id
HAVING COUNT(*) > 1;


/* Customers represented by multiple customer_id values */

SELECT
    customer_unique_id,
    COUNT(*) AS customer_id_count
FROM dbo.olist_customers_dataset
GROUP BY
    customer_unique_id
HAVING COUNT(*) > 1
ORDER BY
    customer_id_count DESC;


/********************************************************************
10. PAYMENT KEY ANALYSIS

Expected business key:

(order_id, payment_sequential)
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(order_id, '|', payment_sequential))
        AS distinct_payment_keys
FROM dbo.olist_order_payments_dataset;


SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_payments_dataset
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1;


/********************************************************************
11. REVIEW KEY ANALYSIS

Review_id is inspected before assuming uniqueness.
********************************************************************/

SELECT
    COUNT(*) AS total_reviews,
    COUNT(review_id) AS non_null_review_ids,
    COUNT(DISTINCT review_id) AS distinct_review_ids
FROM dbo.olist_order_reviews_dataset;


/* Duplicate review IDs */

SELECT
    review_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_reviews_dataset
GROUP BY
    review_id
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/* Composite order + review analysis */

SELECT
    order_id,
    review_id,
    COUNT(*) AS occurrence_count
FROM dbo.olist_order_reviews_dataset
GROUP BY
    order_id,
    review_id
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/********************************************************************
12. CATEGORY TRANSLATION KEY ANALYSIS

YOUR TABLE:

column1 = Portuguese category
column2 = English category
********************************************************************/

SELECT
    COUNT(*) AS total_rows,
    COUNT(column1) AS non_null_column1,
    COUNT(column2) AS non_null_column2,
    COUNT(DISTINCT column1) AS distinct_portuguese_categories,
    COUNT(DISTINCT column2) AS distinct_english_categories
FROM dbo.product_category_name_translation;


/* Duplicate Portuguese categories */

SELECT
    column1 AS portuguese_category,
    COUNT(*) AS occurrence_count
FROM dbo.product_category_name_translation
GROUP BY
    column1
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/* Duplicate English categories */

SELECT
    column2 AS english_category,
    COUNT(*) AS occurrence_count
FROM dbo.product_category_name_translation
GROUP BY
    column2
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC;


/********************************************************************
13. NULL ANALYSIS - ORDERS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN order_id IS NULL
             THEN 1 ELSE 0 END) AS null_order_id,

    SUM(CASE WHEN customer_id IS NULL
             THEN 1 ELSE 0 END) AS null_customer_id,

    SUM(CASE WHEN order_status IS NULL
             THEN 1 ELSE 0 END) AS null_order_status,

    SUM(CASE WHEN order_purchase_timestamp IS NULL
             THEN 1 ELSE 0 END) AS null_purchase_timestamp,

    SUM(CASE WHEN order_approved_at IS NULL
             THEN 1 ELSE 0 END) AS null_approved_at,

    SUM(CASE WHEN order_delivered_carrier_date IS NULL
             THEN 1 ELSE 0 END) AS null_carrier_date,

    SUM(CASE WHEN order_delivered_customer_date IS NULL
             THEN 1 ELSE 0 END) AS null_customer_delivery_date,

    SUM(CASE WHEN order_estimated_delivery_date IS NULL
             THEN 1 ELSE 0 END) AS null_estimated_delivery_date

FROM dbo.olist_orders_dataset;


/********************************************************************
14. NULL ANALYSIS - ORDER ITEMS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN order_id IS NULL
             THEN 1 ELSE 0 END) AS null_order_id,

    SUM(CASE WHEN order_item_id IS NULL
             THEN 1 ELSE 0 END) AS null_order_item_id,

    SUM(CASE WHEN product_id IS NULL
             THEN 1 ELSE 0 END) AS null_product_id,

    SUM(CASE WHEN seller_id IS NULL
             THEN 1 ELSE 0 END) AS null_seller_id,

    SUM(CASE WHEN shipping_limit_date IS NULL
             THEN 1 ELSE 0 END) AS null_shipping_limit_date,

    SUM(CASE WHEN price IS NULL
             THEN 1 ELSE 0 END) AS null_price,

    SUM(CASE WHEN freight_value IS NULL
             THEN 1 ELSE 0 END) AS null_freight_value

FROM dbo.olist_order_items_dataset;


/********************************************************************
15. NULL ANALYSIS - PRODUCTS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN product_id IS NULL
             THEN 1 ELSE 0 END) AS null_product_id,

    SUM(CASE WHEN product_category_name IS NULL
             THEN 1 ELSE 0 END) AS null_category,

    SUM(CASE WHEN product_name_lenght IS NULL
             THEN 1 ELSE 0 END) AS null_name_length,

    SUM(CASE WHEN product_description_lenght IS NULL
             THEN 1 ELSE 0 END) AS null_description_length,

    SUM(CASE WHEN product_photos_qty IS NULL
             THEN 1 ELSE 0 END) AS null_photos,

    SUM(CASE WHEN product_weight_g IS NULL
             THEN 1 ELSE 0 END) AS null_weight,

    SUM(CASE WHEN product_length_cm IS NULL
             THEN 1 ELSE 0 END) AS null_length,

    SUM(CASE WHEN product_height_cm IS NULL
             THEN 1 ELSE 0 END) AS null_height,

    SUM(CASE WHEN product_width_cm IS NULL
             THEN 1 ELSE 0 END) AS null_width

FROM dbo.olist_products_dataset;


/********************************************************************
16. NULL ANALYSIS - REVIEWS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN order_id IS NULL
             THEN 1 ELSE 0 END) AS null_order_id,

    SUM(CASE WHEN review_id IS NULL
             THEN 1 ELSE 0 END) AS null_review_id,

    SUM(CASE WHEN review_score IS NULL
             THEN 1 ELSE 0 END) AS null_review_score,

    SUM(CASE WHEN review_comment_title IS NULL
             THEN 1 ELSE 0 END) AS null_comment_title,

    SUM(CASE WHEN review_comment_message IS NULL
             THEN 1 ELSE 0 END) AS null_comment_message,

    SUM(CASE WHEN review_creation_date IS NULL
             THEN 1 ELSE 0 END) AS null_creation_date,

    SUM(CASE WHEN review_answer_timestamp IS NULL
             THEN 1 ELSE 0 END) AS null_answer_timestamp

FROM dbo.olist_order_reviews_dataset;


/********************************************************************
17. NULL ANALYSIS - PAYMENTS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN order_id IS NULL
             THEN 1 ELSE 0 END) AS null_order_id,

    SUM(CASE WHEN payment_sequential IS NULL
             THEN 1 ELSE 0 END) AS null_payment_sequential,

    SUM(CASE WHEN payment_type IS NULL
             THEN 1 ELSE 0 END) AS null_payment_type,

    SUM(CASE WHEN payment_installments IS NULL
             THEN 1 ELSE 0 END) AS null_installments,

    SUM(CASE WHEN payment_value IS NULL
             THEN 1 ELSE 0 END) AS null_payment_value

FROM dbo.olist_order_payments_dataset;


/********************************************************************
18. NULL ANALYSIS - CUSTOMERS
********************************************************************/

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN customer_id IS NULL
             THEN 1 ELSE 0 END) AS null_customer_id,

    SUM(CASE WHEN customer_unique_id IS NULL
             THEN 1 ELSE 0 END) AS null_customer_unique_id,

    SUM(CASE WHEN customer_zip_code_prefix IS NULL
             THEN 1 ELSE 0 END) AS null_zip,

    SUM(CASE WHEN customer_city IS NULL
             THEN 1 ELSE 0 END) AS null_city,

    SUM(CASE WHEN customer_state IS NULL
             THEN 1 ELSE 0 END) AS null_state

FROM dbo.olist_customers_dataset;


/********************************************************************
19. ORDER STATUS DISTRIBUTION
********************************************************************/

SELECT
    order_status,
    COUNT(*) AS order_count,

    CAST
    (
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER ()
        AS decimal(10,2)
    ) AS percentage_of_orders

FROM dbo.olist_orders_dataset

GROUP BY
    order_status

ORDER BY
    order_count DESC;


/********************************************************************
20. PAYMENT TYPE DISTRIBUTION
********************************************************************/

SELECT
    payment_type,
    COUNT(*) AS payment_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(payment_value) AS total_payment_value,
    AVG(payment_value) AS average_payment_value
FROM dbo.olist_order_payments_dataset
GROUP BY
    payment_type
ORDER BY
    total_payment_value DESC;


/********************************************************************
21. PAYMENT INSTALLMENT DISTRIBUTION
********************************************************************/

SELECT
    payment_installments,
    COUNT(*) AS payment_count,
    SUM(payment_value) AS total_value
FROM dbo.olist_order_payments_dataset
GROUP BY
    payment_installments
ORDER BY
    payment_installments;


/********************************************************************
22. REVIEW SCORE DISTRIBUTION
********************************************************************/

SELECT
    review_score,
    COUNT(*) AS review_count,

    CAST
    (
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER ()
        AS decimal(10,2)
    ) AS review_percentage

FROM dbo.olist_order_reviews_dataset

GROUP BY
    review_score

ORDER BY
    review_score;


/********************************************************************
23. PRODUCT CATEGORY DISTRIBUTION
********************************************************************/

SELECT TOP (30)
    product_category_name,
    COUNT(*) AS product_count
FROM dbo.olist_products_dataset
GROUP BY
    product_category_name
ORDER BY
    product_count DESC;


/********************************************************************
24. CUSTOMER STATE DISTRIBUTION
********************************************************************/

SELECT
    customer_state,
    COUNT(*) AS customer_count
FROM dbo.olist_customers_dataset
GROUP BY
    customer_state
ORDER BY
    customer_count DESC;


/********************************************************************
25. SELLER STATE DISTRIBUTION
********************************************************************/

SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM dbo.olist_sellers_dataset
GROUP BY
    seller_state
ORDER BY
    seller_count DESC;


/********************************************************************
26. ORDER DATE RANGE
********************************************************************/

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order,

    DATEDIFF
    (
        DAY,
        MIN(order_purchase_timestamp),
        MAX(order_purchase_timestamp)
    ) AS number_of_days

FROM dbo.olist_orders_dataset;


/********************************************************************
27. ORDERS BY YEAR
********************************************************************/

SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    COUNT(*) AS order_count

FROM dbo.olist_orders_dataset

WHERE order_purchase_timestamp IS NOT NULL

GROUP BY
    YEAR(order_purchase_timestamp)

ORDER BY
    order_year;


/********************************************************************
28. ORDERS BY YEAR AND MONTH
********************************************************************/

SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    MONTH(order_purchase_timestamp) AS order_month,
    COUNT(*) AS order_count

FROM dbo.olist_orders_dataset

WHERE order_purchase_timestamp IS NOT NULL

GROUP BY
    YEAR(order_purchase_timestamp),
    MONTH(order_purchase_timestamp)

ORDER BY
    order_year,
    order_month;


/********************************************************************
29. REVENUE EDA
********************************************************************/

SELECT
    COUNT(*) AS item_count,
    SUM(price) AS total_product_revenue,
    SUM(freight_value) AS total_freight,
    SUM(price + freight_value) AS total_sales,
    AVG(price) AS average_item_price,
    AVG(freight_value) AS average_freight

FROM dbo.olist_order_items_dataset;


/********************************************************************
30. PRICE DISTRIBUTION
********************************************************************/

SELECT
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price,
    AVG(price) AS average_price,
    STDEV(price) AS price_standard_deviation

FROM dbo.olist_order_items_dataset;


/********************************************************************
31. FREIGHT DISTRIBUTION
********************************************************************/

SELECT
    MIN(freight_value) AS minimum_freight,
    MAX(freight_value) AS maximum_freight,
    AVG(freight_value) AS average_freight,
    STDEV(freight_value) AS freight_standard_deviation

FROM dbo.olist_order_items_dataset;


/********************************************************************
32. PRICE OUTLIER ANALYSIS - IQR
********************************************************************/

WITH price_quartiles AS
(
    SELECT
        PERCENTILE_CONT(0.25)
        WITHIN GROUP
        (
            ORDER BY price
        ) OVER () AS q1,

        PERCENTILE_CONT(0.75)
        WITHIN GROUP
        (
            ORDER BY price
        ) OVER () AS q3

    FROM dbo.olist_order_items_dataset
),

bounds AS
(
    SELECT DISTINCT
        q1,
        q3,

        q1 - 1.5 * (q3 - q1)
            AS lower_bound,

        q3 + 1.5 * (q3 - q1)
            AS upper_bound

    FROM price_quartiles
)

SELECT
    b.lower_bound,
    b.upper_bound,
    COUNT(*) AS possible_outlier_rows

FROM dbo.olist_order_items_dataset i

CROSS JOIN bounds b

WHERE
    i.price < b.lower_bound
    OR i.price > b.upper_bound

GROUP BY
    b.lower_bound,
    b.upper_bound;


/********************************************************************
33. NEGATIVE / ZERO VALUE CHECK
********************************************************************/

SELECT
    SUM(CASE WHEN price < 0
             THEN 1 ELSE 0 END) AS negative_price_rows,

    SUM(CASE WHEN price = 0
             THEN 1 ELSE 0 END) AS zero_price_rows,

    SUM(CASE WHEN freight_value < 0
             THEN 1 ELSE 0 END) AS negative_freight_rows,

    SUM(CASE WHEN freight_value = 0
             THEN 1 ELSE 0 END) AS zero_freight_rows

FROM dbo.olist_order_items_dataset;


/********************************************************************
34. PRODUCT DIMENSION DATA QUALITY
********************************************************************/

SELECT
    SUM(CASE
            WHEN product_weight_g <= 0
            THEN 1 ELSE 0
        END) AS invalid_weight,

    SUM(CASE
            WHEN product_length_cm <= 0
            THEN 1 ELSE 0
        END) AS invalid_length,

    SUM(CASE
            WHEN product_height_cm <= 0
            THEN 1 ELSE 0
        END) AS invalid_height,

    SUM(CASE
            WHEN product_width_cm <= 0
            THEN 1 ELSE 0
        END) AS invalid_width,

    SUM(CASE
            WHEN product_photos_qty < 0
            THEN 1 ELSE 0
        END) AS invalid_photo_count

FROM dbo.olist_products_dataset;


/********************************************************************
35. REVIEW SCORE DATA QUALITY
********************************************************************/

SELECT
    COUNT(*) AS invalid_review_scores

FROM dbo.olist_order_reviews_dataset

WHERE review_score NOT BETWEEN 1 AND 5
   OR review_score IS NULL;


/********************************************************************
36. PAYMENT DATA QUALITY
********************************************************************/

SELECT
    SUM(CASE
            WHEN payment_value < 0
            THEN 1 ELSE 0
        END) AS negative_payment_value,

    SUM(CASE
            WHEN payment_installments < 0
            THEN 1 ELSE 0
        END) AS negative_installments,

    SUM(CASE
            WHEN payment_installments = 0
            THEN 1 ELSE 0
        END) AS zero_installments

FROM dbo.olist_order_payments_dataset;


/********************************************************************
37. ORDER TIMELINE ANOMALIES
********************************************************************/

SELECT
    order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date

FROM dbo.olist_orders_dataset

WHERE

    (
        order_approved_at IS NOT NULL
        AND order_purchase_timestamp IS NOT NULL
        AND order_approved_at < order_purchase_timestamp
    )

    OR

    (
        order_delivered_carrier_date IS NOT NULL
        AND order_purchase_timestamp IS NOT NULL
        AND order_delivered_carrier_date < order_purchase_timestamp
    )

    OR

    (
        order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp IS NOT NULL
        AND order_delivered_customer_date < order_purchase_timestamp
    )

    OR

    (
        order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
        AND order_delivered_customer_date > order_estimated_delivery_date
    );


/********************************************************************
38. DELIVERY PERFORMANCE
********************************************************************/

SELECT
    AVG
    (
        DATEDIFF
        (
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        ) * 1.0
    ) AS average_delivery_days,

    MIN
    (
        DATEDIFF
        (
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS minimum_delivery_days,

    MAX
    (
        DATEDIFF
        (
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS maximum_delivery_days

FROM dbo.olist_orders_dataset

WHERE order_delivered_customer_date IS NOT NULL;


/********************************************************************
39. ON-TIME VS LATE DELIVERY
********************************************************************/

SELECT
    CASE

        WHEN order_delivered_customer_date IS NULL
            THEN 'NOT_DELIVERED'

        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'ON_TIME'

        ELSE 'LATE'

    END AS delivery_status,

    COUNT(*) AS order_count

FROM dbo.olist_orders_dataset

GROUP BY

    CASE

        WHEN order_delivered_customer_date IS NULL
            THEN 'NOT_DELIVERED'

        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'ON_TIME'

        ELSE 'LATE'

    END

ORDER BY
    order_count DESC;


/********************************************************************
40. LATE DELIVERY RATE
********************************************************************/

SELECT

    COUNT(*) AS delivered_orders,

    SUM
    (
        CASE
            WHEN order_delivered_customer_date
                 > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_orders,

    CAST
    (
        100.0 *

        SUM
        (
            CASE
                WHEN order_delivered_customer_date
                     > order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        )

        / NULLIF(COUNT(*), 0)

        AS decimal(10,2)

    ) AS late_delivery_rate_pct

FROM dbo.olist_orders_dataset

WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


/********************************************************************
41. REFERENTIAL INTEGRITY
ORDER ITEMS -> ORDERS
********************************************************************/

SELECT
    COUNT(*) AS orphan_order_items

FROM dbo.olist_order_items_dataset i

LEFT JOIN dbo.olist_orders_dataset o
    ON o.order_id = i.order_id

WHERE o.order_id IS NULL;


/********************************************************************
42. REFERENTIAL INTEGRITY
ORDER ITEMS -> PRODUCTS
********************************************************************/

SELECT
    COUNT(*) AS orphan_products

FROM dbo.olist_order_items_dataset i

LEFT JOIN dbo.olist_products_dataset p
    ON p.product_id = i.product_id

WHERE p.product_id IS NULL;


/********************************************************************
43. REFERENTIAL INTEGRITY
ORDER ITEMS -> SELLERS
********************************************************************/

SELECT
    COUNT(*) AS orphan_sellers

FROM dbo.olist_order_items_dataset i

LEFT JOIN dbo.olist_sellers_dataset s
    ON s.seller_id = i.seller_id

WHERE s.seller_id IS NULL;


/********************************************************************
44. REFERENTIAL INTEGRITY
PAYMENTS -> ORDERS
********************************************************************/

SELECT
    COUNT(*) AS orphan_payments

FROM dbo.olist_order_payments_dataset p

LEFT JOIN dbo.olist_orders_dataset o
    ON o.order_id = p.order_id

WHERE o.order_id IS NULL;


/********************************************************************
45. REFERENTIAL INTEGRITY
REVIEWS -> ORDERS
********************************************************************/

SELECT
    COUNT(*) AS orphan_reviews

FROM dbo.olist_order_reviews_dataset r

LEFT JOIN dbo.olist_orders_dataset o
    ON o.order_id = r.order_id

WHERE o.order_id IS NULL;


/********************************************************************
46. CATEGORY TRANSLATION COVERAGE

IMPORTANT:
column1 = Portuguese category
column2 = English category
********************************************************************/

SELECT

    COUNT(*) AS products_with_category,

    SUM
    (
        CASE
            WHEN t.column1 IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS translated_category_matches,

    SUM
    (
        CASE
            WHEN t.column1 IS NULL
            THEN 1
            ELSE 0
        END
    ) AS untranslated_categories

FROM dbo.olist_products_dataset p

LEFT JOIN dbo.product_category_name_translation t
    ON p.product_category_name = t.column1;


/********************************************************************
47. CATEGORY TRANSLATION SAMPLE
********************************************************************/

SELECT TOP (30)

    p.product_category_name
        AS portuguese_category,

    t.column2
        AS english_category,

    COUNT(*) AS product_count

FROM dbo.olist_products_dataset p

LEFT JOIN dbo.product_category_name_translation t
    ON p.product_category_name = t.column1

GROUP BY
    p.product_category_name,
    t.column2

ORDER BY
    product_count DESC;


/********************************************************************
48. CUSTOMER ORDER FREQUENCY
********************************************************************/

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count

FROM dbo.olist_customers_dataset c

JOIN dbo.olist_orders_dataset o
    ON c.customer_id = o.customer_id

GROUP BY
    c.customer_unique_id

ORDER BY
    order_count DESC;


/********************************************************************
49. TOP CUSTOMERS
********************************************************************/

SELECT TOP (20)

    c.customer_unique_id,

    COUNT(DISTINCT o.order_id) AS order_count

FROM dbo.olist_customers_dataset c

JOIN dbo.olist_orders_dataset o
    ON c.customer_id = o.customer_id

GROUP BY
    c.customer_unique_id

ORDER BY
    order_count DESC;


/********************************************************************
50. TOP SELLERS BY REVENUE
********************************************************************/

SELECT TOP (20)

    seller_id,

    COUNT(DISTINCT order_id) AS order_count,

    COUNT(*) AS item_count,

    SUM(price) AS product_revenue,

    SUM(freight_value) AS freight_revenue,

    SUM(price + freight_value) AS gross_revenue

FROM dbo.olist_order_items_dataset

GROUP BY
    seller_id

ORDER BY
    gross_revenue DESC;


/********************************************************************
51. TOP PRODUCTS BY REVENUE
********************************************************************/

SELECT TOP (20)

    product_id,

    COUNT(*) AS units_sold,

    SUM(price) AS product_revenue,

    SUM(freight_value) AS freight_revenue,

    SUM(price + freight_value) AS gross_revenue

FROM dbo.olist_order_items_dataset

GROUP BY
    product_id

ORDER BY
    gross_revenue DESC;


/********************************************************************
52. TOP CATEGORIES BY REVENUE

FIXED:
translation table uses column1 / column2
********************************************************************/

SELECT TOP (20)

    COALESCE
    (
        t.column2,
        p.product_category_name,
        'unknown'
    ) AS category,

    COUNT(*) AS units_sold,

    SUM(i.price) AS product_revenue,

    SUM(i.freight_value) AS freight_revenue,

    SUM(i.price + i.freight_value) AS gross_revenue

FROM dbo.olist_order_items_dataset i

JOIN dbo.olist_products_dataset p
    ON p.product_id = i.product_id

LEFT JOIN dbo.product_category_name_translation t
    ON t.column1 = p.product_category_name

GROUP BY

    COALESCE
    (
        t.column2,
        p.product_category_name,
        'unknown'
    )

ORDER BY
    gross_revenue DESC;


/********************************************************************
53. MONTHLY REVENUE
********************************************************************/

SELECT

    YEAR(o.order_purchase_timestamp)
        AS order_year,

    MONTH(o.order_purchase_timestamp)
        AS order_month,

    COUNT(DISTINCT o.order_id)
        AS orders,

    COUNT(i.order_id)
        AS items,

    SUM(i.price)
        AS product_revenue,

    SUM(i.freight_value)
        AS freight_revenue,

    SUM(i.price + i.freight_value)
        AS gross_revenue

FROM dbo.olist_orders_dataset o

JOIN dbo.olist_order_items_dataset i
    ON i.order_id = o.order_id

GROUP BY

    YEAR(o.order_purchase_timestamp),

    MONTH(o.order_purchase_timestamp)

ORDER BY

    order_year,

    order_month;


/********************************************************************
54. STATE-WISE REVENUE
********************************************************************/

SELECT

    c.customer_state,

    COUNT(DISTINCT o.order_id)
        AS orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS customers,

    SUM(i.price + i.freight_value)
        AS gross_revenue

FROM dbo.olist_customers_dataset c

JOIN dbo.olist_orders_dataset o
    ON o.customer_id = c.customer_id

JOIN dbo.olist_order_items_dataset i
    ON i.order_id = o.order_id

GROUP BY
    c.customer_state

ORDER BY
    gross_revenue DESC;


/********************************************************************
55. FINAL EDA SUMMARY
********************************************************************/

SELECT

    (
        SELECT COUNT(*)
        FROM dbo.olist_orders_dataset
    ) AS total_orders,

    (
        SELECT COUNT(DISTINCT customer_unique_id)
        FROM dbo.olist_customers_dataset
    ) AS unique_customers,

    (
        SELECT COUNT(*)
        FROM dbo.olist_products_dataset
    ) AS products,

    (
        SELECT COUNT(*)
        FROM dbo.olist_sellers_dataset
    ) AS sellers,

    (
        SELECT COUNT(*)
        FROM dbo.olist_order_items_dataset
    ) AS order_items,

    (
        SELECT SUM(price + freight_value)
        FROM dbo.olist_order_items_dataset
    ) AS gross_revenue,

    (
        SELECT AVG(review_score * 1.0)
        FROM dbo.olist_order_reviews_dataset
    ) AS average_review_score;
