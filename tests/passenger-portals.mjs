import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser,ready} from './helpers/cab-browser-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-portals';
await mkdir(output,{recursive:true});const f=await launchCabBrowser();const report={};
try{
 const p=await f.page({viewport:{width:960,height:600}});p.setDefaultTimeout(120000);
 await ready(p,f.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await p.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready);
 await p.evaluate(()=>{const i=window.metroPassengerInspector;i.pause();i.view([-6,2.6,19.8],[-2.1,1.9,18.75]);});
 const settle=async open=>p.evaluate(async open=>{
  const i=window.metroPassengerInspector,scene=i.scene,backings=[],leaves=[];
  scene.traverse(o=>{if(o.name==='PassengerPortalBacking')backings.push(o);if(o.name==='PassengerExteriorDoorLeaf')leaves.push(o);});
  // Fast-forward the SAME animated door controller; the main scenario already
  // covers real-time opening. No mesh coordinates or visibility are assigned.
  const {animateDoorLeaves}=await import('/js/train/TrainDoors.js?v=20261026-smooth-v16');
  const descriptors=leaves.map(leaf=>{
   const portalBacking=backings.find(b=>Math.sign(b.position.x)===Math.sign(leaf.position.x)&&Math.abs(b.position.z-leaf.position.z)<1.57);
   if(!portalBacking)throw new Error('backing not matched');
   return {leaf,portalBacking,doorZ:portalBacking.position.z,half:Math.sign(leaf.position.z-portalBacking.position.z)};
  });
  i.train({doors:open});for(let n=0;n<17;n++)animateDoorLeaves(descriptors,open,.1);
  await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
  return {count:backings.length,leaves:leaves.length,visible:backings.filter(b=>b.visible).length,aperture:i.system.context.aperture};
 },open);
 report.closed=await settle(false);assert.equal(report.closed.count,20);assert.equal(report.closed.leaves,40);assert.equal(report.closed.visible,20);
 await p.screenshot({path:output+'/closed.png',timeout:120000});
 report.open=await settle(true);assert.equal(report.open.visible,0);assert.ok(report.open.aperture>.96);
 await p.screenshot({path:output+'/open.png',timeout:120000});
 report.reclosed=await settle(false);assert.equal(report.reclosed.visible,20);
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);report.passed=true;
}finally{report.errors=f.errors;report.requests=f.requests;await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2)+'\n');await f.close();}
