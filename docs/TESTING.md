# Testing the release workflows

Everything here runs on GitHub only. There are no Cloud Build triggers, so nothing deploys.

## 1. One-time setup on GitHub

Do these after pushing `master`, `rc` and `develop`.

### Repository settings (Settings → General)
- **Default branch:** `develop` (the Promote button only appears for workflows on the default branch).
- **Pull Requests:** allow **squash merging** only (like `mobietrain-api`), tick **Allow auto-merge** and **Automatically delete head branches**.

### Actions (Settings → Actions → General)
- **Workflow permissions:** *Read and write permissions*.
- Tick **Allow GitHub Actions to create and approve pull requests** (release-please needs it to open the release PR).

### Bot identity (pick one)
- **GitHub App (preferred):** Settings → Developer settings → GitHub Apps → New. No webhook. Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**. Install it on this repo only. Generate a private key.
  - Variable `RELEASE_BOT_APP_ID` = the App ID
  - Secret `RELEASE_BOT_PRIVATE_KEY` = the private key (.pem contents)
- **Fine-grained PAT (quick start):** this repo only, **Contents: Read and write**, **Pull requests: Read and write**.
  - Secret `RELEASE_BOT_TOKEN`

### Environments (Settings → Environments)
Create three. Put the bot variable/secrets above **in each environment** (not as repo secrets), so only these jobs can use them.

| Environment | Deployment branches | Used by | Extra |
| --- | --- | --- | --- |
| `release` | `master` only | auto-merge, sync | add secret `SLACK_CI_WEBHOOK_URL` |
| `promote-staging` | `develop` only | Promote: `develop → rc`, `cherry-pick → rc` | — |
| `promote-production` | `develop` only | Promote: `rc → master` | optional: required reviewer |

### Variables (Settings → Secrets and variables → Actions → Variables)
- `SYNC_MODE` = `merge` or `rebase` (default `merge`)
- `AUTO_MERGE_RELEASE_PR` = `false` to turn off auto-merge (default on)

### Label
- Create a label named `release: hold`.

### Branch protection (Settings → Branches), mirroring `mobietrain-api`

| Branch | Require PR + reviews | Require linear history | Allow force pushes |
| --- | --- | --- | --- |
| `develop` | yes, 1 | **depends on SYNC_MODE** (below) | only for `rebase` mode |
| `rc` | yes, 1 | **depends on SYNC_MODE** | no |
| `master` | yes, 1 | no | **no** |

- `SYNC_MODE=merge` needs **linear history OFF** on `develop` and `rc` (merge commits flow to `rc` at the next promotion).
- `SYNC_MODE=rebase` keeps **linear history ON**, and needs **force pushes allowed** on `develop`.
- Leave "Do not allow bypassing the above settings" **unticked**, so you (admin) and a PAT acting as you can push directly while testing alone.
- If you use the App: add it to the bypass list if GitHub offers it. If its pushes are rejected, that's a finding (personal repos have limited bypass options); switch to the PAT to keep testing.

## 2. Making test commits

Push straight to `develop` (admin bypass) or via PRs:

```bash
git switch develop
scripts/commit.sh "feat: add a thing"
git push origin develop
```

`scripts/commit.sh "<message>" <file>` appends to `<file>` instead of `src/changes.txt`.

## 3. Scenarios

Check each run's **summary** page (Actions → the run) and Slack.

### S1. Normal release, nothing new on develop
1. `scripts/commit.sh "feat: first feature"`, push `develop`.
2. Promote `develop → rc`, dry run ✅. **Expect:** a table with 1 commit, nothing pushed.
3. Promote `develop → rc`, dry run ☐. **Expect:** `rc` moves to that commit.
4. Promote `rc → master`. **Expect:** `master` moves.
5. **Expect:** release-please opens `chore(master): release 1.1.0`, auto-merge approves and merges it within a minute, a `v1.1.0` tag and GitHub Release appear, and the sync job fast-forwards `rc` and `develop`. All three branches end on the release commit.

### S2. develop gets new work while a release goes out
1. Commit A (`feat: A`), push `develop`, then commit B (`fix: B`), push `develop`.
2. Promote `develop → rc` **up to A** (A's hash in *Up to commit*), then `rc → master`.
3. Release happens. `develop` has B, so it can't fast-forward.
4. **Expect, by setting:**
   - `merge` mode + linear history **ON** → push rejected, Slack 🚨. *(This is the problem we found on mobietrain-api.)*
   - `merge` mode + linear history **OFF** → merge commit `chore: sync release … into develop`.
   - `rebase` mode + linear ON + force push allowed → B rebased onto the release, Slack ℹ️ "develop was rebased".
5. Then promote `develop → rc` and `rc → master`. **Expect:** both fast-forward.

### S3. Cherry-pick one ready commit over untested ones
1. Commit X (`feat: X not ready`), then Y (`fix: Y ready`, in another file: `scripts/commit.sh "fix: Y ready" src/y.txt`), push.
2. Promote `cherry-pick → rc` with Y's hash in *Commits to cherry-pick*, dry run first. **Expect:** Y copied, X listed as left behind.
3. `rc → master`, release, sync.
4. **Expect:** `develop` reconverges (merge or rebase, per `SYNC_MODE`). In merge mode Y appears twice in history; in rebase mode the original Y is dropped.

### S4. Conflict during sync
1. On `develop`, edit `"version"` in `package.json` by hand and commit `chore: bump version by hand`, push.
2. Release something via S1 steps 2–4.
3. **Expect:** sync fails on `develop`, nothing pushed, Slack 🚨 naming `package.json`.

### S5. Holding a release
1. Set `AUTO_MERGE_RELEASE_PR=false`, promote a `feat:` to `master`. **Expect:** the release PR stays open.
2. Add the `release: hold` label, set `AUTO_MERGE_RELEASE_PR` back to `true` (or delete it), promote another commit to `master`.
3. **Expect:** auto-merge skips the PR ("has the release: hold label").
4. Remove the label, promote again. **Expect:** it merges.

### S6. Refusals
- Promote with a made-up hash. **Expect:** "does not exist".
- `rc → master` with a commit only on `develop`. **Expect:** "is not on rc".
- Push a commit straight to `rc`, then `develop → rc`. **Expect:** "rc has commits that … does not contain".
- Fill *Commits to cherry-pick* with `develop → rc` selected (or *Up to commit* with `cherry-pick → rc`). **Expect:** refused, naming the right field.
- Set *Use workflow from* to `rc`. **Expect:** refused, "Run this workflow from develop".

### S7. Changelog config is used
1. `scripts/commit.sh "docs: explain the sandbox"` plus a `feat:`, promote, release.
2. **Expect:** `CHANGELOG.md` and the GitHub Release list the docs commit under **Documentation**. (On `mobietrain-api`, docs/test commits never appear, which suggests its config isn't applied.)

### S8. Secrets are locked to the right branches
1. On a new branch, add a workflow with `environment: release` that prints whether `secrets.RELEASE_BOT_PRIVATE_KEY` (or `RELEASE_BOT_TOKEN`) is set, and run it.
2. **Expect:** GitHub refuses the deployment ("branch is not allowed to deploy to release"), so the token can't leak to other branches.
