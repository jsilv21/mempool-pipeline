-- Manual Snowflake bootstrap for the mempool pipeline.
-- Run in the MEMPOOL database.

-- 1) Create a storage integration (replace placeholders)
create or replace storage integration MEMPOOL_S3_INT
  type = external_stage
  storage_provider = s3
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_SNOWFLAKE_ROLE'
  storage_allowed_locations = ('s3://mempool-pipeline-data-bucket-8lwat71n');

-- Capture the IAM user/role Snowflake expects to assume:
-- describe integration MEMPOOL_S3_INT;

-- 2) Create schema, tables, file format, stage
create schema if not exists RAW;

create or replace table RAW.MEMPOOL_STREAM_EVENTS (
  INGESTED_AT timestamp_ntz default current_timestamp,
  INDEX_POS number,
  SEQUENCE number,
  DELTA variant,
  RAW variant,
  S3_KEY string
);

create or replace table RAW.BLOCK_METADATA (
  INGESTED_AT timestamp_ntz default current_timestamp,
  ID string,
  HEIGHT number,
  VERSION number,
  TIMESTAMP number,
  TX_COUNT number,
  SIZE number,
  WEIGHT number,
  MERKLE_ROOT string,
  PREVIOUSBLOCKHASH string,
  MEDIANTIME number,
  NONCE number,
  BITS number,
  DIFFICULTY float,
  RAW variant,
  S3_KEY string
);

create or replace file format RAW.NDJSON_JSON
  type = json
  strip_outer_array = true
  ignore_utf8_errors = true;

create or replace stage RAW.MEMPOOL_STAGE
  url = 's3://mempool-pipeline-data-bucket-8lwat71n'
  storage_integration = MEMPOOL_S3_INT
  file_format = RAW.NDJSON_JSON;

-- 3) Create pipes
create or replace pipe RAW.PIPE_MEMPOOL_STREAM
  auto_ingest = true
as
copy into RAW.MEMPOOL_STREAM_EVENTS (INDEX_POS, SEQUENCE, DELTA, RAW, S3_KEY)
from (
  select
    $1:"projected-block-transactions":"index"::number as index_pos,
    $1:"projected-block-transactions":"sequence"::number as sequence,
    $1:"projected-block-transactions":"delta" as delta,
    $1 as raw,
    metadata$filename as s3_key
  from @RAW.MEMPOOL_STAGE/mempool-data/
)
file_format = (format_name = 'RAW.NDJSON_JSON');

create or replace pipe RAW.PIPE_BLOCK_METADATA
  auto_ingest = true
as
copy into RAW.BLOCK_METADATA (
  ID, HEIGHT, VERSION, TIMESTAMP, TX_COUNT, SIZE, WEIGHT,
  MERKLE_ROOT, PREVIOUSBLOCKHASH, MEDIANTIME, NONCE, BITS, DIFFICULTY,
  RAW, S3_KEY
)
from (
  select
    $1:"id"::string as id,
    $1:"height"::number as height,
    $1:"version"::number as version,
    $1:"timestamp"::number as timestamp,
    $1:"tx_count"::number as tx_count,
    $1:"size"::number as size,
    $1:"weight"::number as weight,
    $1:"merkle_root"::string as merkle_root,
    $1:"previousblockhash"::string as previousblockhash,
    $1:"mediantime"::number as mediantime,
    $1:"nonce"::number as nonce,
    $1:"bits"::number as bits,
    $1:"difficulty"::float as difficulty,
    $1 as raw,
    metadata$filename as s3_key
  from @RAW.MEMPOOL_STAGE/batch/
)
file_format = (format_name = 'RAW.NDJSON_JSON');
