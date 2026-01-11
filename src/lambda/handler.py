import json
import os
import urllib.request
from datetime import datetime, timezone

import boto3

MEMPOOL_API = "https://mempool.space/api/blocks"


def handler(event, context):
    with urllib.request.urlopen(MEMPOOL_API) as resp:
        blocks = json.loads(resp.read().decode("utf-8"))

    bucket = os.getenv("S3_BUCKET", "")
    if not bucket:
        raise RuntimeError("S3_BUCKET is required")

    timestamp = datetime.now(timezone.utc)
    key = f"batch/block_date={timestamp:%Y-%m-%d}/blocks_{timestamp:%H%M%S}.json"

    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(blocks).encode("utf-8"),
        ContentType="application/json",
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "environment": os.getenv("ENVIRONMENT", "unknown"),
                "project": os.getenv("PROJECT", "unknown"),
                "s3_key": key,
                "block_count": len(blocks),
                "timestamp": timestamp.isoformat(),
            }
        ),
    }
