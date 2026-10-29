import assert from 'node:assert/strict';
import {test} from 'node:test';
import {PassengerBoardingController} from '../js/passengers/PassengerBoardingController.js';
import {createPassenger} from '../js/passengers/PassengerSpawner.js';
import {createTestPassengerLayout} from '../js/passengers/PassengerLayout.js';
import {randomSource} from '../js/passengers/PassengerConfig.js';

const layout=createTestPassengerLayout({carCount:4}),door=layout.doors[0];
const context={station:0,dist:0,speed:0,doorsOpen:true,aperture:1};
const person=(id,props={})=>Object.assign(createPassenger(id,randomSource(id+1),0),{car:0,doorId:door.id,x:door.queueX,z:door.z,wantsBoard:true,destination:2,groupId:null,parentId:null,path:[],state:'waiting'},props);

test('empty leaf zones are safe while scheduled alighters still make exchange incomplete',()=>{
 const a=person(1,{space:'train',x:layout.car(0).aisleX,z:door.z-3,state:'riding',destination:0});
 const c=new PassengerBoardingController(layout);c.prepare([a],0,0);c.updateCompletion([a],context);
 assert.equal(c.doorsSafeToClose,true);assert.equal(c.passengerExchangeComplete,false);
});

test('exchange completes once boarders clear the doorway, without waiting for their seats',()=>{
 const a=person(1),c=new PassengerBoardingController(layout,{normal:true});c.prepare([a],0,0);
 a.state='boarding';a.space='train';a.x=door.thresholdX+.70;a.path=[{x:door.insideX,z:door.z}];a.boardingCounted=true;
 c.afterMove(a,context,[a]);c.updateCompletion([a],context);
 assert.equal(a.state,'settling');assert.ok(a.path.length,'rider is still walking to a place');
 assert.equal(c.passengerExchangeComplete,true);assert.equal(c.doorsSafeToClose,true);
});

test('an alighter outside the threshold still prevents closing until its body clears',()=>{
 const a=person(1,{space:'train',state:'riding',destination:0,x:layout.car(0).aisleX});
 const c=new PassengerBoardingController(layout);c.prepare([a],0,0);
 a.space='platform';a.state='alighting';a.x=door.thresholdX-.35;a.path=[];
 c.updateCompletion([a],context);assert.equal(c.doorsSafeToClose,false);assert.equal(c.passengerExchangeComplete,false);
 a.x=door.thresholdX-.80;c.afterMove(a,context,[a]);c.updateCompletion([a],context);
 assert.equal(a.state,'leaving');assert.equal(c.doorsSafeToClose,true);assert.equal(c.passengerExchangeComplete,true);
});

test('even an unscheduled body in a leaf zone blocks a previously finished exchange',()=>{
 const c=new PassengerBoardingController(layout);c.prepare([],0,0);c.updateCompletion([],context);
 assert.equal(c.passengerExchangeComplete,true);
 const a=person(99,{wantsBoard:false,x:door.thresholdX-.25,z:door.z+1.4});
 c.updateCompletion([a],context);assert.equal(c.doorsSafeToClose,false);assert.equal(c.passengerExchangeComplete,false);
});

test('explicit end-of-boarding leaves unstarted passengers waiting and is idempotent',()=>{
 const a=person(1),c=new PassengerBoardingController(layout,{normal:true});c.prepare([a],0,0);
 assert.equal(c.requestFinishBoarding([a]),true);const path=a.path;
 c.requestFinishBoarding([a]);assert.equal(a.path,path);assert.equal(c.missed.size,1);
 assert.equal(a.state,'waitingNextTrain');assert.equal(a.wantsBoard,false);
 c.updateCompletion([a],context);assert.equal(c.passengerExchangeComplete,true);assert.equal(c.doorsSafeToClose,true);
 c.reset();assert.equal(c.passengerExchangeComplete,false);assert.equal(c.missed.size,0);
});

test('ending boarding does not leave a child behind a parent already crossing',()=>{
 const parent=person(12,{groupId:12}),child=person(18,{groupId:12,parentId:12,child:true,radius:.18,z:door.z+.5});
 const c=new PassengerBoardingController(layout,{normal:true});c.prepare([parent,child],0,0);
 parent.state='boarding';parent.space='train';parent.x=door.thresholdX+.1;
 c.requestFinishBoarding([parent,child]);assert.equal(c.missed.size,0);assert.equal(child.wantsBoard,true);
 c.updateCompletion([parent,child],context);assert.equal(c.passengerExchangeComplete,false);assert.equal(c.doorsSafeToClose,false);
});
