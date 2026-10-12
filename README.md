# sandbox-branch-test

Sandbox for testing the release workflows before they go to the MobieTrain repos.
**Dummy content only.** Nothing here deploys anywhere.

Branches mirror `mobietrain-api`: `develop` (default) → `rc` → `master`.

| Workflow | What it does |
| --- | --- |
| `promote.yml` | **Actions → Promote → Run workflow.** `develop → rc`, `rc → master` (fast-forward), or `cherry-pick → rc`. Dry run by default. |
| `release.yml` | On push to `master`: semantic-release creates the next `v*` tag and a GitHub Release from the conventional commits. **No release commit**, so nothing has to be merged back. |

Release notes live on the [Releases page](https://github.com/HaadyDevs/sandbox-branch-test/releases). Builds take the version from the tag (`npm pkg set version=${TAG#v}`), not from `package.json`.

Make test commits with `scripts/commit.sh "feat: something"`.

Setup and test scenarios: [docs/TESTING.md](docs/TESTING.md).
