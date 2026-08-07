// Finicky config — send every URL to ChromeTabFocus, which reuses an already
// open Chrome tab, and carve out Linear so issues open in the desktop app.
//
// Requires Finicky 4.x. A v3 config has different syntax and fails silently.

export default {
  // keepRunning matters for latency: without it Finicky quits after handling a
  // URL, so the next click pays a full app launch and its window steals focus
  // on the way through.
  //
  // hideIcon drops the menu bar item. Nothing here needs it, and it's one less
  // thing appearing on a cold start. You lose the Finicky menu; `pkill -x
  // Finicky` replaces everything it offered.
  options: { keepRunning: true, hideIcon: true },

  defaultBrowser: {
    name: "io.github.gamellis.chrometabfocus",
    appType: "bundleId",
  },

  handlers: [
    // ---8<--- Linear carve-out. Delete this whole entry if you don't use
    // Linear, and every URL goes to Chrome.
    {
      match: ({ url }) => {
        // Finicky 4.2.2 passes a { url } wrapper here, despite the bundled
        // finicky.d.ts declaring the argument as a bare WHATWG URL. Verified by
        // routing: /issue/... reaches Linear while /pricing falls through to
        // Chrome, which only happens if this destructure works. If a future
        // Finicky drops the wrapper this throws, and the symptom is every
        // Linear link opening in Chrome — switch to a bare `url` parameter then.
        if (url.host !== "linear.app" && url.host !== "www.linear.app") {
          return false;
        }
        // Second path segment of an in-app route:
        // https://linear.app/<workspace>/<route>/...
        const [, route] = url.pathname.replace(/^\//, "").split("/");
        return [
          "issue", "project", "projects", "initiative", "initiatives", "team",
          "view", "document", "search", "settings", "inbox", "my-issues",
          "roadmap", "cycle", "label", "profile", "notification",
        ].includes(route);
      },
      browser: { name: "Linear", appType: "appName" },
    },
    // ---8<--- end Linear carve-out.
  ],
};
