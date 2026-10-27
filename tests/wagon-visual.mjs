import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdir,readFile,writeFile,access} from 'node:fs/promises';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {comparePixels,comparePhoto,compareProtectedSide} from './wagon-image-compare.mjs';

const output=process.env.WAGON_RESULTS_DIR||'test-results/wagon';
const baseline=process.env.WAGON_BASELINE_DIR||'test-results/wagon-baseline';
const target=process.env.WAGON_TARGET_URL||'http://127.0.0.1:8765/preview/wagon.html';
await mkdir(output,{recursive:true});
const reference=JSON.parse(await readFile('tests/reference/uruchcha-81-717.json','utf8'));
const sourceHtml=await readFile('preview/wagon.html','utf8');
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
 const url=new URL(target);url.searchParams.set('qa','1');
 await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
 report.renderedModuleSha256=moduleHash(await page.locator('script[type="module"]').textContent());
 assert.equal(report.renderedModuleSha256,report.sourceModuleSha256,'Served model differs from the checked-out source: stale publication or wrong target');
 await page.waitForFunction(()=>window.wagonReady===true&&window.wagonDiagnostics?.().renderedFrames>=3,null,{timeout:90000});
 for(const mode of ['reference','front','side','outside','driver','salon']){
  await page.evaluate(m=>window.wagonSetCamera(m),mode);
  const start=await page.evaluate(()=>window.wagonDiagnostics().renderedFrames);
  await page.waitForFunction(frame=>window.wagonDiagnostics().renderedFrames>=frame+3,start,{timeout:30000});
  const data=await page.evaluate(()=>window.wagonDiagnostics());
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
   comparison={mode,...await comparePixels(screenshot,path.join(baseline,`${mode}.png`),path.join(output,`${mode}-diff.png`)),lightingChanged:!!old&&old.lightingPreset!==data.lightingPreset,cameraChanged:!!old&&JSON.stringify(old.camera)!==JSON.stringify(data.camera)};
  }catch(error){if(error.code!=='ENOENT')throw error;}
  report.comparisons.push(comparison);
  if(mode==='side'&&comparison.status==='compared'){
   report.protectedSide=await compareProtectedSide(screenshot,path.join(baseline,'side.png'));
   assert.equal(report.protectedSide.changedPixels,0,'Protected rear body changed outside the permitted front work');
  }
  if(mode==='reference')report.photo=await comparePhoto(data.features,reference,screenshot,path.join(output,'reference-geometry-overlay.png'));
 }
 assert.deepEqual(errors,[],'Wagon JavaScript errors');
 await page.evaluate(()=>window.wagonSetCamera('reference'));
 const frame=await page.evaluate(()=>window.wagonDiagnostics().renderedFrames);
 await page.waitForFunction(n=>window.wagonDiagnostics().renderedFrames>=n+3,frame);
 await page.screenshot({path:path.join(output,'reference-repeat.png'),animations:'disabled'});
 report.repeat=await comparePixels(path.join(output,'reference.png'),path.join(output,'reference-repeat.png'),path.join(output,'repeat-diff.png'));
 assert.equal(report.repeat.changedPixels,0,'Frozen reference camera produced nondeterministic pixels');
 report.result='pass';
}catch(error){report.result='fail';report.failure=error.stack;throw error;}
finally{
 await writeFile(path.join(output,'report.json'),JSON.stringify(report,null,2));
 const changes=report.comparisons.map(c=>`| ${c.mode} | ${c.status} | ${c.changedPixels??'—'} | ${c.bounds?JSON.stringify(c.bounds):'—'} |`).join('\n');
 const metrics=(report.photo?.measurements||[]).map(m=>`| ${m.name} | ${m.status} | ${m.actual?m.actual.width.toFixed(4):'—'} | ${m.expected?m.expected.width.toFixed(4):'—'} | ${m.actual?m.actual.height.toFixed(4):'—'} | ${m.expected?m.expected.height.toFixed(4):'—'} |`).join('\n');
 const markdown=`# Wagon visual report\n\nTechnical result: **${report.result}**. Photo likeness requires visual review.\n\nCommit: ${report.commit}\n\nBaseline: ${report.baselineCommit||'none / older incompatible report'}\n\n${report.runUrl||'Local run'}\n\n## Previous render\n\n| View | Status | Changed pixels | Bounds |\n| --- | --- | ---: | --- |\n${changes}\n\n## Photo geometry diagnostics\n\nDimensions are fractions of fascia width, not similarity percentages. Cyan: geometry; amber: photo.\n\n| Feature | Flag | Model width | Photo width | Model height | Photo height |\n| --- | --- | ---: | ---: | ---: | ---: |\n${metrics}\n\n## Limits\n\n${reference.limitations.map(s=>'- '+s).join('\n')}\n\nPixel differences can be intentional. These reports do not prove the absence of visual defects.\n`;
 await writeFile(path.join(output,'report.md'),markdown);
 const images=['reference','front','side','reference-geometry-overlay',...report.comparisons.filter(c=>c.status==='compared').map(c=>c.mode+'-diff')];
 await writeFile(path.join(output,'index.html'),`<!doctype html><meta charset="utf-8"><title>Wagon visual report</title><style>body{font:16px system-ui;background:#17202b;color:#eee;max-width:1600px;margin:auto;padding:24px}img{width:100%;height:auto}pre{white-space:pre-wrap}</style><h1>Wagon ${report.views[0]?.modelVersion||''} · ${report.commit}</h1><p>Technical result: ${report.result}. Geometry diagnostics require visual review.</p><p>Cyan: model bounds. Amber: photo bounds aligned to fascia.</p>${images.map(i=>`<h2>${i}</h2><img src="${i}.png" alt="${i}">`).join('')}<pre>${JSON.stringify(report,null,2).replaceAll('&','&amp;').replaceAll('<','&lt;')}</pre>`);
 await browser.close();
}
console.log(JSON.stringify({result:report.result,commit:report.commit,baselineCommit:report.baselineCommit,views:report.views.map(v=>v.cameraMode),repeatChangedPixels:report.repeat?.changedPixels,photoReview:report.photo.measurements.filter(m=>m.status==='review').map(m=>m.name)}));
