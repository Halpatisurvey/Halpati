// Offline copy of the survey form.
// ONLINE  -> always loads the newest files from the server (so every upload shows up at once).
// OFFLINE (or slow network, 4 seconds) -> opens the saved copy, so the app works in the field.
const V="halpati-v5",FILES=["./","index.html","config.js","manifest.json","icon-192.png","icon-512.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES.map(f=>new Request(f,{cache:"reload"})))).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{
 const u=new URL(e.request.url);
 if(e.request.method!=="GET"||u.origin!==location.origin)return;
 e.respondWith((async()=>{
  const c=await caches.open(V);
  try{
   const r=await Promise.race([fetch(e.request,{cache:"no-cache"}),new Promise((_,j)=>setTimeout(()=>j(new Error("slow")),4000))]);
   if(r&&r.ok)c.put(e.request,r.clone());
   return r;
  }catch(x){
   const hit=await c.match(e.request,{ignoreSearch:true});
   return hit||Response.error();
  }
 })());
});
