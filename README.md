# finicky-tab-focus

Click a link anywhere on your Mac. If that URL is already open in a Chrome tab,
that tab gets focused. If it isn't, it opens in a new tab. No duplicate tabs.

Chrome has no built-in equivalent, and no browser chooser does it either —
Finicky, Velja and Choosy all pick a *browser*, then leave tab handling to it.
This wires tab reuse in as the system default handler, so it applies to every
link from every app.

Linear links are the one exception: they open in the Linear desktop app.

## Requirements

- macOS 14+ (developed on 26.5)
- Finicky **4.x** — a v3 config has different syntax and fails *silently*
- Google Chrome — the tab reuse is Chrome-specific (see Limitations)

## Install

```sh
./install.sh
```

That installs Finicky if missing, copies the config, builds and registers the
applet, and prints the two interactive steps it can't do for you: choosing
Finicky as the default browser, and approving Chrome automation on first click.

To back out:

```sh
./uninstall.sh
```

## How it works

Two pieces.

**Finicky** is set as the default browser, so it sees every URL the system
opens and decides where it goes. Its `defaultBrowser` is ChromeTabFocus, so
everything lands there unless a handler claims it first.

**ChromeTabFocus** is an AppleScript applet registered as an http/https
handler. Given a URL it scans every Chrome window for a tab already showing it
(ignoring trailing slashes), focuses that tab and window if found, and
otherwise opens a new tab in the front window.

A click therefore crosses two processes before Chrome sees it. Naively that
cost ~0.6s with a visible focus flash. Three details bring it to ~0.27s:

- The applet is built **stay-open** (`osacompile -s`), so it stays warm instead
  of cold-launching per click.
- **`LSUIElement`** is set, so it has no Dock presence and focus never visibly
  leaves the app you clicked from.
- Tab URLs are read **one Apple event per window**, not one per tab — per-tab
  round trips dominate once you have a lot of tabs.

Finicky's `keepRunning` does the same job on its side.

## Limitations

- **Chrome only.** Safari's scripting dictionary differs, and Firefox exposes
  no tab-URL scripting at all, so it could never participate.
- **Links clicked inside an app that opens its own webview never reach
  Finicky**, so they can't be deduplicated.
- **URLs must match exactly** (modulo trailing slash). Query strings, tracking
  params and anchors all count as different tabs.

## Editing the config

`~/.config/finicky/finicky.js`. **Finicky does not hot-reload it** — an edit
does nothing until Finicky restarts, and every URL quietly falls through to the
default browser in the meantime.

```sh
pkill -x Finicky
```

Stop it and stop there — do **not** launch it again. Finicky shows its window
on every explicit launch, and `open -g -j -a Finicky` is no better than
`open -a Finicky`; the background and hidden flags make no difference. That
window is the flash people mistake for a slow route. Launched by LaunchServices
to handle a URL, it never shows the window at all, so the next link you click
brings it back silently.

When a rule misbehaves, set `options.logRequests: true`, restart, and read
`~/Library/Logs/Finicky/*.log` — it records the exact `open` command issued,
which settles what a rule actually did. Turn it back off afterwards; the log
contains every URL you visit.

### Two v4 API traps

Both fail silently rather than erroring, and both cost hours:

- `match` and `url` functions receive a **WHATWG `URL` instance** as their
  first argument, not a `{ url }` wrapper. Destructuring `{ url }` gives
  `undefined`, and spreading a `URL` gives `{}` — the rule then quietly does
  nothing.
- A **handler has no `url` field** — only `match` and `browser`. URL rewriting
  belongs in the top-level `rewrite` array, which runs first; handlers then
  match the already-rewritten URL.

The `url:` rewrite in the shipped Linear handler hits both, and is left in
place deliberately. See the comment on it.

## Linear notes

Linear.app ships no `com.apple.developer.associated-domains` entitlement, so a
universal link can never reach the app directly — only the `linear://` scheme
can. In practice handing Linear the plain https URL and letting it route
internally works better than rewriting the scheme ourselves.

Linear matches its in-app tabs on the **exact URL**, so a slug-less issue link
(`/issue/ES-583`) opens a second tab alongside the canonical one
(`/issue/ES-583/some-title-slug`). Use the full URL from
`linear issue view <id> --json` when pasting links. Canonicalising slug-less
URLs automatically was considered and rejected: the CLI lookup costs ~0.9s per
click, and links clicked inside Linear never pass through Finicky anyway.

## Rejected approaches

Kept so they don't get re-attempted:

- **Routing GitHub to the GitHub PWA's shim app** drops the deep link. Its
  `app_mode_loader` accepts no URL argument and always lands on the app's start
  URL.
- **Launching Chrome with `--app=<url>`** opens the right URL, but in a fresh
  window every time, with no tab reuse.
- **GitHub Desktop** registers only clone/auth schemes (`x-github-client://`,
  `github-mac://`) and cannot render issues, PRs, or code.

## Files

| File                            | Purpose                                          |
| ------------------------------- | ------------------------------------------------ |
| `finicky.js`                    | Copied to `~/.config/finicky/finicky.js`         |
| `chrome-tab-focus.applescript`  | Source for the applet                            |
| `install-chrome-tab-focus.sh`   | Builds and registers the applet only             |
| `install.sh` / `uninstall.sh`   | Everything, both directions                      |

The applet is built rather than committed: `osacompile` produces the `.app`,
then the installer patches the bundle id, URL types and `LSUIElement` into its
`Info.plist`, ad-hoc signs it, and registers it with LaunchServices.

## License

MIT — see [LICENSE](LICENSE).
