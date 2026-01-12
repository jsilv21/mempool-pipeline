# Checkpoint - 2026-01-12

## Status
- Lambda polling + EventBridge + S3 (state tracking) in place.
- EC2 websocket client writes to Firehose; Firehose writes NDJSON to S3.
- EC2 bootstraps via `user_data` and runs a systemd service; CloudWatch Logs agent ships stdout/stderr.
- Default VPC + egress SG configured; region set via `/etc/mempool/mempool.env`.

## Key files
- `src/ec2/mempool_ws_client.py`:
  - Buffers websocket messages, flushes to Firehose in batches.
  - Region resolution logs source and uses IMDSv2 if env vars missing.
- `terraform/ec2.tf`:
  - `user_data` installs deps, writes app + env file, configures systemd service + CW agent.
- `terraform/firehose.tf`: Firehose buffers (128 MiB / 60s) before writing to S3.
- `terraform/iam.tf`: EC2 role has Firehose + CloudWatch Logs permissions.

## Recent fixes
- Added explicit region env vars and env file (`/etc/mempool/mempool.env`) for the EC2 service.
- Added region resolution logging to the client.
- Added IMDSv2 token flow for region lookup in the client.

## Known issues / notes
- If region errors appear, ensure EC2 was replaced after Terraform changes or restart service.
- Python 3.9 deprecation warning from boto3 is present (optional future upgrade).

## Next tasks
- S3 -> Snowflake setup.
- dbt modeling.
- Streamlit front-end setup.
- GitHub Actions for orchestration.

