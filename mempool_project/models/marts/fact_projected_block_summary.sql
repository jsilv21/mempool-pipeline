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
  sum(value) as total_value,
  avg(fee_rate) as avg_fee_rate,
  min(unix_timestamp) as first_tx_unix_timestamp,
  max(unix_timestamp) as last_tx_unix_timestamp
from txs
group by sequence
