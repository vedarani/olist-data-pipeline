# 📊 Snowflake CSV Upload Guide

## 🔍 Issue Identified
All Snowflake tables have 0 rows - CSV data needs to be loaded properly.

## 📋 Step-by-Step Upload Instructions

### **1. Navigate to Snowflake Interface**
1. Log into Snowflake web interface
2. Click **Databases** → **olist_dw** → **analytics**

### **2. Upload in Correct Order**

#### **A) dim_customer** (FIRST)
1. Click **dim_customer** table
2. Click **Load Data** button
3. **File Selection:**
   - Choose `output_csv/dim_customer.csv`
   - File Format: **CSV**
   - Header: **Skip first row** (checked)
4. **Column Mapping** (auto-detect should work):
   - `customer_id` → customer_id
   - `customer_unique_id` → customer_unique_id
   - `customer_zip_code_prefix` → customer_zip_code_prefix
   - `customer_city` → customer_city
   - `customer_state` → customer_state
5. Click **Load**

#### **B) dim_product**
1. Click **dim_product** table
2. Click **Load Data** → upload `output_csv/dim_product.csv`
3. **Column Mapping:**
   - `product_id` → product_id
   - `product_category_pt` → product_category_pt
   - `product_category_en` → product_category_en
   - `product_weight_g` → product_weight_g
   - `product_length_cm` → product_length_cm
   - `product_height_cm` → product_height_cm
   - `product_width_cm` → product_width_cm
   - `product_photos_qty` → product_photos_qty
4. Click **Load**

#### **C) dim_seller**
1. Click **dim_seller** table
2. Click **Load Data** → upload `output_csv/dim_seller.csv`
3. **Column Mapping:**
   - `seller_id` → seller_id
   - `seller_zip_code_prefix` → seller_zip_code_prefix
   - `seller_city` → seller_city
   - `seller_state` → seller_state
4. Click **Load**

#### **D) dim_date**
1. Click **dim_date** table
2. Click **Load Data** → upload `output_csv/dim_date.csv`
3. **Column Mapping:**
   - `date_id` → date_id
   - `full_date` → full_date
   - `year` → year
   - `month` → month
   - `day` → day
   - `quarter` → quarter
   - `weekday` → weekday
   - `week_of_year` → week_of_year
4. Click **Load**

#### **E) fact_orders** (LAST)
1. Click **fact_orders** table
2. Click **Load Data** → upload `output_csv/fact_orders.csv`
3. **Column Mapping:**
   - `order_id` → order_id
   - `order_item_id` → order_item_id
   - `customer_id` → customer_id
   - `product_id` → product_id
   - `seller_id` → seller_id
   - `date_id` → date_id
   - `order_status` → order_status
   - `order_purchase_timestamp` → order_purchase_timestamp
   - `order_delivered_customer_date` → order_delivered_customer_date
   - `order_estimated_delivery_date` → order_estimated_delivery_date
   - `price` → price
   - `freight_value` → freight_value
   - `total_value` → total_value
   - `payment_type` → payment_type
   - `total_payment_value` → total_payment_value
   - `total_installments` → total_installments
   - `review_score` → review_score
   - `delivery_days` → delivery_days
   - `year` → year
   - `month` → month
4. Click **Load**

## ✅ Verification After Upload

Run this query to confirm data loaded:

```sql
SELECT 'dim_customer' as table_name, COUNT(*) as row_count FROM dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product  
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders;
```

**Expected Results:**
- dim_customer: ~99,441 rows
- dim_product: ~32,951 rows
- dim_seller: ~3,095 rows
- dim_date: ~634 rows
- fact_orders: ~112,650 rows

## 🚨 Common Issues & Fixes

1. **"Column not found" error:** Check CSV headers match table column names exactly
2. **"Data type mismatch":** Ensure numeric columns don't have text values
3. **"File too large":** Snowflake handles large files, but ensure stable internet
4. **"Partial load":** Check for NULL values or invalid dates in CSV

## 📞 If Issues Persist
Run the diagnostic queries in `sql/diagnostic_queries.sql` to identify specific problems.
