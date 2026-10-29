import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as THREE from '../js/vendor/three.module.js';
import {PassengerTrainMotion,PassengerBalance} from '../js/passengers/PassengerBalance.js';
import {readCarriageRails} from '../js/passengers/PassengerRailGrip.js';
import {PassengerAnimator} from '../js/passengers/PassengerAnimator.js';
import {buildCarriageRails} from '../js/carriage/CarriageRails.js';
import {poseAsset} from './helpers/passenger-pose-fixture.mjs';

const person=(phase=1)=>({id:1,phase,state:'riding',space:'train',velocity:0,heading:0,scale:1,distance:0,activity:'rail'});
function response(a,acceleration,supported=false){const b=new PassengerBalance(a);let p;for(let n=0;n<180;n++)p=b.update(1/60,n/60,{speed:0,acceleration},a,supported);return p;}

test('train motion adapter measures m/s² from km/h and resets station discontinuities',()=>{
 const m=new PassengerTrainMotion();m.update(.1,{speed:0,station:0});
 for(let n=1;n<=30;n++)m.update(.1,{speed:n*.36,station:0});
 assert.ok(Math.abs(m.acceleration-1)<.001);
 for(let n=29;n>=0;n--)m.update(.1,{speed:n*.36,station:0});
 assert.ok(Math.abs(m.acceleration+1)<.001);
 m.update(.1,{speed:90,station:1});assert.ok(Math.abs(m.acceleration)<.5);
});

test('acceleration and braking tilt opposite ways in train coordinates for every facing',()=>{
 for(const heading of [0,Math.PI/2,Math.PI,-Math.PI/2]){
  const a={...person(),heading},acc=response(a,1.6),brake=response(a,-2.4);
  const worldForward=p=>-Math.cos(heading)*p.x-Math.sin(heading)*p.z;
  assert.ok(worldForward(acc)>.02);assert.ok(worldForward(brake)<-.03);
  assert.ok(Math.abs(worldForward(response(a,-3.2)))>Math.abs(worldForward(brake)));
 }
 assert.ok(Math.abs(response(person(),2,true).x)<Math.abs(response(person(),2).x)*.6);
 assert.ok(Math.abs(response({...person(),state:'seated'},2).x)<Math.abs(response(person(),2).x)*.3);
 assert.equal(response({...person(),space:'platform'},2).x,0);
});

test('cruising sway has independent phases, remains subtle and settles at rest',()=>{
 const balances=Array.from({length:24},(_,id)=>({a:person(id*.837),b:new PassengerBalance(person(id*.837))}));
 for(let n=0;n<240;n++)for(const {a,b} of balances)b.update(1/60,n/60,{speed:55,acceleration:0},a);
 assert.ok(new Set(balances.map(({b})=>b.forward.toFixed(5))).size>20);
 for(const {a,b} of balances){
  assert.ok(Math.abs(b.forward)<.01&&Math.abs(b.lateral)<.01);
  for(let n=0;n<600;n++)b.update(1/60,n/60,{speed:0,acceleration:0},a);
  assert.ok(Math.abs(b.forward)<1e-8&&Math.abs(b.lateral)<1e-8);
 }
});

test('real carriage rail grips stay fixed while the shipped skeleton compensates train motion',async()=>{
 const carriage=new THREE.Group();carriage.position.set(-.49,.10,32.6785714286);carriage.scale.z=10.5/9.8;
 buildCarriageRails({THREE,carriage,box(){},carSteel:new THREE.MeshBasicMaterial()});
 const rails=readCarriageRails(carriage);assert.ok(rails.length>15);
 const observed=new Set();
 for(const [file,height] of [['man-shirt.glb',1.79],['elder-woman-low.glb',1.59],['boy-low.glb',1.31]]){
  const view=await poseAsset(file,height);view.root.position.set(.40,1.135,29.28);view.root.rotation.y=-Math.PI/2;
  const a={...person(),heading:-Math.PI/2},motion={speed:45,acceleration:0};
  const animator=new PassengerAnimator(view,a,{rails,motion});animator.update(1/60,0);
  assert.ok(animator.grip,file+': must choose a physically reachable rail');
  const fixed=animator.grip.target.clone();
  for(let n=0;n<240;n++){
   motion.acceleration=n<80?1.8:n<160?-3:0;animator.update(1/60,n/60);
   assert.ok(animator.grip.target.distanceTo(fixed)<1e-9);
   assert.ok(animator.grip.error<.002,file+': wrist must remain locked, error '+animator.grip.error);
  }
  observed.add(Math.abs(animator.grip.tangent.y)>.8?'vertical':'horizontal');
  // Exercise a real horizontal section too, not an artificial IK marker.
  animator.grip=null;a.railGrip=null;animator.gripAttempted=false;animator.rails=rails.filter(r=>Math.abs(r.points[60].y-r.points[62].y)<.001);
  animator.update(1/60,5);
  if(animator.grip){observed.add('horizontal');assert.ok(animator.grip.error<.002);}
  a.activity='wait';a.velocity=.3;animator.update(1/60,6);assert.equal(animator.grip,null);
  animator.dispose();
 }
 assert.ok(observed.has('vertical'));
 const horizontal=rails.map(r=>({...r,points:r.points.filter((p,i,points)=>i&&Math.abs(p.clone().sub(points[i-1]).normalize().y)<.18)})).filter(r=>r.points.length>2);
 const childView=await poseAsset('boy-low.glb',1.31),child={...person(),child:true};
 childView.root.position.set(-1.49441332,1.135,32.64642857);
 const animator=new PassengerAnimator(childView,child,{rails:horizontal,motion:{speed:45,acceleration:-2}});
 for(let n=0;n<180;n++)animator.update(1/60,n/60);
 assert.ok(animator.grip,'a child can hold a real lower horizontal bar');
 assert.ok(Math.abs(animator.grip.tangent.y)<.18&&animator.grip.error<.002);
 animator.dispose();
});

test('unreachable physical rails leave the passenger with relaxed arms',async()=>{
 const view=await poseAsset('boy-low.glb',1.31),a=person();
 const animator=new PassengerAnimator(view,a,{rails:[{id:'ceiling',radius:.03,points:[new THREE.Vector3(0,3,0),new THREE.Vector3(1,3,0)]}]});
 animator.update(.1,0);assert.equal(animator.grip,null);animator.dispose();
});
