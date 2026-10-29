import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync,existsSync} from 'node:fs';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {COLUMNS,PLATFORM,trainSeatPositions} from '../js/passengers/PassengerConfig.js';
import {selectPassengerLOD} from '../js/passengers/PassengerLOD.js';

const context={station:0,dist:0,speed:0,doorsOpen:false,aperture:0};
function advance(sim,seconds,ctx=context,rate=30){for(let i=0;i<seconds*rate;i++)sim.update(1/rate,ctx);}
test('seeded crowds differ between visits; families and conversations have real partners',()=>{
 const a=new PassengerSimulation({seed:717}),b=new PassengerSimulation({seed:718});advance(a,1);advance(b,1);
 assert.notEqual(a.agents[0].x,b.agents[0].x);assert.equal(new Set(a.agents.map(p=>p.profile)).size,12);
 for(const p of a.agents.filter(p=>p.child&&p.space==='platform')){
  const parent=a.agents.find(a=>a.id===p.parentId);assert.ok(parent&&!parent.child);assert.ok(Math.hypot(p.x-parent.x,p.z-parent.z)<1.1);
 }
 assert.ok(a.agents.filter(a=>a.activity==='talk').length>=4);
 const before=a.agents.find(a=>a.state==='strolling');assert.ok(before);const distance=before.distance;advance(a,3);assert.ok(before.distance>distance);
});
test('waiting and wandering respect the real safety line and column footprints',()=>{
 for(const seed of [717,42,106,10677]){
  const s=new PassengerSimulation({seed});advance(s,30,{...context,dist:600});
  for(const p of s.agents.filter(p=>p.space==='platform')){
   assert.ok(p.x<=PLATFORM.maxX+.001&&p.x>=PLATFORM.minX-.001,`${seed}/${p.id}: edge`);
   assert.ok(COLUMNS.every(c=>Math.hypot(c.x-p.x,c.z-p.z)>=c.radius+p.radius-.015),`${seed}/${p.id}: column`);
  }
 }
});
test('opening a moving train or a narrow door cannot begin passenger exchange',()=>{
 const s=new PassengerSimulation({seed:717});advance(s,5,{...context,doorsOpen:true,aperture:1,speed:8});assert.equal(s.events.length,0);
 advance(s,5,{...context,doorsOpen:true,aperture:.5});assert.equal(s.events.length,0);
 advance(s,5,{...context,doorsOpen:true,aperture:1,dist:12});assert.equal(s.events.length,0);
});
test('each door finishes alighting before boarding; every crossing is counted once',()=>{
 for(const seed of [717,42,106]){
  const s=new PassengerSimulation({seed});const open={...context,doorsOpen:true,aperture:1};advance(s,120,open);
  const exit=s.events.filter(e=>e.kind==='alight'),enter=s.events.filter(e=>e.kind==='board');
  assert.equal(exit.length,8);assert.ok(enter.length>=40,`${seed}: ${enter.length} boardings`);
  assert.equal(new Set(s.events.map(e=>`${e.kind}:${e.id}`)).size,s.events.length);
  assert.ok(exit.every(e=>e.x< -2.50));assert.ok(enter.every(e=>e.x> -2.50));
  for(const q of s.boarding.queues){
   const first=s.events.findIndex(e=>e.door===q.id&&e.kind==='board');
   const last=s.events.findLastIndex(e=>e.door===q.id&&e.kind==='alight');if(first>=0)assert.ok(last<first);
  }
  assert.ok(s.boarding.queues.every(q=>q.exit.length===0&&q.enter.length===0),`${seed}: queues must drain`);
 }
});
test('door closure cancels new crossings and preserves passengers already aboard',()=>{
 const s=new PassengerSimulation({seed:717}),open={...context,doorsOpen:true,aperture:1};advance(s,12,open);
 const boarded=s.agents.filter(a=>a.space==='train'&&a.boardingCounted).map(a=>a.id);assert.ok(boarded.length>0);
 advance(s,12,context);const events=s.events.length;advance(s,5,context);assert.equal(s.events.length,events);
 for(const id of boarded)assert.equal(s.agents.find(a=>a.id===id).space,'train');
 advance(s,1,{...context,station:1,dist:900});
 for(const id of boarded)assert.ok(s.agents.some(a=>a.id===id&&a.space==='train'));
});
test('independent render rates give the same simulation; seat reservations are unique',()=>{
 const a=new PassengerSimulation({seed:717}),b=new PassengerSimulation({seed:717}),open={...context,doorsOpen:true,aperture:1};
 advance(a,35,open,20);advance(b,35,open,120);
 assert.equal(a.events.length,b.events.length);assert.ok(Math.abs(a.time-b.time)<.034);
 const seats=a.agents.filter(p=>p.space==='train'&&p.seat).map(p=>`${p.seat.x}:${p.seat.z}`);assert.equal(new Set(seats).size,seats.length);
 assert.ok(trainSeatPositions(0).length>=16);
});
test('LOD has hysteresis and every demographic ships textured rigged models',()=>{
 assert.equal(selectPassengerLOD(21,'near'),'near');assert.equal(selectPassengerLOD(21,'far'),'medium');
 assert.equal(selectPassengerLOD(56,'medium'),'medium');assert.equal(selectPassengerLOD(56,'far'),'far');
 const manifest=JSON.parse(readFileSync(new URL('../assets/passengers/manifest.json',import.meta.url)));
 assert.equal(manifest.models.length,24);assert.ok(manifest.textureBytes<9_000_000);
 for(const m of manifest.models){
  assert.ok(m.bones>=25);assert.ok(m.animations.includes('Walk')&&m.animations.includes('Sit idle (chair)'));
  assert.ok(m.triangles<50000);assert.ok(existsSync(new URL('../assets/passengers/'+m.file,import.meta.url)));
 }
});
