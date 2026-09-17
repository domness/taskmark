"""Input-contract checks run without Apple signing credentials or a macOS host."""

import pathlib
import subprocess
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


if __name__ == "__main__":
    unittest.main()
