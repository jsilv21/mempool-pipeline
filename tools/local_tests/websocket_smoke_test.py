import argparse
import json
import time
from datetime import datetime, timezone

try:
    import websocket
except ImportError as exc:
    raise SystemExit("websocket-client is required. Install with: pip install websocket-client") from exc

DEFAULT_WS = "wss://mempool.space/api/v1/ws"
DEFAULT_TRACK_BLOCK = 0


def main():
    parser = argparse.ArgumentParser(description="Read a few mempool websocket messages")
    parser.add_argument("--count", type=int, default=5, help="Number of messages to print")
    parser.add_argument("--url", default=DEFAULT_WS, help="Websocket URL")
    parser.add_argument("--track-block", type=int, default=DEFAULT_TRACK_BLOCK, help="Mempool block number")
    args = parser.parse_args()

    received = 0
    def on_open(ws):
        ws.send(json.dumps({"track-mempool-block": args.track_block}))

    def on_message(ws, message):
        nonlocal received
        received += 1
        payload = None
        try:
            payload = json.loads(message)
        except json.JSONDecodeError:
            payload = {"raw": message}

        envelope = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
        }
        print(json.dumps(envelope))

        if received >= args.count:
            ws.close()

    ws = websocket.WebSocketApp(args.url, on_open=on_open, on_message=on_message)
    ws.run_forever(ping_interval=20, ping_timeout=10)


if __name__ == "__main__":
    main()
