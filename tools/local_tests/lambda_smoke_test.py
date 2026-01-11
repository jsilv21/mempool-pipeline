import argparse
import json
import os
import urllib.request

DEFAULT_API = "https://mempool.space/api/blocks"
FIXTURE_PATH = os.path.join(os.path.dirname(__file__), "fixtures", "sample_mempool_block.json")


def fetch_blocks(api_url):
    with urllib.request.urlopen(api_url) as resp:
        return json.loads(resp.read().decode("utf-8"))


def load_fixture():
    with open(FIXTURE_PATH, "r", encoding="utf-8") as handle:
        return json.loads(handle.read())


def summarize(blocks, limit):
    if isinstance(blocks, dict):
        blocks = [blocks]

    print(f"blocks_received={len(blocks)}")
    for idx, block in enumerate(blocks[:limit], start=1):
        keys = sorted(block.keys())
        print(f"block_{idx}_keys={keys}")
        print(
            "block_{idx}_summary=".format(idx=idx)
            + json.dumps(
                {
                    "height": block.get("height"),
                    "hash": block.get("hash"),
                    "timestamp": block.get("timestamp"),
                    "tx_count": block.get("tx_count"),
                }
            )
        )


def main():
    parser = argparse.ArgumentParser(description="Sanity check mempool REST blocks payload")
    parser.add_argument("--offline", action="store_true", help="Use local fixture instead of live API")
    parser.add_argument("--limit", type=int, default=2, help="How many blocks to print")
    parser.add_argument("--api", default=DEFAULT_API, help="Override API URL")
    args = parser.parse_args()

    if args.offline:
        blocks = load_fixture()
    else:
        blocks = fetch_blocks(args.api)

    summarize(blocks, args.limit)


if __name__ == "__main__":
    main()
