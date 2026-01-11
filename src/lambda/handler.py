import json
import os
import urllib.request
from datetime import datetime, timezone

MEMPOOL_API = "https://mempool.space/api/blocks"


def handler(event, context):
    with urllib.request.urlopen(MEMPOOL_API) as resp:
        blocks = json.loads(resp.read().decode("utf-8"))

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "environment": os.getenv("ENVIRONMENT", "unknown"),
                "project": os.getenv("PROJECT", "unknown"),
                "block_count": len(blocks),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        ),
    }
