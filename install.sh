#!/bin/sh
# Installs, or updates, AOZUMI Agents for Mac from the latest release:
#   curl -fsSL https://raw.githubusercontent.com/AoZumi-Labs/aozumi-agents-desktop/main/install.sh | sh
#
# It checks the download against the release's SHA-512 and the app's own
# signature, installs into /Applications (or ~/Applications when that isn't
# writable), quits only the copy it replaces, puts it back if anything fails,
# and opens the app. AOZUMI_INSTALL_DIR picks another folder; AOZUMI_NO_OPEN=1
# skips opening it.
set -eu

REPO="AoZumi-Labs/aozumi-agents-desktop"
FEED="https://github.com/$REPO/releases/latest/download/desktop-version.json"
APP="AOZUMI Agents.app"

say() { printf '%s\n' "$*"; }
fail() { printf 'AOZUMI Agents: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "this installer is for macOS."
[ "$(uname -m)" = arm64 ] || fail "this Mac has an Intel chip, and AOZUMI Agents needs Apple Silicon (M1 or later) for now."
macos=$(sw_vers -productVersion)
[ "${macos%%.*}" -ge 13 ] || fail "AOZUMI Agents needs macOS 13 or later; this Mac has $macos."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "Finding the latest AOZUMI Agents…"
curl -fsSL "$FEED" -o "$tmp/feed.json" || fail "couldn't reach GitHub. Check your connection and try again."
version=$(plutil -extract version raw -o - "$tmp/feed.json")
url=$(plutil -extract files.0.url raw -o - "$tmp/feed.json")
sha=$(plutil -extract files.0.sha512 raw -o - "$tmp/feed.json")

say "Downloading AOZUMI Agents $version…"
curl -fL --progress-bar "$url" -o "$tmp/app.zip" || fail "the download didn't finish. Try again."
[ "$(openssl dgst -sha512 -binary "$tmp/app.zip" | base64)" = "$sha" ] || fail "the download doesn't match the release's checksum. Try again."
ditto -x -k "$tmp/app.zip" "$tmp/new"
[ -d "$tmp/new/$APP" ] || fail "the release doesn't contain $APP."
codesign --verify --deep --strict "$tmp/new/$APP" 2>/dev/null || fail "the app's signature doesn't verify, so it wasn't installed."

dir=${AOZUMI_INSTALL_DIR:-/Applications}
if [ -z "${AOZUMI_INSTALL_DIR:-}" ] && [ ! -w "$dir" ]; then
  dir="$HOME/Applications"
fi
mkdir -p "$dir"
target="$dir/$APP"

# Quit the copy being replaced (and only that one), then wait for it to exit.
if pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1; then
  say "Quitting the running AOZUMI Agents…"
  osascript -e "tell application \"$target\" to quit" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1 || break
    sleep 1
  done
  pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1 && fail "AOZUMI Agents is still running. Quit it and run this again."
fi

if [ -e "$target" ]; then
  mv "$target" "$tmp/previous.app" || fail "couldn't replace $target."
fi
if ! mv "$tmp/new/$APP" "$target"; then
  [ -e "$tmp/previous.app" ] && mv "$tmp/previous.app" "$target"
  fail "couldn't install into $dir."
fi
# curl doesn't mark downloads as quarantined; clear it anyway, so the first open never asks.
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

say "Installed AOZUMI Agents $version in $dir. It updates itself from now on."
[ "${AOZUMI_NO_OPEN:-}" = 1 ] || open "$target"
