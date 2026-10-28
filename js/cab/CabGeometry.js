// Cab coordinates are metres. Local panel XY is its face; +Z faces the driver.
export function createCabGeometry(THREE,materials){
 const cache=new Map(),labels=new Map();
 const atlas=document.createElement('canvas');atlas.width=atlas.height=2048;
 const atlasContext=atlas.getContext('2d'),atlasTexture=new THREE.CanvasTexture(atlas);atlasTexture.colorSpace=THREE.SRGBColorSpace;atlasTexture.anisotropy=4;
 const labelMaterial=new THREE.MeshBasicMaterial({map:atlasTexture,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
 const geometry=(key,make)=>{if(!cache.has(key))cache.set(key,make());return cache.get(key)};
 function mesh(parent,geo,material,x=0,y=0,z=0){const o=new THREE.Mesh(geo,material);o.position.set(x,y,z);parent.add(o);return o}
 function shape(w,h,r){const s=new THREE.Shape(),x=-w/2,y=-h/2;r=Math.min(r,w*.49,h*.49);
  s.moveTo(x+r,y);s.lineTo(x+w-r,y);s.quadraticCurveTo(x+w,y,x+w,y+r);
  s.lineTo(x+w,y+h-r);s.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
  s.lineTo(x+r,y+h);s.quadraticCurveTo(x,y+h,x,y+h-r);
  s.lineTo(x,y+r);s.quadraticCurveTo(x,y,x+r,y);return s;
 }
 function rounded(parent,w,h,d,x,y,z,mat=materials.panel,r=.012){
  const key=`r:${w}:${h}:${d}:${r}`;
  const surface=mat===materials.panel?'plate':'';
  return mesh(parent,geometry(key+surface,()=>{const bevel=Math.min(.002,w*.08,h*.08,d*.25);const g=new THREE.ExtrudeGeometry(shape(w,h,r),{depth:d,bevelEnabled:true,bevelSegments:3,bevelSize:bevel,bevelThickness:bevel,curveSegments:8,steps:1});g.translate(0,0,-d/2);
   if(surface){const p=g.attributes.position,uv=g.attributes.uv;for(let i=0;i<uv.count;i++)uv.setXY(i,(p.getX(i)+w/2)/w,(p.getY(i)+h/2)/h);}
   return g;}),mat,x,y,z);
 }
 function box(parent,w,h,d,x,y,z,mat=materials.casing){return mesh(parent,geometry(`b:${w}:${h}:${d}`,()=>new THREE.BoxGeometry(w,h,d)),mat,x,y,z)}
 function cylinder(parent,r,h,x,y,z,mat=materials.steel,r2=r,segments=32){
  const o=mesh(parent,geometry(`c:${r}:${r2}:${h}:${segments}`,()=>new THREE.CylinderGeometry(r,r2,h,segments)),mat,x,y,z);o.rotation.x=Math.PI/2;return o;
 }
 function ring(parent,r,t,x,y,z,mat=materials.steel){return mesh(parent,geometry(`t:${r}:${t}`,()=>new THREE.TorusGeometry(r,t,8,40)),mat,x,y,z)}
 function tube(parent,points,r,mat=materials.rubber,segments=28){
  const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(...p)));
  return mesh(parent,new THREE.TubeGeometry(curve,segments,r,8,false),mat);
 }
 function label(parent,text,x,y,w=.15,h=.022,color='#151713',z=.014){
  const key=`${text}:${color}:${w}:${h}`;
  if(!labels.has(key)){
   const i=labels.size;if(i>=128)throw new Error('Cab label atlas is full');const x=i%4*512,y=Math.floor(i/4)*64;
   const ctx=atlasContext;ctx.fillStyle=color;ctx.textAlign='center';ctx.textBaseline='middle';ctx.font='600 44px Arial,sans-serif';ctx.fillText(text,x+256,y+32,498);
   const crop=Math.min(512,ctx.measureText(text).width+14),left=x+(512-crop)/2;
   const g=new THREE.PlaneGeometry(w,h),uv=g.attributes.uv;
   for(let j=0;j<uv.count;j++)uv.setXY(j,(left+uv.getX(j)*crop)/2048,1-(y+64-uv.getY(j)*64)/2048);
   labels.set(key,g);atlasTexture.needsUpdate=true;
  }
  return mesh(parent,labels.get(key),labelMaterial,x,y,z);
 }
 function screws(parent,w,h,z=.026){
  const g=geometry('screw',()=>new THREE.CylinderGeometry(.0045,.0045,.003,12));
  const caps=new THREE.InstancedMesh(g,materials.steel,4),slots=new THREE.InstancedMesh(geometry('slot',()=>new THREE.BoxGeometry(.0058,.0009,.00065)),materials.black,4);
  const temp=new THREE.Object3D();let i=0;
  for(const x of [-w/2+.015,w/2-.015])for(const y of [-h/2+.015,h/2-.015]){
   temp.position.set(x,y,z);temp.rotation.set(Math.PI/2,0,0);temp.updateMatrix();caps.setMatrixAt(i,temp.matrix);
   temp.position.z=z+.002;temp.rotation.set(0,0,.45+x*4);temp.updateMatrix();slots.setMatrixAt(i++,temp.matrix);
  }
  parent.add(caps,slots);
 }
 function panel(parent,w,h,x,y,z=0,mat=materials.panel){
  const group=new THREE.Group();group.position.set(x,y,z);parent.add(group);
  rounded(group,w+.003,h+.003,.008,0,0,-.014,materials.rubber,.012);
  rounded(group,w,h,.021,0,0,0,mat,.012);screws(group,w,h,.014);return group;
 }
 function contactShadow(parent,w,h=w,x=0,y=0,z=-.003){
  const o=mesh(parent,geometry(`shadow:${w}:${h}`,()=>new THREE.PlaneGeometry(w,h)),materials.contactShadow,x,y,z);o.castShadow=false;return o;
 }
 return {THREE,materials,mesh,geometry,shape,box,rounded,cylinder,ring,tube,label,panel,screws,contactShadow,cache};
}
