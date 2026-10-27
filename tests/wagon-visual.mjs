import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
await mkdir('test-results/wagon',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const page=await browser.newPage({viewport:{width:900,height:600},deviceScaleFactor:1});
const errors=[];
page.on('pageerror',e=>errors.push(e.message));
try{
 await page.goto('http://127.0.0.1:8765/preview/wagon.html',{waitUntil:'domcontentloaded',timeout:30000});
 await page.waitForFunction(()=>window.wagonReady===true&&typeof window.wagonDiagnostics==='function',{timeout:90000});
 const views=['front','outside','driver','salon'];
 const reports=[];
 for(const mode of views){
  await page.evaluate(m=>window.wagonSetCamera(m),mode);
  await page.waitForTimeout(350);
  const data=await page.evaluate(()=>window.wagonDiagnostics());
  assert.equal(data.cameraMode,mode);
  assert.ok(data.meshCount>100,'Wagon geometry missing');
  assert.ok(data.renderWidth>0&&data.renderHeight>0,'WebGL canvas empty');
  reports.push(data);
  // One screenshot per active wagon view, never screenshots of the game.
  await page.screenshot({path:`test-results/wagon/${mode}.png`,timeout:90000,animations:'disabled'});
 }
 assert.deepEqual(errors,[],'Wagon page JavaScript errors');
 await writeFile('test-results/wagon/report.json',JSON.stringify({result:'pass',views:reports,errors},null,2));
 console.log('Wagon model checks passed',JSON.stringify(reports));
}finally{await browser.close()}
