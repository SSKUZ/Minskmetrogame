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
 assert.match(main,/const instrumentDeck=new THREE\.Group\(\)/);
});

test('inspection page loads the real game cab and exposes bounded camera API',()=>{
 const html=readFileSync(new URL('../preview/cab-editor.html',import.meta.url),'utf8');
 assert.match(html,/cabInspector=1/);
 assert.match(html,/metroCabInspector/);
 assert.match(main,/window\.metroCabInspector=cabInspect/);
 assert.match(main,/setView\(y,p\)/);
 assert.match(main,/setZoom\(fov\)/);
});
