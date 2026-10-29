import assert from 'node:assert/strict';
import {test} from 'node:test';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
const closed={station:0,dist:0,speed:0,doorsOpen:false,aperture:0},open={...closed,doorsOpen:true,aperture:1};
function advance(s,seconds,ctx){for(let n=0;n<seconds*30;n++)s.update(1/30,ctx);}

for(const seed of [717,42,106])test(`twelve station cycles preserve identities, families and bounded journals (seed ${seed})`,()=>{
 const s=new PassengerSimulation({seed}),allEvents=[];let retained=[];
 for(let station=0;station<12;station++){
  advance(s,2,{...closed,station,dist:900,speed:55});
  for(const a of retained){
   const now=s.agents.find(p=>p.id===a.id);assert.equal(now,a,'same object must survive between stations');
  }
  for(const a of s.agents.filter(a=>a.parentId!==null&&a.space==='platform')){
   const parent=s.agents.find(p=>p.id===a.parentId);assert.equal(a.destination,parent.destination);
  }
  const appearances=new Map(s.agents.map(a=>[a.id,JSON.stringify([a.profile,a.scale,a.width,a.tint,a.accessory,a.destination,a.groupId,a.parentId])]));
  // A later station can have >100 occupants. Concurrent preparation must
  // finish the same dense scenario within 150 s (previously allowed 300 s).
  advance(s,120,{...open,station});
  for(let extra=0;extra<30&&s.boarding.queues.some(q=>q.enter.length||q.exit.length);extra++)advance(s,1,{...open,station});
  assert.ok(s.boarding.queues.every(q=>!q.enter.length&&!q.exit.length),'seed '+seed+', station '+station+': exchange exceeded 150 seconds');
  for(const a of s.agents)assert.equal(JSON.stringify([a.profile,a.scale,a.width,a.tint,a.accessory,a.destination,a.groupId,a.parentId]),appearances.get(a.id));
  assert.equal(new Set(s.agents.map(a=>a.id)).size,s.agents.length);
  assert.ok(!s.agents.some(a=>a.space==='train'&&a.destination<=station),'due passengers must leave');
  const events=s.events.filter(e=>e.station===station);allEvents.push(...events);
  advance(s,2,{...closed,station});advance(s,5,{...open,station});
  assert.equal(s.events.filter(e=>e.station===station).length,events.length,'reopen duplicates');
  retained=s.agents.filter(a=>a.space==='train');
  assert.ok(retained.length<220,'onboard population must reach an equilibrium');
  assert.ok(s.agents.length<300&&s.events.length<=512);
 }
 assert.ok(allEvents.length>512,'test must exceed the retained journal capacity');
 assert.equal(new Set(allEvents.map(e=>e.kind+':'+e.id)).size,allEvents.length);
});
