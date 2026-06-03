#!/usr/bin/env bash
#
# Rebuild and install the dogfood mpv on Debian/Ubuntu: the distro's own source
# package, built the distro's own way, with our sub-snap and sub-pause feature
# branches added as quilt patches.
#
# Run on the Ubuntu box from a clone of the fork (any branch). The only manual
# step, when a new upstream release lands, is to first rebase the two feature
# branches onto the new release tag (see README.md). Then run this.
#
# Requires source packages: add "deb-src" to the Types line in
# /etc/apt/sources.list.d/ubuntu.sources and run `sudo apt update` once.
#
set -euo pipefail

FEATURES=(sub-snap sub-pause-mode)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"

# Upstream version the distro currently ships (e.g. 0.41.0-2ubuntu4 -> 0.41.0).
VER="$(apt policy mpv 2>/dev/null | awk '/Candidate:/{print $2}')"
UPV="$(printf '%s' "$VER" | sed -E 's/^[0-9]+://; s/[-+~].*$//')"
TAG="v$UPV"
echo ">> distro mpv $VER  (upstream $UPV, tag $TAG)"

# Generate our two patches from the feature branches. Fetch only the two feature
# tips plus their parent (the release commit) -- shallow (depth 2), into proper
# remote-tracking refs -- so this works from a lightweight, single-branch clone
# and never pulls the fork's full history over a flaky network. Each feature is
# a single commit on the release tag, so `format-patch -1` is its diff vs the
# release; no separate tag fetch is needed.
refspecs=()
for b in "${FEATURES[@]}"; do refspecs+=("+refs/heads/$b:refs/remotes/origin/$b"); done
git -C "$REPO" fetch --quiet --depth 2 origin "${refspecs[@]}"
PATCHES="$(mktemp -d)"
for b in "${FEATURES[@]}"; do
    git -C "$REPO" format-patch -1 --quiet -o "$PATCHES" "origin/$b"
done
ls -1 "$PATCHES"

# Build dependencies and the exact source the distro builds from.
sudo apt -y build-dep mpv
WORK="$(mktemp -d)"; cd "$WORK"
if ! apt source mpv; then
    echo "!! 'apt source mpv' failed -- enable deb-src (Types: deb deb-src)"
    echo "   in /etc/apt/sources.list.d/ubuntu.sources, then 'sudo apt update'."
    exit 1
fi
cd mpv-*/

# Add our patches to the quilt series, on top of the distro's own patches.
export QUILT_PATCHES=debian/patches
for p in "$PATCHES"/*.patch; do quilt import "$p"; done
quilt push -a

# Version it above the archive so apt keeps ours; build with the distro's rules.
dch --local +feld 'add sub-snap and sub-pause features'
dpkg-buildpackage -b -uc -us

# Install our freshly built mpv + libmpv and pin them so upgrades won't clobber.
cd ..
sudo apt install -y --allow-downgrades ./mpv_*.deb ./libmpv[0-9]_*.deb
HOLD="mpv $(ls ./libmpv[0-9]_*.deb 2>/dev/null | sed -E 's#.*/(libmpv[0-9]+)_.*#\1#' | sort -u)"
sudo apt-mark hold $HOLD
echo ">> installed: $(mpv --version | head -1)"
echo ">> held: $HOLD"
