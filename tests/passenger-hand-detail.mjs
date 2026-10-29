import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser} from './helpers/cab-browser-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-hand-detail';
await mkdir(output,{recursive:true});const f=await launchCabBrowser();
try{
 const p=await f.page({viewport:{width:640,height:640}});
 await p.goto(f.base+'/tests/fixtures/passenger-assets.html');
 await p.waitForFunction(()=>window.assetsReady,null,{timeout:120000});
 const report=await p.evaluate(()=>{
  const {THREE,models,scene,camera,renderer,PassengerAnimator}=window.passengerAssets;
  renderer.setSize(640,640);
  const a={id:10,profile:10,tint:0,scale:1,width:1,phase:1,state:'riding',space:'train',activity:'rail',velocity:0,distance:0,accessory:null};
  const view=models.create(a,'medium');scene.add(view.root);
  const points=Array.from({length:65},(_,n)=>new THREE.Vector3(.44,.5+n*.025,.24));
  const pole=new THREE.Mesh(new THREE.CylinderGeometry(.017,.017,1.6,16),new THREE.MeshStandardMaterial({color:0x7e858b,metalness:.5,roughness:.3}));
  pole.position.set(.44,1.3,.24);scene.add(pole);
  const animator=new PassengerAnimator(view,a,{rails:[{id:'detail-rail',radius:.017,points}]});
  for(let n=0;n<60;n++)animator.update(1/60,n/60);
  const grip=animator.grip;if(!grip)throw new Error('missing grip');
  camera.left=-.22;camera.right=.22;camera.top=.22;camera.bottom=-.22;camera.near=.01;camera.updateProjectionMatrix();
  const target=grip.point;camera.position.copy(target).add(new THREE.Vector3(.65,.18,.85));camera.lookAt(target);renderer.render(scene,camera);
  window.detail={view,a,animator,target};
  return {side:grip.side,error:grip.error,materials:animator.handGrip.materials.map(m=>({name:m.material.name,uniforms:animator.handGrip.uniforms.map(u=>({index:u.gripIndex.value,active:u.gripActive.value}))})),errors:models.errors};
 });
 assert.ok(report.error<.005);assert.ok(report.materials.length,'skin deformation must be installed');
 await p.screenshot({path:output+'/grip-front.png'});
 await p.evaluate(()=>{const {scene,camera,renderer,THREE}=window.passengerAssets;camera.position.copy(window.detail.target).add(new THREE.Vector3(-.85,.12,.65));camera.lookAt(window.detail.target);renderer.render(scene,camera);});
 await p.screenshot({path:output+'/grip-side.png'});
 assert.deepEqual(f.errors,[]);assert.deepEqual(f.requests,[]);report.passed=true;
 await writeFile(output+'/browser-report.json',JSON.stringify(report,null,2)+'\n');
}finally{await f.close();}
