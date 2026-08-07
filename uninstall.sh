#!/bin/sh
# Back out.
#
# Order matters here. Removing the applet and config while Finicky is still the
# default browser leaves you with a default browser that routes nowhere — every
# link dead, and you need a browser to look up the fix. So the default-browser
# step comes first, and it's yours: macOS won't let a script set it.
set -eu

APP="$HOME/Applications/ChromeTabFocus.app"
CONFIG="$HOME/.config/finicky/finicky.js"
BACKUP="$CONFIG.bak"
HERE="$(cd "$(dirname "$0")" && pwd)"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if defaults read com.apple.LaunchServices/com.apple.launchservices.secure 2>/dev/null |
  grep -q 'se\.johnste\.finicky'; then
  cat <<'EOF'
Finicky still looks like your default browser.

Set it back FIRST — System Settings > Desktop & Dock > Default web browser —
or you'll be left with no working browser and no easy way to look up why.

Re-run this script once that's done.
EOF
  exit 1
fi

for id in io.github.gamellis.chrometabfocus local.chrometabfocus; do
  osascript -e "tell application id \"$id\" to quit" 2>/dev/null || true
done
pkill -f "ChromeTabFocus.app" 2>/dev/null || true

# Unregister before deleting, or a handler entry pointing at a missing bundle
# lingers in the default-browser list until the LS database is rebuilt.
[ -e "$APP" ] && "$LSREGISTER" -u "$APP" 2>/dev/null
rm -rf "$APP"
pkill -x Finicky || true

if [ -e "$BACKUP" ]; then
  mv "$BACKUP" "$CONFIG"
  echo "Restored your previous $CONFIG"
elif [ -e "$CONFIG" ] && cmp -s "$CONFIG" "$HERE/finicky.js"; then
  rm -f "$CONFIG"
  echo "Removed the config this tool installed."
elif [ -e "$CONFIG" ]; then
  # Not ours and no backup on record — someone else's work. Never delete it.
  echo "Left $CONFIG alone: it isn't the config this tool installed."
fi

cat <<'EOF'

Removed ChromeTabFocus. Finicky itself is still installed:

  brew uninstall --cask finicky
EOF
