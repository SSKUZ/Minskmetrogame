// Screen-space detail culling for the static opposing consist.
// Non-destructive: geometry/materials remain intact and meshes return when camera approaches.
// THREE's built-in frustum culling still handles objects outside the camera view.
export function createSecondaryTrainDetailLOD(THREE,root,{minDistance=28,hideBelowPixels=2.5,restoreAbovePixels=4}={}){
 const meshes=[];
 root.traverse(object=>{
  if(!object.isMesh||!object.geometry)return;
  const sphere=object.geometry.boundingSphere||(object.geometry.computeBoundingSphere(),object.geometry.boundingSphere);
  if(!sphere||!Number.isFinite(sphere.radius))return;
  meshes.push({object,sphere,hidden:false,originalVisible:object.visible});
 });
 const center=new THREE.Vector3();
 let hiddenCount=0;
 return {
  update(camera,viewportHeight){
   camera.updateMatrixWorld();
   root.updateWorldMatrix(true,true);
   const focal=viewportHeight/(2*Math.tan(THREE.MathUtils.degToRad(camera.fov)*.5));
   let count=0,changed=false;
   for(const item of meshes){
    const {object,sphere}=item;
    if(!item.originalVisible)continue;
    center.copy(sphere.center).applyMatrix4(object.matrixWorld);
    const radius=sphere.radius*object.matrixWorld.getMaxScaleOnAxis();
    const distance=center.distanceTo(camera.position);
    const pixels=2*radius*focal/Math.max(.001,distance);
    const shouldHide=distance>minDistance&&(item.hidden?pixels<restoreAbovePixels:pixels<hideBelowPixels);
    if(shouldHide!==item.hidden){item.hidden=shouldHide;object.visible=!shouldHide;changed=true;}
    if(item.hidden)count++;
   }
   hiddenCount=count;return changed;
  },
  restore(){for(const item of meshes){item.object.visible=item.originalVisible;item.hidden=false;}hiddenCount=0;},
  get hiddenCount(){return hiddenCount;},
  get totalCount(){return meshes.length;}
 };
}
