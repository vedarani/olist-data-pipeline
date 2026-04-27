"""
Olist E-Commerce Data Warehouse Builder
Reads 9 raw CSVs, builds star schema, writes Parquet output.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as _sum, to_timestamp, to_date, year, month,
    dayofmonth, dayofweek, weekofyear, quarter, broadcast,
    datediff, expr, when, length, regexp_extract
)
import sys

# ═══════ CONFIG ═══════
RUN_IN_GLUE = False

if RUN_IN_GLUE:
    from awsglue.utils import getResolvedOptions
    args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_BUCKET'])
    BUCKET = args['S3_BUCKET']
    DATA_DIR = f"s3://{BUCKET}/raw/"
    OUTPUT_DIR = f"s3://{BUCKET}/processed/"
else:
    DATA_DIR = "data/"
    OUTPUT_DIR = "output/"

# ═══════ SPARK SESSION ═══════
spark = SparkSession.builder \
    .appName("OlistWarehouse") \
    .config("spark.sql.shuffle.partitions", "8") \
    .config("spark.driver.memory", "4g") \
    .config("spark.sql.ansi.enabled", "false") \
    .getOrCreate()
spark.sparkContext.setLogLevel("WARN")

print(f"\n{'='*60}\nMode: {'GLUE' if RUN_IN_GLUE else 'LOCAL'}\n{'='*60}")

# Helper: safe CSV read with multiline support (handles quoted text with commas/newlines)
def read_csv(filename):
    return spark.read \
        .option("header", "true") \
        .option("multiLine", "true") \
        .option("escape", '"') \
        .option("quote", '"') \
        .csv(DATA_DIR + filename)

# ═══════ 1. EXTRACT — Read 9 source tables ═══════
print("\nReading 9 source tables...")
customers = read_csv("olist_customers_dataset.csv")
orders = read_csv("olist_orders_dataset.csv")
order_items = read_csv("olist_order_items_dataset.csv")
payments = read_csv("olist_order_payments_dataset.csv")
reviews = read_csv("olist_order_reviews_dataset.csv")
products = read_csv("olist_products_dataset.csv")
sellers = read_csv("olist_sellers_dataset.csv")
cat_trans = read_csv("product_category_name_translation.csv")

# ═══════ 2. CLEAN ═══════
print("Cleaning tables...")
orders_c = orders \
    .withColumn("order_purchase_timestamp", to_timestamp("order_purchase_timestamp")) \
    .withColumn("order_delivered_customer_date", to_timestamp("order_delivered_customer_date")) \
    .withColumn("order_estimated_delivery_date", to_timestamp("order_estimated_delivery_date")) \
    .filter(col("order_purchase_timestamp").isNotNull())

items_c = order_items \
    .withColumn("price", col("price").cast("double")) \
    .withColumn("freight_value", col("freight_value").cast("double")) \
    .withColumn("order_item_id", col("order_item_id").cast("int")) \
    .filter(col("price") > 0)

# Pre-aggregate payments — filter bad rows where installments isn't a number
payments_clean = payments \
    .filter(col("payment_installments").rlike("^[0-9]+$")) \
    .filter(col("payment_value").rlike("^[0-9.]+$")) \
    .withColumn("payment_value", col("payment_value").cast("double")) \
    .withColumn("payment_installments", col("payment_installments").cast("int"))

payments_agg = payments_clean \
    .groupBy("order_id").agg(
        _sum("payment_value").alias("total_payment_value"),
        expr("first(payment_type)").alias("payment_type"),
        _sum("payment_installments").alias("total_installments")
    )

# Pre-aggregate reviews — filter bad rows where review_score isn't 1-5
reviews_clean = reviews \
    .filter(col("review_score").rlike("^[1-5]$")) \
    .withColumn("review_score", col("review_score").cast("int"))

reviews_agg = reviews_clean \
    .groupBy("order_id").agg(expr("avg(review_score)").alias("review_score"))

products_c = products \
    .withColumn("product_weight_g", col("product_weight_g").cast("double")) \
    .withColumn("product_length_cm", col("product_length_cm").cast("double")) \
    .withColumn("product_height_cm", col("product_height_cm").cast("double")) \
    .withColumn("product_width_cm", col("product_width_cm").cast("double")) \
    .withColumn("product_photos_qty", col("product_photos_qty").cast("int"))

# ═══════ 3. BUILD DIMENSIONS ═══════
print("Building dimensions...")
dim_customer = customers.dropDuplicates(["customer_id"])

dim_product = products_c \
    .join(broadcast(cat_trans), on="product_category_name", how="left") \
    .select(
        "product_id",
        col("product_category_name").alias("product_category_pt"),
        col("product_category_name_english").alias("product_category_en"),
        "product_weight_g", "product_length_cm", "product_height_cm",
        "product_width_cm", "product_photos_qty"
    ).dropDuplicates(["product_id"])

dim_seller = sellers.dropDuplicates(["seller_id"])

dim_date = orders_c \
    .select(to_date("order_purchase_timestamp").alias("full_date")) \
    .filter(col("full_date").isNotNull()).dropDuplicates() \
    .withColumn("date_id", expr("date_format(full_date, 'yyyyMMdd')").cast("int")) \
    .withColumn("year", year("full_date")) \
    .withColumn("month", month("full_date")) \
    .withColumn("day", dayofmonth("full_date")) \
    .withColumn("quarter", quarter("full_date")) \
    .withColumn("weekday", dayofweek("full_date")) \
    .withColumn("week_of_year", weekofyear("full_date")) \
    .select("date_id", "full_date", "year", "month", "day", "quarter", "weekday", "week_of_year")

# ═══════ 4. BUILD FACT TABLE ═══════
print("Building fact_orders...")
fact_orders = items_c \
    .join(orders_c, on="order_id", how="inner") \
    .join(payments_agg, on="order_id", how="left") \
    .join(reviews_agg, on="order_id", how="left") \
    .withColumn("total_value", col("price") + col("freight_value")) \
    .withColumn("year", year("order_purchase_timestamp")) \
    .withColumn("month", month("order_purchase_timestamp")) \
    .withColumn("delivery_days",
                datediff("order_delivered_customer_date", "order_purchase_timestamp")) \
    .withColumn("date_id",
                expr("date_format(order_purchase_timestamp, 'yyyyMMdd')").cast("int")) \
    .select(
        "order_id", "order_item_id", "customer_id", "product_id", "seller_id", "date_id",
        "order_status", "order_purchase_timestamp", "order_delivered_customer_date",
        "order_estimated_delivery_date", "price", "freight_value", "total_value",
        "payment_type", "total_payment_value", "total_installments",
        "review_score", "delivery_days", "year", "month"
    )

# ═══════ 5. WRITE OUTPUT ═══════
print("Writing Parquet output...")
fact_orders.write.mode("overwrite").partitionBy("year", "month").parquet(OUTPUT_DIR + "fact_orders/")
dim_customer.write.mode("overwrite").parquet(OUTPUT_DIR + "dim_customer/")
dim_product.write.mode("overwrite").parquet(OUTPUT_DIR + "dim_product/")
dim_seller.write.mode("overwrite").parquet(OUTPUT_DIR + "dim_seller/")
dim_date.write.mode("overwrite").parquet(OUTPUT_DIR + "dim_date/")

print(f"\nDone!")
print(f"  fact_orders:  {fact_orders.count():,}")
print(f"  dim_customer: {dim_customer.count():,}")
print(f"  dim_product:  {dim_product.count():,}")
print(f"  dim_seller:   {dim_seller.count():,}")
print(f"  dim_date:     {dim_date.count():,}")

spark.stop()