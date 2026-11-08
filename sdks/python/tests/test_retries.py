"""Automatic retries, against a fake API on localhost.

Run from sdks/python: python -m unittest discover -s tests
"""

import json
import re
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import requests

from jobcelis import JobcelisClient, JobcelisError

UUID4 = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")


class FakeAPI(BaseHTTPRequestHandler):
    """Each request takes the next scripted response; "drop" closes the
    connection without answering (a network error)."""

    script: list = []
    requests: list = []

    def _handle(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        FakeAPI.requests.append({
            "method": self.command,
            "path": self.path,
            "headers": dict(self.headers),
            "body": json.loads(raw) if raw else None,
        })
        nxt = FakeAPI.script.pop(0) if FakeAPI.script else (200, {}, {})
        if nxt == "drop":
            self.close_connection = True
            self.connection.shutdown(2)
            return
        status, headers, body = nxt
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = _handle

    def log_message(self, *args):
        pass


class RetryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FakeAPI)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        FakeAPI.script = []
        FakeAPI.requests = []

    def client(self, **kwargs):
        kwargs.setdefault("retry_base_delay", 0.001)
        return JobcelisClient("test", base_url=self.base_url, **kwargs)

    @property
    def reqs(self):
        return FakeAPI.requests

    def test_get_retries_503_then_succeeds(self):
        FakeAPI.script = [(503, {}, {}), (503, {}, {}), (200, {}, {"id": "evt_1"})]
        self.assertEqual(self.client().get_event("evt_1")["id"], "evt_1")
        self.assertEqual(len(self.reqs), 3)

    def test_429_with_retry_after_zero_is_retried(self):
        FakeAPI.script = [(429, {"Retry-After": "0"}, {}), (200, {}, {"data": []})]
        self.client().list_events()
        self.assertEqual(len(self.reqs), 2)

    def test_send_event_reuses_generated_idempotency_key(self):
        FakeAPI.script = ["drop", (502, {}, {}), (202, {}, {"id": "evt_1"})]
        self.client().send_event("t", {})
        self.assertEqual(len(self.reqs), 3)
        key = self.reqs[0]["headers"]["X-Idempotency-Key"]
        self.assertRegex(key, UUID4)
        for r in self.reqs:
            self.assertEqual(r["headers"]["X-Idempotency-Key"], key)

    def test_send_event_keeps_caller_key(self):
        FakeAPI.script = [(503, {}, {}), (202, {}, {})]
        self.client().send_event("t", {}, idempotency_key="my-key")
        self.assertEqual(len(self.reqs), 2)
        for r in self.reqs:
            self.assertEqual(r["headers"]["X-Idempotency-Key"], "my-key")
            self.assertEqual(r["body"]["idempotency_key"], "my-key")

    def test_batch_adds_missing_idempotency_keys(self):
        FakeAPI.script = ["drop", (202, {}, {"accepted": 2})]
        events = [{"topic": "a", "payload": {}}, {"topic": "b", "payload": {}, "idempotency_key": "keep-me"}]
        self.client().send_events(events)
        self.assertEqual(len(self.reqs), 2)
        first, second = (r["body"]["events"] for r in self.reqs)
        self.assertRegex(first[0]["idempotency_key"], UUID4)
        self.assertEqual(first[1]["idempotency_key"], "keep-me")
        self.assertEqual(first, second)
        self.assertNotIn("idempotency_key", events[0], "caller dicts are not mutated")

    def test_non_event_post_not_retried_on_network_error(self):
        FakeAPI.script = ["drop"]
        with self.assertRaises(requests.exceptions.ConnectionError):
            self.client().create_webhook("https://example.com")
        self.assertEqual(len(self.reqs), 1)
        self.assertNotIn("X-Idempotency-Key", self.reqs[0]["headers"])

    def test_non_event_post_retried_on_503(self):
        FakeAPI.script = [(503, {}, {}), (201, {}, {"id": "wh_1"})]
        self.assertEqual(self.client().create_webhook("https://example.com")["id"], "wh_1")
        self.assertEqual(len(self.reqs), 2)

    def test_max_retries_zero_makes_one_request(self):
        FakeAPI.script = [(503, {}, {"error": "down"})]
        with self.assertRaises(JobcelisError) as ctx:
            self.client(max_retries=0).get_event("x")
        self.assertEqual(ctx.exception.status, 503)
        self.assertEqual(len(self.reqs), 1)

    def test_last_error_is_jobcelis_error(self):
        FakeAPI.script = [(503, {}, {})] * 3
        with self.assertRaises(JobcelisError) as ctx:
            self.client(max_retries=2).get_event("x")
        self.assertEqual(ctx.exception.status, 503)
        self.assertEqual(len(self.reqs), 3)

    def test_non_retryable_status_not_retried(self):
        for status in (400, 500):
            with self.subTest(status=status):
                FakeAPI.requests = []
                FakeAPI.script = [(status, {}, {"error": "nope"})]
                with self.assertRaises(JobcelisError) as ctx:
                    self.client().get_event("x")
                self.assertEqual(ctx.exception.status, status)
                self.assertEqual(ctx.exception.detail, "nope")
                self.assertEqual(len(self.reqs), 1)

    def test_get_retried_on_network_error(self):
        FakeAPI.script = ["drop", (200, {}, "csv")]
        self.client().export_events()
        self.assertEqual(len(self.reqs), 2)

    def test_backoff_and_retry_after(self):
        c = self.client(retry_base_delay=1.0)
        for attempt, base in [(1, 1), (2, 2), (3, 4), (6, 30), (10, 30)]:
            d = c._retry_delay(attempt, None)
            self.assertTrue(base * 0.8 <= d <= base * 1.2, (attempt, d))
        self.assertEqual(c._retry_delay(1, "5"), 5.0)
        self.assertEqual(c._retry_delay(1, "600"), 60.0)
        self.assertEqual(c._retry_delay(1, "Wed, 21 Oct 2015 07:28:00 GMT"), 0.0)


if __name__ == "__main__":
    unittest.main()
