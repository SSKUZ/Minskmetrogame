import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir} from 'node:fs/promises';

await mkdir('test-results',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const errors=[];
const page=await browser.newPage({viewport:{width:412,height:915},deviceScaleFactor:1,hasTouch:true,isMobile:true});
page.on('pageerror',e=>errors.push('pageerror: '+e.message));
page.on('console',m=>{if(m.type()==='error')errors.push('console: '+m.text())});
try{
 await page.goto('http://127.0.0.1:8765/?preview=station',{waitUntil:'domcontentloaded',timeout:30000});
 await page.waitForFunction(()=>window.metro3DReady===true&&typeof window.metroDiagnostics==='function',{timeout:90000});
 await page.waitForTimeout(2500);
 let state=await page.evaluate(()=>window.metroDiagnostics());
 assert.equal(state.playing,true,'preview must start');
 assert.equal(state.camera,'cab');
 assert.ok(await page.locator('#scene').isVisible());
 await page.screenshot({path:'test-results/01-cab.png'});
 await page.locator('#carCameraToggle').click();
 state=await page.evaluate(()=>window.metroDiagnostics());
 assert.equal(state.camera,'carriage');
 await page.waitForTimeout(600);
 await page.screenshot({path:'test-results/02-carriage.png'});
 await page.locator('#carCameraToggle').click();
 assert.equal((await page.evaluate(()=>window.metroDiagnostics())).camera,'cab');
 const station=page.locator('#stationCameraToggle');
 if(await station.isVisible()){
  await station.click();
  assert.equal((await page.evaluate(()=>window.metroDiagnostics())).camera,'platform');
  await page.waitForTimeout(500);
  await page.screenshot({path:'test-results/03-platform.png'});
  await station.click();
  assert.equal((await page.evaluate(()=>window.metroDiagnostics())).camera,'cab');
 }
 await page.waitForTimeout(1500);
 assert.ok(await page.evaluate(()=>performance.now()-window.metroLastRendered<2500),'render loop should keep running');
 assert.equal(errors.filter(x=>/ReferenceError|SyntaxError|TypeError|Metro render failure|Failed to resolve module/i.test(x)).length,0,errors.join('\n'));
 console.log('Browser smoke passed; captured screenshots; state:',JSON.stringify(state));
}finally{await browser.close()}
