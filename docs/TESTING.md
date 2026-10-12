# Testing the release workflows

Everything here runs on GitHub only. There are no Cloud Build triggers, so nothing deploys.

## How releases work now

- `develop → rc → master` move by **fast-forward** only (Promote button).
- On every push to `master`, **semantic-release** (`.github/workflows/release.yml`, config `.releaserc.json`) reads the commits since the last `v*` tag and, if any are releasable, creates the next tag and a **GitHub Release** with the notes.
  - `feat:` → minor, `fix:` / `perf:` → patch, `!` or `BREAKING CHANGE:` → major.
  - `chore:`, `docs:`, `ci:`, `test:`, `refactor:` … → no release.
- **Nothing is committed back**, so `rc` and `develop` never need syncing after a release. No release PR, no release commit, no merge commits from releases.
- `CHANGELOG.md` is frozen at v1.3.0; the Releases page is the changelog from then on.
- In a real repo, the build sets the version from the tag before building: `npm pkg set version=${TAG#v}`.

The only remaining back-merges come from a **hotfix into `rc`** or a **cherry-pick**: `rc` then has a commit `develop` lacks, so merge `rc` into `develop` by hand once.

## 1. Setup on GitHub

Already done for the earlier tests. What matters now:

- **Default branch:** `develop`.
- **Actions → General → Workflow permissions:** *Read and write*.
- **Secret** `RELEASE_BOT_TOKEN` (fine-grained PAT, this repo only, **Contents: Read and write**). Used by Promote and by `release.yml`.
- **Branch protection:** force pushes **off** everywhere. **Require linear history** must stay **OFF** on `develop` and `rc`: releases no longer create merge commits, but merging `rc` back into `develop` after a hotfix or cherry-pick (T5, T6) still does, and that merge commit reaches `rc` at the next promotion. `master` can have it either way.

No longer used (safe to delete): variables `SYNC_MODE` and `AUTO_MERGE_RELEASE_PR`, label `release: hold`, environment `release`.

## 2. Making test commits

```bash
git switch develop
scripts/commit.sh "feat: add a thing"
git push origin develop
```

`scripts/commit.sh "<message>" <file>` appends to `<file>` instead of `src/changes.txt`.

## 3. Scenarios

Check each run's **summary/log** (Actions → the run) and the **Releases** page.

### T1. Preview the next release (dry run)
1. Actions → **release** → Run workflow, *Use workflow from* `master`, dry run ✅.
2. **Expect:** the log names the last release (`v1.3.0`) and either "no release" or the next version with its notes. Nothing is tagged.

### T2. Normal release, continuing the numbering
1. `scripts/commit.sh "feat: T2 feature"`, push `develop`.
2. Promote `develop → rc`, then `rc → master`.
3. **Expect:** tag `v1.4.0` and a GitHub Release with "T2 feature" under **Features**.
4. **Expect:** **no new commit** on `master`; `master`, `rc` and `develop` are all at the same commit. Nothing to sync.

### T3. Non-releasable commits don't release
1. `scripts/commit.sh "docs: T3 docs only"`, push, promote to `master`.
2. **Expect:** the release run says no release; no new tag.
3. Then `scripts/commit.sh "fix: T3 fix"`, push, promote. **Expect:** `v1.4.1` lists only the fix.

### T4. develop gets new work while a release goes out (the old back-merge case)
1. Commit A (`feat: A`), push, then B (`fix: B`), push.
2. Promote `develop → rc` **up to A**, then `rc → master`. **Expect:** release with A only.
3. **Expect:** `develop` is untouched and still fast-forwards later: promote `develop → rc`, `rc → master`. **Expect:** the next release lists **B** (counted by history, not by date, so nothing is skipped).

### T5. Hotfix branched from rc
1. `git switch -c hotfix/t5 origin/rc`, `scripts/commit.sh "fix: T5 hotfix"`, push the branch, PR into `rc`, merge (or push to `rc` directly).
2. Promote `rc → master`. **Expect:** a patch release with the hotfix.
3. Merge `rc` into `develop` once: `git switch develop && git merge origin/rc && git push origin develop`.
4. Promote `develop → rc` later. **Expect:** fast-forward; the hotfix is **not** listed again (it's already in the last tag's history).

### T6. Cherry-pick (expect a duplicate in the notes)
1. Commit X (`feat: X not ready`), then Y (`fix: Y ready` in `src/y.txt`), push.
2. `cherry-pick → rc` with Y, then `rc → master`. **Expect:** a release with Y.
3. Merge `rc` into `develop` (as in T5 step 3), and later promote everything.
4. **Expect:** the next release lists X **and Y again** (the original Y reaches `master` with a different hash). This is why hotfixes from `rc` (T5) are preferred over cherry-picks.

### T7. Refusals (Promote)
- A made-up hash. **Expect:** "does not exist".
- `rc → master` with a commit only on `develop`. **Expect:** "is not on rc".
- A commit pushed straight to `rc`, then `develop → rc`. **Expect:** "rc has commits that … does not contain".
- *Commits to cherry-pick* filled with `develop → rc` selected (or *Up to commit* with `cherry-pick → rc`). **Expect:** refused, naming the right field.
- *Use workflow from* set to `rc`. **Expect:** "Run this workflow from develop".
- `cherry-pick → rc` with only an empty commit. **Expect:** refused. With a real commit too: the real one is copied, the empty one listed under *Skipped*.
- `cherry-pick → rc` the same commit twice. **Expect:** the second run is refused, "already on rc as a cherry-picked copy (…)".
