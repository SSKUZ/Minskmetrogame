import assert from 'node:assert/strict';
import {test} from 'node:test';
import {PassengerNavigation} from '../js/passengers/PassengerNavigation.js';
import {createPassengerLayout,createTestPassengerLayout} from '../js/passengers/PassengerLayout.js';

const walker=(path,state='settling')=>({id:1,car:0,doorId:0,x:-.31,z:-94,radius:.25,space:'train',state,walkSpeed:1,velocity:0,distance:0,path});
const blocker=(x,z)=>({id:2,car:0,x,z,radius:.25,space:'train',state:'riding',path:[]});
function advance(nav,a,others,seconds=25,obstacles=[]){
 for(let n=0;n<seconds*30&&a.path.length;n++){
  const previous={x:a.x,z:a.z};nav.rebuild([a,...others]);nav.move(a,1/30);
  assert.ok(Math.hypot(a.x-previous.x,a.z-previous.z)<=a.walkSpeed/30+.045,'no teleport around the blocked point');
  for(const b of others)assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=a.radius+b.radius+.025-1e-6,'body collision');
  for(const o of obstacles)assert.ok(Math.hypot(a.x-o.x,a.z-o.z)>=a.radius+o.radius-1e-6,'static collision');
 }
}

test('a passenger bypasses an occupied aisle marker and keeps the real final destination',()=>{
 const target={x:-.31,z:-90},a=walker([{x:-.31,z:-92},target]),b=blocker(-.31,-92);
 advance(new PassengerNavigation(),a,[b]);
 assert.equal(a.path.length,0);assert.ok(Math.hypot(a.x-target.x,a.z-target.z)<.01);
 assert.equal(b.x,-.31);assert.equal(b.z,-92,'standing passenger must not be moved by the planner');
});

test('aisle bypass respects injected obstacles instead of cutting a straight shortcut',()=>{
 const base=createTestPassengerLayout(),obstacle={space:'train',car:0,x:-.31,z:-91,radius:.20};
 const layout=createPassengerLayout({...base,collisionZones:[...base.collisionZones,obstacle]});
 const a=walker([{x:-.31,z:-92},{x:-.31,z:-90}]),b=blocker(-.31,-92);
 advance(new PassengerNavigation(layout),a,[b],30,[obstacle]);
 assert.equal(a.path.length,0);assert.ok(Math.hypot(a.x+.31,a.z+90)<.01);
});

test('an occupied final standing place is not discarded as an aisle marker',()=>{
 const target={x:-.31,z:-92},a=walker([target]),b=blocker(target.x,target.z);
 advance(new PassengerNavigation(),a,[b],10);
 assert.ok(a.path.includes(target),'a final destination must remain reserved/pending');
});

test('aisle recovery cannot skip the mandatory turn into a doorway',()=>{
 const turn={x:-.31,z:-92},portal={x:-2.42,z:-92},a=walker([turn,portal],'alighting'),b=blocker(turn.x,turn.z);
 advance(new PassengerNavigation(),a,[b],10);
 assert.ok(a.path.includes(turn)&&a.path.includes(portal));
 assert.ok(a.x>-1.25,'blocked turn must not become a diagonal through the door jamb');
});

for(const kind of ['person','obstacle'])test(`the last centimetres to a route marker still respect a ${kind}`,()=>{
 const base=createTestPassengerLayout(),a=walker([{x:-.31,z:-93.96}]);
 const obstacle={space:'train',car:0,x:-.31,z:-93.52,radius:.20};
 const b=blocker(-.31,-93.44);
 const nav=new PassengerNavigation(kind==='obstacle'?createPassengerLayout({...base,collisionZones:[obstacle]}):base);
 nav.rebuild(kind==='person'?[a,b]:[a]);nav.move(a,1/30);
 const other=kind==='person'?b:obstacle,margin=kind==='person'?.025:0;
 assert.ok(Math.hypot(a.x-other.x,a.z-other.z)>=a.radius+other.radius+margin-1e-8,'waypoint completion must not bypass collisions');
 assert.equal(a.path.length,1,'blocked destination must stay pending');
});
