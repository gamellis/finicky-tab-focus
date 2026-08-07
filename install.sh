#!/bin/sh
# Install the whole thing: Finicky, the config, and the ChromeTabFocus applet.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/finicky"
CONFIG="$CONFIG_DIR/finicky.js"
BACKUP="$CONFIG.bak"

die() { echo "$@" >&2; exit 1; }

# Resolve apps through LaunchServices rather than testing /Applications: a
# per-user or MDM-managed install lives elsewhere and is still perfectly valid.
app_path() {
  osascript -e "POSIX path of (path to application id \"$1\")" 2>/dev/null
}

[ -n "$(app_path com.google.Chrome)" ] ||
  die "Google Chrome is required — the tab reuse is Chrome-specific."

FINICKY="$(app_path se.johnste.finicky || true)"
if [ -z "$FINICKY" ]; then
  command -v brew >/dev/null 2>&1 ||
    die "Finicky is not installed, and neither is Homebrew. Install Finicky
from https://github.com/johnste/finicky/releases (4.x), then re-run this."
  echo "Installing Finicky..."
  brew install --cask finicky
  FINICKY="$(app_path se.johnste.finicky || true)"
  [ -n "$FINICKY" ] || die "Finicky install did not complete. Aborting before
touching your config."
fi

# A v3 config fails *silently* under a v3 Finicky — no error, every URL just
# falls through. Refuse rather than hand the user that mystery.
VERSION="$(defaults read "$FINICKY/Contents/Info.plist" \
  CFBundleShortVersionString 2>/dev/null || echo 0)"
case "$VERSION" in
  4.*) ;;
  *) die "This config needs Finicky 4.x, found $VERSION at $FINICKY.
Upgrade with:  brew upgrade --cask finicky" ;;
esac

# Finicky also honours ~/.finicky.js, and prefers it. Installing to
# ~/.config/finicky/finicky.js while that exists is a silent no-op.
[ -e "$HOME/.finicky.js" ] && die "You have a config at ~/.finicky.js, which
Finicky reads instead of the one this installs. Move it aside and re-run."

mkdir -p "$CONFIG_DIR"
if [ -e "$CONFIG" ] && ! cmp -s "$CONFIG" "$HERE/finicky.js"; then
  # Guarded: without the -e test a second run backs up the config this script
  # already installed, destroying the real backup and any hope of uninstalling
  # cleanly.
  if [ -e "$BACKUP" ]; then
    echo "Leaving the existing backup at $BACKUP untouched."
  else
    cp "$CONFIG" "$BACKUP"
    echo "Your existing config was backed up to $BACKUP"
  fi
fi
cp "$HERE/finicky.js" "$CONFIG"

"$HERE/install-chrome-tab-focus.sh"

# Finicky does not hot-reload. Stop it rather than restarting it: an explicit
# launch shows its window, but a LaunchServices launch to handle a URL doesn't.
pkill -x Finicky || true

cat <<'EOF'

Installed. Two things left, both one-time and both interactive:

  1. Set Finicky as the default browser:
     System Settings > Desktop & Dock > Default web browser > Finicky
     (If Finicky isn't listed, run `open -a Finicky` once, then look again.)

  2. Click any link. macOS will ask to let ChromeTabFocus control Google
     Chrome — approve it, or the applet silently does nothing.

Then check it worked:

  ./verify.sh
EOF
