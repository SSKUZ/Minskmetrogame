import {chromium} from 'playwright';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
await mkdir('test-results/station-base',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox','--disable-dev-shm-usage']});
const results=[];
for(const quality of ['low','medium','high']){
 const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const response=await page.goto('http://127.0.0.1:8765/station-base.html?quality='+quality+'&benchmark=1&adaptive=0',{waitUntil:'domcontentloaded',timeout:60000});
 assert.equal(response.status(),200);
 let loaded=false;
 try{await page.waitForFunction(()=>!!window.metroBenchmarkSnapshot(),null,{timeout:150000});loaded=true;}catch{}
 const status=await page.locator('#status').innerText();
 const snapshot=loaded?await page.evaluate(()=>window.metroBenchmarkSnapshot()):null;
 await page.screenshot({path:'test-results/station-base/'+quality+'-overview.png',timeout:90000});
 if(loaded){
  for(const camera of ['edge','top','wheels']){
   await page.locator('[data-camera="'+camera+'"]').click();
   await page.waitForTimeout(500);
   await page.screenshot({path:'test-results/station-base/'+quality+'-'+camera+'.png',timeout:90000});
  }
  await page.locator('#open').click();await page.waitForTimeout(2000);
  await page.screenshot({path:'test-results/station-base/'+quality+'-doors-open.png',timeout:90000});
  await page.locator('#close').click();await page.waitForTimeout(2000);
  await page.locator('#depart').click();await page.waitForTimeout(1500);
 }
 results.push({quality,loaded,status,errors,snapshot,finalStatus:await page.locator('#status').innerText()});
 await page.close();
}
await browser.close();
await writeFile('test-results/station-base/report.json',JSON.stringify(results,null,2));
if(results.some(r=>!r.loaded||r.errors.length||r.snapshot?.context==='LOST'))process.exitCode=1;
