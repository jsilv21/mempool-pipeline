
with source as (
  select *
  from MEMPOOL.DBT_JSILV.stg_mempool_stream_events
  
    where ingested_at > (select max(ingested_at) from MEMPOOL.DBT_JSILV.int_stream_events_deduped)
  
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
limit 100;