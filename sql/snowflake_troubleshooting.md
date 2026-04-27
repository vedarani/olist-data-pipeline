# 🔧 Snowflake Upload Troubleshooting Guide

## 📊 CSV Files Verified ✅
Your CSV files are correctly formatted with proper headers:
- `dim_customer.csv`: customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state
- `fact_orders.csv`: All columns present with proper headers

## 🚨 Common Upload Issues & Solutions

### **Issue 1: File Format Settings**
**Problem:** Snowflake not recognizing CSV format correctly

**Solution:**
1. In Snowflake Load Data interface:
   - File Format: **CSV**
   - Header: **Skip first row** ✅ CHECK THIS BOX
   - Field Delimiter: **Comma (,)**
   - Record Delimiter: **Newline**
   - Escape: **None**
   - Skip Blank Lines: **Checked**

### **Issue 2: Column Mapping Problems**
**Problem:** Columns not mapped correctly

**Solution:**
1. **Don't rely on auto-detection** - manually map each column:
   - Left side: CSV column names (from file headers)
   - Right side: Snowflake table column names
2. **Check exact spelling** - no extra spaces or case differences

### **Issue 3: Data Type Mismatches**
**Problem:** Snowflake rejecting due to data type issues

**Solution:**
1. **For TIMESTAMP columns:** Ensure date format is recognized
2. **For FLOAT columns:** Remove any currency symbols or commas
3. **For INT columns:** Ensure no decimal points

### **Issue 4: File Path Issues**
**Problem:** Wrong file selected or corrupted upload

**Solution:**
1. **Verify file paths:**
   - `C:\Users\vedar\Documents\m-p proj\output_csv\dim_customer.csv`
   - `C:\Users\vedar\Documents\m-p proj\output_csv\fact_orders.csv`
2. **Check file sizes:** Should match what we saw earlier

## 🔍 Step-by-Step Debug Process

### **Step 1: Test with One Table First**
Start with `dim_customer` (smallest, simplest):

1. **Delete existing table:**
   ```sql
   DROP TABLE IF EXISTS dim_customer;
   ```

2. **Re-create table:**
   ```sql
   CREATE TABLE dim_customer (
       customer_id STRING PRIMARY KEY,
       customer_unique_id STRING,
       customer_zip_code_prefix STRING,
       customer_city STRING,
       customer_state STRING
   );
   ```

3. **Upload with careful settings:**
   - File: `dim_customer.csv`
   - Format: CSV
   - Header: Skip first row ✅
   - Manual column mapping required

4. **Verify:**
   ```sql
   SELECT COUNT(*) FROM dim_customer;
   ```

### **Step 2: Check Upload Logs**
In Snowflake, check for any error messages during upload:
1. Go to **History** tab
2. Look for recent **COPY INTO** operations
3. Check for error messages

### **Step 3: Alternative Upload Method**
If Load Data button fails, try SQL approach:

```sql
-- Create stage first
CREATE OR REPLACE TEMPORARY STAGE csv_stage;

-- Upload file to stage (use web interface or SnowSQL)
-- Then run:
COPY INTO dim_customer
FROM @csv_stage
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1)
PATTERN = 'dim_customer.csv';
```

## 📞 Quick Verification Commands

After each upload, run:
```sql
-- Check row count
SELECT COUNT(*) FROM dim_customer;

-- Check sample data
SELECT * FROM dim_customer LIMIT 3;

-- Check for NULL values
SELECT 
    COUNT(*) as total,
    COUNT(customer_id) as with_customer_id,
    COUNT(customer_state) as with_state
FROM dim_customer;
```

## 🎯 Most Likely Fix
The most common issue is **not checking "Skip first row"** or **incorrect column mapping**. 

**Action:** Re-upload `dim_customer.csv` first, ensuring:
1. ✅ Skip first row is checked
2. ✅ Manual column mapping (don't rely on auto-detect)
3. ✅ Verify all 5 columns are mapped correctly

Once `dim_customer` works, repeat for other tables in the same order.
