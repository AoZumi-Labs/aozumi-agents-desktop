#!/bin/sh
# Installs, or updates, Hachi (AOZUMI's agents app, first released as AOZUMI
# Agents) for Mac from the latest release:
#   curl -fsSL https://raw.githubusercontent.com/AoZumi-Labs/aozumi-agents-desktop/main/install.sh | sh
#
# It checks the download against the release's SHA-512 and the app's own
# signature, installs into /Applications (or ~/Applications when that isn't
# writable), quits only the copy it replaces, puts it back if anything fails,
# and opens the app. A copy under the old name, AOZUMI Agents.app, is the same
# app and is replaced too; its data stays. AOZUMI_INSTALL_DIR picks another
# folder; AOZUMI_NO_OPEN=1 skips opening it.
set -eu

REPO="AoZumi-Labs/aozumi-agents-desktop"
FEED="https://github.com/$REPO/releases/latest/download/desktop-version.json"
ID="dev.aozumi.agents"
OLD_APP="AOZUMI Agents.app"

say() { printf '%s\n' "$*"; }
fail() { printf 'Hachi: %s\n' "$*" >&2; exit 1; }
bundle_id() { plutil -extract CFBundleIdentifier raw -o - "$1/Contents/Info.plist" 2>/dev/null || true; }

# Quits the copy at $1 (and only that one), then waits for it to exit.
quit_copy() {
  pgrep -f "$1/Contents/MacOS/" >/dev/null 2>&1 || return 0
  say "Quitting the running $(basename "$1" .app)…"
  osascript -e "tell application \"$1\" to quit" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    pgrep -f "$1/Contents/MacOS/" >/dev/null 2>&1 || return 0
    sleep 1
  done
  fail "$(basename "$1" .app) is still running. Quit it and run this again."
}

[ "$(uname -s)" = Darwin ] || fail "this installer is for macOS."
[ "$(uname -m)" = arm64 ] || fail "this Mac has an Intel chip, and Hachi needs Apple Silicon (M1 or later) for now."
macos=$(sw_vers -productVersion)
[ "${macos%%.*}" -ge 13 ] || fail "Hachi needs macOS 13 or later; this Mac has $macos."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "Finding the latest Hachi…"
curl -fsSL "$FEED" -o "$tmp/feed.json" || fail "couldn't reach GitHub. Check your connection and try again."
version=$(plutil -extract version raw -o - "$tmp/feed.json")
url=$(plutil -extract files.0.url raw -o - "$tmp/feed.json")
sha=$(plutil -extract files.0.sha512 raw -o - "$tmp/feed.json")

say "Downloading Hachi $version…"
curl -fL --progress-bar "$url" -o "$tmp/app.zip" || fail "the download didn't finish. Try again."
[ "$(openssl dgst -sha512 -binary "$tmp/app.zip" | base64)" = "$sha" ] || fail "the download doesn't match the release's checksum. Try again."
ditto -x -k "$tmp/app.zip" "$tmp/new"
# One app: Hachi.app, or AOZUMI Agents.app in releases from before the rename.
set -- "$tmp/new"/*.app
{ [ $# -eq 1 ] && [ -d "$1" ]; } || fail "the release should hold one app."
APP=$(basename "$1")
[ "$(bundle_id "$1")" = "$ID" ] || fail "the release holds a different app, so it wasn't installed."
codesign --verify --deep --strict "$tmp/new/$APP" 2>/dev/null || fail "the app's signature doesn't verify, so it wasn't installed."

dir=${AOZUMI_INSTALL_DIR:-/Applications}
if [ -z "${AOZUMI_INSTALL_DIR:-}" ] && [ ! -w "$dir" ]; then
  dir="$HOME/Applications"
fi
mkdir -p "$dir"
target="$dir/$APP"
old=""
if [ "$APP" != "$OLD_APP" ] && [ -d "$dir/$OLD_APP" ] && [ "$(bundle_id "$dir/$OLD_APP")" = "$ID" ]; then
  old="$dir/$OLD_APP"
fi

quit_copy "$target"
if [ -n "$old" ]; then quit_copy "$old"; fi

if [ -e "$target" ]; then
  mv "$target" "$tmp/previous.app" || fail "couldn't replace $target."
fi
if ! mv "$tmp/new/$APP" "$target"; then
  [ -e "$tmp/previous.app" ] && mv "$tmp/previous.app" "$target"
  fail "couldn't install into $dir."
fi
# curl doesn't mark downloads as quarantined; clear it anyway, so the first open never asks.
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

if [ -n "$old" ]; then
  if mv "$old" "$tmp/old-name.app" 2>/dev/null; then
    say "Replaced $OLD_APP, the app's old name; your data stays. If it was in your Dock, add ${APP%.app} there instead."
  else
    say "Couldn't remove $old. It's the same app under its old name: move it to the Trash."
  fi
fi

say "Installed ${APP%.app} $version in $dir. It updates itself from now on."
[ "${AOZUMI_NO_OPEN:-}" = 1 ] || open "$target"
