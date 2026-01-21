with streams as (
  select *
  from {{ ref('stg_mempool_stream_events') }}
)

select
*
from streams
order by ingested_at desc
limit 5;

