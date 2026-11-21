# Xcode Cloud recon (my-dev @ `8251442`, 2026-11-21)

Read-only findings that the Xcode Cloud setup in `ci_scripts/` is based on. Re-check them after a big `dev` merge.

## 1. Signing config

- `Config.xcconfig` sets `DEVELOPER_TEAM = ##TEAM_ID##` and ends with `#include? "ConfigOverride.xcconfig"` (also `../` and `../../`).
- Every target sets `DEVELOPMENT_TEAM = "$(DEVELOPER_TEAM)"`. The variable to override is **`DEVELOPER_TEAM`**, as the README says.
- `ConfigOverride.xcconfig` is gitignored (`.gitignore` line 83).
- `Config.xcconfig` is the base config of the **project** (Debug and Release), so its settings and the override reach every Trio target. They don't reach submodule or SwiftPM projects.

## 2. Targets

All targets use `CODE_SIGN_STYLE = Automatic`. `BUNDLE_IDENTIFIER = org.nightscout.$(DEVELOPMENT_TEAM).trio`.

| Target | Bundle ID | Deployment target | Entitlements |
|---|---|---|---|
| Trio | `$(BUNDLE_IDENTIFIER)` | iOS 17.6 | `Trio/Resources/Trio.entitlements`: push, HealthKit (+ background delivery), NFC, time-sensitive notifications, app group `$(APP_GROUP_ID)` |
| LiveActivityExtension | `….LiveActivity` | iOS 17.6 | none |
| Trio Watch App | `….watchkitapp` | watchOS 10 | none |
| Trio Watch Complication Extension | `….watchkitapp.TrioWatchComplication` | watchOS 10 | none |
| TrioTests, Trio Watch AppTests | `….TrioTests`, `….TrioWatchAppTests` | not archived | none |

App group: `TRIO_APP_GROUP_ID = group.org.nightscout.$(DEVELOPMENT_TEAM).trio.trio-app-group`.

Version: `APP_VERSION = 1.0.2`, `APP_DEV_VERSION = 1.0.2.79`, `APP_BUILD_NUMBER = 1` (Trio target `CURRENT_PROJECT_VERSION = $APP_BUILD_NUMBER`). The other targets hard-code `CURRENT_PROJECT_VERSION = 1`.

## 3. Xcode version

- The browser build (`build_trio.yml`) selects **Xcode 26.5** on `macos-26`.
- `objectVersion = 70`, `LastUpgradeCheck = 1620`. There's no `.xcode-version` file.

## 4. What the browser build does beyond a plain archive

| Step | Where | Xcode Cloud equivalent |
|---|---|---|
| Syncs the fork with upstream (scheduled) | `build_trio.yml` | Dropped. I sync `dev` and merge it into `my-dev` by hand (MY-DEV.md). |
| Applies `patches/*` with `git apply` | `build_trio.yml` | Dropped. `my-dev` carries its patches as merges, and `patches/` only has the placeholder `.md`. |
| `DEV_BRANCH_WARNING_DISABLED` via ConfigOverride | `build_trio.yml` | Optional workflow variable `DEV_BRANCH_WARNING_DISABLED=true` (`write_config_override.sh`). |
| `update_project_team` (writes the team into pbxproj) | Fastfile | `DEVELOPER_TEAM` in a generated `ConfigOverride.xcconfig`, from `CI_TEAM_ID`. |
| Build number = latest TestFlight + 1 | Fastfile | Xcode Cloud's own build counter. Set **Next Build Number** in App Store Connect once. |
| `match` + manual profiles for 4 bundle IDs | Fastfile | Dropped. Xcode Cloud uses cloud-managed certificates with automatic signing. |
| `identifiers` lane creates bundle IDs and capabilities | Fastfile | Not needed: they already exist from the browser build. Check them in the portal. |
| TestFlight "What to Test" = `branch dev_version sha` | Fastfile `release` | `ci_post_xcodebuild.sh` writes `TestFlight/WhatToTest.en-US.txt`. |
| Bundled release notes appended to TestFlight notes (main only) | Fastfile `release` | Dropped. They only apply off `main`. |
| Build phase: SwiftFormat, skipped when `CI = "true"` | `scripts/swiftformat.sh` | Xcode Cloud sets `CI=TRUE` (uppercase), so this would run. The override sets the build setting `CI = true` so it skips. |
| Build phase: Crashlytics dSYM upload, skipped when `CI = "true"` | pbxproj | Same as above. |
| Build phase: `capture-build-details.sh` (branch, sha, submodules into BuildDetails.plist) | pbxproj | Runs as is. `ci_post_clone.sh` checks out a local branch so it records `my-dev` instead of `detached`. |
| Build phase: `capture-release-notes.sh` (GitHub API, never fails) | pbxproj | Runs as is, unauthenticated. |

## 5. Submodules

16 submodules (the plan said 11), all public HTTPS on github.com. On `my-dev`, `OmnipodKit` points at `https://github.com/ssabo/omnipodkit` (public, checked with `git ls-remote`). Apple says public submodules need no setup.

## 6. Existing files

There was no `ci_scripts/`, no `.xcode-version` and no `TestFlight/` directory.

## Surprises compared with the plan

- **`CI_TEAM_ID` is built in.** Xcode Cloud provides the team ID, so no `TEAM_ID` workflow variable is needed. `TEAM_ID` still works as an override.
- **`CI=TRUE` vs `"true"`.** Without the override, SwiftFormat would run `swift run` against `BuildTools` (slow, needs network, reformats sources in the build checkout), and the Crashlytics upload would run.
- **16 submodules, not 11**, and one of them is my fork.
- **Only the Trio target has an entitlements file.** The watch targets and LiveActivity don't request the app group at build time. The portal's app-group setup from the browser build is fine as it is.
- **Two `Package.resolved` files disagree.** The workspace's file (`Trio.xcworkspace/xcshareddata/swiftpm/`) has TidepoolKit, BigInt and ASN1. The project's file is stale. Xcode Cloud builds the workspace, which uses the workspace file. **VERIFY** in the first build log that package resolution doesn't complain.
- **The branch is `my-dev`, not a new `xcode-cloud` branch**, per your instructions. The CI files merge into `my-dev`.
