import test from 'node:test';
import assert from 'node:assert/strict';
import {stepTrainMotion} from '../js/train/TrainPhysics.js';
const simulate=(speed,lever,seconds)=>{
  let v=speed;
  for(let t=0;t<seconds-1e-9;t+=.05)v=stepTrainMotion(v,lever,Math.min(.05,seconds-t));
  return v;
};
test('full traction accelerates twice as fast as previous tune',()=>{
  assert.ok(Math.abs(simulate(0,1,10)-45)<.001);
  assert.equal(simulate(0,1,20),90);
});
test('full brake stops 90 km/h in about 10 seconds',()=>{
  assert.ok(simulate(90,-1,9.5)>0);
  assert.ok(simulate(90,-1,10)<.001);
});
test('full brake stops 60 km/h proportionally in about 6.67 seconds',()=>{
  assert.ok(simulate(60,-1,6.5)>0);
  assert.ok(simulate(60,-1,6.7)<.001);
});
test('partial brake is weaker than full brake',()=>assert.ok(simulate(60,-.5,5)>simulate(60,-1,5)));
test('neutral coasts for at least one minute',()=>assert.ok(simulate(60,0,60)>55));
test('speed remains within 0..90',()=>{
  assert.equal(stepTrainMotion(90,1,.05),90);
  assert.equal(stepTrainMotion(.01,-1,.05),0);
});
test('half traction selects 60 km/h',()=>assert.ok(Math.abs(simulate(0,.5,120)-60)<.001));
test('85% traction reaches 90 km/h',()=>assert.ok(simulate(0,.85,60)>89.9));
