"""Verify that the readiness check boots the exact requested simulator."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("wait-for-ios-test-simulator")
SIMULATOR = "F7E97A4A-18B4-4F21-AEB1-A92EC951F8A5"


class SimulatorReadinessTests(unittest.TestCase):
    def run_readiness_check(self, destination, boot_exit=0):
        with tempfile.TemporaryDirectory() as directory:
            mock = Path(directory) / "xcrun"
            mock.write_text(f'#!/bin/bash\nprintf "%s\\n" "$@"\nexit {boot_exit}\n')
            mock.chmod(0o755)
            return subprocess.run(
                ["bash", SCRIPT, destination],
                env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}"},
                capture_output=True,
                text=True,
            )

    def test_boots_the_simulator_from_the_destination(self):
        result = self.run_readiness_check(f"platform=iOS Simulator,id={SIMULATOR},arch=arm64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["simctl", "bootstatus", SIMULATOR, "-b"])

    def test_does_not_hide_a_boot_failure(self):
        result = self.run_readiness_check(f"platform=iOS Simulator,id={SIMULATOR}", boot_exit=42)
        self.assertEqual(result.returncode, 42)

    def test_name_based_destination_leaves_booting_to_xcode(self):
        result = self.run_readiness_check("platform=iOS Simulator,name=iPad", boot_exit=42)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("xcodebuild will boot it", result.stdout)


if __name__ == "__main__":
    unittest.main()
