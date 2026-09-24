#!/usr/bin/env python3
"""Exercise local and CI commit validation against real Git commit graphs."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent


class CommitValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="taskmark-commits-")
        self.addCleanup(self.temporary.cleanup)
        self.repo = pathlib.Path(self.temporary.name)
        shutil.copytree(ROOT / ".githooks", self.repo / ".githooks")
        (self.repo / "scripts").mkdir()
        for name in ("validate-commit-message", "validate-commit-range"):
            shutil.copy2(ROOT / "scripts" / name, self.repo / "scripts" / name)
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "Commit Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", ".githooks")
        self.git("add", ".")
        self.git("commit", "-m", "chore(ci): initialize fixture")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def run_command(self, *command, succeeds=True):
        result = subprocess.run(command, cwd=self.repo, capture_output=True, text=True)
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *arguments, succeeds=True):
        return self.run_command("git", *arguments, succeeds=succeeds)

    def branch_commit(self, branch, subject, bypass_hook=False):
        self.git("checkout", "-b", branch, self.base)
        (self.repo / "change.txt").write_text(branch)
        self.git("add", "change.txt")
        options = ("-c", "core.hooksPath=/dev/null") if bypass_hook else ()
        self.git(*options, "commit", "-m", subject)
        self.git("checkout", "main")

    def validate_range(self, succeeds=True):
        return self.run_command("scripts/validate-commit-range", self.base, "HEAD", succeeds=succeeds)

    def test_default_merge_subjects_are_accepted_even_when_long(self):
        for branch in ("develop", "feature/" + "long-branch-name-" * 6):
            with self.subTest(branch=branch):
                self.git("reset", "--hard", self.base)
                self.branch_commit(branch, "feat(app): add fixture change")
                self.git("merge", "--no-ff", "--no-edit", branch)
                parents = self.git("rev-list", "--parents", "-n", "1", "HEAD").stdout.split()
                self.assertEqual(len(parents), 3)
                self.validate_range()

    def test_ordinary_commits_still_require_valid_scoped_subjects(self):
        for subject in ("Merge branch 'develop'", "fix: missing scope", "fix(app): " + "x" * 70):
            with self.subTest(subject=subject):
                self.git("commit", "--allow-empty", "-m", subject, succeeds=False)
        self.git("commit", "--allow-empty", "-m", "fix(app): retain valid subjects")
        self.validate_range()

    def test_ci_rejects_invalid_commits_brought_in_by_a_merge(self):
        self.branch_commit("develop", "unscoped change", bypass_hook=True)
        self.git("merge", "--no-ff", "--no-edit", "develop")
        result = self.validate_range(succeeds=False)
        self.assertIn("invalid Conventional Commit: unscoped change", result.stderr)

    def test_merge_like_single_parent_subject_does_not_bypass_ci(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-m", "Merge branch 'develop'")
        self.validate_range(succeeds=False)


if __name__ == "__main__":
    unittest.main()
