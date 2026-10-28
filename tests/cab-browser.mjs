import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';

await mkdir('test-results/cab',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const errors=[];
const page=await browser.newPage({viewport:{width:1365,height:768},deviceScaleFactor:1});
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto('http://127.0.0.1:8765/preview/cab-editor.html',{waitUntil:'domcontentloaded',timeout:30000});
 const game=page.frameLocator('#game');
 await game.locator('#scene').waitFor({state:'visible',timeout:90000});
 await page.waitForFunction(()=>{
  const w=document.querySelector('#game')?.contentWindow;
  return w?.metro3DReady===true&&!!w.metroCabInspector&&typeof w.metroDiagnostics==='function';
 },{timeout:90000});
 await page.waitForTimeout(1500);
 const before=await page.evaluate(()=>{
  const w=document.querySelector('#game').contentWindow,a=w.metroCabInspector;
  let meshes=0;a.cab.traverse(x=>{if(x.isMesh)meshes++});
  return {meshes,playing:w.metroDiagnostics().playing,camera:w.metroDiagnostics().camera,children:a.cab.children.length};
 });
 assert.ok(before.meshes>50,'actual 3D cab must contain many meshes');
 assert.equal(before.camera,'cab');
 assert.equal(before.playing,true);
 await page.screenshot({path:'test-results/cab/01-original-cab.png',animations:'disabled'});
 await page.locator('#left').click();
 await page.waitForTimeout(900);
 let view=await page.evaluate(()=>document.querySelector('#game').contentWindow.metroCabInspector.getView());
 assert.ok(view.yaw<-.7,'left view must rotate');
 await page.screenshot({path:'test-results/cab/02-left-view.png',animations:'disabled'});
 await page.locator('#right').click();
 await page.waitForTimeout(900);
 view=await page.evaluate(()=>document.querySelector('#game').contentWindow.metroCabInspector.getView());
 assert.ok(view.yaw>.7,'right view must rotate');
 await page.screenshot({path:'test-results/cab/03-right-view.png',animations:'disabled'});
 await page.locator('#zoom').fill('40');
 view=await page.evaluate(()=>document.querySelector('#game').contentWindow.metroCabInspector.getView());
 assert.equal(view.fov,40);
 await page.screenshot({path:'test-results/cab/04-zoom.png',animations:'disabled'});
 await page.locator('#reset').click();
 await page.waitForTimeout(500);
 const after=await page.evaluate(()=>{
  const w=document.querySelector('#game').contentWindow,a=w.metroCabInspector;
  return {fov:a.getView().fov,playing:w.metroDiagnostics().playing,camera:w.metroDiagnostics().camera,renderAge:performance.now()-w.metroLastRendered};
 });
 assert.equal(after.fov,75);
 assert.equal(after.camera,'cab');
 assert.ok(after.renderAge<3000,'3D render loop must remain active');
 assert.equal(errors.filter(x=>/ReferenceError|SyntaxError|TypeError|Metro render failure|Failed to resolve module/i.test(x)).length,0,errors.join('\n'));
 console.log('Cab browser smoke PASSED',JSON.stringify({before,after,errors}));
}finally{await browser.close()}
