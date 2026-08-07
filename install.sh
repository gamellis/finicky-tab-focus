#!/bin/sh
# Install the whole thing: Finicky, the config, and the ChromeTabFocus applet.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! [ -d /Applications/Google\ Chrome.app ]; then
  echo "Google Chrome is required — the tab reuse is Chrome-specific." >&2
  exit 1
fi

if ! [ -d /Applications/Finicky.app ]; then
  echo "Installing Finicky..."
  brew install --cask finicky
fi

mkdir -p "$HOME/.config/finicky"
if [ -e "$HOME/.config/finicky/finicky.js" ]; then
  cp "$HOME/.config/finicky/finicky.js" "$HOME/.config/finicky/finicky.js.bak"
  echo "Existing config backed up to ~/.config/finicky/finicky.js.bak"
fi
cp "$HERE/finicky.js" "$HOME/.config/finicky/finicky.js"

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

Then click a link that's already open in a tab. It should focus that tab.
EOF
