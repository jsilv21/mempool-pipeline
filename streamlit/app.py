import json
import os
from io import BytesIO

import boto3
import streamlit as st

DEFAULT_PREFIX = "mempool-data/"


def get_config():
    bucket = os.getenv("S3_BUCKET") or st.secrets.get("S3_BUCKET")
    prefix = os.getenv("S3_PREFIX") or st.secrets.get("S3_PREFIX", DEFAULT_PREFIX)
    region = os.getenv("AWS_REGION") or st.secrets.get("AWS_REGION", "us-east-1")
    if not bucket:
        st.error("Missing S3_BUCKET in env or Streamlit secrets.")
        st.stop()
    return bucket, prefix, region


@st.cache_data(ttl=5)
def fetch_latest_object(bucket, prefix, region):
    s3 = boto3.client("s3", region_name=region)
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    contents = response.get("Contents", [])
    if not contents:
        return None, None

    latest = max(contents, key=lambda obj: obj["LastModified"])
    key = latest["Key"]
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    return key, body


def parse_ndjson(blob):
    items = []
    for line in BytesIO(blob).read().splitlines():
        if not line:
            continue
        try:
            items.append(json.loads(line.decode("utf-8")))
        except json.JSONDecodeError:
            continue
    return items


def main():
    st.set_page_config(page_title="Mempool Live (S3)", layout="wide")
    st.title("Mempool Live (S3)")
    st.caption("Polling S3 every 5 seconds for the latest Firehose object.")

    bucket, prefix, region = get_config()
    key, body = fetch_latest_object(bucket, prefix, region)

    if not key:
        st.info("No objects found yet. Try again after data arrives.")
        return

    st.write(f"Latest object: `{key}`")
    records = parse_ndjson(body)
    st.write(f"Records in object: {len(records)}")
    if records:
        st.json(records[-10:])


if __name__ == "__main__":
    main()
