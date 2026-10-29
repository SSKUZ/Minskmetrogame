import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';

export async function launchCabBrowser(){
 const root=process.env.CAB_SOURCE_ROOT?resolve(process.env.CAB_SOURCE_ROOT)+sep:fileURLToPath(new URL('../../',import.meta.url));let server;
 const base=process.env.CAB_BASE_URL??await new Promise(ok=>{
  server=createServer(async(req,res)=>{
   try{
    const path=decodeURIComponent(new URL(req.url,'http://localhost').pathname),file=resolve(root,'.'+(path.endsWith('/')?path+'index.html':path));
    if(!file.startsWith(root.endsWith(sep)?root:root+sep)){res.writeHead(403).end();return;}
    const mime={'.html':'text/html','.js':'application/javascript','.css':'text/css','.png':'image/png','.jpg':'image/jpeg','.mp3':'audio/mpeg','.json':'application/json'};
    const data=await readFile(file);res.writeHead(200,{'Content-Type':mime[extname(file)]??'application/octet-stream','Cache-Control':'no-store'}).end(data);
   }catch{res.writeHead(404).end('Not found');}
  });server.listen(0,'127.0.0.1',()=>ok(`http://127.0.0.1:${server.address().port}`));
 });
 const local=!!process.env.CAB_CHROMIUM;
 const browser=await chromium.launch({headless:true,...(local?{executablePath:process.env.CAB_CHROMIUM}:{}),
  ...(process.env.CAB_BASE_URL?.startsWith('https:')&&process.env.HTTPS_PROXY?{proxy:{server:process.env.HTTPS_PROXY,bypass:'127.0.0.1,localhost'}}:{}),
  args:[...(local&&process.env.CAB_SINGLE_PROCESS==='1'?['--single-process','--in-process-gpu','--no-zygote']:[]),'--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox']});
 const errors=[],requests=[];
 async function page(options={}){
  const p=await browser.newPage({viewport:{width:1536,height:864},deviceScaleFactor:1,...options});
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error'&&/Metro render|ReferenceError|TypeError|SyntaxError|resolve module/i.test(m.text()))errors.push(m.text());});
  p.on('response',r=>{if(r.status()>=400&&!r.url().includes('favicon'))requests.push({url:r.url(),status:r.status()});});
  if(process.env.CAB_THREE_FIXTURE)await p.route('https://cdn.jsdelivr.net/npm/three@0.161.0/**',r=>r.fulfill({path:process.env.CAB_THREE_FIXTURE,contentType:'application/javascript',headers:{'access-control-allow-origin':'*'}}));
  if(base.startsWith('https:'))await p.route(base+'/**',async r=>r.fulfill({response:await r.fetch()}));
  return p;
 }
 return {browser,base,page,errors,requests,async close(){await browser.close();if(server)await new Promise(ok=>server.close(ok));}};
}
export async function ready(page,url){
 await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
 await page.waitForFunction(()=>window.metro3DReady===true&&typeof window.metroDiagnostics==='function'&&!!window.metroCabInspector,null,{timeout:120000});
}
export async function view(page,yaw=0,pitch=-.43,fov=66){
 await page.evaluate(([y,p,f])=>{window.metroCabInspector.setView(y,p);window.metroCabInspector.setZoom(f)},[yaw,pitch,fov]);
 await page.waitForFunction(([y,p])=>Math.abs(window.metroCabInspector.camera.rotation.y-y)<.006&&Math.abs(window.metroCabInspector.camera.rotation.x-p)<.006,[yaw,pitch],{timeout:60000});
}
export async function control(page,id){return page.evaluate(id=>window.metroCabInspector.getControls().find(c=>c.id===id),id)}
export async function samplePerformance(page){return page.evaluate(()=>new Promise(resolve=>{
 const start=performance.now(),times=[];let previous=start;
 function step(now){times.push(now-previous);previous=now;if(now-start<5000||times.length<5){requestAnimationFrame(step);return;}
  const sorted=times.slice(1).sort((a,b)=>a-b),gl=document.querySelector('#scene').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');
  resolve({durationMs:now-start,frames:times.length,fps:(times.length-1)*1000/(now-start-times[0]),medianFrameMs:sorted[Math.floor(sorted.length*.5)],p95FrameMs:sorted[Math.floor(sorted.length*.95)],gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):'unavailable',heapBytes:performance.memory?.usedJSHeapSize,...(window.metroCabInspector.getPerformance?.()??{})});
 }requestAnimationFrame(step);
}));}
