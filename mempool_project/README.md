# Mempool dbt project

This repo keeps Snowflake bootstrap SQL in version control so you can run it
manually without dbt macros or Snowflake worksheets.

## Bootstrap Snowflake raw objects

Run the statements in `mempool_project/sql/bootstrap_raw.sql` after your profile
points at the `MEMPOOL` database.

Notes:
- This setup uses a Snowflake storage integration; you must create the AWS IAM
  role separately and allow the generated Snowflake IAM user to assume it.
- Ensure S3 event notifications are configured for the `mempool-data/` and
  `batch/` prefixes so Snowpipe auto-ingest works.
