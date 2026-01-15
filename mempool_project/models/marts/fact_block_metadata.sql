with blocks as (
  select *
  from {{ ref('int_block_metadata_deduped') }}
)

select
  id as block_id,
  height,
  to_timestamp_ntz(timestamp) as block_time,
  tx_count,
  size,
  weight,
  size / 1000000.0 as size_mb,
  weight / 1000.0 as weight_kwu,
  version,
  merkle_root,
  previousblockhash,
  mediantime,
  nonce,
  bits,
  difficulty,
  ingested_at,
  s3_key,
  raw
from blocks
