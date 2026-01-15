with events as (
  select *
  from {{ ref('int_stream_events_deduped') }}
),
added as (
  select
    ingested_at,
    sequence,
    index_pos,
    'added' as event_type,
    f.index as tx_index,
    f.value as tx
  from events,
  lateral flatten(input => delta:added) f
),
changed as (
  select
    ingested_at,
    sequence,
    index_pos,
    'changed' as event_type,
    f.index as tx_index,
    f.value as tx
  from events,
  lateral flatten(input => delta:changed) f
),
removed as (
  select
    ingested_at,
    sequence,
    index_pos,
    'removed' as event_type,
    f.index as tx_index,
    f.value as tx
  from events,
  lateral flatten(input => delta:removed) f
),
flattened as (
  select
    ingested_at,
    sequence,
    index_pos,
    event_type,
    tx_index,
    tx
  from added
  union all
  select
    ingested_at,
    sequence,
    index_pos,
    event_type,
    tx_index,
    tx
  from changed
  union all
  select
    ingested_at,
    sequence,
    index_pos,
    event_type,
    tx_index,
    tx
  from removed
)

select
  ingested_at,
  sequence,
  index_pos,
  event_type,
  tx_index,
  case
    when event_type in ('added', 'changed') then tx[0]::string
    else tx::string
  end as txid,
  case when event_type in ('added', 'changed') then tx[1]::number end as fee,
  case when event_type in ('added', 'changed') then tx[2]::float end as vsize,
  case when event_type in ('added', 'changed') then tx[3]::number end as value,
  case when event_type in ('added', 'changed') then tx[4]::float end as fee_rate,
  case when event_type in ('added', 'changed') then tx[6]::number end as unix_timestamp,
  tx as raw_tx
from flattened
