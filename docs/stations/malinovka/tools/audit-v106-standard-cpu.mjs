import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {pathToFileURL} from 'node:url';
import crypto from 'node:crypto';
const [sourceRootArg='.',threeArg='research-code/dependencies/three160.module.mjs',outArg='tz12-audit.json']=process.argv.slice(2);
const sourceRoot=path.resolve(sourceRootArg),threePath=path.resolve(threeArg);
const N=await import(pathToFileURL(threePath).href);
const context=new Proxy({measureText:s=>({width:s.length*10})},{get:(o,k)=>k in o?o[k]:(...args)=>undefined,set:(o,k,v)=>(o[k]=v,true)});
const element=()=>({style:{},children:[],width:1,height:1,addEventListener(){},removeEventListener(){},appendChild(x){this.children.push(x)},setAttribute(){},getContext(){return context}});
const els=new Map();
globalThis.document={createElement:element,body:element(),head:element(),getElementById:id=>{if(!els.has(id))els.set(id,element());return els.get(id)},querySelectorAll:()=>[]};
globalThis.window=globalThis;globalThis.innerWidth=1280;globalThis.innerHeight=720;globalThis.devicePixelRatio=1;globalThis.location={search:'?formation=train&gameExport=1'};
globalThis.addEventListener=()=>{};
class Renderer{constructor(){this.domElement=element();this.capabilities={getMaxAnisotropy:()=>1};this.info={render:{},memory:{},reset(){}}}setSize(){}setPixelRatio(){}render(){}getPixelRatio(){return 1}}
class PMREM{fromScene(){return {texture:new N.Texture(),dispose(){}}}dispose(){}}
class Loader{load(){return new N.Texture()}}
globalThis.__auditThree={...N,WebGLRenderer:Renderer,PMREMGenerator:PMREM,TextureLoader:Loader};
globalThis.__auditControls=class{constructor(){this.target=new N.Vector3()}update(){}addEventListener(){}};
const fileNames=['preview/wagon.html','preview/train-factory.js','preview/train-components.js','preview/train-batching.js','js/main.js'];
const sources={};for(const name of fileNames)sources[name]=await fs.readFile(path.join(sourceRoot,name),'utf8');
const scratch=await fs.mkdtemp(path.join(os.tmpdir(),'v106-cpu-audit-'));
const replaceThree=s=>s.replace(/import \* as T from 'three';/g,'const T=globalThis.__auditThree;');
for(const name of ['train-components','train-factory','train-batching']){
 let s=replaceThree(sources[`preview/${name}.js`]).replaceAll("'./train-components.js?v=106'","'./train-components.mjs'");
 await fs.writeFile(path.join(scratch,name+'.mjs'),s);
}
globalThis.__auditBefore=[];
let script=sources['preview/wagon.html'].match(/<script type="module">([\s\S]*?)<\/script>/)[1];
script=script.slice(0,script.indexOf('const grid=new T.GridHelper'));
if(!script.includes('const consist=assembleConsist'))throw new Error('Geometry cutoff invalid');
script=replaceThree(script).replace("import {OrbitControls} from 'three/addons/controls/OrbitControls.js';",'const OrbitControls=globalThis.__auditControls;').replaceAll("'./train-components.js?v=106'","'./train-components.mjs'").replaceAll("'./train-factory.js?v=106'","'./train-factory.mjs'").replace("import {batchStaticCar} from './train-batching.js?v=106';",`import {batchStaticCar as originalBatch} from './train-batching.mjs';
function batchStaticCar(root){root.updateMatrixWorld(true);const record={name:root.name,thresholds:[],seats:[],rails:[]};root.traverse(o=>{if(o.userData.passengerSeat)record.seats.push({bounds:{min:new T.Box3().setFromObject(o,true).min.toArray(),max:new T.Box3().setFromObject(o,true).max.toArray()}});const gp=o.geometry?.parameters;if(gp?.path&&o.geometry.type==='TubeGeometry'&&saloonRails.some(r=>r.geometry===o.geometry)&&gp.radius<=.04){record.rails.push({kind:'tube',radius:gp.radius,curveType:gp.path.curveType,closed:gp.path.closed,tension:gp.path.tension,controlPoints:gp.path.points.map(p=>p.clone().applyMatrix4(o.matrixWorld).toArray()),points:Array.from({length:17},(_,i)=>gp.path.getPointAt(i/16).applyMatrix4(o.matrixWorld).toArray())});}else if(o.geometry?.type==='CylinderGeometry'&&Math.abs(gp.radiusTop-.018)<1e-8&&Math.abs(gp.height-18.406)<1e-6&&Math.abs(o.position.y-3.07)<1e-8){record.rails.push({kind:'cylinder',radius:gp.radiusTop,points:[new T.Vector3(0,-gp.height/2,0).applyMatrix4(o.matrixWorld).toArray(),new T.Vector3(0,gp.height/2,0).applyMatrix4(o.matrixWorld).toArray()]});}if(o.userData.passengerThreshold)record.thresholds.push({name:o.name,bounds:new T.Box3().setFromObject(o,true).toJSON?.()??{min:new T.Box3().setFromObject(o,true).min.toArray(),max:new T.Box3().setFromObject(o,true).max.toArray()}})});globalThis.__auditBefore.push(record);return originalBatch(root);}`);
script+='\nlet qaFramesRemaining=0; globalThis.__auditConsist={consist,scene,nominal:{L,W,F},setDoorProgress,carMeasurements};\n';
await fs.writeFile(path.join(scratch,'geometry.mjs'),script);
await import(pathToFileURL(path.join(scratch,'geometry.mjs')).href);
const {consist,nominal,setDoorProgress}=globalThis.__auditConsist;
const boxOf=o=>{const b=new N.Box3().setFromObject(o,true);return {min:b.min.toArray(),max:b.max.toArray(),size:b.getSize(new N.Vector3()).toArray()}};
function partBounds(mesh,part){const b=new N.Box3(),a=mesh.geometry.attributes.position,v=new N.Vector3();for(let i=part.vertexStart;i<part.vertexStart+part.vertexCount;i++)b.expandByPoint(v.fromBufferAttribute(a,i).applyMatrix4(mesh.matrixWorld));return {min:b.min.toArray(),max:b.max.toArray(),size:b.getSize(new N.Vector3()).toArray()};}
function capture(){consist.root.updateMatrixWorld(true);return consist.cars.map((car,i)=>{const result={index:i,type:car.type,rootPosition:car.root.position.toArray(),yaw:car.root.rotation.y,allMeshBounds:boxOf(car.root),thresholdNodes:0,negativeSideThresholdNodes:0,wheelNodes:0,wheels:[],thresholdParts:[],thresholdBounds:[],doorways:[]};
 car.root.traverse(o=>{if(o.userData.passengerThreshold){result.thresholdNodes++;result.thresholdBounds.push(boxOf(o));if(new N.Box3().setFromObject(o,true).getCenter(new N.Vector3()).x<0)result.negativeSideThresholdNodes++;}if(o.userData.wheel)result.wheelNodes++;if(o.isMesh)for(const p of o.userData.batchedParts??[]){if(p.wheel)result.wheels.push(partBounds(o,p));const localSize=p.bounds.max.map((v,j)=>v-p.bounds.min[j]);if(Math.abs(localSize[0]-.115)<1e-5&&Math.abs(localSize[1]-.009)<1e-5&&Math.abs(localSize[2]-1.355)<1e-5)result.thresholdParts.push(partBounds(o,p));}});
 const groups=new Map();for(const d of car.leaves){const key=d.side+':'+d.doorZ;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(d)}
 for(const leaves of groups.values()){const d=leaves[0],point=new N.Vector3(d.side,0,0).transformDirection(car.root.matrixWorld),center=new N.Vector3(0,0,d.doorZ).applyMatrix4(car.root.matrixWorld);result.doorways.push({id:`car-${i}/local-side-${d.side}/door-${d.doorZ}`,localZ:d.doorZ,worldSide:Math.sign(point.x),centerZ:center.z,leafZ:leaves.map(l=>l.leaf.position.z),leafBounds:leaves.map(l=>boxOf(l.leaf))});}
 return result;});}
const closed=capture();setDoorProgress(1);const opened=capture();
// Evaluate only the original placement constants and construction statements.
// This is an isolated CPU scene, not execution of the whole game main.js.
const main=sources['js/main.js'];
const names=['V106_PLATFORM_GAP','V106_WHEEL_CONTACT_X','V106_PLATFORM_THRESHOLD_OUTER_X','V106_PLATFORM_EDGE_X','V106_PLATFORM_FAR_EDGE_X','V106_PLATFORM_SURFACE_Y','islandWidth','islandCentre'];
const constants=names.map(n=>main.match(new RegExp('const '+n+'=[^;]+;'))?.[0]);if(constants.some(x=>!x))throw new Error('Missing original placement declaration');
const platformLine=main.split('\n').find(l=>l.startsWith('box(platform,islandWidth,.045,128'));
const railLine=main.split('\n').find(l=>l.startsWith('for(const x of [-V106_WHEEL_CONTACT_X'));
const stationFn=new Function('T',`const useExperimentalV106=true;const platform=new T.Group();const rail=new T.MeshBasicMaterial();const box=(parent,w,h,d,x,y,z,material)=>{const o=new T.Mesh(new T.BoxGeometry(w,h,d),material);o.position.set(x,y,z);parent.add(o);return o};const THREE=T;${constants.join('\n')}\n${platformLine}\n${railLine}\nreturn {platform,edgeX:V106_PLATFORM_EDGE_X,targetGap:V106_PLATFORM_GAP};`);
const station=stationFn(N);station.platform.updateMatrixWorld(true);const platformBounds=boxOf(station.platform.children[0]),rails=station.platform.children.slice(1).map(boxOf);
function sectionAt(root,y){
 root.updateMatrixWorld(true);let minX=Infinity,maxX=-Infinity,minPoint=null,maxPoint=null,segments=0;
 root.traverse(mesh=>{if(!mesh.isMesh)return;const g=mesh.geometry,a=g.attributes.position,index=g.index,bb=new N.Box3().setFromObject(mesh,true);if(y<bb.min.y-1e-9||y>bb.max.y+1e-9)return;const v=[new N.Vector3(),new N.Vector3(),new N.Vector3()];for(let i=0;i<(index?.count??a.count);i+=3){for(let j=0;j<3;j++)v[j].fromBufferAttribute(a,index?index.getX(i+j):i+j).applyMatrix4(mesh.matrixWorld);for(let j=0;j<3;j++){const p=v[j],q=v[(j+1)%3];if((p.y-y)*(q.y-y)>0||Math.abs(q.y-p.y)<1e-12)continue;const t=(y-p.y)/(q.y-p.y);if(t<0||t>1)continue;const pt=p.clone().lerp(q,t);segments++;if(pt.x<minX){minX=pt.x;minPoint=pt.toArray()}if(pt.x>maxX){maxX=pt.x;maxPoint=pt.toArray()}}}});
 return {y,minX,maxX,minPoint,maxPoint,intersections:segments,gapToCurrentNegativeEdge:minX-station.edgeX};
}
const platformSectionsOpen=consist.cars.map(c=>({car:c.index,atSurface:sectionAt(c.root,platformBounds.max[1]),atSill:sectionAt(c.root,.9605)}));
setDoorProgress(0);
const platformSectionsClosed=consist.cars.map(c=>({car:c.index,atSurface:sectionAt(c.root,platformBounds.max[1]),atSill:sectionAt(c.root,.9605)}));
const thresholdParts=closed.flatMap(c=>[...c.thresholdParts,...c.thresholdBounds]).filter(b=>(b.min[0]+b.max[0])/2<0);
const wheelParts=closed.flatMap(c=>c.wheels);
const matches=thresholdParts.map(b=>({minZ:b.min[2],maxZ:b.max[2],outerX:b.min[0],bottomY:b.min[1],topY:b.max[1],gap:b.min[0]-station.edgeX,step:b.max[1]-platformBounds.max[1]}));
const result={method:'Original v106 geometry builders and original batching executed on CPU; real BufferGeometry vertices and matrixWorld measured. Canvas, TextureLoader, WebGL renderer and PMREM are inert; no rendered image or GPU/browser verification.',dependencyRevision:N.REVISION,sourceRoot,sourceHashes:Object.fromEntries(Object.entries(sources).map(([k,v])=>[k,crypto.createHash('sha256').update(v).digest('hex')])),threeSha256:crypto.createHash('sha256').update(await fs.readFile(threePath)).digest('hex'),nominal,templatePreBatch:globalThis.__auditBefore,closed,opened,platformSectionsClosed,platformSectionsOpen,station:{platformBounds,rails,constructionStatements:[...constants,platformLine,railLine]},measurements:{platformSideThresholdParts:thresholdParts.length,thresholdNodes:closed.reduce((n,c)=>n+c.thresholdNodes,0),wheelNodes:closed.reduce((n,c)=>n+c.wheelNodes,0),wheelParts:wheelParts.length,platformTop:platformBounds.max[1],railTop:rails[0].max[1],wheelBottom:Math.min(...wheelParts.map(b=>b.min[1])),thresholds:matches},loaderGuard:{expectedPlatformSideThresholdNodes:16,actual:closed.reduce((n,c)=>n+c.negativeSideThresholdNodes,0)}};
result.measurements.wheelRailPenetration=result.measurements.railTop-result.measurements.wheelBottom;
const near=(a,b)=>Math.abs(a-b)<1e-5;
const checks={fourCars:closed.length===4,thresholds32:result.measurements.thresholdNodes===32,platformDoors16:result.loaderGuard.actual===16,wheels32:wheelParts.length===32,overlap320mm:near(result.measurements.wheelRailPenetration,.32),thresholdGap47_5mm:matches.every(m=>near(m.gap,.0475)),step35mm:matches.every(m=>near(m.step,.035)),all64LeavesMove600mm:closed.flatMap((c,i)=>c.doorways.flatMap((d,j)=>d.leafZ.map((z,k)=>near(Math.abs(opened[i].doorways[j].leafZ[k]-z),.6)))).length===64&&closed.every((c,i)=>c.doorways.every((d,j)=>d.leafZ.every((z,k)=>near(Math.abs(opened[i].doorways[j].leafZ[k]-z),.6))))};
result.acceptanceChecks=checks;result.sourceCommit='9a1a17bd68039a47e5ea0742bccd285dc100bf16';if(Object.values(checks).some(v=>!v))throw new Error(JSON.stringify(checks));

// Research-only analytic placement: a rigid translation, never persisted to game files.
const canonical=[0,.220,9.603];
const pointCanonical=p=>p.map((v,i)=>v+canonical[i]);
const canonicalWheels=closed.flatMap(c=>c.wheels.map((w,i)=>{const center=w.min.map((v,k)=>(v+w.max[k])/2),side=Math.sign(center[0]),contact=[center[0],w.min[1],center[2]],p=pointCanonical(contact),railX=side*.9;return {id:`c${c.index}-w${i}`,car:c.index,center:pointCanonical(center),contact:p,railX,verticalError:p[1],lateralError:p[0]-railX,wheelXInterval:[w.min[0],w.max[0]],railXInterval:[railX-.06,railX+.06]};}));
function clipY(poly,y,above){const out=[];for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],ia=above?a.y>=y:a.y<=y,ib=above?b.y>=y:b.y<=y;if(ia)out.push(a);if(ia!==ib)out.push(a.clone().lerp(b,(y-a.y)/(b.y-a.y)));}return out;}
function band(root,low,high){let minX=Infinity,maxX=-Infinity,triangles=0;root.updateMatrixWorld(true);root.traverse(mesh=>{if(!mesh.isMesh)return;const g=mesh.geometry,a=g.attributes.position,ix=g.index,bb=new N.Box3().setFromObject(mesh,true);if(bb.max.y<low||bb.min.y>high)return;for(let i=0;i<(ix?.count??a.count);i+=3){let poly=[0,1,2].map(k=>new N.Vector3().fromBufferAttribute(a,ix?ix.getX(i+k):i+k).applyMatrix4(mesh.matrixWorld));if(poly.every(p=>p.y<low)||poly.every(p=>p.y>high))continue;poly=clipY(clipY(poly,low,true),high,false);if(poly.length){triangles++;for(const p of poly){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);}}}});return {low,high,minX,maxX,triangles};}
const poses=[];for(const p of [0,.25,.5,.75,1]){setDoorProgress(p);poses.push({progress:p,slab200mm:band(consist.root,.7605,.9605),fullPlatformFace:band(consist.root,-.22,.9605),toleranceBand:band(consist.root,-.225,.9655)});}setDoorProgress(0);
const interior=consist.cars.map(car=>{const template=globalThis.__auditBefore.find(t=>t.name===car.type),matrix=car.root.matrixWorld;const toWorld=p=>pointCanonical(new N.Vector3(...p).applyMatrix4(matrix).toArray());return {car:car.index,type:car.type,seats:template.seats.map((s,i)=>{const b=s.bounds,center=b.min.map((v,k)=>(v+b.max[k])/2);return {id:`c${car.index}-seat-${i}`,cushionCenter:toWorld(center),cushionTopY:b.max[1]+canonical[1],side:Math.sign(toWorld(center)[0]),boundsLocal:b};}),rails:template.rails.map((r,i)=>({...r,id:`c${car.index}-rail-${i}`,points:r.points.map(toWorld),...(r.controlPoints?{controlPoints:r.controlPoints.map(toWorld)}:{})}))};});
const doorwayAnchors=closed.flatMap(car=>car.doorways.filter(d=>d.worldSide===-1).sort((a,b)=>a.centerZ-b.centerZ).map((d,i)=>{const sill=car.thresholdBounds.find(b=>b.min[0]<0&&Math.abs((b.min[2]+b.max[2])/2-d.centerZ)<1e-4);return {id:`c${car.index}-minus-door-${i}`,car:car.index,localSide:Math.sign(Math.cos(car.yaw))===1?-1:1,z:d.centerZ+canonical[2],thresholdX:sill.min[0],thresholdY:sill.max[1]+canonical[1],thresholdHalfLength:(sill.max[2]-sill.min[2])/2,normal:[-1,0,0]};}));
const openingProjections=opened.flatMap(c=>c.doorways.map(d=>{const b=[...d.leafBounds].sort((a,b)=>a.min[2]-b.min[2]);return {car:c.index,worldSide:d.worldSide,z:d.centerZ+canonical[2],width:b[1].min[2]-b[0].max[2]};}));
result.tz12={openingProjections,canonicalPlacement:canonical,canonicalConsistBounds:{min:pointCanonical(new N.Box3().setFromObject(consist.root,true).min.toArray()),max:pointCanonical(new N.Box3().setFromObject(consist.root,true).max.toArray())},wheels:canonicalWheels,doorwayAnchors,interior,poses,contactChecks:{all32:canonicalWheels.length===32,allVerticalWithin1um:canonicalWheels.every(w=>Math.abs(w.verticalError)<1e-6),allLateralWithin1um:canonicalWheels.every(w=>Math.abs(w.lateralError)<1e-6)},sourceNote:'Interior tube and slender-cylinder centrelines captured before batching, transformed with unchanged car matrices. Seat top is mesh-bound, not a human hip pose. Proposed coordinates are analytical only.'};
result.tz12.clearanceChecks={allFivePoses:poses.length===5,minClearanceAfter10mmOffset:Math.min(...poses.map(p=>1.370-Math.max(Math.abs(p.toleranceBand.minX),Math.abs(p.toleranceBand.maxX))-.010)),all32DoorOpenings:openingProjections.length===32&&openingProjections.every(d=>Math.abs(d.width-1.203)<1e-6)};
if(!Object.values(result.tz12.contactChecks).every(Boolean))throw new Error('Contact audit failed');

await fs.writeFile(outArg,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output:outArg,revision:N.REVISION,cars:closed.length,...result.measurements,thresholds:matches.slice(0,1),loaderGuard:result.loaderGuard},null,2));
await fs.rm(scratch,{recursive:true,force:true});
