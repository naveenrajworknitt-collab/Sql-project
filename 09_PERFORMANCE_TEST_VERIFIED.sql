/* ================================================================
   OLIST E-COMMERCE PROJECT
   09_PERFORMANCE_TEST_VERIFIED.sql
   SQL Server / SSMS

   Purpose:
   Measure index usage, table size, and representative query performance
   using only columns verified from the current project schema.

   This script is READ-ONLY.
   It does not CREATE / DROP / ALTER indexes or modify data.

   Run in SSMS. For the query sections, STATISTICS IO/TIME output will
   appear in the Messages tab.
   ================================================================ */

USE [Sql_project];
GO
SET NOCOUNT ON;
GO

PRINT '===============================================================';
PRINT '09 - PERFORMANCE TEST START';
PRINT '===============================================================';


/* ================================================================
   A. DATABASE INFORMATION
   ================================================================ */

PRINT 'A - DATABASE INFORMATION';

SELECT
    DB_NAME() AS database_name,
    @@SERVERNAME AS server_name,
    SYSDATETIME() AS test_time;
GO


/* ================================================================
   B. PROJECT INDEX INVENTORY
   ================================================================ */

PRINT 'B - PROJECT INDEX INVENTORY';

SELECT
    s.name AS schema_name,
    o.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    i.is_disabled,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint
FROM sys.indexes AS i
INNER JOIN sys.objects AS o
    ON i.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE s.name = N'dbo'
  AND o.type = N'U'
  AND (
        i.name LIKE N'IX[_]fact[_]%'
        OR i.name LIKE N'IX[_]dim[_]%'
        OR i.name LIKE N'IX[_]cond[_]%'
      )
ORDER BY
    o.name,
    i.name;
GO


/* ================================================================
   C. INDEX USAGE
   ================================================================ */

PRINT 'C - INDEX USAGE';

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    ISNULL(us.user_seeks, 0) AS user_seeks,
    ISNULL(us.user_scans, 0) AS user_scans,
    ISNULL(us.user_lookups, 0) AS user_lookups,
    ISNULL(us.user_updates, 0) AS user_updates,
    us.last_user_seek,
    us.last_user_scan,
    us.last_user_lookup
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS us
    ON us.database_id = DB_ID()
   AND us.object_id = i.object_id
   AND us.index_id = i.index_id
WHERE OBJECT_SCHEMA_NAME(i.object_id) = N'dbo'
  AND (
        i.name LIKE N'IX[_]fact[_]%'
        OR i.name LIKE N'IX[_]dim[_]%'
        OR i.name LIKE N'IX[_]cond[_]%'
      )
ORDER BY
    ISNULL(us.user_seeks, 0) DESC,
    table_name,
    index_name;
GO


/* ================================================================
   D. TABLE SIZE PROFILE
   ================================================================ */

PRINT 'D - TABLE SIZE PROFILE';

SELECT
    t.name AS table_name,
    SUM(p.rows) AS row_count,
    CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2))
        AS total_size_mb,
    CAST(SUM(a.used_pages) * 8.0 / 1024 AS DECIMAL(18,2))
        AS used_size_mb
FROM sys.tables AS t
INNER JOIN sys.indexes AS i
    ON t.object_id = i.object_id
INNER JOIN sys.partitions AS p
    ON i.object_id = p.object_id
   AND i.index_id = p.index_id
INNER JOIN sys.allocation_units AS a
    ON p.partition_id = a.container_id
WHERE t.schema_id = SCHEMA_ID(N'dbo')
GROUP BY t.name
ORDER BY total_size_mb DESC;
GO


/* ================================================================
   E. VERIFIED FACT_ORDER_ITEM PERFORMANCE
   Verified columns:
     order_id
     product_key
     seller_key
     price
     freight_value
     item_gross_value
   ================================================================ */

PRINT 'E - FACT_ORDER_ITEM AGGREGATION';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    product_key,
    COUNT_BIG(*) AS item_count,
    SUM(price) AS total_price,
    SUM(freight_value) AS total_freight,
    SUM(item_gross_value) AS total_item_gross_value,
    AVG(price) AS average_price
FROM dbo.fact_order_item
GROUP BY product_key
ORDER BY total_item_gross_value DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   F. VERIFIED CATEGORY PERFORMANCE VIEW
   Verified columns:
     category_key
     product_category_name
     product_category_name_english
     item_count
     order_count
     product_count
     item_value
     freight_value
     average_item_price
   ================================================================ */

PRINT 'F - CATEGORY REPORTING VIEW';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    category_key,
    product_category_name,
    product_category_name_english,
    item_count,
    order_count,
    product_count,
    item_value,
    freight_value,
    average_item_price
FROM dbo.vw_category_performance
ORDER BY item_value DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   G. VERIFIED ORDER ITEM REPORT VIEW
   ================================================================ */

PRINT 'G - ORDER ITEM REPORT VIEW';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    category_key,
    product_category_name,
    product_category_name_english,
    COUNT_BIG(*) AS row_count,
    SUM(item_gross_value) AS item_gross_value,
    SUM(freight_value) AS freight_value,
    AVG(price) AS average_price
FROM dbo.vw_order_item_report
GROUP BY
    category_key,
    product_category_name,
    product_category_name_english
ORDER BY item_gross_value DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   H. VERIFIED PAYMENT FACT PERFORMANCE
   ================================================================ */

PRINT 'H - FACT_PAYMENT AGGREGATION';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    payment_type,
    COUNT_BIG(*) AS payment_count,
    COUNT_BIG(DISTINCT order_id) AS order_count,
    SUM(payment_value) AS total_payment_value,
    AVG(payment_value) AS average_payment_value
FROM dbo.fact_payment
GROUP BY payment_type
ORDER BY total_payment_value DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   I. VERIFIED PAYMENT REPORT VIEW
   ================================================================ */

PRINT 'I - PAYMENT REPORT VIEW';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    payment_type,
    COUNT_BIG(*) AS payment_count,
    COUNT_BIG(DISTINCT order_id) AS order_count,
    SUM(payment_value) AS total_payment_value
FROM dbo.vw_payment_report
GROUP BY payment_type
ORDER BY total_payment_value DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   J. VERIFIED REVIEW REPORT VIEW
   ================================================================ */

PRINT 'J - REVIEW REPORT VIEW';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT
    review_score,
    COUNT_BIG(*) AS review_count,
    SUM(CASE WHEN is_positive_review = 1 THEN 1 ELSE 0 END)
        AS positive_count,
    SUM(CASE WHEN is_neutral_review = 1 THEN 1 ELSE 0 END)
        AS neutral_count,
    SUM(CASE WHEN is_negative_review = 1 THEN 1 ELSE 0 END)
        AS negative_count
FROM dbo.vw_review_report
GROUP BY review_score
ORDER BY review_score;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


/* ================================================================
   K. DATE / ORDER PERFORMANCE TEST
   Uses dynamic metadata check before executing.
   This prevents an invalid-column failure if the order timestamp
   column differs in the imported schema.
   ================================================================ */

PRINT 'K - ORDER DATE COLUMN CHECK';

SELECT
    c.name AS column_name,
    ty.name AS data_type
FROM sys.columns AS c
INNER JOIN sys.types AS ty
    ON c.user_type_id = ty.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.fact_order')
  AND (
       c.name LIKE N'%purchase%'
       OR c.name LIKE N'%timestamp%'
       OR c.name LIKE N'%date%'
      )
ORDER BY c.column_id;
GO


/* ================================================================
   L. MISSING INDEX DMV
   Suggestions only. Do not create indexes automatically.
   ================================================================ */

PRINT 'L - MISSING INDEX SUGGESTIONS';

SELECT TOP (30)
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    migs.user_seeks,
    migs.user_scans,
    mid.statement AS table_statement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON mig.index_group_handle = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY
    migs.avg_user_impact DESC,
    migs.user_seeks DESC;
GO


/* ================================================================
   M. INDEX FRAGMENTATION
   ================================================================ */

PRINT 'M - INDEX FRAGMENTATION';

SELECT
    OBJECT_SCHEMA_NAME(ps.object_id) AS schema_name,
    OBJECT_NAME(ps.object_id) AS table_name,
    i.name AS index_name,
    ps.index_type_desc,
    ps.page_count,
    ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats
(
    DB_ID(),
    NULL,
    NULL,
    NULL,
    'LIMITED'
) AS ps
INNER JOIN sys.indexes AS i
    ON ps.object_id = i.object_id
   AND ps.index_id = i.index_id
WHERE OBJECT_SCHEMA_NAME(ps.object_id) = N'dbo'
  AND ps.page_count >= 100
ORDER BY
    ps.avg_fragmentation_in_percent DESC;
GO


/* ================================================================
   N. QUERY STORE STATUS
   ================================================================ */

PRINT 'N - QUERY STORE STATUS';

SELECT
    actual_state_desc,
    desired_state_desc,
    readonly_reason
FROM sys.database_query_store_options;
GO


/* ================================================================
   O. FINAL
   ================================================================ */

PRINT '===============================================================';
PRINT '09 - PERFORMANCE TEST COMPLETE';
PRINT '===============================================================';
PRINT 'Compare STATISTICS IO/TIME for sections E-J.';
PRINT 'Review missing-index suggestions in section L.';
PRINT 'Do not automatically implement DMV suggestions.';
PRINT 'Next layer: 10_POWER_BI_DATASET.sql';
PRINT '===============================================================';
GO
