import json
import os
import urllib.request
from datetime import datetime, timezone

import boto3

MEMPOOL_API = "https://mempool.space/api/blocks"
MEMPOOL_TIP_HEIGHT = "https://mempool.space/api/blocks/tip/height"
STATE_KEY = "state/last_block.json"


def handler(event, context):
    bucket = os.getenv("S3_BUCKET", "")
    if not bucket:
        raise RuntimeError("S3_BUCKET is required")

    s3 = boto3.client("s3")

    with urllib.request.urlopen(MEMPOOL_TIP_HEIGHT) as resp:
        tip_height = int(resp.read().decode("utf-8").strip())

    last_height = None
    try:
        state = s3.get_object(Bucket=bucket, Key=STATE_KEY)
        payload = json.loads(state["Body"].read().decode("utf-8"))
        last_height = payload.get("height")
    except s3.exceptions.NoSuchKey:
        last_height = None

    if last_height == tip_height:
        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "environment": os.getenv("ENVIRONMENT", "unknown"),
                    "project": os.getenv("PROJECT", "unknown"),
                    "s3_key": None,
                    "block_count": 0,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "note": "no new block",
                }
            ),
        }

    with urllib.request.urlopen(MEMPOOL_API) as resp:
        blocks = json.loads(resp.read().decode("utf-8"))

    timestamp = datetime.now(timezone.utc)
    key = f"batch/block_date={timestamp:%Y-%m-%d}/blocks_{timestamp:%H%M%S}.json"

    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(blocks).encode("utf-8"),
        ContentType="application/json",
    )

    s3.put_object(
        Bucket=bucket,
        Key=STATE_KEY,
        Body=json.dumps({"height": tip_height, "updated_at": timestamp.isoformat()}).encode("utf-8"),
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
