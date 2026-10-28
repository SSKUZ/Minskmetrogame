import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';

await mkdir('test-results/v106',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const page=await browser.newPage({viewport:{width:412,height:915},deviceScaleFactor:1});
const errors=[];
page.on('pageerror',e=>errors.push(e.message));
try{
 await page.goto('http://127.0.0.1:8765/?preview=station',{waitUntil:'domcontentloaded',timeout:30000});
 await page.waitForFunction(()=>window.metro3DReady===true,{timeout:90000});
 await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().loaded===true,{timeout:90000});
 const state=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(state.loaded,true,JSON.stringify(state));
 assert.equal(state.metrics.doorLeaves,64);
 assert.ok(state.metrics.meshCount>0);
 assert.ok(state.metrics.triangles>0);
 assert.equal(state.stationCameraActive,true);
 await page.screenshot({path:'test-results/v106/station-closed.png'});
 await page.locator('#screenDoorToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorProgress>.8,{timeout:12000});
 await page.screenshot({path:'test-results/v106/station-open.png'});
 const after=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(after.doorsOpen,true);
 assert.deepEqual(errors,[]);
 console.log(JSON.stringify({state,after},null,2));
}finally{await browser.close()}
