import * as T from 'three';

// Merge only static opaque meshes with identical materials and render state.
// Keep every original triangle, normal and UV. Transparent panes, markings,
// moving leaves and protected front equipment remain separate real meshes.
export function batchStaticCar(root){
 root.updateMatrixWorld(true);
 const inverse=new T.Matrix4().copy(root.matrixWorld).invert(),buckets=new Map();
 const count=()=>{let meshes=0,triangles=0;root.traverse(o=>{if(o.isMesh){meshes++;triangles+=(o.geometry.index?.count||o.geometry.attributes.position.count)/3}});return {meshes,triangles}};
 const before=count();
 root.traverse(mesh=>{
  if(!mesh.isMesh||Array.isArray(mesh.material)||mesh.material.transparent||mesh.userData.warningDecal||mesh.userData.slidingDoor||mesh.userData.couplingContact)return;
  for(let p=mesh;p&&p!==root;p=p.parent)if(p.userData.keepRenderObject)return;
  if(!mesh.geometry.attributes.position||!mesh.geometry.attributes.normal)return;
  const key=[mesh.material.uuid,mesh.layers.mask,mesh.renderOrder,mesh.frustumCulled].join(':');
  if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(mesh);
 });
 let batches=0,mergedSources=0;
 for(const meshes of buckets.values()){
  if(meshes.length<2)continue;
  const vertices=meshes.reduce((n,o)=>n+o.geometry.attributes.position.count,0),indices=meshes.reduce((n,o)=>n+(o.geometry.index?.count||o.geometry.attributes.position.count),0);
  const positions=new Float32Array(vertices*3),normals=new Float32Array(vertices*3),uvs=new Float32Array(vertices*2),index=vertices>65535?new Uint32Array(indices):new Uint16Array(indices),parts=[];
  let vertexOffset=0,indexOffset=0;
  for(const mesh of meshes){
   const g=mesh.geometry,p=g.attributes.position,n=g.attributes.normal,uv=g.attributes.uv,matrix=new T.Matrix4().multiplyMatrices(inverse,mesh.matrixWorld),normalMatrix=new T.Matrix3().getNormalMatrix(matrix),v=new T.Vector3(),normal=new T.Vector3(),bounds=new T.Box3();
   for(let i=0;i<p.count;i++){
    v.fromBufferAttribute(p,i).applyMatrix4(matrix);normal.fromBufferAttribute(n,i).applyNormalMatrix(normalMatrix);
    const at=(vertexOffset+i)*3;positions[at]=v.x;positions[at+1]=v.y;positions[at+2]=v.z;
    normals[at]=normal.x;normals[at+1]=normal.y;normals[at+2]=normal.z;
    uvs[(vertexOffset+i)*2]=uv?.getX(i)||0;uvs[(vertexOffset+i)*2+1]=uv?.getY(i)||0;
    bounds.expandByPoint(v.set(positions[at],positions[at+1],positions[at+2]));
   }
   const indexCount=g.index?.count||p.count;
   for(let i=0;i<indexCount;i++)index[indexOffset+i]=vertexOffset+(g.index?g.index.getX(i):i);
   parts.push({vertexStart:vertexOffset,vertexCount:p.count,indexStart:indexOffset,indexCount,bounds:{min:bounds.min.toArray(),max:bounds.max.toArray()},passengerSeat:!!mesh.userData.passengerSeat,wheel:!!mesh.userData.wheel,roofVent:!!mesh.userData.roofVent,structural:!!mesh.userData.sideWall||['outer-side','outer-roof'].includes(mesh.userData.structuralRole)});
   vertexOffset+=p.count;indexOffset+=indexCount;
  }
  const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.BufferAttribute(positions,3));geometry.setAttribute('normal',new T.BufferAttribute(normals,3));geometry.setAttribute('uv',new T.BufferAttribute(uvs,2));geometry.setIndex(new T.BufferAttribute(index,1));geometry.computeBoundingBox();geometry.computeBoundingSphere();
  const batch=new T.Mesh(geometry,meshes[0].material);batch.name='static-material-batch';batch.layers.mask=meshes[0].layers.mask;batch.renderOrder=meshes[0].renderOrder;batch.frustumCulled=meshes[0].frustumCulled;batch.userData.batchedParts=parts;
  for(const mesh of meshes)mesh.removeFromParent();root.add(batch);batches++;mergedSources+=meshes.length;
 }
 const after=count();if(before.triangles!==after.triangles)throw new Error('Batching changed triangle count');
 return {before,after,batches,mergedSources,method:'Exact static opaque material batches; original triangles, normals and UVs retained'};
}
