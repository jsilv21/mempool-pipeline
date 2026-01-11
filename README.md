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
    - Ec2, firehose
  - Batched Data:
    - lambda, eventbridge
  - storage via S3
  - IAM for all
- Data Warehousing
  - Snowflake DW
  - dbt for transformations
- Front end (TBD - Streamlit?)

## Rough Architecture Diagram

```mermaid
flowchart LR
%% Data Sources
MempoolAPI[Mempool API] -->|REST Pulls| Lambda[Lambda]
MempoolAPI -->|Streaming| EC2[EC2]

    %% Streaming pipeline
    EC2 -->|Websocket Stream| Firehose[Firehose]
    Firehose -->|Realtime mempool chgs| Frontend[Front End Dashboard]

    %% Batched pipeline
    Lambda --> EventBridge[EventBridge]
    EventBridge --> S3Landing[S3 - Landing]

    %% Snowflake Layers
    S3Landing --> SnowflakeBronze[Snowflake Bronze]
    SnowflakeBronze --> SnowflakeSilver[Snowflake Silver]
    SnowflakeSilver --> SnowflakeGold[Snowflake Gold]

    %% Analytics
    SnowflakeGold -->|Historical Analytics| Frontend

    %% Transformations
    SnowflakeBronze -->|dbt transformations| DBT[dbt]
    SnowflakeSilver -->|dbt transformations| DBT
    SnowflakeGold -->|dbt transformations| DBT

    %% Terraform and GitHub Actions
    Terraform --> S3Landing
    GH[GitHub Actions] --> Terraform
    GH --> C[EC2 script updates?]
```
