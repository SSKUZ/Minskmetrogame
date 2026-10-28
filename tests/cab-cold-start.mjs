import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser} from './helpers/cab-browser-fixture.mjs';

const out=process.env.CAB_RESULTS??'test-results/cab';await mkdir(out,{recursive:true});
const fixture=await launchCabBrowser(),started=Date.now();let release;
const gate=new Promise(resolve=>{release=resolve;}),report={checks:[],errors:[]};
try{
 const p=await fixture.page({viewport:{width:412,height:915},hasTouch:true,isMobile:true});
 await p.addInitScript(()=>{
  const original=HTMLCanvasElement.prototype.getContext;window.cabStartupCanvasClaims=[];
  HTMLCanvasElement.prototype.getContext=function(kind,...args){if(this.id==='scene')window.cabStartupCanvasClaims.push(kind);return original.call(this,kind,...args);};
 });
 // Hold the actual engine import past the fallback deadline. Do not wait for
 // DOMContentLoaded: module loading blocks that event, unlike the visible UI.
 await p.route('**/js/vendor/three.module.js',async route=>{await gate;await route.continue();});
 await p.goto(fixture.base+'/?cabInspector=1',{waitUntil:'commit'});
 await p.locator('#play').tap();await p.locator('#start').waitFor({state:'hidden'});
 await p.waitForTimeout(1500);assert.equal(fixture.errors.length,0);assert.equal(await p.locator('#fallbackScene').count(),0);
 report.checks.push('Start works before the engine finishes; the old one-second crash is absent');
 await p.locator('#fallbackScene').waitFor({state:'visible',timeout:20000});
 assert.equal(await p.evaluate(()=>window.cabStartupCanvasClaims.includes('2d')),false);
 await p.screenshot({path:out+'/cold-start-fallback.png'});report.checks.push('A delayed engine enables a separate 2D surface without claiming the WebGL canvas');
 release();
 await p.waitForFunction(()=>window.metro3DReady&&window.metroLastRendered&&window.metroCabInspector,null,{timeout:120000});
 await p.locator('#fallbackScene').waitFor({state:'detached'});
 assert.equal(await p.evaluate(()=>window.metroDiagnostics().playing),true);
 assert.equal(await p.evaluate(()=>window.cabStartupCanvasClaims.includes('2d')),false);
 await p.keyboard.press('Digit1');await p.waitForFunction(()=>window.metroDiagnostics().train.speed>.2,null,{timeout:60000});
 await p.keyboard.press('Space');await p.screenshot({path:out+'/cold-start-ready.png',timeout:120000});
 assert.equal(fixture.errors.length,0,fixture.errors.join('\n'));report.checks.push('Late 3D takes over, preserves early Start, removes the fallback and drives the real train');
 report.status='passed';
}catch(error){report.status='failed';report.failure=error.stack;process.exitCode=1;console.error(error);}
finally{
 release();report.errors=fixture.errors;report.durationMs=Date.now()-started;
 await writeFile(out+'/cold-start-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));await fixture.close();
}
