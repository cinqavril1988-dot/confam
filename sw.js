const CACHE='confam-shell-v24';
const CORE=['/','/index.html','/styles.css','/app.js','/config.js','/manifest.webmanifest','/favicon.svg'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>true)));
self.addEventListener('message',e=>{if(e.data&&e.data.type==='SKIP_WAITING')self.skipWaiting()});
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=='GET'||u.origin!==location.origin)return;
  const fresh=['/','/index.html','/styles.css','/app.js','/config.js'].includes(u.pathname);
  if(fresh){
    e.respondWith(fetch(e.request).then(res=>{
      if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));}
      return res;
    }).catch(()=>caches.match(e.request).then(hit=>hit||caches.match('/index.html'))));
    return;
  }
  e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(res=>{
    if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));}
    return res;
  }).catch(()=>caches.match('/index.html'))));
});