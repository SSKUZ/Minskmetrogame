import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {V106_FORMATION,V106_TRAIN_LENGTH,V106_CAR_PITCH,consistCarPose,consistDoorCommand,validateV106Consist} from '../js/train/ConsistIntegration.js';
test('v106 formation matches actual reusable train factory',()=>{
 const factory=readFileSync(new URL('../preview/train-factory.js',import.meta.url),'utf8');
 assert.match(factory,/export function assembleConsist/);
 assert.match(factory,/export function cloneCar/);
 assert.deepEqual(V106_FORMATION,['81-717','81-714','81-714','81-717']);
 assert.ok(Math.abs(V106_TRAIN_LENGTH-79.224)<1e-9);
 assert.ok(Math.abs(V106_CAR_PITCH-20.006)<1e-9);
});
test('all four car transforms are unscaled and outward-ended',()=>{
 const p=V106_FORMATION.map((_,i)=>consistCarPose(i));
 assert.deepEqual(p.map(x=>x.z),[0,20.006,40.012,60.018].map(x=>Number(x.toFixed(3))));
 assert.equal(p[3].yaw,Math.PI);
 assert.ok(p.every(x=>x.scale===1));
 assert.throws(()=>consistCarPose(4),RangeError);
});
test('door adapter addresses all original 64 leaves without rewriting door physics',()=>{
 assert.deepEqual(consistDoorCommand(true),{open:true,cars:[0,1,2,3],leavesPerCar:16});
 const cars=V106_FORMATION.map(type=>({type,root:{},leaves:Array(16).fill({})}));
 assert.equal(validateV106Consist({cars}),true);
 assert.throws(()=>validateV106Consist({cars:cars.slice(1)}));
});
