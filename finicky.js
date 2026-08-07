// Finicky config — send every URL to ChromeTabFocus, which reuses an already
// open Chrome tab, and carve out Linear so issues open in the desktop app.
//
// Requires Finicky 4.x. A v3 config has different syntax and fails silently.
//
// The Linear handler below is optional — delete it if you don't use Linear and
// every URL goes to Chrome.

// Second path segment of an in-app route: https://linear.app/<workspace>/<route>/...
const appRoutes = [
  "issue",
  "project",
  "projects",
  "initiative",
  "initiatives",
  "team",
  "view",
  "document",
  "search",
  "settings",
  "inbox",
  "my-issues",
  "roadmap",
  "cycle",
  "label",
  "profile",
  "notification",
];


export default {
  // keepRunning matters for latency: without it Finicky quits after handling a
  // URL, so the next click pays a full app launch and its window steals focus
  // on the way through.
  options: { keepRunning: true },

  defaultBrowser: { name: "local.chrometabfocus", appType: "bundleId" },

  handlers: [
    {
      match: ({ url }) => {
        if (url.host !== "linear.app") return false;
        const [, route] = url.pathname.replace(/^\//, "").split("/");
        return appRoutes.includes(route);
      },
      browser: { name: "Linear", appType: "appName" },
      // This rewrite is a DEAD NO-OP, kept because the resulting behaviour is
      // the one we want: Linear receives the original https URL and applies its
      // own routing. Two v4 API traps defeat it, both silently — the argument
      // is a WHATWG URL instance (not a { url } wrapper, so this destructure
      // yields undefined) and a handler has no `url` field at all (rewrites
      // belong in a top-level `rewrite` array). Don't "fix" it without
      // re-testing; a working linear:// rewrite routes worse.
      url: ({ url }) => ({ ...url, protocol: "linear" }),
    },
  ],
};
