import assert from 'node:assert/strict';
import {test} from 'node:test';
import {clampView,chooseCamera} from '../js/core/CameraManager.js';
import {animateDoorLeaves,animateCarriageDoors,canOpenDoors} from '../js/train/TrainDoors.js';
import {nearestDoor,smoothProgress,facingDirection,shortestTurn} from '../js/passengers/PassengerMotion.js';
import {gameSnapshot} from '../js/core/GameState.js';
test('camera clamps and selects modes',()=>{assert.equal(clampView(0,1),.35);assert.equal(clampView(0,-1),-.35);assert.equal(chooseCamera({cab:1,platform:2,carriage:3},'cab'),1)});
test('doors open and close progressively in 1.55 seconds',()=>{
 const d={leaf:{position:{z:0}},doorZ:10,half:1},c={leaf:{position:{z:0}},leafZ:3,half:-1};
 animateDoorLeaves([d],false,1/60);assert.equal(d.leaf.position.z,10.53);
 animateDoorLeaves([d],true,1/60);assert.ok(d.leaf.position.z>10.53&&d.leaf.position.z<10.54);
 for(let i=1;i<94;i++){animateDoorLeaves([d],true,1/60);animateCarriageDoors([c],true,1/60);}
 assert.ok(Math.abs(d.leaf.position.z-11.56)<1e-9);assert.ok(Math.abs(c.leaf.position.z-2.08)<1e-9);
 for(let i=0;i<94;i++)animateDoorLeaves([d],false,1/60);assert.equal(d.leaf.position.z,10.53);
 assert.equal(canOpenDoors(0,0),true);assert.equal(canOpenDoors(3,0),false);
});
test('passenger movement',()=>{assert.equal(nearestDoor(-3,[-10,0,10]),0);assert.equal(smoothProgress(-1,4),0);assert.equal(smoothProgress(6,4),1);assert.ok(Math.abs(facingDirection(0,-1))<1e-12);assert.ok(Math.abs(shortestTurn(3,-3))<1)});
test('exterior doorway backing is hidden while leaves open and restored only when closed',()=>{
 const portalBacking={visible:true},leaves=[-1,1].map(half=>({leaf:{position:{z:10+half*.53}},doorZ:10,half,portalBacking}));
 animateDoorLeaves(leaves,false,0);assert.equal(portalBacking.visible,true);
 animateDoorLeaves(leaves,true,.1);assert.equal(portalBacking.visible,false);
 for(let i=0;i<16;i++)animateDoorLeaves(leaves,true,.1);
 assert.equal(portalBacking.visible,false);assert.ok(leaves.every(d=>Math.abs(d.leaf.position.z-10)>1.55));
 animateDoorLeaves(leaves,false,.1);assert.equal(portalBacking.visible,false,'no opaque panel behind partially closing leaves');
 for(let i=0;i<16;i++)animateDoorLeaves(leaves,false,.1);
 assert.equal(portalBacking.visible,true);assert.equal(leaves[0].leaf.position.z,9.47);
});
test('game state snapshot',()=>{const s=gameSnapshot({speed:0,doors:true,dist:0,index:0,playing:true,camera:'cab'});assert.equal(s.train.doorsOpen,true);assert.equal(s.station.stopped,true);assert.ok(Object.isFrozen(s.train))});
