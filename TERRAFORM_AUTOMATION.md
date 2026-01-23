Terraform Automation Notes

Purpose
Keep the IAM permissions and Terraform automation requirements in one place for
GitHub Actions scheduling, remote state, and dbt runs.

IAM Policy (attach to the GitHub Actions Terraform role)
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

Next Steps (state migration)
1) Create the remote backend: an S3 bucket (versioning + encryption) and a
   DynamoDB table with a `LockID` partition key.
2) Add repo secrets: `TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`,
   `AWS_TERRAFORM_ROLE_ARN`.
3) Migrate local state (run from `terraform/`):
   `terraform init -migrate-state -backend-config="bucket=YOUR_BUCKET" -backend-config="key=mempool-pipeline/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="dynamodb_table=YOUR_LOCK_TABLE" -backend-config="encrypt=true"`
4) Remove or archive any local `terraform.tfstate` copies after migration.

Future Requirements / Architectural Changes
- GitHub Actions must assume the Terraform role via OIDC; ensure the role trust
  policy allows `token.actions.githubusercontent.com` for this repo.
- The backend S3 bucket must remain available; if renamed, update
  `TF_STATE_BUCKET` and the state key.
- Scheduled workflows are in UTC; adjust cron times if timezone changes.
- dbt runs require Snowflake secrets to be present; keep them rotated and
  aligned with the warehouse/database/schema naming in dbt.
