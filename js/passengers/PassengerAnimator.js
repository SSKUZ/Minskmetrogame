import * as THREE from '../vendor/three.module.js';

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
 constructor(view,agent){
  this.view=view;this.agent=agent;this.mixer=new THREE.AnimationMixer(view.model);this.actions={};this.mode=null;
  for(const clip of view.animations)this.actions[clip.name]=this.mixer.clipAction(clip);
  this.rest={};for(const [name,bone] of Object.entries(view.bones))this.rest[name]=bone.quaternion.clone();
  this.lastTime=0;this.sitOffset=0;
 }
 update(dt,time){
  const a=this.agent,v=this.view,walking=a.velocity>.055;
  const mode=a.state==='seated'?'Sit idle (chair)':walking?'Walk':a.activity==='talk'?'Talk':'Idle';
  if(this.mode!==mode){
   const next=this.actions[mode]??this.actions.Idle;
   next.reset().play();next.time=a.phase%next.getClip().duration;next.fadeIn(.22);
   if(this.mode)this.actions[this.mode]?.fadeOut(.22);
   this.mode=mode;
  }
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
  v.props.phone.visible=phone;
  if(phone)add('Head',.19,-.06);
  if(a.activity==='look'||a.state==='watching')add('Head',0,Math.sin(time*.48+a.phase)*.28);
  if(a.activity==='talk'&&!walking){
   const gesture=Math.max(0,Math.sin(time*.87+a.phase));
   add('LeftForeArm',-.45*gesture);add('LeftArm',-.11*gesture,0,.06*gesture);
  }
  if(a.space==='train'&&!walking){add('Spine',Math.sin(time*1.2+a.phase)*.012,0,Math.sin(time*.8+a.phase)*.012);}
  if(a.state==='seated'){
   // Fit the hips to the real 81-717 bench, independent of the CMU chair height.
   v.model.updateMatrixWorld(true);
   const hips=v.bones.Hips;
   if(hips){
    const p=new THREE.Vector3();hips.getWorldPosition(p);v.root.worldToLocal(p);
    this.sitOffset+=(.43-p.y)*.55;
    v.model.position.y+=this.sitOffset;
    this.sitOffset=0;
   }
  }else v.model.position.y=0;
  if(!walking){
   const seated=a.state==='seated',hips=new THREE.Vector3();
   v.model.updateWorldMatrix(true,true);v.bones.Hips?.getWorldPosition(hips);v.model.worldToLocal(hips);
   const y=seated?hips.y+.13:v.height/v.scale*.45;
   const bodyHeight=v.height/v.scale;
   for(const [side,sign] of [['Left',1],['Right',-1]]){
    const target=new THREE.Vector3(sign*.215,y,seated?.28:.035);
    if(side==='Right'&&phone)target.set(-.13,seated?hips.y+.36:bodyHeight*.68,.27);
    if(side==='Right'&&a.activity==='rail'&&a.space==='train'&&!seated)target.set(-.18,bodyHeight*1.08,.045);
    if(side==='Left'&&a.activity==='talk'){target.z+=.07+.06*Math.sin(time+a.phase);target.y+=.07*Math.max(0,Math.sin(time*.87+a.phase));}
    solveArm(v,side,target,new THREE.Vector3(sign*.55,bodyHeight*.57,-.22));
   }
   if(phone&&v.bones.RightHand){
    const hand=new THREE.Vector3();v.bones.RightHand.getWorldPosition(hand);v.model.worldToLocal(hand);
    v.props.phone.position.copy(hand);v.props.phone.position.y+=.035;
    v.props.phone.lookAt(v.model.localToWorld(new THREE.Vector3(0,bodyHeight*.87,.04)));
   }
  }
  this.lastTime=time;
 }
 dispose(){this.mixer.stopAllAction();this.mixer.uncacheRoot(this.view.model);}
}
