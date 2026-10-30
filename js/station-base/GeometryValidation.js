// CPU geometry measurements, shared by the browser viewer and Node audit.
// No expected wheel bounds are substituted for actual BufferGeometry vertices.
function bounds(THREE,mesh,start=0,count=mesh.geometry.attributes.position.count){
 const b=new THREE.Box3(),v=new THREE.Vector3(),a=mesh.geometry.attributes.position;
 for(let i=start;i<start+count;i++)b.expandByPoint(v.fromBufferAttribute(a,i).applyMatrix4(mesh.matrixWorld));
 return {min:b.min.toArray(),max:b.max.toArray()};
}
export function measureTrain(THREE,consist){
 consist.root.updateMatrixWorld(true);const wheels=[],thresholds=[],doors=[];
 for(const car of consist.cars){
  car.root.traverse(o=>{if(!o.isMesh)return;
   if(o.userData.wheel)wheels.push({car:car.index,...bounds(THREE,o)});
   for(const p of o.userData.batchedParts??[])if(p.wheel)wheels.push({car:car.index,...bounds(THREE,o,p.vertexStart,p.vertexCount)});
   if(o.userData.passengerThreshold)thresholds.push({car:car.index,...bounds(THREE,o)});
  });
  const groups=new Map();for(const d of car.leaves){const key=d.side+':'+d.doorZ;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(d);}
  for(const leaves of groups.values()){
   const d=leaves[0],center=new THREE.Vector3(0,0,d.doorZ).applyMatrix4(car.root.matrixWorld),normal=new THREE.Vector3(d.side,0,0).transformDirection(car.root.matrixWorld);
   // Box3 covers all descendants, including grab handles and seams.
   const full=leaves.map(l=>{const b=new THREE.Box3().setFromObject(l.leaf,true);return {min:b.min.toArray(),max:b.max.toArray()};}).sort((a,b)=>a.min[2]-b.min[2]);
   doors.push({car:car.index,localSide:d.side,side:Math.sign(normal.x),z:center.z,leafPositions:leaves.map(l=>l.leaf.position.z),openProjectionWidth:full[1].min[2]-full[0].max[2]});
  }
 }
 return {wheels,thresholds,doors};
}
export function validateActualGeometry(THREE,base,consist,{frontZ=base.modules.stop.frontZ,doorProgress=0,band,railMeshes,platformMesh,stop=base.modules.stop}={}){
 const measured=measureTrain(THREE,consist),p=base.profile,s=base.station,eps=p.validation.epsilon,issues=[],checks=[];
 const check=(id,ok,value,expected)=>{checks.push({id,ok,value,expected});if(!ok)issues.push(id);};
 const track=s.tracks.find(t=>t.id===stop.trackId);
 const railHeads=railMeshes?railMeshes.slice(s.tracks.findIndex(t=>t.id===stop.trackId)*2,s.tracks.findIndex(t=>t.id===stop.trackId)*2+2).map(o=>new THREE.Box3().setFromObject(o,true).max.y):base.modules.track.tracks.find(t=>t.id===stop.trackId).rails.map(r=>r.center.y+r.size.y/2);
 const contacts=measured.wheels.map(w=>{const x=(w.min[0]+w.max[0])/2,z=(w.min[2]+w.max[2])/2;const railIndex=x<track.x?0:1,rail=base.modules.track.tracks.find(t=>t.id===stop.trackId).rails[railIndex];const top=railHeads[railIndex];
  return {car:w.car,x,z,y:w.min[1],verticalError:w.min[1]-top,lateralError:x-rail.center.x};});
 check('32 wheel contacts',contacts.length===p.train.wheelCount&&contacts.every(w=>Math.abs(w.verticalError)<=eps&&Math.abs(w.lateralError)<=eps&&w.z>=s.trackRange.minZ&&w.z<=s.trackRange.maxZ),contacts,p.train.wheelCount);
 if(railMeshes){const railBounds=railMeshes.map(o=>new THREE.Box3().setFromObject(o,true));check('4 rail mesh profiles',railBounds.length===base.modules.track.tracks.length*p.rail.centerOffsets.length&&railBounds.every((b,i)=>{const expected=base.modules.track.tracks[Math.floor(i/p.rail.centerOffsets.length)].rails[i%p.rail.centerOffsets.length];return Math.abs((b.min.x+b.max.x)/2-expected.center.x)<=eps&&Math.abs(b.max.y-p.rail.headY)<=eps&&Math.abs(b.max.x-b.min.x-p.rail.width)<=eps;}),railBounds.map(b=>({min:b.min.toArray(),max:b.max.toArray()})),p.id);}
 const platformTop=platformMesh?new THREE.Box3().setFromObject(platformMesh,true).max.y:s.platform.topY;
 const served=measured.thresholds.filter(t=>Math.sign((t.min[0]+t.max[0])/2-track.x)===stop.servedSide).sort((a,b)=>a.min[2]-b.min[2]);
 check('16 served thresholds',served.length===p.doors.length,served.length,p.doors.length);
 const expectedDoors=[...stop.doors].sort((a,b)=>a.z-b.z);const dz=frontZ-stop.frontZ;
 const doorErrors=served.map((t,i)=>({id:expectedDoors[i]?.id,z:(t.min[2]+t.max[2])/2,zError:(t.min[2]+t.max[2])/2-(expectedDoors[i]?.z+dz),step:t.max[1]-platformTop,gap:stop.servedSide===-1?t.min[0]-s.platform.maxX:s.platform.minX-t.max[0]}));
 check('door Z anchors',doorErrors.length===p.doors.length&&doorErrors.every(d=>Math.abs(d.zError)<=eps),doorErrors.map(d=>d.zError),0);
 check('level platform/sills',doorErrors.every(d=>Math.abs(d.step)<=eps),doorErrors.map(d=>d.step),0);
 const sillGap=served.length?Math.min(...served.map(t=>stop.servedSide===-1?t.min[0]-s.platform.maxX:s.platform.minX-t.max[0])):null;
 check('sill horizontal gap',sillGap!==null&&Math.abs(sillGap-(p.platform.edgeOffset-p.train.thresholdAbsX))<=eps,sillGap,p.platform.edgeOffset-p.train.thresholdAbsX);
 const allLeaves=consist.cars.flatMap(c=>c.leaves.map(d=>({car:c,leaf:d,side:Math.sign(new THREE.Vector3(d.side,0,0).transformDirection(c.root.matrixWorld).x)})));
 const curve=doorProgress**3*(doorProgress*(doorProgress*6-15)+10);
 check('door actuator positions',allLeaves.length===p.train.doorLeafCount&&allLeaves.every(({leaf:d,side})=>Math.abs(d.leaf.position.z-(d.homeZ+(side===stop.servedSide?d.half*d.travel*curve:0)))<=eps),allLeaves.length,p.train.doorLeafCount);
 const servedDoors=measured.doors.filter(d=>d.side===stop.servedSide);
 if(doorProgress===1)check('open door projection',servedDoors.every(d=>Math.abs(d.openProjectionWidth-p.door.openProjectionWidth)<=eps),servedDoors.map(d=>d.openProjectionWidth),p.door.openProjectionWidth);
 check('measured clearance band',!!band,band?.method??null,'actual triangle clipping');
 if(band){const bodyGap=stop.servedSide===-1?band.minX-s.platform.maxX:s.platform.minX-band.maxX;check('body/platform solid clearance',bodyGap>0,bodyGap,'>0');check('clearance budget',bodyGap-p.validation.lateralBudget>=p.validation.minimumResidualClearance-eps,bodyGap-p.validation.lateralBudget,p.validation.minimumResidualClearance);}
 // Z references outside platform while approaching are expected; verify extents at stop only.
 if(Math.abs(frontZ-stop.frontZ)<=eps)check('stopped doors inside platform',doorErrors.every(d=>d.z-p.door.routeHalfWidth>s.platform.minZ&&d.z+p.door.routeHalfWidth<s.platform.maxZ),frontZ,stop.frontZ);
 return {ok:issues.length===0,issues,checks,frontZ,doorProgress,trackId:stop.trackId,direction:stop.direction,servedSide:stop.servedSide,contactCount:contacts.length,servedDoorCount:served.length,platformTop,sillGap,bodyGap:band?(stop.servedSide===-1?band.minX-s.platform.maxX:s.platform.minX-band.maxX):null,contacts,doorErrors,assetCommit:p.assetCommit,scope:'straight level, immutable v106 geometry; no passenger simulation'};
}
// Exact extrema of triangles clipped to a Y band; all Z positions are included.
export async function measureHeightBand(THREE,root,low,high,{yieldTask=async()=>{},onProgress=()=>{}}={}){
 root.updateMatrixWorld(true);const meshes=[];root.traverse(o=>{if(o.isMesh)meshes.push(o)});
 let minX=Infinity,maxX=-Infinity,triangles=0;const v=[new THREE.Vector3(),new THREE.Vector3(),new THREE.Vector3()];
 const include=x=>{minX=Math.min(minX,x);maxX=Math.max(maxX,x)};
 for(let n=0;n<meshes.length;n++){
  const mesh=meshes[n],g=mesh.geometry,a=g.attributes.position,index=g.index,bb=new THREE.Box3().setFromObject(mesh,true);
  if(bb.max.y>=low&&bb.min.y<=high)for(let i=0;i<(index?.count??a.count);i+=3){
   for(let k=0;k<3;k++)v[k].fromBufferAttribute(a,index?index.getX(i+k):i+k).applyMatrix4(mesh.matrixWorld);
   if(v.every(p=>p.y<low)||v.every(p=>p.y>high))continue;triangles++;
   for(let k=0;k<3;k++){const p=v[k],q=v[(k+1)%3];if(p.y>=low&&p.y<=high)include(p.x);
    if(Math.abs(q.y-p.y)<1e-12)continue;
    for(const y of [low,high]){const t=(y-p.y)/(q.y-p.y);if(t>=0&&t<=1)include(p.x+t*(q.x-p.x));}
   }
  }
  if(n%32===0){onProgress(n/meshes.length);await yieldTask();}
 }
 return {low,high,minX,maxX,triangles,method:'actual triangle clipping in world frame'};
}

export function validateTrainSeparation(THREE,first,second,epsilon){
 first.updateMatrixWorld(true);second.updateMatrixWorld(true);const a=new THREE.Box3().setFromObject(first,true),b=new THREE.Box3().setFromObject(second,true);
 const gapX=Math.max(a.min.x-b.max.x,b.min.x-a.max.x),gapY=Math.max(a.min.y-b.max.y,b.min.y-a.max.y),gapZ=Math.max(a.min.z-b.max.z,b.min.z-a.max.z);
 return {ok:Math.max(gapX,gapY,gapZ)>epsilon,gapX,gapY,gapZ,method:'conservative complete-mesh AABBs'};
}
