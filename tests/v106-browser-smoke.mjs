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
 // The detailed model's first car is centered half a car behind the front anchor.
 assert.ok(Math.abs(state.trainPosition[2]-(state.trainAnchorZ+19.206/2))<.001,'incorrect v106 longitudinal placement');
 assert.ok(Math.abs(state.trainPosition[0]+.31)<.001,'incorrect v106 track lateral alignment');
 assert.ok(Math.abs(state.trainPosition[1]-state.platformPosition[1])<.001,'v106 and platform elevation differ');
 await page.screenshot({path:'test-results/v106/station-closed.png'});
 // Also capture the full desktop camera framing; mobile-only images can hide clipping.
 await page.setViewportSize({width:1365,height:768});
 await page.waitForTimeout(450);
 await page.screenshot({path:'test-results/v106/station-desktop-closed.png'});
 await page.locator('#screenDoorToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorProgress>.8,{timeout:12000});
 await page.screenshot({path:'test-results/v106/station-open.png'});
 await page.screenshot({path:'test-results/v106/station-desktop-open.png'});
 const after=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(after.doorsOpen,true);
 // Reversing the door command must close all animated leaves, not only open them.
 await page.locator('#screenDoorToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorProgress<.05,{timeout:12000});
 const closedAgain=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(closedAgain.doorsOpen,false);
 // The original model must survive leaving and re-entering the platform camera.
 await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().stationCameraActive===false);
 await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().visible===true);
 const restored=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(restored.loaded,true);
 assert.equal(restored.metrics.doorLeaves,64);
 assert.deepEqual(errors,[]);
 console.log(JSON.stringify({state,after},null,2));
}finally{await browser.close()}
