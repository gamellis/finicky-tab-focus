#!/bin/sh
# Check the install. Every failure mode this tool has is silent, so this exists
# to turn "links just don't do anything" into a specific answer.
set -u

BUNDLE_ID="io.github.gamellis.chrometabfocus"
APP="$HOME/Applications/ChromeTabFocus.app"
CONFIG="$HOME/.config/finicky/finicky.js"
fails=0

ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; echo "        $2"; fails=$((fails + 1)); }

app_path() {
  osascript -e "POSIX path of (path to application id \"$1\")" 2>/dev/null
}

echo "Checking..."

if [ -n "$(app_path com.google.Chrome)" ]; then
  ok "Google Chrome installed"
else
  bad "Google Chrome not found" "Tab reuse is Chrome-specific."
fi

FINICKY="$(app_path se.johnste.finicky)"
if [ -z "$FINICKY" ]; then
  bad "Finicky not found" "brew install --cask finicky"
else
  VERSION="$(defaults read "$FINICKY/Contents/Info.plist" \
    CFBundleShortVersionString 2>/dev/null || echo "?")"
  case "$VERSION" in
    4.*) ok "Finicky $VERSION" ;;
    *)   bad "Finicky $VERSION is not 4.x" \
             "This config fails silently on older Finicky. brew upgrade --cask finicky" ;;
  esac
fi

if [ -e "$HOME/.finicky.js" ]; then
  bad "$HOME/.finicky.js exists" \
      "Finicky reads that instead of $CONFIG. Move it aside."
fi

if [ -e "$CONFIG" ]; then
  ok "config present"
else
  bad "no config at $CONFIG" "Run ./install.sh"
fi

if [ -d "$APP" ]; then
  ok "applet built"
  # An applet built before local-file support claims no document types, and the
  # symptom is specific: `open page.html` puts up "cannot open files in the
  # 'HTML text' format" while web links keep working.
  if plutil -p "$APP/Contents/Info.plist" 2>/dev/null | grep -q 'public\.html'; then
    ok "applet handles local HTML files"
  else
    bad "applet predates local HTML file support" \
        "Run ./install-chrome-tab-focus.sh to rebuild it."
  fi
else
  bad "no applet at $APP" "Run ./install-chrome-tab-focus.sh"
fi

if defaults read com.apple.LaunchServices/com.apple.launchservices.secure 2>/dev/null |
  grep -q 'se\.johnste\.finicky'; then
  ok "Finicky is the default browser"
else
  bad "Finicky is not the default browser" \
      "System Settings > Desktop & Dock > Default web browser > Finicky"
fi

# The automation grant is the one thing that can't be checked without asking:
# a dry run either returns a tab count or trips the TCC denial.
if osascript -e 'tell application "Google Chrome" to count windows' >/dev/null 2>&1; then
  ok "Chrome automation permitted (for this terminal)"
  echo
  echo "  note  That tested this terminal, not the applet — TCC grants are"
  echo "        per-app. If links still do nothing, reset the applet's grant:"
  echo "          tccutil reset AppleEvents $BUNDLE_ID"
else
  bad "Chrome automation denied" \
      "Approve it in System Settings > Privacy & Security > Automation."
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All checks passed. Open a link that's already in a tab — it should focus"
  echo "that tab rather than opening a second one."
else
  echo "$fails check(s) failed."
fi
exit "$fails"
