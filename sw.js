// Service worker do Taskflow: guarda o app para abrir rápido e sem internet.
// Dados (Supabase, Google) nunca são guardados aqui; sempre vêm da rede.
const VERSAO = 'taskflow-v5';
const BASE = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/apple-180.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSAO).then(c => Promise.allSettled(BASE.map(u => c.add(u)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSAO).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== 'GET') return;
  if (/supabase\.co$|googleapis\.com$|accounts\.google\.com$/.test(u.hostname) && !u.pathname.includes('/css2')) return;
  // Página: rede primeiro (pega a versão nova), cache se estiver sem internet
  if (r.mode === 'navigate') {
    e.respondWith(fetch(r.url, { cache: 'no-store', credentials: 'same-origin' }).then(res => { const c = res.clone(); caches.open(VERSAO).then(x => x.put('./index.html', c)); return res; })
      .catch(() => caches.match('./index.html')));
    return;
  }
  // Demais arquivos (ícones, biblioteca, fontes): cache primeiro, atualiza em segundo plano
  e.respondWith(caches.match(r).then(cached => {
    const rede = fetch(r).then(res => { if (res.ok || res.type === 'opaque') { const c = res.clone(); caches.open(VERSAO).then(x => x.put(r, c)); } return res; }).catch(() => cached);
    return cached || rede;
  }));
});
