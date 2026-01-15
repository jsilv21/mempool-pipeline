with conversions as (
  select *
  from {{ ref('int_conversions_deduped') }}
)

select
  to_timestamp_ntz(conversion_time) as conversion_time,
  usd,
  eur,
  gbp,
  cad,
  aud,
  chf,
  jpy,
  ingested_at,
  s3_key,
  raw
from conversions
