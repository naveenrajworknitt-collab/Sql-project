/* ================================================================
   OLIST E-COMMERCE PROJECT
   06_INDEXES.sql
   SQL Server / SSMS

   PURPOSE
   -------
   Add targeted nonclustered indexes to support the reporting views,
   joins, filters, grouping, and common business-analysis queries.

   PREREQUISITE
   ------------
   03_NORMALIZATION.sql and 04_CONDITIONS.sql must succeed.
   05_VIEWS_FIXED.sql must compile successfully before this layer.

   INDEX DESIGN PRINCIPLES
   -----------------------
   1. Do not duplicate indexes already created by PRIMARY KEY / UNIQUE
      constraints.
   2. Index foreign-key and high-use join columns.
   3. Use INCLUDE columns for common reporting projections.
   4. Avoid indexing every column.
   5. Keep this layer separate from query-specific experimental indexes.
   ================================================================ */

USE [Sql_project];
GO

SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '06 - INDEXING START';
PRINT '===============================================================';


/* ================================================================
   01. DROP ONLY THE INDEXES OWNED BY THIS SCRIPT
   ================================================================ */

DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql +
    N'DROP INDEX ' + QUOTENAME(i.name) +
    N' ON ' + QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) + N';' +
    CHAR(13) + CHAR(10)
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON i.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE i.name IN
(
    N'IX_fact_order_customer_date',
    N'IX_fact_order_purchase_date',
    N'IX_fact_order_status',
    N'IX_fact_order_item_product',
    N'IX_fact_order_item_seller',
    N'IX_fact_order_item_shipping_date',
    N'IX_fact_payment_type',
    N'IX_fact_review_score',
    N'IX_fact_review_creation_date',

    N'IX_dim_customer_state',
    N'IX_dim_customer_unique_id',
    N'IX_dim_product_category',
    N'IX_dim_product_category_english',
    N'IX_dim_seller_state',
    N'IX_dim_geolocation_zip',
    N'IX_dim_date_year_month',

    N'IX_cond_order_status',
    N'IX_cond_order_delivery_late',
    N'IX_cond_order_item_band',
    N'IX_cond_customer_activity',
    N'IX_cond_seller_activity',
    N'IX_cond_product_bands',
    N'IX_cond_payment_type',
    N'IX_cond_review_band'
);

IF @sql <> N''
    EXEC sys.sp_executesql @sql;
GO


/* ================================================================
   02. FACT ORDER INDEXES
   ================================================================ */

/*
   Supports:
       fact_order -> dim_customer
       customer/state analysis
       monthly/customer reporting
*/
CREATE NONCLUSTERED INDEX IX_fact_order_customer_date
ON dbo.fact_order
(
    customer_key,
    purchase_date_key
)
INCLUDE
(
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date
);
GO

/*
   Supports:
       date filtering
       monthly sales
       delivery analysis
*/
CREATE NONCLUSTERED INDEX IX_fact_order_purchase_date
ON dbo.fact_order
(
    purchase_date_key
)
INCLUDE
(
    order_id,
    customer_key,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date
);
GO

/*
   Supports:
       order-status filtering and condition analysis.
*/
CREATE NONCLUSTERED INDEX IX_fact_order_status
ON dbo.fact_order
(
    order_status
)
INCLUDE
(
    order_id,
    customer_key,
    purchase_date_key,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date
);
GO


/* ================================================================
   03. FACT ORDER ITEM INDEXES
   ================================================================ */

/*
   Supports product/category performance and product joins.
*/
CREATE NONCLUSTERED INDEX IX_fact_order_item_product
ON dbo.fact_order_item
(
    product_key
)
INCLUDE
(
    order_id,
    seller_key,
    price,
    freight_value,
    item_gross_value
);
GO

/*
   Supports seller performance.
*/
CREATE NONCLUSTERED INDEX IX_fact_order_item_seller
ON dbo.fact_order_item
(
    seller_key
)
INCLUDE
(
    order_id,
    product_key,
    price,
    freight_value,
    item_gross_value
);
GO

/*
   Supports shipping-limit date analysis.
*/
CREATE NONCLUSTERED INDEX IX_fact_order_item_shipping_date
ON dbo.fact_order_item
(
    shipping_limit_date
)
INCLUDE
(
    order_id,
    product_key,
    seller_key,
    price,
    freight_value
);
GO


/* ================================================================
   04. FACT PAYMENT INDEXES
   ================================================================ */

/*
   payment_type is frequently grouped in payment reporting.
*/
CREATE NONCLUSTERED INDEX IX_fact_payment_type
ON dbo.fact_payment
(
    payment_type
)
INCLUDE
(
    order_id,
    payment_installments,
    payment_value
);
GO


/* ================================================================
   05. FACT REVIEW INDEXES
   ================================================================ */

CREATE NONCLUSTERED INDEX IX_fact_review_score
ON dbo.fact_review
(
    review_score
)
INCLUDE
(
    order_id,
    review_creation_date,
    review_answer_timestamp
);
GO

CREATE NONCLUSTERED INDEX IX_fact_review_creation_date
ON dbo.fact_review
(
    review_creation_date
)
INCLUDE
(
    order_id,
    review_score,
    review_answer_timestamp
);
GO


/* ================================================================
   06. DIMENSION INDEXES
   ================================================================ */

/*
   State-level customer analysis.
*/
CREATE NONCLUSTERED INDEX IX_dim_customer_state
ON dbo.dim_customer
(
    customer_state
)
INCLUDE
(
    customer_id,
    customer_unique_id,
    customer_city,
    customer_zip_code_prefix
);
GO

/*
   Customer-level repeat behavior.
*/
CREATE NONCLUSTERED INDEX IX_dim_customer_unique_id
ON dbo.dim_customer
(
    customer_unique_id
)
INCLUDE
(
    customer_id,
    customer_state,
    customer_city
);
GO

/*
   Category performance.
*/
CREATE NONCLUSTERED INDEX IX_dim_product_category
ON dbo.dim_product
(
    category_key
)
INCLUDE
(
    product_id,
    product_category_name,
    product_category_name_english
);
GO

/*
   Search/reporting by English category name.
*/
CREATE NONCLUSTERED INDEX IX_dim_product_category_english
ON dbo.dim_product
(
    product_category_name_english
)
INCLUDE
(
    product_id,
    category_key,
    product_category_name
);
GO

/*
   Seller state analysis.
*/
CREATE NONCLUSTERED INDEX IX_dim_seller_state
ON dbo.dim_seller
(
    seller_state
)
INCLUDE
(
    seller_id,
    seller_city,
    seller_zip_code_prefix
);
GO

/*
   Geolocation ZIP lookups.
*/
CREATE NONCLUSTERED INDEX IX_dim_geolocation_zip
ON dbo.dim_geolocation
(
    geolocation_zip_code_prefix
)
INCLUDE
(
    avg_latitude,
    avg_longitude,
    geolocation_city,
    geolocation_state
);
GO

/*
   Date dimension:
   supports year/month grouping and filtering.
*/
CREATE NONCLUSTERED INDEX IX_dim_date_year_month
ON dbo.dim_date
(
    calendar_year,
    calendar_month
)
INCLUDE
(
    date_key,
    full_date,
    calendar_quarter,
    month_name,
    is_weekend
);
GO


/* ================================================================
   07. CONDITION TABLE INDEXES
   ================================================================ */

CREATE NONCLUSTERED INDEX IX_cond_order_status
ON dbo.cond_order
(
    order_status
)
INCLUDE
(
    order_id,
    is_delivered,
    is_cancelled,
    is_delivery_late,
    delivery_days,
    delivery_delay_days
);
GO

CREATE NONCLUSTERED INDEX IX_cond_order_delivery_late
ON dbo.cond_order
(
    is_delivery_late
)
INCLUDE
(
    order_id,
    is_delivered,
    delivery_days,
    delivery_delay_days
);
GO

CREATE NONCLUSTERED INDEX IX_cond_order_item_band
ON dbo.cond_order_item
(
    item_value_band,
    freight_band
)
INCLUDE
(
    order_id,
    order_item_id,
    freight_ratio
);
GO

CREATE NONCLUSTERED INDEX IX_cond_customer_activity
ON dbo.cond_customer
(
    customer_activity_band
)
INCLUDE
(
    customer_id,
    order_count,
    delivered_order_count,
    cancelled_order_count,
    total_item_value,
    total_freight_value
);
GO

CREATE NONCLUSTERED INDEX IX_cond_seller_activity
ON dbo.cond_seller
(
    seller_activity_band
)
INCLUDE
(
    seller_id,
    item_count,
    order_count,
    total_item_value,
    total_freight_value,
    average_item_price
);
GO

CREATE NONCLUSTERED INDEX IX_cond_product_bands
ON dbo.cond_product
(
    product_size_band,
    product_weight_band
)
INCLUDE
(
    product_id,
    photo_band,
    description_length_band
);
GO

CREATE NONCLUSTERED INDEX IX_cond_payment_type
ON dbo.cond_payment
(
    payment_type
)
INCLUDE
(
    order_id,
    payment_installments,
    payment_value,
    payment_value_band,
    installment_band,
    is_high_installment
);
GO

CREATE NONCLUSTERED INDEX IX_cond_review_band
ON dbo.cond_review
(
    review_band
)
INCLUDE
(
    review_id,
    order_id,
    review_score,
    has_comment_message,
    answer_delay_days
);
GO


/* ================================================================
   08. INDEX INVENTORY
   ================================================================ */

PRINT '===============================================================';
PRINT 'INDEX INVENTORY';
PRINT '===============================================================';

SELECT
    s.name AS schema_name,
    o.name AS table_name,
    i.name AS index_name,
    i.type_desc AS index_type,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON i.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE s.name = 'dbo'
  AND o.type = 'U'
  AND i.name IS NOT NULL
ORDER BY
    o.name,
    i.index_id;
GO


/* ================================================================
   09. INDEXED COLUMN CHECK
   ================================================================ */

PRINT '===============================================================';
PRINT 'PROJECT INDEX COLUMN CHECK';
PRINT '===============================================================';

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    ic.key_ordinal,
    ic.is_included_column,
    COL_NAME(ic.object_id, ic.column_id) AS column_name
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
   AND i.index_id = ic.index_id
WHERE i.name IN
(
    N'IX_fact_order_customer_date',
    N'IX_fact_order_purchase_date',
    N'IX_fact_order_status',
    N'IX_fact_order_item_product',
    N'IX_fact_order_item_seller',
    N'IX_fact_order_item_shipping_date',
    N'IX_fact_payment_type',
    N'IX_fact_review_score',
    N'IX_fact_review_creation_date',
    N'IX_dim_customer_state',
    N'IX_dim_customer_unique_id',
    N'IX_dim_product_category',
    N'IX_dim_product_category_english',
    N'IX_dim_seller_state',
    N'IX_dim_geolocation_zip',
    N'IX_dim_date_year_month',
    N'IX_cond_order_status',
    N'IX_cond_order_delivery_late',
    N'IX_cond_order_item_band',
    N'IX_cond_customer_activity',
    N'IX_cond_seller_activity',
    N'IX_cond_product_bands',
    N'IX_cond_payment_type',
    N'IX_cond_review_band'
)
ORDER BY
    table_name,
    index_name,
    ic.is_included_column,
    ic.key_ordinal;
GO


/* ================================================================
   10. BASIC INDEX VALIDATION
   ================================================================ */

DECLARE @ExpectedIndexes TABLE
(
    index_name SYSNAME NOT NULL
);

INSERT INTO @ExpectedIndexes(index_name)
VALUES
(N'IX_fact_order_customer_date'),
(N'IX_fact_order_purchase_date'),
(N'IX_fact_order_status'),
(N'IX_fact_order_item_product'),
(N'IX_fact_order_item_seller'),
(N'IX_fact_order_item_shipping_date'),
(N'IX_fact_payment_type'),
(N'IX_fact_review_score'),
(N'IX_fact_review_creation_date'),
(N'IX_dim_customer_state'),
(N'IX_dim_customer_unique_id'),
(N'IX_dim_product_category'),
(N'IX_dim_product_category_english'),
(N'IX_dim_seller_state'),
(N'IX_dim_geolocation_zip'),
(N'IX_dim_date_year_month'),
(N'IX_cond_order_status'),
(N'IX_cond_order_delivery_late'),
(N'IX_cond_order_item_band'),
(N'IX_cond_customer_activity'),
(N'IX_cond_seller_activity'),
(N'IX_cond_product_bands'),
(N'IX_cond_payment_type'),
(N'IX_cond_review_band');

SELECT
    e.index_name,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM sys.indexes AS i
            INNER JOIN sys.objects AS o
                ON i.object_id = o.object_id
            WHERE o.schema_id = SCHEMA_ID('dbo')
              AND i.name = e.index_name
        )
        THEN 'PRESENT'
        ELSE 'MISSING'
    END AS validation_status
FROM @ExpectedIndexes AS e
ORDER BY e.index_name;
GO


/* ================================================================
   11. FINISH
   ================================================================ */

PRINT '===============================================================';
PRINT '06 - INDEXING COMPLETE';
PRINT '===============================================================';
PRINT 'Indexes were added only to tables, not reporting views.';
PRINT 'Primary-key and unique-constraint indexes were not duplicated.';
PRINT 'Next layer: 07_BUSINESS_ANALYSIS.sql';
PRINT '===============================================================';
GO
