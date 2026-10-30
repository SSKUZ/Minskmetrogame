// Lightweight distant substitute for the opposing train.
// Each carriage becomes a small number of meshes instead of thousands of details.
// Original geometry is retained and automatically restored near the camera.
export function createOpposingTrainProxyLOD(THREE,consist,{enterDistance=65,exitDistance=48}={}){
 const proxies=[];
 const bodyMaterial=new THREE.MeshStandardMaterial({color:0xb5bdc2,metalness:.35,roughness:.55});
 const windowMaterial=new THREE.MeshStandardMaterial({color:0x253d49,metalness:.1,roughness:.3});
 const roofMaterial=new THREE.MeshStandardMaterial({color:0x858f94,metalness:.25,roughness:.7});
 const wheelsMaterial=new THREE.MeshStandardMaterial({color:0x242b2e,roughness:.9});
 const box=new THREE.Box3(),size=new THREE.Vector3(),center=new THREE.Vector3();
 const group=new THREE.Group();group.name='opposing-train-distant-proxy';
 consist.root.add(group);
 for(const car of consist.cars){
  // Compute bounds in carriage-local coordinates, without including the proxy.
  car.root.updateWorldMatrix(true,true);
  const inverse=car.root.matrixWorld.clone().invert();
  box.makeEmpty();
  car.root.traverse(o=>{
   if(!o.isMesh||!o.geometry)return;
   o.geometry.computeBoundingBox();
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
  // Avoid adding proxy geometry to the original train's detail hierarchy.
  proxies.push(carriage);
 }
 const originals=[];
 consist.root.traverse(o=>{if(o.isMesh&&!proxies.some(p=>p===o||p.children.includes(o)))originals.push({mesh:o,visible:o.visible});});
 for(const p of proxies)p.visible=false;
 let distant=false;
 const midpoint=new THREE.Vector3();
 return {
  update(camera){
   consist.root.updateWorldMatrix(true);
   midpoint.set(0,0,0);
   for(const car of consist.cars){car.root.getWorldPosition(center);midpoint.add(center);}
   midpoint.multiplyScalar(1/consist.cars.length);
   const distance=midpoint.distanceTo(camera.position);
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
