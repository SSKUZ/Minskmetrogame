import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdirSync,writeFileSync} from 'node:fs';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {normalPassengerLayout} from './helpers/normal-passenger-layout.mjs';
const counts=[40,50,60,50,40,60,50,60];
const appearance=a=>[a.profile,a.scale,a.width,a.tint,a.accessory,a.groupId,a.parentId,a.destination];
for(const seed of [717,42,106])test(`normal 4-car flow: 8 stops, 40–60 people, <=30 s (busy <=35 s) and independent closure signals (seed ${seed})`,()=>{
 const layout=normalPassengerLayout(),s=new PassengerSimulation({seed,normal:true,layout}),report={seed,doorCount:layout.doors.length,stations:[]},events=[];
 const advance=(seconds,ctx)=>{for(let n=0;n<seconds*30;n++)s.update(1/30,ctx);};
 let retained=[];
 try{
  for(let station=0;station<8;station++){
   s.platformCount=counts[station];const closed={station,dist:900,speed:50,doorsOpen:false,aperture:0},open={...closed,dist:0,speed:0,doorsOpen:true,aperture:1};
   s.update(1/30,closed);assert.equal(s.boarding.passengerExchangeComplete,false,'new station resets completion');
   for(const a of retained)assert.equal(s.agents.find(p=>p.id===a.id),a,'onboard identity must survive');
   const platform=s.agents.filter(a=>a.space==='platform');assert.equal(platform.length,counts[station]);
   assert.ok(platform.every(a=>!a.nextTrainReason),'the normal target must not be passed by rejecting passengers at spawn');
   const zs=platform.map(a=>a.z);assert.ok(Math.max(...zs)-Math.min(...zs)>.7*(layout.platform.maxZ-layout.platform.minZ),'people span the platform');
   const identities=new Map(s.agents.map(a=>[a.id,appearance(a)]));
   const expectedBoard=platform.filter(a=>a.wantsBoard).length,expectedExit=s.agents.filter(a=>a.space==='train'&&a.destination<=station).length;
   advance(35,closed);
   for(let n=0;n<12*30;n++)s.update(1/30,{...closed,dist:140-n/30*11.6,speed:42});
   // TZ3 permits a small increase for a busy stop, without rejecting people.
   const deadline=expectedBoard+expectedExit>=60?35:30;
   let dwell=null,parallel=0,parallelExit=0,queues;
   for(let n=0;n<deadline*30;n++){
    s.update(1/30,open);
    if(n===0){
     queues=s.boarding.queues.map(q=>({id:q.id,car:q.car,in:q.enter.length,out:q.exit.length}));
     assert.equal(new Set(queues.filter(q=>q.in).map(q=>q.car)).size,4,'use all four cars');
     assert.ok(Math.max(...queues.map(q=>q.in))<=8,'small door groups');
    }
    parallel=Math.max(parallel,s.boarding.queues.filter(q=>q.active!==null).length);
    parallelExit=Math.max(parallelExit,s.agents.filter(a=>a.state==='alighting').length);
    if(n%3===0){
     const near=new Map(s.boarding.obstructions.map(o=>[o.id,s.agents.find(a=>a.id===o.id)]));const people=[...near.values()];
     for(let i=0;i<people.length;i++)for(let j=i+1;j<people.length;j++){
      const a=people[i],b=people[j];assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>=a.radius+b.radius-.02,'doorway body overlap');
     }
    }
    if(s.boarding.passengerExchangeComplete){dwell=(n+1)/30;break;}
   }
   const result={station,population:counts[station],expectedBoard,expectedExit,deadline,dwell,parallel,parallelExit,queues,...s.boarding.exchangeSnapshot()};report.stations.push(result);
   if(dwell===null)result.failure={snapshot:s.snapshot(),paths:s.agents.filter(a=>a.path.length).map(a=>({id:a.id,path:a.path}))};
   assert.ok(dwell!==null,`seed ${seed}, station ${station}: normal exchange exceeded ${deadline} s`);
   assert.equal(s.boarding.doorsSafeToClose,true);assert.equal(s.boarding.obstructions.length,0);assert.equal(s.boarding.missed.size,0,'no timer-based rejection to pass the target');
   assert.ok(parallel>=8);if(expectedExit>1)assert.ok(parallelExit>=2);
   const current=s.events.filter(e=>e.station===station);
   assert.equal(current.filter(e=>e.kind==='board').length,expectedBoard);assert.equal(current.filter(e=>e.kind==='alight').length,expectedExit);
   for(const q of queues){const doorEvents=current.filter(e=>e.door===q.id),first=doorEvents.findIndex(e=>e.kind==='board'),last=doorEvents.findLastIndex(e=>e.kind==='alight');if(first>=0)assert.ok(last<first,'exit priority');}
   for(const a of s.agents)assert.deepEqual(appearance(a),identities.get(a.id));
   events.push(...current);const sequence=s.eventSequence;
   advance(1,{...open,doorsOpen:false,aperture:0});advance(1,open);assert.equal(s.eventSequence,sequence,'close/reopen must not duplicate crossings');
   retained=s.agents.filter(a=>a.space==='train');
  }
  assert.equal(new Set(events.map(e=>e.kind+':'+e.id)).size,events.length);report.passed=true;
 }finally{mkdirSync('test-results/normal-flow',{recursive:true});writeFileSync(`test-results/normal-flow/seed-${seed}.json`,JSON.stringify(report,null,2)+'\n');}
});
