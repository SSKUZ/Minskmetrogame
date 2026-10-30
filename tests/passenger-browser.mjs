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
 assert.ok(report.initial.platform>=80&&report.initial.platform<=100);assert.equal(report.initial.service.cars,4);assert.equal(report.initial.service.normal,true);
 const expectedBoardings=report.initial.agents.filter(a=>a.space==='platform'&&a.wantsBoard).length;
 const expectedAlightings=report.initial.agents.filter(a=>a.space==='train'&&a.destination<=report.initial.station).length;
 console.log('24 textured model variants loaded');
 await p.locator('#stationCameraToggle').click();
 await p.screenshot({path:output+'/platform.png',timeout:120000});
 await p.locator('#stationCameraToggle').click();
 await p.evaluate(()=>window.metroPassengerInspector.focus(4,2.7));
 await p.screenshot({path:output+'/portrait.png',timeout:120000});
 console.log('Clear portrait captured');
 await p.evaluate(()=>{const i=window.metroPassengerInspector;i.view([-7,2.6,21.7],[-2.4,1.9,18.75],58);i.train({dist:140,speed:42,doors:false});i.step(12);i.train({dist:0,speed:0,doors:true});});
 await p.waitForFunction(()=>window.metroPassengerInspector.system.context.aperture>.96,null,{timeout:120000});
 await p.evaluate(()=>window.metroPassengerInspector.step(8));
 report.boarding=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.boarding.events.some(e=>e.kind==='alight'));
 await p.screenshot({path:output+'/exchange.png',timeout:120000});
 console.log('Actual door exchange captured',report.boarding.events.length);
 // Functional rendering check on the unmodified eight-door temporary stand.
 // Eight-stop timing is tested separately on 4x4 door anchors.
 // This ordinary 80–100-person stop must also finish within 30 s on the stand.
 report.temporaryStandDwell=await p.evaluate(()=>{const i=window.metroPassengerInspector;let elapsed=8;while(elapsed<30&&!i.snapshot().passengerExchangeComplete){i.step(1);elapsed++;}return elapsed;});
 assert.ok(report.temporaryStandDwell<=30);
 report.completed=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.completed.doors.every(q=>!q.waiting&&!q.exiting));
 assert.equal(report.completed.events.filter(e=>e.kind==='alight').length,expectedAlightings);
 assert.equal(report.completed.events.filter(e=>e.kind==='board').length,expectedBoardings);
 assert.equal(report.completed.passengerExchangeComplete,true);assert.equal(report.completed.doorsSafeToClose,true);
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
 // Fast-forward the actual game's existing simulation between rendered stages.
 // Each stop still runs fixed timesteps, real queues and threshold crossings.
 await p.locator('#carCameraToggle').click();
 report.route=[];
 const continueRoute=async target=>{
  const stops=await p.evaluate(target=>{
   const i=window.metroPassengerInspector,s=i.system.simulation,stationCount=s.routePlan.stationCount,result=[];
   const advance=(seconds,ctx)=>{for(let n=0;n<seconds*30;n++)s.update(1/30,ctx);};
   for(let station=s.station+1;station<=target;station++){
    const before=s.agents.filter(a=>a.space==='train').length;
    const closed={station,stationCount,dist:900,speed:50,doorsOpen:false,aperture:0},open={...closed,dist:0,speed:0,doorsOpen:true,aperture:1};
    i.train({station,dist:900,speed:50,doors:false});advance(35,closed);
    advance(12,{...closed,dist:140,speed:42});let dwell=null;
    for(let n=0;n<(station===stationCount-1?120:60)*30;n++){
     s.update(1/30,open);if(s.boarding.passengerExchangeComplete){dwell=(n+1)/30;break;}
    }
    const events=s.events.filter(e=>e.station===station),boarded=events.filter(e=>e.kind==='board').length,alighted=events.filter(e=>e.kind==='alight').length;
    if(dwell===null||!s.boarding.doorsSafeToClose||s.boarding.missed.size||boarded!==s.routePlan.boarding||alighted!==s.routePlan.exiting)throw Error('Route exchange failed at station '+station);
    const onboard=s.agents.filter(a=>a.space==='train').length;
    if(onboard!==before+boarded-alighted)throw Error('Route conservation failed at station '+station);
    result.push({station,population:s.platformCount,before,boarded,alighted,onboard,dwell});
    advance(15,{...open,doorsOpen:false,aperture:0});i.train({station,dist:0,speed:0,doors:false});
   }
   return result;
  },target);
  report.route.push(...stops);return await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 };
 report.midRoute=await continueRoute(7);
 assert.ok(report.midRoute.onboard>report.completed.onboard*1.4);
 await p.screenshot({path:output+'/carriage-middle.png',timeout:120000});
 console.log('Route midpoint captured',report.midRoute.onboard);
 report.preTerminal=await continueRoute(13);
 assert.ok(report.preTerminal.onboard<report.midRoute.onboard*.3);
 await p.screenshot({path:output+'/carriage-before-terminal.png',timeout:120000});
 report.terminal=await continueRoute(14);
 assert.equal(report.terminal.onboard,0);assert.equal(report.terminal.route.boarding,0);assert.equal(report.terminal.route.readyForNextTrip,true);
 report.terminalPerCar=await p.evaluate(()=>{const s=window.metroPassengerInspector.system.simulation;return s.layout.cars.map(c=>({car:c.id,onboard:s.agents.filter(a=>a.space==='train'&&a.car===c.id).length}));});
 assert.ok(report.terminalPerCar.every(c=>c.onboard===0));
 await p.screenshot({path:output+'/carriage-terminal-empty.png',timeout:120000});
 console.log('Terminal train empty',report.terminal.onboard);
 report.errors=f.errors;report.requests=f.requests;
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);
 console.log('Browser scenarios passed',JSON.stringify({onboard:report.completed.onboard,performance:report.performance}));
}finally{
 await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2));
 await f.close();
}
