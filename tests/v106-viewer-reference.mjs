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
 try{await page.waitForFunction(()=>window.wagonReady===true,null,{timeout:240000});}
 catch(error){console.error('V106_VIEWER_STARTUP_DIAGNOSTIC',JSON.stringify(await page.evaluate(()=>({stage:window.wagonStartupStage||null,status:document.getElementById('status')?.textContent||null,wagonReady:window.wagonReady||false}))),JSON.stringify(errors));throw error;}
 await page.waitForFunction(()=>window.wagonDiagnostics?.().renderedFrames>=1,null,{timeout:180000});
 await page.screenshot({path:'test-results/v106-source/source-viewer-side-angle.png',timeout:90000});
 const previous=await page.evaluate(()=>{window.wagonSetCamera('front');return window.wagonDiagnostics().renderedFrames});
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,previous,{timeout:90000});
 await page.screenshot({path:'test-results/v106-source/source-viewer-front.png',timeout:90000});
 // Independent saloon advertisement evidence: does not wait for the slow station/door smoke.
 const ad=await page.evaluate(()=>{const cars=window.wagonGetLiveConsist().cars;return cars.map((car,i)=>{let posters=0;car.root.traverse(o=>{if(o.userData.advertisement==='goodmix-duo')posters++});return {car:i+1,posters}})});
 console.log('GOODMIX_POSTER_COUNTS',JSON.stringify(ad));
 if(ad.length!==4||ad.some(x=>x.posters!==2))throw new Error('Expected two Goodmix posters on each of four cars');
 for(const [mode,file] of [['salon','saloon-overview'],['goodmix-closeup-left','goodmix-left'],['goodmix-closeup-right','goodmix-right']]){
  const before=await page.evaluate(v=>{window.wagonSetCamera(v);return window.wagonDiagnostics().renderedFrames},mode);
  await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+2,before,{timeout:90000});
  await page.screenshot({path:'test-results/v106-source/'+file+'.png',timeout:90000});
 }

 console.log(JSON.stringify({diagnostics:await page.evaluate(()=>window.wagonDiagnostics()),errors},null,2));
}finally{await browser.close()}
