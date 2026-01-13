import json
import logging
import os
import urllib.request
import time
from datetime import datetime, timezone

try:
    import boto3
except ImportError as exc:
    raise SystemExit("boto3 is required. Install with: pip install boto3") from exc

try:
    import websocket
except ImportError as exc:
    raise SystemExit("websocket-client is required. Install with: pip install websocket-client") from exc

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")

MEMPOOL_WS_URL = os.getenv("MEMPOOL_WS_URL", "wss://mempool.space/api/v1/ws")
MEMPOOL_TRACK_BLOCK = int(os.getenv("MEMPOOL_TRACK_BLOCK", "0"))
FIREHOSE_STREAM_NAME = os.getenv("FIREHOSE_STREAM_NAME", "")
FIREHOSE_CONVERSIONS_STREAM_NAME = os.getenv("FIREHOSE_CONVERSIONS_STREAM_NAME", "")

def get_region():
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    if region:
        logging.info("AWS region resolved from environment: %s", region)
        return region
    try:
        token_req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode("utf-8")
        doc_req = urllib.request.Request(
            "http://169.254.169.254/latest/dynamic/instance-identity/document",
            headers={"X-aws-ec2-metadata-token": token},
        )
        with urllib.request.urlopen(doc_req, timeout=2) as resp:
            doc = json.loads(resp.read().decode("utf-8"))
            region = doc.get("region")
            if region:
                logging.info("AWS region resolved from IMDS: %s", region)
            return region
    except Exception:
        return None

BATCH_SIZE = int(os.getenv("BATCH_SIZE", "200"))
FLUSH_INTERVAL_SEC = int(os.getenv("FLUSH_INTERVAL_SEC", "5"))

if not FIREHOSE_STREAM_NAME:
    raise SystemExit("FIREHOSE_STREAM_NAME is required")

region = get_region()
if not region:
    raise SystemExit("AWS region not found. Set AWS_REGION or AWS_DEFAULT_REGION.")

firehose = boto3.client("firehose", region_name=region)

streams = {
    FIREHOSE_STREAM_NAME: {"buffer": [], "last_flush": time.time()},
}
if FIREHOSE_CONVERSIONS_STREAM_NAME:
    streams[FIREHOSE_CONVERSIONS_STREAM_NAME] = {"buffer": [], "last_flush": time.time()}

logged_missing_conversions_stream = False


def flush_stream(stream_name, force=False):
    entry = streams.get(stream_name)
    if not entry or not entry["buffer"]:
        return

    if (
        not force
        and len(entry["buffer"]) < BATCH_SIZE
        and (time.time() - entry["last_flush"]) < FLUSH_INTERVAL_SEC
    ):
        return

    records = [{"Data": (json.dumps(item) + "\n").encode("utf-8")} for item in entry["buffer"]]
    entry["buffer"] = []
    entry["last_flush"] = time.time()

    response = firehose.put_record_batch(
        DeliveryStreamName=stream_name,
        Records=records,
    )

    failed = response.get("FailedPutCount", 0)
    if failed:
        logging.warning("Firehose failed to ingest %s records into %s", failed, stream_name)


def flush_all(force=False):
    for stream_name in streams:
        flush_stream(stream_name, force=force)


def on_open(ws):
    logging.info("Connected to %s", MEMPOOL_WS_URL)
    ws.send(json.dumps({"track-mempool-block": MEMPOOL_TRACK_BLOCK}))


def on_message(ws, message):
    global logged_missing_conversions_stream

    try:
        payload = json.loads(message)
    except json.JSONDecodeError:
        payload = {"raw": message}

    envelope = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "source": "mempool.space",
        "payload": payload,
    }

    target_stream = FIREHOSE_STREAM_NAME
    if isinstance(payload, dict) and "conversions" in payload:
        if FIREHOSE_CONVERSIONS_STREAM_NAME:
            target_stream = FIREHOSE_CONVERSIONS_STREAM_NAME
        else:
            if not logged_missing_conversions_stream:
                logging.warning(
                    "Conversions payload received but FIREHOSE_CONVERSIONS_STREAM_NAME is not set."
                )
                logged_missing_conversions_stream = True

    streams[target_stream]["buffer"].append(envelope)
    flush_stream(target_stream)


def on_error(ws, error):
    logging.error("WebSocket error: %s", error)


def on_close(ws, status_code, message):
    logging.warning("WebSocket closed: %s %s", status_code, message)
    flush_all(force=True)


def run():
    while True:
        ws = websocket.WebSocketApp(
            MEMPOOL_WS_URL,
            on_open=on_open,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
        )
        ws.run_forever(ping_interval=20, ping_timeout=10)
        logging.info("Reconnect in 5 seconds...")
        time.sleep(5)


if __name__ == "__main__":
    run()

