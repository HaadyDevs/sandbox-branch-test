# sandbox-branch-test

Sandbox for testing the release workflows before they go to the MobieTrain repos.
**Dummy content only.** Nothing here deploys anywhere.

Branches mirror `mobietrain-api`: `develop` (default) → `rc` → `master`.

| Workflow | What it does |
| --- | --- |
| `promote.yml` | **Actions → Promote → Run workflow.** `develop → rc`, `rc → master` (fast-forward), or `cherry-pick → rc`. Dry run by default. |
| `release-please.yml` | On push to `master`: release PR → auto-merge → tag + release → sync `rc` and `develop`. Slack alert on failure. |

Make test commits with `scripts/commit.sh "feat: something"`.

Setup and test scenarios: [docs/TESTING.md](docs/TESTING.md).
