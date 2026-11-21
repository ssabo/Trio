#!/bin/sh
# Xcode Cloud: runs before each xcodebuild action.
# Apple says files a custom script creates may not be available to later scripts,
# so write ConfigOverride.xcconfig again right before building. It's idempotent.
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
"$REPO/ci_scripts/write_config_override.sh"
