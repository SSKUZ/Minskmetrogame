import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {PNG} from 'pngjs';
import {launchCabBrowser,ready} from './helpers/cab-browser-fixture.mjs';
import {settlePassengerDoors} from './helpers/passenger-door-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-motion-inside';
await mkdir(output,{recursive:true});const f=await launchCabBrowser(),report={motion:[]};
try{
 const p=await f.page({viewport:{width:640,height:400}});p.setDefaultTimeout(180000);
 await ready(p,f.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await p.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready);
 await p.evaluate(()=>window.metroPassengerInspector.pause());await settlePassengerDoors(p,true);
 await p.evaluate(()=>window.metroPassengerInspector.step(120));
 const initial=await p.evaluate(()=>window.metroPassengerInspector.snapshot()),ids=initial.agents.filter(a=>a.space==='train').map(a=>a.id);
 const agent=initial.agents.find(a=>a.id===10&&a.state==='riding');assert.ok(agent);
 await settlePassengerDoors(p,false);
 await p.evaluate(id=>{
  const i=window.metroPassengerInspector,a=i.system.simulation.agents.find(a=>a.id===id),pos=i.system.worldPosition(a);
  i.view([.30,pos.y+1.4,pos.z+2.3],[pos.x,pos.y+1.0,pos.z],52);i.train({speed:20,dist:-70});
 },agent.id);
 await p.keyboard.press('Digit5');await p.locator('#carCameraToggle').click();
 const shot=async name=>{
  const snapshot=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
  assert.deepEqual(snapshot.agents.filter(a=>a.space==='train').map(a=>a.id),ids);
  const path=output+'/'+name+'.png';await p.screenshot({path,timeout:180000});
  const png=PNG.sync.read(await readFile(path));let bright=0,pixels=0;
  // HUD text cannot make an otherwise black interior frame pass.
  for(let y=110;y<png.height;y++)for(let x=0;x<png.width;x++){
   const n=(y*png.width+x)*4;if(png.data[n]+png.data[n+1]+png.data[n+2]>180)bright++;pixels++;
  }
  const fraction=bright/pixels;assert.ok(fraction>.10,`${name}: interior is occluded or black`);
  report.motion.push({name,...snapshot.motion,brightFraction:fraction,grips:snapshot.grips});console.log('Captured',name);
 };
 await p.waitForFunction(()=>window.metroPassengerInspector.snapshot().motion.acceleration>.5);await shot('acceleration');
 await p.locator('#carCameraToggle').click();await p.keyboard.press('Space');await p.locator('#carCameraToggle').click();
 await p.waitForFunction(()=>window.metroPassengerInspector.snapshot().motion.acceleration<-.5);await shot('braking');
 await p.waitForFunction(()=>{const m=window.metroPassengerInspector.snapshot().motion;return m.speed<.1&&Math.abs(m.acceleration)<.02;});await shot('stabilized');
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);report.passed=true;
}finally{report.errors=f.errors;report.requests=f.requests;await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2)+'\n');await f.close();}
