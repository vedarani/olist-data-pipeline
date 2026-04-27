# Olist E-Commerce Multi-Cloud Data Pipeline

*End-to-end data engineering project showcasing cloud-native ETL, star schema design, and advanced analytics*

![Architecture](docs/architecture.png)

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-------------|
| Storage | AWS S3 |
| Processing | AWS Glue (Crawler + Job) |
| Compute | Apache Spark (PySpark) |
| Warehouse | Snowflake |
| Languages | Python, SQL |
| Version Control | GitHub |

## ✨ Project Highlights

- **Multi-Cloud Architecture**: Seamless data flow between AWS and Snowflake
- **Production-Grade ETL**: Automated schema discovery, data cleansing, and transformation
- **Scalable Design**: Partitioned Parquet output with optimized joins
- **Advanced Analytics**: 6 sophisticated SQL queries with window functions and CTEs
- **Environment Portability**: Single script runs locally and in cloud with configuration flag

## 🔄 Pipeline Stages

1. **Raw Ingestion** → 9 Olist CSV files loaded to S3 bucket
2. **Schema Discovery** → Glue Crawler automatically infers table structures  
3. **Data Transformation** → PySpark job performs multi-table joins and cleansing
4. **Warehouse Load** → Star schema loaded to Snowflake via S3 external stage
5. **Analytics** → Business insights through advanced SQL queries

## ⭐ Star Schema

```
                    ┌─────────────┐
                    │ dim_date    │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │ dim_product  │
                    └──────┬──────┘
                           │
┌──────────┐    ┌───────┴───────┐    ┌─────────────┐
│dim_customer│────┤ fact_orders    │────┤ dim_seller  │
└──────────┘    └────────────────┘    └─────────────┘
```

## 🧠 Engineering Decisions

| Decision | Rationale |
|----------|-----------|
| **Parquet over CSV** | Columnar compression + schema evolution for analytics workloads |
| **Partition by year/month** | Optimizes time-series queries and partition pruning |
| **Broadcast joins for dimensions** | Small lookup tables replicated to all executors |
| **Defensive cleansing with regex** | Handles malformed Portuguese text gracefully |
| **RUN_IN_GLUE flag** | Single codebase supports local and cloud execution |
| **S3 external stage** | Cross-cloud data transfer without network bottlenecks |
| **DISTKEY/SORTKEY design** | Optimizes Redshift performance (included in repo) |
| **Pre-aggregate 1:N relationships** | Prevents row explosion during fact joins |

## 📊 Sample Analytics Queries

Six advanced SQL queries demonstrating interview-ready analytical thinking:

1. **Revenue by State** - Multi-table joins with business KPIs
2. **Top Category per State** - ROW_NUMBER() window function with PARTITION BY
3. **Month-over-Month Growth** - LAG() function for period analysis
4. **Customer Segmentation** - CASE WHEN for business logic tiering
5. **Seller Performance** - RANK() with HAVING for top performers
6. **Cohort Retention** - CTE with DATE_TRUNC for time-based analysis

*Full queries available in `sql/analytics_queries.sql`*

## 📁 Repository Structure

```
olist-data-pipeline/
├── data/                    # Raw CSV files (local testing)
├── output/                   # Parquet output (local)
├── output_csv/               # CSV conversion output
├── scripts/
│   ├── build_warehouse.py     # Main PySpark ETL script
│   └── parquet_to_csv.py    # Parquet to CSV converter
├── sql/
│   ├── snowflake_setup.sql    # Snowflake DDL
│   ├── redshift_setup.sql     # Redshift DDL (alternative)
│   ├── analytics_queries.sql  # 6 advanced analytical queries
│   └── diagnostic_queries.sql  # Troubleshooting queries
├── aws_glue_deployment_guide.md    # Glue setup instructions
├── aws_redshift_setup_guide.md     # Redshift setup instructions
└── README.md                 # This file
```

## 🚀 How to Run

### Local Development
```bash
# Install dependencies
pip install pyspark pandas

# Run ETL locally
python scripts/build_warehouse.py

# Convert to CSV
python scripts/parquet_to_csv.py
```

### Snowflake Setup
1. Run DDL in `sql/snowflake_setup.sql`
2. Upload CSV files via Snowflake Load Data interface
3. Execute queries from `sql/analytics_queries.sql`

### AWS Glue Deployment
1. Upload script to S3: `aws s3 cp scripts/build_warehouse.py s3://bucket/scripts/`
2. Create Glue Crawler for raw data discovery
3. Create Glue Job pointing to S3 script
4. Run job and monitor in CloudWatch

## 🛠️ Real-World Issues Solved

- **Messy Portuguese Reviews**: CSV parsing failed on accented characters → Implemented regex-based cleansing with defensive error handling
- **Java 25 Incompatibility**: PySpark requires Java 8-17 → Downloaded and configured Java 17 with proper JAVA_HOME
- **Windows + Spark Issues**: Missing winutils.exe causing Hadoop errors → Installed Hadoop shim in C:\hadoop\bin with environment variables
- **Large File Uploads**: Snowflake direct upload timeouts → Leveraged S3 external stage for reliable cross-cloud transfer
- **Schema Evolution**: Source data structure changes → Built flexible PySpark schema with optional columns and type casting

## 🏭 Production Deployment Notes

**Security & Infrastructure**
- Replace inline credentials with Snowflake Storage Integration
- Use AWS Secrets Manager for sensitive configuration
- Implement VPC endpoints for private connectivity

**Orchestration & Monitoring**
- Schedule Glue jobs via Step Functions with retry logic
- Set up CloudWatch alarms for job failures
- Implement data quality checks with AWS Glue DataBrew

**Performance & Scaling**
- Enable auto-scaling for Glue jobs based on data volume
- Use Redshift concurrency scaling for warehouse optimization
- Implement query result caching for frequently accessed analytics

**Governance**
- Add data lineage tracking with AWS Glue Catalog
- Implement cost allocation tags for multi-team usage
- Set up automated data retention policies