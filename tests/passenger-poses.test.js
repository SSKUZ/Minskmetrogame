import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as THREE from '../js/vendor/three.module.js';
import {poseAsset} from './helpers/passenger-pose-fixture.mjs';
import {PassengerAnimator} from '../js/passengers/PassengerAnimator.js';

test('shipped chair animations keep the pelvis on its reserved seat and hands near the lap',async()=>{
 for(const [file,height] of [['man-shirt.glb',1.79],['elder-woman-low.glb',1.59],['boy-low.glb',1.31]]){
  const view=await poseAsset(file,height),a={state:'seated',activity:'wait',space:'train',velocity:0,distance:0,phase:1,scale:1};
  const animator=new PassengerAnimator(view,a);
  for(let i=0;i<60;i++)animator.update(1/30,i/30);
  view.root.updateWorldMatrix(true,true);
  const hips=view.bones.Hips.getWorldPosition(new THREE.Vector3());
  assert.ok(Math.abs(hips.x)<.015&&Math.abs(hips.z)<.015,file+': clip must not move pelvis into backrest');
  assert.ok(Math.abs(hips.y-.53)<.015,file+': seat height');
  for(const side of ['Left','Right']){
   const hand=view.bones[side+'Hand'].getWorldPosition(new THREE.Vector3());
   assert.ok(Math.abs(hand.x)<.30&&hand.z>0&&hand.z<.40,file+': hands must rest over thighs');
  }
  a.state='riding';animator.update(1/30,3);
  assert.ok(Math.abs(view.model.position.x)<.001&&Math.abs(view.model.position.z)<.001,'standing clears chair root correction');
  animator.dispose();
 }
});
