import {DOORS,PLATFORM,COLUMNS,randomSource,clamp,trainSeatPositions} from './PassengerConfig.js';
import {platformPath} from './PassengerNavigation.js';

function freePoint(rng,agents,door){
 for(let n=0;n<200;n++){
  const x=n<100?-3.65-rng()*6.9:-10-rng()*8;
  const z=Math.max(-113,Math.min(2,door.z+(rng()-.5)*8.5));
  if(COLUMNS.some(c=>Math.hypot(x-c.x,z-c.z)<c.radius+.5))continue;
  if(agents.some(a=>a.space==='platform'&&Math.hypot(x-a.x,z-a.z)<.72))continue;
  return {x,z};
 }
 return {x:-12-rng()*5,z:-112+rng()*112};
}
export function createPassenger(id,rng,station){
 const profile=id%12,child=profile===6||profile===7,elder=profile===4||profile===5;
 return {id,profile,child,elder,radius:child?.18:.25,scale:.95+rng()*.10,width:.94+rng()*.12,
  railPreference:id%3===1,tint:Math.floor(rng()*5),phase:rng()*13,heading:rng()*Math.PI*2,targetHeading:0,
  walkSpeed:child?.76:elder?.64+rng()*.14:.86+rng()*.48,
  state:'waiting',space:'platform',x:0,z:0,velocity:0,distance:0,path:[],
  activity:rng()<.28?'phone':'wait',nextDecision:2+rng()*9,createdAt:station,
  destination:station+1+Math.floor(rng()*4),wantsBoard:rng()<.82,doorId:0,
  groupId:null,parentId:null,seat:null,boardingCounted:false,exitCounted:false,
  accessory:child?'backpack':rng()<.28?'backpack':rng()<.45?'bag':rng()<.25?'shopping':null,
 };
}

export class PassengerSpawner{
 constructor(seed){this.seed=seed;this.nextId=0;}
 station(index,count=64,existing=[]){
  const rng=randomSource(this.seed+index*91771),agents=[];
  for(let i=0;i<count;i++){
   const a=createPassenger(this.nextId++,rng,index),door=DOORS[i%DOORS.length];
   Object.assign(a,freePoint(rng,[...existing,...agents],door),{doorId:door.id});
   a.targetHeading=a.heading;
   if(i%10===2){a.state='strolling';a.path=platformPath(a,{x:-7-rng()*5,z:a.z+9*(rng()-.5)});}
   agents.push(a);
  }
  // Conversation partners face each other; families keep an adult beside a child.
  for(let i=0;i<agents.length;i++){
   const a=agents[i];
   if(a.child){
    const parent=agents.slice(Math.max(0,i-5),i).find(p=>!p.child&&!p.elder&&p.groupId===null);
    if(parent){a.parentId=parent.id;a.groupId=parent.id;parent.groupId=parent.id;
     a.x=parent.x-.55;a.z=parent.z+.12;a.doorId=parent.doorId;a.wantsBoard=parent.wantsBoard;
     a.state=parent.state='waiting';a.path=[];parent.path=[];
     a.walkSpeed=parent.walkSpeed=Math.min(a.walkSpeed,parent.walkSpeed);a.destination=parent.destination;
    }
   }else if(i%12===0&&agents[i+1]&&a.groupId===null){
    const b=agents[i+1];if(b.child)continue;
    a.activity=b.activity='talk';a.groupId=b.groupId=a.id;
    b.wantsBoard=a.wantsBoard;b.destination=a.destination;
    b.x=a.x-.92;b.z=a.z+.08;b.doorId=a.doorId;
    a.heading=a.targetHeading=-Math.PI/2;b.heading=b.targetHeading=Math.PI/2;
    a.state=b.state='waiting';a.path=[];b.path=[];
   }
  }
  // Group placement is followed by a small packing relaxation, including column footprints.
  for(let iteration=0;iteration<12;iteration++)for(const a of agents){
   for(const b of agents){if(a.id>=b.id)continue;
    const dx=a.x-b.x,dz=a.z-b.z,d=Math.hypot(dx,dz),min=a.radius+b.radius+.09;
    if(d<min){const k=(min-d)*.51/(d||1);a.x+=dx*k;a.z+=dz*k;b.x-=dx*k;b.z-=dz*k;}
   }
   for(const c of COLUMNS){const dx=a.x-c.x,dz=a.z-c.z,d=Math.hypot(dx,dz),r=c.radius+a.radius+.06;
    if(d<r){a.x=c.x+dx/(d||1)*r;a.z=c.z+dz/(d||1)*r;}}
   a.x=clamp(a.x,PLATFORM.minX,PLATFORM.maxX);a.z=clamp(a.z,PLATFORM.minZ,PLATFORM.maxZ);
  }
  return agents;
 }
 onboard(index,count=24){
  const rng=randomSource(this.seed^0x81_717),agents=[];
  for(let i=0;i<count;i++){
   const a=createPassenger(this.nextId++,rng,index),door=DOORS[i%DOORS.length];
   a.space='train';a.doorId=door.id;a.car=door.car;a.wantsBoard=false;
   a.destination=i%3===0?index:index+1+Math.floor(rng()*3);
   const seats=trainSeatPositions(door.car).sort((p,b)=>Math.abs(p.z-door.z)-Math.abs(b.z-door.z));
   a.seat=i%3?seats.find(p=>!agents.some(o=>o.seat&&Math.hypot(o.seat.x-p.x,o.seat.z-p.z)<.58)):null;
   a.x=a.seat?.x??(-1.02+(i%2)*1.42);a.z=a.seat?.z??door.z+(i%2?1.3:-1.3);
   a.state=a.seat?'seated':'riding';a.activity=i%4===0?'phone':i%4===1?'rail':'window';
   a.heading=a.targetHeading=a.seat?(a.x<-.31?Math.PI/2:-Math.PI/2):rng()*6.28;
   agents.push(a);
  }
  return agents;
 }
}
