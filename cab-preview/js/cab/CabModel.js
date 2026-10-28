import {createCabMaterials} from './CabMaterials.js?v=cab-r2';
import {createCabGeometry} from './CabGeometry.js?v=cab-r2';
import {buildCabShell} from './CabShell.js?v=cab-r2';
import {buildCabDesk} from './CabDesk.js?v=cab-r2';
import {buildCabEquipment} from './CabEquipment.js?v=cab-r2';
import {createCabControls} from './CabControls.js?v=cab-r2';
import {createCabInstruments} from './CabInstruments.js?v=cab-r2';
import {batchCabStatic} from './CabBatching.js?v=cab-r2';
import {applyCabEnvironment} from './CabLighting.js?v=cab-r2';

export function createCabModel(THREE,renderer){
 const root=new THREE.Group();root.name='Cab81_717_R1';
 // The game's legacy rolling-stock/world units are 1.65 per metre.
 root.scale.setScalar(1.65);root.position.set(0,.65,.35);
 const materials=createCabMaterials(THREE),kit=createCabGeometry(THREE,materials);
 const environment=applyCabEnvironment(THREE,renderer,materials);
 const controls=createCabControls(kit),instruments=createCabInstruments(kit);
 buildCabShell(kit,root);
 const desk=buildCabDesk(kit,root,controls,instruments),equipment=buildCabEquipment(kit,root,controls);
 const lamp=new THREE.SpotLight(0xffedd0,19,5.4,Math.PI*.32,.7,2);lamp.position.set(-.62,2.04,1.91);lamp.target.position.set(.18,.98,1.25);root.add(lamp,lamp.target);
 lamp.castShadow=true;lamp.shadow.mapSize.set(1024,1024);lamp.shadow.camera.near=.2;lamp.shadow.camera.far=5.4;lamp.shadow.bias=-.00002;lamp.shadow.normalBias=.006;
 lamp.shadow.autoUpdate=false;lamp.shadow.needsUpdate=true;
 const fill=new THREE.PointLight(0xcbdbe0,1.8,3.8,2);fill.position.set(.93,1.82,1.95);root.add(fill);
 const rearMirrors=[];
 for(const side of [-1,1]){
  const g=new THREE.Group();g.position.set(side*1.268,1.68,.73);g.rotation.y=-side*.56;root.add(g);
  kit.rounded(g,.075,.274,.016,0,0,0,materials.rubber,.008);
  const target=new THREE.WebGLRenderTarget(192,336,{depthBuffer:true,stencilBuffer:false});target.texture.colorSpace=THREE.SRGBColorSpace;
  const face=new THREE.Mesh(new THREE.PlaneGeometry(.062,.253),new THREE.MeshBasicMaterial({map:target.texture}));face.userData.cabDynamic=true;face.position.z=.012;g.add(face);
  const mirrorCamera=new THREE.PerspectiveCamera(53,.59/1.19,.35,210);
  rearMirrors.push({side,target,mirrorCamera,face,enabled:true});
 }
 equipment.video.material.map=rearMirrors[1].target.texture;equipment.video.material.color.setHex(0xffffff);equipment.video.material.needsUpdate=true;
 const batching=batchCabStatic(THREE,root);
 root.traverse(o=>{if(o.isMesh){o.castShadow=!o.material?.transparent;o.receiveShadow=!o.material?.transparent;}});
 let clock=0,lastShadowPose='';
 function update(dt,state){
  clock+=Math.min(dt,.1);controls.update(dt,state);desk.speed.update(state.speed,state.lampTest);
  desk.indicators.forEach((l,i)=>l.set(state.lampTest||(i===0&&state.lever>0)||(i===2&&state.lever<0)||(i===4&&Math.abs(state.lever)<.02)));
  desk.doorLamps.forEach((l,i)=>l.set(state.lampTest||[state.doors,state.doorsMoving,state.doorsClosed,state.lastAction?.id==='open'&&state.lastAction?.ok===false][i]));
  controls.controls.get('info').target=state.info?1:0;
  controls.controls.get('open').target=state.doors?1:0;controls.controls.get('close').target=state.doors?0:1;
  for(const [id,value] of Object.entries(state.switches??{})){const c=controls.controls.get(id);if(c)c.value=value;}
  lamp.intensity=state.switches?.cabLight===0?0:19;fill.intensity=state.switches?.cabLight===0?0:1.8;
  equipment.wipers.forEach((o,i)=>{o.rotation.z=state.switches?.[i===0?'wiperLeft':'wiperRight']?(Math.sin(clock*2.6)*.45+.45)*(i===0?1:-1):0;});
  const pose=[controls.controls.get('master').handle.position.y,controls.controls.get('brake').handle.rotation.y,...equipment.wipers.map(o=>o.rotation.z)].map(n=>Math.round(n*100)).join(',');
  if(pose!==lastShadowPose){lamp.shadow.needsUpdate=true;lastShadowPose=pose;}
 }
 function landmarks(camera){
  root.updateMatrixWorld(true);camera.updateMatrixWorld(true);
  const points={speed:[desk.speed.group,0,0,0],doors:[desk.upper,-.414+.221,0,.05],voltage:[desk.gauges[0],0,0,0],current:[desk.gauges[1],0,0,0],radioSpeaker:[equipment.radio,.029,.175,.048],cctv:[equipment.cctv,0,.085,.042]};
  for(const [name,id] of Object.entries({lighting:'cabLight',wiper:'wiperLeft',check:'lampTest',doorOpen:'open',controller:'master',brakeValve:'brake',brakeRelease:'release',emergency:'emergency'}))points[name]=[controls.controls.get(id).hit,0,0,0];
  return Object.fromEntries(Object.entries(points).map(([name,[o,x,y,z]])=>{const p=o.localToWorld(new THREE.Vector3(x,y,z)).project(camera);return [name,{u:(p.x+1)/2,v:(1-p.y)/2}];}));
 }
 return {root,kit,materials,controls:controls.controls,desk,equipment,rearMirrors,update,batching,environment,landmarks,version:'cab-r2'};
}
