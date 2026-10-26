import test from 'node:test';
import assert from 'node:assert/strict';
import {stepTrainMotion} from '../js/train/TrainPhysics.js';
const simulate=(speed,lever,seconds)=>{let v=speed;for(let t=0;t<seconds;t+=.05)v=stepTrainMotion(v,lever,.05);return v};
test('neutral cannot accelerate a train',()=>assert.ok(stepTrainMotion(50,0,.05)<50));
test('traction accelerates slowly from rest',()=>{const v=simulate(0,1,10);assert.ok(v>15&&v<25)});
test('full braking takes meaningful time',()=>{const v=simulate(60,-1,10);assert.ok(v>15&&v<25)});
test('neutral coasts for at least one minute at useful speed',()=>assert.ok(simulate(60,0,60)>55));
test('braking reduces speed without reversing',()=>assert.equal(stepTrainMotion(.01,-1,.05),0));
test('speed stays within bounds',()=>assert.ok(stepTrainMotion(90,1,.05)<=90));
test('half controller targets approximately 60 km/h',()=>assert.ok(Math.abs(simulate(0,.5,300)-60)<.1));

test('85% lever reaches 90 km/h',()=>assert.ok(simulate(0,.85,120)>89.9));
test('full traction reaches 90 km/h',()=>assert.equal(simulate(0,1,120),90));

test('braking is 30 percent stronger than prior tune',()=>{const dt=.05,v=60;const actual=(v-stepTrainMotion(v,-1,dt))/dt;assert.ok(Math.abs(actual-3.05*1.3)<1e-9)});
