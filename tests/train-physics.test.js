import test from 'node:test';
import assert from 'node:assert/strict';
import {stepTrainMotion} from '../js/train/TrainPhysics.js';
const simulate=(speed,lever,seconds,dt=.05)=>{
  let v=speed;
  for(let t=0;t<seconds-1e-9;t+=dt)v=stepTrainMotion(v,lever,Math.min(dt,seconds-t));
  return v;
};
test('full traction reaches 90 km/h in about 13 seconds',()=>{
  assert.ok(simulate(0,1,12.5)<90);
  assert.ok(Math.abs(simulate(0,1,13)-90)<.001);
});
test('full brake stops 90 km/h in about 8.33 seconds',()=>{
  assert.ok(simulate(90,-1,8.3)>0);
  assert.ok(simulate(90,-1,8.35)<.001);
});
test('full brake stops 60 km/h proportionally in about 5.56 seconds',()=>{
  assert.ok(simulate(60,-1,5.5)>0);
  assert.ok(simulate(60,-1,5.6)<.001);
});
test('partial brake is weaker than full brake',()=>assert.ok(simulate(60,-.5,5)>simulate(60,-1,5)));
test('neutral preserves the long coast from 60 km/h for one minute',()=>{
  // Analytical solution of dv/dt = -(0.045 + 0.000016*v*v):
  // 60 km/h becomes 54.1745 km/h after 60 s, not more than 55 km/h.
  // Allow 0.01 km/h for the numerical integration error at different frame rates.
  for(const dt of [.05,1/30,1/60]){
    const speed=simulate(60,0,60,dt);
    assert.ok(Math.abs(speed-54.1745)<.01,`neutral speed at dt=${dt}: ${speed}`);
  }
});
test('speed remains within 0..90',()=>{
  assert.equal(stepTrainMotion(90,1,.05),90);
  assert.equal(stepTrainMotion(.01,-1,.05),0);
});
test('half traction selects 60 km/h',()=>assert.ok(Math.abs(simulate(0,.5,120)-60)<.001));
test('85% traction reaches 90 km/h',()=>assert.ok(simulate(0,.85,60)>89.9));
