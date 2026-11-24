"""Request shapes and auth headers, against the fake API of test_retries.

Run from sdks/python: python -m unittest discover -s tests
"""

import base64
import hashlib
import hmac
import threading
import unittest
from http.server import ThreadingHTTPServer

from test_retries import FakeAPI

from jobcelis import JobcelisClient, JobcelisError, verify_webhook_signature


class ClientTest(unittest.TestCase):
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

    def client(self, api_key="test", **kwargs):
        kwargs.setdefault("retry_base_delay", 0.001)
        return JobcelisClient(api_key, base_url=self.base_url, **kwargs)

    @property
    def reqs(self):
        return FakeAPI.requests

    # --- auth ---

    def test_api_key_header_without_bearer(self):
        self.client().list_events()
        self.assertEqual(self.reqs[0]["headers"]["X-Api-Key"], "test")
        self.assertNotIn("Authorization", self.reqs[0]["headers"])

    def test_auth_token_sent_as_bearer(self):
        c = self.client(auth_token="jwt-1")
        c.list_projects()
        self.assertEqual(self.reqs[0]["headers"]["Authorization"], "Bearer jwt-1")
        c.set_auth_token(None)
        c.list_projects()
        self.assertNotIn("Authorization", self.reqs[1]["headers"])

    def test_login_without_api_key_stores_token(self):
        FakeAPI.script = [(200, {}, {"user": {"id": "u1"}, "token": "jwt-login"}), (200, {}, {"data": []})]
        c = self.client(api_key=None)
        c.login("a@b.c", "pw")
        self.assertEqual(self.reqs[0]["path"], "/api/v1/auth/login")
        self.assertEqual(self.reqs[0]["body"], {"email": "a@b.c", "password": "pw"})
        self.assertNotIn("X-Api-Key", self.reqs[0]["headers"])
        c.list_projects()
        self.assertEqual(self.reqs[1]["headers"]["Authorization"], "Bearer jwt-login")

    def test_verify_mfa_and_refresh(self):
        FakeAPI.script = [(200, {}, {"user": {}, "token": "jwt-mfa"}), (200, {}, {"token": "jwt-new"})]
        c = self.client()
        c.verify_mfa("mfa-1", "123456")
        self.assertEqual(self.reqs[0]["path"], "/api/v1/auth/mfa/verify")
        self.assertEqual(self.reqs[0]["body"], {"mfa_token": "mfa-1", "code": "123456"})
        c.refresh_token()
        self.assertEqual(self.reqs[1]["path"], "/api/v1/auth/refresh")
        self.assertEqual(self.reqs[1]["body"], {"token": "jwt-mfa"})

    # --- request shapes ---

    def test_create_job_with_topic(self):
        self.client().create_job("nightly", cron_expression="0 3 * * *", topic="report.run", payload={"a": 1})
        self.assertEqual(
            self.reqs[0]["body"],
            {"name": "nightly", "cron_expression": "0 3 * * *", "topic": "report.run", "payload": {"a": 1}},
        )

    def test_create_job_with_url(self):
        self.client().create_job("ping", cron_expression="daily", url="https://example.com/ping")
        self.assertEqual(self.reqs[0]["body"]["url"], "https://example.com/ping")

    def test_create_job_without_action_raises(self):
        with self.assertRaises(ValueError):
            self.client().create_job("noop", cron_expression="daily")
        self.assertEqual(self.reqs, [])

    def test_create_pipeline_sends_webhook_id(self):
        steps = [{"type": "filter", "field": "amount", "operator": "gt", "value": 10}]
        self.client().create_pipeline("p", ["order.created"], steps, webhook_id="wh_1")
        self.assertEqual(
            self.reqs[0]["body"],
            {"name": "p", "topics": ["order.created"], "steps": steps, "webhook_id": "wh_1"},
        )

    def test_test_pipeline_wraps_payload(self):
        self.client().test_pipeline("p1", {"amount": 5})
        self.assertEqual(self.reqs[0]["body"], {"payload": {"amount": 5}})

    def test_update_retention_policy_wraps_policy(self):
        self.client().update_retention_policy({"events_days": 30})
        self.assertEqual(self.reqs[0]["body"], {"retention_policy": {"events_days": 30}})

    def test_restrict_processing_sends_password(self):
        self.client(auth_token="jwt").restrict_processing("secret")
        self.assertEqual(self.reqs[0]["body"], {"password": "secret"})

    def test_add_member_default_role_is_viewer(self):
        self.client(auth_token="jwt").add_member("p1", "x@y.z")
        self.assertEqual(self.reqs[0]["body"], {"email": "x@y.z", "role": "viewer"})

    def test_status_reads_health(self):
        self.client().status()
        self.assertEqual(self.reqs[0]["path"], "/health")

    # --- retries of non-idempotent POSTs ---

    def test_post_without_key_not_retried_on_502_504(self):
        for status in (502, 504):
            with self.subTest(status=status):
                FakeAPI.requests = []
                FakeAPI.script = [(status, {}, {"error": "gateway"})]
                with self.assertRaises(JobcelisError) as ctx:
                    self.client().create_webhook("https://example.com")
                self.assertEqual(ctx.exception.status, status)
                self.assertEqual(len(self.reqs), 1)

    def test_get_still_retried_on_502(self):
        FakeAPI.script = [(502, {}, {}), (200, {}, {"id": "x"})]
        self.client().get_event("x")
        self.assertEqual(len(self.reqs), 2)


class WebhookSignatureTest(unittest.TestCase):
    secret = "whsec_test"
    body = '{"topic":"order.created","payload":{"id":1}}'

    def sig(self, body, pad=False):
        digest = hmac.new(self.secret.encode(), body.encode(), hashlib.sha256).digest()
        b64 = base64.b64encode(digest).decode()
        return "sha256=" + (b64 if pad else b64.rstrip("="))

    def test_valid_for_str_and_bytes(self):
        self.assertTrue(verify_webhook_signature(self.secret, self.body, self.sig(self.body)))
        self.assertTrue(verify_webhook_signature(self.secret, self.body.encode(), self.sig(self.body)))

    def test_padded_signature_accepted(self):
        self.assertTrue(verify_webhook_signature(self.secret, self.body, self.sig(self.body, pad=True)))

    def test_invalid(self):
        good = self.sig(self.body)
        self.assertFalse(verify_webhook_signature(self.secret, self.body + " ", good))
        self.assertFalse(verify_webhook_signature("other", self.body, good))
        self.assertFalse(verify_webhook_signature(self.secret, self.body, good + "!!"))
        self.assertFalse(verify_webhook_signature(self.secret, self.body, good.replace("sha256=", "sha1=")))
        self.assertFalse(verify_webhook_signature(self.secret, b"", good))


if __name__ == "__main__":
    unittest.main()
