with source as (
  select *
  from {{ source('raw', 'MEMPOOL_STREAM_EVENTS') }}
)

select
  ingested_at,
  index,
  sequence,
  delta,
  raw,
  s3_key
from source
