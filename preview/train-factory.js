import * as T from 'three';
import {createIntercarEnd} from './train-components.js?v=106';

// The intermediate is built from passenger modules, not a scaled head car.
// The library owns the shared materials/geometries and calibrated head parts.
export function createIntermediateCar(library){
 const {length:L,width:W,floor:F,wallHalf,eave,crown}=library.dimensions,m=library.materials;
 const root=new T.Group();root.name='81-714';root.userData.carType='81-714';root.userData.hasCab=false;
 const windows=[],leaves=[],doorCenters=[-6.645,-2.215,2.215,6.645];
 const addBox=(w,h,d,x,y,z,material)=>{const n=new T.Mesh(new T.BoxGeometry(w,h,d),material);n.position.set(x,y,z);n.layers.set(2);root.add(n);return n};
 addBox(W-.12,.12,L-.08,0,F-.06,0,m.floor);
 for(const side of [-1,1])addBox(.075,.20,L-.12,side*(W/2-.055),F-.08,0,m.steel);
 const ranges=[-L/2,...doorCenters.flatMap(z=>[z-.69,z+.69]),L/2];
 for(let i=0;i<ranges.length-1;i++){
  const a=ranges[i],b=ranges[i+1];if(Math.abs(b-a-1.38)<.001)continue;
  if(a<-8){
   const reflected=new T.Group();reflected.rotation.y=Math.PI;root.add(reflected);
   for(const side of [-1,1]){
    const built=library.buildBay(reflected,side,-b,-a);
    windows.push(...built.windows.map(w=>({...w,side:-w.side,z:-w.z})));
   }
  }else for(const side of [-1,1])windows.push(...library.buildBay(root,side,a,b).windows);
 }
 for(const side of [-1,1])for(const dz of doorCenters){
  leaves.push(...library.buildDoors(root,side,dz).leaves);library.buildWarnings(root,side,dz);
 }
 // Full length floor/ceiling and five bench bays: 44 actual volumetric seats.
 addBox(W-.28,.009,L-.30,0,F+.006,0,m.floorFinish);
 for(const [z,template] of [[-8.52,library.bench2],[-4.43,library.bench6],[0,library.bench6],[4.43,library.bench6],[8.52,library.bench2]]){
  const bench=template.clone(true);bench.position.z+=z;root.add(bench);
 }
 const cv=[],ci=[],columns=48;
 for(let i=0;i<=columns;i++){
  const x=-1.20+2.40*i/columns,y=3.32-.18*Math.pow(Math.abs(x)/1.20,2.4);cv.push(x,y,-L/2+.17,x,y,L/2-.17);
 }
 for(let i=0;i<columns;i++){const k=i*2;ci.push(k,k+1,k+2,k+1,k+3,k+2)}
 const ceiling=new T.BufferGeometry();ceiling.setAttribute('position',new T.Float32BufferAttribute(cv,3));ceiling.setIndex(ci);ceiling.computeVertexNormals();
 root.add(new T.Mesh(ceiling,m.ceiling));
 for(const side of [-1,1]){
  const rail=new T.Mesh(new T.CylinderGeometry(.018,.018,L-.80,8),m.steel);rail.rotation.x=Math.PI/2;rail.position.set(side*.72,F+2.12,0);root.add(rail);
  for(let i=-4;i<=4;i++){
   const z=i*2.1;addBox(.16,.022,1.88,side*.53,3.285,z,m.steel);addBox(.137,.025,1.83,side*.53,3.267,z,m.diffuser);
  }
  for(const dz of doorCenters)addBox(.10,.18,1.44,side*(W/2-.20),3.13,dz,m.lining);
  for(const w of windows.filter(w=>w.side===side))library.addInnerWindowTrim(root,w);
 }
 // One common rounded roof section over the complete passenger compartment.
 const rv=[],rn=[],ri=[],rows=160,cols=64;
 function roofY(x,z){const s=x/wallHalf,arch=Math.sqrt(Math.max(0,1-s**4));return eave+(crown-eave+.004*Math.sin(Math.PI*(z+L/2)/L)**2)*arch}
 for(let j=0;j<=rows;j++)for(let i=0;i<=cols;i++){
  const z=-L/2+L*j/rows,phi=-Math.PI/2+Math.PI*i/cols,s=Math.sin(phi),x=wallHalf*s,y=roofY(x,z),da=-2*s**3/Math.sqrt(1+s*s);
  rv.push(x,y,z);const n=new T.Vector3(-(crown-eave)*da,wallHalf*Math.cos(phi),0).normalize();rn.push(n.x,n.y,n.z);
 }
 for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){const k=j*(cols+1)+i,n=k+cols+1;ri.push(k,n,k+1,k+1,n,n+1)}
 const roof=new T.BufferGeometry();roof.setAttribute('position',new T.Float32BufferAttribute(rv,3));roof.setAttribute('normal',new T.Float32BufferAttribute(rn,3));roof.setIndex(ri);
 const shell=new T.Mesh(roof,m.paint);shell.name='81-714-roof';shell.userData.structuralRole='outer-roof';root.add(shell);
 for(const side of [-1,1])for(let i=0;i<13;i++){
  const z=-7.68+i*1.28,hood=library.ventTemplates[side>0?1:0].clone(true);
  hood.position.z+=z;hood.position.y+=roofY(side*.94,z)-library.ventReferenceY;root.add(hood);
 }
 const endShape=new T.Shape();endShape.moveTo(-wallHalf,eave-.015);
 for(let i=0;i<=cols;i++){const x=wallHalf*Math.sin(-Math.PI/2+Math.PI*i/cols);endShape.lineTo(x,roofY(x,L/2))}endShape.lineTo(wallHalf,eave-.015);endShape.closePath();
 const capGeometry=new T.ShapeGeometry(endShape,16);
 for(const sign of [-1,1]){
  const cap=new T.Mesh(capGeometry,m.paint);cap.position.z=sign*L/2;root.add(cap);
  const end=createIntercarEnd({floor:F,width:2*wallHalf,eave:eave-.015,materials:library.intercarMaterials});end.position.z=sign*L/2;if(sign<0)end.rotation.y=Math.PI;root.add(end);
 }
 root.add(library.underframe.clone(true));
 root.traverse(o=>{if(o.isMesh&&!o.userData.keepOriginalLayer)o.layers.set(2)});
 return {root,type:'81-714',windows,leaves,doorCenters,length:L,hasCab:false};
}

// Object copies keep BufferGeometry, Texture and Material identity shared.
// Door/window registries are rebound to each copy's own transform nodes.
export function cloneCar(template){
 const root=template.root.clone(true),old=[],copies=[];template.root.traverse(o=>old.push(o));root.traverse(o=>copies.push(o));
 const map=new Map(old.map((o,i)=>[o,copies[i]]));
 return {...template,root,leaves:template.leaves.map(d=>({...d,leaf:map.get(d.leaf)})),windows:template.windows.map(w=>({...w,pane:map.get(w.pane)}))};
}

export function assembleConsist(templates,types=['81-717','81-714','81-714','81-717'],gap=.80){
 if(types.length<2||types[0]!=='81-717'||types.at(-1)!=='81-717'||types.slice(1,-1).some(t=>t!=='81-714'))throw new Error('Use two outward head cars and intermediate 81-714 cars');
 const root=new T.Group();root.name='81-717-714-consist';const cars=[];let z=0;
 for(let i=0;i<types.length;i++){
  const car=cloneCar(templates[types[i]]);car.index=i;car.root.name=`car-${i+1}-${car.type}`;car.root.position.z=z;
  if(i===types.length-1)car.root.rotation.y=Math.PI;
  root.add(car.root);cars.push(car);z+=car.length+gap;
 }
 root.updateMatrixWorld(true);return {root,cars,gap,length:z-gap};
}
