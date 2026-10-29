import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as THREE from '../js/vendor/three.module.js';
import {createPassengerLayout,createTestPassengerLayout} from '../js/passengers/PassengerLayout.js';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {PassengerNavigation,crowdDetour} from '../js/passengers/PassengerNavigation.js';
import {PassengerAnimator} from '../js/passengers/PassengerAnimator.js';
import {poseAsset} from './helpers/passenger-pose-fixture.mjs';

function movedLayout(){
 const base=createTestPassengerLayout(),dx=3.25,dz=17;
 const point=p=>({...p,x:p.x+dx,z:p.z+dz});
 const bounds=p=>({...p,minX:p.minX+dx,maxX:p.maxX+dx,minZ:p.minZ+dz,maxZ:p.maxZ+dz});
 const cars=base.cars.map(c=>({...c,id:c.id+30,centerZ:c.centerZ+dz,aisleX:c.aisleX+dx,
  bounds:bounds(c.bounds),navigationZone:bounds(c.navigationZone),standingZones:c.standingZones.map(point),
  seatAnchors:c.seatAnchors.map(s=>({...point(s),approach:point(s.approach),hipHeight:.71}))}));
 const doors=base.doors.map(d=>{
  const out={...d,id:101+d.id*7,car:d.car+30,z:d.z+dz,fallback:point(d.fallback),initialStanding:d.initialStanding.map(point)};
  for(const k of Object.keys(d))if(k.endsWith('X'))out[k]+=dx;
  return out;
 });
 return createPassengerLayout({train:{...base.train,thresholdX:base.train.thresholdX+dx,aisleX:base.train.aisleX+dx},
  platform:{...bounds(base.platform)},doors,cars,collisionZones:base.collisionZones.map(point)});
}
const open={station:0,dist:0,speed:0,doorsOpen:true,aperture:1};
function advance(s,seconds,context){for(let n=0;n<seconds*30;n++)s.update(1/30,context);}

test('shifted doors/seats/aisles and sparse IDs work across stations without changing passenger logic',()=>{
 const layout=movedLayout(),s=new PassengerSimulation({seed:717,platformCount:30,onboardCount:12,layout});
 for(let station=0;station<3;station++){
  advance(s,2,{...open,station,dist:900,speed:50,doorsOpen:false,aperture:0});
  const identities=new Map(s.agents.map(a=>[a.id,[a.profile,a.scale,a.width,a.tint,a.destination,a.parentId,a.groupId]]));
  const boarding=s.agents.filter(a=>a.space==='platform'&&a.wantsBoard).length;
  const exiting=s.agents.filter(a=>a.space==='train'&&a.destination<=station).length;
  advance(s,180,{...open,station});
  assert.ok(s.boarding.queues.every(q=>!q.exit.length&&!q.enter.length),'relocated exchange must drain at station '+station);
  assert.equal(s.events.filter(e=>e.station===station&&e.kind==='board').length,boarding);
  assert.equal(s.events.filter(e=>e.station===station&&e.kind==='alight').length,exiting);
  for(const a of s.agents){
   assert.deepEqual([a.profile,a.scale,a.width,a.tint,a.destination,a.parentId,a.groupId],identities.get(a.id));
   if(a.space==='train'){
    const car=layout.car(a.car);assert.ok(a.x>=car.bounds.minX-.01&&a.x<=car.bounds.maxX+.01);
    if(a.seat){assert.ok(car.seatAnchors.includes(a.seat));assert.equal(a.seat.hipHeight,.71);}
   }
  }
  for(const door of layout.doors){
   const events=s.events.filter(e=>e.station===station&&e.door===door.id);
   const first=events.findIndex(e=>e.kind==='board'),last=events.findLastIndex(e=>e.kind==='alight');
   if(first>=0)assert.ok(last<first);
   for(const e of events)assert.ok(e.kind==='board'?e.x>door.thresholdX:e.x<door.thresholdX);
  }
  const count=s.eventSequence;advance(s,2,{...open,station,doorsOpen:false,aperture:0});advance(s,5,{...open,station});
  assert.equal(s.eventSequence,count,'reopen must not duplicate relocated crossings');
 }
});

test('navigation uses injected train collision zones and carriage bounds',()=>{
 const base=createTestPassengerLayout(),obstacle={space:'train',car:0,x:-.31,z:-90,radius:.30};
 const layout=createPassengerLayout({...base,collisionZones:[...base.collisionZones,obstacle]});
 const a={id:1,car:0,doorId:0,x:-.31,z:-92,radius:.25,space:'train',state:'riding',walkSpeed:1,velocity:0,distance:0};
 const goal={x:-.31,z:-88};a.path=crowdDetour(a,goal,[],layout);
 assert.ok(a.path?.length>1,'must route around the supplied obstacle');
 const nav=new PassengerNavigation(layout);
 for(let n=0;n<900&&a.path.length;n++){
  nav.rebuild([a]);nav.move(a,1/30);
  assert.ok(Math.hypot(a.x-obstacle.x,a.z-obstacle.z)>=a.radius+obstacle.radius-1e-7);
 }
 assert.equal(a.path.length,0);assert.ok(Math.hypot(a.x-goal.x,a.z-goal.z)<.01);
});

test('shipped skeleton uses adapter seat height rather than the temporary bench height',async()=>{
 const view=await poseAsset('boy-low.glb',1.31),a={state:'seated',activity:'wait',space:'train',velocity:0,distance:0,phase:1,scale:1,seat:{hipHeight:.71}};
 const animator=new PassengerAnimator(view,a);
 for(let n=0;n<60;n++)animator.update(1/30,n/30);
 const hips=view.bones.Hips.getWorldPosition(new THREE.Vector3());
 assert.ok(Math.abs(hips.y-.71)<.015);animator.dispose();
});

test('moving, removing and restoring a rail anchor updates or releases an existing grip',async()=>{
 const view=await poseAsset('man-shirt.glb',1.79);
 view.root.position.set(.40,1.135,29.28);view.root.rotation.y=-Math.PI/2;
 const rails=[{id:'adapter-bar',radius:.025,points:Array.from({length:40},(_,i)=>new THREE.Vector3(.15,2.1+i*.015,29.05))}];
 const a={id:1,phase:1,state:'riding',space:'train',activity:'rail',velocity:0,heading:-Math.PI/2,scale:1,distance:0};
 const animator=new PassengerAnimator(view,a,{rails});animator.update(1/30,0);
 assert.ok(animator.grip,'fixture must grip the supplied anchor');
 const target=animator.grip.target.clone();
 for(const p of rails[0].points)p.x+=.04;
 animator.update(1/30,.1);assert.ok(animator.grip&&animator.grip.target.distanceTo(target)>.02);
 assert.ok(animator.grip.error<.002);
 const bar=rails.pop();animator.update(1/30,.2);assert.equal(animator.grip,null);assert.equal(a.railGrip,null);
 rails.push(bar);animator.update(1/30,1);assert.ok(animator.grip&&animator.grip.error<.002);animator.dispose();
});
