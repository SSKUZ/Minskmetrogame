import {chromium} from 'playwright';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {PNG} from 'pngjs';
import {createHash} from 'node:crypto';

const output=path.join(process.env.WAGON_RESULTS_DIR||'test-results/wagon','train');await mkdir(output,{recursive:true});
const target=process.env.WAGON_TARGET_URL||'http://127.0.0.1:8765/preview/wagon.html';
const launch={headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox']};
if(process.env.WAGON_CHROMIUM_EXECUTABLE){launch.executablePath=process.env.WAGON_CHROMIUM_EXECUTABLE;launch.args.push('--single-process','--in-process-gpu','--no-zygote')}
if(process.env.HTTPS_PROXY&&process.env.WAGON_USE_PROXY==='1')launch.proxy={server:process.env.HTTPS_PROXY,bypass:'127.0.0.1,localhost'};
const browser=await chromium.launch(launch),page=await browser.newPage({viewport:{width:1536,height:934},deviceScaleFactor:1});
const errors=[],report={result:'running',target,views:[],errors};
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
if(process.env.WAGON_FETCH_HTML==='1')await page.route('https://sskuz.github.io/**',async r=>r.fulfill({response:await r.fetch()}));
if(process.env.WAGON_LOCAL_ROOT)await page.route('http://127.0.0.1:8765/**',r=>r.fulfill({path:path.join(process.env.WAGON_LOCAL_ROOT,new URL(r.request().url()).pathname),contentType:r.request().url().includes('.html')?'text/html':'application/javascript'}));
if(process.env.WAGON_ASSET_DIR)await page.route('https://cdn.jsdelivr.net/npm/three@0.160.1/**',r=>r.fulfill({path:path.join(process.env.WAGON_ASSET_DIR,r.request().url().endsWith('OrbitControls.js')?'OrbitControls.js':'three.module.js'),contentType:'application/javascript',headers:{'access-control-allow-origin':'*'}}));
async function frame(view,name=view){
 const n=await page.evaluate(v=>{window.wagonSetCamera(v);return window.wagonDiagnostics().renderedFrames},view);
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,n,{timeout:60000});
 if(view.startsWith('train-')){const b=await page.evaluate(()=>window.wagonTrainFraming());assert.ok(b.maxX<.97&&b.maxY<.97,'Whole-train camera crops a body end');}
 await page.screenshot({path:path.join(output,name+'.png'),timeout:90000});report.views.push(name);
 report.frameStats??=[];report.frameStats.push({view:name,...await page.evaluate(()=>window.wagonFrameStats)});
}
try{
 const url=new URL(target);url.searchParams.set('qa','1');url.searchParams.set('formation','intermediate');
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 const source=await readFile('preview/wagon.html','utf8'),hash=s=>createHash('sha256').update(s).digest('hex');
 assert.equal(hash(await page.locator('script[type="module"]').textContent()),hash(source.match(/<script type="module">([\s\S]*?)<\/script>/)[1]),'Published viewer is stale');
 report.externalModules=[];
 for(const match of source.matchAll(/from '\.\/([^']+\.js(?:\?[^']*)?)'/g)){
  const file=match[1],response=await page.evaluate(async file=>{const r=await fetch(new URL(file,location.href));return {status:r.status,text:await r.text()}},file);
  assert.equal(response.status,200,`Missing published module: ${file}`);
  const sha=hash(response.text);assert.equal(sha,hash(await readFile(path.join('preview',file.split('?')[0]),'utf8')),`Stale published module: ${file}`);report.externalModules.push({file,sha256:sha});
 }
 report.version=await page.evaluate(()=>window.wagonDiagnostics().modelVersion);
 report.intermediate=await page.evaluate(()=>window.wagonTrainDiagnostics());
 assert.equal(report.intermediate.cars.length,1);const c=report.intermediate.cars[0];
 assert.equal(c.type,'81-714');assert.equal(c.hasCab,false);assert.equal(c.seats,44);assert.equal(c.wheels,8);assert.equal(c.ends,2);assert.equal(c.windows,10);assert.equal(c.leaves,16);assert.equal(c.warnings,16);
 for(const view of ['intermediate-side','intermediate-angle','intermediate-salon','rear-end','warning-positive','warning-negative'])await frame(view);
 await page.evaluate(()=>window.wagonSetDoors(true,{instant:true}));await frame('door-open');
 report.open=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.equal(report.open.cars[0].openLeaves,16);assert.ok(Math.abs(report.open.cars[0].doorClearWidth-1.208)<.0001);
 await page.evaluate(()=>window.wagonSetDoors(false,{instant:true}));report.closed=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.equal(report.closed.cars[0].openLeaves,0);
 if(report.version>=105){
  await page.evaluate(()=>window.wagonSetFormation('train'));
  report.train=await page.evaluate(()=>window.wagonTrainDiagnostics());
  assert.deepEqual(report.train.cars.map(c=>c.type),['81-717','81-714','81-714','81-717']);
  assert.deepEqual(report.train.cars.map(c=>c.seats),[40,44,44,40]);
  assert.deepEqual(report.train.cars.map(c=>c.frontLamps),[6,0,0,6]);
  assert.deepEqual(report.train.cars.map(c=>c.frontPanes),[3,0,0,3]);
  assert.ok(report.train.cars[0].cabDirection[2]<-.999&&report.train.cars[3].cabDirection[2]>.999,'Both cabs must face outwards');
  for(const car of report.train.cars){assert.equal(car.position[0],0);assert.equal(car.position[1],0);assert.deepEqual(car.scale,[1,1,1]);assert.equal(car.warnings,16);assert.equal(car.wheels,8);assert.equal(car.leaves,16)}
  assert.equal(report.train.joints.length,3);
  for(const j of report.train.joints){assert.ok(Math.abs(j.bodyGap-.80)<.00001,'Bodies overlap or separate excessively');assert.ok(j.couplingGap<.00001,'Actual cast coupling faces do not meet');assert.ok(j.opposedNormals<-.99999)}
  assert.ok(report.train.uniqueGeometries<report.train.cars.reduce((n,c)=>n+c.meshes,0)*.6,'Car copies duplicate GPU geometry');
  if(report.version>=106)for(const b of Object.values(report.train.batching)){assert.equal(b.before.triangles,b.after.triangles,'Optimisation removed triangles');assert.ok(b.after.meshes<b.before.meshes*.5,'Static batching failed to reduce object submissions')}
  for(const view of ['train-side','train-side-negative','train-angle','front','rear-cab','rear-cab-angle','intercar','coupling-close'])await frame(view);
  report.visibleWarningPixels=[];
  for(let car=0;car<4;car++){
   await page.evaluate(i=>window.wagonSelectCar(i),car);
   for(const [view,localSide] of [['side-full',1],['side-negative',-1]]){
    const name=`car-${car+1}-${view}`;await frame(view,name);
    const stickers=await page.evaluate(()=>window.wagonWarningDiagnostics()),worldSide=localSide*(car===3?-1:1);
    const visible=stickers.filter(s=>s.carIndex===car&&s.side===worldSide);assert.equal(visible.length,8);
    const png=PNG.sync.read(await readFile(path.join(output,name+'.png')));
    for(const s of visible){
     const [cx,cy]=s.screen;let yellow=0;
     for(let y=Math.floor(cy-8);y<=Math.ceil(cy+8);y++)for(let x=Math.floor(cx-12);x<=Math.ceil(cx+12);x++){
      if(x<0||y<0||x>=png.width||y>=png.height)continue;const i=(y*png.width+x)*4;if(png.data[i]>150&&png.data[i+1]>110&&png.data[i+2]<85)yellow++;
     }
     assert.ok(yellow>=12,`Car ${car+1}, ${view}: warning is absent from actual pixels`);report.visibleWarningPixels.push({car:car+1,side:worldSide,doorZ:s.doorZ,yellow});
    }
   }
  }
  assert.equal(report.visibleWarningPixels.length,64);
  await page.evaluate(()=>window.wagonSetDoors(true,{instant:true}));report.trainOpen=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.ok(report.trainOpen.cars.every(c=>c.openLeaves===16));
  await page.evaluate(()=>window.wagonSetDoors(false,{instant:true}));assert.ok((await page.evaluate(()=>window.wagonTrainDiagnostics())).cars.every(c=>c.openLeaves===0));
  await page.setViewportSize({width:412,height:915});await frame('train-angle','phone-train');await frame('rear-cab','phone-rear-cab');
 }
 assert.deepEqual(errors,[]);report.result='pass';
}catch(e){report.result='fail';report.failure=e.stack;throw e}
finally{await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));await browser.close()}
console.log(JSON.stringify({result:report.result,version:report.version,cars:report.intermediate.cars,views:report.views}));
