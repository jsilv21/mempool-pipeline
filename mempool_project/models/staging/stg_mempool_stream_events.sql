with source as (
  select *
  from {{ source('raw', 'MEMPOOL_STREAM_EVENTS') }}
)

select
  ingested_at,
  index_pos,
  sequence,
  delta,
  raw,
  s3_key
from source
where sequence is not null