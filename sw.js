// Service worker — app shell 快取，讓 PWA 離線可開、二次載入即時
const CACHE = 'adhd-v1';
const SHELL = [
  './',
  './index.html',
  './unblock.html',
  './manifest.webmanifest',
  './lib/supabase.js',
  './lib/sortable.min.js',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png',
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// 同源 GET：stale-while-revalidate（先回快取，背景更新）
// Supabase API（跨域）一律直連網路，不快取
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  e.respondWith(
    caches.open(CACHE).then(async cache => {
      const cached = await cache.match(e.request);
      const network = fetch(e.request)
        .then(res => {
          if (res && res.ok) cache.put(e.request, res.clone());
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
