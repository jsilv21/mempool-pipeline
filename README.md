# Mempool data pipeline project:

- Pulls data from Mempool.space's API & WebSockets connection
- Event stream: transaction deltas for the next expected block
- Conversions stream: periodic BTC conversion rates
- Batch data: block metadata snapshots

## Requirements

### Goals

- Able to visualize 'next block' changes in realtime
- Visualize historical block data statistics
- Track periodic BTC conversion rates

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
    - EC2: Python connection to mempool websocket to receive JSON data to Firehose
    - Firehose stream: writes to `s3://.../mempool-data/stream/`
    - Firehose conversions: writes to `s3://.../mempool-data/conversions/`
  - Batched Data:
    - EventBridge triggers Lambda function
    - Lambda polls mempool REST for block data -> `s3://.../batch/`
  - S3 stores raw data and state
  - IAM manages access among AWS resources
- Data Warehousing
  - Snowflake DW
  - Snowpipe auto-ingests stream + conversions into raw tables
  - dbt for transformations
- Front end (TBD - Streamlit?)

## Rough Architecture Diagram

![](mempool-project.drawio.png)

## GitHub Actions OIDC (Terraform)

This repo's workflows can use GitHub Actions OIDC to assume an AWS IAM role
without storing long-lived AWS keys. You create the IAM role once, then save
the role ARN in GitHub as a secret.

High-level setup:
1) Create an AWS OIDC provider for `https://token.actions.githubusercontent.com`.
2) Create an IAM role with a trust policy scoped to this repo/branch/workflow.
3) Attach a least-privilege permissions policy to that role.
4) Add `AWS_TERRAFORM_ROLE_ARN` in GitHub Actions secrets and (optionally)
   `AWS_REGION` in GitHub Actions variables.

Example trust policy (update `ACCOUNT_ID` and repo name):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Baseline permissions for this repo's Terraform resources:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyDescribe",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "iam:Get*",
        "iam:List*",
        "logs:Describe*",
        "events:Describe*",
        "lambda:Get*",
        "firehose:Describe*",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2SecurityGroupsAndInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:ModifyInstanceAttribute",
        "ec2:AssociateIamInstanceProfile",
        "ec2:DisassociateIamInstanceProfile",
        "ec2:ReplaceIamInstanceProfileAssociation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Buckets",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketVersioning",
        "s3:GetBucketVersioning",
        "s3:PutBucketTagging",
        "s3:GetBucketTagging",
        "s3:ListBucket"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMForPipelineRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:TagResource",
        "lambda:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Firehose",
      "Effect": "Allow",
      "Action": [
        "firehose:CreateDeliveryStream",
        "firehose:DeleteDeliveryStream",
        "firehose:UpdateDestination",
        "firehose:TagDeliveryStream",
        "firehose:UntagDeliveryStream"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchAndEventBridge",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy",
        "logs:DeleteLogGroup",
        "events:PutRule",
        "events:DeleteRule",
        "events:PutTargets",
        "events:RemoveTargets"
      ],
      "Resource": "*"
    }
  ]
}
```

Notes:
- Scope the `StringLike` `sub` to your repo/branch or specific workflows for
  tighter access.
- You can split roles (plan vs apply/destroy) for tighter control.
