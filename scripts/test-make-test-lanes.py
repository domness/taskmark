"""Verify that focused Make targets select only their intended test bundles."""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parent.parent


def dry_run(target, phone="phone-uuid", tablet="tablet-uuid"):
    result = subprocess.run(
        ["make", "--no-print-directory", "-n", target, f"IOS_SIMULATOR_ID={phone}", f"IOS_TABLET_SIMULATOR_ID={tablet}",
         "IOS_TEST_RESULT_DIR=/example/results"],
        cwd=ROOT, check=True, capture_output=True, text=True,
    )
    return result.stdout


class TestLanes(unittest.TestCase):
    def test_package_tests_need_no_app_or_simulator(self):
        self.assertEqual(dry_run("test-unit", phone="", tablet="").strip(), "swift test")

    def test_hosted_ios_tests_only_need_the_phone(self):
        commands = dry_run("test-ios-unit", tablet="")
        self.assertIn("id=phone-uuid", commands)
        self.assertIn("-only-testing:LocalTodoIOSAppTests", commands)
        self.assertNotIn("LocalTodoIOSAppUITests", commands)
        self.assertNotIn("No available iPad", commands)

    def test_phone_ui_only_needs_the_phone(self):
        commands = dry_run("test-ios-phone", tablet="")
        self.assertIn("id=phone-uuid", commands)
        self.assertIn("-only-testing:LocalTodoIOSAppUITests", commands)
        self.assertNotIn("-only-testing:LocalTodoIOSAppTests", commands)
        self.assertNotIn("No available iPad", commands)

    def test_tablet_ui_only_needs_the_tablet(self):
        commands = dry_run("test-ios-tablet", phone="")
        self.assertIn("id=tablet-uuid", commands)
        self.assertIn("testTabletAdaptiveWorkspaceShowsSidebarListAndDetail", commands)
        self.assertIn("-only-testing:LocalTodoIOSAppUITests/SampleVaultUITests", commands)
        self.assertNotIn("-only-testing:LocalTodoIOSAppTests", commands)
        self.assertNotIn("No available iPhone", commands)

    def test_full_gate_keeps_each_lane_and_both_builds(self):
        commands = dry_run("check")
        for lane in ("Unit", "Phone", "Tablet"):
            self.assertIn(f"LocalTodoIOSApp-{lane}.xcresult", commands)
        for scheme in ("LocalTodoApp", "LocalTodoIOSApp"):
            self.assertIn(f"-scheme {scheme} -configuration Debug build", commands)
        self.assertEqual(commands.count("bash scripts/wait-for-ios-test-simulator"), 2)


if __name__ == "__main__":
    unittest.main()
