import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

// A deliberately unavailable WebGL module: DOM controls already exist, but the
// module may finish long after the user presses Start on a slow connection.
function startup({missingHud=false}={}){
 const timers=new Map(),frames=new Map(),nodes=new Map();let time=0,id=0,sceneContexts=0;
 class Element extends EventTarget{
  constructor(){super();this.style={};this.attributes={};this.classes=new Set();this.classList={add:n=>this.classes.add(n),remove:n=>this.classes.delete(n),toggle:(n,on)=>on?this.classes.add(n):this.classes.delete(n)};}
  setAttribute(k,v){this.attributes[k]=v;}
  setPointerCapture(){} hasPointerCapture(){return true;}
  getBoundingClientRect(){return {top:0,height:200};}
  after(el){nodes.set(el.id,el);}
  remove(){nodes.delete(this.id);}
  getContext(){return new Proxy({},{get:()=>()=>{}});}
 }
 for(const name of ['scene',...(missingHud?[]:['status','masterTrack','masterHandle','masterValue','screenDoorToggle','speed','station','people'])]){const el=new Element();el.id=name;nodes.set(name,el);}
 nodes.get('scene').getContext=()=>{sceneContexts++;throw new Error('The WebGL canvas must never be claimed by fallback');};
 const window=new EventTarget(),document={getElementById:k=>nodes.get(k)??null,body:new Element(),createElement:()=>new Element()};
 runInNewContext(readFileSync(new URL('../js/fallback.js',import.meta.url),'utf8'),{
  window,document,performance:{now:()=>time},innerWidth:412,innerHeight:915,
  setTimeout:(fn,ms)=>{timers.set(++id,{fn,at:time+ms});return id;},clearTimeout:i=>timers.delete(i),
  requestAnimationFrame:fn=>{frames.set(++id,fn);return id;},cancelAnimationFrame:i=>frames.delete(i)
 });
 const emit=name=>window.dispatchEvent(new Event(name));
 return {window,document,nodes,frames,emit,sceneContexts:()=>sceneContexts,
  advance(ms){time+=ms;for(const [i,t] of [...timers])if(t.at<=time){timers.delete(i);t.fn();}},
  frame(){time+=16;for(const [i,fn] of [...frames]){frames.delete(i);fn(time);}}
 };
}
test('early Start permits a slow 3D download without touching its canvas',()=>{
 const s=startup();s.window.metroStarted=true;s.emit('metro-start');s.advance(1000);s.advance(5000);
 assert.equal(s.nodes.has('fallbackScene'),false);assert.equal(s.sceneContexts(),0);
 s.window.metro3DReady=true;s.emit('metro-3d-ready');s.advance(10000);
 assert.equal(s.nodes.has('fallbackScene'),false);assert.equal(s.frames.size,0);
});
test('unavailable 3D uses a separate canvas and the current door button',()=>{
 const s=startup();s.window.metroStarted=true;s.advance(10000);s.frame();
 assert.ok(s.nodes.has('fallbackScene'));assert.equal(s.sceneContexts(),0);
 s.nodes.get('screenDoorToggle').dispatchEvent(new Event('click'));
 assert.equal(s.nodes.get('status').textContent,'До платформы ещё далеко');
 s.window.metro3DReady=true;s.emit('metro-3d-ready');
 assert.equal(s.nodes.has('fallbackScene'),false);assert.equal(s.frames.size,0);
 s.nodes.get('status').textContent='3D управляет поездом';s.nodes.get('screenDoorToggle').dispatchEvent(new Event('click'));
 assert.equal(s.nodes.get('status').textContent,'3D управляет поездом');
});
test('timeout before Start waits for the user; missing optional HUD is safe',()=>{
 const s=startup({missingHud:true});s.advance(10000);assert.equal(s.frames.size,0);
 s.window.metroStarted=true;s.emit('metro-start');s.frame();assert.ok(s.nodes.has('fallbackScene'));
 s.window.metro3DReady=true;s.emit('metro-3d-ready');assert.equal(s.frames.size,0);
});
