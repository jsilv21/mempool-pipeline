# Mempool data pipeline project:

- Pulls data from Mempool.space's API & Websockets connection
- Event Stream: Raw txn deltas from next expected block
- Batched data: Historical analysis of blockchain

## Requirements

### Goals

- Able to visualize 'next block' changes in realtime
- Visualize historical block data statistics

### Architecture

- Orchestration - GitHub Actions
  - Terraform build/destroy - AWS
  - Ec2 start/stop listening
  - dbt transformations in Snowflake
- Data Source - mempool.space
  - Realtime via [websocket api](https://mempool.space/docs/api/websocket)
  - Batch via [REST API](https://mempool.space/docs/api/rest)
- AWS Infrastructure
  - Managed via Terraform. S3 must persist on destroy.
  - Event Streaming:
    - Ec2: python connection to mempool websocket to receive JSON data to firehose
    - Firehose pushes to dashboard (realtime) and s3 (historical)
  - Batched Data:
    - EventBridge triggers lambda function
    - Lambda function polls mempool REST for block data
  - S3 stores all historical data, version controlled
  - IAM manages access amongst AWS resourecs
- Data Warehousing
  - Snowflake DW
  - dbt for transformations
- Front end (TBD - Streamlit?)

## Rough Architecture Diagram

![](mempool-project.drawio.png)
