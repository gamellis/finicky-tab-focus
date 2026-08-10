-- ChromeTabFocus — open a URL in Chrome, reusing an existing tab if one
-- already shows that URL. Registered as an http/https handler so Finicky can
-- hand URLs to it.
--
-- Compiled as a stay-open applet: it keeps running between URLs so each click
-- reuses the warm process instead of paying an app launch. LSUIElement keeps it
-- out of the Dock, so focus never visibly leaves the app you clicked from.

-- Foundation is here for percent-encoding only. Loading it costs ~130ms, paid
-- once at launch rather than per URL because the applet stays open.
use framework "Foundation"
use scripting additions

on open location this_URL
	my focusOrOpen(this_URL)
end open location

-- Files, not URLs. Because Finicky is the default handler for public.html, a
-- plain `open page.html` reaches Finicky, which hands the *file* to the default
-- browser — us. Without this handler (and the matching CFBundleDocumentTypes in
-- the installer) macOS refuses with "ChromeTabFocus cannot open files in the
-- 'HTML text' format" and the page never opens.
on open theFiles
	repeat with f in theFiles
		my focusOrOpen(my fileURLFor(POSIX path of f))
	end repeat
end open

-- POSIX path -> file:// URL, encoded the way Chrome encodes one. Chrome leaves
-- most punctuation literal and escapes only space, non-ASCII, and # ; ? % { }
-- (and the rest of the unsafe set). Escaping more than that is not merely ugly
-- in the URL bar: a tab Chrome opened itself, from Finder or a link, carries
-- Chrome's spelling, and a string that doesn't match it opens a duplicate.
--
-- Deliberately not NSURL's fileURLWithPath: its absoluteString escapes [ and ]
-- where Chrome leaves them literal, so it is not the rule we need to match.
on fileURLFor(posixPath)
	set allowed to current application's NSCharacterSet's ¬
		characterSetWithCharactersInString:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$&'()*+,/:=@[]"
	set s to current application's NSString's stringWithString:posixPath
	return "file://" & ((s's stringByAddingPercentEncodingWithAllowedCharacters:allowed) as text)
end fileURLFor

-- Decode and normalize a file: URL into something two spellings of the same
-- path both reduce to. Load-bearing, not just insurance against Chromium's
-- escaping rule drifting: `POSIX path of` hands us the filesystem
-- representation, which is NFD, while a tab Chrome opened from Finder carries
-- the NFC form from disk. "caf%C3%A9" and "cafe%CC%81" are different strings.
--
-- Decoding alone already matches them today, but only by accident: coercing an
-- NSString to AppleScript text composes it (the NSString here is length 20, the
-- coerced text 19). Composing explicitly says so, and keeps the match from
-- resting on an undocumented property of a type coercion two lines up.
-- Returns the input unchanged if it isn't decodable.
on decodedURL(u)
	set s to current application's NSString's stringWithString:u
	set d to s's stringByRemovingPercentEncoding()
	if d is missing value then return u
	return (d's precomposedStringWithCanonicalMapping()) as text
end decodedURL

on run argv
	if class of argv is list and (count of argv) > 0 then
		my focusOrOpen(item 1 of argv)
	end if
end run

-- Trailing slashes are cosmetic; treat ".../pull/1" and ".../pull/1/" as one.
on normalizeURL(u)
	set s to u as text
	repeat while s ends with "/"
		if (count of s) is 1 then exit repeat
		set s to text 1 thru -2 of s
	end repeat
	return s
end normalizeURL

on focusOrOpen(theURL)
	set wanted to my normalizeURL(theURL)
	-- file: URLs compare decoded, so two spellings of the same path still match.
	-- Only file: URLs: decoding every tab URL would add a bridged call per tab,
	-- and for http the string Chrome reports is already the string we were given.
	set wantIsFile to wanted starts with "file:"
	if wantIsFile then set wanted to my decodedURL(wanted)
	tell application "Google Chrome"
		-- One Apple event per window rather than one per tab: with many tabs
		-- open, per-tab round trips dominate the whole operation.
		set winCount to (count of windows)
		repeat with wi from 1 to winCount
			set tabURLs to URL of every tab of window wi
			repeat with ti from 1 to (count of tabURLs)
				set tabURL to my normalizeURL(item ti of tabURLs)
				if wantIsFile and tabURL starts with "file:" then ¬
					set tabURL to my decodedURL(tabURL)
				if tabURL is wanted then
					-- KNOWN LIMITATION: this does not deminiaturize. If the
					-- matching tab lives in a minimized window, the click looks
					-- like it did nothing at all. Confirmed, deliberately not
					-- fixed; see the README.
					--
					-- try/end try because Chrome's `index` is historically
					-- unreliable: without it a failure here aborts after the tab
					-- was selected but before `activate`, so Chrome never comes
					-- forward and the click silently does nothing.
					set active tab index of window wi to ti
					try
						set index of window wi to 1
					end try
					activate
					return
				end if
			end repeat
		end repeat

		-- No match: open a new tab in the frontmost window.
		if winCount is 0 then
			make new window
			set URL of active tab of front window to theURL
		else
			tell front window
				make new tab with properties {URL:theURL}
			end tell
		end if
		activate
	end tell
end focusOrOpen
