import {chromium} from 'playwright';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';

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
async function frame(view){
 const n=await page.evaluate(v=>{window.wagonSetCamera(v);return window.wagonDiagnostics().renderedFrames},view);
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,n,{timeout:60000});
 await page.screenshot({path:path.join(output,view+'.png'),timeout:90000});report.views.push(view);
}
try{
 const url=new URL(target);url.searchParams.set('qa','1');url.searchParams.set('formation','intermediate');
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 report.version=await page.evaluate(()=>window.wagonDiagnostics().modelVersion);
 report.intermediate=await page.evaluate(()=>window.wagonTrainDiagnostics());
 assert.equal(report.intermediate.cars.length,1);const c=report.intermediate.cars[0];
 assert.equal(c.type,'81-714');assert.equal(c.hasCab,false);assert.equal(c.seats,44);assert.equal(c.wheels,8);assert.equal(c.ends,2);assert.equal(c.windows,10);assert.equal(c.leaves,16);assert.equal(c.warnings,16);
 for(const view of ['intermediate-side','intermediate-angle','intermediate-salon','rear-end','warning-positive','warning-negative'])await frame(view);
 await page.evaluate(()=>window.wagonSetDoors(true,{instant:true}));await frame('door-open');
 report.open=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.equal(report.open.cars[0].openLeaves,16);assert.ok(Math.abs(report.open.cars[0].doorClearWidth-1.208)<.0001);
 await page.evaluate(()=>window.wagonSetDoors(false,{instant:true}));report.closed=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.equal(report.closed.cars[0].openLeaves,0);
 assert.deepEqual(errors,[]);report.result='pass';
}catch(e){report.result='fail';report.failure=e.stack;throw e}
finally{await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));await browser.close()}
console.log(JSON.stringify({result:report.result,version:report.version,cars:report.intermediate.cars,views:report.views}));
