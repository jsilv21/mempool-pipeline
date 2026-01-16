import json
import os
from io import BytesIO

import boto3
import pandas as pd
import snowflake.connector
import streamlit as st

DEFAULT_PREFIX = "mempool-data/stream/"


def get_s3_config():
    bucket = os.getenv("S3_BUCKET") or st.secrets.get("S3_BUCKET")
    prefix = os.getenv("S3_PREFIX") or st.secrets.get("S3_PREFIX", DEFAULT_PREFIX)
    region = os.getenv("AWS_REGION") or st.secrets.get("AWS_REGION", "us-east-1")
    if not bucket:
        return None
    return {"bucket": bucket, "prefix": prefix, "region": region}


def get_snowflake_config():
    if "snowflake" in st.secrets:
        return dict(st.secrets["snowflake"])

    account = os.getenv("SNOWFLAKE_ACCOUNT") or st.secrets.get("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER") or st.secrets.get("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD") or st.secrets.get("SNOWFLAKE_PASSWORD")
    warehouse = os.getenv("SNOWFLAKE_WAREHOUSE") or st.secrets.get(
        "SNOWFLAKE_WAREHOUSE"
    )
    database = os.getenv("SNOWFLAKE_DATABASE") or st.secrets.get("SNOWFLAKE_DATABASE")
    schema = os.getenv("SNOWFLAKE_SCHEMA") or st.secrets.get("SNOWFLAKE_SCHEMA")
    role = os.getenv("SNOWFLAKE_ROLE") or st.secrets.get("SNOWFLAKE_ROLE")
    private_key = os.getenv("SNOWFLAKE_PRIVATE_KEY") or st.secrets.get(
        "SNOWFLAKE_PRIVATE_KEY"
    )

    required = [account, user, warehouse, database, schema]
    if not all(required):
        return None

    return {
        "account": account,
        "user": user,
        "password": password,
        "warehouse": warehouse,
        "database": database,
        "schema": schema,
        "role": role,
        "private_key": private_key,
    }


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


@st.cache_data(ttl=60)
def fetch_snowflake_df(query, config):
    ctx = snowflake.connector.connect(
        **config,
    )
    try:
        return pd.read_sql(query, ctx)
    finally:
        ctx.close()


def main():
    st.set_page_config(page_title="Mempool Live (S3)", layout="wide")
    st.title("Mempool Live (S3) + Analytics (Snowflake)")
    st.caption("Realtime stream from S3 plus historical metrics from Snowflake.")

    live_tab, analytics_tab = st.tabs(["Live Stream", "Analytics"])

    with live_tab:
        s3_config = get_s3_config()
        if not s3_config:
            st.info("S3 not configured yet. Skipping live stream.")
        else:
            key, body = fetch_latest_object(
                s3_config["bucket"], s3_config["prefix"], s3_config["region"]
            )

            if not key:
                st.info("No objects found yet. Try again after data arrives.")
            else:
                st.write(f"Latest object: `{key}`")
                records = parse_ndjson(body)
                st.write(f"Records in object: {len(records)}")
                if records:
                    st.json(records[-10:])

    with analytics_tab:
        config = get_snowflake_config()
        if not config:
            st.info(
                "Set SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, "
                "SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE, SNOWFLAKE_SCHEMA "
                "(and optional SNOWFLAKE_ROLE / SNOWFLAKE_PRIVATE_KEY), or add a "
                "[snowflake] section in Streamlit secrets."
            )
            return

        db = config["database"]
        schema = config["schema"]

        blocks_query = f"""
            select block_time, height, tx_count, size_mb, weight_kwu
            from {db}.{schema}.FACT_BLOCK_METADATA
            order by block_time desc
            limit 200
        """
        conversions_query = f"""
            select conversion_time, usd
            from {db}.{schema}.FACT_CONVERSIONS
            order by conversion_time desc
            limit 200
        """
        projected_query = f"""
            select sequence, last_seen_at, tx_count, total_fee, total_vsize
            from {db}.{schema}.FACT_PROJECTED_BLOCK_SUMMARY
            order by last_seen_at desc
            limit 1
        """

        blocks_df = fetch_snowflake_df(blocks_query, config)
        conversions_df = fetch_snowflake_df(conversions_query, config)
        projected_df = fetch_snowflake_df(projected_query, config)

        if not blocks_df.empty:
            latest_block = blocks_df.iloc[0]
            st.metric("Latest Block Height", int(latest_block["HEIGHT"]))
            st.metric("Latest Block Time", str(latest_block["BLOCK_TIME"]))

            st.subheader("Block Size + Weight (last 200)")
            blocks_chart = blocks_df.sort_values("BLOCK_TIME")
            st.line_chart(blocks_chart, x="BLOCK_TIME", y=["SIZE_MB", "WEIGHT_KWU"])

        if not conversions_df.empty:
            st.subheader("BTC Conversion (USD)")
            conversions_chart = conversions_df.sort_values("CONVERSION_TIME")
            st.line_chart(conversions_chart, x="CONVERSION_TIME", y="USD")

        if not projected_df.empty:
            projected = projected_df.iloc[0]
            st.subheader("Projected Next Block (Latest Sequence)")
            st.write(
                {
                    "sequence": int(projected["SEQUENCE"]),
                    "last_seen_at": str(projected["LAST_SEEN_AT"]),
                    "tx_count": int(projected["TX_COUNT"]),
                    "total_fee": float(projected["TOTAL_FEE"] or 0),
                    "total_vsize": float(projected["TOTAL_VSIZE"] or 0),
                }
            )


if __name__ == "__main__":
    main()
