-- ChromeTabFocus — open a URL in Chrome, reusing an existing tab if one
-- already shows that URL. Registered as an http/https handler so Finicky can
-- hand URLs to it.
--
-- Compiled as a stay-open applet: it keeps running between URLs so each click
-- reuses the warm process instead of paying an app launch. LSUIElement keeps it
-- out of the Dock, so focus never visibly leaves the app you clicked from.

on open location this_URL
	my focusOrOpen(this_URL)
end open location

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
	tell application "Google Chrome"
		-- One Apple event per window rather than one per tab: with many tabs
		-- open, per-tab round trips dominate the whole operation.
		set winCount to (count of windows)
		repeat with wi from 1 to winCount
			set tabURLs to URL of every tab of window wi
			repeat with ti from 1 to (count of tabURLs)
				if my normalizeURL(item ti of tabURLs) is wanted then
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
