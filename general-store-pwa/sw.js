const CACHE='general-store-pwa-v7';
const SUPABASE_SCRIPT='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
const CORE=['./','./index.html','./config.js','./manifest.webmanifest','./icon.svg'];
self.addEventListener('install',event=>{event.waitUntil((async()=>{const cache=await caches.open(CACHE);await cache.addAll(CORE);try{const response=await fetch(SUPABASE_SCRIPT,{mode:'cors'});if(response.ok)await cache.put(SUPABASE_SCRIPT,response.clone())}catch(e){}await self.skipWaiting()})())});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',event=>{
 const req=event.request;
 if(req.method!=='GET')return;
 const url=new URL(req.url);
 if(url.href.startsWith(SUPABASE_SCRIPT)){
  event.respondWith(fetch(req).then(res=>{if(res.ok)caches.open(CACHE).then(c=>c.put(req,res.clone()));return res}).catch(()=>caches.match(req).then(hit=>hit||caches.match(SUPABASE_SCRIPT))));
  return;
 }
 if(url.origin!==self.location.origin)return;
 event.respondWith(caches.match(req).then(hit=>hit||fetch(req).then(res=>{if(res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(req,copy))}return res}).catch(()=>caches.match('./index.html'))));
});
