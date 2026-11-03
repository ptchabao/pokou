// Service worker minimal : il rend l'espace installable et garde la coquille
// hors ligne. Les appels à l'API ne sont JAMAIS mis en cache — une
// ordonnance ou un devis périmé affiché comme frais serait dangereux.
const SHELL = "honam-officine-v3";
const FILES = ["/officine/", "/officine/officine.css", "/officine/officine.js", "/officine/icon-192.png", "/officine/favicon.ico"];
self.addEventListener("install", (e) => e.waitUntil(caches.open(SHELL).then((c) => c.addAll(FILES))));
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== SHELL).map((k) => caches.delete(k))))
));
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (!url.pathname.startsWith("/officine/")) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
