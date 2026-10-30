import {chromium} from 'playwright';import assert from 'node:assert/strict';import fs from 'node:fs/promises';
const out='test-results/station-base';await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
const page=await browser.newPage({viewport:{width:1365,height:900},deviceScaleFactor:1});const errors=[],cases=[];
page.on('pageerror',e=>errors.push(e.stack??e.message));
const read=()=>page.locator('#report-json').textContent().then(JSON.parse);
const ready=()=>page.waitForFunction(()=>{const e=document.getElementById('report-json');try{return JSON.parse(e.textContent).contactCount===32}catch{return false}},{},{timeout:240000});
try{
 await page.goto(process.env.STATION_BASE_URL??'http://127.0.0.1:8765/station-base.html',{waitUntil:'domcontentloaded',timeout:30000});await ready();
 let r=await read();assert.ok(r.ok,JSON.stringify(r.issues));assert.ok(r.second?.ok);assert.equal(r.second.contactCount,32);assert.ok(r.secondVisible);assert.ok(r.separation.ok);assert.equal(r.runtime.three,'160');
 cases.push({name:'two trains stopped',ok:r.ok,report:r});await page.screenshot({path:out+'/two-trains-overview.png'});
 await page.getByRole('button',{name:'У края',exact:true}).click();await page.screenshot({path:out+'/platform-gap.png'});
 await page.getByRole('button',{name:'Открыть',exact:true}).click();await page.waitForFunction(()=>document.getElementById('door-state').textContent==='Двери открыты');r=await read();assert.ok(r.ok,JSON.stringify(r.issues));assert.equal(r.doorProgress,1);assert.equal(await page.getByRole('button',{name:'Отправление',exact:true}).isEnabled(),false);cases.push({name:'served doors open, departure blocked',ok:r.ok,report:r});await page.screenshot({path:out+'/doors-open.png'});
 await page.getByRole('button',{name:'Закрыть',exact:true}).click();await page.waitForFunction(()=>document.getElementById('door-state').textContent==='Двери закрыты');
 await page.getByRole('button',{name:'Колёса',exact:true}).click();await page.screenshot({path:out+'/wheel-rail-contact.png'});
 await page.locator('#second-train').uncheck();r=await read();assert.equal(r.secondVisible,false);cases.push({name:'second train hidden',ok:true});await page.locator('#second-train').check();
 await page.getByRole('button',{name:'Общий',exact:true}).click();await page.getByRole('button',{name:'Подъезд',exact:true}).click();assert.equal(await page.getByRole('button',{name:'Открыть',exact:true}).isEnabled(),false);
 await page.waitForFunction(()=>document.getElementById('motion-state').textContent==='Остановка',{},{timeout:45000});r=await read();assert.ok(r.ok);assert.equal(r.frontZ,0);cases.push({name:'arrival stopped at reference',ok:r.ok,report:r});
 await page.getByRole('button',{name:'Отправление',exact:true}).click();await page.waitForFunction(()=>document.getElementById('motion-state').textContent==='За платформой',{},{timeout:45000});r=await read();assert.ok(r.ok);cases.push({name:'departure',ok:r.ok,report:r});
 await page.getByRole('button',{name:'↺',exact:true}).click();
 await page.getByText('Параметры станции',{exact:true}).click();await page.locator('#direction').selectOption('1');await page.getByRole('button',{name:'Применить на стенде',exact:true}).click();await page.waitForFunction(()=>{try{const r=JSON.parse(document.getElementById('report-json').textContent);return r.direction===1&&r.second.direction===-1&&r.ok}catch{return false}},{},{timeout:180000});r=await read();cases.push({name:'opposite direction on both tracks',ok:r.ok,report:r});
 await page.getByRole('button',{name:'Сверху',exact:true}).click();await page.screenshot({path:out+'/two-trains-top-reversed.png'});
 // A phone viewport verifies responsive controls without replacing the source model.
 await page.setViewportSize({width:412,height:915});await page.getByRole('button',{name:'Общий',exact:true}).click();await page.screenshot({path:out+'/mobile.png'});
 assert.equal(errors.length,0,JSON.stringify(errors));
 await fs.writeFile(out+'/browser.json',JSON.stringify({ok:true,cases,pageErrors:errors,renderer:'Chromium WebGL software GPU, exact 0.160.1 dependency'},null,2));
}catch(error){await page.screenshot({path:out+'/failure.png'});await fs.writeFile(out+'/browser.json',JSON.stringify({ok:false,error:error.stack,cases,pageErrors:errors,status:await page.locator('#status').textContent()},null,2));throw error;}
finally{await browser.close();}
