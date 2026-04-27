-- ═══════ SNOWFLAKE DIAGNOSTIC QUERIES ═══════
-- Run these to diagnose why the verification query returned no results

-- 1. Check if tables have data
SELECT 'dim_customer' as table_name, COUNT(*) as row_count FROM dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product  
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders;

-- 2. Check order_status values in fact_orders
SELECT order_status, COUNT(*) as count 
FROM fact_orders 
GROUP BY order_status 
ORDER BY count DESC;

-- 3. Check if customer_id values match between tables
SELECT 'fact_orders' as source, COUNT(*) as distinct_customers 
FROM (SELECT DISTINCT customer_id FROM fact_orders)
UNION ALL
SELECT 'dim_customer', COUNT(*) 
FROM (SELECT DISTINCT customer_id FROM dim_customer);

-- 4. Sample data check - first few rows
SELECT 'fact_orders sample:' as info, * FROM fact_orders LIMIT 3;
SELECT 'dim_customer sample:' as info, * FROM dim_customer LIMIT 3;

-- 5. Check for NULL values that might break joins
SELECT 
    COUNT(*) as total_orders,
    COUNT(customer_id) as orders_with_customer_id,
    COUNT(product_id) as orders_with_product_id,
    COUNT(seller_id) as orders_with_seller_id,
    COUNT(date_id) as orders_with_date_id
FROM fact_orders;

-- 6. Simple join test without WHERE clause
SELECT COUNT(*) as joined_records
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id;

-- 7. Alternative verification query (without order_status filter)
SELECT 
    dc.customer_state,
    SUM(fo.total_value) AS total_revenue,
    COUNT(DISTINCT fo.order_id) AS order_count,
    AVG(fo.total_value) AS avg_order_value,
    AVG(fo.review_score) AS avg_review_score
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
GROUP BY dc.customer_state
ORDER BY total_revenue DESC
LIMIT 10;
