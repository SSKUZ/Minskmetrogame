import {chromium} from 'playwright';
import {mkdir} from 'node:fs/promises';

await mkdir('test-results/v106-source',{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--disable-dev-shm-usage','--no-sandbox']});
const page=await browser.newPage({viewport:{width:1365,height:768},deviceScaleFactor:1});
const errors=[];
page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto('http://127.0.0.1:8765/preview/wagon.html?qa=1&formation=train&view=side-angle',{waitUntil:'commit',timeout:30000});
 await page.waitForFunction(()=>window.wagonReady===true,null,{timeout:240000});
 await page.waitForFunction(()=>window.wagonDiagnostics?.().renderedFrames>=1,null,{timeout:180000});
 await page.screenshot({path:'test-results/v106-source/source-viewer-side-angle.png',timeout:90000});
 const previous=await page.evaluate(()=>{window.wagonSetCamera('front');return window.wagonDiagnostics().renderedFrames});
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,previous,{timeout:90000});
 await page.screenshot({path:'test-results/v106-source/source-viewer-front.png',timeout:90000});
 console.log(JSON.stringify({diagnostics:await page.evaluate(()=>window.wagonDiagnostics()),errors},null,2));
}finally{await browser.close()}
