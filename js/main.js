import {createCabModel} from './cab/CabModel.js?v=cab-r2';
import {createCabCommands} from './cab/CabCommands.js';
import {installCabInteraction} from './cab/CabInteraction.js?v=cab-r2';
import {buildPlatformApproach,buildPlatformFurniture} from './platforms/PlatformGeometry.js';
import {PassengerSystem} from './passengers/PassengerSystem.js';
import {buildCarriageDoors} from './carriage/CarriageDoors.js';
import {buildCarriageInterior} from './carriage/CarriageInterior.js';
import {smoothstep01,trackDrop as calculateTrackDrop} from './world/TrackProfile.js';
import {box as createBox} from './graphics/Geometry.js';
import {createMaterial} from './graphics/Materials.js';
import {createCarriageCameraController} from './cameras/CarriageCamera.js?v=20261026-lookat-world-v35';
import {stepTrainMotion} from './train/TrainPhysics.js?v=20261026-physics-fps-fix';
import {clampView,restoreViewport,resizeCameras,chooseCamera} from './core/CameraManager.js';
import {gameSnapshot} from './core/GameState.js';
import {animateDoorLeaves,animateCarriageDoors} from './train/TrainDoors.js?v=20261026-smooth-v16';

import * as THREE from './vendor/three.module.js';
const renderer=new THREE.WebGLRenderer({canvas:document.querySelector('#scene'),antialias:true,powerPreference:'default',preserveDrawingBuffer:false});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const scene=new THREE.Scene();scene.background=new THREE.Color(0x11161a);scene.fog=new THREE.Fog(0x11161a,45,190);const camera=new THREE.PerspectiveCamera(66,innerWidth/innerHeight,.045,230);const stationCamera=new THREE.PerspectiveCamera(68,innerWidth/innerHeight,.1,230);camera.position.set(0,3.35,4.72);scene.add(new THREE.HemisphereLight(0x708599,0x080b10,.16));const headlights=[];for(const side of [-1,1]){const beam=new THREE.SpotLight(0xf0f6ff,185,88,Math.PI/9,.34,1.4);beam.position.set(side*1.02,1.48,1.0);beam.target.position.set(side*1.55,1.65,-37);scene.add(beam,beam.target);headlights.push(beam)}const ambientStation=new THREE.AmbientLight(0xd7e9ff,.15);scene.add(ambientStation);
const mat=(c,metal=0)=>createMaterial(THREE,c,metal),concrete=mat(0x4a4d4d),dark=mat(0x25292b),rail=mat(0xa5a6a4,.8),steel=mat(0x697985,.65),wood=mat(0x69584b),yellow=mat(0xeacb40),tile=mat(0xa7a39a),light=new THREE.MeshBasicMaterial({color:0xe5f5ff}),blue=mat(0x1d5d84);
const box=(...args)=>createBox(THREE,...args);
// Actual world-space 3D driver's cab: head turns around a stationary dashboard.
// Unlike a HUD overlay, its screens, buttons and housing change perspective.
const cabModel=createCabModel(THREE,renderer),cab=cabModel.root;scene.add(cab);
const rearMirrors=cabModel.rearMirrors,cabMetal=cabModel.materials.steel;
// Bounded inspection bridge reads the actual game, never a separate mock-up.
const cabInspect={version:cabModel.version,get scene(){return scene},get cab(){return cab},get camera(){return camera},
 setView(y,p){targetYaw=THREE.MathUtils.clamp(y,-1.04,1.04);targetPitch=THREE.MathUtils.clamp(p,-.68,.35)},
 setZoom(fov){camera.fov=THREE.MathUtils.clamp(fov,38,82);camera.updateProjectionMatrix()},
 getView(){return {yaw:targetYaw,pitch:targetPitch,fov:camera.fov}},
 focusControl(id){const c=cabModel.controls.get(id);if(!c)return false;cab.updateMatrixWorld(true);const p=new THREE.Vector3();c.hit.getWorldPosition(p);p.sub(camera.position);targetYaw=THREE.MathUtils.clamp(Math.atan2(-p.x,-p.z),-1.04,1.04);targetPitch=THREE.MathUtils.clamp(Math.atan2(p.y,Math.hypot(p.x,p.z)),-.68,.35);return true;},
 getLandmarks(){return cabModel.landmarks(camera)},getControls(){return cabInteraction.projected()},pickControl(x,y,touch=false){return cabInteraction.pick(x,y,touch)?.id??null},getState(){return cabCommands.snapshot()},
 getPerformance(){return {render:{...renderer.info.render},memory:{...renderer.info.memory},frameHistoryMs:cabFrameTimes.slice(),batching:cabModel.batching,version:cabModel.version}},
 setCabVisible(v){cab.visible=Boolean(v)}};
if(new URLSearchParams(location.search).has('cabInspector'))window.metroCabInspector=cabInspect;
// Exterior side of the driver's train, seen in both mirrors looking backwards.
const reflectedTrain=new THREE.Group();scene.add(reflectedTrain);
// Shared livery for exterior platform view and the driver's side mirrors.
const metroBluePaint=0x4679b5;
const trainBodyMat=new THREE.MeshStandardMaterial({color:metroBluePaint,metalness:.28,roughness:.46});
const trainBeltMat=trainBodyMat,trainGlassMat=mat(0x152e3b,.3);
const mirrorWhite=new THREE.MeshBasicMaterial({color:0xf4f5f0});
for(const side of [-1,1]){
 box(reflectedTrain,.15,2.65,25,side*2.07,2.25,17,trainBodyMat);
 box(reflectedTrain,.17,.64,25,side*2.16,2.23,17,trainBeltMat);
 // Match the long white stripe and lower body ribs of the exterior cars.
 box(reflectedTrain,.035,.12,25,side*2.265,2.04,17,mirrorWhite);
 for(const y of [1.34,1.52,1.70])box(reflectedTrain,.025,.02,25,side*2.268,y,17,mirrorWhite);
 for(let j=0;j<7;j++){
  const z=6+j*3.1;
  box(reflectedTrain,.185,.83,1.48,side*2.17,2.83,z,trainGlassMat);
  box(reflectedTrain,.19,1.6,.07,side*2.19,1.75,z+1.35,cabMetal);
 }
}
// Five-car exterior train, visible only from the elevated platform camera.
const stationTrain=new THREE.Group();scene.add(stationTrain);stationTrain.visible=false;
const extSilver=mat(0xdce3e8,.42),extBlue=trainBodyMat;
const extWhite=new THREE.MeshBasicMaterial({color:0xf4f5f0});
const extLine=new THREE.MeshStandardMaterial({color:0xd5e8f3,metalness:.35,roughness:.4});
const extGlass=new THREE.MeshPhysicalMaterial({color:0xd3e9ef,metalness:0,roughness:.16,transparent:true,opacity:.16,depthWrite:false,side:THREE.DoubleSide});
const interiorLight=new THREE.MeshBasicMaterial({color:0xe4e6d7});
const interiorSeatLit=new THREE.MeshStandardMaterial({color:0x7995aa,roughness:.82,emissive:0x304455,emissiveIntensity:.24});
const trainInterior= new THREE.MeshStandardMaterial({color:0xb7c6cf,roughness:.76});
const trainSeat=new THREE.MeshStandardMaterial({color:0x486d8b,roughness:.85});
const extDark=new THREE.MeshBasicMaterial({color:0x101c27});
const stationDoorLeaves=[];
// Rounded, nearly flush panels with smooth corners (mobile-friendly geometry).
function roundedTrainPanel(parent,w,h,r,depth,x,y,z,material,rotationY=0){
 const q=new THREE.Shape(),a=-w/2,b=-h/2;
 r=Math.min(r,w*.49,h*.49);
 q.moveTo(a+r,b);q.lineTo(a+w-r,b);q.quadraticCurveTo(a+w,b,a+w,b+r);
 q.lineTo(a+w,b+h-r);q.quadraticCurveTo(a+w,b+h,a+w-r,b+h);
 q.lineTo(a+r,b+h);q.quadraticCurveTo(a,b+h,a,b+h-r);
 q.lineTo(a,b+r);q.quadraticCurveTo(a,b,a+r,b);
 const geo=new THREE.ExtrudeGeometry(q,{depth,bevelEnabled:false,curveSegments:8,steps:1});
 geo.translate(0,0,-depth/2);geo.computeVertexNormals();
 const mesh=new THREE.Mesh(geo,material);mesh.position.set(x,y,z);mesh.rotation.y=rotationY;
 parent.add(mesh);return mesh;
}
// Detailed leading cab face; the previous external model had no visible front.
const trainNose=new THREE.Group();stationTrain.add(trainNose);trainNose.position.z=-.05;
roundedTrainPanel(trainNose,4.30,3.06,.38,.38,0,2.27,0,extBlue);
roundedTrainPanel(trainNose,3.55,1.27,.26,.035,0,2.76,-.222,extDark);
box(trainNose,3.25,.12,.48,0,2.02,-.28,extSilver);
roundedTrainPanel(trainNose,3.55,.33,.14,.035,0,1.13,-.23,extBlue);
for(const x of [-1.55,1.55]){const lamp=new THREE.Mesh(new THREE.SphereGeometry(.19,12,8),new THREE.MeshBasicMaterial({color:0xfff4c7}));lamp.position.set(x,1.46,-.55);trainNose.add(lamp)}
const trainDestination=document.createElement('canvas');trainDestination.width=512;trainDestination.height=96;
const td=trainDestination.getContext('2d');td.fillStyle='#121e29';td.fillRect(0,0,512,96);td.fillStyle='#ffe077';td.textAlign='center';td.font='bold 40px Arial';td.fillText('МАЛІНАЎКА',256,65);
const trainDestinationTex=new THREE.CanvasTexture(trainDestination);
const dest=new THREE.Mesh(new THREE.PlaneGeometry(2.75,.52),new THREE.MeshBasicMaterial({map:trainDestinationTex}));dest.position.set(0,2.06,-.525);dest.rotation.y=Math.PI;trainNose.add(dest);
for(let car=0;car<5;car++){
 const cz=12+car*21.5;
 roundedTrainPanel(stationTrain,4.32,.44,.21,20.7,0,3.57,cz,extBlue);
 box(stationTrain,4.25,.25,20.7,0,.93,cz,extBlue);
 // Interior geometry seen through the glazing.
 box(stationTrain,3.9,.11,20.0,0,1.08,cz,trainInterior);
 box(stationTrain,3.8,.10,20.0,0,3.35,cz,interiorLight);
 // Warm lit panels inside the car make seats and the opposite wall visible.
 for(let iz=-7.5;iz<=7.5;iz+=5)box(stationTrain,1.1,.018,2.2,0,3.26,cz+iz,interiorLight);
 for(let seat=0;seat<7;seat++){
  const sz=cz-8.2+seat*2.65;
  if([-5.25,5.25].some(d=>Math.abs(sz-cz-d)<1.15))continue;
  for(const sideSeat of [-1,1]){
   box(stationTrain,.65,.12,1.45,sideSeat*1.48,1.46,sz,interiorSeatLit);
   box(stationTrain,.15,.73,1.45,sideSeat*1.79,1.84,sz,interiorSeatLit);
  }
 }
 for(const side of [-1,1]){
  // Do not put an opaque wall across the door openings: split side into
  // lower sill, upper lintel and short solid sections between doorways.
  box(stationTrain,.12,.45,20.7,side*2.15,1.17,cz,extBlue);
  box(stationTrain,.12,.48,20.7,side*2.15,3.32,cz,extBlue);
  for(const segment of [[-9.3,-6.45],[-4.05,4.05],[6.45,9.3]]){
   const mid=(segment[0]+segment[1])/2;
   // Window belt is open behind glazing; upper/lower solid panels and
   // narrow vertical mullions retain the silhouette of the carriage.
   box(stationTrain,.12,.88,segment[1]-segment[0],side*2.15,1.81,cz+mid,extBlue);
   box(stationTrain,.12,.26,segment[1]-segment[0],side*2.15,3.23,cz+mid,extBlue);
   for(let mz=segment[0];mz<=segment[1];mz+=2.35)box(stationTrain,.12,1.0,.12,side*2.15,2.78,cz+mz,extBlue);
   // The distinctive long white stripe crosses only solid side panels.
   box(stationTrain,.025,.115,segment[1]-segment[0],side*2.315,2.04,cz+mid,extWhite);
   for(const yy of [1.34,1.52,1.70])box(stationTrain,.018,.018,segment[1]-segment[0],side*2.32,yy,cz+mid,extLine);
   // Blue lower panels retain thin horizontal stamped-metal ribs.
  }
  for(let j=0;j<4;j++){
   const wz=cz-8.2+j*5;
   // Never put a solid dark panel behind the glass: it hid the interior.
   // Narrow metal surround plus a truly translucent pane over an open hole.
   // Open center: four slim gasket strips instead of an opaque backing.
   box(stationTrain,.022,.055,2.08,side*2.218,3.31,wz,extDark);
   box(stationTrain,.022,.055,2.08,side*2.218,2.43,wz,extDark);
   for(const edge of [-1,1])box(stationTrain,.022,.84,.06,side*2.218,2.87,wz+edge*1.01,extDark);
   roundedTrainPanel(stationTrain,1.94,.79,.15,.009,side*2.228,2.87,wz,extGlass,side*Math.PI/2);
  }
  for(const dz of [-5.25,5.25]){
   const doorZ=cz+dz;
   // Dark interior beyond the doorway, recessed inside the carriage.
   box(stationTrain,.08,2.12,2.18,side*1.95,2.15,doorZ,extDark);
   for(const half of [-1,1]){
    const leaf=new THREE.Group();stationTrain.add(leaf);
    leaf.position.set(side*2.19,2.15,doorZ+half*.53);
    // Door shell with softly rounded perimeter and flush glass aperture.
 // Door skin built around a genuine window opening, not a solid plate.
    box(leaf,.052,.63,1.035,0,-.71,0,extBlue);
    box(leaf,.052,.49,1.035,0,.79,0,extBlue);
    for(const zz of [-.47,.47])box(leaf,.052,1.05,.095,0,.02,zz,extBlue);
    // Door-specific white diagonal motif: mounted ON the moving leaf,
    // so it slides out of the doorway when the doors are opened.
    const slash=box(leaf,.025,.13,1.33,side*.039,-.24,0,extWhite);
    slash.rotation.x=half*.92;
    box(leaf,.028,.11,.92,side*.040,-.03,0,extWhite);
    // No opaque black backing behind the door glass either.
    roundedTrainPanel(leaf,.61,.70,.13,.008,side*.030,.34,0,extGlass,side*Math.PI/2);
    stationDoorLeaves.push({leaf,half,doorZ});
   }
  }
 }
}
let mirrorFrameNumber=0;
function renderRearMirrors(){
 // Reduced resolution and 1 mirror per 3 frames keeps Android performance acceptable.
 if(window.metroMirrorsDisabled||++mirrorFrameNumber%3!==0)return;
 const m=rearMirrors[Math.floor(mirrorFrameNumber/3)%2];
 if(!m.enabled)return;
 cab.visible=false;
 for(const item of rearMirrors)item.face.visible=false;
 try{
 // Camera outside the side wall, angled inward: train windows and doors MUST
 // occupy the near half of the reflection, platform the far half.
 // Camera stays inside the tunnel's safe clearance envelope and looks aft.
 // Near clipping avoids cables and wall details intersecting the mirror image.
 m.mirrorCamera.position.set(m.side*2.70,3.15,3.35);
 m.mirrorCamera.lookAt(m.side*2.05,2.25,19.0);
 m.mirrorCamera.updateProjectionMatrix();
 renderer.setRenderTarget(m.target);
 renderer.clear();
 renderer.render(scene,m.mirrorCamera);
 }finally{
  renderer.setRenderTarget(null);
  cab.visible=true;
  for(const item of rearMirrors)item.face.visible=item.enabled;
 }
}
const infoControl=cabModel.controls.get('info');
function syncDoorButtons(){cabModel.controls.get('open').target=doors?1:0;cabModel.controls.get('close').target=doors?0:1}
// Departure announcements are triggered by the EXISTING INFO switch.
const departureAudio=new Audio();
departureAudio.preload='auto';
let infoPlaying=false,infoCompleted=false,infoStarted=false,infoToken=0;
let driverErrorCount=0,seriousErrorCount=0;
function reportDriverError(message,serious=false){
 if(serious){seriousErrorCount++;const severe=document.querySelector('#seriousErrorCount');if(severe)severe.textContent=seriousErrorCount;}
 driverErrorCount++;
 const counter=document.querySelector('#errorCount');
 if(counter)counter.textContent=driverErrorCount;
 status.textContent='⚠ Ошибка машиниста: '+message;
}
function finishInfo(token){
 if(token!==infoToken)return;
 infoPlaying=false;infoCompleted=true;infoControl.target=0;
 status.textContent='Объявление завершено — можно закрывать двери';
}
// INFO has two announcements per station: arrival, then departure.
let infoArrivalPlayed=false;
function syntheticAnnouncement(parts,onDone){
 const token=++infoToken;
 infoPlaying=true;infoControl.target=1;
 if(!('speechSynthesis' in window)){status.textContent='На устройстве недоступен синтез речи';finishInfo(token);return}
 const synth=window.speechSynthesis;
 synth.cancel();
 let i=0;
 function sayNext(){
  if(token!==infoToken)return;
  if(i>=parts.length){finishInfo(token);if(onDone)onDone();return}
  const [words,language]=parts[i++];
  const u=new SpeechSynthesisUtterance(words);
  u.lang=language;u.rate=.88;u.volume=1;
  const voices=synth.getVoices();
  const voice=voices.find(v=>v.lang.toLowerCase()===language.toLowerCase())||
   voices.find(v=>v.lang.toLowerCase().startsWith(language.slice(0,2).toLowerCase()))||
   voices.find(v=>v.lang.toLowerCase().startsWith(language==='be-BY'?'ru':'en'));
  if(voice)u.voice=voice;
  u.onend=sayNext;
  u.onerror=()=>{if(token===infoToken)sayNext()};
  try{synth.speak(u)}catch(e){console.warn('INFO speech:',e);sayNext()}
 }
 sayNext();
}
// Original announcer recordings for the first station.
// Keep the synthetic speech as fallback until MP3 assets are uploaded.
const originalInfoAudio=new Audio();
originalInfoAudio.preload='auto';
function playInfoRecording(path,parts){
 const token=infoToken+1;
 const url=new URL(path,document.baseURI);
 const probe=new Audio();
 probe.preload='auto';
 probe.src=url.href;
 // A failed request must not silence the INFO switch.
 let settled=false;
 function fallback(){
  if(settled)return;settled=true;
  probe.pause();syntheticAnnouncement(parts);
 }
 probe.onerror=fallback;
 probe.oncanplay=()=>{
  if(settled)return;settled=true;
  const current=++infoToken;
  infoPlaying=true;infoControl.target=1;
  originalInfoAudio.pause();
  originalInfoAudio.src=url.href;
  originalInfoAudio.onended=()=>finishInfo(current);
  originalInfoAudio.onerror=()=>{if(current===infoToken)syntheticAnnouncement(parts)};
  originalInfoAudio.play().catch(()=>{if(current===infoToken)syntheticAnnouncement(parts)});
 };
 probe.load();
}
const metroBelarusian=['Малінаўка','Пятроўшчына','Міхалова','Грушаўка','Інстытут культуры','Плошча Леніна','Кастрычніцкая','Плошча Перамогі','Плошча Якуба Коласа','Акадэмія навук','Парк Чалюскінцаў','Маскоўская','Усход','Барысаўскі тракт','Уручча'];
const metroEnglish=['Malinauka','Piatroushchyna','Mikhalova','Hrushauka','Instytut Kultury','Ploshcha Lenina','Kastrychnitskaya','Ploshcha Peramohi','Ploshcha Yakuba Kolasa','Akademiya Navuk','Park Chalyuskintsau','Maskouskaya','Uschod','Barysawski Trakt','Uruchcha'];
document.getElementById('infoSpeaker')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();cabCommands.command('info')});
function pressInfo(){
 infoControl.target=1;
 clearTimeout(pressInfo.pressTimer);
 pressInfo.pressTimer=setTimeout(()=>{if(!infoPlaying)infoControl.target=0},400);
 if(infoPlaying){status.textContent='INFO: объявление уже звучит';return}
 if(doors){
  if(index>=names.length-1){status.textContent='INFO: конечная станция Уручье';return}
  infoArrivalPlayed=true;infoStarted=true;infoCompleted=false;
  const next=(index+1)%names.length;
  status.textContent='INFO: следующая станция — '+names[next];
  const parts=[
   ['Асцярожна, дзверы зачыняюцца. Наступная станцыя — '+metroBelarusian[next]+'.','ru-RU'],
   [(next===1?'Petrovshchina':metroEnglish[next])+' Station. Mind the closing doors.','en-US']
  ];
  if(index===0)playInfoRecording('audio/malinovka_departure_petrovshchina.mp3',parts);
  else syntheticAnnouncement(parts);
  return;
 }
 if(!infoArrivalPlayed){
  infoArrivalPlayed=true;
  status.textContent='INFO: станция '+names[index%names.length];
  const parts=[
   ['Станцыя '+metroBelarusian[index%names.length]+'.','ru-RU'],
   [metroEnglish[index%names.length]+' Station.','en-US']
  ];
  if(index===0)playInfoRecording('audio/malinovka_arrival.mp3',parts);
  else syntheticAnnouncement(parts);
 }else status.textContent='INFO: откройте двери для объявления об отпра…14412 tokens truncated…. Keep the platform camera attached
 // to the moving platform geometry, but hold the train model at its initial
 // world position: relative to the platform it now drives out of view.
 stationTrain.position.set(-.31,platform.position.y,stationCameraTrainZ);
 stationTrain.visible=true;
 // At the head of the train, looking down its side as in the photo.
 // Height 5.5 stays BELOW the original Malinauka ceiling (8.35).
 // A three-quarter front-side shot: nose in foreground, cars and platform
 // receding into the distance. The camera stays below the original roof.
 const noseZ=platform.position.z-100;
 stationCamera.fov=61;stationCamera.updateProjectionMatrix();stationCamera.position.set(-3.72,4.55,noseZ+3.2);
 const target=new THREE.Vector3(-5.6,2.65,noseZ+44);
 target.x+=Math.sin(stationViewYaw)*35;
 
 target.y+=stationViewPitch*9;
 stationCamera.lookAt(target);
}
restoreViewport(renderer,innerWidth,innerHeight);
if(carCameraActive){
 carriageCamera.aspect=renderer.domElement.clientWidth/Math.max(1,renderer.domElement.clientHeight);carriageCamera.updateProjectionMatrix();
 // Three.js setViewport expects CSS pixels; drawing-buffer dimensions
 // are scaled by devicePixelRatio and cropped/zoomed the next cab view.
 renderer.setViewport(0,0,innerWidth,innerHeight);
 renderer.setScissorTest(false);
 // The same THREE.Scene is rendered by cab, platform and carriage cameras.
 // Keep the driver's cab out of the carriage view; all station objects remain.
 cab.visible=false;
 stationTrain.visible=false;
 renderer.render(scene,carriageCamera);
 cab.visible=true;
}else renderer.render(scene,passengerInspectionCamera??chooseCamera({cab:camera,platform:stationCamera,carriage:carriageCamera},stationCameraActive?'platform':'cab'));
if(stationCameraActive){cab.visible=true;}
document.body.classList.toggle('outside-cab',carCameraActive||stationCameraActive);window.metroLastRendered=performance.now();window.metroDiagnostics=()=>gameSnapshot({speed,doors,dist,index,playing,camera:carCameraActive?'carriage':stationCameraActive?'platform':'cab'});}catch(e){console.error('Metro render failure',e);const st=document.getElementById('status');if(st)st.textContent='Ошибка 3D: '+e.message;window.metro3DReady=false;window.dispatchEvent(new Event('metro-render-error'));}}document.querySelector('#cockpit').style.display='none';document.querySelector('#window').style.display='none';window.metro3DReady=true;window.dispatchEvent(new Event('metro-3d-ready'));
if(previewMode==='station'||previewMode==='approach'){
 // Jump the WORLD forward, not the camera. The train remains on the right-hand track.
 dist=previewMode==='station'?0:105;
 const skip=1100-dist;
 depot.position.z=skip;
 depot.position.y=descentDepth;
 for(const g of chunks){g.position.z=((g.position.z+skip+384)%384+384)%384-352;g.position.y=0;}
 platform.position.z=-dist+112;platform.position.y=0;
 const entrance=platform.position.z+6;
 for(const g of chunks){const far=g.position.z-32;g.visible=(far>entrance+3||g.position.z<entrance-145);}
 const previewFog=new THREE.Color(0x05080b);
 scene.fog.color.copy(previewFog);scene.background.copy(previewFog);scene.fog.near=27;scene.fog.far=145;
 sun.intensity=.04;skyFill.intensity=.06;
 document.getElementById('start').style.display='none';
 playing=true;
 status.textContent=previewMode==='station'?'ПРОСМОТР: Малиновка — у платформы':'ПРОСМОТР: въезд на Малиновку';
 // Remain stopped so station details can be inspected. Traction controls still work.
}

if(passengerParams.has('passengerInspector')){
 window.metroPassengerInspector={
  snapshot:()=>passengerSystem.snapshot(),get system(){return passengerSystem},get scene(){return scene},
  focus(id,distance=3.0){const a=passengerSystem.simulation.agents.find(a=>a.id===id);if(!a)return false;
   const p=passengerSystem.worldPosition(a);passengerInspectionCamera=new THREE.PerspectiveCamera(48,innerWidth/innerHeight,.06,200);
   passengerInspectionCamera.position.set(p.x+Math.sin(a.heading)*distance,p.y+1.45,p.z+Math.cos(a.heading)*distance);
   passengerInspectionCamera.lookAt(p.x,p.y+.98,p.z);return true;},
  view(position,target,fov=58){passengerInspectionCamera=new THREE.PerspectiveCamera(fov,innerWidth/innerHeight,.06,230);passengerInspectionCamera.position.fromArray(position);passengerInspectionCamera.lookAt(...target);},
  resetView(){passengerInspectionCamera=null;},
  pause(value=true){passengerSystem.paused=value;},
  step(seconds){const ctx={station:index,dist,speed,doorsOpen:doors&&!stationDoorCycleCompleted,aperture:((stationDoorLeaves[0].leaf.position.z-stationDoorLeaves[0].doorZ)*stationDoorLeaves[0].half-.53)/1.03};for(let t=0;t<Math.min(120,seconds);t+=1/30)passengerSystem.simulation.step(1/30,ctx);},
  train(values){if(Number.isFinite(values.dist))dist=THREE.MathUtils.clamp(values.dist,-200,1200);if(Number.isFinite(values.speed))speed=THREE.MathUtils.clamp(values.speed,0,90);if(typeof values.doors==='boolean')doors=values.doors;if(Number.isInteger(values.station))index=THREE.MathUtils.clamp(values.station,0,names.length-1);},
  mirrors(){return rearMirrors.map(m=>({side:m.side,enabled:m.enabled,camera:m.mirrorCamera.position.toArray(),size:[m.target.width,m.target.height]}));},
  mirrorImage(side){const m=rearMirrors.find(m=>m.side===side);if(!m)return null;const pixels=new Uint8Array(m.target.width*m.target.height*4);renderer.readRenderTargetPixels(m.target,0,0,m.target.width,m.target.height,pixels);const c=document.createElement('canvas');c.width=m.target.width;c.height=m.target.height;const ctx=c.getContext('2d'),data=ctx.createImageData(c.width,c.height);for(let y=0;y<c.height;y++)data.data.set(pixels.subarray((c.height-y-1)*c.width*4,(c.height-y)*c.width*4),y*c.width*4);ctx.putImageData(data,0,0);return c.toDataURL();},
  performance:()=>({render:{...renderer.info.render},memory:{...renderer.info.memory},passengers:passengerSystem.lodStats}),
 };
}
requestAnimationFrame(frame);
