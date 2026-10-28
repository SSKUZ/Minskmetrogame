import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile,access} from 'node:fs/promises';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {comparePixels,comparePhoto,compareProtectedFront} from './wagon-image-compare.mjs';
import {verifyFrontProtection} from './wagon-front-protection.mjs';
import {checkContinuity} from './wagon-continuity.mjs';

const output=process.env.WAGON_RESULTS_DIR||'test-results/wagon';
const baseline=process.env.WAGON_BASELINE_DIR||'test-results/wagon-baseline';
const target=process.env.WAGON_TARGET_URL||'http://127.0.0.1:8765/preview/wagon.html';
const viewModes=process.env.WAGON_VIEWS?.split(',')||['reference','front','side','outside','driver','salon','side-full','side-angle','door-close','window-close','window-inside','door-open','roof-side','roof-join','quarter-45','roof-overview','cab-roof-join','cab-wall-join'];
assert.ok(!process.env.GITHUB_ACTIONS||!process.env.WAGON_VIEWS,'CI must capture every view');
await mkdir(output,{recursive:true});
const reference=JSON.parse(await readFile('tests/reference/uruchcha-81-717.json','utf8'));
const sourceHtml=await readFile('preview/wagon.html','utf8');
const frontLock=await verifyFrontProtection(sourceHtml);
const stage4Cameras=JSON.parse(await readFile('tests/reference/stage4-cameras.json','utf8'));
const stage4Base=JSON.parse(await readFile('tests/reference/stage4-v88.json','utf8'));
const v88Fixture=await readFile(`tests/reference/${stage4Base.fixture}`,'utf8');
assert.equal(createHash('sha256').update(v88Fixture).digest('hex'),stage4Base.sha256,'Immutable v88 fixture changed');
const continuityCode=sourceHtml.slice(sourceHtml.indexOf('// Measured structural continuity:'),sourceHtml.indexOf('// End measured structural continuity.')+'// End measured structural continuity.'.length);
const controlledV88=v88Fixture.replace('const captureMode=',`Object.assign(cameraPresets,${JSON.stringify(stage4Cameras)});\nconst captureMode=`).replace('window.wagonFrontGlassTriangles=',continuityCode+'\nwindow.wagonFrontGlassTriangles=');
const continuityViews=['side-full','front','quarter-45','roof-overview','cab-roof-join','cab-wall-join'];
const unchangedRegions=[['saloon','// Longitudinal benches','// Front fascia based'],['passenger windows','function buildPassengerBay(','function doorOutline(']];
for(const [name,start,end] of unchangedRegions){
 const extract=text=>text.slice(text.indexOf(start),text.indexOf(end,text.indexOf(start)));
 assert.equal(moduleHashSafe(extract(sourceHtml)),moduleHashSafe(extract(v88Fixture)),`Stage 4 changed protected ${name}`);
}
function moduleHashSafe(text){return createHash('sha256').update(text).digest('hex')}
const expectedModule=sourceHtml.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
const moduleHash=text=>createHash('sha256').update(text).digest('hex');
const photo=await readFile(`tests/reference/${reference.image}`);
assert.equal(createHash('sha256').update(photo).digest('hex'),reference.sha256,'Reference photo changed without new annotations');
const launch={headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage','--no-sandbox']};
if(process.env.WAGON_CHROMIUM_EXECUTABLE){launch.executablePath=process.env.WAGON_CHROMIUM_EXECUTABLE;launch.args.push('--single-process','--in-process-gpu','--no-zygote');}
if(process.env.HTTPS_PROXY&&process.env.WAGON_USE_PROXY==='1')launch.proxy={server:process.env.HTTPS_PROXY,bypass:'127.0.0.1,localhost'};
const browser=await chromium.launch(launch);
const page=await browser.newPage({viewport:{width:1536,height:934},deviceScaleFactor:1,reducedMotion:'reduce',locale:'ru-RU',timezoneId:'UTC'});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
// Node's request context can use the runtime's trusted proxy CA when the
// local Chromium certificate store lacks it. HTTPS verification stays enabled.
if(process.env.WAGON_FETCH_HTML==='1')await page.route('https://**/wagon.html*',async route=>{
 const response=await route.fetch();await route.fulfill({response});
});
// Optional fixtures for restricted local runtimes. CI uses its HTTP server.
if(process.env.WAGON_LOCAL_ROOT)await page.route('http://127.0.0.1:8765/**',async route=>{
 const file=path.resolve(process.env.WAGON_LOCAL_ROOT,'.'+new URL(route.request().url()).pathname);
 assert.ok(file.startsWith(path.resolve(process.env.WAGON_LOCAL_ROOT)+path.sep));
 await route.fulfill({path:file,contentType:file.endsWith('.html')?'text/html':'application/javascript'});
});
if(process.env.WAGON_ASSET_DIR)await page.route('https://cdn.jsdelivr.net/npm/three@0.160.1/**',async route=>{
 const filename=route.request().url().endsWith('OrbitControls.js')?'OrbitControls.js':'three.module.js';
 await route.fulfill({path:path.join(process.env.WAGON_ASSET_DIR,filename),contentType:'application/javascript',headers:{'access-control-allow-origin':'*'}});
});
let previous=null;
try{previous=JSON.parse(await readFile(path.join(baseline,'report.json'),'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
const report={result:'running',commit:process.env.GITHUB_SHA||execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),runUrl:process.env.GITHUB_RUN_ID?`${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`:null,target,referenceSha256:reference.sha256,baselineCommit:previous?.commit||null,captureProfile:{width:1536,height:934,deviceScaleFactor:1,mode:'fixed-camera-no-ui-v1'},views:[],comparisons:[],errors};
report.sourceModuleSha256=moduleHash(expectedModule);
report.workingTreeDirty=!process.env.GITHUB_ACTIONS&&!!execFileSync('git',['status','--porcelain','--untracked-files=no'],{encoding:'utf8'}).trim();
try{
 // Render the immutable v84 in this exact Chromium/GPU, avoiding false
 // regressions caused by historical screenshots from another renderer.
 await page.route('**/__wagon_v84.html*',route=>route.fulfill({body:frontLock.fixture,contentType:'text/html'}));
 await page.goto(new URL('__wagon_v84.html?qa=1&view=front',target).href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 await page.screenshot({path:path.join(output,'protected-v84-front.png'),animations:'disabled',timeout:90000});
 const immutableFrontGeometry=(await page.evaluate(()=>window.wagonDiagnostics())).features;
 report.frontProtection={baseCommit:frontLock.baseCommit,protectedBlocks:frontLock.protectedBlocks};
 // The original v88 geometry is rendered, with only common inspection
 // cameras and a read-only measuring function injected into its module.
 await page.route('**/__wagon_v88.html*',route=>route.fulfill({body:controlledV88,contentType:'text/html'}));
 await page.goto(new URL('__wagon_v88.html?qa=1',target).href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.wagonReady&&window.wagonDiagnostics().renderedFrames>=3,null,{timeout:90000});
 report.v88Control={commit:stage4Base.baseCommit,fixtureSha256:stage4Base.sha256,cameraOverrides:stage4Cameras,measurements:await page.evaluate(()=>window.wagonContinuityDiagnostics()),layout:await page.evaluate(()=>window.wagonSideDiagnostics())};
 await writeFile(path.join(output,'v88-geometry.json'),JSON.stringify(report.v88Control,null,2));
 for(const mode of continuityViews){
  const frame=await page.evaluate(m=>{window.wagonSetCamera(m);return window.wagonDiagnostics().renderedFrames},mode);
  await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,frame,{timeout:30000});
  await page.screenshot({path:path.join(output,`before-v88-${mode}.png`),animations:'disabled',timeout:90000});
 }
 const url=new URL(target);url.searchParams.set('qa','1');url.searchParams.set('formation','single');
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 report.renderedModuleSha256=moduleHash(await page.locator('script[type="module"]').textContent());
 assert.equal(report.renderedModuleSha256,report.sourceModuleSha256,'Served model differs from the checked-out source: stale publication or wrong target');
 await page.waitForFunction(()=>window.wagonReady===true&&window.wagonDiagnostics?.().renderedFrames>=3,null,{timeout:90000});
 const version=await page.evaluate(()=>window.wagonDiagnostics().modelVersion);
 const currentLayout=await page.evaluate(()=>window.wagonSideDiagnostics());
 assert.deepEqual(currentLayout.windows,report.v88Control.layout.windows,'Passenger apertures moved relative to the saloon');
 const homes=layout=>layout.leaves.map(({side,doorZ,homeZ,x,thickness})=>({side,doorZ,homeZ,x,thickness}));
 assert.deepEqual(homes(currentLayout),homes(report.v88Control.layout),'Passenger door home positions changed');
 report.continuity=checkContinuity(await page.evaluate(()=>window.wagonContinuityDiagnostics()),version);
 await writeFile(path.join(output,'current-geometry.json'),JSON.stringify(report.continuity,null,2));
 if(await page.evaluate(()=>!!window.wagonAdvanceDoors)){
  report.doorMotion=await page.evaluate(()=>{
   const travel=dt=>{window.wagonSetDoors(false,{instant:true});window.wagonSetDoors(true);for(let i=0;i<Math.round(1/dt);i++)window.wagonAdvanceDoors(dt);return window.wagonSideDiagnostics().leaves.map(d=>d.z)};
   const at60=travel(1/60),at30=travel(1/30),sweep=[];
   for(const progress of [0,.25,.50,.75,1]){
    window.wagonSetDoors(false,{instant:true});window.wagonSetDoors(true);
    for(let i=0;i<31*progress;i++)window.wagonAdvanceDoors(1.55*progress/Math.ceil(31*progress));
    sweep.push({progress:window.wagonSideDiagnostics().doorProgress,...window.wagonApertureChecks()});
   }
   window.wagonSetDoors(false,{instant:true});return {at60,at30,sweep};
  });
  for(let i=0;i<16;i++)assert.ok(Math.abs(report.doorMotion.at60[i]-report.doorMotion.at30[i])<1e-8,'Frame rate changes door travel');
  for(const pose of report.doorMotion.sweep)assert.equal(pose.pocketCollisions,0,'Door intersects a pocket during its sweep');
 }
 for(const mode of viewModes){
  await page.evaluate(m=>window.wagonSetDoors?.(m==='door-open',{instant:true}),mode);
  const start=await page.evaluate(m=>{window.wagonSetCamera(m);return window.wagonDiagnostics().renderedFrames},mode);
  await page.waitForFunction(frame=>window.wagonDiagnostics().renderedFrames>=frame+3,start,{timeout:30000});
  const data=await page.evaluate(()=>window.wagonDiagnostics());
  data.passenger=await page.evaluate(()=>window.wagonSideDiagnostics?.()||null);
  if(data.passenger){
   assert.equal(data.passenger.leafCount,16);assert.equal(data.passenger.windowCount,8);
   assert.ok(data.passenger.wallThickness>.1,'Real wall depth missing');
   if('roofScoops' in data.passenger)assert.equal(data.passenger.roofScoops,26);
   if('invertedWallNormals' in data.passenger)assert.equal(data.passenger.invertedWallNormals,0,'Side face winding contradicts the lighting normals');
   if(data.passenger.interior){assert.equal(data.passenger.interior.seatCount,40);assert.equal(data.passenger.interior.allSeatsVolumetric,true);assert.ok(data.passenger.interior.aisleWidth>=1.4);}
   if(mode==='door-open')assert.ok(Math.abs(data.passenger.doorClearWidth-1.208)<.001,'Open leaves must leave the measured clear aperture');
   if(mode==='window-close'||mode==='door-open'){
    data.apertures=await page.evaluate(()=>window.wagonApertureChecks());
    report.lastApertureCheck=data.apertures;
    assert.equal(data.apertures.windowBlocked,0,'Opaque geometry covers a passenger window');
    assert.equal(data.apertures.pocketCollisions,0,'Door leaf intersects its wall pocket');
    if(mode==='door-open')assert.equal(data.apertures.openDoorBlocked,0,'Open doorway has opaque obstructions');
   }
  }
  if(process.env.WAGON_EXPECT_VERSION)assert.equal(data.modelVersion,Number(process.env.WAGON_EXPECT_VERSION),'Published model version is stale');
  assert.equal(data.cameraMode,mode);assert.ok(data.meshCount>100);assert.equal(data.renderWidth,1536);assert.equal(data.renderHeight,934);
  assert.deepEqual(data.frontFeatures,{upperRedLamps:2,lowerLamps:6,frontGlazingSections:3,destinationDisplay:'blank',reference:'user-supplied-front-photo'});
  assert.ok(data.features.fascia&&data.features['window-center']);
  if(mode==='reference')for(const [name,bounds] of Object.entries(data.features)){
   for(const key of ['x','y','width','height'])assert.ok(Number.isFinite(bounds[key]),name+' has invalid projected geometry');
   assert.ok(bounds.width>0&&bounds.height>0,name+' has empty projected geometry');
  }
  for(const [prefix,count] of [['headlamp-',6],['marker-',2],['window-',3]])assert.equal(Object.keys(data.features).filter(k=>k.startsWith(prefix)).length,count,'Actual registered front meshes: '+prefix);
  const screenshot=path.join(output,`${mode}.png`);
  await page.screenshot({path:screenshot,timeout:90000,animations:'disabled'});
  report.views.push({...data,screenshot:`${mode}.png`});
  const old=previous?.views?.find(v=>v.cameraMode===mode);
  if(old?.features)assert.deepEqual(Object.keys(data.features).sort(),Object.keys(old.features).sort(),'A registered feature disappeared');
  let comparison={mode,status:'no-compatible-baseline'};
  try{
   await access(path.join(baseline,`${mode}.png`));
   comparison={mode,...await comparePixels(screenshot,path.join(baseline,`${mode}.png`),path.join(output,`${mode}-diff.png`)),lightingChanged:!!old&&old.lightingPreset!==data.lightingPreset,sideLightingChanged:old?.passenger?.lightingPreset!==data.passenger?.lightingPreset,cameraChanged:!!old&&JSON.stringify(old.camera)!==JSON.stringify(data.camera)};
  }catch(error){if(error.code!=='ENOENT')throw error;}
  report.comparisons.push(comparison);
  if(continuityViews.includes(mode)){
   report.v88Comparisons??=[];
   const comparison=await comparePixels(screenshot,path.join(output,`before-v88-${mode}.png`),path.join(output,`v88-${mode}-diff.png`));
   report.v88Comparisons.push({mode,...comparison});
   if(version===89)assert.equal(comparison.changedPixels,0,'Diagnostic release must retain v88 geometry');
  }
  if(mode==='front'){
   const character=features=>Object.fromEntries(Object.entries(features).filter(([name])=>!frontLock.stage4||name!=='roof'));
   assert.deepEqual(character(data.features),character(immutableFrontGeometry),'Projected front equipment differs from v84');
   const triangles=await page.evaluate(stage4=>stage4?window.wagonProtectedFrontTriangles():window.wagonFrontGlassTriangles?.()||[],frontLock.stage4);
   report.frontProtection.policy=frontLock.stage4?'Stage 4 permits structural roof/corner changes; facade and equipment remain fixed':'Full front outside transparent glazing';
   report.frontProtection.pixels=triangles.length?await compareProtectedFront(screenshot,path.join(output,'protected-v84-front.png'),path.join(output,'protected-front-diff.png'),triangles,frontLock.stage4?'include-equipment':'exclude-glazing'):await comparePixels(screenshot,path.join(output,'protected-v84-front.png'),path.join(output,'protected-front-diff.png'));
   assert.equal(report.frontProtection.pixels.changedPixels,0,'Protected front differs from immutable v84');
  }
  if(mode==='reference')report.photo=await comparePhoto(data.features,reference,screenshot,path.join(output,'reference-geometry-overlay.png'));
  if(mode==='window-inside'&&await page.evaluate(()=>!!window.wagonShiftInspectionCamera)){
   const f=await page.evaluate(()=>{window.wagonShiftInspectionCamera(.18);return window.wagonDiagnostics().renderedFrames});
   await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,f);
   const shifted=path.join(output,'window-inside-parallax.png');await page.screenshot({path:shifted,animations:'disabled',timeout:90000});
   report.parallax={translationMetres:.18,...await comparePixels(shifted,screenshot,path.join(output,'window-inside-parallax-diff.png'))};
   assert.ok(report.parallax.changedPixels>300,'Moving alongside the window does not reveal changing perspective');
  }
 }
 assert.deepEqual(errors,[],'Wagon JavaScript errors');
 const frame=await page.evaluate(()=>{window.wagonSetDoors?.(false,{instant:true});window.wagonSetCamera('reference');return window.wagonDiagnostics().renderedFrames});
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,frame);
 await page.screenshot({path:path.join(output,'reference-repeat.png'),animations:'disabled',timeout:90000});
 report.repeat=await comparePixels(path.join(output,'reference.png'),path.join(output,'reference-repeat.png'),path.join(output,'repeat-diff.png'));
 assert.equal(report.repeat.changedPixels,0,'Frozen reference camera produced nondeterministic pixels');
 await page.setViewportSize({width:412,height:915});
 const mobileFrame=await page.evaluate(()=>{window.wagonSetCamera('reference');return window.wagonDiagnostics().renderedFrames});
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,mobileFrame);
 report.mobile=await page.evaluate(()=>window.wagonDiagnostics());
 const mobileFace=report.mobile.features.fascia;
 assert.ok(mobileFace.x>=0&&mobileFace.x+mobileFace.width<=412,'Reference fascia is clipped on a phone');
 await page.screenshot({path:path.join(output,'mobile-reference.png'),animations:'disabled',timeout:90000});
 report.result='pass';
}catch(error){report.result='fail';report.failure=error.stack;throw error;}
finally{
 await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));
 const changes=report.comparisons.map(c=>`| ${c.mode} | ${c.status} | ${c.changedPixels??'—'} | ${c.bounds?JSON.stringify(c.bounds):'—'} |`).join('\n');
 const geometryFields=[['Cab crown (m)','cabCrown',1],['Main crown (m)','mainCrown',1],['Wall plane mismatch (mm)','cabBodyPlaneDifference',1000],['Lower edge mismatch (mm)','sideBottomDifference',1000],['Roof-wall gap (mm)','roofWallGap',1000],['Brow-root gap (mm)','roofCapGap',1000],['Brow-root tangent angle (deg)','roofCapNormalAngle',1],['Maximum step / 20 mm (mm)','maximumRoofStep20mm',1000],['Samples with multiple roof heights','roofOverlapSamples',1]];
 const geometryRows=geometryFields.map(([label,key,scale])=>`| ${label} | ${((report.v88Control?.measurements?.[key]??0)*scale).toFixed(4)} | ${((report.continuity?.measurements?.[key]??0)*scale).toFixed(4)} |`).join('\n');
 const geometrySummary=`\n\n## Structural continuity\n\nStatus: **${report.continuity?.status||'not measured'}**. Geometry is measured from actual transformed triangles.\n\n| Measurement | Immutable v88 | Current |\n| --- | ---: | ---: |\n${geometryRows}\n\nEquipment pixel protection: ${report.frontProtection?.policy||'not captured'}. Source blocks protected: ${frontLock.protectedBlocks.length}; passenger windows and saloon source and placement also remain fixed.\n`;
 const metrics=(report.photo?.measurements||[]).map(m=>`| ${m.name} | ${m.status} | ${m.actual?m.actual.width.toFixed(4):'—'} | ${m.expected?m.expected.width.toFixed(4):'—'} | ${m.actual?m.actual.height.toFixed(4):'—'} | ${m.expected?m.expected.height.toFixed(4):'—'} |`).join('\n');
 const markdown=`# Wagon visual report\n\nTechnical result: **${report.result}**. Photo likeness requires visual review.\n\nCommit: ${report.commit}\n\nBaseline: ${report.baselineCommit||'none / older incompatible report'}\n\n${report.runUrl||'Local run'}${geometrySummary}\n\nProtected front equipment: **${report.frontProtection?.pixels?.changedPixels??'not captured'} changed pixels**; ${frontLock.protectedBlocks.length} pinned source regions and identical equipment projections. Full frontal frame: ${report.frontProtection?.pixels?.fullFrameChangedPixels??report.frontProtection?.pixels?.changedPixels??'not captured'} changes; authorized envelope/glazing changes: ${report.frontProtection?.pixels?.structuralEnvelopeAndGlazingChanges??report.frontProtection?.pixels?.glazingContentChangedPixels??0}. The complete unmasked difference is saved. Doors: ${report.doorMotion?'30/60 Hz and five sampled clearance poses checked':'not available'}.\n\n## Previous render\n\n| View | Status | Changed pixels | Bounds |\n| --- | --- | ---: | --- |\n${changes}\n\n## Photo geometry diagnostics\n\nDimensions are fractions of fascia width, not similarity percentages. Cyan: geometry; amber: photo.\n\n| Feature | Flag | Model width | Photo width | Model height | Photo height |\n| --- | --- | ---: | ---: | ---: | ---: |\n${metrics}\n\n## Limits\n\n${reference.limitations.map(s=>'- '+s).join('\n')}\n\nPixel differences can be intentional. Sampled clearance rays do not replace continuous collision detection. These reports do not prove the absence of visual defects.\n`;
 await writeFile(path.join(output,'report.md'),markdown);
 const images=[...continuityViews.map(m=>'before-v88-'+m),...report.views.map(v=>v.cameraMode),...(report.v88Comparisons||[]).map(c=>'v88-'+c.mode+'-diff'),'mobile-reference','protected-v84-front','protected-front-diff',...(report.frontProtection?.pixels?.fullFrameChangedPixels!==undefined?['protected-front-diff-full']:[]),...(report.parallax?['window-inside-parallax','window-inside-parallax-diff']:[]),'reference-geometry-overlay',...report.comparisons.filter(c=>c.status==='compared').map(c=>c.mode+'-diff')];
 await writeFile(path.join(output,'index.html'),`<!doctype html><meta charset="utf-8"><title>Wagon visual report</title><style>body{font:16px system-ui;background:#17202b;color:#eee;max-width:1600px;margin:auto;padding:24px}img{width:100%;height:auto}pre{white-space:pre-wrap}</style><h1>Wagon ${report.views[0]?.modelVersion||''} · ${report.commit}</h1><p>Technical result: ${report.result}. Geometry diagnostics require visual review.</p><p>Cyan: model bounds. Amber: photo bounds aligned to fascia.</p>${images.map(i=>`<h2>${i}</h2><img src="${i}.png" alt="${i}">`).join('')}<pre>${JSON.stringify(report,null,2).replaceAll('&','&amp;').replaceAll('<','&lt;')}</pre>`);
 await browser.close();
}
console.log(JSON.stringify({result:report.result,commit:report.commit,baselineCommit:report.baselineCommit,views:report.views.map(v=>v.cameraMode),repeatChangedPixels:report.repeat?.changedPixels,photoReview:report.photo.measurements.filter(m=>m.status==='review').map(m=>m.name)}));
