"""Apply Taskmark's release protections with an owner/admin gh login; never handles secrets."""

import argparse
import json
import subprocess
import sys


REPOSITORY = "domness/taskmark"
PREFIX = f"repos/{REPOSITORY}"


def api(path, method="GET", body=None):
    command = ["gh", "api", path, "--method", method]
    if body is not None:
        command.extend(["--input", "-"])
    result = subprocess.run(command, input=json.dumps(body) if body is not None else None,
                            text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def ensure_ruleset(body):
    existing = api(f"{PREFIX}/rulesets")
    match = next((rule for rule in existing if rule["name"] == body["name"]), None)
    endpoint = f"{PREFIX}/rulesets" + (f"/{match['id']}" if match else "")
    api(endpoint, "PUT" if match else "POST", body)
    print(f"Configured ruleset: {body['name']}")


def configure():
    repository = api(PREFIX)
    if not repository.get("permissions", {}).get("admin"):
        raise RuntimeError("Repository admin access is required. Authenticate gh as domness before applying settings.")
    owner = api("users/domness")
    api(f"{PREFIX}/environments/release", "PUT", {
        "wait_timer": 0,
        "prevent_self_review": False,
        "reviewers": [{"type": "User", "id": owner["id"]}],
        "can_admins_bypass": False,
        "deployment_branch_policy": {"protected_branches": False, "custom_branch_policies": True},
    })
    desired = {(name, kind) for name, kind in [("main", "branch"), ("*.*.*", "tag")]}
    endpoint = f"{PREFIX}/environments/release/deployment-branch-policies"
    policies = api(endpoint)["branch_policies"]
    for name, kind in sorted(desired):
        if not any(policy["name"] == name and policy["type"] == kind for policy in policies):
            api(endpoint, "POST", {"name": name, "type": kind})
    for policy in policies:
        if (policy["name"], policy["type"]) not in desired:
            api(f"{endpoint}/{policy['id']}", "DELETE")
    print("Configured release environment: owner approval, main/version tags, no admin bypass.")

    # Zero peer approvals supports a solo owner; the release environment is the signing gate.
    ensure_ruleset({
        "name": "Taskmark main protection", "target": "branch", "enforcement": "active",
        "bypass_actors": [],
        "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
        "rules": [
            {"type": "deletion"}, {"type": "non_fast_forward"},
            {"type": "pull_request", "parameters": {
                "required_approving_review_count": 0,
                "dismiss_stale_reviews_on_push": True,
                "require_code_owner_review": False,
                "require_last_push_approval": False,
                "required_review_thread_resolution": True,
            }},
            {"type": "required_status_checks", "parameters": {
                "strict_required_status_checks_policy": True,
                "required_status_checks": [{"context": "swift"}, {"context": "commits"}],
            }},
        ],
    })
    ensure_ruleset({
        "name": "Taskmark release tag protection", "target": "tag", "enforcement": "active",
        # Repository administrator role: the personal repository owner controls release tags.
        "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}],
        "conditions": {"ref_name": {"include": ["refs/tags/*"], "exclude": []}},
        "rules": [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}],
    })
    api(f"{PREFIX}/actions/permissions/workflow", "PUT", {
        "default_workflow_permissions": "read", "can_approve_pull_request_reviews": False,
    })
    print("Configured read-only default workflow token; Actions cannot approve PRs.")
    api(f"{PREFIX}/actions/permissions/fork-pr-contributor-approval", "PUT", {
        "approval_policy": "all_external_contributors",
    })
    api(f"{PREFIX}/actions/permissions", "PUT", {
        "enabled": True, "allowed_actions": "selected", "sha_pinning_required": True,
    })
    api(f"{PREFIX}/actions/permissions/selected-actions", "PUT", {
        "github_owned_allowed": True, "verified_allowed": False, "patterns_allowed": [],
    })
    print("Required external-contributor approval and SHA-pinned, GitHub-owned actions.")
    print("Add the credentials documented in docs/CI_RELEASES.md. No secrets were uploaded.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", required=True,
                        help="Apply owner-reviewed environment, ruleset and workflow-permission settings")
    parser.parse_args()
    try:
        configure()
    except (RuntimeError, KeyError) as error:
        print(f"Setup stopped: {error}", file=sys.stderr)
        print("Earlier successful API changes remain applied; the command is safe to rerun.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
