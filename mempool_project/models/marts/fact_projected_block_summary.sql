with txs as (
  select *
  from {{ ref('fact_projected_block_transactions') }}
)

select
  sequence,
  max(ingested_at) as last_seen_at,
  count(*) as tx_count,
  sum(fee) as total_fee,
  sum(vsize) as total_vsize,
  sum(weight) as total_weight,
  sum(value) as total_value
from txs
group by sequence
