import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdirSync,writeFileSync} from 'node:fs';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {createTestPassengerLayout} from '../js/passengers/PassengerLayout.js';
import {normalPassengerLayout} from './helpers/normal-passenger-layout.mjs';

const appearance=a=>[a.profile,a.scale,a.width,a.tint,a.accessory,a.groupId,a.parentId];
for(const [name,makeLayout,seed]of [['stand',()=>createTestPassengerLayout({carCount:4}),717],['contract',normalPassengerLayout,42]]){
 test(`TZ4 full 15-stop route: ${name}, seed ${seed}, terminal empties all four cars`,()=>{
  const s=new PassengerSimulation({seed,normal:true,layout:makeLayout(),platformCount:90,onboardCount:12}),report={name,seed,stations:[]};
  const advance=(seconds,ctx)=>{for(let n=0;n<seconds*30;n++)s.update(1/30,ctx);};
  let retained=[];
  try{
   for(let station=0;station<15;station++){
    const closed={station,stationCount:15,dist:900,speed:50,doorsOpen:false,aperture:0},open={...closed,dist:0,speed:0,doorsOpen:true,aperture:1};
    s.update(1/30,closed);const plan=s.routePlan,platform=s.agents.filter(a=>a.space==='platform'),before=s.agents.filter(a=>a.space==='train');
    assert.ok(platform.length>=80&&platform.length<=100);
    for(const a of retained)assert.equal(s.agents.find(p=>p.id===a.id),a,'retained identities');
    assert.equal(before.length,station===0?12:retained.length,'no replacement or disappearing riders');
    const identities=new Map(s.agents.map(a=>[a.id,appearance(a)]));
    assert.equal(platform.filter(a=>a.wantsBoard).length,plan.boarding);assert.ok(plan.boarding<=40);
    const zs=platform.map(a=>a.z),cars=s.layout.cars;
    assert.ok(Math.max(...zs)-Math.min(...zs)>.75*(Math.max(...cars.map(c=>c.navigationZone.maxZ))-Math.min(...cars.map(c=>c.navigationZone.minZ))));
    if(plan.boarding>=12)assert.equal(new Set(platform.filter(a=>a.wantsBoard).map(a=>a.boardingCar)).size,4);
    if(station===14){assert.equal(plan.boarding,0);assert.equal(plan.exiting,before.length);}
    advance(35,closed);for(let n=0;n<360;n++)s.update(1/30,{...closed,dist:140-n/30*11.6,speed:42});
    let dwell=null;const deadline=station===14?120:name==='stand'?60:35;
    for(let n=0;n<deadline*30;n++){
     s.update(1/30,open);if(s.boarding.passengerExchangeComplete){dwell=(n+1)/30;break;}
    }
    const events=s.events.filter(e=>e.station===station),board=events.filter(e=>e.kind==='board'),exit=events.filter(e=>e.kind==='alight');
    const onboard=s.agents.filter(a=>a.space==='train'),result={station,population:platform.length,plan,dwell,before:before.length,boarded:board.length,alighted:exit.length,onboard:onboard.length,perCar:cars.map(c=>({id:c.id,count:onboard.filter(a=>a.car===c.id).length})),...s.boarding.exchangeSnapshot()};report.stations.push(result);
    if(dwell===null)result.failure={snapshot:s.snapshot(),paths:s.agents.filter(a=>a.path.length).map(a=>({id:a.id,path:a.path}))};
    assert.ok(dwell!==null,`${name} station ${station}: exchange exceeded ${deadline} s`);
    assert.equal(s.boarding.doorsSafeToClose,true);assert.equal(s.boarding.missed.size,0);
    assert.equal(board.length,plan.boarding);assert.equal(exit.length,plan.exiting);
    assert.equal(onboard.length,before.length+board.length-exit.length);
    for(const a of s.agents)assert.deepEqual(appearance(a),identities.get(a.id));
    for(const c of plan.cars)assert.ok(onboard.filter(a=>a.car===c.id).length<=c.capacity);
    for(const d of s.layout.doors){const ee=events.filter(e=>e.door===d.id),first=ee.findIndex(e=>e.kind==='board'),last=ee.findLastIndex(e=>e.kind==='alight');if(first>=0)assert.ok(last<first,'exit priority');}
    advance(15,{...open,doorsOpen:false,aperture:0});
    result.seated=s.agents.filter(a=>a.space==='train'&&a.state==='seated').length;result.standing=s.agents.filter(a=>a.space==='train'&&a.state==='riding').length;
    if(station===14){assert.equal(s.snapshot().route.readyForNextTrip,true);assert.equal(onboard.length,0);assert.ok(result.perCar.every(c=>c.count===0));const seq=s.eventSequence;advance(1,open);assert.equal(s.eventSequence,seq);}
    retained=s.agents.filter(a=>a.space==='train');
   }
   const peak=Math.max(...report.stations.map(s=>s.onboard));assert.ok(peak>report.stations[0].onboard*1.4);
   const mid=report.stations.slice(4,9);assert.ok(mid.some(s=>s.seated>0&&s.standing>0));
   assert.ok(report.stations[13].onboard<=peak*.25);assert.equal(report.stations[14].onboard,0);
   s.update(1/30,{station:0,stationCount:15,dist:900,speed:50,doorsOpen:false,aperture:0});assert.equal(s.agents.filter(a=>a.space==='train').length,0,'next trip starts empty');
   report.passed=true;
  }finally{mkdirSync('test-results/route-flow',{recursive:true});writeFileSync(`test-results/route-flow/${name}-${seed}.json`,JSON.stringify(report,null,2)+'\n');}
 });
}
