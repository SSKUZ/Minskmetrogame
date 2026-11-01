import fs from 'node:fs';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
// CAB_SOURCE_DIR: checkout of cab-development with existing Three.js dependency.
const sourceUrl=pathToFileURL(process.env.CAB_SOURCE_DIR.replace(/\/$/,'')+'/');
const require=createRequire(new URL('package.json',sourceUrl));
const THREE=await import(pathToFileURL(require.resolve('three')).href);
const {GLTFExporter}=await import(pathToFileURL(require.resolve('three/addons/exporters/GLTFExporter.js')).href);
const canvas=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/@napi-rs/canvas');
globalThis.document={createElement(type){if(type!=='canvas')throw Error(type);return canvas.createCanvas(1,1);}};
globalThis.ImageData=canvas.ImageData;
globalThis.FileReader=class {
 readAsArrayBuffer(blob){blob.arrayBuffer().then(r=>{this.result=r;this.onloadend?.();});}
 readAsDataURL(blob){blob.arrayBuffer().then(r=>{this.result='data:'+blob.type+';base64,'+Buffer.from(r).toString('base64');this.onloadend?.();});}
};
// Export adapter only: skip runtime GPU environment and optional static batching.
// The original assembly and geometry/material builders remain unchanged.
const original=fs.readFileSync(new URL('./js/cab/CabModel.js',sourceUrl),'utf8');
const adapted=original.replace("import {batchCabStatic} from './CabBatching.js?v=cab-r2';",'const batchCabStatic=()=>null;').replace("import {applyCabEnvironment} from './CabLighting.js?v=cab-r2';",'const applyCabEnvironment=()=>null;');
fs.writeFileSync(new URL('./js/cab/CabModel.export.js',sourceUrl),adapted);
const {createCabModel}=await import(new URL('./js/cab/CabModel.export.js',sourceUrl).href);
const model=createCabModel(THREE,null);
const root=model.root;root.name='Cab81_717_R2';root.scale.setScalar(1);root.position.set(0,0,0);
const removed=[];root.traverse(o=>{if(o.isLight||o.isCamera)removed.push(o);});
// Keep mirror and monitor meshes; replace GPU-only maps with static surfaces.
for(const face of [...model.rearMirrors.map(m=>m.face),model.equipment.video]){
 face.material=face.material.clone();face.material.map=null;
 face.material.color.setHex(face===model.equipment.video?0x172024:0x718084);
}
removed.forEach(o=>o.removeFromParent());
const movable=[];
for(const [id,c] of model.controls){
 const moving=c.handle??c.knob??c.cap;
 if(moving){moving.name='Moving_'+id;moving.userData.control=id;movable.push(moving.name);}
}
model.equipment.wipers.forEach((o,i)=>{o.name='Wiper_'+(i?'Right':'Left');movable.push(o.name);});
for(const gauge of model.desk.gauges){const pivot=gauge.children.find(o=>o.isGroup);if(pivot){pivot.name=gauge.name+'_Needle';movable.push(pivot.name);}}
model.desk.speed.group.name='SpeedDisplay';
root.updateMatrixWorld(true);
let meshes=0,instances=0;root.traverse(o=>{if(o.isMesh)meshes++;if(o.isInstancedMesh)instances+=o.count;});
// Godot 4.3 does not import EXT_mesh_gpu_instancing. Preserve every instance
// as an ordinary mesh sharing the exact original geometry and material.
const instanced=[];root.traverse(o=>{if(o.isInstancedMesh)instanced.push(o);});
for(const object of instanced){
 const group=new THREE.Group();group.name=object.name;group.position.copy(object.position);group.quaternion.copy(object.quaternion);group.scale.copy(object.scale);group.userData={...object.userData};
 for(let i=0;i<object.count;i++){
  const mesh=new THREE.Mesh(object.geometry,object.material);const matrix=new THREE.Matrix4();object.getMatrixAt(i,matrix);matrix.decompose(mesh.position,mesh.quaternion,mesh.scale);group.add(mesh);
 }
 object.parent.add(group);object.removeFromParent();
}
const result=await new GLTFExporter().parseAsync(root,{binary:true,onlyVisible:false,trs:true});
const output=process.argv[2];if(!output)throw Error('Provide output GLB path');
fs.mkdirSync(new URL('.', 'file://'+output),{recursive:true});fs.writeFileSync(output,Buffer.from(result));
fs.writeFileSync(output+'.export.json',JSON.stringify({version:model.version,three:THREE.REVISION,meshes,instances,movable,scale:root.scale.toArray(),position:root.position.toArray()},null,2));
console.log(JSON.stringify({bytes:result.byteLength,meshes,instances,movable:movable.length}));
