-- ═══════════════════════════════════════════════════════════════════════
-- SNOWFLAKE STAR SCHEMA SETUP — Olist E-Commerce Data Warehouse
-- Loads processed star schema from S3 external stage into Snowflake
-- ═══════════════════════════════════════════════════════════════════════

-- ═══════ 1. WAREHOUSE, DATABASE, SCHEMA ═══════

CREATE OR REPLACE WAREHOUSE etl_wh
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE OR REPLACE DATABASE olist_dw;
USE DATABASE olist_dw;

CREATE OR REPLACE SCHEMA analytics;
USE SCHEMA analytics;
USE WAREHOUSE etl_wh;

-- ═══════ 2. STAR SCHEMA TABLES ═══════

-- Customer Dimension
CREATE OR REPLACE TABLE dim_customer (
    customer_id STRING PRIMARY KEY,
    customer_unique_id STRING,
    customer_zip_code_prefix STRING,
    customer_city STRING,
    customer_state STRING
);

-- Product Dimension
CREATE OR REPLACE TABLE dim_product (
    product_id STRING PRIMARY KEY,
    product_category_pt STRING,
    product_category_en STRING,
    product_weight_g FLOAT,
    product_length_cm FLOAT,
    product_height_cm FLOAT,
    product_width_cm FLOAT,
    product_photos_qty INT
);

-- Seller Dimension
CREATE OR REPLACE TABLE dim_seller (
    seller_id STRING PRIMARY KEY,
    seller_zip_code_prefix STRING,
    seller_city STRING,
    seller_state STRING
);

-- Date Dimension
CREATE OR REPLACE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    day INT,
    quarter INT,
    weekday INT,
    week_of_year INT
);

-- Orders Fact Table
CREATE OR REPLACE TABLE fact_orders (
    order_id STRING,
    order_item_id INT,
    customer_id STRING,
    product_id STRING,
    seller_id STRING,
    date_id INT,
    order_status STRING,
    order_purchase_timestamp TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    price FLOAT,
    freight_value FLOAT,
    total_value FLOAT,
    payment_type STRING,
    total_payment_value FLOAT,
    total_installments INT,
    review_score FLOAT,
    delivery_days INT,
    year INT,
    month INT
);

-- ═══════ 3. EXTERNAL S3 STAGE ═══════
-- Production-grade pattern: load data directly from S3 into Snowflake.
-- In production, replace inline credentials with a Storage Integration
-- (uses IAM role trust relationship, no keys stored in Snowflake).

CREATE OR REPLACE STAGE s3_csv_stage
    URL = 's3://olist-pipeline-vedar-2026/csv_for_snowflake/'
    CREDENTIALS = (
        AWS_KEY_ID = '<REDACTED_FOR_GIT>'
        AWS_SECRET_KEY = '<REDACTED_FOR_GIT>'
    )
    FILE_FORMAT = (
        TYPE = 'CSV'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        NULL_IF = ('NULL', 'null', '')
        EMPTY_FIELD_AS_NULL = TRUE
    );

-- Verify stage can see the files
LIST @s3_csv_stage;

-- ═══════ 4. LOAD DATA — COPY INTO from S3 stage ═══════
-- Order matters: dimensions before fact (referential integrity, even if not enforced)

COPY INTO dim_customer
    FROM @s3_csv_stage/dim_customer.csv
    ON_ERROR = 'CONTINUE';

COPY INTO dim_product
    FROM @s3_csv_stage/dim_product.csv
    ON_ERROR = 'CONTINUE';

COPY INTO dim_seller
    FROM @s3_csv_stage/dim_seller.csv
    ON_ERROR = 'CONTINUE';

COPY INTO dim_date
    FROM @s3_csv_stage/dim_date.csv
    ON_ERROR = 'CONTINUE';

COPY INTO fact_orders
    FROM @s3_csv_stage/fact_orders.csv
    ON_ERROR = 'CONTINUE';

-- ═══════ 5. VERIFICATION QUERIES ═══════

-- Row counts per table
SELECT 'dim_customer' AS tbl, COUNT(*) AS row_count FROM dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_orders', COUNT(*) FROM fact_orders;

-- Expected row counts:
--   dim_customer: 99,441
--   dim_product:  32,951
--   dim_seller:    3,095
--   dim_date:        634
--   fact_orders: 112,650

-- Revenue by Brazilian state (validates the join works)
SELECT
    c.customer_state,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(DISTINCT f.customer_id) AS customers,
    ROUND(SUM(f.total_value), 2) AS revenue,
    ROUND(AVG(f.total_value), 2) AS avg_order_value,
    ROUND(AVG(f.review_score), 2) AS avg_review_score
FROM fact_orders f
JOIN dim_customer c ON f.customer_id = c.customer_id
WHERE f.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- Expected: São Paulo (SP) at the top with the most revenue