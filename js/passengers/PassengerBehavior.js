import {DOORS,PLATFORM,randomSource,turnDelta} from './PassengerConfig.js';
import {PassengerSpawner} from './PassengerSpawner.js';
import {PassengerNavigation,platformPath} from './PassengerNavigation.js';
import {PassengerBoardingController} from './PassengerBoardingController.js';
import {updateSeating} from './PassengerSeating.js';
import {updateCarriageActivity} from './PassengerActivities.js';

export class PassengerSimulation{
 constructor({seed=Date.now(),platformCount=64,onboardCount=24}={}){
  this.seed=seed;this.random=randomSource(seed);this.spawner=new PassengerSpawner(seed);
  this.platformCount=platformCount;this.onboardCount=onboardCount;this.agents=[];
  this.navigation=new PassengerNavigation();this.boarding=new PassengerBoardingController();
  this.station=-1;this.time=0;this.accumulator=0;this.events=[];this.eventSequence=0;
 }
 enterStation(index){
  const onboard=this.agents.filter(a=>a.space==='train'&&a.state!=='gone');
  for(const a of onboard){a.boardingCounted=false;a.exitCounted=false;}
  this.agents=[...onboard,...this.spawner.station(index,this.platformCount)];
  if(this.station===-1)this.agents.push(...this.spawner.onboard(index,this.onboardCount));
  this.station=index;this.boarding.reset();
 }
 update(elapsed,context){
  if(this.station!==context.station)this.enterStation(context.station);
  this.accumulator+=Math.max(0,Math.min(elapsed,.25));
  while(this.accumulator>=1/30){this.step(1/30,context);this.accumulator-=1/30;}
 }
 step(dt,context){
  this.time+=dt;this.navigation.rebuild(this.agents);this.boarding.update(this.agents,context);
  const preparing=context.dist<145&&context.dist>-12&&context.speed>1;
  for(const a of this.agents){
   if(a.state==='gone')continue;
   if(a.space==='platform'&&['waiting','strolling','watching','approaching'].includes(a.state)){
    if(preparing&&a.wantsBoard&&a.state!=='approaching'){
     a.state='approaching';a.activity='wait';
     const door=DOORS[a.doorId];a.path=platformPath(a,{x:-3.7-(a.id%3)*.60,z:door.z+(a.id%2?1.7:-1.7)},a.radius);
    }
    if(a.parentId!==null){
     const parent=this.agents.find(p=>p.id===a.parentId);
     if(parent&&Math.hypot(a.x-parent.x,a.z-parent.z)>1.05)
      a.path=platformPath(a,{x:parent.x-.52,z:parent.z+.18},a.radius);
    }
    if(!a.path.length){
     if(a.state==='approaching'){a.state='watching';a.targetHeading=Math.PI/2;}
     if(a.state==='strolling'){a.state='waiting';a.nextDecision=this.time+2+this.random()*5;}
     if(this.time>a.nextDecision&&!preparing&&a.groupId===null){
      const n=this.random();a.nextDecision=this.time+5+this.random()*11;
      if(n<.31){a.state='strolling';a.activity='wait';a.path=platformPath(a,{x:a.x+(this.random()-.5)*3,z:a.z+(this.random()-.5)*16},a.radius);}
      else a.activity=n<.63?'phone':n<.86?'look':'wait';
     }
     if(a.state==='watching')a.targetHeading=Math.PI/2;
    }
   }
   updateCarriageActivity(a,this.time,this.random,this.agents);
   const seating=updateSeating(a,dt);
   if(a.path.length&&!seating)this.navigation.move(a,dt);else a.velocity=Math.max(0,a.velocity-dt*2.5);
   this.boarding.afterMove(a,context,this.agents);
   const delta=turnDelta(a.heading,a.targetHeading),turn=Math.min(1,dt*(a.state==='seatTurning'?6:a.velocity>.08?7:2));
   a.heading+=delta*turn;
  }
  for(const event of this.boarding.events.splice(0))this.events.push({...event,sequence:++this.eventSequence});
  if(this.events.length>512)this.events.splice(0,this.events.length-512);
 }
 snapshot(){
  const counts={};for(const a of this.agents)counts[a.state]=(counts[a.state]??0)+1;
  return {seed:this.seed,station:this.station,time:this.time,counts,
   onboard:this.agents.filter(a=>a.space==='train'&&a.state!=='gone').length,
   platform:this.agents.filter(a=>a.space==='platform'&&a.state!=='gone').length,
   doors:this.boarding.snapshot(),events:this.events.slice(-200),
   agents:this.agents.map(a=>({id:a.id,profile:a.profile,state:a.state,activity:a.activity,space:a.space,x:a.x,z:a.z,heading:a.heading,velocity:a.velocity,distance:a.distance,parentId:a.parentId,groupId:a.groupId,doorId:a.doorId,scale:a.scale,destination:a.destination,seat:a.seat,seatTime:a.seatTime,accessory:a.accessory,tint:a.tint})),
  };
 }
}
