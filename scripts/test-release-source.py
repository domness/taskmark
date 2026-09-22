"""Release trust checks against real temporary Git histories and a fake GitHub CLI."""

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = pathlib.Path(__file__).parent


class ReleaseSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ("resolve-release-source", "package-macos-release"):
            shutil.copyfile(SCRIPTS / name, scripts / name)
        tool = self.root / "gh"
        tool.write_text('#!/bin/bash\nprintf "%s\\n" "${DRAFT:-false}"\n')
        tool.chmod(0o755)
        self.env = {**os.environ, "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
                    "GITHUB_REPOSITORY": "test/repo", "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
                    "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com"}
        self.git("init", "-b", "main")
        self.git("add", "scripts")
        self.git("commit", "-m", "Initial source")
        self.sha = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/main", self.sha)

    def git(self, *arguments):
        return subprocess.run(["git", *arguments], cwd=self.root, env=self.env,
                              text=True, capture_output=True, check=True).stdout.strip()

    def resolve(self, tag):
        return subprocess.run(["bash", "scripts/resolve-release-source", tag], cwd=self.root,
                              env=self.env, text=True, capture_output=True, check=False)

    def test_lightweight_and_annotated_tags_resolve_to_same_commit(self):
        self.git("tag", "1.2.3")
        self.git("tag", "-a", "v1.2.3", "-m", "Annotated release")
        for tag in ("1.2.3", "v1.2.3"):
            result = self.resolve(tag)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), self.sha)

    def test_unmerged_source_is_rejected(self):
        self.git("checkout", "-b", "untrusted")
        (self.root / "untrusted").touch()
        self.git("add", "untrusted")
        self.git("commit", "-m", "Unmerged source")
        self.git("tag", "1.2.3")
        result = self.resolve("1.2.3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("origin/main history", result.stderr)

    def test_branch_is_not_accepted_as_a_tag(self):
        self.git("branch", "1.2.3")
        self.assertNotEqual(self.resolve("1.2.3").returncode, 0)

    def test_draft_release_is_rejected(self):
        self.git("tag", "1.2.3")
        self.env["DRAFT"] = "true"
        result = self.resolve("1.2.3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be published", result.stderr)


if __name__ == "__main__":
    unittest.main()
