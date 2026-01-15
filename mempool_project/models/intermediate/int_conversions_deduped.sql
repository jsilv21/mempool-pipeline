with source as (
  select *
  from {{ ref('stg_mempool_stream_conversions') }}
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
