-- ═══════ AWS REDSHIFT SERVERLESS SETUP FOR OLIST DATA WAREHOUSE ═══════
-- 
-- Design Choices:
-- - DISTSTYLE ALL for dimension tables: Replicates dimension data to all compute nodes
--   for optimal join performance with fact table
-- - DISTKEY(customer_id) for fact_orders: Distributes data by customer_id 
--   to avoid data skew and optimize customer-centric queries
-- - SORTKEY(year, month) for fact_orders: Optimizes time-series queries 
--   and partition pruning for date-based analysis
-- - VARCHAR(50) for IDs: Balances storage efficiency with data length
-- - VARCHAR(100) for city/text: Accommodates longer names while maintaining performance
-- - FLOAT for monetary values: Supports decimal precision for financial calculations
-- - INT for counts/dates: Optimized storage and performance
-- - TIMESTAMP for temporal data: Native Redshift temporal type with timezone support

-- ═══════ DIMENSION TABLES (DISTSTYLE ALL) ═══════

-- Customer Dimension
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
) DISTSTYLE ALL;

-- Product Dimension
CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_pt VARCHAR(100),
    product_category_en VARCHAR(100),
    product_weight_g FLOAT,
    product_length_cm FLOAT,
    product_height_cm FLOAT,
    product_width_cm FLOAT,
    product_photos_qty INT
) DISTSTYLE ALL;

-- Seller Dimension
CREATE TABLE dim_seller (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
) DISTSTYLE ALL;

-- Date Dimension
CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    day INT,
    quarter INT,
    weekday INT,
    week_of_year INT
) DISTSTYLE ALL;

-- ═══════ FACT TABLE ═══════

-- Orders Fact Table
CREATE TABLE fact_orders (
    order_id VARCHAR(50),
    order_item_id INT,
    customer_id VARCHAR(50),
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    date_id INT,
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    price FLOAT,
    freight_value FLOAT,
    total_value FLOAT,
    payment_type VARCHAR(50),
    total_payment_value FLOAT,
    total_installments INT,
    review_score FLOAT,
    delivery_days INT,
    year INT,
    month INT
) DISTSTYLE KEY DISTKEY(customer_id) SORTKEY(year, month);

-- ═══════ COPY COMMANDS ═══════

-- Copy Customer Dimension
COPY dim_customer
FROM 's3://olist-pipeline-vedar-2026/processed/dim_customer/'
IAM_ROLE 'arn:aws:iam::196403805229:role/RedshiftS3Role'
FORMAT AS PARQUET;

-- Copy Product Dimension
COPY dim_product
FROM 's3://olist-pipeline-vedar-2026/processed/dim_product/'
IAM_ROLE 'arn:aws:iam::196403805229:role/RedshiftS3Role'
FORMAT AS PARQUET;

-- Copy Seller Dimension
COPY dim_seller
FROM 's3://olist-pipeline-vedar-2026/processed/dim_seller/'
IAM_ROLE 'arn:aws:iam::196403805229:role/RedshiftS3Role'
FORMAT AS PARQUET;

-- Copy Date Dimension
COPY dim_date
FROM 's3://olist-pipeline-vedar-2026/processed/dim_date/'
IAM_ROLE 'arn:aws:iam::196403805229:role/RedshiftS3Role'
FORMAT AS PARQUET;

-- Copy Orders Fact Table
COPY fact_orders
FROM 's3://olist-pipeline-vedar-2026/processed/fact_orders/'
IAM_ROLE 'arn:aws:iam::196403805229:role/RedshiftS3Role'
FORMAT AS PARQUET;

-- ═══════ VERIFICATION QUERIES ═══════

-- Query 1: Row counts per table
SELECT 
    'dim_customer' as table_name, COUNT(*) as row_count FROM dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders
ORDER BY table_name;

-- Query 2: Revenue by Brazilian State (Top 10)
SELECT 
    dc.customer_state,
    SUM(fo.total_value) AS total_revenue,
    COUNT(DISTINCT fo.order_id) AS order_count,
    AVG(fo.total_value) AS avg_order_value,
    AVG(fo.review_score) AS avg_review_score
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
WHERE fo.order_status = 'delivered'
GROUP BY dc.customer_state
ORDER BY total_revenue DESC
LIMIT 10;
