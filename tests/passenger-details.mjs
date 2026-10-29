import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser,ready} from './helpers/cab-browser-fixture.mjs';
const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-details-r4';await mkdir(output,{recursive:true});
const f=await launchCabBrowser();let report={};
try{
 const p=await f.page({viewport:{width:1280,height:800}});p.setDefaultTimeout(120000);
 await ready(p,f.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await p.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready);await p.evaluate(()=>window.metroPassengerInspector.pause());
 await p.evaluate(()=>window.metroPassengerInspector.train({doors:true}));await p.waitForFunction(()=>window.metroPassengerInspector.system.context.aperture>.96);
 await p.evaluate(()=>window.metroPassengerInspector.step(120));await p.locator('#carCameraToggle').click();
 const shot=async(name,position,target,fov=48)=>{await p.evaluate(({position,target,fov})=>window.metroPassengerInspector.view(position,target,fov),{position,target,fov});await p.screenshot({path:output+'/'+name+'.png',timeout:120000});console.log('Captured',name);};
 await shot('carriage',[.2,2.55,31],[-.45,2.15,14],58);report.snapshot=await p.evaluate(()=>window.metroPassengerInspector.snapshot());
 const s=report.snapshot,grip=s.grips[0];assert.ok(grip);const a=s.agents.find(a=>a.id===grip.id),[x,y,z]=grip.point,side=grip.side==='Right'?-1:1;
 await shot('real-grip',[Math.max(-1.85,Math.min(1.2,x+Math.cos(a.heading)*side*1.15+(x<-.31?.15:-.15))),y+.18,z-Math.sin(a.heading)*side*1.15],[x,y-.04,z],43);
 await shot('standing',[-.25,2.6,z+1.8],[a.x,2.1,a.z+112],50);
 const child=s.agents.find(c=>c.parentId!==null&&c.space==='train'&&c.z> -98&&c.z< -77),parent=s.agents.find(a=>a.id===child.parentId);
 assert.ok(parent&&Math.hypot(child.x-parent.x,child.z-parent.z)<1);
 const middleZ=(child.z+parent.z)/2+112,lookX=(child.x+parent.x)/2,sign=lookX<-.31?1:-1;
 await shot('family-seated',[lookX+sign*1.8,2.5,middleZ+.3],[lookX,2.05,middleZ],58);
 report.errors=f.errors;report.requests=f.requests;assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);report.passed=true;
}finally{await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2));await f.close();}
