# dogfood

Scripts to build my personal mpv — exactly the way each platform's package
manager builds the official mpv, plus my two feature branches:

- **`sub-snap`** — `seek <amount> sub-snap`: snap to the adjacent subtitle line.
- **`sub-pause-mode`** — `--sub-pause`: auto-pause on each subtitle's last frame.

These two branches are the single source of truth. Everything else (the
`homebrew-build` branch, the Debian quilt patches) is generated from them.

## Branch layout on the fork

| branch | what it is |
|---|---|
| `sub-snap`, `sub-pause-mode` | the features, one commit each, based on the **release tag** (also the upstream PR branches) |
| `homebrew-build` | generated: release tag + Homebrew's stable patches + the two features. Force-pushed by `update-macos.sh`; the tap builds it with `--HEAD` |
| `master` | optional integration (upstream master + both features merged) |
| `dogfood` | this branch — scripts only, no mpv source |

There is intentionally **no Ubuntu branch**: dpkg builds locally from
`apt-get source` + patches generated from the feature branches, so nothing needs
to be hosted for it (unlike Homebrew, which clones a git branch over HTTP).

## Routine update (new upstream release)

The only non-mechanical step is the rebase — normally one command per branch:

```sh
git fetch upstream --tags
git rebase --onto vNEW vOLD sub-snap
git rebase --onto vNEW vOLD sub-pause-mode
# build + smoke-test, then push
git push --force origin sub-snap sub-pause-mode
```

Then, mechanically:

- **macOS:** `./update-macos.sh`
- **Ubuntu:** `./update-ubuntu.sh` (on the Ubuntu box)

If the rebase hits a conflict, resolve it once; that's the only hand-work.

## After a fresh OS install

macOS:

```sh
git clone https://github.com/feldgendler/mpv && cd mpv
git switch dogfood        # these scripts
./update-macos.sh         # recreates the tap, builds, installs
```

Ubuntu (enable deb-src first — see the `update-ubuntu.sh` header):

```sh
# A lightweight clone is enough: the script fetches only the release tag and the
# two feature tips (shallow). The fork carries all of mpv's history, so a full
# clone is large and pointless here.
git clone --depth 1 --single-branch --branch dogfood \
    https://github.com/feldgendler/mpv && cd mpv
./update-ubuntu.sh
```

Both scripts are idempotent and bootstrap from nothing (the macOS one recreates
the Homebrew tap from `homebrew/mpv.rb`).

## Keeping "exactly like the distro" true

- **macOS:** `homebrew/mpv.rb` is a copy of homebrew/core's formula with only the
  `head` line repointed at the fork. When Homebrew changes the core formula
  (flags, deps, version, patches), refresh it: `brew cat mpv > homebrew/mpv.rb`,
  re-point `head` at `https://github.com/feldgendler/mpv.git` branch
  `homebrew-build`, and commit. `update-macos.sh` reads the release tag and
  stable patch list straight from this file.
- **Ubuntu:** nothing to maintain — `update-ubuntu.sh` always pulls the distro's
  current source and packaging via `apt-get source`, and only injects the two
  patches. The version it targets is read from `apt-cache policy mpv`.

## Reverting to stock

- **macOS:** `brew uninstall feldgendler/dogfood/mpv && brew install mpv`
- **Ubuntu:** `sudo apt-mark unhold mpv libmpv2 && sudo apt-get install --reinstall --allow-downgrades mpv libmpv2`
