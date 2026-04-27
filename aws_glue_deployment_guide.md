# 🚀 AWS Glue Deployment Guide

## ✅ Terminal Commands Completed
- ✅ Modified `build_warehouse.py` to set `RUN_IN_GLUE = True`
- ✅ Uploaded script to S3: `s3://olist-pipeline-vedar-2026/scripts/build_warehouse.py`
- ✅ Changed `RUN_IN_GLUE = False` locally (for local runs)

## 🎯 AWS Console Instructions (us-east-2)

### **A) Create IAM Role: GlueRetailRole**

1. **Navigate to IAM Console:**
   - Go to AWS Console → IAM → Roles
   - Click **"Create role"**

2. **Select Trusted Entity:**
   - Choose **"AWS service"**
   - Use case: **"Glue"**
   - Click **Next**

3. **Add Permissions:**
   - Search and add **"AWSGlueServiceRole"**
   - Search and add **"AmazonS3FullAccess"**
   - Click **Next**

4. **Role Details:**
   - Role name: **`GlueRetailRole`**
   - Description: **`Role for Olist Glue ETL jobs and crawlers`**
   - Click **"Create role"**

### **B) Create Glue Database and Crawler**

1. **Navigate to Glue Console:**
   - AWS Console → Glue (in us-east-2)
   - Click **"Databases"** in left navigation

2. **Create Database:**
   - Click **"Add database"**
   - Database name: **`olist_db`**
   - Click **"Create"**

3. **Create Crawler:**
   - Click **"Crawlers"** in left navigation
   - Click **"Create crawler"**
   - Crawler name: **`olist-raw-crawler`**

4. **Crawler Source:**
   - Data source: **"S3"**
   - Connection method: **"Crawl data in S3"**
   - S3 path: **`s3://olist-pipeline-vedar-2026/raw/`**
   - Click **Next**

5. **Include/Exclude Paths:**
   - Keep default (include all)
   - Click **Next**

6. **Crawler Target:**
   - Database: **`olist_db`**
   - Click **Next**

7. **IAM Role:**
   - Select **`GlueRetailRole`**
   - Click **Next**

8. **Schedule:**
   - Schedule: **"On demand"**
   - Click **Next**

9. **Review & Create:**
   - Review all settings
   - Click **"Create crawler"**

10. **Run Crawler:**
    - Select **`olist-raw-crawler`**
    - Click **"Run"**
    - **⏱️ Expect 1-2 minutes to complete**

### **C) Create Glue Job**

1. **Navigate to Glue Jobs:**
   - Click **"Jobs"** in left navigation
   - Click **"Create job"**

2. **Job Properties:**
   - Name: **`olist-etl-job`**
   - Type: **"Spark"**
   - Glue version: **"Glue 4.0"**
   - Click **Next**

3. **Script Details:**
   - Script location: **"Browse S3"**
   - Navigate to: **`s3://olist-pipeline-vedar-2026/scripts/build_warehouse.py`**
   - Click **"Select"**
   - Click **Next**

4. **IAM Role:**
   - Select **`GlueRetailRole`**
   - Click **Next**

5. **Job Details:**
   - Worker type: **"G.1X"**
   - Number of workers: **2**
   - Glue version: **"Glue 4.0"**
   - Click **Next**

6. **Advanced Properties:**
   - Job parameters:
     - Key: **`--S3_BUCKET`**
     - Value: **`olist-pipeline-vedar-2026`**
   - Click **Next**

7. **Review & Create:**
   - Review all settings
   - Click **"Create job"**

### **D) Run Job & Monitor Logs**

1. **Run the Job:**
   - Select **`olist-etl-job`**
   - Click **"Run"**
   - **⏱️ Expect 4-8 minutes to complete**

2. **Monitor Job Progress:**
   - Job will show **"Running"** → **"Succeeded"**
   - Click on job name to see details

3. **View CloudWatch Logs:**
   - In job details, click **"Logs"** tab
   - Click **"View logs in CloudWatch"**
   - Look for log stream: **`/aws-glue/jobs/olist-etl-job/...`**

## 📊 Verification Steps

### **After Crawler Runs:**
1. **Check Glue Catalog:**
   - Glue → Databases → **`olist_db`** → Tables
   - **Should see 9 tables** (all CSV files from raw/)

2. **Expected Tables:**
   - olist_customers
   - olist_geolocation  
   - olist_order_items
   - olist_order_payments
   - olist_order_reviews
   - olist_orders
   - olist_products
   - olist_sellers
   - olist_product_category_name_translation

### **After Job Runs:**
1. **Check S3 Output:**
   ```bash
   aws s3 ls s3://olist-pipeline-vedar-2026/processed/ --recursive
   ```
   - **Should see new files** with timestamps newer than your local upload
   - **Expected folders:** fact_orders/, dim_customer/, dim_product/, dim_seller/, dim_date/

2. **Verify Structure:**
   ```bash
   aws s3 ls s3://olist-pipeline-vedar-2026/processed/fact_orders/
   ```
   - Should see partitioned folders: `year=2017/`, `year=2018/`

## 🚨 Troubleshooting

### **Job Fails:**
1. **Check CloudWatch logs** for specific error
2. **Common issues:**
   - Missing IAM permissions
   - S3 path incorrect
   - Script syntax errors

### **Crawler Fails:**
1. **Check IAM role** has S3 access
2. **Verify S3 path** exists and contains files
3. **Check file formats** (CSV headers)

## 📝 Final Commands
```bash
# Commit changes after successful deployment
git add scripts/
git commit -m "Phase E: AWS Glue deployment"
git push
```

## ⏱️ Expected Timings
- **Crawler:** 1-2 minutes
- **ETL Job:** 4-8 minutes
- **Total setup:** ~15 minutes (including console navigation)
