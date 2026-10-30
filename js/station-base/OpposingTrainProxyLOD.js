import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
// Lightweight distant substitute for the opposing train.
// Each carriage becomes a small number of meshes instead of thousands of details.
// Original geometry is retained and automatically restored near the camera.
export function createOpposingTrainProxyLOD(THREE,consist,{enterDistance=65,exitDistance=48}={}){
 const proxies=[];
 const bodyMaterial=new THREE.MeshStandardMaterial({color:0xb5bdc2,metalness:.35,roughness:.55});
 const windowMaterial=new THREE.MeshStandardMaterial({color:0x253d49,metalness:.1,roughness:.3});
 const roofMaterial=new THREE.MeshStandardMaterial({color:0x858f94,metalness:.25,roughness:.7});
 const box=new THREE.Box3(),size=new THREE.Vector3(),center=new THREE.Vector3();
 const doorMaterial=new THREE.MeshStandardMaterial({color:0x929fa5,metalness:.28,roughness:.6});
 const lampMaterial=new THREE.MeshBasicMaterial({color:0xe6e5d0});
 for(const car of consist.cars){
  // Compute bounds in carriage-local coordinates, without including the proxy.
  car.root.updateWorldMatrix(true,true);
  const inverse=car.root.matrixWorld.clone().invert();
  box.makeEmpty();
  car.root.traverse(o=>{
   if(!o.isMesh||!o.geometry)return;
   if(!o.geometry.boundingBox)o.geometry.computeBoundingBox();
   const local=o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld).applyMatrix4(inverse);
   box.union(local);
  });
  if(box.isEmpty())continue;
  box.getSize(size);box.getCenter(center);
  // Conservative body silhouette: leave existing car position and dimensions unchanged.
  const carriage=new THREE.Group();carriage.name='distant-car-proxy';
  car.root.add(carriage);
  const body=new THREE.Mesh(new THREE.BoxGeometry(size.x*.95,size.y*.68,size.z*.98),bodyMaterial);
  body.position.set(center.x,box.min.y+size.y*.55,center.z);carriage.add(body);
  const roof=new THREE.Mesh(new THREE.BoxGeometry(size.x*.96,size.y*.08,size.z*.98),roofMaterial);
  roof.position.set(center.x,box.max.y-size.y*.08,center.z);carriage.add(roof);
  for(const side of [-1,1]){
   const strip=new THREE.Mesh(new THREE.BoxGeometry(.015,size.y*.18,size.z*.86),windowMaterial);
   strip.position.set(center.x+side*size.x*.477,box.min.y+size.y*.72,center.z);
   carriage.add(strip);
  }
  // A small number of distinct door/window panels preserves the familiar 81-717 rhythm.
  for(const side of [-1,1])for(let i=0;i<4;i++){
   const z=center.z+(i-1.5)*size.z*.215;
   const door=new THREE.Mesh(new THREE.BoxGeometry(.024,size.y*.43,size.z*.105),doorMaterial);
   door.position.set(center.x+side*size.x*.483,box.min.y+size.y*.47,z);carriage.add(door);
   const glass=new THREE.Mesh(new THREE.BoxGeometry(.028,size.y*.16,size.z*.085),windowMaterial);
   glass.position.set(center.x+side*size.x*.497,box.min.y+size.y*.63,z);carriage.add(glass);
  }
  for(const zSign of [-1,1]){
   const end=new THREE.Mesh(new THREE.BoxGeometry(size.x*.9,size.y*.46,.04),bodyMaterial);
   end.position.set(center.x,box.min.y+size.y*.48,center.z+zSign*size.z*.49);carriage.add(end);
   for(const xSign of [-1,1]){
    const lamp=new THREE.Mesh(new THREE.BoxGeometry(size.x*.09,size.y*.055,.045),lampMaterial);
    lamp.position.set(center.x+xSign*size.x*.32,box.min.y+size.y*.45,center.z+zSign*size.z*.515);carriage.add(lamp);
   }
  }
  // Batch the static proxy into at most one draw call per material per car.
  // Merge in carriage-local coordinates so car transforms remain independent.
  carriage.updateMatrix();
  const batches=new Map();
  for(const part of [...carriage.children]){
   part.updateMatrix();
   const geometry=part.geometry.clone();
   geometry.applyMatrix4(part.matrix);
   const entries=batches.get(part.material)||[];
   entries.push(geometry);batches.set(part.material,entries);
   carriage.remove(part);part.geometry.dispose();
  }
  for(const [material,geometries] of batches){
   const merged=mergeGeometries(geometries,false);
   for(const geometry of geometries)geometry.dispose();
   if(!merged)throw new Error('Unable to batch distant train proxy geometry');
   const mesh=new THREE.Mesh(merged,material);
   mesh.name='distant-car-batched-'+proxies.length;
   carriage.add(mesh);
  }
  proxies.push(carriage);
 }
 const proxyMeshes=new Set();
 for(const proxy of proxies)proxy.traverse(o=>{if(o.isMesh)proxyMeshes.add(o);});
 const originals=[];
 consist.root.traverse(o=>{if(o.isMesh&&!proxyMeshes.has(o))originals.push({mesh:o,visible:o.visible});});
 for(const p of proxies)p.visible=false;
 let distant=false;
 const nearest=new THREE.Vector3();
 // Proxy meshes must remain outside fine-detail LOD bookkeeping.
 return {
  update(camera){
   consist.root.updateWorldMatrix(true);
   // Long trains must use the closest carriage, not their midpoint.
   let distance=Infinity;
   for(const car of consist.cars){car.root.getWorldPosition(nearest);distance=Math.min(distance,nearest.distanceTo(camera.position));}
   const next=distant?distance>exitDistance:distance>enterDistance;
   if(next===distant)return false;
   distant=next;
   for(const {mesh,visible} of originals)mesh.visible=next?false:visible;
   for(const p of proxies)p.visible=next;
   return true;
  },
  get distant(){return distant;},
  restore(){distant=false;for(const {mesh,visible} of originals)mesh.visible=visible;for(const p of proxies)p.visible=false;}
 };
}
