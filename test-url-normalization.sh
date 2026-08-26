#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SOURCE="$ROOT/chrome-tab-focus.applescript"
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/chrome-tab-focus-test.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT HUP INT TERM

# Compile the production handler in isolation. The complete source is an applet
# and osacompile cannot compile its `open location` handler as a plain script.
sed -n '/^use framework "Foundation"$/p; /^use scripting additions$/p; /^on decodedURL/,/^end decodedURL/p' "$SOURCE" \
  >"$TMPDIR_TEST/url-normalization.applescript"
printf '%s\n' \
  'on run argv' \
  '  return my decodedURL(item 1 of argv)' \
  'end run' >>"$TMPDIR_TEST/url-normalization.applescript"
osacompile -l AppleScript -o "$TMPDIR_TEST/url-normalization.scpt" \
  "$TMPDIR_TEST/url-normalization.applescript"

normalize() {
  osascript -l AppleScript "$TMPDIR_TEST/url-normalization.scpt" "$1"
}

assert_equal() {
  actual=$1
  expected=$2
  label=$3
  if [ "$actual" != "$expected" ]; then
    echo "$label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_not_equal() {
  left=$1
  right=$2
  label=$3
  if [ "$left" = "$right" ]; then
    echo "$label: both normalized to '$left'" >&2
    exit 1
  fi
}

encoded_hash=$(normalize 'file:///tmp/report.html%23intro')
fragment_hash=$(normalize 'file:///tmp/report.html#intro')
assert_not_equal "$encoded_hash" "$fragment_hash" \
  'encoded # path versus fragment'
assert_equal "$encoded_hash" 'file:///tmp/report.html%23intro' \
  'encoded # remains path data'
assert_equal "$fragment_hash" 'file:///tmp/report.html#intro' \
  'fragment remains a fragment'

encoded_question=$(normalize 'file:///tmp/report.html%3Fprint')
query_question=$(normalize 'file:///tmp/report.html?print')
assert_not_equal "$encoded_question" "$query_question" \
  'encoded ? path versus query'
assert_equal "$encoded_question" 'file:///tmp/report.html%3Fprint' \
  'encoded ? remains path data'
assert_equal "$query_question" 'file:///tmp/report.html?print' \
  'query remains a query'

structured=$(normalize 'file://server/share/report%23draft.html?mode=print#intro')
assert_equal "$structured" \
  'file://server/share/report%23draft.html?mode=print#intro' \
  'authority, query, and fragment remain distinct components'

composed=$(normalize 'file:///tmp/caf%C3%A9.html')
decomposed=$(normalize 'file:///tmp/cafe%CC%81.html')
assert_equal "$decomposed" "$composed" 'NFD and NFC path spellings'

echo 'url normalization tests passed'
