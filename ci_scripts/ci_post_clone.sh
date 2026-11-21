#!/bin/sh
# Xcode Cloud: runs after the repository is cloned.
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

echo "Branch: ${CI_BRANCH:-unknown}  Commit: ${CI_COMMIT:-unknown}  Build: ${CI_BUILD_NUMBER:-unknown}"

# my-dev points some submodules at forks (see MY-DEV.md), so sync URLs from
# .gitmodules before updating, then make sure every pinned submodule is present.
git submodule sync --recursive
git submodule update --init --recursive

echo "Submodules:"
git submodule status
# '-' = not checked out, '+' = checked out at a commit other than the pin, 'U' = conflict.
if git submodule status | grep -q '^[-+U]'; then
    echo "error: a submodule is missing or not at its pinned commit (see the list above)." >&2
    exit 1
fi
echo "$(git submodule status | wc -l | tr -d ' ') submodules at their pinned commits."

# Xcode Cloud checks out a detached HEAD. scripts/capture-build-details.sh records the
# branch name in BuildDetails.plist (shown in Trio's settings), and would record
# "detached". Put a local branch at the same commit so the real name is recorded.
if [ -n "${CI_BRANCH:-}" ] && ! git symbolic-ref -q HEAD > /dev/null; then
    git checkout -q -B "$CI_BRANCH"
    echo "Checked out local branch $CI_BRANCH at $(git rev-parse --short HEAD)."
fi

"$REPO/ci_scripts/write_config_override.sh"
