/* Retires the cache-first service worker that used to be served from this
   address. Only static/js/deferred-loader.js and an unused backup partial
   could register it, and no layout in the repository's history loaded
   either, so it was probably never installed. A browser that did install it
   checks this address for updates, receives this version, deletes the old
   caches and unregisters, so its later requests reach the network again. A
   browser that never held it never requests this file. */

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
