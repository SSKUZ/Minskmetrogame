// Bake fixed parts by shared material, keeping controls, needles and video live.
export function batchCabStatic(THREE,root){
 root.updateMatrixWorld(true);const inverse=root.matrixWorld.clone().invert(),groups=new Map(),remove=[];
 root.traverse(o=>{
  if(!o.isMesh||o.isInstancedMesh||Array.isArray(o.material))return;
  for(let p=o;p&&p!==root;p=p.parent)if(p.userData.cabDynamic)return;
  const source=o.geometry;if(!source.attributes.normal||!source.attributes.uv)return;
  const geometry=source.index?source.toNonIndexed():source.clone();
  geometry.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inverse,o.matrixWorld));
  if(!groups.has(o.material))groups.set(o.material,[]);groups.get(o.material).push(geometry);remove.push(o);
 });
 for(const [material,parts] of groups){
  const combined=new THREE.BufferGeometry();
  for(const [key,size] of [['position',3],['normal',3],['uv',2]]){
   const count=parts.reduce((n,g)=>n+g.attributes[key].array.length,0),data=new Float32Array(count);let offset=0;
   for(const g of parts){data.set(g.attributes[key].array,offset);offset+=g.attributes[key].array.length;}
   combined.setAttribute(key,new THREE.BufferAttribute(data,size));
  }
  combined.computeBoundingSphere();const mesh=new THREE.Mesh(combined,material);mesh.name='CabStaticBatch';root.add(mesh);parts.forEach(g=>g.dispose());
 }
 for(const o of remove)o.removeFromParent();
 return {sourceMeshes:remove.length,batches:groups.size};
}
