import test from 'node:test';
import assert from 'node:assert/strict';
import {stepTrainMotion} from '../js/train/TrainPhysics.js';
test('neutral cannot accelerate a train',()=>assert.ok(stepTrainMotion(50,0,.05)<50));
test('traction accelerates from rest',()=>assert.ok(stepTrainMotion(0,1,.05)>0));
test('braking reduces speed without reversing',()=>assert.equal(stepTrainMotion(.01,-1,.05),0));
test('speed stays within bounds',()=>assert.ok(stepTrainMotion(90,1,.05)<=90));
test('half controller targets approximately 60 km/h',()=>{let v=0;for(let i=0;i<4000;i++)v=stepTrainMotion(v,.5,.05);assert.ok(Math.abs(v-60)<.1)});
