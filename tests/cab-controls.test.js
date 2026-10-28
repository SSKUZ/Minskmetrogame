import test from 'node:test';
import assert from 'node:assert/strict';
import {createCabCommands} from '../js/cab/CabCommands.js';
import {installCabInteraction} from '../js/cab/CabInteraction.js';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
function fixture(){
 const train={speed:0,lever:0,doors:false,info:false},calls=[];
 const adapter=createCabCommands({getTrain:()=>({...train}),setLever:v=>train.lever=v,
  setDoors:open=>{if(!open||train.speed<.5)train.doors=open;},info:()=>{train.info=true;},
  setHeadlights:v=>calls.push(['headlights',v]),setMirror:(s,v)=>calls.push(['mirror',s,v]),camera:id=>{calls.push(['camera',id]);return id!=='platform';},notify:m=>calls.push(['notice',m]),horn:v=>calls.push(['horn',v]),setVolume:v=>calls.push(['volume',v])});
 return {train,calls,...adapter};
}
test('controller and brake feed the same clamped train input',()=>{const a=fixture();a.command('master',.8);assert.equal(a.snapshot().lever,.8);a.command('brake',-5);assert.equal(a.snapshot().lever,-1);a.command('release');assert.equal(a.snapshot().lever,0);a.command('service');assert.equal(a.snapshot().lever,-.5);a.command('emergency');assert.equal(a.snapshot().lever,-1);});
test('3D and keyboard commands respect the existing door validator',()=>{const a=fixture();assert.equal(a.command('open').ok,true);a.command('close');a.train.speed=15;assert.equal(a.command('open').ok,false);assert.equal(a.snapshot().doors,false);a.train.speed=0;a.command('toggleDoors');assert.equal(a.snapshot().doors,true);});
test('instruments read actual train data without fictional electrical readings',()=>{const a=fixture();a.train.speed=43.7;assert.equal(a.snapshot().speed,43.7);for(const key of ['voltage','current','pressure'])assert.equal(key in a.snapshot(),false);a.command('info');assert.equal(a.snapshot().info,true);});
test('momentary horn and lamp check release; unsupported commands are explicit',()=>{const a=fixture();a.command('lampTest');assert.equal(a.snapshot().lampTest,true);a.command('lampTest',null,'release');assert.equal(a.snapshot().lampTest,false);a.command('horn');a.command('horn',null,'release');assert.deepEqual(a.calls.slice(-2),[['horn',true],['horn',false]]);assert.equal(a.command('reverse').reason,'unsupported');});
test('lights, mirrors and camera selectors report the real result',()=>{const a=fixture();a.command('headlights');assert.deepEqual(a.calls.at(-1),['headlights',false]);a.command('mirrorLeft');assert.deepEqual(a.calls.at(-1),['mirror',-1,false]);assert.equal(a.command('platform').ok,false);assert.equal(a.command('carriage').ok,true);});
test('held horn and lamp test release after leaving the cab',()=>{
 const saved={document:globalThis.document,window:globalThis.window},window=new EventTarget(),document=new EventTarget();
 document.createElement=()=>({setAttribute(){}});document.body={append(){}};
 const Empty=class{};const THREE={Raycaster:Empty,Vector2:Empty,Vector3:Empty,TorusGeometry:Empty,MeshBasicMaterial:Empty,Mesh:Empty};
 let inCab=true,running=true;const a=fixture();
 try{
  Object.assign(globalThis,{document,window});
  installCabInteraction({THREE,canvas:{},camera:{},cab:{add(){}},controls:new Map(),commands:a,isActive:()=>inCab,isRunning:()=>running});
  const key=(type,code)=>{const event=new Event(type,{cancelable:true});Object.defineProperty(event,'code',{value:code});window.dispatchEvent(event);};
  key('keydown','KeyH');key('keydown','KeyT');assert.equal(a.snapshot().hornActive,true);assert.equal(a.snapshot().lampTest,true);
  inCab=false;running=false;key('keyup','KeyH');key('keyup','KeyT');assert.equal(a.snapshot().hornActive,false);assert.equal(a.snapshot().lampTest,false);
 }finally{Object.assign(globalThis,saved);}
});
test('game physics source is byte-identical to the audited base',()=>{
 const source=readFileSync(new URL('../js/train/TrainPhysics.js',import.meta.url));
 assert.equal(createHash('sha256').update(source).digest('hex'),'affb7aafc4cb896073c89d965337b6c2cfd9307455ba9fdba9308a963b5da9ff');
});
