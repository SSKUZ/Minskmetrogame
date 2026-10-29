import {crowdDetour} from './PassengerNavigation.js';
import {standingPlaceKeepsDoorsClear} from './PassengerPlaces.js';

function units(agents){
 const groups=new Map();
 for(const a of agents){const key=a.groupId===null?'person:'+a.id:'group:'+a.groupId;
  if(!groups.has(key))groups.set(key,[]);groups.get(key).push(a);}
 return [...groups.values()];
}
function pathLength(from,path){let sum=0;for(const p of path){sum+=Math.hypot(p.x-from.x,p.z-from.z);from=p;}return sum;}

export function choosePlatformDoors(agents,layout,{dist=0,station=-1,preserveAssignments=false}={}){
 const doors=layout.doors.filter(d=>d.available!==false),load=new Map(doors.map(d=>[d.id,0]));
 const carLoad=new Map(layout.cars.map(c=>[c.id,agents.filter(a=>a.space==='train'&&a.car===c.id&&a.destination>station).length]));
 const capacity=new Map(layout.cars.map(c=>[c.id,Math.max(0,c.seatAnchors.length+c.standingZones.filter(p=>standingPlaceKeepsDoorsClear(p,layout,c.id)).length-2)]));
 const exiting=new Map(doors.map(d=>[d.id,agents.filter(a=>a.space==='train'&&a.destination<=station&&a.doorId===d.id)
  .reduce((sum,a)=>sum+(layout.car(d.car).aisleX-d.thresholdX+.70)/a.walkSpeed+.25,0)]));
 const waiting=agents.filter(a=>a.space==='platform'&&a.wantsBoard&&['waiting','strolling','watching','approaching','queueing','queued'].includes(a.state));
 const work=new Map(doors.map(d=>[d.id,0]));
 const records=units(waiting).map(group=>({group,choices:doors.flatMap(d=>{
  let walk=0;
  for(const a of group){
   const path=crowdDetour(a,{x:d.queueX,z:d.z+dist},[],layout);
   if(!path)return [];
   walk=Math.max(walk,pathLength(a,path)/a.walkSpeed);
  }
  const clearX=Math.max(d.thresholdX+.63,layout.car(d.car).bounds.minX+.01);
  const service=group.reduce((sum,a)=>sum+(clearX-d.approachX)/a.walkSpeed+.65,0);
  return [{door:d,walk,service}];
 })}));
 const change=(record,choice,sign)=>{
  const size=record.group.length,d=choice.door;
  load.set(d.id,load.get(d.id)+sign*size);carLoad.set(d.car,(carLoad.get(d.car)??0)+sign*size);
  work.set(d.id,work.get(d.id)+sign*choice.service);
 };
 const score=(choice,record)=>((carLoad.get(choice.door.car)??0)+record.group.length>capacity.get(choice.door.car))?Infinity:choice.walk+work.get(choice.door.id)+(exiting.get(choice.door.id)??0)+(carLoad.get(choice.door.car)??0)*.5+(preserveAssignments&&record.group[0].doorId!==choice.door.id?8:0);
 const best=record=>record.choices.reduce((a,c)=>Number.isFinite(score(c,record))&&(!a||score(c,record)<score(a,record))?c:a,null);
 for(const record of records){record.choice=best(record);if(record.choice)change(record,record.choice,1);}
 for(let pass=0;pass<3;pass++)for(const record of records){
  if(!record.choice)continue;
  change(record,record.choice,-1);const alternative=best(record);
  if(alternative&&score(alternative,record)+2<score(record.choice,record))record.choice=alternative;
  change(record,record.choice,1);
 }
 for(const record of records)for(const a of record.group){
  if(record.choice)a.doorId=record.choice.door.id;
  else{a.wantsBoard=false;a.state='waitingNextTrain';a.nextTrainReason='noAccessibleCapacity';a.path=[];}
 }
 const ranks=new Map();
 for(const a of waiting)if(a.wantsBoard){const d=layout.door(a.doorId),rank=ranks.get(d.id)??0;ranks.set(d.id,rank+1);a.approachPoint={x:d.queueX-Math.min(Math.floor(rank/2),2)*.35,z:d.z+(rank%2?1:-1)*(1.28+Math.floor(rank/2)*.65)};}
 return Object.fromEntries(load);
}

export function chooseExitDoors(agents,layout,station,{preserveAssignments=false}={}){
 const load=new Map();
 for(const group of units(agents.filter(a=>a.space==='train'&&a.destination<=station))){
  const car=group[0].car;if(group.some(a=>a.car!==car))continue;
  const available=layout.doors.filter(d=>d.car===car&&d.available!==false);let best=null;
  for(const d of available){
   const score=Math.max(...group.map(a=>Math.abs(a.z-d.z)/a.walkSpeed))+(load.get(d.id)??0)+(preserveAssignments&&group[0].doorId!==d.id?8:0);
   if(!best||score<best.score)best={door:d,score};
  }
  if(best){for(const a of group)a.doorId=best.door.id;load.set(best.door.id,(load.get(best.door.id)??0)+group.reduce((sum,a)=>sum+(layout.car(car).aisleX-best.door.thresholdX+.70)/a.walkSpeed+.25,0));}
 }
}
