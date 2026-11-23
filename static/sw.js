/* Retires the service worker that static/js/deferred-loader.js once
   registered. That worker served scripts, stylesheets and pages under /post/
   and /publication/ from a cache that it never refreshed, and no page has
   registered it since the loader went out of use. A browser that still holds
   it checks this address for updates, receives this version, deletes the old
   caches and unregisters, so its later requests reach the network again. A
   browser that never held it never requests this file. Keep the file at this
   address for as long as such browsers may remain. */

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all(
      ["website-cache-v1", "search-cache-v1"].map((name) => caches.delete(name))
    ).then(() => self.registration.unregister())
  );
});
