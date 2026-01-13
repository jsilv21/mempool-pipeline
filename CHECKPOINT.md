# Checkpoint - 2026-01-13

## Status

- Lambda polling + EventBridge + S3 (state tracking) in place.
- EC2 websocket client writes to Firehose; Firehose writes NDJSON to S3.
- EC2 bootstraps via `user_data` and runs a systemd service; CloudWatch Logs agent ships stdout/stderr.
- Default VPC + egress SG configured; region set via `/etc/mempool/mempool.env`.
- Firehose split: stream and conversions land in `mempool-data/stream/` and `mempool-data/conversions/`.
- Snowflake setup updated for separate stream + conversions pipes and payload JSON paths.
- dbt staging models exist for stream events and conversions.

## Key files

- `src/ec2/mempool_ws_client.py`:
  - Buffers websocket messages, flushes to Firehose in batches.
  - Routes conversions to a separate Firehose stream when configured.
  - Region resolution logs source and uses IMDSv2 if env vars missing.
- `terraform/ec2.tf`:
  - `user_data` installs deps, writes app + env file, configures systemd service + CW agent.
- `terraform/firehose.tf`: Separate Firehose streams for stream + conversions; buffers (128 MiB / 60s).
- `terraform/iam.tf`: EC2 role can write to both Firehose streams.
- `mempool_project/sql/bootstrap_raw.sql`: Snowpipe definitions for stream + conversions.

## Recent fixes

- Lambda timeout increased to 10s.
- Stream payload parsing fixed to use `payload` JSON path.
- Snowpipe prefixes updated to `mempool-data/stream/` and `mempool-data/conversions/`.

## Known issues / notes

- Snowpipe/SQS delivery is at-least-once and unordered; use payload timestamps/sequence for ordering in dbt.
- If EC2 changes were applied via Terraform, replace the instance so updated `user_data` takes effect.
- Python 3.9 deprecation warning from boto3 is present (optional future upgrade).

## Next tasks

- Validate stream + conversions Snowpipe ingestion end-to-end.
- Backfill conversions and stream data if needed.
- Finalize dbt models (silver/gold).
- Streamlit dashboard for realtime + batch data.
- GitHub Actions for orchestration.

### Data Changes

- BLOCK_METADATA contains duplicate rows
