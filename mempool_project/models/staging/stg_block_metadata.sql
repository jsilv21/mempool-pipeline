with source as (
  select *
  from {{ source('raw', 'BLOCK_METADATA') }}
)

select
  ingested_at,
  id,
  height,
  version,
  timestamp,
  tx_count,
  size,
  weight,
  merkle_root,
  previousblockhash,
  mediantime,
  nonce,
  bits,
  difficulty,
  raw,
  s3_key
from source
