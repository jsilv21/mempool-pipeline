with source as (
  select *
  from {{ source('raw', 'MEMPOOL_CONVERSIONS') }}
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
