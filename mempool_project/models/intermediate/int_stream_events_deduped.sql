{{ config(
  materialized='incremental',
  unique_key=['sequence', 'index_pos'],
  incremental_strategy='merge'
) }}

with source as (
  select *
  from {{ ref('stg_mempool_stream_events') }}
  {% if is_incremental() %}
    where ingested_at > (select max(ingested_at) from {{ this }})
  {% endif %}
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
