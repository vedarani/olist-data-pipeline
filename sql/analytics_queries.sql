-- ═══════ ADVANCED ANALYTICS QUERIES FOR OLIST STAR SCHEMA ═══════
-- These queries demonstrate advanced SQL techniques for business analytics
-- Compatible with Snowflake ANSI SQL

-- ═══════ QUERY 1: REVENUE AND PERFORMANCE BY STATE ═══════
-- Business Question: Which Brazilian states generate the most revenue and how do they perform?
-- SQL Technique: Multi-table join with aggregation and filtering
SELECT 
    dc.customer_state,
    SUM(fo.total_value) AS total_revenue,
    COUNT(DISTINCT fo.order_id) AS order_count,
    COUNT(DISTINCT fo.customer_id) AS customer_count,
    AVG(fo.total_value) AS avg_order_value,
    AVG(fo.review_score) AS avg_review_score
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
WHERE fo.order_status = 'delivered'
GROUP BY dc.customer_state
ORDER BY total_revenue DESC
LIMIT 10;

-- ═══════ QUERY 2: TOP PRODUCT CATEGORY PER STATE ═══════
-- Business Question: What is the #1 product category in each Brazilian state?
-- SQL Technique: ROW_NUMBER window function with PARTITION BY for ranking
WITH state_category_revenue AS (
    SELECT 
        dc.customer_state,
        dp.product_category_en,
        SUM(fo.total_value) AS category_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY dc.customer_state 
            ORDER BY SUM(fo.total_value) DESC
        ) AS category_rank
    FROM fact_orders fo
    JOIN dim_customer dc ON fo.customer_id = dc.customer_id
    JOIN dim_product dp ON fo.product_id = dp.product_id
    WHERE fo.order_status = 'delivered' 
        AND dp.product_category_en IS NOT NULL
    GROUP BY dc.customer_state, dp.product_category_en
)
SELECT 
    customer_state,
    product_category_en,
    category_revenue
FROM state_category_revenue
WHERE category_rank = 1
ORDER BY category_revenue DESC;

-- ═══════ QUERY 3: MONTH-OVER-MONTH REVENUE GROWTH ═══════
-- Business Question: How is revenue growing month over month?
-- SQL Technique: LAG window function for period-over-period analysis
WITH monthly_revenue AS (
    SELECT 
        dd.year,
        dd.month,
        SUM(fo.total_value) AS monthly_revenue
    FROM fact_orders fo
    JOIN dim_date dd ON fo.date_id = dd.date_id
    WHERE fo.order_status = 'delivered'
    GROUP BY dd.year, dd.month
),
revenue_growth AS (
    SELECT 
        year,
        month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY year, month) AS previous_month_revenue,
        LAG(monthly_revenue, 1) OVER (ORDER BY year, month) AS prev_revenue
    FROM monthly_revenue
)
SELECT 
    year,
    month,
    monthly_revenue,
    previous_month_revenue,
    CASE 
        WHEN previous_month_revenue IS NULL OR previous_month_revenue = 0 THEN NULL
        ELSE ROUND((monthly_revenue - previous_month_revenue) / previous_month_revenue * 100, 2)
    END AS growth_pct
FROM revenue_growth
ORDER BY year, month;

-- ═══════ QUERY 4: CUSTOMER LIFETIME VALUE SEGMENTATION ═══════
-- Business Question: How do customers segment by their total spending?
-- SQL Technique: CASE WHEN for business logic segmentation
WITH customer_ltv AS (
    SELECT 
        fo.customer_id,
        SUM(fo.total_value) AS total_spend,
        COUNT(DISTINCT fo.order_id) AS order_count
    FROM fact_orders fo
    WHERE fo.order_status = 'delivered'
    GROUP BY fo.customer_id
),
customer_segments AS (
    SELECT 
        customer_id,
        total_spend,
        order_count,
        CASE 
            WHEN total_spend > 2000 THEN 'VIP'
            WHEN total_spend > 500 THEN 'Premium'
            WHEN total_spend > 100 THEN 'Regular'
            ELSE 'Casual'
        END AS customer_segment
    FROM customer_ltv
)
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    SUM(total_spend) AS segment_revenue,
    AVG(total_spend) AS avg_customer_value,
    AVG(order_count) AS avg_orders_per_customer
FROM customer_segments
GROUP BY customer_segment
ORDER BY segment_revenue DESC;

-- ═══════ QUERY 5: SELLER PERFORMANCE SCORECARD ═══════
-- Business Question: Who are the top-performing sellers by revenue?
-- SQL Technique: RANK window function with HAVING clause for filtering
WITH seller_performance AS (
    SELECT 
        fo.seller_id,
        ds.seller_state,
        SUM(fo.total_value) AS total_revenue,
        COUNT(DISTINCT fo.order_id) AS order_count,
        AVG(fo.review_score) AS avg_review_score,
        AVG(fo.delivery_days) AS avg_delivery_days,
        RANK() OVER (ORDER BY SUM(fo.total_value) DESC) AS revenue_rank
    FROM fact_orders fo
    JOIN dim_seller ds ON fo.seller_id = ds.seller_id
    WHERE fo.order_status = 'delivered'
        AND fo.review_score IS NOT NULL
    GROUP BY fo.seller_id, ds.seller_state
)
SELECT 
    seller_id,
    seller_state,
    total_revenue,
    order_count,
    ROUND(avg_review_score, 2) AS avg_review_score,
    ROUND(avg_delivery_days, 1) AS avg_delivery_days,
    revenue_rank
FROM seller_performance
WHERE order_count >= 100  -- HAVING clause equivalent
ORDER BY revenue_rank
LIMIT 20;

-- ═══════ QUERY 6: CUSTOMER COHORT RETENTION ANALYSIS ═══════
-- Business Question: How well do we retain customers over time?
-- SQL Technique: CTE with DATE_TRUNC for cohort analysis
WITH customer_first_order AS (
    SELECT 
        fo.customer_id,
        MIN(fo.order_purchase_timestamp) AS first_order_date
    FROM fact_orders fo
    WHERE fo.order_status = 'delivered'
    GROUP BY fo.customer_id
),
customer_cohorts AS (
    SELECT 
        cfo.customer_id,
        cfo.first_order_date,
        DATE_TRUNC('month', cfo.first_order_date) AS cohort_month,
        fo.order_purchase_timestamp,
        DATE_TRUNC('month', fo.order_purchase_timestamp) AS order_month,
        DATEDIFF('month', cfo.first_order_date, fo.order_purchase_timestamp) AS months_since_first_order
    FROM customer_first_order cfo
    JOIN fact_orders fo ON cfo.customer_id = fo.customer_id
    WHERE fo.order_status = 'delivered'
),
cohort_retention AS (
    SELECT 
        cohort_month,
        months_since_first_order,
        COUNT(DISTINCT customer_id) AS customer_count
    FROM customer_cohorts
    WHERE months_since_first_order >= 0
    GROUP BY cohort_month, months_since_first_order
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        customer_count AS cohort_size
    FROM cohort_retention
    WHERE months_since_first_order = 0
)
SELECT 
    cr.cohort_month,
    cs.cohort_size,
    cr.months_since_first_order,
    cr.customer_count,
    ROUND(cr.customer_count * 100.0 / cs.cohort_size, 2) AS retention_rate_pct
FROM cohort_retention cr
JOIN cohort_sizes cs ON cr.cohort_month = cs.cohort_month
ORDER BY cr.cohort_month, cr.months_since_first_order;
