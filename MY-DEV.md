# my-dev: Trio `dev` + my patches under test

`my-dev` is my personal build branch: a recent copy of [nightscout/Trio `dev`](https://github.com/nightscout/Trio/tree/dev) with the patches I'm testing or trying to upstream merged on top. I build and run it on my phone.

- **Never open an upstream PR from this branch.** Each patch lives on its own branch, which is what gets upstreamed.
- This file exists only on `my-dev`. Keep it out of patch branches.
- Submodule patches are tracked here too. Their repos have no copy of this file.

**Overview:** [ssabo/Trio#5](https://github.com/ssabo/Trio/pull/5) is a draft PR of `my-dev` against `dev`, labeled `do not merge`. It's only there to view the full diff in one place.

**Last synced with `dev`:** 2026-11-20, nightscout/Trio `dev` at `d37fe347e` (APP_DEV_VERSION 1.0.2.79)

## Applied patches

| ID | Repo | Patch branch (in my fork) | Base | What it does | Upstream PR | Upstream status | Depends on | Drop when | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `omnipod-approx-reservoir` (Trio side) | Trio | [`feature/omnipod-approximate-reservoir`](https://github.com/ssabo/Trio/tree/feature/omnipod-approximate-reservoir) | `dev` | The home screen shows an estimated Omnipod reservoir level (`~145 U`) instead of `50+ U` | Not opened yet | Waits on OmnipodKit#217 | `omnipod-approx-reservoir` (OmnipodKit side) | The upstream Trio PR is merged into `dev` | Points `.gitmodules` at the ssabo/omnipodkit fork. Squash the commits before upstreaming; the first one adds an estimator that the second one removes. Fork PR, for viewing only: [ssabo/Trio#3](https://github.com/ssabo/Trio/pull/3) |
| `omnipod-approx-reservoir` (OmnipodKit side) | OmnipodKit (submodule) | [`feat/approximate-reservoir-next-dev`](https://github.com/ssabo/omnipodkit/tree/feat/approximate-reservoir-next-dev) | OmnipodKit `next-dev` @ `6fdf0e0` | Adds a pod fill amount setting and `OmniPumpManager.approximateReservoirLevel` | [loopandlearn/OmnipodKit#217](https://github.com/loopandlearn/OmnipodKit/pull/217) (base `next-dev`) | Open, in review | none | #217 is merged and Trio `dev` pins a commit that includes it | Pinned at `2ff767f`. Upstream `next-dev` has moved past `6fdf0e0` (`dc8b923`, with async PumpManagerDelegate and doseId changes), so #217 may need a rebase. Replaces [#213](https://github.com/loopandlearn/OmnipodKit/pull/213) (closed). |
| `watch-running-preset` | Trio | [`claude/nifty-hamilton-fctxkb`](https://github.com/ssabo/Trio/tree/claude/nifty-hamilton-fctxkb) | `dev` @ `d37fe347e` | Watch: tapping the preset that's already running closes the sheet instead of opening a stuck screen | Not opened yet | Not opened yet | none | Merged upstream | Not built or tested yet. Fork PR, for viewing only: [ssabo/Trio#4](https://github.com/ssabo/Trio/pull/4) |

### Submodule overrides on my-dev

These are the submodules that `my-dev` points somewhere other than `dev` does. Everything else matches `dev`.

| Submodule | `dev` uses | `my-dev` uses | For patch |
|---|---|---|---|
| OmnipodKit | `loopandlearn/OmnipodKit`, `next-dev` @ `6fdf0e0` | `ssabo/omnipodkit`, `feat/approximate-reservoir-next-dev` @ `2ff767f` | `omnipod-approx-reservoir` |

After checking out `my-dev`, or after a merge that changes `.gitmodules`, run these so the submodule uses the fork's URL:

```bash
git submodule sync --recursive
```

```bash
git submodule update --init --recursive
```

### Retired branches

| Branch | Why it was retired |
|---|---|
| ssabo/omnipodkit `feat/approximate-reservoir` (`a144627`) | The OmnipodKit patch written against `dev`, then merged with `next-dev`. It's replaced by `feat/approximate-reservoir-next-dev`, which has the same feature code. Keep the branch for history and don't build from it. Its upstream PR, #213, is closed. |

## Why OmnipodKit doesn't need a dev branch and a next-dev branch

Trio `dev` already pins OmnipodKit **`next-dev`**, not OmnipodKit `dev`, and `.gitmodules` says `branch = next-dev`. The upstream PR (#217) targets `next-dev`, so one branch, `feat/approximate-reservoir-next-dev`, covers both my build and upstreaming.

Rule for submodule patches: **base the patch on whatever branch Trio `dev` pins for that submodule.** That's usually `next-dev` or `trio-next-dev` for the loopandlearn kits, and matches what upstream wants. A second "personal" branch is only needed if Trio `dev` pins a commit that the upstream PR's base doesn't contain.

## Adding a patch

1. Make a branch for the patch from current `dev`, or from the branch Trio `dev` pins for a submodule, in my fork.
2. For a submodule patch: push the branch to my fork of the submodule. On the Trio patch branch, point `.gitmodules` at the fork with `branch = <patch branch>`, and commit the new pin.
3. Merge it into `my-dev` with a merge commit, so each patch is one revertible unit:

   ```bash
   git switch my-dev && git merge --no-ff -m "Patch: <id> (<branch>)" <branch>
   ```

4. Add a row to the table above, and a submodule override row if needed.

## Merging a newer dev into my-dev

`rerere` is enabled in this clone (`git config rerere.enabled true`), so a conflict resolved once is reused on later merges.

1. Fetch:

   ```bash
   git fetch upstream && git -C OmnipodKit fetch origin && git -C OmnipodKit fetch ssabo
   ```

2. **Update the patch branches first**, so they stay upstreamable and conflicts are solved where they belong. For each Trio patch branch, run `git merge upstream/dev`, or rebase if no one else has the branch and the upstream PR isn't open yet.
3. **Check whether `dev` moved a submodule that has a patch.** Run `git diff <last synced sha> upstream/dev -- .gitmodules OmnipodKit`. If `dev` now pins a newer OmnipodKit commit `X`:
   - In `OmnipodKit`, bring the patch branch up to `X`. Rebase it if the upstream PR is still being reworked, otherwise merge `X` into it. Push it to the fork, which also updates #217.
   - On the Trio patch branch, pin the new patch commit, and keep the fork URL in `.gitmodules`.
4. Merge into `my-dev`:

   ```bash
   git switch my-dev && git merge upstream/dev
   ```

   Then merge each updated patch branch. Expected conflict spots:
   - **`.gitmodules` / the `OmnipodKit` gitlink:** always keep the fork URL and the patch branch's pin, unless the patch has landed upstream (see the next step).
   - **`Localizable.xcstrings`:** keep both sides' keys.
5. **Patches that landed upstream:** when `dev` contains a patch, merging `dev` brings it in. Delete its row, and move it to Retired. For a submodule patch, also restore the loopandlearn URL and branch in `.gitmodules`, and take `dev`'s pin.
6. Run `git submodule sync --recursive && git submodule update --init --recursive`, then build, run on the phone, update **Last synced** at the top, and push.

### Removing a patch without waiting for upstream

```bash
git revert -m 1 <the "Patch: ..." merge commit>
```

To bring it back later, revert that revert. Merging the branch again won't reapply the changes git already considers merged.

## Xcode Cloud builds

`my-dev` is built in Xcode Cloud and uploaded to internal TestFlight, replacing the GitHub Actions browser build. Full runbook: [docs/XCODE_CLOUD.md](docs/XCODE_CLOUD.md). Recon notes: [docs/xcode-cloud-recon.md](docs/xcode-cloud-recon.md).

- **What's on `my-dev` for it:** `ci_scripts/` (post-clone, pre-xcodebuild, post-xcodebuild and a helper) and the two docs. No app or submodule source changes. Like this file, these exist only on `my-dev`, so keep them out of patch branches.
- **Signing:** Apple-managed automatic signing. The scripts generate the gitignored `ConfigOverride.xcconfig` from Xcode Cloud's `CI_TEAM_ID`, so no team ID or secret is committed.
- **Workflow:** `Trio TestFlight`, branch `my-dev`, manual start (a schedule comes later), archive → TestFlight internal group.
- **Updating:** after the merge steps above, push `my-dev`, then start the workflow in Xcode (Report navigator → Cloud). Keep TestFlight auto-updates off on the phone, so I choose when a new build gets installed.
- **Fallback:** the GitHub Actions browser build and its secrets stay untouched until two Xcode Cloud builds have worked.

## Local setup notes

- `origin` is `ssabo/Trio`, and `upstream` is `nightscout/Trio`. Inside `OmnipodKit`, `origin` is loopandlearn and `ssabo` is my fork.
- Xcode rewrites `*.xcscheme` and `*.xcstrings` when it builds. Don't commit those changes to `my-dev` or to patch branches.
