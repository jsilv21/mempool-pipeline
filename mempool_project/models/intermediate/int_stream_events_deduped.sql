with source as (
  select *
  from {{ ref('stg_mempool_stream_events') }}
)

select
  ingested_at,
  index_pos,
  sequence,
  delta,
  raw,
  s3_key
from source
qualify row_number() over (partition by sequence, index_pos order by ingested_at desc) = 1
