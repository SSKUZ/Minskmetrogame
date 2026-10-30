import {trainPlacement} from './TrainCompatibilityProfile.js';
export function createV106Adapter(THREE,root,consist,profile,servedSide=-1,direction=-1){
 if(consist.cars.length!==profile.formation.length||consist.cars.some((c,i)=>c.type!==profile.formation[i]||c.leaves.length!==profile.train.doorLeafCount/profile.formation.length))throw new Error('Unexpected original v106 formation');
 return {root,consist,
  place(frontZ=0,trackX=0){const p=trainPlacement(profile,frontZ,trackX,direction);root.position.set(p.x,p.y,p.z);root.rotation.set(0,p.yaw,0);root.scale.setScalar(1);root.visible=true;root.updateMatrixWorld(true);},
  doors(progress){const p=THREE.MathUtils.clamp(progress,0,1),t=p*p*p*(p*(p*6-15)+10);root.updateMatrixWorld(true);
   for(const c of consist.cars)for(const d of c.leaves){const side=Math.sign(new THREE.Vector3(d.side,0,0).transformDirection(c.root.matrixWorld).x);d.leaf.position.z=d.homeZ+(side===servedSide?d.half*d.travel*t:0);}root.updateMatrixWorld(true);}
 };
}

// Share immutable geometry/materials; clone transforms and remap door registries.
export function cloneV106Consist(source){
 const root=source.root.clone(true),old=[],copies=[];source.root.traverse(o=>old.push(o));root.traverse(o=>copies.push(o));const map=new Map(old.map((o,i)=>[o,copies[i]]));
 for(const original of old)if(original.isDirectionalLight&&map.has(original.target))map.get(original).target=map.get(original.target);
 const cars=source.cars.map(c=>({...c,root:map.get(c.root),leaves:c.leaves.map(d=>({...d,leaf:map.get(d.leaf)}))}));
 root.name='station-base-opposing-v106';return {root,cars};
}
