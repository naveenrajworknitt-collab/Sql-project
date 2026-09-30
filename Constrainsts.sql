/* =========================================================
   05_CONSTRAINTS.sql
   Olist E-Commerce SQL Project

   Purpose:
   Enforce business and data-quality rules on the
   normalized schema.

   Schema:
       norm

   NOTE:
   Primary keys and core foreign keys were already created
   in 04_NORMALIZATION.sql.
   This file adds additional constraints and validates them.
   ========================================================= */

USE Naveenraj;
GO


/* =========================================================
   1. ORDERS
   ========================================================= */

/*
Order status should contain only known Olist statuses.
*/

ALTER TABLE norm.orders
ADD CONSTRAINT CK_orders_status
CHECK
(
    order_status IN
    (
        'created',
        'approved',
        'invoiced',
        'processing',
        'shipped',
        'delivered',
        'canceled',
        'unavailable'
    )
);
GO


/*
Purchase timestamp must exist.
Already NOT NULL in normalization, so no additional
constraint is necessary here.
*/


/* =========================================================
   2. ORDER ITEMS
   ========================================================= */

/*
Prices and freight should not be negative.
*/

ALTER TABLE norm.order_items
ADD CONSTRAINT CK_order_items_price
CHECK
(
    price IS NULL OR price >= 0
);
GO

ALTER TABLE norm.order_items
ADD CONSTRAINT CK_order_items_freight
CHECK
(
    freight_value IS NULL OR freight_value >= 0
);
GO

/*
Order item number should be positive.
*/

ALTER TABLE norm.order_items
ADD CONSTRAINT CK_order_items_item_id
CHECK
(
    order_item_id > 0
);
GO


/* =========================================================
   3. PAYMENTS
   ========================================================= */

/*
Payment sequence must be positive.
*/

ALTER TABLE norm.order_payments
ADD CONSTRAINT CK_payments_sequential
CHECK
(
    payment_sequential > 0
);
GO


/*
Payment installments must be positive.
*/

ALTER TABLE norm.order_payments
ADD CONSTRAINT CK_payments_installments
CHECK
(
    payment_installments IS NULL
    OR payment_installments > 0
);
GO


/*
Payment value cannot be negative.
*/

ALTER TABLE norm.order_payments
ADD CONSTRAINT CK_payments_value
CHECK
(
    payment_value IS NULL
    OR payment_value >= 0
);
GO


/*
Known payment types.

Important:
The source contains 'not_defined', so we preserve it.
*/

ALTER TABLE norm.order_payments
ADD CONSTRAINT CK_payments_type
CHECK
(
    payment_type IS NULL
    OR payment_type IN
    (
        'credit_card',
        'boleto',
        'voucher',
        'debit_card',
        'not_defined'
    )
);
GO


/* =========================================================
   4. REVIEWS
   ========================================================= */

/*
Review score must be between 1 and 5.

This constraint was already created in the normalization
script. Therefore we DO NOT add it again.
*/


/* =========================================================
   5. PRODUCTS
   ========================================================= */

/*
Physical measurements cannot be negative.
*/

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_weight
CHECK
(
    product_weight_g IS NULL
    OR product_weight_g >= 0
);
GO

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_length
CHECK
(
    product_length_cm IS NULL
    OR product_length_cm >= 0
);
GO

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_height
CHECK
(
    product_height_cm IS NULL
    OR product_height_cm >= 0
);
GO

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_width
CHECK
(
    product_width_cm IS NULL
    OR product_width_cm >= 0
);
GO


/*
Number of product photos cannot be negative.
*/

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_photos
CHECK
(
    product_photos_qty IS NULL
    OR product_photos_qty >= 0
);
GO


/*
Text lengths cannot be negative.
*/

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_name_length
CHECK
(
    product_name_length IS NULL
    OR product_name_length >= 0
);
GO

ALTER TABLE norm.products
ADD CONSTRAINT CK_products_description_length
CHECK
(
    product_description_length IS NULL
    OR product_description_length >= 0
);
GO


/* =========================================================
   6. CATEGORIES
   ========================================================= */

/*
category_name is already:
    NOT NULL
    UNIQUE

from normalization.
*/


/* =========================================================
   7. CUSTOMERS
   ========================================================= */

/*
customer_unique_id represents the actual customer identity.

IMPORTANT:
Do NOT make it UNIQUE.

Reason:
The Olist dataset contains multiple customer_id records
belonging to the same customer_unique_id because the same
customer can place multiple orders.
*/


/* =========================================================
   8. SELLERS
   ========================================================= */

/*
Seller state should contain a two-character Brazilian state
code where available.

The source contains state abbreviations.
*/

ALTER TABLE norm.sellers
ADD CONSTRAINT CK_sellers_state
CHECK
(
    seller_state IS NULL
    OR LEN(seller_state) = 2
);
GO


/* =========================================================
   9. CUSTOMERS - STATE
   ========================================================= */

ALTER TABLE norm.customers
ADD CONSTRAINT CK_customers_state
CHECK
(
    customer_state IS NULL
    OR LEN(customer_state) = 2
);
GO


/* =========================================================
   10. GEOLOCATION
   ========================================================= */

/*
Brazilian latitude approximately lies between:
- 34 and 6 degrees south

Longitude approximately lies between:
- 74 and 34 degrees west

We should be careful here because source data quality
and geographic precision can vary.

Instead of imposing overly aggressive geographical rules,
we only validate that coordinates are valid ranges.
*/

ALTER TABLE norm.geolocation
ADD CONSTRAINT CK_geolocation_latitude
CHECK
(
    latitude IS NULL
    OR latitude BETWEEN -90 AND 90
);
GO

ALTER TABLE norm.geolocation
ADD CONSTRAINT CK_geolocation_longitude
CHECK
(
    longitude IS NULL
    OR longitude BETWEEN -180 AND 180
);
GO


/* =========================================================
   11. VALIDATION QUERIES
   ========================================================= */


/* ---------------------------------------------------------
   Check invalid order statuses
--------------------------------------------------------- */

SELECT
    order_status,
    COUNT(*) AS record_count
FROM norm.orders
GROUP BY order_status
ORDER BY record_count DESC;
GO


/* ---------------------------------------------------------
   Check negative order item values
--------------------------------------------------------- */

SELECT *
FROM norm.order_items
WHERE price < 0
   OR freight_value < 0;
GO


/* ---------------------------------------------------------
   Check invalid payments
--------------------------------------------------------- */

SELECT *
FROM norm.order_payments
WHERE payment_value < 0
   OR payment_installments <= 0
   OR payment_sequential <= 0;
GO


/* ---------------------------------------------------------
   Check invalid reviews
--------------------------------------------------------- */

SELECT *
FROM norm.order_reviews
WHERE review_score IS NOT NULL
  AND review_score NOT BETWEEN 1 AND 5;
GO


/* ---------------------------------------------------------
   Check invalid product dimensions
--------------------------------------------------------- */

SELECT *
FROM norm.products
WHERE product_weight_g < 0
   OR product_length_cm < 0
   OR product_height_cm < 0
   OR product_width_cm < 0;
GO


/* ---------------------------------------------------------
   Check invalid coordinates
--------------------------------------------------------- */

SELECT *
FROM norm.geolocation
WHERE latitude NOT BETWEEN -90 AND 90
   OR longitude NOT BETWEEN -180 AND 180;
GO


/* =========================================================
   12. REFERENTIAL INTEGRITY VALIDATION
   ========================================================= */

/*
Orders → Customers
*/

SELECT COUNT(*) AS orphan_orders
FROM norm.orders o
LEFT JOIN norm.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
GO


/*
Order Items → Orders
*/

SELECT COUNT(*) AS orphan_order_items
FROM norm.order_items oi
LEFT JOIN norm.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


/*
Order Items → Products
*/

SELECT COUNT(*) AS orphan_product_items
FROM norm.order_items oi
LEFT JOIN norm.products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
GO


/*
Order Items → Sellers
*/

SELECT COUNT(*) AS orphan_seller_items
FROM norm.order_items oi
LEFT JOIN norm.sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
GO


/*
Orders → Payments
*/

SELECT COUNT(*) AS orphan_payments
FROM norm.order_payments op
LEFT JOIN norm.orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


/*
Orders → Reviews
*/

SELECT COUNT(*) AS orphan_reviews
FROM norm.order_reviews r
LEFT JOIN norm.orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
GO


/* =========================================================
   13. CONSTRAINT SUMMARY
   =========================================================

   PRIMARY KEYS
   -------------
   customers       → customer_id
   orders          → order_id
   products        → product_id
   sellers         → seller_id
   categories      → category_id
   geolocation     → geolocation_id

   COMPOSITE KEYS
   --------------
   order_items     → (order_id, order_item_id)
   payments        → (order_id, payment_sequential)
   reviews         → (order_id, review_id)

   FOREIGN KEYS
   ------------
   orders.customer_id
       → customers.customer_id

   order_items.order_id
       → orders.order_id

   order_items.product_id
       → products.product_id

   order_items.seller_id
       → sellers.seller_id

   order_payments.order_id
       → orders.order_id

   order_reviews.order_id
       → orders.order_id

   products.category_id
       → categories.category_id

   CHECK CONSTRAINTS
   -----------------
   Valid order statuses
   Non-negative prices
   Non-negative freight
   Positive item numbers
   Positive payment sequence
   Positive payment installments
   Non-negative payment values
   Valid review scores
   Non-negative product dimensions
   Valid latitude/longitude
   Two-character state codes

   ========================================================= */
