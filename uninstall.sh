#!/bin/sh
# Back out. This does not choose a new default browser for you — macOS won't
# let a script set that; the last step is yours.
set -eu

APP="$HOME/Applications/ChromeTabFocus.app"

osascript -e 'tell application id "local.chrometabfocus" to quit' 2>/dev/null || true
rm -rf "$APP"
pkill -x Finicky || true

if [ -e "$HOME/.config/finicky/finicky.js.bak" ]; then
  mv "$HOME/.config/finicky/finicky.js.bak" "$HOME/.config/finicky/finicky.js"
  echo "Restored your previous ~/.config/finicky/finicky.js"
else
  rm -f "$HOME/.config/finicky/finicky.js"
fi

cat <<'EOF'

Removed ChromeTabFocus and the config.

Finicky itself is still installed and may still be your default browser. Set
that back in System Settings > Desktop & Dock > Default web browser, then:

  brew uninstall --cask finicky
EOF
