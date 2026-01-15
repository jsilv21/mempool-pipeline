with events as (
  select *
  from {{ ref('int_stream_events_deduped') }}
),
flattened as (
  select
    ingested_at,
    sequence,
    index_pos,
    f.index as tx_index,
    f.value as tx
  from events,
  lateral flatten(input => delta) f
)

select
  ingested_at,
  sequence,
  index_pos,
  tx_index,
  tx:"txid"::string as txid,
  tx:"fee"::number as fee,
  tx:"vsize"::number as vsize,
  tx:"weight"::number as weight,
  tx:"value"::number as value,
  tx as raw_tx
from flattened
