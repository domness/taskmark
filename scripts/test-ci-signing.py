"""Exercise credential lifecycle with fake Apple tools; never touch a real Keychain."""

import base64
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("setup-ci-signing")


class SigningLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.directory = self.root / "taskmark-signing"
        self.log = self.root / "calls.jsonl"
        for name in ("security", "xcrun"):
            tool = self.root / name
            tool.write_text(
                f"#!{sys.executable}\n"
                "import json, os, pathlib, sys\n"
                "args = sys.argv[1:]\n"
                "with open(os.environ['CALL_LOG'], 'a') as log: log.write(json.dumps(args) + '\\n')\n"
                "if args[0] == os.environ.get('FAIL_COMMAND'): sys.exit(65)\n"
                "if args[0] == 'create-keychain': pathlib.Path(args[-1]).touch()\n"
                "if args[0] == 'delete-keychain': pathlib.Path(args[-1]).unlink()\n"
            )
            tool.chmod(0o755)
        self.env = {
            **os.environ, "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
            "RUNNER_ENVIRONMENT": "github-hosted", "RUNNER_TEMP": str(self.root),
            "CALL_LOG": str(self.log), "MACOS_CERTIFICATE_P12_BASE64": base64.b64encode(b"certificate").decode(),
            "MACOS_CERTIFICATE_PASSWORD": "private-password", "APP_STORE_CONNECT_PRIVATE_KEY": "private-api-key",
            "APP_STORE_CONNECT_KEY_ID": "TESTKEY", "APP_STORE_CONNECT_ISSUER_ID": "test-issuer",
            "NOTARYTOOL_PROFILE": "test-profile", "NOTARYTOOL_KEYCHAIN": str(self.directory / "signing.keychain-db"),
        }

    def run_script(self, *arguments):
        return subprocess.run(["bash", str(SCRIPT), *arguments], env=self.env,
                              text=True, capture_output=True, check=False)

    def test_import_discards_raw_credentials_and_cleanup_removes_keychain(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([path.name for path in self.directory.iterdir()], ["signing.keychain-db"])
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        self.assertNotIn("private-password", result.stdout + result.stderr)
        self.assertNotIn("private-api-key", result.stdout + result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        store = next(call for call in calls if call[0] == "notarytool")
        self.assertEqual(store[-2:], ["--keychain", self.env["NOTARYTOOL_KEYCHAIN"]])
        importer = next(call for call in calls if call[0] == "import")
        self.assertNotIn("-A", importer, "Import must not authorize every application")
        self.assertEqual(self.run_script("--cleanup").returncode, 0)
        self.assertFalse(self.directory.exists())
        self.assertEqual(self.run_script("--cleanup").returncode, 0, "Cleanup must be repeatable")

    def test_failures_remove_partial_credentials_and_preserve_exit_status(self):
        for command in ("create-keychain", "import", "notarytool"):
            with self.subTest(command=command):
                self.env["FAIL_COMMAND"] = command
                result = self.run_script()
                self.assertEqual(result.returncode, 65, result.stderr)
                self.assertFalse(self.directory.exists())

    def test_missing_secret_and_wrong_keychain_fail_before_creating_files(self):
        self.env["APP_STORE_CONNECT_PRIVATE_KEY"] = ""
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("APP_STORE_CONNECT_PRIVATE_KEY", result.stderr)
        self.assertFalse(self.directory.exists())
        self.env["APP_STORE_CONNECT_PRIVATE_KEY"] = "key"
        self.env["NOTARYTOOL_KEYCHAIN"] = "/some/other/keychain"
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(self.directory.exists())

    def test_refuses_personal_runner_even_for_cleanup(self):
        self.env["RUNNER_ENVIRONMENT"] = "self-hosted"
        for arguments in ((), ("--cleanup",)):
            self.assertNotEqual(self.run_script(*arguments).returncode, 0)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
