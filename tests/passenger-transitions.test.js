import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as THREE from '../js/vendor/three.module.js';
import {poseAsset} from './helpers/passenger-pose-fixture.mjs';
import {PassengerAnimator} from '../js/passengers/PassengerAnimator.js';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {beginSitting,beginStanding,updateSeating,seatApproach} from '../js/passengers/PassengerSeating.js';

const closed={station:0,dist:0,speed:0,doorsOpen:false,aperture:0},open={...closed,doorsOpen:true,aperture:1};
function advance(s,seconds,ctx){for(let n=0;n<seconds*30;n++)s.update(1/30,ctx);}

test('seat state machine turns, sits, rises and stabilizes before starting a path',()=>{
 const seat={x:-1.71,z:-90},a={seat,...seatApproach(seat),heading:0,scale:1};beginSitting(a);
 for(let n=0;n<40;n++)updateSeating(a,1/30);assert.equal(a.state,'seatTurning','must finish turning');
 a.heading=a.targetHeading;updateSeating(a,1/30);assert.equal(a.state,'sittingDown');
 for(let n=0;n<30;n++)updateSeating(a,1/30);assert.equal(a.state,'sittingDown');
 assert.ok(a.x>seat.x&&a.x<seatApproach(seat).x);
 for(let n=0;n<32;n++)updateSeating(a,1/30);assert.equal(a.state,'seated');assert.equal(a.x,seat.x);
 beginStanding(a);for(let n=0;n<61;n++)updateSeating(a,1/30);
 assert.equal(a.state,'seatStabilizing');assert.ok(a.seat,'seat stays reserved during stabilization');
 for(let n=0;n<10;n++)updateSeating(a,1/30);assert.equal(a.state,'riding');assert.equal(a.seat,null);
 assert.ok(Math.abs(a.x-seatApproach(seat).x)<.001);
});

test('actual adult, child and elderly sit/stand clips have continuous pelvis height and correct endpoints',async()=>{
 for(const [file,height] of [['man-shirt.glb',1.79],['elder-woman-low.glb',1.59],['boy-low.glb',1.31]]){
  const v=await poseAsset(file,height),a={id:1,phase:1,state:'riding',space:'train',activity:'wait',heading:0,scale:1,distance:0,velocity:0};
  const animator=new PassengerAnimator(v,a);for(let n=0;n<20;n++)animator.update(1/60,n/60);
  let previous=v.bones.Hips.getWorldPosition(new THREE.Vector3()).y;
  for(const state of ['sittingDown','standingUp']){
   a.state=state;a.seatTime=0;
   const heights=[];
   for(let n=0;n<121;n++){
    a.seatTime=n/60;animator.update(1/60,1+n/60);
    const p=v.bones.Hips.getWorldPosition(new THREE.Vector3());heights.push(p.y);
    assert.ok(Math.abs(p.y-previous)<.035,file+': discontinuous pelvis at '+state+'/'+n);
    assert.ok(Math.abs(p.z)<.015&&Math.abs(p.x)<.015,file+': no backrest penetration from root motion');previous=p.y;
   }
   if(state==='sittingDown')assert.ok(Math.abs(heights.at(-1)-.53)<.015,file+': seated height');
   else assert.ok(heights.at(-1)>height*.49,file+': fully standing');
  }
  animator.dispose();
 }
});

test('closing and reopening doors during stand-up cannot skip the clip or duplicate a crossing',()=>{
 const s=new PassengerSimulation({seed:42});s.update(1/30,closed);
 const a=s.agents.find(a=>a.state==='seated');assert.ok(a);a.destination=0;
 s.update(1/30,open);assert.equal(a.state,'standingUp');
 advance(s,1,closed);assert.equal(a.state,'standingUp');assert.equal(a.space,'train');
 assert.equal(s.events.filter(e=>e.id===a.id).length,0);
 advance(s,120,open);assert.equal(s.events.filter(e=>e.kind==='alight'&&e.id===a.id).length,1);
 assert.ok(s.boarding.queues.every(q=>!q.enter.length&&!q.exit.length));
});

test('families reserve adjacent seats without duplicate reservations or isolating children',()=>{
 for(const seed of [717,42,106]){
  const s=new PassengerSimulation({seed});advance(s,120,open);
  for(const child of s.agents.filter(a=>a.parentId!==null&&a.space==='train')){
   const parent=s.agents.find(a=>a.id===child.parentId);
   assert.ok(parent&&parent.space==='train');assert.equal(child.destination,parent.destination);
   assert.ok(Math.hypot(child.x-parent.x,child.z-parent.z)<2,`${seed}/${child.id}: parent must remain nearby`);
   if(child.seat&&parent.seat)assert.ok(Math.hypot(child.seat.x-parent.seat.x,child.seat.z-parent.seat.z)<1);
  }
  const seats=s.agents.flatMap(a=>[a.seat??a.reservedSeat].filter(Boolean)).map(p=>p.x+':'+p.z);
  assert.equal(new Set(seats).size,seats.length);
 }
});

test('twelve consecutive station cycles preserve identities, family destinations and bounded journals',()=>{
 const s=new PassengerSimulation({seed:717}),allEvents=[];let retained=[];
 for(let station=0;station<12;station++){
  advance(s,2,{...closed,station,dist:900,speed:55});
  for(const a of retained){
   const now=s.agents.find(p=>p.id===a.id);assert.equal(now,a,'same object must survive between stations');
  }
  for(const a of s.agents.filter(a=>a.parentId!==null&&a.space==='platform')){
   const parent=s.agents.find(p=>p.id===a.parentId);assert.equal(a.destination,parent.destination);
  }
  const appearances=new Map(s.agents.map(a=>[a.id,JSON.stringify([a.profile,a.scale,a.width,a.tint,a.accessory,a.destination,a.groupId,a.parentId])]));
  // A later station can have >100 occupants, unlike the 24-person initial scene.
  // Keep a finite service deadline while allowing the existing serial door lanes.
  advance(s,120,{...open,station});
  for(let extra=0;extra<180&&s.boarding.queues.some(q=>q.enter.length||q.exit.length);extra++)advance(s,1,{...open,station});
  assert.ok(s.boarding.queues.every(q=>!q.enter.length&&!q.exit.length),'station '+station+': queue leak');
  for(const a of s.agents)assert.equal(JSON.stringify([a.profile,a.scale,a.width,a.tint,a.accessory,a.destination,a.groupId,a.parentId]),appearances.get(a.id));
  assert.equal(new Set(s.agents.map(a=>a.id)).size,s.agents.length);
  assert.ok(!s.agents.some(a=>a.space==='train'&&a.destination<=station),'due passengers must leave');
  const events=s.events.filter(e=>e.station===station);allEvents.push(...events);
  advance(s,2,{...closed,station});advance(s,5,{...open,station});
  assert.equal(s.events.filter(e=>e.station===station).length,events.length,'reopen duplicates');
  retained=s.agents.filter(a=>a.space==='train');
  assert.ok(retained.length<220,'onboard population must reach an equilibrium');
  assert.ok(s.agents.length<300&&s.events.length<=512);
 }
 assert.ok(allEvents.length>512,'test must exceed the retained journal capacity');
 assert.equal(new Set(allEvents.map(e=>e.kind+':'+e.id)).size,allEvents.length);
});
