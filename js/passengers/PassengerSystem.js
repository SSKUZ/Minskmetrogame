import * as THREE from '../vendor/three.module.js';
import {createTestPassengerLayout} from './PassengerLayout.js';
import {PassengerSimulation} from './PassengerBehavior.js';
import {PassengerModelLibrary} from './PassengerModel.js';
import {PassengerAnimator} from './PassengerAnimator.js';
import {PassengerImpostors,selectPassengerLOD} from './PassengerLOD.js';
import {PassengerAudio} from './PassengerAudio.js';
import {PassengerTrainMotion} from './PassengerBalance.js';
import {readCarriageRails,railStandingPlaces} from './PassengerRailGrip.js';

function contactMaterial(){
 const canvas=document.createElement('canvas');canvas.width=64;canvas.height=64;const c=canvas.getContext('2d');
 const g=c.createRadialGradient(32,32,1,32,32,32);g.addColorStop(0,'rgba(0,0,0,.24)');g.addColorStop(1,'rgba(0,0,0,0)');c.fillStyle=g;c.fillRect(0,0,64,64);
 return new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas),transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1});
}
export class PassengerSystem{
 constructor({scene,platform,seed,onCount,carriage,layout}){
  this.layout=layout??createTestPassengerLayout({gripAnchors:carriage?readCarriageRails(carriage):[],carCount:4});
  this.motion=new PassengerTrainMotion();this.rails=this.layout.gripAnchors;
  this.scene=scene;this.platform=platform;this.onCount=onCount;this.simulation=new PassengerSimulation({seed,layout:this.layout,platformCount:90,onboardCount:12,normal:true});
  this.simulation.boarding.railPlaces=this.layout.cars.flatMap(car=>railStandingPlaces(this.rails,this.layout.train.offsetZ,car.aisleX,{...car.bounds,floorY:this.layout.train.floorY}).filter(p=>p.z>car.navigationZone.minZ&&p.z<car.navigationZone.maxZ).map(p=>({...p,car:car.id})));
  this.models=new PassengerModelLibrary();this.impostors=new PassengerImpostors(scene);this.audio=new PassengerAudio();
  this.actors=new Map();this.root=new THREE.Group();this.root.name='PassengerSystem';scene.add(this.root);
  this.shadowMaterial=contactMaterial();this.shadowGeometry=new THREE.PlaneGeometry(.72,.56);this.shadowGeometry.rotateX(-Math.PI/2);
  this.ready=false;this.errors=[];this.time=0;this.eventCursor=0;this.counted=new Set();this.lodStats={};
  this.readyPromise=Promise.all([this.models.preload(),this.impostors.load()]).then(()=>{this.ready=true;}).catch(e=>{this.errors.push(e.message);console.error('Passenger assets:',e);});
  const unlock=()=>{this.audio.start().catch(()=>{});};
  window.addEventListener('pointerdown',unlock,{once:true});window.addEventListener('keydown',unlock,{once:true});
 }
 worldPosition(a,out=new THREE.Vector3()){
  const platformZ=this.platform.position.z,{train:TRAIN,platform:PLATFORM}=this.layout,door=this.layout.door(a.doorId);
  const z=a.z+(a.space==='train'?TRAIN.offsetZ:platformZ);
  // A physical step across the threshold; waiting people always stay behind the safety line.
  const lift=THREE.MathUtils.smoothstep(a.x,door.thresholdX-.22,door.thresholdX+.20);
  const y=(a.space==='train'?TRAIN.floorY:PLATFORM.y+(TRAIN.floorY-PLATFORM.y)*lift)+this.platform.position.y;
  return out.set(a.x,y,z);
 }
 get passengerExchangeComplete(){return this.simulation.boarding.passengerExchangeComplete;}
 get doorsSafeToClose(){return this.simulation.boarding.doorsSafeToClose;}
 requestFinishBoarding(){return this.simulation.boarding.requestFinishBoarding(this.simulation.agents);}
 update(dt,context,camera,{mirrorCameras=[],volume=1,inCab=false,playing=true}={}){
  this.time+=dt;this.context=context;this.motion.update(dt,context);
  if(!this.paused)this.simulation.update(dt,context);
  const live=new Set(this.simulation.agents.filter(a=>a.state!=='gone').map(a=>a.id));
  for(const [id,actor] of this.actors)if(!live.has(id)){
   for(const view of actor.views.values()){view.animator.dispose();view.dispose();this.root.remove(view.root);}
   this.root.remove(actor.shadow);this.actors.delete(id);
  }
  for(const event of this.simulation.events.filter(e=>e.sequence>this.eventCursor)){
   const key=`${event.kind}:${event.id}:${event.station}`;if(this.counted.has(key))continue;
   this.counted.add(key);this.onCount?.(event.kind==='board'?1:-1,event);
  }
  this.eventCursor=this.simulation.eventSequence;
  while(this.counted.size>512)this.counted.delete(this.counted.values().next().value);
  if(!this.ready)return;
  const cameraPosition=new THREE.Vector3();camera.getWorldPosition(cameraPosition);
  const cameraPositions=[cameraPosition];
  // Mirrors choose LOD using their own viewpoints, not only the driver's view direction.
  if(inCab)for(const m of mirrorCameras){const p=new THREE.Vector3();m.getWorldPosition(p);cameraPositions.push(p);}
  this.impostors.begin();this.lodStats={near:0,medium:0,far:0,hidden:0,animated:0};
  for(const a of this.simulation.agents){
   if(a.state==='gone')continue;
   let actor=this.actors.get(a.id);
   if(!actor){
    const shadow=new THREE.Mesh(this.shadowGeometry,this.shadowMaterial);this.root.add(shadow);
    actor={views:new Map(),shadow,lod:'far',lastAnimationTime:0};this.actors.set(a.id,actor);
   }
   const position=this.worldPosition(a),distance=Math.min(...cameraPositions.map(p=>p.distanceTo(position)));
   let lod=selectPassengerLOD(distance,actor.lod);
   // Separate seated atlases retain the pose without animating the entire train
   // at full depth. Doorway actions continue to use real skeletal geometry.
   if(lod==='far'&&['boarding','alighting','seatTurning','sittingDown','standingUp','seatStabilizing'].includes(a.state))lod='medium';
   if(distance>155)lod='hidden';actor.lod=lod;this.lodStats[lod]++;
   for(const view of actor.views.values())view.root.visible=false;
   actor.shadow.visible=lod!=='hidden'&&lod!=='far';actor.shadow.position.copy(position);actor.shadow.position.y+=.009;
   if(lod==='far'){this.impostors.add(a,position);continue;}
   if(lod==='hidden')continue;
   const detail=lod==='near'?'medium':'low';let view=actor.views.get(detail);
   if(!view){view=this.models.create(a,detail);if(!view)continue;view.animator=new PassengerAnimator(view,a,{rails:this.rails,motion:this.motion,aisleX:this.layout.car(a.car??this.layout.door(a.doorId).car).aisleX});actor.views.set(detail,view);this.root.add(view.root);}
   view.root.visible=true;view.root.position.copy(position);view.root.rotation.y=a.heading;view.root.scale.set(a.scale*a.width,a.scale,a.scale);
   const period=lod==='near'?0:1/15;
   if(this.time-actor.lastAnimationTime>=period){view.animator.update(this.time-actor.lastAnimationTime,this.time);actor.lastAnimationTime=this.time;this.lodStats.animated++;}
  }
  this.impostors.end();
  this.audio.update(this.simulation.agents,cameraPosition,a=>this.worldPosition(a),{volume,playing,inCab,doorsOpen:context.doorsOpen},dt);
 }
 snapshot(){return {...this.simulation.snapshot(),resources:{sharedTextures:this.models.textures.size,tintMaterials:this.models.materials.size,views:[...this.actors.values()].reduce((n,a)=>n+a.views.size,0),journal:this.simulation.events.length,counted:this.counted.size},motion:{speed:this.motion.speed,acceleration:this.motion.acceleration},railCount:this.rails.length,grips:[...this.actors.entries()].flatMap(([id,a])=>[...a.views.values()].filter(v=>v.root.visible&&v.animator.grip).map(v=>({id,side:v.animator.grip.side,railId:v.animator.grip.railId,point:v.animator.grip.point.toArray(),error:v.animator.grip.error}))),ready:this.ready,errors:[...this.errors,...this.models.errors],lod:{...this.lodStats},
  modelsLoaded:this.models.sources.size,actors:this.actors.size,audio:this.audio.snapshot()};}
}
