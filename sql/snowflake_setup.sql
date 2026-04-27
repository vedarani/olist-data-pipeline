-- ═══════ SNOWFLAKE STAR SCHEMA SETUP FOR OLIST DATA WAREHOUSE ═══════

-- Create ETL Warehouse
CREATE OR REPLACE WAREHOUSE etl_wh 
WITH 
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create Database and Schema
CREATE OR REPLACE DATABASE olist_dw;
USE DATABASE olist_dw;

CREATE OR REPLACE SCHEMA analytics;
USE SCHEMA analytics;
USE WAREHOUSE etl_wh;

-- ═══════ DIMENSION TABLES ═══════

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

-- ═══════ FACT TABLE ═══════

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

-- ═══════ VERIFICATION QUERY ═══════
-- Run this AFTER loading data to verify the star schema works
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
