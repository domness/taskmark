"""Check admin setup fails closed and reapplies protections without duplicate rules."""

import importlib.util
import pathlib
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("configuration", pathlib.Path(__file__).with_name("configure-github-actions.py"))
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)


class GitHubConfigurationTests(unittest.TestCase):
    def test_write_only_account_cannot_make_any_changes(self):
        with patch.object(CONFIG, "api", return_value={"permissions": {"admin": False}}) as api:
            with self.assertRaisesRegex(RuntimeError, "admin access"):
                CONFIG.configure()
            api.assert_called_once_with(CONFIG.PREFIX)

    def test_repeat_setup_updates_named_rules_and_retains_matching_ref_policies(self):
        mutations = []

        def api(path, method="GET", body=None):
            if method != "GET":
                mutations.append((path, method, body))
                return None
            if path == CONFIG.PREFIX:
                return {"permissions": {"admin": True}}
            if path == "users/domness":
                return {"id": 42}
            if path.endswith("deployment-branch-policies"):
                return {"branch_policies": [{"id": 1, "name": "main", "type": "branch"},
                                            {"id": 2, "name": "*.*.*", "type": "tag"},
                                            {"id": 3, "name": "unsafe", "type": "branch"}]}
            if path.endswith("rulesets"):
                return [{"id": 4, "name": "Taskmark main protection"},
                        {"id": 5, "name": "Taskmark release tag protection"},
                        {"id": 6, "name": "Unrelated policy"}]
            self.fail(f"Unexpected read: {path}")

        with patch.object(CONFIG, "api", side_effect=api), patch("builtins.print"):
            CONFIG.configure()
        self.assertFalse(any(method == "POST" for _, method, _ in mutations))
        self.assertIn((f"{CONFIG.PREFIX}/environments/release/deployment-branch-policies/3", "DELETE", None), mutations)
        self.assertFalse(any(path.endswith("rulesets/6") or "/secrets" in path for path, _, _ in mutations))
        environment = next(body for path, _, body in mutations if path.endswith("environments/release"))
        self.assertEqual(environment["reviewers"], [{"type": "User", "id": 42}])
        self.assertFalse(environment["can_admins_bypass"])
        self.assertFalse(environment["prevent_self_review"])


if __name__ == "__main__":
    unittest.main()
