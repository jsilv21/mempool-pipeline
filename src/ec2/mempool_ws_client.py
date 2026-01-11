import json
import logging
import os
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
MEMPOOL_CHANNELS = os.getenv("MEMPOOL_CHANNELS", "mempool-blocks").split(",")
FIREHOSE_STREAM_NAME = os.getenv("FIREHOSE_STREAM_NAME", "")

BATCH_SIZE = int(os.getenv("BATCH_SIZE", "200"))
FLUSH_INTERVAL_SEC = int(os.getenv("FLUSH_INTERVAL_SEC", "5"))

if not FIREHOSE_STREAM_NAME:
    raise SystemExit("FIREHOSE_STREAM_NAME is required")

firehose = boto3.client("firehose")

buffer = []
last_flush = time.time()


def flush(force=False):
    global buffer, last_flush

    if not buffer:
        return

    if not force and len(buffer) < BATCH_SIZE and (time.time() - last_flush) < FLUSH_INTERVAL_SEC:
        return

    records = [{"Data": json.dumps(item).encode("utf-8")} for item in buffer]
    buffer = []
    last_flush = time.time()

    response = firehose.put_record_batch(
        DeliveryStreamName=FIREHOSE_STREAM_NAME,
        Records=records,
    )

    failed = response.get("FailedPutCount", 0)
    if failed:
        logging.warning("Firehose failed to ingest %s records", failed)


def on_open(ws):
    logging.info("Connected to %s", MEMPOOL_WS_URL)
    ws.send(json.dumps({"action": "want", "data": MEMPOOL_CHANNELS}))


def on_message(ws, message):
    try:
        payload = json.loads(message)
    except json.JSONDecodeError:
        payload = {"raw": message}

    envelope = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "source": "mempool.space",
        "payload": payload,
    }

    buffer.append(envelope)
    flush()


def on_error(ws, error):
    logging.error("WebSocket error: %s", error)


def on_close(ws, status_code, message):
    logging.warning("WebSocket closed: %s %s", status_code, message)
    flush(force=True)


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
