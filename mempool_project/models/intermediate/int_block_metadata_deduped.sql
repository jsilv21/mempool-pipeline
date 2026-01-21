{{ config(
  materialized='incremental',
  unique_key='id',
  incremental_strategy='merge'
) }}

with source as (
  select *
  from {{ ref('stg_block_metadata') }}
  {% if is_incremental() %}
    where ingested_at > (select max(ingested_at) from {{ this }})
  {% endif %}
)

select
  ingested_at,
  id,
  height,
  version,
  timestamp,
  tx_count,
  size,
  weight,
  merkle_root,
  previousblockhash,
  mediantime,
  nonce,
  bits,
  difficulty,
  raw,
  s3_key
from source
qualify row_number() over (partition by id order by ingested_at desc) = 1
