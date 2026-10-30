import {STATION_MATERIALS} from '../../data/station-base/materials.js';
import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {loadV106Geometry} from '../train/V106GeometryLoader.js';
import {createStationBase} from './StationBase.js';
import {createV106Adapter,cloneV106Consist} from './V106Adapter.js';
import {renderStation} from './WebSceneAdapter.js';
import {measureHeightBand,validateActualGeometry,validateTrainSeparation} from './GeometryValidation.js';
import {setStaticOccupancy} from './TrackOccupancyContract.js';
import {DemoMotion} from './DemoMotion.js';
import {createSecondaryTrainDetailLOD} from './SecondaryTrainDetailLOD.js';
import {createOpposingTrainProxyLOD} from './OpposingTrainProxyLOD.js';
import {resolveGraphicsPreset} from './GraphicsPresets.js';
import {auditSceneResources} from './SceneResourceAudit.js';
import {createPlayerTrainDetailLOD} from './PlayerTrainDetailLOD.js';
const $=id=>document.getElementById(id),status=$('status');
let base=createStationBase(),scene=new THREE.Scene(),train,secondTrain,stationView,band,secondBand,lastReport,loading=true,dirty=true,busy=false,secondaryLOD,opposingProxyLOD,playerDetailLOD;
// Constrain framebuffer cost on mobile without changing source mesh geometry.
const graphicsDevice={userAgent:navigator.userAgent,deviceMemory:Number(navigator.deviceMemory||0),hardwareConcurrency:Number(navigator.hardwareConcurrency||0)};
const graphics=resolveGraphicsPreset(new URLSearchParams(location.search).get('quality'),graphicsDevice);
const lowMemory=graphics.name==='low';
const pixelRatioCap=graphics.dpr;
const renderer=new THREE.WebGLRenderer({antialias:!lowMemory,powerPreference:'high-performance',preserveDrawingBuffer:false});
renderer.setPixelRatio(Math.min(devicePixelRatio||1,pixelRatioCap));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.info.autoReset=false;
// Mobile diagnostic checkpoint: observations only; no changes to v106 geometry or rendering passes.
const diagnostic=document.createElement('div');
diagnostic.id='mobile-render-diagnostics';
diagnostic.style.cssText='position:fixed;right:8px;bottom:170px;z-index:50;background:#091827dc;color:#eaffff;padding:7px 10px;border-radius:7px;font:12px/1.45 monospace;pointer-events:none;white-space:pre;max-width:95vw';
diagnostic.textContent='GPU: initializing';
document.body.appendChild(diagnostic);
const gpuStats={context:'active',frames:0,windowStart:performance.now(),fps:0,lastFrameMs:0,error:''};
renderer.domElement.addEventListener('webglcontextlost',event=>{event.preventDefault();gpuStats.context='LOST';gpuStats.error='WebGL context lost';diagnostic.textContent='GPU: LOST — reload if not restored';setStatus('WebGL-контекст потерян. Ожидание восстановления.',true);});
renderer.domElement.addEventListener('webglcontextrestored',()=>{gpuStats.context='restored';gpuStats.error='';dirty=true;setStatus('WebGL-контекст восстановлен.');});
window.addEventListener('error',event=>{gpuStats.error=String(event.message||'JavaScript error').slice(0,120);});
window.addEventListener('unhandledrejection',event=>{gpuStats.error=String(event.reason?.message||event.reason||'Promise rejected').slice(0,120);});
$('viewport').appendChild(renderer.domElement);scene.background=new THREE.Color(0xbccbd5);scene.fog=new THREE.Fog(0xbccbd5,170,390);
const camera=new THREE.PerspectiveCamera(53,innerWidth/innerHeight,.025,800),controls=new OrbitControls(camera,renderer.domElement);
controls.enableDamping=true;controls.maxDistance=300;controls.minDistance=.25;controls.maxPolarAngle=Math.PI*.98;
controls.addEventListener('change',()=>dirty=true);
scene.add(new THREE.HemisphereLight(0xffffff,0x465a68,2));const light=new THREE.DirectionalLight(0xfff4dc,2);light.position.set(-20,35,-20);scene.add(light);
stationView=renderStation(THREE,scene,base);
let motion=new DemoMotion(base.modules.stop,{doorSeconds:base.profile.door.animationSeconds});
const view=(name)=>{const sign=base.modules.stop.direction===-1?1:-1,z=motion.frontZ,center=z+sign*base.profile.train.nominalLength/2;let position,target;
 if(name==='edge'){position=[-2.4,1.8,base.modules.stop.doors[0].z+(z-base.modules.stop.frontZ)-2.2];target=[-1.25,1.25,base.modules.stop.doors[0].z+(z-base.modules.stop.frontZ)+.5];}
 else if(name==='wheels'){position=[3.2,.5,z+sign*.8];target=[.9,.13,z+sign*(base.profile.train.frontOffsetZ+Math.min(...base.profile.train.wheelLocalZ))];}
 else if(name==='top'){position=[-4.8,88,center];target=[-4.8,0,center-.1];}
 else {position=[-31,24,center-64];target=[-3,1.2,center-2.6];}
 camera.position.set(...position);controls.target.set(...target);controls.update();dirty=true;
 for(const button of document.querySelectorAll('[data-camera]'))button.classList.toggle('active',button.dataset.camera===name);
};view('overview');
function size(){renderer.setSize(innerWidth,innerHeight);camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();dirty=true;}size();window.addEventListener('resize',size);
function setStatus(text,error=false){status.textContent=text;status.style.color=error?'#ffad9c':'#b9e9dc';}
function sync(){if(!train)return;train.place(motion.frontZ,base.modules.stop.trackX);train.doors(motion.doorProgress);if(secondTrain){const stop=base.modules.stops[1];secondTrain.place(stop.frontZ,stop.trackX);secondTrain.doors(0);secondTrain.root.visible=$('second-train').checked;}const state=motion.phase==='approaching'?'APPROACHING':motion.phase==='departing'?'DEPARTING':motion.phase==='departed'?'EMPTY':motion.doorProgress>0?'BOARDING':'STOPPED';base.modules.occupancy[0]={...base.modules.occupancy[0],state,trainId:state==='EMPTY'?null:'v106-player',mode:'demo-kinematics'};dirty=true;updateHUD();}
function updateHUD(){
 $('front-z').textContent=motion.frontZ.toFixed(3).replace('.',',')+' м';
 $('motion-state').textContent=({stopped:'Остановка',approaching:'Подъезд',departing:'Отправление',departed:'За платформой'})[motion.phase];
 $('door-state').textContent=motion.doorProgress===0?'Двери закрыты':motion.doorProgress===1?'Двери открыты':'Двери в движении';
 for(const id of ['arrive','stop','open','close','depart','reset'])$(id).disabled=loading||busy;
 $('open').disabled=loading||busy||motion.phase!=='stopped'||motion.doorProgress!==0||motion.doorTarget!==0;
 $('close').disabled=loading||busy||motion.doorProgress===0;
 $('depart').disabled=loading||busy||motion.phase!=='stopped'||motion.doorProgress!==0||motion.doorTarget!==0;
 $('arrive').disabled=loading||busy||motion.doorProgress!==0||motion.doorTarget!==0;
 $('validate').disabled=loading||busy;
}
function showReport(report){
 lastReport=report;$('report-json').textContent=JSON.stringify(report,null,2);
 $('wheels').textContent=report.ok?'32 / 32':report.contactCount+' / 32';$('doors').textContent=report.servedDoorCount+' / 16';
 $('body-gap').textContent=report.bodyGap===null?'—':(report.bodyGap*1000).toFixed(1)+' мм';$('sill-gap').textContent=(report.sillGap*1000).toFixed(1)+' мм';
 $('step').textContent=(Math.max(...report.doorErrors.map(d=>Math.abs(d.step)))*1000).toFixed(2)+' мм';
 $('checks').replaceChildren(...report.checks.map(c=>{const d=document.createElement('div');d.className='check '+(c.ok?'pass':'fail');d.textContent=(c.ok?'✓ ':'✕ ')+c.id;return d;}));
 setStatus(report.ok?'Проверки mesh пройдены · '+report.checks.length+'/'+report.checks.length:'Ошибка: '+report.issues.join(', '),!report.ok);
}
function audit(){if(!train||busy)return;sync();const report=validateActualGeometry(THREE,base,train.consist,{frontZ:motion.frontZ,doorProgress:motion.doorProgress,band,railMeshes:stationView.railMeshes,platformMesh:stationView.platformMesh});if(secondTrain){const stop=base.modules.stops[1];report.second=validateActualGeometry(THREE,base,secondTrain.consist,{frontZ:stop.frontZ,doorProgress:0,band:secondBand,railMeshes:stationView.railMeshes,platformMesh:stationView.platformMesh,stop});report.separation=validateTrainSeparation(THREE,train.root,secondTrain.root,base.profile.validation.epsilon);report.checks.push({id:'second v106 track/datum/clearance',ok:report.second.ok},{id:'two-train separation',ok:report.separation.ok});report.ok=report.ok&&report.second.ok&&report.separation.ok;if(!report.second.ok)report.issues.push('second-train: '+report.second.issues.join(', '));if(!report.separation.ok)report.issues.push('trains intersect');report.secondVisible=secondTrain.root.visible;}report.occupancy=base.modules.occupancy;report.runtime={three:THREE.REVISION,sourceThree:window.metroV106Metrics?.sourceThreeRevision,metrics:window.metroV106Metrics};showReport(report);return report;}
$('validate').onclick=audit;
$('arrive').onclick=()=>{lastTime=performance.now();if(motion.arrive()){sync();setStatus('Подъезд по прямому пути. Итоговый контроль — на остановке.');}};
$('stop').onclick=()=>{motion.stopNow();sync();audit();};
$('open').onclick=()=>{lastTime=performance.now();if(motion.setDoors(true)){sync();setStatus('Открываются 16 дверей со стороны платформы.');}};
$('close').onclick=()=>{lastTime=performance.now();motion.setDoors(false);sync();};
$('depart').onclick=()=>{lastTime=performance.now();if(motion.depart()){sync();setStatus('Отправление по прямому пути.');}};
$('reset').onclick=()=>{motion.reset();sync();view('overview');audit();};
$('second-train').onchange=()=>{if(secondTrain){secondTrain.root.visible=$('second-train').checked;base.modules.occupancy[1]=setStaticOccupancy(base.modules.occupancy[1],secondTrain.root.visible?'v106-opposing':null);$('second-state').textContent='Путь 2: '+base.modules.occupancy[1].state;audit();dirty=true;}};
$('markers').onchange=()=>{stationView.markers.visible=$('markers').checked;dirty=true;};
$('collapse').onclick=()=>{const body=$('panel-body');body.hidden=!body.hidden;$('collapse').textContent=body.hidden?'+':'−';};
for(const button of document.querySelectorAll('[data-camera]'))button.onclick=()=>view(button.dataset.camera);
$('export').onclick=()=>{if(!lastReport)return;const blob=new Blob([JSON.stringify({station:base.station,contract:base.modules.passengers,profile:base.profile,materials:STATION_MATERIALS,modules:base.modules,validation:lastReport},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='station-base-validation.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$('parameters').onsubmit=async e=>{e.preventDefault();if(loading||busy||motion.phase!=='stopped'||motion.doorProgress!==0){setStatus('Для изменения размеров остановите состав и закройте двери.',true);return;}
 try{const next=createStationBase({length:Number($('length').value),width:Number($('width').value),direction:Number($('direction').value)});
 const old=stationView.root;scene.remove(old);const gs=new Set(),ms=new Set();old.traverse(o=>{if(o.geometry)gs.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:[o.material])if(m)ms.add(m)});for(const g of gs)g.dispose();for(const m of ms){m.map?.dispose();m.dispose();}
 base=next;stationView=renderStation(THREE,scene,base);motion=new DemoMotion(base.modules.stop,{doorSeconds:base.profile.door.animationSeconds});train=createV106Adapter(THREE,train.root,train.consist,base.profile,base.modules.stop.servedSide,base.modules.stop.direction);secondTrain=createV106Adapter(THREE,secondTrain.root,secondTrain.consist,base.profile,base.modules.stops[1].servedSide,base.modules.stops[1].direction);base.modules.occupancy[1]=setStaticOccupancy(base.modules.occupancy[1],$('second-train').checked?'v106-opposing':null);sync();await measureBands();view('overview');audit();updateHUD();
 }catch(error){setStatus(error.message,true);}
};
let lastTime=performance.now(),lastRender=0,frames=0;
function loop(now){requestAnimationFrame(loop);const dt=Math.max(0,(now-lastTime)/1000);lastTime=Math.max(lastTime,now);
 const previousPhase=motion.phase,previousDoor=motion.doorProgress;const changed=motion.update(dt);if(changed)sync();controls.update();
 if(!loading&&!busy&&((previousPhase!==motion.phase)||(previousDoor!==motion.doorProgress&&(motion.doorProgress===0||motion.doorProgress===1))))audit();
 if(dirty&&playerDetailLOD)playerDetailLOD.update(camera,renderer.domElement.height);
 if(dirty&&opposingProxyLOD&&secondTrain?.root.visible&&opposingProxyLOD.update(camera)){if(!opposingProxyLOD.distant)secondaryLOD?.restore();}
 if(dirty&&secondaryLOD&&secondTrain?.root.visible&&!opposingProxyLOD?.distant)secondaryLOD.update(camera,renderer.domElement.height);
 if(dirty&&now-lastRender>=1000/20){lastRender=now;dirty=false;const renderStart=performance.now();renderer.info.reset();const background=scene.background;const perPass=[];
 const capturePass=(layer)=>{const beforeCalls=renderer.info.render.calls,beforeTriangles=renderer.info.render.triangles,start=performance.now();camera.layers.set(layer);renderer.render(scene,camera);perPass.push({layer,drawCalls:renderer.info.render.calls-beforeCalls,triangles:renderer.info.render.triangles-beforeTriangles,cpuMs:Math.round((performance.now()-start)*100)/100});};
 renderer.toneMapping=THREE.NoToneMapping;renderer.toneMappingExposure=1;capturePass(0);renderer.autoClear=false;scene.background=null;
 renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=.95;for(const layer of [2,1,3])capturePass(layer);
 scene.background=background;renderer.autoClear=true;camera.layers.set(0);
 window.metroRenderPassAudit={timestamp:new Date().toISOString(),quality:graphics.name,perPass,total:{drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles},note:'CPU wall time is not GPU frame time; pass counts include visibility and culling.'};
 ++frames;gpuStats.frames++;gpuStats.lastFrameMs=performance.now()-renderStart;
 if(now-gpuStats.windowStart>=2000){gpuStats.fps=gpuStats.frames*1000/(now-gpuStats.windowStart);gpuStats.frames=0;gpuStats.windowStart=now;}
 diagnostic.textContent='GPU: '+gpuStats.context+' | Quality: '+graphics.name+' | DPR: '+renderer.getPixelRatio().toFixed(2)+' | FPS(render): '+gpuStats.fps.toFixed(1)+' / cap 20'+'\n'+'Draw calls: '+renderer.info.render.calls+' | Triangles: '+(renderer.info.render.triangles/1e6).toFixed(2)+'M'+'\n'+'Render CPU: '+gpuStats.lastFrameMs.toFixed(1)+' ms | Train 2: '+(secondTrain?.root.visible?'ON':'OFF')+(gpuStats.error?'\nError: '+gpuStats.error:'');
 $('render-info').textContent=`${renderer.info.render.calls} вызовов · ${(renderer.info.render.triangles/1e6).toFixed(2)} млн треуг.`;
 }
}requestAnimationFrame(loop);
async function measureBands(){
 busy=true;updateHUD();const p=base.station.platform,v=base.profile.validation;
 band=await measureHeightBand(THREE,train.root,p.topY-p.thickness-v.verticalBudget,p.topY+v.verticalBudget,{yieldTask:()=>new Promise(r=>setTimeout(r,0)),onProgress:n=>setStatus('Измерение пути 1: '+Math.round(n*100)+'%')});
 secondBand=await measureHeightBand(THREE,secondTrain.root,p.topY-p.thickness-v.verticalBudget,p.topY+v.verticalBudget,{yieldTask:()=>new Promise(r=>setTimeout(r,0)),onProgress:n=>setStatus('Измерение пути 2: '+Math.round(n*100)+'%')});busy=false;
}
try{
 const root=await loadV106Geometry({THREE,scene,renderer}),consist=root.v106SourceFrame.contentWindow.wagonGetLiveConsist();
 train=createV106Adapter(THREE,root,consist,base.profile,base.modules.stop.servedSide,base.modules.stop.direction);
 playerDetailLOD=createPlayerTrainDetailLOD(THREE,consist,{hidePixels:graphics.name==='low'?2.5:graphics.name==='medium'?1.8:1.1,restorePixels:graphics.name==='low'?4:graphics.name==='medium'?3:2});
 const second=cloneV106Consist(consist);scene.add(second.root);secondTrain=createV106Adapter(THREE,second.root,second,base.profile,base.modules.stops[1].servedSide,base.modules.stops[1].direction);
 secondaryLOD=createSecondaryTrainDetailLOD(THREE,second.root,{hideBelowPixels:graphics.detailPixels,restoreAbovePixels:graphics.restorePixels});
 opposingProxyLOD=createOpposingTrainProxyLOD(THREE,second,{enterDistance:graphics.proxyEnter,exitDistance:graphics.proxyExit});
 base.modules.occupancy[1]=setStaticOccupancy(base.modules.occupancy[1],$('second-train').checked?'v106-opposing':null);$('second-state').textContent='Путь 2: STOPPED';sync();
 await measureBands();loading=false;busy=false;audit();updateHUD();dirty=true;
 // One-time, read-only resource snapshot; available to automation and browser console.
 window.metroSceneResourceAudit=auditSceneResources({scene,train,secondTrain,stationView,renderer});
 console.info('Station Base resource audit',window.metroSceneResourceAudit);
}catch(error){loading=false;busy=true;setStatus('Не удалось проверить v106: '+error.message,true);console.error(error);updateHUD();}
