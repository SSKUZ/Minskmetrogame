import {DOORS,TRAIN,trainSeatPositions} from './PassengerConfig.js';
import {platformPath} from './PassengerNavigation.js';
import {beginSitting,beginStanding,seatApproach} from './PassengerSeating.js';
import {reservePassengerSeat,familyCompanions} from './PassengerPlaces.js';

function departurePath(a){
 const bay={x:-8.5-(a.id%6)*.58,z:a.z+((a.id%7)-3)*.65};
 const exit={x:-12-(a.id%8)*.75,z:a.z<-55?-114:3};
 return [...platformPath(a,bay,a.radius),...platformPath(bay,exit,a.radius)];
}

export class PassengerBoardingController{
 constructor(){this.queues=DOORS.map(d=>({...d,phase:'closed',active:null,exit:[],enter:[],served:0}));this.opened=false;this.events=[];}
 prepare(agents,station,dist){
  this.opened=true;
  // People who are not boarding make room for the doorway and alighting lane.
  for(const a of agents)if(a.space==='platform'&&!a.wantsBoard&&a.x>-5.3&&DOORS.some(d=>Math.abs(a.z-d.z-dist)<1.0)){
   const target={x:-7.8,z:a.z};
   a.state='yielding';a.activity='wait';a.path=platformPath(a,target,a.radius);
  }
  for(const q of this.queues){
   q.active=null;q.phase='alighting';q.served=0;
   q.exit=agents.filter(a=>a.space==='train'&&a.destination<=station&&a.doorId===q.id).map(a=>a.id);
   q.enter=agents.filter(a=>a.space==='platform'&&a.wantsBoard&&a.state!=='leaving'&&a.doorId===q.id)
    .sort((a,b)=>Math.hypot(a.x+3.8,a.z-q.z-dist)-Math.hypot(b.x+3.8,b.z-q.z-dist)).map(a=>a.id);
   q.enter.forEach((id,rank)=>{
    const a=agents.find(a=>a.id===id);a.state='queueing';a.activity='wait';
    const edge=q.z>1;
    a.queuePoint={x:-3.65-(edge?rank%2:Math.floor(rank/2)%2)*.72,z:q.z+dist+(edge?-1:rank%2?1:-1)*(1.28+Math.floor(rank/(edge?2:4))*.76)};
    a.path=platformPath(a,a.queuePoint,a.radius);
   });
  }
 }
 update(agents,context){
  const {station,dist,speed,doorsOpen,aperture}=context;
  const stopped=Math.abs(dist)<=3&&speed<.5;
  if(!this.opened&&stopped&&doorsOpen&&aperture>.80)this.prepare(agents,station,dist);
  const byId=new Map(agents.map(a=>[a.id,a]));
  for(const q of this.queues){
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
      active.path=departurePath(active);
      continue;
     }
     if(active.state==='boarding'&&active.space==='train'){
      active.path=[];this.afterMove(active,context,agents);continue;
     }
     if(active.space==='train'){
      // If already inside, finish walking away from the leaves. Otherwise retreat.
      active.path=[{x:TRAIN.aisleX,z:q.z}];active.state='returning';
     }else{
      active.path=[{x:-3.75,z:q.z+dist}];active.state='returning';
     }
    }
    continue;
   }
   if(!this.opened||aperture<.92||active)continue;
   if(q.exit.length){
    const a=byId.get(q.exit[0]);if(!a){q.exit.shift();continue;}
    if(a.state==='seated'){beginStanding(a);continue;}
    if(['seatTurning','sittingDown','standingUp','seatStabilizing'].includes(a.state))continue;
    // Alighters walk to the doorway through the aisle, then leave into the clear central lane.
    a.state='alighting';a.seat=null;a.activity='wait';
    a.path=[{x:TRAIN.aisleX,z:a.z},{x:TRAIN.aisleX,z:q.z},{x:-2.42,z:q.z},{x:-3.8,z:q.z},{x:-4.45,z:q.z}];
    q.active=a.id;q.phase='alighting';
   }else if(q.enter.length){
    const a=byId.get(q.enter[0]);if(!a){q.enter.shift();continue;}
    q.phase='boarding';
    // Everybody sharing this door yields until the first person reaches the waiting bay.
    if(a.state==='queueing'&&Math.hypot(a.x+3.65,a.z-q.z-dist)<4.5)a.state='queued';
    if(a.state!=='queued')continue;
    a.state='boarding';a.path=[...platformPath(a,{x:-3.55,z:q.z+dist},a.radius),{x:-2.56,z:q.z+dist},{x:-1.65,z:q.z+dist}];
    q.active=a.id;
   }else q.phase='complete';
  }
 }
 afterMove(a,context,agents=[]){
  const q=this.queues[a.doorId],{dist,station}=context;
  if(a.state==='boarding'&&a.space==='platform'&&a.x>TRAIN.thresholdX+.02){
   a.space='train';a.z-=dist;for(const p of a.path)p.z-=dist;
   if(!a.boardingCounted){a.boardingCounted=true;this.events.push({kind:'board',id:a.id,door:q.id,station,x:a.x});}
  }
  if(a.state==='alighting'&&a.space==='train'&&a.x<TRAIN.thresholdX-.02){
   a.space='platform';a.z+=dist;for(const p of a.path)p.z+=dist;
   if(!a.exitCounted){a.exitCounted=true;this.events.push({kind:'alight',id:a.id,door:q.id,station,x:a.x});}
  }
  if(a.path.length)return;
  if(a.state==='queueing'){a.state='queued';return;}
  if(a.state==='yielding'){a.state='waiting';return;}
  if(a.state==='alighting'){
   q.exit=q.exit.filter(id=>id!==a.id);q.active=null;
   a.state='leaving';a.wantsBoard=false;a.path=departurePath(a);
  }else if(a.state==='boarding'){
   q.enter=q.enter.filter(id=>id!==a.id);q.active=null;q.served++;
   a.car=q.car;a.state='settling';
   const slot=q.served-1,side=slot%2?-1:1;
   // Keep the doorway clear; walk down the aisle before taking a free place.
   const center=-88+q.car*21.5,candidates=trainSeatPositions(q.car);
   candidates.sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
   a.seat=reservePassengerSeat(a,agents,candidates,slot);
   const standing=[];for(const sx of [-1,1])for(let n=0;n<8;n++)standing.push({x:TRAIN.aisleX+sx*.71,z:center-7+n*2});
   standing.sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
   if(a.railPreference){
    const physical=(this.railPlaces??[]).filter(p=>p.z>center-10&&p.z<center+10).sort((p,b)=>Math.abs(p.z-q.z)-Math.abs(b.z-q.z));
    standing.unshift(...physical);
   }
   const companion=familyCompanions(a,agents).find(o=>o.space==='train'&&o.state!=='alighting');
   if(companion&&(a.child||companion.child||!a.railPreference)){const anchor=companion.seat??companion.path.at(-1)??companion;standing.sort((p,b)=>Math.hypot(p.x-anchor.x,p.z-anchor.z)-Math.hypot(b.x-anchor.x,b.z-anchor.z));}
   const place=standing.find(p=>!agents.some(o=>o!==a&&o.space==='train'&&Math.hypot(p.x-(o.path.at(-1)?.x??o.x),p.z-(o.path.at(-1)?.z??o.z))<.60));
   const target=(a.seat?seatApproach(a.seat):null)??place??{x:side*.71-.31,z:q.z+(q.id%2?-1:1)*3.2};
   a.assignedRailId=target.railId??null;
   a.path=[{x:TRAIN.aisleX,z:q.z},{x:TRAIN.aisleX,z:target.z},target];
  }else if(a.state==='returning'){
   q.active=null;
   a.state=a.space==='train'?'riding':'queued';
   if(a.space==='train'&&a.boardingCounted){q.enter=q.enter.filter(id=>id!==a.id);}
  }else if(a.state==='settling'){
   if(a.seat)beginSitting(a);else a.state='riding';
   a.activity=a.seat?'wait':a.assignedRailId?'rail':a.id%3===0?'phone':a.id%3===1?'rail':'window';
   a.targetHeading=a.seat?(a.x<-.31?Math.PI/2:-Math.PI/2):a.heading;
  }else if(a.state==='leaving'){a.state='gone';}
 }
 reset(){this.opened=false;for(const q of this.queues){q.active=null;q.exit=[];q.enter=[];q.phase='closed';}}
 snapshot(){return this.queues.map(q=>({id:q.id,phase:q.phase,active:q.active,exiting:q.exit.length,waiting:q.enter.length,served:q.served}));}
}
