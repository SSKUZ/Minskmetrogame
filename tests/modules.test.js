import assert from 'node:assert/strict';
import {test} from 'node:test';
import {clampView,chooseCamera} from '../js/core/CameraManager.js';
import {animateDoorLeaves,animateCarriageDoors,canOpenDoors} from '../js/train/TrainDoors.js';
import {nearestDoor,smoothProgress,facingDirection,shortestTurn} from '../js/passengers/PassengerMotion.js';
import {gameSnapshot} from '../js/core/GameState.js';
test('camera clamps and selects modes',()=>{assert.equal(clampView(0,1),.35);assert.equal(clampView(0,-1),-.35);assert.equal(chooseCamera({cab:1,platform:2,carriage:3},'cab'),1)});
test('doors open and close',()=>{
 const advance=(animate,leaves,open,seconds,dt)=>{
  for(let t=0;t<seconds-1e-9;t+=dt)animate(leaves,open,Math.min(dt,seconds-t));
 };
 const near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<1e-10,`${actual} != ${expected}`);
 for(const dt of [1/30,1/60]){
  const d={leaf:{position:{z:0}},doorZ:10,half:1};
  const c={leaf:{position:{z:0}},leafZ:3,half:-1};
  animateDoorLeaves([d],false,0);
  animateCarriageDoors([c],false,0);
  near(d.leaf.position.z,10.53);
  near(c.leaf.position.z,3);
  // With no elapsed time the leaves must stay closed, not teleport open.
  animateDoorLeaves([d],true);
  animateCarriageDoors([c],true);
  near(d.leaf.position.z,10.53);
  near(c.leaf.position.z,3);
  // Opening lasts 1.55 seconds; halfway through, both leaves are in transit.
  advance(animateDoorLeaves,[d],true,.775,dt);
  advance(animateCarriageDoors,[c],true,.775,dt);
  near(d.leaf.position.z,11.045);
  near(c.leaf.position.z,2.54);
  advance(animateDoorLeaves,[d],true,.775,dt);
  advance(animateCarriageDoors,[c],true,.775,dt);
  near(d.leaf.position.z,11.56);
  near(c.leaf.position.z,2.08);
  advance(animateDoorLeaves,[d],false,1.55,dt);
  advance(animateCarriageDoors,[c],false,1.55,dt);
  near(d.leaf.position.z,10.53);
  near(c.leaf.position.z,3);
 }
 assert.equal(canOpenDoors(0,0),true);
 assert.equal(canOpenDoors(3,0),false);
});
test('passenger movement',()=>{assert.equal(nearestDoor(-3,[-10,0,10]),0);assert.equal(smoothProgress(-1,4),0);assert.equal(smoothProgress(6,4),1);assert.ok(Math.abs(facingDirection(0,-1))<1e-12);assert.ok(Math.abs(shortestTurn(3,-3))<1)});
test('game state snapshot',()=>{const s=gameSnapshot({speed:0,doors:true,dist:0,index:0,playing:true,camera:'cab'});assert.equal(s.train.doorsOpen,true);assert.equal(s.station.stopped,true);assert.ok(Object.isFrozen(s.train))});
