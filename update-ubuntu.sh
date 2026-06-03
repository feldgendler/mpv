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

UPSTREAM=https://github.com/mpv-player/mpv
FEATURES=(sub-snap sub-pause-mode)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"

# Upstream version the distro currently ships (e.g. 0.41.0-2ubuntu4 -> 0.41.0).
VER="$(apt-cache policy mpv | awk '/Candidate:/{print $2}')"
UPV="$(printf '%s' "$VER" | sed -E 's/^[0-9]+://; s/[-+~].*$//')"
TAG="v$UPV"
echo ">> distro mpv $VER  (upstream $UPV, tag $TAG)"

# Generate our two patches from the feature branches, against the release tag.
git -C "$REPO" fetch --quiet "$UPSTREAM" "refs/tags/$TAG:refs/tags/$TAG" 2>/dev/null || true
git -C "$REPO" fetch --quiet origin
PATCHES="$(mktemp -d)"
for b in "${FEATURES[@]}"; do
    git -C "$REPO" format-patch --quiet -o "$PATCHES" "$TAG..origin/$b"
done
ls -1 "$PATCHES"

# Build dependencies and the exact source the distro builds from.
sudo apt-get -y build-dep mpv
WORK="$(mktemp -d)"; cd "$WORK"
if ! apt-get source mpv; then
    echo "!! 'apt-get source mpv' failed -- enable deb-src (Types: deb deb-src)"
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
sudo apt-get install -y --allow-downgrades ./mpv_*.deb ./libmpv[0-9]_*.deb
HOLD="mpv $(ls ./libmpv[0-9]_*.deb 2>/dev/null | sed -E 's#.*/(libmpv[0-9]+)_.*#\1#' | sort -u)"
sudo apt-mark hold $HOLD
echo ">> installed: $(mpv --version | head -1)"
echo ">> held: $HOLD"
