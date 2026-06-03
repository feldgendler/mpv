#!/usr/bin/env bash
#
# Rebuild and install the dogfood mpv on macOS: exactly as Homebrew builds the
# current mpv formula (same flags, dependencies and stable patches), plus our
# sub-snap and sub-pause feature branches.
#
# Run from a clone of the fork (any branch -- it works in an isolated worktree).
# The only manual step, when a new upstream release lands, is to first rebase
# the two feature branches onto the new release tag, e.g.
#     git rebase --onto vX.Y.Z vA.B.C sub-snap
#     git rebase --onto vX.Y.Z vA.B.C sub-pause-mode
# and to refresh homebrew/mpv.rb from the current homebrew/core formula (see
# README.md). Then run this.
#
set -euo pipefail

UPSTREAM=https://github.com/mpv-player/mpv
TAP=feldgendler/dogfood
FEATURES=(sub-snap sub-pause-mode)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
FORMULA="$HERE/homebrew/mpv.rb"

# The release tag and Homebrew's stable patches are taken straight from the
# versioned formula, so the build matches whatever homebrew/core currently does.
TAG="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$FORMULA" | head -1)"
mapfile -t PATCHES < <(grep -oE 'commit/[0-9a-f]{40}' "$FORMULA" | cut -d/ -f2)
echo ">> mpv $TAG + ${#PATCHES[@]} Homebrew patch(es) + ${FEATURES[*]}"

# Ensure the release tag, the patch commits and the feature branches are local.
git -C "$REPO" fetch --quiet "$UPSTREAM" master "refs/tags/$TAG:refs/tags/$TAG" \
    2>/dev/null || git -C "$REPO" fetch --quiet "$UPSTREAM" master || true
git -C "$REPO" fetch --quiet origin
for b in "${FEATURES[@]}"; do
    git -C "$REPO" rev-parse -q --verify "origin/$b" >/dev/null \
        || { echo "!! missing branch origin/$b on the fork"; exit 1; }
done

# Assemble the exact source tree in a throwaway worktree, then publish it as
# homebrew-build -- the branch the tap formula builds from with --HEAD.
WT="$(mktemp -d)"
trap 'git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$WT"' EXIT
git -C "$REPO" worktree add --quiet --force --detach "$WT" "$TAG"
for h in "${PATCHES[@]}"; do git -C "$WT" cherry-pick "$h"; done
git -C "$WT" cherry-pick "${FEATURES[@]/#/origin/}"
git -C "$WT" push --force origin HEAD:homebrew-build

# (Re)create the tap and install our formula (idempotent -- works after a wipe).
TAPDIR="$(brew --repository)/Library/Taps/feldgendler/homebrew-dogfood"
[ -d "$TAPDIR/.git" ] || brew tap-new "$TAP"
install -d "$TAPDIR/Formula"
cp "$FORMULA" "$TAPDIR/Formula/mpv.rb"

brew uninstall --force mpv 2>/dev/null || true
rm -rf "$(brew --cache)/mpv--git"
brew install --HEAD "$TAP/mpv"
echo ">> installed: $(mpv --version | head -1)"
