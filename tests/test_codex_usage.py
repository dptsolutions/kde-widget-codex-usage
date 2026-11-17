import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import codex_usage


class UsageReaderTests(unittest.TestCase):
    def test_windows_are_matched_by_duration_not_slot(self):
        result = {"rateLimitsByLimitId": {"codex": {
            "primary": {"usedPercent": 27, "windowDurationMins": 10080, "resetsAt": 200},
            "secondary": {"usedPercent": 76, "windowDurationMins": 300, "resetsAt": 100},
        }}}
        windows = codex_usage.classify_windows(result)
        self.assertEqual(windows["five_hour"], {"remaining": 24, "used": 76, "resets_at": 100})
        self.assertEqual(windows["weekly"], {"remaining": 73, "used": 27, "resets_at": 200})

    def test_weekly_only_is_supported(self):
        windows = codex_usage.classify_windows({"rateLimits": {
            "primary": {"usedPercent": 10, "windowDurationMins": 10080, "resetsAt": None},
            "secondary": None,
        }})
        self.assertIsNone(windows["five_hour"])
        self.assertEqual(windows["weekly"]["remaining"], 90)

    def test_binary_validation_rejects_other_programs(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "codex"
            script.write_text("#!/bin/sh\necho codex-cli 0.1.0\n")
            script.chmod(0o755)
            self.assertTrue(codex_usage.validate_binary(str(script)))
            self.assertFalse(codex_usage.validate_binary("/bin/ls"))
            self.assertFalse(codex_usage.validate_binary(str(script) + "-missing"))

    def test_custom_path_never_falls_back(self):
        with patch.object(codex_usage.shutil, "which", return_value="/valid/codex"):
            self.assertIsNone(codex_usage.resolve_binary("/invalid/codex", lambda path: path == "/valid/codex"))

    def test_missing_binary_has_distinct_status(self):
        with patch.object(codex_usage, "resolve_binary", return_value=None):
            result = codex_usage.Bridge().handle({"command": "fetch", "path": ""})
        self.assertEqual(result["status"], "missing")

    def test_auth_failure_has_distinct_status(self):
        class FakeSession:
            binary = "/valid/codex"

            class process:
                @staticmethod
                def poll(): return None

            def request(self, *_args, **_kwargs):
                return {"error": {"message": "chatgpt authentication required to read rate limits"}}

        bridge = codex_usage.Bridge()
        bridge.session = FakeSession()
        with patch.object(codex_usage, "resolve_binary", return_value="/valid/codex"):
            result = bridge.handle({"command": "fetch", "path": ""})
        self.assertEqual(result["status"], "auth")


if __name__ == "__main__":
    unittest.main()
