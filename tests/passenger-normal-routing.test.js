import assert from 'node:assert/strict';
import {test} from 'node:test';
import {choosePlatformDoors,chooseExitDoors} from '../js/passengers/PassengerDoorChoice.js';
import {createPassengerLayout,createTestPassengerLayout} from '../js/passengers/PassengerLayout.js';
import {createPassenger} from '../js/passengers/PassengerSpawner.js';
import {randomSource} from '../js/passengers/PassengerConfig.js';
import {standingPlaceKeepsDoorsClear} from '../js/passengers/PassengerPlaces.js';
import {PassengerBoardingController} from '../js/passengers/PassengerBoardingController.js';
import {PassengerSimulation} from '../js/passengers/PassengerBehavior.js';
import {normalPassengerLayout} from './helpers/normal-passenger-layout.mjs';
const person=(id,props={})=>Object.assign(createPassenger(id,randomSource(id+1),0),{groupId:null,parentId:null,wantsBoard:true,state:'waiting',space:'platform',x:-3.8,z:-94.3,walkSpeed:1},props);
test('door choice keeps an isolated passenger near the closest reachable door',()=>{const l=normalPassengerLayout(),a=person(0);choosePlatformDoors([a],l);assert.equal(a.doorId,0);});
test('a local queue sends some passengers to adjacent quieter doors without splitting a family',()=>{
 const l=normalPassengerLayout(),agents=Array.from({length:12},(_,id)=>person(id));agents[0].groupId=agents[1].groupId=100;agents[1].parentId=0;
 choosePlatformDoors(agents,l);assert.ok(new Set(agents.map(a=>a.doorId)).size>1);assert.equal(agents[0].doorId,agents[1].doorId);
 const counts=new Map();for(const a of agents)counts.set(a.doorId,(counts.get(a.doorId)??0)+1);assert.ok(Math.max(...counts.values())<agents.length/2,JSON.stringify([...counts]));
});
test('unavailable doors and a statically blocked approach are excluded',()=>{
 const base=normalPassengerLayout(),doors=base.doors.map(d=>({...d,available:d.id!==0})),blocked=doors[1];
 const l=createPassengerLayout({...base,doors,collisionZones:[...base.collisionZones,{space:'platform',x:blocked.queueX,z:blocked.z,radius:.6}]});
 const a=person(0);choosePlatformDoors([a],l);assert.ok(![0,1].includes(a.doorId));
});
test('car occupancy is considered before arrival, so a full car does not receive another queue',()=>{
 const l=normalPassengerLayout(),occupied=Array.from({length:40},(_,id)=>person(id,{space:'train',car:0,destination:5,state:'riding',wantsBoard:false})),a=person(100);
 choosePlatformDoors([...occupied,a],l,{station:0});assert.notEqual(l.door(a.doorId).car,0);
});
test('exit choice uses nearby doors across the same car',()=>{
 const l=normalPassengerLayout(),agents=Array.from({length:8},(_,id)=>person(id,{space:'train',car:0,destination:0,z:[-94,-93,-90,-89,-86,-85,-81,-80][id],walkSpeed:id%2?.65:1.2}));
 chooseExitDoors(agents,l,0);assert.equal(new Set(agents.map(a=>a.doorId)).size,4);assert.ok(agents.every(a=>l.door(a.doorId).car===0));
});
test('standing anchors do not block entrances or bench approaches',()=>{
 const l=normalPassengerLayout(),c=l.cars[0],d=l.doors[0];assert.equal(standingPlaceKeepsDoorsClear({x:c.aisleX-.71,z:d.z},l,c.id),false);
 assert.equal(standingPlaceKeepsDoorsClear(c.seatAnchors[0].approach,l,c.id),false);assert.ok(c.standingZones.some(p=>standingPlaceKeepsDoorsClear(p,l,c.id)));
});
test('exhausted standing slots fall back to a real free seat rather than an occupied vestibule',()=>{
 const base=createTestPassengerLayout({carCount:4}),l=createPassengerLayout({...base,cars:base.cars.map(c=>({...c,standingZones:[]}))}),c=new PassengerBoardingController(l,{normal:true}),d=l.doors[0];
 const a=person(1,{doorId:d.id,car:0,space:'train',state:'boarding',x:d.insideX,z:d.z,path:[],boardingCounted:true});c.afterMove(a,{station:0,dist:0},[a]);assert.ok(a.seat);assert.equal(a.state,'settling');
});
test('normal alighters can cross the portal boundary and finish both completion signals',()=>{
 const s=new PassengerSimulation({seed:717,normal:true,layout:normalPassengerLayout(),platformCount:0,onboardCount:1}),open={station:0,dist:0,speed:0,doorsOpen:true,aperture:1};
 for(let n=0;n<20*30&&!s.boarding.passengerExchangeComplete;n++)s.update(1/30,open);
 assert.equal(s.events.filter(e=>e.kind==='alight').length,1);assert.equal(s.boarding.passengerExchangeComplete,true);assert.equal(s.boarding.doorsSafeToClose,true);
});

test('the next boarder cannot claim a bay still needed by the active boarder',()=>{
 const l=normalPassengerLayout(),c=new PassengerBoardingController(l,{normal:true}),q=c.queues[0];
 const a=person(100,{state:'boarding',x:q.thresholdX-.54,z:q.z,path:[{x:q.approachX,z:q.z},{x:q.entryX,z:q.z}]}),b=person(101,{state:'queued',z:q.z-1.28,queueSide:-1,doorReady:true,path:[]});
 q.active=a.id;q.enter=[a.id,b.id];q.exit=[];const people=new Map([[a.id,a],[b.id,b]]);
 c.advanceQueue(q,people,0);assert.equal(b.doorReady,false);assert.notEqual(b.queuePoint.z,q.z);
 a.path.shift();c.advanceQueue(q,people,0);assert.equal(b.doorReady,true);assert.equal(b.queuePoint.z,q.z);
});
