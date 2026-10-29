import * as THREE from '../vendor/three.module.js';
import {PassengerBalance} from './PassengerBalance.js';
import {chooseRailGrip} from './PassengerRailGrip.js';
import {SEAT_TIMING} from './PassengerSeating.js';
import {PassengerHandGrip} from './PassengerHandGrip.js';

const delta=new THREE.Quaternion(),euler=new THREE.Euler();
const v0=new THREE.Vector3(),v1=new THREE.Vector3(),v2=new THREE.Vector3(),v3=new THREE.Vector3(),v4=new THREE.Vector3();
const q0=new THREE.Quaternion(),q1=new THREE.Quaternion(),q2=new THREE.Quaternion();
function pointBone(bone,child,target){
 bone.getWorldPosition(v0);child.getWorldPosition(v1);v1.sub(v0).normalize();v2.copy(target).sub(v0).normalize();
 q0.setFromUnitVectors(v1,v2);bone.getWorldQuaternion(q1);q0.multiply(q1);
 bone.parent.getWorldQuaternion(q2).invert();bone.quaternion.copy(q2.multiply(q0));bone.updateWorldMatrix(false,true);
}
// Analytic two-bone IK keeps hands beside the body, on a lap or around a phone.
function solveArm(view,side,targetLocal,poleLocal){
 const upper=view.bones[side+'Arm'],elbow=view.bones[side+'ForeArm'],hand=view.bones[side+'Hand'];if(!upper||!elbow||!hand)return;
 view.model.updateWorldMatrix(true,true);
 const shoulder=new THREE.Vector3(),bend=new THREE.Vector3(),wrist=new THREE.Vector3();
 upper.getWorldPosition(shoulder);elbow.getWorldPosition(bend);hand.getWorldPosition(wrist);
 const target=view.model.localToWorld(targetLocal.clone()),pole=view.model.localToWorld(poleLocal.clone());
 const l1=shoulder.distanceTo(bend),l2=bend.distanceTo(wrist),direction=target.clone().sub(shoulder);
 const d=THREE.MathUtils.clamp(direction.length(),Math.abs(l1-l2)+.001,l1+l2-.003);direction.normalize();
 const perpendicular=pole.sub(shoulder).addScaledVector(direction,-pole.dot(direction)).normalize();
 const along=(l1*l1-l2*l2+d*d)/(2*d),height=Math.sqrt(Math.max(0,l1*l1-along*along));
 const desired=shoulder.clone().addScaledVector(direction,along).addScaledVector(perpendicular,height);
 pointBone(upper,elbow,desired);pointBone(elbow,hand,target);
}
export class PassengerAnimator{
 constructor(view,agent,{rails=[],motion=null}={}){
  this.handGrip=new PassengerHandGrip(view);this.rails=rails;this.motion=motion;this.balance=new PassengerBalance(agent);this.grip=null;this.gripAttempted=false;
  this.view=view;this.agent=agent;this.mixer=new THREE.AnimationMixer(view.model);this.actions={};this.mode=null;
  for(const clip of view.animations)this.actions[clip.name]=this.mixer.clipAction(clip);
  this.rest={};for(const [name,bone] of Object.entries(view.bones))this.rest[name]=bone.quaternion.clone();
  this.lastTime=0;this.sitOffset=0;
 }
 update(dt,time){
  const a=this.agent,v=this.view,walking=a.velocity>.055;
  const transitioning=['sittingDown','standingUp'].includes(a.state);
  const mode=a.state==='sittingDown'?'Sit down (chair)':a.state==='standingUp'?'Stand up (chair)':a.state==='seated'?'Sit idle (chair)':walking?'Walk':a.activity==='talk'?'Talk':'Idle';
  if(this.mode!==mode){
   const next=this.actions[mode]??this.actions.Idle;
   next.reset().play();next.setLoop(transitioning?THREE.LoopOnce:THREE.LoopRepeat,Infinity);next.clampWhenFinished=transitioning;next.timeScale=transitioning?0:1;next.time=transitioning?0:a.phase%next.getClip().duration;next.fadeIn(.16);
   if(this.mode)this.actions[this.mode]?.fadeOut(.22);
   this.mode=mode;
  }
  if(transitioning){const action=this.actions[mode];if(action)action.time=Math.min(action.getClip().duration-.00001,(a.seatTime??0)/2*action.getClip().duration);}
  v.model.position.set(0,0,0);
  const walk=this.actions.Walk;
  if(walk){
   walk.timeScale=0;
   // CMU walk travels 1.4916m per cycle at a reference adult height of 1.75m.
   const stride=1.4916*(v.height/1.75)*a.scale;
   walk.time=(a.distance/stride*walk.getClip().duration+a.phase)%walk.getClip().duration;
  }
  // Remove the previous procedural layer before sampling a fresh skeletal pose.
  for(const [name,bone] of Object.entries(v.bones))if(this.pose?.[name])bone.quaternion.copy(this.pose[name]);
  this.mixer.update(Math.min(.12,dt));
  this.pose={};for(const [name,bone] of Object.entries(v.bones))this.pose[name]=bone.quaternion.clone();
  const add=(name,x,y=0,z=0)=>{const bone=v.bones[name];if(!bone)return;euler.set(x,y,z,'XYZ');delta.setFromEuler(euler);bone.quaternion.multiply(delta);};
  const phone=a.activity==='phone'&&!walking;
  const phoneSide=this.grip?.side==='Right'?'Left':'Right';
  const actionWeight=a.activityStart===undefined?1:Math.min(1,Math.max(0,(time-a.activityStart)/.5),Math.max(0,((a.activityUntil??time+1)-time)/.5));
  v.props.phone.visible=phone;
  if(phone)add('Head',.19*actionWeight,-.06);
  if(['window','display','child','talk','bag','weight'].includes(a.activity)&&!walking){
   if(a.activity==='window')add('Head',0,(a.x<-.31?-.38:.38)*actionWeight);
   if(a.activity==='display')add('Head',-.12*actionWeight,.23*actionWeight);
   if(a.activity==='child'||a.activity==='talk')add('Head',a.activity==='child'?.12:0,THREE.MathUtils.clamp(Math.atan2(Math.sin(a.attentionAngle??0),Math.cos(a.attentionAngle??0)),-.5,.5)*actionWeight);
   if(a.activity==='bag')add('Head',.12*actionWeight);
   if(a.activity==='weight')add('Spine',0,0,Math.sin((time-(a.activityStart??time))*1.3)*.012*actionWeight);
  }
  if(a.activity==='look'||a.state==='watching')add('Head',0,Math.sin(time*.48+a.phase)*.28);
  if(a.activity==='talk'&&!walking){
   const gesture=Math.max(0,Math.sin(time*.87+a.phase));
   add('LeftForeArm',-.45*gesture);add('LeftArm',-.11*gesture,0,.06*gesture);
  }
  const lean=this.balance.update(dt,time,this.motion,a,!!this.grip);
  add('Spine',lean.x*.55,0,lean.z*.55);add('Spine1',lean.x*.35,0,lean.z*.35);add('Head',-lean.x*.15,0,-lean.z*.12);
  if(a.state==='seated'||transitioning){
   // Fit the hips to the real 81-717 bench, independent of the CMU chair height.
   v.model.updateMatrixWorld(true);
   const hips=v.bones.Hips;
   if(hips){
    const p=new THREE.Vector3();hips.getWorldPosition(p);v.root.worldToLocal(p);
    // The source chair clip translates the pelvis ~0.55m backwards. Remove
    // that root motion so the reserved seat is the actual pelvis position.
    v.model.position.x-=p.x;v.model.position.z-=p.z;
    if(!transitioning)v.model.position.y+=.53/(a.scale??1)-p.y;
    else {
     const track=this.actions[mode]?.getClip().tracks.find(t=>t.name==='Hips.position');
     if(track){
      const endY=track.values[a.state==='sittingDown'?track.values.length-2:1]*v.scale;
      const standingY=track.values[a.state==='sittingDown'?1:track.values.length-2]*v.scale;
      const weight=THREE.MathUtils.clamp((standingY-p.y)/(standingY-endY),0,1);
      v.model.position.y+=weight*(.53/(a.scale??1)-endY);
     }
    }
   }
  }else v.model.position.set(0,0,0);
  const wantsGrip=(a.activity==='rail'||a.railPreference||!!a.railGrip)&&a.space==='train'&&a.state==='riding'&&!walking;
  if(!wantsGrip){this.grip=null;this.gripAttempted=false;a.railGrip=null;}
  if(wantsGrip&&!this.gripAttempted){this.grip=a.railGrip??chooseRailGrip(v,this.rails);a.railGrip=this.grip;this.gripAttempted=true;}
  if(!walking){
   const seated=a.state==='seated'||transitioning,hips=new THREE.Vector3();
   v.model.updateWorldMatrix(true,true);v.bones.Hips?.getWorldPosition(hips);v.model.worldToLocal(hips);
   const y=seated?hips.y+.13:v.height/v.scale*.45;
   const bodyHeight=v.height/v.scale;
   for(const [side,sign] of [['Left',1],['Right',-1]]){
    const target=new THREE.Vector3(sign*.215+(seated?hips.x:0),y,seated?hips.z+.28:.035);
    if(side===phoneSide&&phone)target.set((seated?hips.x:0)+(side==='Left'?.13:-.13),seated?hips.y+.36:bodyHeight*.68,(seated?hips.z:0)+.27);
    if(this.grip?.side===side)target.copy(v.model.worldToLocal(this.grip.target.clone()));
    if(side==='Left'&&a.activity==='bag'&&!this.grip){target.y+=.15*actionWeight;target.z+=.06*actionWeight;}
    if(side==='Left'&&a.activity==='talk'&&this.grip?.side!=='Left'){target.z+=.07+.06*Math.sin(time+a.phase);target.y+=.07*Math.max(0,Math.sin(time*.87+a.phase));}
    solveArm(v,side,target,new THREE.Vector3(sign*.55+(seated?hips.x:0),seated?hips.y+.25:bodyHeight*.57,(seated?hips.z:0)-.22));
   }
   this.handGrip.update(this.grip);
   if(this.grip){
    const wrist=v.bones[this.grip.side+'Hand'].getWorldPosition(new THREE.Vector3());
    this.grip.error=wrist.distanceTo(this.grip.target);
   }
   if(phone&&v.bones[phoneSide+'Hand']){
    const hand=new THREE.Vector3();v.bones[phoneSide+'Hand'].getWorldPosition(hand);v.model.worldToLocal(hand);
    v.props.phone.position.copy(hand);v.props.phone.position.y+=.035;
    const head=new THREE.Vector3();v.bones.Head?.getWorldPosition(head);v.props.phone.lookAt(head);
   }
  }
  if(walking)this.handGrip.update(null);
  const bag=v.props.bag;
  if(bag&&a.accessory==='backpack'){
   const carried=bag.userData.carried;
   if(a.state==='seated'||transitioning){
    const hips=v.model.worldToLocal(v.bones.Hips.getWorldPosition(new THREE.Vector3()));
    if(bag.parent!==v.model)v.model.attach(bag);
    const weight=a.state==='seated'?1:THREE.MathUtils.smoothstep((a.seatTime??0)/2,0,1);
    const blend=a.state==='standingUp'?1-weight:weight;
    const carriedMatrix=new THREE.Matrix4().multiplyMatrices(carried.parent.matrixWorld,carried.matrix);
    carriedMatrix.premultiply(v.model.matrixWorld.clone().invert());
    carriedMatrix.decompose(bag.position,bag.quaternion,bag.scale);
    bag.position.lerp(new THREE.Vector3(hips.x,hips.y+.15,hips.z+.27),blend);
    bag.quaternion.slerp(new THREE.Quaternion().setFromEuler(new THREE.Euler(-.35,0,0)),blend);
   }else if(bag.parent!==carried.parent){carried.parent.add(bag);carried.matrix.decompose(bag.position,bag.quaternion,bag.scale);}
  }
  this.lastTime=time;
 }
 dispose(){this.handGrip.dispose();this.mixer.stopAllAction();this.mixer.uncacheRoot(this.view.model);}
}
