import {chromium} from 'playwright';
import {PNG} from 'pngjs';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

const output=path.join(process.env.WAGON_RESULTS_DIR||'test-results/wagon','warnings');
await mkdir(output,{recursive:true});
const target=process.env.WAGON_TARGET_URL||'http://127.0.0.1:8765/preview/wagon.html';
const launch={headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox']};
if(process.env.WAGON_CHROMIUM_EXECUTABLE){launch.executablePath=process.env.WAGON_CHROMIUM_EXECUTABLE;launch.args.push('--single-process','--in-process-gpu','--no-zygote')}
if(process.env.HTTPS_PROXY&&process.env.WAGON_USE_PROXY==='1')launch.proxy={server:process.env.HTTPS_PROXY,bypass:'127.0.0.1,localhost'};
const browser=await chromium.launch(launch),page=await browser.newPage({viewport:{width:1536,height:934},deviceScaleFactor:1});
const errors=[],report={result:'running',target,views:[],errors};
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
if(process.env.WAGON_FETCH_HTML==='1')await page.route('https://**/wagon.html*',async r=>r.fulfill({response:await r.fetch()}));
if(process.env.WAGON_LOCAL_ROOT)await page.route('http://127.0.0.1:8765/**',r=>r.fulfill({path:path.join(process.env.WAGON_LOCAL_ROOT,new URL(r.request().url()).pathname),contentType:r.request().url().includes('.html')?'text/html':'application/javascript'}));
if(process.env.WAGON_ASSET_DIR)await page.route('https://cdn.jsdelivr.net/npm/three@0.160.1/**',r=>r.fulfill({path:path.join(process.env.WAGON_ASSET_DIR,r.request().url().endsWith('OrbitControls.js')?'OrbitControls.js':'three.module.js'),contentType:'application/javascript',headers:{'access-control-allow-origin':'*'}}));
try{
 const url=new URL(target);url.searchParams.set('qa','1');url.searchParams.set('formation','single');
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 const module=html=>html.match(/<script type="module">([\s\S]*?)<\/script>/)[1],hash=s=>createHash('sha256').update(s).digest('hex');
 report.moduleSha256=hash(await page.locator('script[type="module"]').textContent());
 assert.equal(report.moduleSha256,hash(module(await readFile('preview/wagon.html','utf8'))),'Published warning source is stale');
 report.version=await page.evaluate(()=>window.wagonDiagnostics().modelVersion);
 assert.equal(await page.locator('#warningOverlay').count(),0,'Obsolete DOM sticker overlay remains');
 for(const view of ['side-full','side-negative','warning-positive','warning-negative','warning-oblique']){
  const start=await page.evaluate(v=>{window.wagonSetCamera(v);return window.wagonDiagnostics().renderedFrames},view);
  await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,start,{timeout:60000});
  const stickers=await page.evaluate(()=>window.wagonWarningDiagnostics());
  assert.equal(stickers.length,16,'Head wagon must have sixteen warnings');
  const file=path.join(output,view+'.png');await page.screenshot({path:file,timeout:90000});
  const png=PNG.sync.read(await readFile(file)),side=view.includes('negative')?-1:1,visible=stickers.filter(s=>s.side===side),counts=[];
  for(const s of stickers){
   assert.ok(s.depthTest,'Warnings must respect the metal body depth');
   assert.ok(s.bounds.min[1]>=1.379&&s.bounds.max[1]<=1.541,'Warning overlaps a pressed rib');
   assert.ok(Math.abs(s.center[2]-s.doorZ)>.69+.12,'Warning lies on a moving door');
  }
  if(view.startsWith('side-'))for(const s of visible){
   const [cx,cy]=s.screen;let yellow=0;
   for(let y=Math.floor(cy-8);y<=Math.ceil(cy+8);y++)for(let x=Math.floor(cx-12);x<=Math.ceil(cx+12);x++){
    if(x<0||y<0||x>=png.width||y>=png.height)continue;const i=(y*png.width+x)*4;
    if(png.data[i]>150&&png.data[i+1]>110&&png.data[i+2]<85)yellow++;
   }
   assert.ok(yellow>=12,`Warning is not visible in actual pixels: ${view}, door ${s.doorZ}, direction ${s.direction}, yellow ${yellow}`);
   counts.push({doorZ:s.doorZ,direction:s.direction,yellowPixels:yellow});
  }
  report.views.push({view,screenshot:path.basename(file),visibleWarnings:counts});
 }
 assert.deepEqual(errors,[]);report.result='pass';
}catch(e){report.result='fail';report.failure=e.stack;throw e}
finally{await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));await browser.close()}
console.log(JSON.stringify({result:report.result,version:report.version,actualYellowWarnings:16,views:report.views.map(v=>v.view)}));
