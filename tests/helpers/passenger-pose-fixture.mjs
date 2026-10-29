import {readFileSync} from 'node:fs';
import * as THREE from '../../js/vendor/three.module.js';
import {GLTFLoader} from '../../js/vendor/addons/GLTFLoader.js';

// Load the exact shipped skeleton/animations without browser image decoding.
// Materials do not affect this measurement of pelvis and hand placement.
export async function poseAsset(file,height){
 globalThis.ProgressEvent??=class{constructor(type,info){Object.assign(this,info)}};
 const b=readFileSync(new URL('../../assets/passengers/'+file,import.meta.url)),length=b.readUInt32LE(12);
 const json=JSON.parse(b.subarray(20,20+length).toString());
 json.buffers[0].uri='data:application/octet-stream;base64,'+b.subarray(28+length).toString('base64');
 delete json.images;delete json.textures;
 json.materials=json.materials.map(m=>({name:m.name}));
 const source=await new GLTFLoader().parseAsync(JSON.stringify(json),'');
 const root=new THREE.Group(),model=source.scene,bones={},bounds=new THREE.Box3();root.add(model);
 model.traverse(o=>{if(o.isBone)bones[o.name]=o;if(o.isMesh){o.geometry.computeBoundingBox();bounds.union(o.geometry.boundingBox);}});
 const scale=height/(bounds.max.y-bounds.min.y);model.scale.setScalar(scale);
 return {root,model,bones,height,scale,animations:source.animations,props:{phone:new THREE.Object3D()}};
}

