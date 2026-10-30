import {STATION_MATERIALS} from '../../data/station-base/materials.js';
// Engine adapter only. Core modules remain engine-neutral data.
export function renderStation(THREE,scene,base){
 const root=new THREE.Group();root.name='StationBase-v1';scene.add(root);
 const materials=Object.fromEntries(Object.entries(STATION_MATERIALS).map(([id,spec])=>{const {kind,...values}=spec;return [id,kind==='unlit'?new THREE.MeshBasicMaterial(values):new THREE.MeshStandardMaterial(values)];}));
 const box=(size,center,material,name)=>{const o=new THREE.Mesh(new THREE.BoxGeometry(size.x,size.y,size.z),material);o.name=name;o.position.set(center.x,center.y,center.z);root.add(o);return o;};
 const railMeshes=[];
 for(const t of base.modules.track.tracks){
  for(const r of t.rails)railMeshes.push(box(r.size,r.center,materials.rail,r.id));
  box(t.bed.size,t.bed.center,materials.bed,t.id+'/bed');
  const spec=t.sleepers,count=spec.count,sleepers=new THREE.InstancedMesh(new THREE.BoxGeometry(spec.size.x,spec.size.y,spec.size.z),materials.sleeper,count),m=new THREE.Matrix4();
  for(let i=0;i<count;i++){m.makeTranslation(spec.x,spec.y,spec.startZ+i*spec.pitch);sleepers.setMatrixAt(i,m);}root.add(sleepers);
 }
 const slab=base.modules.platform.slab,platformMesh=box(slab.size,slab.center,materials.platform,'platform-slab');
 for(const edge of base.modules.platform.edges){const sign=edge.id==='edge-1'?-1:1;box({x:.055,y:.005,z:edge.maxZ-edge.minZ},{x:edge.x+sign*.25,y:base.station.platform.topY+.003,z:(edge.minZ+edge.maxZ)/2},materials.edge,edge.id+'/safety-reference');}
 const markers=new THREE.Group();markers.name='technical-anchors';root.add(markers);
 const sphere=new THREE.SphereGeometry(.025,8,6);
 for(const d of base.modules.stops.flatMap(s=>s.doors)){const mesh=new THREE.Mesh(sphere,materials.marker);mesh.position.set(d.x,d.y+.06,d.z);markers.add(mesh);
  const line=new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(d.x+d.normal.x*.8,d.y+.012,d.z),new THREE.Vector3(d.x,d.y+.012,d.z)]);markers.add(new THREE.Line(line,new THREE.LineBasicMaterial({color:0x26afc5})));}
 const label=(text,x,y,z)=>{const canvas=document.createElement('canvas');canvas.width=512;canvas.height=96;const c=canvas.getContext('2d');c.fillStyle='#102733';c.fillRect(0,0,512,96);c.fillStyle='#c7f6ff';c.font='bold 40px sans-serif';c.textAlign='center';c.fillText(text,256,64);const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:new THREE.CanvasTexture(canvas),depthTest:true}));sprite.position.set(x,y,z);sprite.scale.set(3.7,.7,1);markers.add(sprite);};
 for(const stop of base.modules.stops)label(stop.trackId+' · STOP',stop.trackX+stop.servedSide*2.8,2.4,stop.frontZ);
 for(const port of base.modules.ports){const geometry=new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(port.position.x-1.65,0,port.position.z),new THREE.Vector3(port.position.x-1.65,4.02,port.position.z),new THREE.Vector3(port.position.x+1.65,4.02,port.position.z),new THREE.Vector3(port.position.x+1.65,0,port.position.z)]);markers.add(new THREE.Line(geometry,new THREE.LineBasicMaterial({color:0x408db0})));}
 const floorGrid=new THREE.GridHelper(120,60,0x85959f,0xadbcc5);floorGrid.position.set(-5.4,-.38,40);root.add(floorGrid);
 const axis=new THREE.AxesHelper(3);axis.position.set(0,0,base.modules.stop.frontZ);markers.add(axis);
 return {root,railMeshes,platformMesh,markers};
}
