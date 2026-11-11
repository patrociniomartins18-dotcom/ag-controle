var CACHE_NAME = 'ag-controle-vendas-v7';
var NUCLEO = ['./', './index.html', './manifest.json', './supabase.js', './config.js', './logo.png', './favicon.ico', './icon-192.png', './icon-512.png', './icon-maskable-512.png', './apple-touch-icon.png'];
/* Recursos externos que o app usa (estilo, fontes e mapas): guardados para funcionar sem internet depois do primeiro acesso. */
var HOSTS_CACHE = ['cdn.tailwindcss.com', 'fonts.googleapis.com', 'fonts.gstatic.com', 'cdn.jsdelivr.net', 'server.arcgisonline.com'];

self.addEventListener('install', function(event){
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache){
      return Promise.all(NUCLEO.map(function(u){ return cache.add(u).catch(function(){}); }));
    })
  );
});

self.addEventListener('activate', function(event){
  event.waitUntil(
    caches.keys().then(function(keys){
      return Promise.all(keys.filter(function(k){ return k !== CACHE_NAME; }).map(function(k){ return caches.delete(k); }));
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(event){
  var req = event.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  var mesmaOrigem = url.origin === self.location.origin;
  /* O banco (Supabase) e qualquer outro serviço nunca passam pelo cache. */
  if (!mesmaOrigem && HOSTS_CACHE.indexOf(url.hostname) === -1) return;
  event.respondWith(
    caches.match(req).then(function(cached){
      var rede = fetch(req).then(function(resp){
        if (resp && (resp.status === 200 || resp.type === 'opaque')){
          var copia = resp.clone();
          caches.open(CACHE_NAME).then(function(cache){ cache.put(req, copia); });
        }
        return resp;
      }).catch(function(){ return cached; });
      return cached || rede;
    })
  );
});
