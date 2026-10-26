const CACHE_NAME = 'hnw-shell-v1';
const SHELL = ['/', '/index.html', '/manifest.json', '/favicon.png'];
const SENSITIVE_PATHS = [
  '/api',
  '/ws',
  '/auth',
  '/kyc',
  '/support',
  '/account',
  '/deposit',
  '/withdraw',
  '/order',
  '/trade',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  const sensitive = SENSITIVE_PATHS.some(
    (path) => url.pathname === path || url.pathname.startsWith(`${path}/`),
  );
  if (request.method !== 'GET' || sensitive || url.origin !== self.location.origin) {
    event.respondWith(fetch(request, { cache: 'no-store' }));
    return;
  }
  if (!SHELL.includes(url.pathname)) return;
  event.respondWith(caches.match(request).then((cached) => cached || fetch(request)));
});
