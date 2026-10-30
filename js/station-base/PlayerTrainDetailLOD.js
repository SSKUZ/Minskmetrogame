// Conservative detail culling for the player consist.
// Never hide door leaves, wheel/threshold meshes, or their descendants.
// This affects only small visual meshes and never mutates source geometry.
export function createPlayerTrainDetailLOD(THREE,consist,{minDistance=22,hidePixels=1.5,restorePixels=2.5}={}){
 const protectedRoots=new Set();
 for(const car of consist.cars){
  for(const leaf of car.leaves)protectedRoots.add(leaf.leaf);
  car.root.traverse(o=>{if(o.userData?.wheel||o.userData?.passengerThreshold||o.userData?.batchedParts?.some(p=>p.wheel))protectedRoots.add(o);});
 }
 const items=[];
 consist.root.traverse(o=>{
  if(!o.isMesh||!o.geometry||!o.visible)return;
  let p=o,protectedMesh=false;
  while(p&&p!==consist.root){if(protectedRoots.has(p)){protectedMesh=true;break;}p=p.parent;}
  if(protectedMesh)return;
  if(!o.geometry.boundingSphere)o.geometry.computeBoundingSphere();
  const sphere=o.geometry.boundingSphere;
  if(sphere&&Number.isFinite(sphere.radius))items.push({mesh:o,sphere,hidden:false});
 });
 const center=new THREE.Vector3();
 let hiddenCount=0;
 return {
  update(camera,viewportHeight){
   consist.root.updateWorldMatrix(true);
   const focal=viewportHeight/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov)/2));
   let changed=false,count=0;
   for(const item of items){
    center.copy(item.sphere.center).applyMatrix4(item.mesh.matrixWorld);
    const distance=center.distanceTo(camera.position);
    const diameter=2*item.sphere.radius*item.mesh.matrixWorld.getMaxScaleOnAxis();
    const pixels=diameter*focal/Math.max(.001,distance);
    const hide=distance>minDistance&&(item.hidden?pixels<restorePixels:pixels<hidePixels);
    if(hide!==item.hidden){item.mesh.visible=!hide;item.hidden=hide;changed=true;}
    if(hide)count++;
   }
   hiddenCount=count;return changed;
  },
  restore(){for(const item of items){item.mesh.visible=true;item.hidden=false;}hiddenCount=0;},
  get hiddenCount(){return hiddenCount;},
  get totalCount(){return items.length;}
 };
}
