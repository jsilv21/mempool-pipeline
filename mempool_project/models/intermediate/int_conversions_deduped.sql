{{ config(
  materialized='incremental',
  unique_key='conversion_time',
  incremental_strategy='merge'
) }}

with source as (
  select *
  from {{ ref('stg_mempool_stream_conversions') }}
  {% if is_incremental() %}
    where ingested_at > (select max(ingested_at) from {{ this }})
  {% endif %}
)

select
  ingested_at,
  aud,
  cad,
  chf,
  eur,
  gbp,
  jpy,
  usd,
  conversion_time,
  raw,
  s3_key
from source
qualify row_number() over (partition by conversion_time order by ingested_at desc) = 1
