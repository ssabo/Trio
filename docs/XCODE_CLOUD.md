# Xcode Cloud builds of my-dev

Xcode Cloud archives `my-dev` and uploads it to TestFlight for internal testing. It replaces the GitHub Actions browser build (fastlane, match, 6 secrets). Apple manages signing, so no certificates, API key, `GH_PAT` or `MATCH_PASSWORD` are involved.

This is unofficial. Trio's docs only cover the browser build and Xcode. Items marked **VERIFY** are assumptions to check on the first run. The recon behind this setup is in [`xcode-cloud-recon.md`](xcode-cloud-recon.md).

## What's in the repo

| File | Runs | What it does |
|---|---|---|
| `ci_scripts/ci_post_clone.sh` | after clone | Syncs and updates all submodules and fails if any isn't at its pin. Checks out a local branch so `BuildDetails.plist` records `my-dev`, not `detached`. Writes `ConfigOverride.xcconfig`. |
| `ci_scripts/ci_pre_xcodebuild.sh` | before each `xcodebuild` | Writes `ConfigOverride.xcconfig` again. Apple says files a script creates may not survive to later steps. |
| `ci_scripts/ci_post_xcodebuild.sh` | after each `xcodebuild` | For App Store signed archives, writes `TestFlight/WhatToTest.en-US.txt`: `<branch> <APP_DEV_VERSION> <sha>`, the commit subject and the Xcode Cloud build number. |
| `ci_scripts/write_config_override.sh` | helper | Generates the gitignored `ConfigOverride.xcconfig` (see below). |

The generated `ConfigOverride.xcconfig` contains:

- `DEVELOPER_TEAM = $CI_TEAM_ID`. Xcode Cloud provides the team ID. A `TEAM_ID` workflow variable overrides it.
- `CI = true`. Xcode Cloud sets `CI=TRUE`, but the SwiftFormat and Crashlytics build phases only skip when `CI` is `"true"`. Build settings are exported to run-script phases, so this makes them skip as they do on GitHub Actions. **VERIFY** in the log that the phases print `CI detected - skipping …`.
- With the workflow variable `DEV_BRANCH_WARNING_DISABLED=true`: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEV_BRANCH_WARNING_DISABLED`. This hides the "not built from main" startup alert, like the browser build's repository variable.

No app, watch, widget or submodule source is changed.

## Workflow settings at a glance

| Setting | Value | Where |
|---|---|---|
| Workflow name | `Trio TestFlight` | Xcode → Report navigator → Cloud → Manage Workflows |
| Source | `ssabo/Trio`, branch `my-dev` | Workflow → Start Conditions |
| Xcode | 26.5 (what `build_trio.yml` uses), or the closest available | Workflow → Environment |
| Env vars | none required. Optional: `DEV_BRANCH_WARNING_DISABLED=true`, `TEAM_ID` | Workflow → Environment → Environment Variables |
| Start conditions | Manual only to begin with. Add a schedule after Phase 3 passes. | Workflow → Start Conditions |
| Action | Archive, iOS, scheme `Trio`, Distribution Preparation: TestFlight (Internal Testing Only) | Workflow → Actions |
| Post-action | TestFlight Internal Testing → my internal group | Workflow → Post-Actions |
| Next build number | higher than the last browser build upload | App Store Connect → app → Xcode Cloud → Settings → Build Number |

## One-time setup (on the Mac)

1. **Role.** In App Store Connect → Users and Access, confirm I'm **Account Holder or Admin**. One of those is needed to turn on Xcode Cloud the first time.
2. **Merge this PR into `my-dev`**, so the workflow can build `my-dev` directly.
3. **Check identifiers.** The browser build's `identifiers` lane already created them. In the Developer portal → Identifiers, check that these exist for my team ID:
   - `org.nightscout.TEAMID.trio`, with App Groups, HealthKit, NFC Tag Reading, Push Notifications and Time Sensitive Notifications
   - `org.nightscout.TEAMID.trio.LiveActivity`
   - `org.nightscout.TEAMID.trio.watchkitapp`
   - `org.nightscout.TEAMID.trio.watchkitapp.TrioWatchComplication`
   - App Group `group.org.nightscout.TEAMID.trio.trio-app-group` on Trio (Watch App and Complication too, per the browser-build docs)

   Don't rename or change any of them. The same bundle ID is what makes the build install over the current app with settings kept.
4. **App record.** Use the existing App Store Connect app (bundle ID `org.nightscout.TEAMID.trio`) that the browser build uploads to. Don't create a new one.
5. **Open the workspace locally once.** Open `Trio.xcworkspace` in Xcode 26.5 on `my-dev` after running `git submodule sync --recursive && git submodule update --init --recursive`. A local `ConfigOverride.xcconfig` with `DEVELOPER_TEAM = <team id>` is needed for a local build, but Xcode Cloud doesn't use it. Let Xcode resolve packages, and don't commit `*.xcscheme`, `*.xcstrings` or `Package.resolved` churn.
6. **Create the workflow.** Report navigator → Cloud → Get Started (or Product → Xcode Cloud → Create Workflow). Pick the **Trio** product, app, and scheme. When asked, grant Xcode Cloud access to `ssabo/Trio` through Apple's GitHub app. Public submodules (including `ssabo/omnipodkit`) need no extra access. Then edit the default workflow to match the table above:
   - **Remove the default "Branch Changes" start condition**, or every push to `my-dev` uploads a TestFlight build. Add **Manual Start** on branch `my-dev`.
   - Environment: Xcode 26.5 if offered. **VERIFY** it's in the list, and pick the closest otherwise.
   - Archive: Distribution Preparation **TestFlight (Internal Testing Only)**.
   - Post-action: **TestFlight Internal Testing** → my existing internal group.
7. **Build number.** Before the first run, open TestFlight in App Store Connect and note the highest build number under version **1.0.2** (the browser build used "latest + 1"). Then go to App Store Connect → the app → **Xcode Cloud** → Settings → **Build Number** and set Next Build Number to a higher number. Without this, Xcode Cloud starts at 1 and the upload is rejected as a duplicate version and build.
8. **Turn off TestFlight auto-updates for Trio on the phone** (TestFlight app → Trio → Automatic Updates). Then a scheduled build never replaces the running AID app by surprise.
9. **First build.** Start it manually (Report navigator → Cloud → the workflow → Start Build). Read the logs against Phase 3 below.

## Phase 3 checks (before adding a schedule)

- [ ] `ci_post_clone.sh` prints `16 submodules at their pinned commits` and `Checked out local branch my-dev`.
- [ ] SwiftFormat and Crashlytics phases print `CI detected - skipping …`.
- [ ] SwiftPM resolution works from the workspace `Package.resolved` (**VERIFY**: the project-level `Package.resolved` is out of date).
- [ ] The archive includes the Watch app and LiveActivity (Xcode Cloud build → Artifacts).
- [ ] The build shows in TestFlight with "What to Test" = `my-dev 1.0.2.xx <sha>`.
- [ ] It installs over the current Trio, and settings, pump and CGM pairing survive. Keep the previous TestFlight build installable, and do the swap at a calm time.
- [ ] App group sharing still works (watch app, xDrip4iOS if used). In Trio → Settings, the build details show branch `my-dev` and the right commit.
- [ ] Note the compute time per build. The free tier is 25 compute hours a month.

## Keeping a build from expiring

TestFlight builds expire after 90 days. Pick one:

- **Schedule (after Phase 3 passes).** Add an "On a Schedule" start condition for `my-dev`. **VERIFY** the available frequencies. I believe they're hourly, daily and weekly, with no monthly option. Weekly costs about 4 builds a month, which is still a small part of 25 hours. Keep auto-updates off (step 8) so I choose when to install.
- **Calendar reminder.** Start a build by hand at least every ~60 days. Set a reminder either way.

## Updating my-dev and rebuilding

1. Sync `dev` by hand and merge it into `my-dev`, with the patch handling in [MY-DEV.md → Merging a newer dev into my-dev](../MY-DEV.md#merging-a-newer-dev-into-my-dev).
2. The `ci_scripts/` and `docs/` files exist only on `my-dev`, and upstream doesn't touch them, so they shouldn't conflict. If `dev` ever adds its own `ci_scripts/` or `TestFlight/`, look at it before merging.
3. Push `my-dev`, then start **Trio TestFlight** manually (or wait for the schedule).
4. After a big merge, re-check `docs/xcode-cloud-recon.md`: the Xcode version in `build_trio.yml`, new build phases, new targets or bundle IDs, new submodules.

## Rollback to the browser build

Nothing here touches `.github/` or fastlane. Until cutover, the GitHub Actions build and its 6 secrets stay as they are.

- If Xcode Cloud fails, run **4. Build Trio** in GitHub Actions as before.
- If an Xcode Cloud build misbehaves, install the previous build from TestFlight (TestFlight → Trio → Previous Builds).
- Build-number note: after Xcode Cloud uploads, the browser build's "latest TestFlight + 1" keeps working, because fastlane reads the latest number from TestFlight.

## Cutover (later, needs my OK)

1. Get two good Xcode Cloud builds, one manual and one scheduled.
2. Then consider turning off GitHub Actions on the fork (Settings → Actions → Disable), so the Sunday `build_trio.yml` schedule doesn't email failures once secrets are gone. Not done here.
3. Only after confirming: delete the 6 repo secrets and the `Match-Secrets` repo.
