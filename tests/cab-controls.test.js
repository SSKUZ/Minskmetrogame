import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const main=readFileSync(new URL('../js/main.js',import.meta.url),'utf8');
const controls=readFileSync(new URL('../js/cab/CabControls3D.js',import.meta.url),'utf8');
test('cab 3D button factory is imported and used by the game',()=>{
 assert.match(main,/import \{createCabDeskButtonFactory\} from '\.\/cab\/CabControls3D\.js'/);
 assert.match(main,/const deskButton=createCabDeskButtonFactory\(\{THREE,instrumentDeck,cabMetal,cabHitTargets\}\)/);
});
test('all existing cab control actions remain bound to 3D hit targets',()=>{
 for(const [label,action] of [['Info','info'],['ОТКР','open'],['ЗАКР','close']]){
  assert.ok(main.includes("'"+label+"'")&&main.includes("'"+action+"'"),label+' action must remain');
 }
 assert.match(controls,/cabHitTargets\.push\(\{mesh:cap,type\},\{mesh:face,type\}\)/);
 assert.match(main,/animateButtons\(cabButtons,dt\)/);
});
test('cab shell and mirrors remain present',()=>{
 assert.match(main,/const cab=new THREE\.Group\(\)/);
 assert.match(main,/const rearMirrors=\[\]/);
 assert.match(main,/createCabInstrumentDeck\(\{THREE,cab,box,cabShell,cabEdge\}\)/);
});

test('inspection page loads the real game cab and exposes bounded camera API',()=>{
 const html=readFileSync(new URL('../preview/cab-editor.html',import.meta.url),'utf8');
 assert.match(html,/cabInspector=1/);
 assert.match(html,/metroCabInspector/);
 assert.match(main,/window\.metroCabInspector=cabInspect/);
 assert.match(main,/setView\(y,p\)/);
 assert.match(main,/setZoom\(fov\)/);
});

test('instrument deck factory retains original measurements and screen creation',()=>{
 const deck=readFileSync(new URL('../js/cab/CabInstrumentDeck.js',import.meta.url),'utf8');
 assert.match(deck,/instrumentDeck\.position\.set\(0,1\.79,3\.24\)/);
 assert.match(deck,/instrumentDeck\.rotation\.x=\.39/);
 assert.match(deck,/box\(instrumentDeck,6\.0,\.13,1\.32,0,0,0,cabShell\)/);
 assert.match(deck,/return \{instrumentDeck,cabScreen\}/);
 for(const name of ['leftCabScreen','midCabScreen','rightCabScreen'])assert.ok(main.includes(name));
});

test('original front and rear cab shell geometry is modular',()=>{
 const shell=readFileSync(new URL('../js/cab/CabShell.js',import.meta.url),'utf8');
 assert.match(main,/buildCabFrontShell\(\{cab,box,cabShell,cabEdge,cabRubber\}\)/);
 assert.match(main,/buildCabRearShell\(\{cab,box,mat,sideInterior,windowFrame,cabMetal\}\)/);
 assert.match(shell,/box\(cab,6\.8,\.25,2\.3,0,1\.37,3\.55,cabShell\)/);
 assert.match(shell,/box\(cab,8\.25,\.23,9\.8,0,\.53,4\.5,floorRubber\)/);
});

test('non-interactive cab desk details do not replace original controls',()=>{
 const details=readFileSync(new URL('../js/cab/CabDeskDetails.js',import.meta.url),'utf8');
 assert.match(main,/detailCabInstrumentDeck\(\{THREE,instrumentDeck,cabMetal,cabRubber\}\)/);
 assert.match(details,/CabDeskSurfaceDetails/);
 assert.match(details,/for\(let i=0;i<8;i\+\+\)/);
 assert.match(main,/const cabHitTargets=\[\]/);
});
