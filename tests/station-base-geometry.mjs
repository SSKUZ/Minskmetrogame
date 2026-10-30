import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {pathToFileURL} from 'node:url';
import {createStationBase} from '../js/station-base/StationBase.js';
import {createV106Adapter,cloneV106Consist} from '../js/station-base/V106Adapter.js';
import {renderStation} from '../js/station-base/WebSceneAdapter.js';
import {measureHeightBand,validateActualGeometry,validateTrainSeparation} from '../js/station-base/GeometryValidation.js';
const sourceRoot=path.resolve(process.argv[2]??'.'),three=path.resolve(process.argv[3]??'node_modules/three/build/three.module.js'),out=path.resolve(process.argv[4]??'test-results/station-base/geometry.json'),temp=await fs.mkdtemp(path.join(os.tmpdir(),'station-base-'));
process.argv=[process.argv[0],'research-audit',sourceRoot,three,path.join(temp,'source.json')];
await import(pathToFileURL(path.join(sourceRoot,'docs/stations/malinovka/tools/audit-v106-standard-cpu.mjs')).href);
const T=globalThis.__auditThree,original=globalThis.__auditConsist.consist;
function geometryHash(){const h=crypto.createHash('sha256'),seen=new Set();original.root.traverse(o=>{if(o.isMesh&&!seen.has(o.geometry)){seen.add(o.geometry);for(const a of [...Object.values(o.geometry.attributes),o.geometry.index].filter(Boolean))h.update(Buffer.from(a.array.buffer,a.array.byteOffset,a.array.byteLength));}});return h.digest('hex');}
const before=geometryHash(),scenarios=[],negative=[];
for(const direction of [-1,1]){
 const base=createStationBase({direction}),scene=new T.Scene(),view=renderStation(T,scene,base),other=cloneV106Consist(original);scene.add(original.root,other.root);
 const adapters=[original,other].map((c,i)=>{const s=base.modules.stops[i];const a=createV106Adapter(T,c.root,c,base.profile,s.servedSide,s.direction);a.place(s.frontZ,s.trackX);a.doors(0);return a;});
 for(let i=0;i<2;i++){
  const stop=base.modules.stops[i],a=adapters[i],p=base.station.platform,v=base.profile.validation;
  for(const progress of [0,.25,.5,.75,1]){
   a.place(stop.frontZ,stop.trackX);a.doors(progress);
   const band=await measureHeightBand(T,a.root,p.topY-p.thickness-v.verticalBudget,p.topY+v.verticalBudget);
   const result=validateActualGeometry(T,base,a.consist,{frontZ:stop.frontZ,doorProgress:progress,stop,band,railMeshes:view.railMeshes,platformMesh:view.platformMesh});
   assert.equal(result.ok,true,JSON.stringify({direction,i,progress,issues:result.issues,doors:result.doorErrors}));
   scenarios.push({track:stop.trackId,direction:stop.direction,phase:'doors',progress,contactCount:result.contactCount,servedDoorCount:result.servedDoorCount,bodyGap:result.bodyGap,sillGap:result.sillGap,checks:result.checks.map(c=>({id:c.id,ok:c.ok}))});
   if(progress===0){
    for(const distance of [110,60,15,0,-15,-60,-120]){
     const frontZ=stop.frontZ-stop.direction*distance;a.place(frontZ,stop.trackX);
     const pose=validateActualGeometry(T,base,a.consist,{frontZ,doorProgress:0,stop,band,railMeshes:view.railMeshes,platformMesh:view.platformMesh});assert.equal(pose.ok,true,JSON.stringify({direction,i,distance,issues:pose.issues}));
     scenarios.push({track:stop.trackId,direction:stop.direction,phase:'motion',frontZ,contactCount:pose.contactCount,bodyGap:pose.bodyGap,ok:pose.ok});
    }a.place(stop.frontZ,stop.trackX);
   }
  }a.doors(0);
 }
 const separation=validateTrainSeparation(T,adapters[0].root,adapters[1].root,base.profile.validation.epsilon);assert.equal(separation.ok,true);scenarios.push({phase:'train-separation',direction,...separation});
 // Mutate actual transforms/meshes to ensure the validator catches real errors.
 const a=adapters[0],stop=base.modules.stops[0],p=base.station.platform;a.root.position.x-=.05;a.root.updateMatrixWorld(true);
 const wrongBand=await measureHeightBand(T,a.root,p.topY-p.thickness,p.topY);
 const invalid=validateActualGeometry(T,base,a.consist,{frontZ:stop.frontZ,stop,band:wrongBand,railMeshes:view.railMeshes,platformMesh:view.platformMesh});
 assert.equal(invalid.ok,false);assert.ok(invalid.issues.includes('32 wheel contacts'));assert.ok(invalid.issues.includes('body/platform solid clearance'));negative.push({kind:'actual train lateral drift',direction,caught:invalid.issues});a.place(stop.frontZ,stop.trackX);
 view.railMeshes[0].position.y+=.02;const drift=validateActualGeometry(T,base,a.consist,{frontZ:stop.frontZ,stop,band:wrongBand,railMeshes:view.railMeshes,platformMesh:view.platformMesh});assert.equal(drift.ok,false);assert.ok(drift.issues.includes('4 rail mesh profiles'));negative.push({kind:'actual rail mesh raised',direction,caught:drift.issues});
 view.railMeshes[0].position.y-=.02;view.platformMesh.position.x+=.05;const shiftedSlab=validateActualGeometry(T,base,a.consist,{frontZ:stop.frontZ,stop,band:await measureHeightBand(T,a.root,p.topY-p.thickness,p.topY),railMeshes:view.railMeshes,platformMesh:view.platformMesh});assert.equal(shiftedSlab.ok,false);assert.ok(shiftedSlab.issues.includes('platform mesh extents'));assert.ok(shiftedSlab.issues.includes('body/platform solid clearance'));negative.push({kind:'actual platform slab shifted toward train',direction,caught:shiftedSlab.issues});
}
const after=geometryHash();assert.equal(after,before,'Actual train BufferGeometry changed');
const result={ok:true,sourceAssetCommit:createStationBase().profile.assetCommit,threeRevision:T.REVISION,scenarios,negative,geometryBytesUnchanged:before===after,geometrySha256:after,summary:{wheelChecksPerPose:32,doorsPerSide:16,railMeshes:4,trackDirectionCombinations:4,scenarioCount:scenarios.length,negativeCases:negative.length},limits:['CPU geometry execution; browser WebGL test is separate','No full passenger runtime','Straight and level only']};
await fs.mkdir(path.dirname(out),{recursive:true});await fs.writeFile(out,JSON.stringify(result,null,2)+'\n');await fs.rm(temp,{recursive:true,force:true});console.log(JSON.stringify(result.summary));
