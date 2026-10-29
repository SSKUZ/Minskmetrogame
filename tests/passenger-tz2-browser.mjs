import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser,ready} from './helpers/cab-browser-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-final';
await mkdir(output,{recursive:true});
const f=await launchCabBrowser(),report={stations:[],motion:[]};
try{
 const p=await f.page({viewport:{width:1280,height:800}});p.setDefaultTimeout(120000);
 p.on('console',m=>{if(m.type()==='error'&&/Shader Error|VALIDATE_STATUS|WebGLProgram/.test(m.text()))f.errors.push(m.text());});
 const cdp=await p.context().newCDPSession(p);await cdp.send('Performance.enable');
 await ready(p,f.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await p.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready);
 await p.evaluate(()=>window.metroPassengerInspector.pause());
 const shot=async(name,position,target,fov=58)=>{
  if(position)await p.evaluate(({position,target,fov})=>window.metroPassengerInspector.view(position,target,fov),{position,target,fov});
  await p.screenshot({path:output+'/'+name+'.png',timeout:120000});await writeFile(output+'/browser-report.partial.json',JSON.stringify(report,null,2));console.log('Captured',name);
 };
 await shot('01-platform',[-9,2.7,15],[-5,1.7,22]);
 await p.evaluate(()=>window.metroPassengerInspector.train({doors:true}));
 await p.waitForFunction(()=>window.metroPassengerInspector.system.context.aperture>.96);
 await p.evaluate(()=>window.metroPassengerInspector.step(8));
 await shot('02-alighting',[-7,2.6,21.7],[-2.4,1.9,18.75]);
 await p.evaluate(()=>window.metroPassengerInspector.step(22));
 await shot('03-boarding',[-6,2.6,19.8],[-2.1,1.9,18.75]);
 await p.evaluate(()=>window.metroPassengerInspector.step(90));
 report.exchange=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.exchange.doors.every(q=>!q.exiting&&!q.waiting));
 assert.equal(report.exchange.events.filter(e=>e.kind==='board').length,51);
 await p.locator('#carCameraToggle').click();
 await shot('04-carriage',[.20,2.55,31],[-.45,2.15,14]);
 report.carriage=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 assert.ok(report.carriage.grips.length,'real scene must contain a physically supported standing passenger');
 assert.ok(report.carriage.grips.every(g=>g.error<.005));
 const grip=report.carriage.grips[0],agent=report.carriage.agents.find(a=>a.id===grip.id);
 await p.evaluate(id=>window.metroPassengerInspector.focus(id,2.5),agent.id);
 await shot('05-standing');
 const [x,y,z]=grip.point;
 const side=grip.side==='Right'?-1:1;
 await shot('06-real-grip',[Math.max(-1.85,Math.min(1.2,x+Math.cos(agent.heading)*side*1.15+(x<-.31?.15:-.15))),y+.18,z-Math.sin(agent.heading)*side*1.15],[x,y-.04,z],43);
 const seated=report.carriage.agents.find(a=>a.state==='seated'&&a.z>-97&&a.z<-78);
 assert.ok(seated);await p.evaluate(id=>window.metroPassengerInspector.focus(id,2.8),seated.id);await shot('07-seated');
 await shot('08-through-windows',[-4.5,2.3,25],[-.2,2.2,23.7]);
 await p.evaluate(()=>window.metroPassengerInspector.resetView());await p.locator('#carCameraToggle').click();
 // Both mirrors are the game's actual render targets.
 await p.waitForFunction(()=>window.metroPassengerInspector.mirrors().every(m=>m.camera[2]===3.35));
 for(const side of [-1,1]){
  const data=await p.evaluate(side=>window.metroPassengerInspector.mirrorImage(side),side);
  await writeFile(output+`/09-mirror-${side<0?'left':'right'}.png`,Buffer.from(data.split(',')[1],'base64'));
 }
 await p.locator('#carCameraToggle').click();await p.setViewportSize({width:412,height:915});await shot('10-mobile');
 await p.setViewportSize({width:1280,height:800});await p.locator('#carCameraToggle').click();
 // Drive through the existing physical controller. No fake acceleration input.
 await p.evaluate(id=>{const i=window.metroPassengerInspector;i.train({doors:false,speed:20,dist:-70});i.focus(id,2.6);},agent.id);
 await p.keyboard.press('Digit5');await p.locator('#carCameraToggle').click();
 await p.waitForFunction(()=>window.metroPassengerInspector.snapshot().motion.acceleration>.5);
 report.motion.push(await p.evaluate(()=>window.metroPassengerInspector.snapshot()));await shot('11-acceleration');
 await p.locator('#carCameraToggle').click();await p.keyboard.press('Space');await p.locator('#carCameraToggle').click();
 await p.waitForFunction(()=>window.metroPassengerInspector.snapshot().motion.acceleration<-.5);
 report.motion.push(await p.evaluate(()=>window.metroPassengerInspector.snapshot()));await shot('12-braking');
 await p.waitForFunction(()=>window.metroPassengerInspector.snapshot().motion.speed<.1);
 report.motion.push(await p.evaluate(()=>window.metroPassengerInspector.snapshot()));await shot('13-stabilized');
 await p.locator('#carCameraToggle').click();await p.keyboard.press('KeyN');await p.locator('#carCameraToggle').click();
 const beforeIds=report.carriage.agents.filter(a=>a.space==='train').map(a=>a.id);
 assert.deepEqual(report.motion[0].agents.filter(a=>a.space==='train').map(a=>a.id),beforeIds);
 await p.evaluate(()=>{window.metroPassengerInspector.train({speed:0,dist:0});window.metroPassengerInspector.view([.2,2.55,31],[-.45,2.15,14]);});
 // Warm the actual renderer, then measure over 45 seconds rather than a short burst.
 await p.evaluate(()=>new Promise(resolve=>{const start=performance.now();function frame(){if(performance.now()-start>=30000)resolve();else requestAnimationFrame(frame);}requestAnimationFrame(frame);}));
 report.performance=await p.evaluate(()=>new Promise(resolve=>{
  const start=performance.now(),times=[];let last=start;
  function frame(now){times.push(now-last);last=now;if(now-start<45000){requestAnimationFrame(frame);return;}
   const gl=document.querySelector('#scene').getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info'),sorted=times.slice(1).sort((a,b)=>a-b);
   resolve({durationMs:now-start,frames:times.length,fps:(times.length-1)*1000/(now-start-times[0]),medianFrameMs:sorted[Math.floor(sorted.length*.5)],p95FrameMs:sorted[Math.floor(sorted.length*.95)],gpu:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):'unknown',...window.metroPassengerInspector.performance(),resources:window.metroPassengerInspector.snapshot().resources});
  }requestAnimationFrame(frame);
 }));await writeFile(output+'/browser-report.partial.json',JSON.stringify(report,null,2));console.log('Warm performance',report.performance.fps,report.performance.memory);
 for(let station=1;station<=8;station++){
  const result=await p.evaluate(station=>{
   const i=window.metroPassengerInspector,s=i.system.simulation;
   i.train({station,dist:0,speed:0,doors:true});
   const closed={station,dist:800,speed:50,doorsOpen:false,aperture:0},open={station,dist:0,speed:0,doorsOpen:true,aperture:1};
   for(let n=0;n<60;n++)s.update(1/30,closed);
   let ticks=0;do{s.update(1/30,open);ticks++;}while(ticks<9000&&(ticks<3600||s.boarding.queues.some(q=>q.enter.length||q.exit.length)));
   for(let n=0;n<60;n++)s.update(1/30,{...open,doorsOpen:false,aperture:0});
   const before=s.eventSequence;for(let n=0;n<90;n++)s.update(1/30,open);
   return {station,dwell: ticks/30,snapshot:s.snapshot(),duplicateReopen:s.eventSequence-before};
  },station);
  assert.equal(result.duplicateReopen,0);assert.ok(result.snapshot.doors.every(q=>!q.waiting&&!q.exiting),'station '+station);
  await p.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await cdp.send('HeapProfiler.collectGarbage');
  const metrics=await cdp.send('Performance.getMetrics');
  result.heapBytes=metrics.metrics.find(m=>m.name==='JSHeapUsedSize')?.value;
  result.render=await p.evaluate(()=>({snapshot:window.metroPassengerInspector.snapshot(),...window.metroPassengerInspector.performance()}));
  assert.ok(result.render.snapshot.resources.journal<=512&&result.render.snapshot.resources.counted<=512);
  report.stations.push(result);await writeFile(output+'/browser-report.partial.json',JSON.stringify(report,null,2));console.log('Station',station,'dwell',result.dwell,'heap',result.heapBytes,'GPU',result.render.memory);
 }
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);report.passed=true;
}finally{
 report.errors=f.errors;report.requests=f.requests;
 await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2));await f.close();
}
