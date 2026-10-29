import {crowdDetour} from './PassengerNavigation.js';

function units(agents){
 const groups=new Map();
 for(const a of agents){const key=a.groupId===null?'person:'+a.id:'group:'+a.groupId;
  if(!groups.has(key))groups.set(key,[]);groups.get(key).push(a);}
 return [...groups.values()];
}
function pathLength(from,path){let sum=0;for(const p of path){sum+=Math.hypot(p.x-from.x,p.z-from.z);from=p;}return sum;}

// Choose the whole family's door together. Queue time is compared with walking
// time, so the next quieter doorway is useful without sending people across
// the entire train merely to make all counters equal.
export function choosePlatformDoors(agents,layout,{dist=0,station=-1}={}){
 const doors=layout.doors.filter(d=>d.available!==false),load=new Map(doors.map(d=>[d.id,0])),carLoad=new Map();
 const exiting=new Map(doors.map(d=>[d.id,agents.filter(a=>a.space==='train'&&a.destination<=station&&a.doorId===d.id).length]));
 const waiting=agents.filter(a=>a.space==='platform'&&a.wantsBoard&&['waiting','strolling','watching','approaching','queueing','queued'].includes(a.state));
 const records=units(waiting).map(group=>({group,choices:doors.flatMap(d=>{
  let walk=0;
  for(const a of group){
   const path=crowdDetour(a,{x:d.queueX,z:d.z+dist},[],layout);
   if(!path)return [];
   walk=Math.max(walk,pathLength(a,path)/a.walkSpeed);
  }
  return [{door:d,walk}];
 })}));
 const change=(record,choice,sign)=>{
  const size=record.group.length,d=choice.door;
  load.set(d.id,load.get(d.id)+sign*size);carLoad.set(d.car,(carLoad.get(d.car)??0)+sign*size);
 };
 const score=choice=>choice.walk+load.get(choice.door.id)*6+(exiting.get(choice.door.id)??0)*3+(carLoad.get(choice.door.car)??0)*.5;
 const best=record=>record.choices.reduce((a,c)=>!a||score(c)<score(a)?c:a,null);
 for(const record of records){
  record.choice=best(record);
  if(record.choice)change(record,record.choice,1);
 }
 // A second look after everyone has selected catches queues formed by people
 // farther along the platform. Cached route costs avoid another path search.
 for(let pass=0;pass<3;pass++)for(const record of records){
  if(!record.choice)continue;
  change(record,record.choice,-1);
  const alternative=best(record);
  if(alternative&&score(alternative)+2<score(record.choice))record.choice=alternative;
  change(record,record.choice,1);
 }
 for(const record of records)if(record.choice)for(const a of record.group)a.doorId=record.choice.door.id;
 return Object.fromEntries(load);
}

export function chooseExitDoors(agents,layout,station){
 const load=new Map();
 for(const group of units(agents.filter(a=>a.space==='train'&&a.destination<=station))){
  const car=group[0].car;
  if(group.some(a=>a.car!==car))continue;
  const available=layout.doors.filter(d=>d.car===car&&d.available!==false);
  let best=null;
  for(const d of available){
   const score=Math.max(...group.map(a=>Math.abs(a.z-d.z)/a.walkSpeed))+(load.get(d.id)??0)*3;
   if(!best||score<best.score)best={door:d,score};
  }
  if(best){for(const a of group)a.doorId=best.door.id;load.set(best.door.id,(load.get(best.door.id)??0)+group.length);}
 }
}
