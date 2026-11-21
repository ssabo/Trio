#!/bin/sh
# Xcode Cloud: runs after each xcodebuild action, even when it failed.
# For an archive that will go to TestFlight, writes the "What to Test" notes:
# branch, dev version and commit, like the browser build's fastlane release lane.
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

if [ -z "${CI_APP_STORE_SIGNED_APP_PATH:-}" ] || [ ! -d "$CI_APP_STORE_SIGNED_APP_PATH" ]; then
    echo "No App Store signed app; skipping TestFlight notes."
    exit 0
fi

branch="${CI_BRANCH:-$(git symbolic-ref --short -q HEAD || echo detached)}"
commit="$(git rev-parse --short=7 HEAD)"
dev_version="$(sed -n 's/^APP_DEV_VERSION *= *//p' Config.xcconfig | head -n 1)"
subject="$(git log -1 --format=%s)"

# Apple: the TestFlight folder sits next to the workspace, i.e. the repo root.
mkdir -p TestFlight
{
    echo "$branch $dev_version $commit"
    echo ""
    echo "$subject"
    echo ""
    echo "Xcode Cloud build ${CI_BUILD_NUMBER:-?}, workflow ${CI_WORKFLOW:-?}"
} > TestFlight/WhatToTest.en-US.txt

echo "TestFlight notes:"
sed 's/^/    /' TestFlight/WhatToTest.en-US.txt
