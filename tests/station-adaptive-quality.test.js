import test from 'node:test';
import assert from 'node:assert/strict';
import {createAdaptiveQuality} from '../js/station-base/AdaptiveQuality.js';
import {resolveGraphicsPreset} from '../js/station-base/GraphicsPresets.js';

test('mobile presets keep high fidelity available and low conservative',()=>{
 const low=resolveGraphicsPreset('low',{});
 const high=resolveGraphicsPreset('high',{});
 assert.ok(low.dpr<high.dpr);
 assert.ok(low.proxyEnter<high.proxyEnter);
 assert.equal(low.antialias,false);
 assert.ok(low.mediumExit<low.mediumEnter);
 assert.ok(high.mediumExit<high.mediumEnter);
});

test('adaptive controller reduces DPR under sustained low FPS and never goes below minimum',()=>{
 const q=createAdaptiveQuality({baseDpr:1,minDpr:.6,targetFps:30,windowMs:1000,cooldownMs:0});
 for(let cycle=0;cycle<10;cycle++){
  const start=cycle*2000;
  q.sample(start,{frameMs:100});
  const result=q.sample(start+1000,{frameMs:100});
  assert.ok(result.dpr>=.6);
 }
 assert.equal(q.dpr,.6);
});

test('adaptive controller ignores idle periods and restores gradually on sustained high FPS',()=>{
 const q=createAdaptiveQuality({baseDpr:.8,minDpr:.6,maxDpr:1,targetFps:30,windowMs:1000,cooldownMs:0});
 q.sample(0,{frameMs:100});
 q.sample(1000,{frameMs:100});
 const low=q.dpr;
 q.sample(2000,{active:false});
 q.sample(3000,{frameMs:16});
 const result=q.sample(4000,{frameMs:16});
 assert.ok(result.dpr>=low);
 assert.ok(result.dpr<=1);
});
