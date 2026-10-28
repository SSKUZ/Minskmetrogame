import {chromium} from 'playwright';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
const output=path.join(process.env.WAGON_RESULTS_DIR||'test-results/wagon','ui');await mkdir(output,{recursive:true});
const target=process.env.WAGON_TARGET_URL||'http://127.0.0.1:8765/preview/wagon.html';
const launch={headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox']};
if(process.env.WAGON_CHROMIUM_EXECUTABLE){launch.executablePath=process.env.WAGON_CHROMIUM_EXECUTABLE;launch.args.push('--single-process','--in-process-gpu','--no-zygote')}
if(process.env.HTTPS_PROXY&&process.env.WAGON_USE_PROXY==='1')launch.proxy={server:process.env.HTTPS_PROXY,bypass:'127.0.0.1,localhost'};
const browser=await chromium.launch(launch),page=await browser.newPage({viewport:{width:412,height:915},deviceScaleFactor:1}),report={result:'running',target,errors:[]};
page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text())});
if(process.env.WAGON_FETCH_HTML==='1')await page.route('https://sskuz.github.io/**',async r=>r.fulfill({response:await r.fetch()}));
if(process.env.WAGON_LOCAL_ROOT)await page.route('http://127.0.0.1:8765/**',r=>r.fulfill({path:path.join(process.env.WAGON_LOCAL_ROOT,new URL(r.request().url()).pathname),contentType:r.request().url().includes('.html')?'text/html':'application/javascript'}));
if(process.env.WAGON_ASSET_DIR)await page.route('https://cdn.jsdelivr.net/npm/three@0.160.1/**',r=>r.fulfill({path:path.join(process.env.WAGON_ASSET_DIR,r.request().url().endsWith('OrbitControls.js')?'OrbitControls.js':'three.module.js'),contentType:'application/javascript',headers:{'access-control-allow-origin':'*'}}));
try{
 await page.goto(target,{waitUntil:'domcontentloaded',timeout:60000});await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 report.version=await page.evaluate(()=>window.wagonDiagnostics().modelVersion);assert.equal((await page.evaluate(()=>window.wagonTrainDiagnostics())).cars.length,4);
 for(const id of ['formationSelect','carSelect','cameraSelect','doors']){const b=await page.locator('#'+id).boundingBox();assert.ok(b&&b.x>=0&&b.y>=0&&b.x+b.width<=412&&b.y+b.height<=915,`Phone control outside viewport: ${id}`)}
 await page.screenshot({path:path.join(output,'phone-ui-train.png'),timeout:90000});
 await page.selectOption('#carSelect','3');await page.selectOption('#cameraSelect','rear-cab');
 await page.locator('#doors').click();await page.waitForFunction(()=>window.wagonSideDiagnostics().doorProgress===1,null,{timeout:90000});
 report.open=await page.evaluate(()=>window.wagonTrainDiagnostics());assert.ok(report.open.cars.every(c=>c.openLeaves===16));
 await page.screenshot({path:path.join(output,'phone-ui-rear-open.png'),timeout:90000});
 await page.locator('#doors').click();await page.waitForFunction(()=>window.wagonSideDiagnostics().doorProgress===0,null,{timeout:90000});
 await page.waitForTimeout(500);const idle=await page.evaluate(()=>window.wagonDiagnostics().renderedFrames);await page.waitForTimeout(500);report.idleFrames=(await page.evaluate(()=>window.wagonDiagnostics().renderedFrames))-idle;assert.ok(report.idleFrames<=1,'Stationary viewer continues submitting GPU frames');
 const before=await page.evaluate(()=>window.wagonDiagnostics());await page.mouse.move(180,350);await page.mouse.down();await page.mouse.move(245,370,{steps:8});await page.mouse.up();
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>n,before.renderedFrames,{timeout:30000});report.orbit=await page.evaluate(()=>window.wagonDiagnostics().camera);assert.notDeepEqual(report.orbit.position,before.camera.position,'Orbit gesture did not move the camera');
 await page.selectOption('#formationSelect','intermediate');assert.equal((await page.evaluate(()=>window.wagonTrainDiagnostics())).cars[0].type,'81-714');
 const salonFrame=await page.evaluate(()=>window.wagonDiagnostics().renderedFrames);await page.selectOption('#cameraSelect','intermediate-salon');
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,salonFrame,{timeout:90000});
 assert.equal(await page.evaluate(()=>window.wagonDiagnostics().cameraMode),'intermediate-salon');
 assert.deepEqual(report.errors,[]);report.result='pass';
}catch(e){report.result='fail';report.failure=e.stack;throw e}
finally{await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));await browser.close()}
console.log(JSON.stringify({result:report.result,version:report.version,doorButton:true,orbit:true,idleFrames:report.idleFrames}));
