#!/bin/sh
# Build ChromeTabFocus.app from the AppleScript source and register it as an
# http/https handler so Finicky can hand URLs to it.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)/chrome-tab-focus.applescript"
APP="$HOME/Applications/ChromeTabFocus.app"
PLIST="$APP/Contents/Info.plist"

osascript -e 'tell application id "local.chrometabfocus" to quit' 2>/dev/null || true
rm -rf "$APP"

# -s: stay-open applet, so the process stays warm between URLs instead of
# cold-launching on every click.
osacompile -s -o "$APP" "$SRC"

plutil -replace CFBundleIdentifier -string "local.chrometabfocus" "$PLIST"
plutil -replace CFBundleURLTypes \
  -json '[{"CFBundleURLName":"Web","CFBundleURLSchemes":["http","https"]}]' "$PLIST"
plutil -replace NSAppleEventsUsageDescription \
  -string "Focus an existing Chrome tab." "$PLIST"
# Agent app: no Dock icon, no app switch when handling a URL.
plutil -replace LSUIElement -bool true "$PLIST"

codesign --force --deep -s - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Installed $APP"
echo "First use will prompt to allow controlling Google Chrome — approve it."
