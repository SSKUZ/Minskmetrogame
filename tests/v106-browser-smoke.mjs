import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';

await mkdir('test-results/v106',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const page=await browser.newPage({viewport:{width:412,height:915},deviceScaleFactor:1});
const errors=[];let renderErrors=0;
page.on('pageerror',e=>errors.push(e.message));
try{
 await page.goto('http://127.0.0.1:8765/?preview=station&v106=1',{waitUntil:'domcontentloaded',timeout:30000});
 await page.evaluate(()=>window.addEventListener('metro-render-error',()=>window.__v106RenderErrors=(window.__v106RenderErrors||0)+1));
 await page.evaluate(()=>{const original=console.error;console.error=(...args)=>{window.__v106ConsoleErrors=(window.__v106ConsoleErrors||[]).concat(args.map(v=>v?.stack||v?.message||String(v)));original(...args)}});
 await page.waitForFunction(()=>window.metro3DReady===true,null,{timeout:90000});
 // Station preview already selects the platform camera. Only toggle it when
 // a future startup path leaves it disabled; blindly clicking here used to
 // turn the correct preview camera off and produced a false-negative smoke failure.
 const stationCameraAlreadyActive=await page.evaluate(()=>window.metroV106Diagnostics?.().stationCameraActive===true);
 if(!stationCameraAlreadyActive)await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().loaded===true,null,{timeout:90000});
 const state=await page.evaluate(()=>window.metroV106Diagnostics());
 renderErrors=await page.evaluate(()=>window.__v106RenderErrors||0);
 assert.equal(renderErrors,0,'main render loop failed while v106 was active: '+JSON.stringify(await page.evaluate(()=>window.__v106ConsoleErrors||[])));
 assert.equal(state.loaded,true,JSON.stringify(state));
 assert.equal(state.metrics.doorLeaves,64);
 assert.equal(state.metrics.warningDecals,64,'all original v106 door warning decals must survive gameplay import');
 assert.equal(state.metrics.warningTexturesRehomed,1,'warning decal canvas texture must be transferred into gameplay renderer realm');
 assert.ok(state.metrics.rehomedAttributes>1000,'v106 buffers were not transferred to the game THREE realm');
 assert.ok(state.metrics.lightCount>0,'original v106 lighting rig was not imported');
 assert.ok(state.metrics.rehomedEnvironmentMaterials>0,'original studio reflections were not rebuilt in the gameplay WebGL context');
 assert.ok(state.metrics.meshCount>0);
 assert.ok(state.metrics.triangles>0);
 assert.equal(state.stationCameraActive,true);
 assert.equal(state.inCamera,true,'v106 geometry is loaded but outside station camera: '+JSON.stringify(state));
 // The detailed model's first car is centered half a car behind the front anchor.
 assert.ok(Math.abs(state.trainPosition[2]-(state.trainAnchorZ+19.206/2))<.001,'incorrect v106 longitudinal placement');
 assert.ok(Math.abs(state.platformGap-state.targetPlatformGap)<.001,'v106 platform clearance is not calibrated: '+JSON.stringify(state));
 assert.ok(state.platformGap>=.008&&state.platformGap<=.012,'v106 doorway/body edge must remain about 1 cm from platform: '+state.platformGap);
 assert.equal(state.measuredThresholdCount,16,'platform gap must be measured from all 16 real door-threshold meshes');
 assert.ok(Math.abs(state.trainPosition[0]-state.railCentreX)<.001,'v106 bogies are displaced sideways from the rails: '+JSON.stringify(state));
 assert.deepEqual(state.railPositions,[-.9,.9],'station rails must use v106 wheel-contact centres');
 assert.ok(state.wheelContactPositions.every((x,i)=>Math.abs(x-state.railPositions[i])<.001),'v106 wheel contacts do not sit on rail centres: '+JSON.stringify(state));
 assert.ok(Math.abs(state.platformEdgeX-(-1.348))<.001,'island slab edge is not aligned with the original 81-717 threshold: '+state.platformEdgeX);
 assert.ok(Math.abs(state.trainPosition[1]-state.platformPosition[1])<.001,'v106 and platform elevation differ');
 await page.screenshot({path:'test-results/v106/station-closed.png'});
 // Also capture the full desktop camera framing; mobile-only images can hide clipping.
 await page.setViewportSize({width:1365,height:768});
 await page.waitForTimeout(450);
 await page.screenshot({path:'test-results/v106/station-desktop-closed.png'});
 await page.locator('#screenDoorToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorsOpen===true,null,{timeout:60000});
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorProgress>.8,null,{timeout:120000});
 await page.screenshot({path:'test-results/v106/station-open.png'});
 await page.screenshot({path:'test-results/v106/station-desktop-open.png'});
 const after=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(after.doorsOpen,true);
 // Reversing the door command must close all animated leaves, not only open them.
 await page.locator('#screenDoorToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().doorProgress<.05,null,{timeout:120000});
 const closedAgain=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(closedAgain.doorsOpen,false);
 // The original model must survive leaving and re-entering the platform camera.
 await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().stationCameraActive===false);
 await page.locator('#stationCameraToggle').click();
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().stationCameraActive===true);
 // Re-entry may be slow in software WebGL; visibility must be checked after
 // the camera has rendered a new frame rather than during the toggle.
 await page.waitForFunction(()=>window.metroV106Diagnostics?.().inCamera!==null,null,{timeout:90000});
 const restored=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(restored.loaded,true);
 assert.equal(restored.metrics.doorLeaves,64);
 // The in-game "carriage view" must render the authentic imported v106 saloon,
 // never the legacy CarriageInterior mock-up.
 await page.locator('#carCameraToggle').click();
 await page.waitForFunction(()=>window.metroDiagnostics?.().camera==='carriage');
 await page.waitForTimeout(1200);
 const saloon=await page.evaluate(()=>window.metroV106Diagnostics());
 assert.equal(saloon.loaded,true,'v106 must remain loaded in carriage view');
 assert.equal(await page.locator('#carCameraToggle').innerText(),'🎮 В КАБИНУ');
 await page.screenshot({path:'test-results/v106/v106-saloon.png',timeout:120000,animations:'disabled'});
 await page.locator('#carCameraToggle').click();
 await page.waitForFunction(()=>window.metroDiagnostics?.().camera==='cab');
 // Final integration check: drive the train away from the platform with real traction.
 // Use the same master-controller pointer interaction as a player, then verify
 // that physics advances and the imported v106 remains render-stable in motion.
 const beforeMove=await page.evaluate(()=>window.metroDiagnostics());
 const master=page.locator('#masterTrack');
 const box=await master.boundingBox();
 assert.ok(box,'master controller is unavailable');
 await page.mouse.move(box.x+box.width/2,box.y+box.height*.12);
 await page.mouse.down();
 await page.mouse.up();
 assert.match(await page.locator('#masterValue').innerText(),/ТЯГА/,'master controller did not engage traction');
 await page.waitForFunction(()=>window.metroDiagnostics?.().train.speed>3,null,{timeout:90000});
 await page.waitForFunction(()=>window.metroDiagnostics?.().train.distanceToStation<-2,null,{timeout:90000});
 const moving=await page.evaluate(()=>({game:window.metroDiagnostics(),v106:window.metroV106Diagnostics()}));
 assert.ok(moving.game.train.speed>3,'train failed to accelerate under traction: '+JSON.stringify(moving));
 assert.ok(moving.game.train.distanceToStation<beforeMove.train.distanceToStation-2,'train distance did not advance: '+JSON.stringify({beforeMove,moving}));
 assert.equal(moving.v106.loaded,true,'v106 unloaded while train was moving');
 assert.equal(moving.v106.metrics.warningDecals,64,'warning decals disappeared while moving');
 // Software WebGL may need over 30s to deliver a full frame while the train moves.
 await page.screenshot({path:'test-results/v106/station-desktop-moving.png',timeout:120000,animations:'disabled'});
 renderErrors=await page.evaluate(()=>window.__v106RenderErrors||0);
 assert.equal(renderErrors,0,'main render loop failed during v106 smoke');
 assert.deepEqual(errors,[]);
 console.log(JSON.stringify({state,after},null,2));
}finally{await browser.close()}
