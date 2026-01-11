Local sanity tests

These scripts are for learning + local verification only. They do not touch Terraform or AWS.

lambda_smoke_test.py
- Pulls mempool REST API blocks or uses a local fixture.
- Prints basic shape info so you can sanity check data.

websocket_smoke_test.py
- Connects to mempool websocket and prints a few messages.
- Requires websocket-client.

Examples
- python tools\local_tests\lambda_smoke_test.py --offline
- python tools\local_tests\lambda_smoke_test.py --limit 3
- python tools\local_tests\websocket_smoke_test.py --count 5
