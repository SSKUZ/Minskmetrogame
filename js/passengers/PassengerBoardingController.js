import {TEST_PASSENGER_LAYOUT} from './PassengerLayout.js';
import {platformPath as layoutPath} from './PassengerNavigation.js';
import {beginSitting,beginStanding,seatApproach} from './PassengerSeating.js';
import {reservePassengerSeat,familyCompanions} from './PassengerPlaces.js';
import {choosePlatformDoors,chooseExitDoors} from './PassengerDoorChoice.js';

function departurePath(a,layout){
 const platformPath=(from,to,radius)=>layoutPath(from,to,radius,layout),PLATFORM=layout.platform;
 const bay={x:PLATFORM.minX+11.8-(a.id%6)*.58,z:a.z+((a.id%7)-3)*.65};
 const exit={x:PLATFORM.minX+8.3-(a.id%8)*.75,z:a.z<(PLATFORM.minZ+PLATFORM.maxZ)/2?PLATFORM.minZ+1:PLATFORM.maxZ-.5};
 return [...platformPath(a,bay,a.radius),...platformPath(bay,exit,a.radius)];
}

export class PassengerBoardingController{
 constructor(layout=TEST_PASSENGER_LAYOUT,{normal=false}={}){this.layout=layout;this.normal=normal;this.queues=layout.doors.map(d=>({...d,phase:'closed',active:null,exit:[],enter:[],served:0}));this.queueById=new Map(this.queues.map(q=>[q.id,q]));this.opened=false;this.events=[];}
 clearPlatformLanes(agents,dist){
  const DOORS=this.layout.doors,platformPath=(from,to,radius)=>layoutPath(from,to,radius,this.layout);
  // People who are not boarding make room for the doorway and alighting lane.
  for(const a of agents)if(a.space==='platform'&&!a.wantsBoard&&['waiting','strolling','watching','approaching'].includes(a.state)&&DOORS.some(d=>a.x>d.yieldBoundaryX&&Math.abs(a.z-d.z-dist)<1.2)){
   const door=DOORS.find(d=>a.x>d.yieldBoundaryX&&Math.abs(a.z-d.z-dist)<1.2),target={x:door.yieldX,z:a.z};
   a.state='yielding';a.activity='wait';a.path=platformPath(a,target,a.radius);
  }
 }
 prepare(agents,station,dist){
  const platformPath=(from,to,radius)=>layoutPath(from,to,radius,this.layout);
  if(this.normal){chooseExitDoors(agents,this.layout,station);choosePlatformDoors(agents,this.layout,{dist,station});}
  this.opened=true;this.clearPlatformLanes(agents,dist);
  for(const q of this.queues){
   q.active=null;q.phase='alighting';q.served=0;
   q.exit=agents.filter(a=>a.space==='train'&&a.destination<=station&&a.doorId===q.id)
    .sort((a,b)=>Math.abs(a.z-q.z)-Math.abs(b.z-q.z)||a.id-b.id).map(a=>a.id);
   for(const id of q.exit){const a=agents.find(a=>a.id===id);a.exitSide=a.z<q.z?-1:1;a.exitQueuePoint=null;}
   q.enter=agents.filter(a=>a.space==='platform'&&a.wantsBoard&&a.state!=='leaving'&&a.doorId===q.id)
    .sort((a,b)=>Math.hypot(a.x-q.exitOuterX,a.z-q.z-dist)-Math.hypot(b.x-q.exitOuterX,b.z-q.z-dist)).map(a=>a.id);
   q.enter.forEach((id,rank)=>{
    const a=agents.find(a=>a.id===id);a.state='queueing';a.activity='wait';
    const edge=q.edge;
    a.queuePoint={x:q.queueX-(edge?rank%2:Math.floor(rank/2)%2)*.72,z:q.z+dist+(edge?-1:rank%2?1:-1)*(1.28+Math.floor(rank/(edge?2:4))*.76)};
    a.path=platformPath(a,a.queuePoint,a.radius);
   });
  }
 }
 stageAlighters(q,byId){
  const TRAIN=this.layout.car(q.car);
  const ranks={[-1]:0,[1]:0};
  for(const id of q.exit){
   const a=byId.get(id);if(!a||a.id===q.active)continue;
   const rank=ranks[a.exitSide]++,front=id===q.exit[0];
   const point={x:TRAIN.aisleX+(front?0:(a.x<TRAIN.aisleX?-.71:.71)),z:q.z+(front?0:a.exitSide*(1.5+rank*.68))};
   // Everybody gets the full stand-up and stabilization clips concurrently.
   // Until their turn, they may only approach a waiting place INSIDE the train.
   if(a.state==='seated'){beginStanding(a);continue;}
   if(['seatTurning','sittingDown','standingUp','seatStabilizing','returning'].includes(a.state))continue;
   if(!['exitApproaching','exitQueued'].includes(a.state)||!a.exitQueuePoint||Math.abs(a.exitQueuePoint.z-point.z)>.01){
    a.state='exitApproaching';a.activity='wait';a.seat=null;a.reservedSeat=null;
    a.railGrip=null;a.assignedRailId=null;a.exitQueuePoint=point;
    // The stand-up clip ends at the bench front. Merge diagonally into the
    // aisle instead of requiring two opposite passengers to touch one point.
    const mergeX=Math.max(TRAIN.aisleX-.97,Math.min(TRAIN.aisleX+.97,a.x));
    a.path=Math.abs(mergeX-a.x)>.01?[{x:mergeX,z:a.z},point]:[point];
   }
  }
 }
 update(agents,context){
  const platformPath=(from,to,radius)=>layoutPath(from,to,radius,this.layout);
  const {station,dist,speed,doorsOpen,aperture}=context;
  const stopped=Math.abs(dist)<=3&&speed<.5;
  if(!this.opened&&stopped&&doorsOpen&&aperture>.80)this.prepare(agents,station,dist);
  if(this.opened&&stopped&&doorsOpen)this.clearPlatformLanes(agents,dist);
  const byId=new Map(agents.map(a=>[a.id,a]));
  for(const q of this.queues){
   const TRAIN=this.layout.car(q.car);
   if(q.active===null)q.exit.sort((left,right)=>{
    const a=byId.get(left),b=byId.get(right);if(!a||!b)return 0;
    const ready=a=>['exitApproaching','exitQueued','riding','settling'].includes(a.state)?0:1;
    return ready(a)-ready(b)||Math.hypot(a.x-TRAIN.aisleX,a.z-q.z)-Math.hypot(b.x-TRAIN.aisleX,b.z-q.z)||a.id-b.id;
   });
   if(this.opened&&stopped&&doorsOpen)this.stageAlighters(q,byId);
   let active=byId.get(q.active);
   if(active&&!['boarding','alighting','returning'].includes(active.state)){q.active=null;active=null;}
   if(!stopped||!doorsOpen){
    if(active&&active.state!=='returning'){
     // A completed threshold crossing stays completed when the leaves close.
     // In particular an alighter already on the platform must never walk back
     // through the doorway just to finish an obsolete train-space route.
     if(active.state==='alighting'&&active.space==='platform'){
      q.exit=q.exit.filter(id=>id!==active.id);q.active=null;
      active.state='leaving';active.wantsBoard=false;
      active.path=departurePath(active,this.layout);
      continue;
     }
     if(active.state==='boarding'&&active.space==='train'){
      active.path=[];this.afterMove(active,context,agents);continue;
     }
     if(active.space==='train'){
      // If already inside, finish walking away from the leaves. Otherwise retreat.
      active.path=[{x:TRAIN.aisleX,z:q.z}];active.state='returning';
     }else{
      active.path=[{x:q.approachX-.20,z:q.z+dist}];active.state='returning';
     }
    }
    continue;
   }
   if(!this.opened||aperture<.92||active)continue;
   if(q.exit.length){
    const a=byId.get(q.exit[0]);if(!a){q.exit.shift();continue;}
    if(!['exitApproaching','exitQueued'].includes(a.state))continue;
    // Alighters walk to the doorway through the aisle, then leave into the clear central lane.
    a.state='alighting';a.seat=null;a.activity='wait';
    a.path=[{x:TRAIN.aisleX,z:q.z},{x:q.exitInnerX,z:q.z},{x:q.exitOuterX,z:q.z},{x:q.exitClearX,z:q.z}];
    q.active=a.id;q.phase='alighting';
   }else if(q.enter.length){
    const a=byId.get(q.enter[0]);if(!a){q.enter.shift();continue;}
    q.phase='boarding';
    // Everybody sharing this door yields until the first person reaches the waiting bay.
    if(a.state==='queueing'&&Math.hypot(a.x-q.queueX,a.z-q.z-dist)<4.5)a.state='queued';
    if(a.state!=='queued')continue;
    a.state='boarding';a.path=[...platformPath(a,{x:q.approachX,z:q.z+dist},a.radius),{x:q.entryX,z:q.z+dist},{x:q.insideX,z:q.z+dist}];
    q.active=a.id;
   }else q.phase='complete';
  }
 }
 afterMove(a,context,agents=[]){
  const q=this.queueById.get(a.doorId),{dist,station}=context;
  const TRAIN=this.layout.car(q.car);
  if(a.state==='boarding'&&a.space==='platform'&&a.x>q.thresholdX+.02){
   a.space='train';a.car=q.car;a.z-=dist;for(const p of a.path)p.z-=dist;
   if(!a.boardingCounted){a.boardingCounted=true;this.events.push({kind:'board',id:a.id,door:q.id,station,x:a.x});}
  }
  if(a.state==='alighting'&&a.space==='train'&&a.x<q.thresholdX-.02){
   a.space='platform';a.z+=dist;for(const p of a.path)p.z+=dist;
   if(!a.exitCounted){a.exitCounted=true;this.events.push({kind:'alight',id:a.id,door:q.id,station,x:a.x});}
  }
  // Once the whole body has cleared the sill, continue leaving independently.
  // The next alighter need not wait for a walk across the whole platform bay.
  if(a.state==='alighting'&&a.space==='platform'&&a.x<q.thresholdX-.70){
   q.exit=q.exit.filter(id=>id!==a.id);q.active=null;
   a.state='leaving';a.wantsBoard=false;a.path=departurePath(a,this.layout);
  }
  if(a.path.length)return;
  if(a.state==='queueing'){a.state='queued';return;}
  if(a.state==='exitApproaching'){a.state='exitQueued';return;}
  if(a.state==='yielding'){a.state='waiting';return;}
  if(a.state==='alighting'){
   q.exit=q.exit.filter(id=>id!==a.id);q.active=null;
   a.state='leaving';a.wantsBoard=false;a.path=departurePath(a,this.layout);
  }else if(a.state==='boarding'){
   q.enter=q.enter.filter(id=>id!==a.id);q.active=null;q.served++;
   a.car=q.car;a.state='settling';
   const slot=q.served-1;
   // Keep the doorway clear; walk down the aisle before taking a free place.
   const car=this.layout.car(q.car),candidates=[...car.seatAnchors];
   candidates.sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
   a.seat=reservePassengerSeat(a,agents,candidates,slot);
   const standing=[...car.standingZones];
   standing.sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
   if(a.railPreference){
    const physical=(this.railPlaces??[]).filter(p=>p.car===q.car).sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
    standing.unshift(...physical);
   }
   const companion=familyCompanions(a,agents).find(o=>o.space==='train'&&o.state!=='alighting');
   if(companion&&(a.child||companion.child||!a.railPreference)){const anchor=companion.seat??companion.path.at(-1)??companion;standing.sort((p,b)=>Math.hypot(p.x-anchor.x,p.z-anchor.z)-Math.hypot(b.x-anchor.x,b.z-anchor.z));}
   const place=standing.find(p=>!agents.some(o=>o!==a&&o.space==='train'&&Math.hypot(p.x-(o.path.at(-1)?.x??o.x),p.z-(o.path.at(-1)?.z??o.z))<.60));
   const target=(a.seat?seatApproach(a.seat):null)??place??q.fallback;
   a.assignedRailId=target.railId??null;
   a.path=[{x:TRAIN.aisleX,z:q.z},{x:TRAIN.aisleX,z:target.z},target];
  }else if(a.state==='returning'){
   q.active=null;
   a.state=a.space==='train'?'riding':'queued';
   if(a.space==='train'&&a.boardingCounted){q.enter=q.enter.filter(id=>id!==a.id);}
  }else if(a.state==='settling'){
   if(a.seat)beginSitting(a);else a.state='riding';
   a.activity=a.seat?'wait':a.assignedRailId?'rail':a.id%3===0?'phone':a.id%3===1?'rail':'window';
   a.targetHeading=a.seat?a.seat.heading:a.heading;
  }else if(a.state==='leaving'){a.state='gone';}
 }
 reset(){this.opened=false;for(const q of this.queues){q.active=null;q.exit=[];q.enter=[];q.phase='closed';}}
 snapshot(){return this.queues.map(q=>({id:q.id,phase:q.phase,active:q.active,exiting:q.exit.length,waiting:q.enter.length,served:q.served}));}
}
