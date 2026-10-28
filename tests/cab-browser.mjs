import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {writeFileSync} from 'node:fs';
import {launchCabBrowser,ready,view,control,samplePerformance} from './helpers/cab-browser-fixture.mjs';

const out=process.env.CAB_RESULTS??'test-results/cab';await mkdir(out,{recursive:true});
const suite=process.env.CAB_SUITE??'all';assert.ok(['all','desktop','mobile','launch'].includes(suite),'unknown CAB_SUITE');
const reportPath=`${out}/browser${suite==='all'?'':'-'+suite}-report.json`;
let fixture=await launchCabBrowser();const checks=[],report={suite,status:'running',checks,errors:[],requests:[]};
// Functional checks do not need a 1536px screenshot for every input. The
// separate reference comparison retains its full 1536×864 resolution.
let page=await fixture.page({viewport:{width:1024,height:576}});
async function restart(){report.errors.push(...fixture.errors);report.requests.push(...fixture.requests);await fixture.close();fixture=await launchCabBrowser();}
const pass=(name,detail)=>{checks.push({name,result:'passed',detail});writeFileSync(reportPath,JSON.stringify(report,null,2));console.log('PASS',name)};
async function capture(p,name){if(process.env.CAB_CAPTURE_DETAILS==='0'&&!/^(01-|02-|03-|09-|10-|11-)/.test(name))return;await p.screenshot({path:`${out}/${name}.png`,animations:'disabled',timeout:120000});}
async function state(p=page){return p.evaluate(()=>window.metroCabInspector.getState());}
async function click(id,p=page){const c=await control(p,id);assert.ok(c?.inFrame,`${id} must be in frame`);await p.mouse.click(c.x,c.y);return c;}
async function waitState(fn,arg,p=page){await p.waitForFunction(fn,arg,{timeout:60000});}
async function focus(id,p=page){await p.evaluate(id=>window.metroCabInspector.focusControl(id),id);await p.waitForFunction(()=>{const a=window.metroCabInspector;return Math.abs(a.camera.rotation.x-a.getView().pitch)<.004&&Math.abs(a.camera.rotation.y-a.getView().yaw)<.004},null,{timeout:60000});}
try{
 if(suite==='all'||suite==='desktop'){
 report.desktopViewport=page.viewportSize();
 await ready(page,fixture.base+'/?preview=station&cabInspector=1');await view(page);
 await page.evaluate(()=>document.body.classList.add('cab-capture'));await capture(page,'01-reference-view');await page.evaluate(()=>document.body.classList.remove('cab-capture'));
 const model=await page.evaluate(()=>{const a=window.metroCabInspector;let meshes=0,triangles=0;const geometries=new Set(),materials=new Set();a.cab.traverse(o=>{if(o.isMesh){meshes++;triangles+=(o.geometry.index?.count??o.geometry.attributes.position.count)/3*(o.isInstancedMesh?o.count:1);geometries.add(o.geometry);materials.add(o.material);}});return {meshes,triangles,geometries:geometries.size,materials:materials.size,version:a.version,controls:a.getControls()};});
 assert.equal(model.version,'cab-r2');assert.ok(model.controls.length>=35);report.model=model;pass('actual game cab loaded',model.version);
 await click('open');await waitState(()=>window.metroCabInspector.getState().doors===true);pass('3D door open uses game validation');
 await page.keyboard.press('KeyI');assert.equal((await state()).lastAction.id,'info');pass('keyboard INFO command');
 await focus('carriage');await click('carriage');await waitState(()=>window.metroDiagnostics().camera==='carriage');await capture(page,'02-carriage-regression');
 await page.locator('#carCameraToggle').click();await waitState(()=>window.metroDiagnostics().camera==='cab');
 await page.locator('#stationCameraToggle').click();await waitState(()=>window.metroDiagnostics().camera==='platform');await capture(page,'03-platform-regression');
 await page.locator('#stationCameraToggle').click();await waitState(()=>window.metroDiagnostics().camera==='cab');pass('carriage and platform cameras still render');
 await view(page);await click('close');await waitState(()=>!window.metroCabInspector.getState().doors);pass('3D door close');
 const lamp=await control(page,'lampTest');await page.mouse.move(lamp.x,lamp.y);await page.mouse.down();assert.equal((await state()).lampTest,true);await capture(page,'04-lamp-test');await page.mouse.up();assert.equal((await state()).lampTest,false);pass('momentary lamp check and release');
 const beforeLight=(await state()).switches.cabLight;await click('cabLight');assert.notEqual((await state()).switches.cabLight,beforeLight);await capture(page,'05-cab-light-off');await click('cabLight');pass('3D cabin light selector');
 await click('wiperLeft');assert.equal((await state()).switches.wiperLeft,1);await click('wiperLeft');pass('3D wiper selector');
 await click('headlights');assert.equal((await state()).switches.headlights,0);await click('headlights');pass('headlight selector');
 await page.keyboard.down('KeyH');assert.equal((await state()).hornActive,true);await page.keyboard.up('KeyH');assert.equal((await state()).hornActive,false);pass('horn press/release');
 await focus('volume');await click('volume');assert.equal((await state()).switches.volume,.85);pass('radio volume control');
 await focus('mirrorLeft');await click('mirrorLeft');assert.equal((await state()).switches.mirrorLeft,0);await click('mirrorLeft');pass('mirror on/off');
 await focus('service');await click('service');assert.equal((await state()).lever,-.5);await click('release');assert.equal((await state()).lever,0);await click('emergency');assert.equal((await state()).lever,-1);await click('release');pass('3D service/release/emergency buttons');
 await focus('master');let master=await control(page,'master'),beforeView=await page.evaluate(()=>window.metroCabInspector.getView());
 await page.mouse.move(master.x,master.y);await page.mouse.down();await page.mouse.move(master.x,master.y-100,{steps:8});await page.mouse.up();
 assert.ok((await state()).lever>.2,'dragging real controller must apply traction');
 const afterView=await page.evaluate(()=>window.metroCabInspector.getView());assert.equal(afterView.yaw,beforeView.yaw);assert.equal(afterView.pitch,beforeView.pitch);pass('3D controller drag does not drag camera');
 await waitState(()=>window.metroCabInspector.getState().speed>.5);pass('actual physics accelerates from 3D handle');
 await page.keyboard.press('Space');await waitState(()=>window.metroCabInspector.getState().speed<.1);assert.equal((await state()).lever,-1);pass('keyboard full brake stops train');
 await page.keyboard.press('KeyN');await focus('brake');const brake=await control(page,'brake');assert.ok(brake.inFrame);
 await page.mouse.move(brake.x,brake.y);await page.mouse.down();await page.mouse.move(brake.x,brake.y+100,{steps:8});await page.mouse.up();assert.ok((await state()).lever<-.2);pass('physical brake valve drag');
 await page.keyboard.press('KeyN');await page.keyboard.press('Digit5');await waitState(()=>window.metroCabInspector.getState().speed>4);
 await page.keyboard.press('KeyO');assert.equal((await state()).doors,false);assert.equal((await state()).lastAction.ok,false);pass('doors stay locked while moving');
 await page.keyboard.press('Space');await waitState(()=>window.metroCabInspector.getState().speed<.1);await page.keyboard.press('KeyN');
 await view(page,0,-.03);await capture(page,'06-driving-view');await view(page,.62,-.37);await capture(page,'07-radio-left');await view(page,-.62,-.37);await capture(page,'08-brake-right');
 await view(page);report.desktopPerformance=await samplePerformance(page);pass('desktop frame and memory sample',{fps:report.desktopPerformance.fps,gpu:report.desktopPerformance.gpu});
 await restart();
 }

 if(suite==='all'||suite==='mobile'){
 const mobile=await fixture.page({viewport:{width:412,height:915},hasTouch:true,isMobile:true});
 page=mobile;await ready(mobile,fixture.base+'/?preview=station&cabInspector=1');
 async function phoneLayout(){
  return mobile.evaluate(()=>{
   const hud=document.querySelector('#hud').getBoundingClientRect(),camera=document.querySelector('#stationCameraToggle').getBoundingClientRect();
   const buttons=[...document.querySelectorAll('#cabLookBar button')].map(b=>b.getBoundingClientRect().height);
   return {hudRight:hud.right,cameraLeft:camera.left,buttons,overflow:document.documentElement.scrollWidth-innerWidth};
  });
 }
 for(const width of [360,412]){
  await mobile.setViewportSize({width,height:width===360?780:915});const layout=await phoneLayout();
  assert.ok(layout.hudRight+3<=layout.cameraLeft,'phone HUD must not overlap camera buttons');assert.ok(layout.buttons.every(h=>h>=40));assert.ok(layout.overflow<=1);
  pass('phone HUD and touch targets at '+width+'px',layout);
 }
 await capture(mobile,'09-mobile-driving');await focus('open',mobile);
 const open=await control(mobile,'open');assert.ok(open.inFrame);await mobile.touchscreen.tap(open.x,open.y);await waitState(()=>window.metroCabInspector.getState().doors,null,mobile);pass('real mobile touchscreen opens 3D door control');
 await focus('close',mobile);const close=await control(mobile,'close');await mobile.touchscreen.tap(close.x,close.y);await waitState(()=>!window.metroCabInspector.getState().doors,null,mobile);
 await focus('master',mobile);const master=await control(mobile,'master');const cdp=await mobile.context().newCDPSession(mobile),startView=await mobile.evaluate(()=>window.metroCabInspector.getView());
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:master.x,y:master.y}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:master.x,y:master.y-90}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});assert.ok((await state(mobile)).lever>.2);assert.equal((await mobile.evaluate(()=>window.metroCabInspector.getView())).yaw,startView.yaw);pass('real touch controller drag and camera separation');
 await mobile.keyboard.press('Space');await waitState(()=>window.metroCabInspector.getState().speed<.1,null,mobile);await mobile.keyboard.press('KeyN');
 await mobile.locator('#cabView-right').tap();await mobile.waitForTimeout(800);await capture(mobile,'10-mobile-controls');
 report.mobilePerformance=await samplePerformance(mobile);
 await mobile.setViewportSize({width:915,height:412});await view(mobile,0,-.43);await capture(mobile,'11-mobile-landscape');pass('portrait and landscape layouts');
 await restart();
 }
 if(suite==='all'||suite==='launch'){
 const launch=await fixture.page({viewport:{width:1024,height:576}});page=launch;await ready(launch,fixture.base+'/?cabInspector=1');await launch.locator('#play').click();
 await waitState(()=>window.metroDiagnostics().playing,null,launch);await launch.keyboard.press('Digit1');await waitState(()=>window.metroDiagnostics().train.speed>.2,null,launch);pass('normal start screen and depot traction');
 }
 report.errors.push(...fixture.errors);report.requests.push(...fixture.requests);assert.equal(report.errors.length,0,report.errors.join('\n'));assert.equal(report.requests.filter(r=>/\.(js|css)(\?|$)/.test(r.url)).length,0,'no missing code assets');pass('no JavaScript or module load errors');
 report.status='passed';
}catch(error){report.status='failed';report.failure=error.stack;console.error(error);try{if(!page.isClosed())await capture(page,'failure');}catch{}process.exitCode=1;
}finally{await writeFile(reportPath,JSON.stringify(report,null,2));await fixture.close();}
