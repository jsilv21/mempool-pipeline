with source as (
  select *
  from {{ source('raw', 'MEMPOOL_STREAM_EVENTS') }}
)

select
COUNT(*) as count
from source

