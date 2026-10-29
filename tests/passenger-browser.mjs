import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser,ready,samplePerformance} from './helpers/cab-browser-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/verified';
await mkdir(output,{recursive:true});
const f=await launchCabBrowser();const report={};
try{
 const p=await f.page({viewport:{width:1280,height:800}});
 await ready(p,f.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await p.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready&&window.metroPassengerInspector.snapshot().actors>0,null,{timeout:120000});
 await p.evaluate(()=>window.metroPassengerInspector.pause());
 report.initial=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.equal(report.initial.modelsLoaded,24);assert.deepEqual(report.initial.errors,[]);
 console.log('24 textured model variants loaded');
 await p.evaluate(()=>window.metroPassengerInspector.focus(4,2.7));
 await p.screenshot({path:output+'/portrait.png',timeout:120000});
 console.log('Clear portrait captured');
 await p.evaluate(()=>{const i=window.metroPassengerInspector;i.view([-7,2.6,21.7],[-2.4,1.9,18.75],58);i.train({doors:true});});
 await p.waitForFunction(()=>window.metroPassengerInspector.system.context.aperture>.96,null,{timeout:120000});
 await p.evaluate(()=>window.metroPassengerInspector.step(8));
 report.boarding=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.boarding.events.some(e=>e.kind==='alight'));
 await p.screenshot({path:output+'/exchange.png',timeout:120000});
 console.log('Actual door exchange captured',report.boarding.events.length);
 await p.evaluate(()=>window.metroPassengerInspector.step(112));
 report.completed=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.completed.doors.every(q=>!q.waiting&&!q.exiting));
 assert.equal(report.completed.events.filter(e=>e.kind==='alight').length,8);
 assert.equal(report.completed.events.filter(e=>e.kind==='board').length,51);
 assert.equal(new Set(report.completed.events.map(e=>e.kind+':'+e.id)).size,report.completed.events.length);
 await p.evaluate(()=>window.metroPassengerInspector.resetView());
 await p.locator('#carCameraToggle').click();
 await p.screenshot({path:output+'/carriage.png',timeout:120000});
 report.carriage=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.equal(report.carriage.onboard,report.completed.onboard);
 assert.deepEqual(report.carriage.agents.filter(a=>a.space==='train').map(a=>a.id),report.completed.agents.filter(a=>a.space==='train').map(a=>a.id));
 console.log('Carriage identities match platform view');
 report.performance=await samplePerformance(p);
 await p.evaluate(()=>{const s=window.metroPassengerInspector.system;s.root.visible=false;for(const b of s.impostors.batches)b.layers.disableAll();});
 report.withoutPassengerRendering=await samplePerformance(p);
 await p.evaluate(()=>{const s=window.metroPassengerInspector.system;s.root.visible=true;for(const b of s.impostors.batches)b.layers.enable(0);});
 await p.setViewportSize({width:412,height:915});
 await p.screenshot({path:output+'/carriage-mobile.png',timeout:120000});
 report.mobile=await p.evaluate(()=>({width:innerWidth,canvas:document.querySelector('#scene').getBoundingClientRect().toJSON(),snapshot:window.metroPassengerInspector.snapshot()}));
 assert.equal(report.mobile.width,412);assert.equal(report.mobile.snapshot.onboard,report.completed.onboard);
 await p.setViewportSize({width:1280,height:800});
 await p.locator('#carCameraToggle').click();
 // Mirrors need several real frames because the game updates one mirror per 3 frames.
 await p.waitForFunction(()=>window.metroPassengerInspector.mirrors().every(m=>m.camera[2]===3.35),null,{timeout:120000});
 report.mirrors=await p.evaluate(()=>window.metroPassengerInspector.mirrors());
 for(const side of [-1,1]){
  const data=await p.evaluate(side=>window.metroPassengerInspector.mirrorImage(side),side);
  assert.ok(data?.startsWith('data:image/png;base64,'));
  await writeFile(output+`/mirror-${side<0?'left':'right'}.png`,Buffer.from(data.split(',')[1],'base64'));
 }
 report.errors=f.errors;report.requests=f.requests;
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);
 console.log('Browser scenarios passed',JSON.stringify({onboard:report.completed.onboard,performance:report.performance}));
}finally{
 await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2));
 await f.close();
}
