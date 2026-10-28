import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {V106_FORMATION,V106_TRAIN_LENGTH,V106_CAR_PITCH,consistCarPose,consistDoorCommand,validateV106Consist,updateConsistPose,synchronizeConsistDoors} from '../js/train/ConsistIntegration.js';
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
 assert.deepEqual(p.map(x=>Number(x.z.toFixed(3))),[0,20.006,40.012,60.018]);
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

test('game loads actual v106 model on demand without replacing physics',()=>{
 const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
 const bridge=readFileSync(new URL('../js/train/ConsistViewerBridge.js',import.meta.url),'utf8');
 assert.match(html,/id="consistInspectFrame"/);
 assert.match(html,/ConsistViewerBridge\.js/);
 assert.match(bridge,/preview\/wagon\.html\?formation=train/);
 assert.match(bridge,/frame\.src='about:blank'/);
 assert.doesNotMatch(bridge,/stepTrainMotion|TrainPhysics/);
});

test('v106 viewer door leaves follow real game door control state',()=>{
 const bridge=readFileSync(new URL('../js/train/ConsistViewerBridge.js',import.meta.url),'utf8');
 assert.match(bridge,/getElementById\('screenDoorToggle'\)/);
 assert.match(bridge,/wagonSetDoors\(open,\{instant:true\}\)/);
 assert.match(bridge,/clearInterval\(syncTimer\)/);
});

test('station exterior is four cars with v106 centre spacing, not the old five-car layout',()=>{
 const main=readFileSync(new URL('../js/main.js',import.meta.url),'utf8');
 assert.match(main,/for\(let car=0;car<V106_FORMATION\.length;car\+\+\)/);
 assert.match(main,/const cz=12\+car\*V106_CAR_PITCH/);
 assert.doesNotMatch(main,/for\(let car=0;car<5;car\+\+\)/);
});

test('v106 car transforms follow the train position with original geometry scale',()=>{
 const cars=V106_FORMATION.map(type=>({
  type,leaves:Array(16).fill({}),
  root:{position:{set(x,y,z){this.x=x;this.y=y;this.z=z}},
   rotation:{y:0},scale:{setScalar(n){this.value=n}}}
 }));
 const consist={cars,root:{updateMatrixWorld(){this.updated=true}}};
 updateConsistPose(consist,{frontZ:-100,lateral:-.31,railY:2});
 assert.deepEqual(cars.map(c=>Number(c.root.position.z.toFixed(3))),[-100,-79.994,-59.988,-39.982]);
 assert.ok(cars.every(c=>c.root.position.x===-.31&&c.root.scale.value===1));
 assert.equal(cars[3].root.rotation.y,Math.PI);
 assert.equal(consist.root.updated,true);
 const calls=[];
 assert.equal(synchronizeConsistDoors(consist,true,(car,open)=>calls.push({car,open})),64);
 assert.equal(calls.length,4);
 assert.ok(calls.every(c=>c.open===true));
});

test('original v106 meshes are exported and rendered in gameplay scene',()=>{
 const viewer=readFileSync(new URL('../preview/wagon.html',import.meta.url),'utf8');
 const loader=readFileSync(new URL('../js/train/V106GeometryLoader.js',import.meta.url),'utf8');
 const main=readFileSync(new URL('../js/main.js',import.meta.url),'utf8');
 assert.match(viewer,/wagonExportConsist/);
 assert.match(viewer,/consist\.root\.toJSON\(\)/);
 assert.match(loader,/new THREE\.ObjectLoader\(\)\.parse\(serialized\)/);
 assert.match(loader,/scene\.add\(root\)/);
 assert.match(main,/ensureDetailedV106\(\)/);
 assert.match(main,/detailedV106Train\.visible=true/);
 assert.match(main,/stationTrain\.visible=false/);
});

test('imported v106 geometry preserves all original sliding door actuators',()=>{
 const viewer=readFileSync(new URL('../preview/wagon.html',import.meta.url),'utf8');
 const loader=readFileSync(new URL('../js/train/V106GeometryLoader.js',import.meta.url),'utf8');
 const main=readFileSync(new URL('../js/main.js',import.meta.url),'utf8');
 assert.match(viewer,/uuid:d\.leaf\.uuid/);
 assert.match(loader,/leaves\.length!==64/);
 assert.match(loader,/root\.userData\.doorActuators=leaves/);
 assert.match(main,/animateDetailedV106Doors\(elapsed\)/);
 assert.match(main,/d\.object\.position\.z=d\.homeZ\+d\.half\*d\.travel\*t/);
});
