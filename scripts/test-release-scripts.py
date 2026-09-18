"""Input-contract checks run without Apple signing credentials or a macOS host."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("package-macos-release")


class ReleaseInputTests(unittest.TestCase):
    def validate(self, tag, build="42.1"):
        return subprocess.run(
            ["bash", str(SCRIPT), "--validate-inputs", tag, build],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_tag_is_mapped_to_apple_numeric_version(self):
        for tag in ("v1.2.3", "1.2.3", "v1.2.3-rc.1", "v1.2.3+build.4"):
            with self.subTest(tag=tag):
                result = self.validate(tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "1.2.3")

    def test_path_and_shell_payloads_are_rejected(self):
        for tag in ("", "main", "v1.2", "../v1.2.3", "v1.2.3/other", "v1.2.3\nother", "v1.2.3;exit 0", "$(id)"):
            with self.subTest(tag=tag):
                self.assertEqual(self.validate(tag).returncode, 2)

    def test_invalid_build_numbers_are_rejected(self):
        for build in ("0", "-1", "10000", "1.100", "1.2.3.4", "1;exit 0", ""):
            with self.subTest(build=build):
                self.assertEqual(self.validate("v1.2.3", build).returncode, 2)

    def test_missing_arguments_fail_before_any_build(self):
        result = subprocess.run(["bash", str(SCRIPT), "--validate-inputs"], capture_output=True, check=False)
        self.assertEqual(result.returncode, 2)


class NotarizationKeychainTests(unittest.TestCase):
    def test_preflight_and_submission_use_explicit_keychain(self):
        for custom in (False, True):
            for action in ("history", "submit"):
                with self.subTest(custom=custom, action=action), tempfile.TemporaryDirectory() as directory:
                    root = pathlib.Path(directory)
                    keychain = root / ("Custom Signing.keychain-db" if custom else "Library/Keychains/login.keychain-db")
                    keychain.parent.mkdir(parents=True, exist_ok=True)
                    keychain.touch()
                    log = root / "arguments.json"
                    tool = root / "xcrun"
                    tool.write_text(
                        f"#!{sys.executable}\nimport json, os, sys\n"
                        "with open(os.environ['ARGUMENT_LOG'], 'w') as output: json.dump(sys.argv[1:], output)\n"
                        "sys.exit(int(os.environ.get('NOTARY_TEST_EXIT', '0')))\n"
                    )
                    tool.chmod(0o755)
                    env = {**os.environ, "HOME": str(root), "PATH": str(root) + os.pathsep + os.environ["PATH"],
                           "NOTARYTOOL_PROFILE": "test-profile", "NOTARYTOOL_KEYCHAIN": str(keychain) if custom else "",
                           "ARGUMENT_LOG": str(log)}
                    arguments = [action, "--output-format", "json"]
                    if action == "submit":
                        arguments.insert(1, str(root / "Taskmark update.zip"))
                    command = ["bash", str(SCRIPT.with_name("notarytool-with-keychain")), *arguments]
                    result = subprocess.run(command, env=env, capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(log.read_text()),
                                     ["notarytool", *arguments, "--keychain-profile", "test-profile", "--keychain", str(keychain)])
                    env["NOTARY_TEST_EXIT"] = "69"
                    self.assertEqual(subprocess.run(command, env=env, capture_output=True, check=False).returncode, 69)
                    log.unlink()
                    keychain.unlink()
                    result = subprocess.run(command, env=env, capture_output=True, text=True, check=False)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Keychain not found", result.stderr)
                    self.assertFalse(log.exists(), "Missing Keychain must not fall back to an implicit lookup")


if __name__ == "__main__":
    unittest.main()
