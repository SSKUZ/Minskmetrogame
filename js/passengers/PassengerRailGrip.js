import * as THREE from '../vendor/three.module.js';

// Sample the centreline actually used by each existing TubeGeometry. This also
// captures the carriage's translation and nonuniform Z scale. No invented poles.
export function readCarriageRails(carriage){
 const rails=[];carriage.updateWorldMatrix(true,true);
 carriage.traverse(mesh=>{
  const geometry=mesh.geometry,path=geometry?.parameters?.path;
  if(geometry?.type!=='TubeGeometry'||!path||geometry.parameters.radius>.04)return;
  const points=[];for(let n=0;n<=128;n++)points.push(mesh.localToWorld(path.getPointAt(n/128)));
  rails.push({id:mesh.uuid,radius:geometry.parameters.radius,points});
 });
 return rails;
}

// Navigation candidates beside actual vertical posts. Coordinates stay in the
// simulation's train frame; the accepted carriage geometry remains untouched.
export function railStandingPlaces(rails,offsetZ=112,aisleX=-.31){
 const places=[];
 for(const rail of rails){
  let point=null,error=Infinity;
  for(let i=1;i<rail.points.length;i++){
   const p=rail.points[i],t=p.clone().sub(rail.points[i-1]).normalize();
   if(Math.abs(t.y)<.94||p.y<2.1||p.y>2.8)continue;
   if(Math.abs(p.y-2.4)<error){point=p;error=Math.abs(p.y-2.4);}
  }
  if(!point)continue;
  const direction=point.x<aisleX?1:-1;
  for(const zOffset of [-.25,.25]){
   const place={x:point.x+direction*.43,z:point.z-offsetZ+zOffset,railId:rail.id};
   if(place.x< -1.82||place.x>1.25)continue;
   if(!places.some(p=>Math.hypot(p.x-place.x,p.z-place.z)<.4))places.push(place);
  }
 }
 return places;
}

export function chooseRailGrip(view,rails){
 view.model.updateWorldMatrix(true,true);
 let best=null,score=Infinity;
 for(const side of ['Right','Left']){
  const upper=view.bones[side+'Arm'],elbow=view.bones[side+'ForeArm'],hand=view.bones[side+'Hand'];
  if(!upper||!elbow||!hand)continue;
  const shoulder=upper.getWorldPosition(new THREE.Vector3()),bend=elbow.getWorldPosition(new THREE.Vector3()),wrist=hand.getWorldPosition(new THREE.Vector3());
  const reach=shoulder.distanceTo(bend)+bend.distanceTo(wrist);
  for(const rail of rails)for(let n=1;n<rail.points.length;n++){
   const p=rail.points[n],previous=rail.points[n-1],tangent=p.clone().sub(previous).normalize();
   // Keep children on lower bars and all hands below a comfortable reach limit.
   if(p.y<shoulder.y-reach*.72||p.y>shoulder.y+reach*.90)continue;
   const normal=shoulder.clone().sub(p).addScaledVector(tangent,-shoulder.clone().sub(p).dot(tangent)).normalize();
   const handUp=tangent.clone().cross(normal.clone().multiplyScalar(side==='Left'?-1:1)).normalize();
   const palmLength=.07*(view.height/1.75)*view.root.scale.y;
   const target=p.clone().addScaledVector(normal,rail.radius+.025).addScaledVector(handUp,-palmLength);
   const distance=target.distanceTo(shoulder);
   if(distance>reach*.89||distance<reach*.29)continue;
   const local=view.root.worldToLocal(target.clone());
   if(local.z<-.27)continue; // no reversed shoulder joint behind the back
   const cost=distance+Math.abs(p.y-shoulder.y-.10)*.25+(side==='Left'?.02:0);
   if(cost<score){score=cost;best={railId:rail.id,side,point:p.clone(),target,normal,tangent,radius:rail.radius,reach};}
  }
 }
 return best;
}
