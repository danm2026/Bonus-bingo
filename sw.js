const CACHE_NAME = 'bonus-bingo-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png',
  './favicon-32x32.png',
  './favicon-16x16.png'
];

// Cache the app shell (icons/manifest/html) on install so the icon/branding
// is available offline. This does NOT cache your live Supabase data.
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .catch(() => {})
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Network-first: always try the live network first (important for live game
// data), fall back to cache only if the network request fails (offline).
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});

// ===== Phase 5: push notifications (game finished / winner alerts) =====
// The actual push message is sent by a Supabase Edge Function (see
// PUSH_SETUP.md) whenever a game finishes or a win is recorded.
self.addEventListener('push', event => {
  let data = { title: 'Bonus Bingo', body: 'Something happened in your game!' };
  try { if (event.data) data = event.data.json(); } catch(e) {}
  event.waitUntil(
    self.registration.showNotification(data.title || 'Bonus Bingo', {
      body: data.body || '',
      icon: './icon-192.png',
      badge: './favicon-32x32.png',
      data: { url: data.url || './' }
    })
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(list => {
      for (const client of list) { if ('focus' in client) return client.focus(); }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
