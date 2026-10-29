import {createCabModel} from './cab/CabModel.js?v=cab-r2';
import {createCabCommands} from './cab/CabCommands.js';
import {installCabInteraction} from './cab/CabInteraction.js?v=cab-r2';
import {buildPlatformApproach,buildPlatformFurniture} from './platforms/PlatformGeometry.js';
import {PassengerSystem} from './passengers/PassengerSystem.js';
import {requestPassengerDeparture,consumePassengerDeparture} from './passengers/PassengerDeparture.js';
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
   const portalBacking=box(stationTrain,.08,2.12,2.18,side*1.95,2.15,doorZ,extDark);
   portalBacking.name='PassengerPortalBacking';
   for(const half of [-1,1]){
    const leaf=new THREE.Group();leaf.name='PassengerExteriorDoorLeaf';stationTrain.add(leaf);
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
    stationDoorLeaves.push({leaf,half,doorZ,portalBacking});
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
 }else status.textContent='INFO: откройте двери для объявления об отправлении';
}
let stationDoorCycleCompleted=false,stationDoorReopenPenalty=false;
function setCabDoors(open){
 if(open)passengerSystem.closeRequested=false;
 if(doors===open)return;
 if(open){
  if(stationSkipped||dist < -stopTolerance){markStationSkipped();if(stopWarning.style.display!=='none')showStopWarning('ГРУБАЯ ОШИБКА! ОБСЛУЖИВАНИЕ СТАНЦИИ ЗАПРЕЩЕНО. ПРОДОЛЖАЙТЕ ДВИЖЕНИЕ',true);return;}
  if(speed>=.5){showStopWarning('ОШИБКА МАШИНИСТА: поезд ещё движется — двери заблокированы');return;}
  if(dist>stopTolerance){if(!shortStopErrorRecorded){shortStopErrorRecorded=true;shortStopErrorPosition=dist;reportDriverError('попытка открыть двери до знака остановки');}showStopWarning('ОШИБКА МАШИНИСТА! НЕ ДОЕХАЛИ '+dist.toFixed(1)+' М. ПОДЪЕДЬТЕ БЛИЖЕ (ДОПУСК ±3 М)');return;}
 }
 if(!open&&!requestPassengerDeparture(passengerSystem)){status.textContent='Завершается пассажирообмен — ожидайте освобождения дверей';return;}
 const reopening=open&&stationDoorCycleCompleted&&Math.abs(dist)<=stopTolerance&&speed<.5;
 if(reopening){
  if(!stationDoorReopenPenalty){stationDoorReopenPenalty=true;reportDriverError('повторное открытие дверей после объявления об отправлении');}
  showStopWarning('ОСТОРОЖНО! ДВЕРИ ПОВТОРНО ОТКРЫТЫ. ДВИЖЕНИЕ ЗАПРЕЩЕНО',true);
 }
 initMetroAudio();metroChime(open);
 if(!open&&Math.abs(dist)<32&&!stationDoorCycleCompleted){
  // Departure warning begins with «Асцярожна, дзверы зачыняюцца».
  // Closing during the announcement is now correct; only skipping INFO is an error.
  if(!infoStarted)reportDriverError('двери закрыты без объявления INFO');
 }
 if(!open&&stationServiced&&Math.abs(dist)<32)stationDoorCycleCompleted=true;
 doors=open;syncDoorButtons();syncScreenDoorToggle();
 if(open){
  infoStarted=false;infoCompleted=false;
  // Opening doors must not cut off an announcement already playing.
 }
 if(!status.textContent.startsWith('⚠'))status.textContent=doors?'Двери открыты':'Двери закрыты';
 if(doors&&speed>1)reportDriverError('открытие дверей на ходу');
 if(doors&&!stationSkipped&&Math.abs(dist)<=stopTolerance&&speed<.5){stationServiced=true;overrunReported=false;if(!reopening)stopWarning.style.display='none';}
 if(!doors){departureTimes[index%departureTimes.length]=Date.now();if(stationServiced)status.textContent='Двери закрыты — отправляйтесь в тоннель';if(stationDoorReopenPenalty)stopWarning.style.display='none';}
 // Do not interrupt the active departure announcement with door TTS.
}
// Close, dark tunnel with an arched concrete lining, train headlights and wayside signals.
const tunnelWall=mat(0x171b20),tunnelRib=mat(0x303840,.3),tunnelBallast=mat(0x252628),signalBlack=mat(0x101619,.35);
const signalGreen=new THREE.MeshBasicMaterial({color:0x26ff73}),signalRed=new THREE.MeshBasicMaterial({color:0xff2828});
const tunnelSignals=[];
function addSignal(group,z,green){
 const assembly=new THREE.Group();assembly.position.set(-2.82,0,z);group.add(assembly);
 box(assembly,.13,4.2,.16,0,2.15,0,tunnelRib);
 box(assembly,.48,1.17,.26,.05,4.20,0,signalBlack);
 for(const [height,on,colour] of [[4.47,green,signalGreen],[4.0,!green,signalRed]]){
  const bulb=new THREE.Mesh(new THREE.SphereGeometry(.145,16,12),on?colour:signalBlack);
  bulb.position.set(.05,height,.15);assembly.add(bulb);
  if(on){const glow=new THREE.PointLight(green?0x23f873:0xff2525,1.4,5);glow.position.set(.05,height,.3);assembly.add(glow)}
 }
 tunnelSignals.push(assembly);
}
const cableBlack=mat(0x10161b,.3),cableBlue=mat(0x253d49,.32),cableBrown=mat(0x302a28,.4);
const serviceBox=mat(0x62696b,.5),serviceDoor=mat(0x3d474b,.4);
function tunnelCable(group,side,y,offset,material){
 const points=[];for(let j=0;j<=20;j++){const z=-32+j*1.6;points.push(new THREE.Vector3(side*(3.12-offset*.32+.025*Math.sin(j*.6+offset*12)),y+.055*Math.sin(j*.52+offset*6),z))}
 group.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),70,.045+offset*.025,7,false),material));
}
const chunks=[];
function addChunk(z){
 const g=new THREE.Group();g.position.z=z;scene.add(g);
 box(g,6.45,.34,32,0,-.32,-16,tunnelBallast);
 // Faceted arch instead of broad flat rectangular walls.
 const archPts=[[-3.15,.05],[-3.15,3.3],[-2.94,4.8],[-2.25,6.15],[-1.25,6.85],[0,7.05],[1.25,6.85],[2.25,6.15],[2.94,4.8],[3.15,3.3],[3.15,.05]];
 for(let j=0;j<archPts.length-1;j++){
  const [x1,y1]=archPts[j],[x2,y2]=archPts[j+1];
  const dx=x2-x1,dy=y2-y1,len=Math.hypot(dx,dy);
  const panel=box(g,.22,len,32,(x1+x2)/2,(y1+y2)/2,-16,tunnelWall);
  panel.rotation.z=-Math.atan2(dx,dy);
 }
 for(let k=0;k<4;k++){
  const zz=-k*8;
  for(let j=0;j<archPts.length-1;j++){
   const [x1,y1]=archPts[j],[x2,y2]=archPts[j+1],dx=x2-x1,dy=y2-y1;
   const rib=box(g,.065,Math.hypot(dx,dy),.095,(x1+x2)/2,(y1+y2)/2,zz,tunnelRib);
   rib.rotation.z=-Math.atan2(dx,dy);
  }
 }
 for(const x of [-1.15,1.15])box(g,.12,.17,32,x,.08,-16,rail);
 for(let j=0;j<16;j++)box(g,3.3,.11,.27,0,-.03,-j*2,wood);
 // Smooth insulated cable bundles and equipment cabinets along the tunnel walls.
 for(const side of [-1,1]){
  for(let k=0;k<6;k++)tunnelCable(g,side,1.45+k*.22,k*.075,[cableBlack,cableBlue,cableBrown][k%3]);
  for(let k=0;k<5;k++){const zz=-3-k*7;box(g,.12,.07,.24,side*3.04,1.54,zz,tunnelRib);box(g,.12,.07,.24,side*3.04,2.58,zz,tunnelRib)}
  if(Math.round(-z/32)%3===0){box(g,.22,.82,.86,side*2.97,2.35,-13,serviceBox);box(g,.235,.68,.69,side*2.82,2.35,-13,serviceDoor)}
 }
 // Sparse wall lamps: most of the tunnel stays dark.
 for(let j=0;j<2;j++){
  const zz=-6-j*16;
  box(g,.11,.62,.25,-3.02,3.3,zz,light);
 }
 chunks.push(g);
}
for(let i=0;i<12;i++)addChunk(-i*32);
// Open-air Minsk metro depot and industrial outskirts. World moves past the cab.
const depot=new THREE.Group();scene.add(depot);
const depotConcreteMat=mat(0x4b5055),asphalt=mat(0x34393d),depotSteelMat=mat(0x434b54,.45),
 orange=mat(0xff761b),vestStripe=new THREE.MeshBasicMaterial({color:0xf9ed92}),
 skinWorker=mat(0xd7a487),helmet=mat(0xf4cc35),glassCity=mat(0x708c9e,.2);
box(depot,52,.28,157,0,-.43,-56.5,asphalt);
for(const x of [-1.15,1.15])box(depot,.13,.17,157,x,.02,-56.5,rail);
for(let j=0;j<78;j++)box(depot,3.3,.12,.27,0,-.1,22-j*2,wood);
// Parallel sidings, overhead electrical gantries, maintenance yard.
for(const side of [-1,1]){
 const x=side*13;
 for(const dx of [-1.1,1.1])box(depot,.12,.16,245,x+dx,-.01,-105,rail);
 for(let j=0;j<80;j++)box(depot,3.2,.12,.25,x,-.12,12-j*2,wood);
 box(depot,4,.25,205,side*21,-.12,-110,depotConcreteMat);
 for(let j=0;j<9;j++){
  const z=5-j*27;
  box(depot,.34,9,.35,side*7.5,4.25,z,depotSteelMat);
  box(depot,15,.25,.35,0,8.6,z,depotSteelMat);
  box(depot,.10,.10,27,side*5,8.0,z-13,depotSteelMat);
 }
}
// Workshop building to the left: the train starts OUTSIDE, not under a roof.
const brick=mat(0x997b70),roof=mat(0x495968);
box(depot,17,7,110,-23,3.35,-70,brick);
box(depot,18,.45,114,-23,7.05,-70,roof);
for(let j=0;j<9;j++){
 const z=-15-j*12;
 box(depot,.08,3.2,5.2,-14.43,3.1,z,glassCity);
 box(depot,.12,.16,5.4,-14.32,4.5,z,depotSteelMat);
}
// Utility buildings, cranes, fences and distant city apartment towers.
for(let i=0;i<8;i++){
 const side=i%2?-1:1,x=side*(38+(i%3)*13),z=-15-i*15;
 const height=16+(i*11)%34;
 const facade=mat(i%3===0?0xb7b9b7:i%3===1?0x8e9eaa:0xc3b6a5);
 box(depot,12,height,13,x,height/2-.3,z,facade);
 for(let floor=1;floor<height/3-1;floor++){
  for(let k=-1;k<=1;k++)box(depot,1.6,1.35,.09,x+k*3,floor*3,z+6.55,glassCity);
 }
}
for(const side of [-1,1]){
 for(let j=0;j<20;j++){
  const z=12-j*13;
  box(depot,.1,2.2,.12,side*25,1,z,depotSteelMat);
  box(depot,.06,.06,260,side*25,1.7,-115,depotSteelMat);
 }
}
// High-visibility orange-vest maintenance workers inspecting the train.
const workers=[];
function depotWorker(x,z,phase,patrol=0){
 const root=new THREE.Group();root.position.set(x,0,z);depot.add(root);
 const trousers=mat(0x273343),boots=mat(0x20252b),jacket=mat(0x35485c);
 const torso=new THREE.Group();root.add(torso);
 box(torso,.62,.85,.34,0,1.30,0,orange);
 box(torso,.65,.11,.38,0,1.13,.02,vestStripe);
 for(const side of [-1,1])box(torso,.075,.74,.37,side*.17,1.32,.02,vestStripe);
 const limbs=[];
 for(const side of [-1,1]){
  const leg=new THREE.Group();leg.position.set(side*.17,.88,0);root.add(leg);
  box(leg,.21,.72,.23,0,-.36,0,trousers);box(leg,.24,.16,.34,0,-.73,-.055,boots);
  const arm=new THREE.Group();arm.position.set(side*.42,1.66,0);root.add(arm);
  box(arm,.18,.67,.21,0,-.32,0,jacket);
  box(arm,.2,.12,.23,0,-.28,0,vestStripe);
  limbs.push({leg,arm,side});
 }
 const neck=new THREE.Mesh(new THREE.CylinderGeometry(.095,.1,.17,9),skinWorker);neck.position.y=1.83;root.add(neck);
 const face=new THREE.Mesh(new THREE.SphereGeometry(.22,12,10),skinWorker);face.position.y=2.08;root.add(face);
 box(root,.49,.15,.45,0,2.30,0,helmet);
 const visor=box(root,.54,.055,.24,0,2.23,-.21,helmet);
 const eyes=mat(0x282a2a);for(const side of [-1,1])box(root,.038,.035,.015,side*.085,2.1,-.205,eyes);
 root.userData={originX:x,originZ:z,phase,patrol,limbs,torso};
 workers.push(root);
}
depotWorker(-3.8,-7,0,5);depotWorker(4.1,-16,1.3,0);
depotWorker(-4.4,-32,2.4,7);depotWorker(5,-53,3.6,0);
depotWorker(-7.8,-84,4.8,9);
function animateDepotWorkers(time){
 for(let i=0;i<workers.length;i++){
  const w=workers[i],u=w.userData,t=time*.001+u.phase;
  const walking=u.patrol>0;
  // Workers patrol along the train, pause at each end, and talk in pairs.
  const cycle=t*.25,travel=walking?Math.sin(cycle):0;
  w.position.z=u.originZ+travel*u.patrol;
  w.position.x=u.originX+(walking?.16*Math.sin(cycle*.7):.04*Math.sin(t*.6));
  const step=walking?Math.cos(cycle)*Math.min(1,Math.abs(Math.cos(cycle)))*.55:0;
  w.rotation.y=walking?(Math.cos(cycle)>0?Math.PI:0):(i%2?Math.PI*.55:-Math.PI*.55);
  u.torso.rotation.z=.025*Math.sin(t*1.4);
  u.torso.rotation.x=walking?.04*Math.sin(t*2):.02*Math.sin(t);
  for(const l of u.limbs){l.leg.rotation.x=l.side*step;l.arm.rotation.x=-l.side*step*.8+(walking?0:.12*Math.sin(t*1.7+l.side));}
  w.position.y=walking?.025*Math.abs(Math.sin(cycle*4)):0;
 }
}
// Smooth track grade: flat depot -> descending cutting -> level underground.
const descentStart=135,descentEnd=270,descentDepth=11;
// The depot-to-tunnel transition must never be hidden by near-black fog.
const trackDrop=(distance)=>calculateTrackDrop(distance,descentDepth,descentStart,descentEnd);
const ramp=new THREE.Group();depot.add(ramp);
const retaining=mat(0x85888a),portalDark=new THREE.MeshBasicMaterial({color:0x06090e});
for(let j=0;j<35;j++){
 const d=descentStart+j*4,drop=trackDrop(d);
 const z=-d;
 box(ramp,7,.22,4.12,0,-.42-drop,z,asphalt);
 for(const x of [-1.15,1.15])box(ramp,.12,.14,4.1,x,-.19-drop,z,rail);
 box(ramp,3.2,.11,.26,0,-.24-drop,z,wood);
 for(const side of [-1,1]){
  const height=2+drop;
  box(ramp,.5,height,4.1,side*3.75,(-.15-drop)+height/2,z,retaining);
 }
}
for(const x of [-3.75,3.75])box(ramp,.8,8,.9,x,-7,-275,retaining);
box(ramp,8,.7,1,0,-2.5,-275,retaining);
// Continuous underground throat: a real arched tunnel, not a black entrance.
// The fixed throat overlaps the sloping rails and the repeating tunnel modules.
const throat=new THREE.Group();depot.add(throat);
for(let j=0;j<28;j++){
 const d=266+j*4,drop=trackDrop(d),z=-d;
 box(throat,6.5,.34,4.12,0,-.32-drop,z,tunnelBallast);
 for(const x of [-1.15,1.15])box(throat,.12,.16,4.12,x,-.08-drop,z,rail);
 if(j%2===0)box(throat,3.25,.13,.3,0,-.13-drop,z,wood);
 // Continuous roof and sidewall panels share the tunnel's existing profile.
 const arch=[[-3.15,.05],[-3.15,3.3],[-2.94,4.8],[-2.25,6.15],[-1.25,6.85],[0,7.05],[1.25,6.85],[2.25,6.15],[2.94,4.8],[3.15,3.3],[3.15,.05]];
 for(let k=0;k<arch.length-1;k++){
  const [x1,y1]=arch[k],[x2,y2]=arch[k+1];
  const dx=x2-x1,dy=y2-y1,len=Math.hypot(dx,dy);
  const panel=box(throat,.22,len,4.15,(x1+x2)/2,(y1+y2)/2-drop,z,tunnelWall);
  panel.rotation.z=-Math.atan2(dx,dy);
 }
 if(j%4===0){
  for(const side of [-1,1])box(throat,.16,.34,.65,side*2.95,3.15-drop,z,tunnelRib);
  const lamp=new THREE.PointLight(0xc3d8e9,2.0,13,2);
  lamp.position.set(-2.5,4.25-drop,z);throat.add(lamp);
 }
}
// No opaque wall or dark plane at the transition; geometry stays continuous.
// Portal opening: do not block the track with a solid dark plane.
// Sunlit yard gradually gives way to the existing dark tunnel.
const sun=new THREE.DirectionalLight(0xe2e4dc,.78);sun.position.set(-40,75,-70);depot.add(sun);
const skyFill=new THREE.HemisphereLight(0x82919b,0x25282b,.38);depot.add(skyFill);
scene.fog.far=310;
// Fixed-distance signal placements inside repeating tunnel sections.
addSignal(chunks[2],-17,true);addSignal(chunks[5],-19,false);addSignal(chunks[7],-10,true);
// Detailed island station: open view through marble columns to the opposite track.
// Continuous rail approach fills the seam between the arched tunnel and the station hall.
const approachRailBed=mat(0x292d30);
const platform=new THREE.Group();scene.add(platform);
buildPlatformApproach({platform,box,approachRailBed,rail,wood});
// Visible cab stopping marker: local z=-112 aligns with the cab at dist=0, at the tunnel-side end.
const stopMarkerMat=new THREE.MeshBasicMaterial({color:0xffdf35});
box(platform,5.5,.06,.22,0,.12,-112,stopMarkerMat);
for(const x of [-3.05,3.05]){box(platform,.18,3.1,.18,x,1.6,-112,stopMarkerMat);box(platform,.85,.55,.13,x,3.25,-112,stopMarkerMat);}
const entranceGlow=new THREE.Mesh(new THREE.PlaneGeometry(5.8,5.4),new THREE.MeshBasicMaterial({color:0xb8d4e4,transparent:true,opacity:.16,depthWrite:false,side:THREE.DoubleSide}));
entranceGlow.position.set(0,3.4,6.0);platform.add(entranceGlow);
// Bright station lighting, independent of the train headlights.
const stationFill=new THREE.AmbientLight(0xf1f4ff,.95);platform.add(stationFill);
for(let z=-108;z<=5;z+=20){for(const x of [-3.8,3.8]){const lamp=new THREE.PointLight(0xf4f6ff,18,16,2);lamp.position.set(x,7.5,z);platform.add(lamp)}}
const marble=mat(0xe5dfca),floorTile=mat(0xc9c8b9),trim=mat(0x77736e),glass=mat(0x5c8093,.35),doorMat=mat(0xced8dd,.4);
const greenBand=mat(0x24552b),blackGranite=mat(0x17191a),creamWall=mat(0xe8e5d6),warmGold=new THREE.MeshBasicMaterial({color:0xffc25d}),silverRail=mat(0xa7aaa5,.6);
// Glossy cream terrazzo with dark granite strips beside both platform edges.
// Platform edge must meet the carriage threshold: train outer door face x=-2.43,
// new island edge x=-2.55 -> 0.12 m clearance (previously >2 metres).
box(platform,20.2,.045,128,-12.65,.725,-57,new THREE.MeshStandardMaterial({color:0xb8b9b5,roughness:.96}));
for(const x of [-2.84,-22.39])box(platform,.35,.052,128,x,.754,-57,blackGranite);
// Fine terrazzo tile joints and longitudinal seams on the original cream floor.
// Reference station photo: smooth, uninterrupted pale-grey platform surface.
// No decorative square grid or tile joints.
// Right-side station wall, across the player's track: pale ceramic panels, green band and black base.
box(platform,.25,7.0,128,3.58,3.72,-57,creamWall);
box(platform,.30,1.18,128,3.39,.79,-57,blackGranite);
box(platform,.31,.27,128,3.38,1.54,-57,greenBand);
for(let z=4;z>-120;z-=3.5)box(platform,.035,4.6,.025,3.40,4.25,z,trim);
// Painted floral decoration and station names on the wall, facing the cab.
const floralCanvas=document.createElement('canvas');floralCanvas.width=1024;floralCanvas.height=256;
const fc=floralCanvas.getContext('2d');fc.fillStyle='#e8e5d6';fc.fillRect(0,0,1024,256);
fc.fillStyle='#554032';fc.font='bold 89px Georgia,serif';fc.textAlign='center';fc.fillText('МАЛІНАЎКА',512,156);
for(let j=0;j<30;j++){const xx=(j*173+45)%1024,yy=(j*97+37)%220;fc.strokeStyle='#3c7448';fc.lineWidth=3;fc.beginPath();fc.moveTo(xx,yy+35);fc.quadraticCurveTo(xx+13,yy+8,xx+8,yy-18);fc.stroke();for(let k=0;k<3;k++){fc.fillStyle=k===0?'#447c52':'#7b9871';fc.beginPath();fc.ellipse(xx+(k-1)*11,yy+(k-1)*9,7,3.5,(k-1)*.7,0,Math.PI*2);fc.fill();}if(j%4===0){fc.fillStyle='#a85b64';fc.beginPath();fc.arc(xx+8,yy-19,5,0,Math.PI*2);fc.fill();}}
const floralTexture=new THREE.CanvasTexture(floralCanvas);floralTexture.colorSpace=THREE.SRGBColorSpace;
const floralMat=new THREE.MeshBasicMaterial({map:floralTexture,side:THREE.DoubleSide});
for(const z of [-11,-103]){const wallSign=new THREE.Mesh(new THREE.PlaneGeometry(21,4.1),floralMat);wallSign.rotation.y=-Math.PI/2;wallSign.position.set(3.215,4.1,z);platform.add(wallSign);}
// High-resolution route diagram: yellow Malinauka, blue subsequent stops.
// Bilingual wall route diagram, based on the original Malinauka sign.
// Columns run from Urucca at the left to yellow Malinauka at the right.
const routeStops=[
 ['МАЛІНАЎКА','МАЛИНОВКА','110'],['ПЯТРОЎШЧЫНА','ПЕТРОВЩИНА','111'],
 ['МІХАЛОВА','МИХАЛОВО','112'],['ГРУШАЎКА','ГРУШЕВКА','113'],
 ['ІНСТЫТУТ КУЛЬТУРЫ','ИНСТИТУТ КУЛЬТУРЫ','114'],
 ['ПЛОШЧА ЛЕНІНА','ПЛОЩАДЬ ЛЕНИНА','115'],
 ['КАСТРЫЧНІЦКАЯ','ОКТЯБРЬСКАЯ','116'],
 ['ПЛОШЧА ПЕРАМОГІ','ПЛОЩАДЬ ПОБЕДЫ','117'],
 ['ПЛОШЧА ЯКУБА КОЛАСА','ПЛОЩАДЬ ЯКУБА КОЛАСА','118'],
 ['АКАДЭМІЯ НАВУК','АКАДЕМИЯ НАУК','119'],
 ['ПАРК ЧАЛЮСКІНЦАЎ','ПАРК ЧЕЛЮСКИНЦЕВ','120'],
 ['МАСКОЎСКАЯ','МОСКОВСКАЯ','121'],['УСХОД','ВОСТОК','122'],
 ['БАРЫСАЎСКІ ТРАКТ','БОРИСОВСКИЙ ТРАКТ','123'],['УРУЧЧА','УРУЧЬЕ','124']
];
const routeCanvas=document.createElement('canvas');routeCanvas.width=4096;routeCanvas.height=920;
const rc=routeCanvas.getContext('2d');
rc.fillStyle='#e9e5d7';rc.fillRect(0,0,4096,920);
const cellW=255,firstX=242,top=48;
function routeCircle(x,y,r,color,label,textColor='#ffffff'){
 rc.fillStyle=color;rc.beginPath();rc.arc(x,y,r,0,Math.PI*2);rc.fill();
 rc.fillStyle=textColor;rc.textAlign='center';rc.textBaseline='middle';
 rc.font='bold '+Math.floor(r*.88)+'px Arial';rc.fillText(label,x,y+2);
}
for(let i=0;i<routeStops.length;i++){
 const x=firstX+(routeStops.length-1-i)*cellW,selected=i===0;
 rc.fillStyle=selected?'#e2aa17':'#292653';
 // Slanted trapezoid: BOTH top and bottom edges rise to the right,
 // matching the diagonal station panels on the real wall diagram.
 rc.beginPath();rc.moveTo(x-93,top+64);rc.lineTo(x+132,top+8);
 rc.lineTo(x+76,top+605);rc.lineTo(x-149,top+661);rc.closePath();rc.fill();
 rc.strokeStyle='#eee9d9';rc.lineWidth=7;rc.stroke();
 // Each station carries both Belarusian and Russian names, on separate lines.
 rc.save();rc.translate(x-65,top+435);rc.rotate(-Math.PI/3.1);
 rc.textAlign='left';rc.textBaseline='middle';rc.fillStyle=selected?'#24204b':'#ffffff';
 const labels=[routeStops[i][0],routeStops[i][1]];
 rc.font='bold 32px Arial';
 for(let language=0;language<2;language++){
  const words=labels[language].split(' '),lines=[];let line='';
  for(const word of words){const candidate=line?line+' '+word:word;
   if(rc.measureText(candidate).width>350&&line){lines.push(line);line=word}else line=candidate}
  if(line)lines.push(line);
  lines.slice(0,3).forEach((txt,k)=>rc.fillText(txt,0,(language===0?-64:28)+k*38));
 }
 rc.restore();
 routeCircle(x,top+654,52,selected?'#e2aa17':'#292653',routeStops[i][2],selected?'#292653':'#ffffff');
}
// Interchange markers and their labels beneath the respective station circles.
function interchange(stationNumber,number,color,titleBel,titleRu){
 const i=routeStops.findIndex(s=>s[2]===stationNumber);
 const x=firstX+(routeStops.length-1-i)*cellW;
 rc.strokeStyle=color;rc.lineWidth=9;rc.beginPath();rc.moveTo(x,top+707);rc.lineTo(x,top+737);rc.stroke();
 routeCircle(x,top+779,38,color,number);
 rc.fillStyle=color;rc.font='bold 24px Arial';rc.textBaseline='middle';
 if(stationNumber==='116'){rc.textAlign='right';rc.fillText(titleBel,x-47,top+768);rc.fillText(titleRu,x-47,top+797)}
 else {rc.textAlign='left';rc.fillText(titleBel,x+47,top+768);rc.fillText(titleRu,x+47,top+797)}
}
interchange('116','2','#c52c32','КУПАЛАЎСКАЯ','КУПАЛОВСКАЯ');
interchange('115','3','#177a49','ВАКЗАЛЬНАЯ','ВОКЗАЛЬНАЯ');
rc.strokeStyle='#f4f1e8';rc.lineWidth=11;rc.strokeRect(12,12,4072,895);
const routeTexture=new THREE.CanvasTexture(routeCanvas);routeTexture.colorSpace=THREE.SRGBColorSpace;
routeTexture.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());
const routePanel=new THREE.Mesh(new THREE.PlaneGeometry(13.6,2.12),new THREE.MeshBasicMaterial({map:routeTexture,side:THREE.DoubleSide}));
routePanel.rotation.y=-Math.PI/2;routePanel.position.set(3.17,2.735,-55);platform.add(routePanel);
const routeFrame=mat(0xd1d1c8,.35);
// Green strip top = 1.54 + .27/2 = 1.675; board bottom aligns with it.
for(const y of [1.675,3.795])box(platform,.05,.035,13.66,3.14,y,-55,routeFrame);
for(const z of [-61.83,-48.17])box(platform,.05,2.16,.035,3.14,2.735,z,routeFrame);


box(platform,20.2,.8,128,-12.65,.30,-57,new THREE.MeshStandardMaterial({color:0xb8b9b5,roughness:.96}));
box(platform,.16,.07,128,-2.94,.78,-57,yellow);
// Single central island platform: the player drives on the RIGHT-hand track.
// The opposite track lies beyond the LEFT-hand row of columns.
box(platform,.16,.07,128,-22.73,.74,-57,yellow);
// Yellow safety line exists only along the two actual island platform edges.
// Station hall: columns rather than a solid wall. Opposite side remains visible.
for(let j=0;j<13;j++){const z=5-j*10;
for(const x of [-5.65,-21.65]){
 const column=new THREE.Mesh(new THREE.CylinderGeometry(.53,.56,6.15,48),marble);column.position.set(x,3.93,z);platform.add(column);
 const base=new THREE.Mesh(new THREE.CylinderGeometry(.62,.62,.65,48),greenBand);base.position.set(x,1.13,z);platform.add(base);
 for(const yy of [.79,1.45]){const ring=new THREE.Mesh(new THREE.TorusGeometry(.65,.045,8,24),silverRail);ring.rotation.x=Math.PI/2;ring.position.set(x,yy,z);platform.add(ring);}
 const crown=new THREE.Mesh(new THREE.CylinderGeometry(.73,.62,.22,48),marble);crown.position.set(x,7.08,z);platform.add(crown);
 // Three decorated columns on the platform's track-facing row.
 if(x===-5.65 && j>=3 && j<=5){
  const relief=mat(0xd8c7a1);
  // Raised botanical relief wrapping the visible half of each decorated column.
  for(let n=0;n<7;n++){
   const y=1.85+n*.68, angle=n*.93;
   const points=[];
   for(let k=0;k<=18;k++){const a=-1.30+k*2.6/18+angle*.18;points.push(new THREE.Vector3(x+.565*Math.cos(a),y+.26*Math.sin(a*1.8),z+.565*Math.sin(a)));}
   platform.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),30,.052,8,false),relief));
   for(const a of [-.7,.5]){const leaf=new THREE.Mesh(new THREE.SphereGeometry(.15,12,8),relief);leaf.scale.set(.45,1.3,.35);leaf.position.set(x+.58*Math.cos(a),y+.22,z+.58*Math.sin(a));leaf.rotation.y=a;platform.add(leaf);}
  }
  const halo=new THREE.Mesh(new THREE.TorusGeometry(.77,.11,12,48),warmGold);halo.rotation.x=Math.PI/2;halo.position.set(x,7.22,z);platform.add(halo);
  const diffuser=new THREE.Mesh(new THREE.CylinderGeometry(.86,.86,.06,48),new THREE.MeshBasicMaterial({color:0xffd995}));diffuser.position.set(x,7.23,z);platform.add(diffuser);
  const glow=new THREE.PointLight(0xffb344,26,8,2);glow.position.set(x,6.85,z);platform.add(glow);
 }
}
box(platform,19.3,.15,.28,-13.65,7.04,z,marble);
box(platform,2.3,.12,1.15,-5.4,6.98,z,light);box(platform,2.3,.12,1.15,-21.9,6.98,z,light);
}
box(platform,18.4,.14,128,-13.65,7.15,-57,marble);
// Spacious station concourse: tall ceiling, tiled floor and track bed, tunnel portal at far end.
const hallRoof=mat(0xece9dd),hallTrim=mat(0x9d9990),portalBlack=new THREE.MeshBasicMaterial({color:0x060a0f});
box(platform,31.5,.32,128,-12.0,8.35,-57,hallRoof);
// Long luminous recessed ceiling above the central pedestrian concourse.
box(platform,15.1,.025,127,-13.65,8.16,-57,new THREE.MeshBasicMaterial({color:0xfffdf2}));
for(const x of [-5.55,-21.75])box(platform,.14,.16,127,x,8.04,-57,trim);
for(let j=0;j<17;j++){const z=5-j*7.5;box(platform,31.5,.035,.07,-12.0,8.09,z,hallTrim);box(platform,2.3,.08,1.2,-2.9,8.05,z,light)}
box(platform,5,.28,128,0,-.22,-57,otherTrackPlaceholder());
function otherTrackPlaceholder(){return mat(0x313439)}
for(const x of [-1.15,1.15])box(platform,.12,.16,128,x,.02,-57,rail);
for(let j=0;j<65;j++)box(platform,4.1,.12,.3,0,-.08,5-j*2,wood);
// Portal frame, tunnel mouth and receding track visible beyond station end.
const portalZ=-118;
// Portal is an actual opening, not an opaque black rectangle.
for(const x of [-2.9,2.9])box(platform,.48,6.7,.6,x,3.45,portalZ+.6,hallTrim);
box(platform,6.2,.45,.6,0,6.75,portalZ+.6,hallTrim);
for(let j=0;j<8;j++){const z=portalZ-3-j*5;for(const x of [-1.15,1.15])box(platform,.1,.12,5,x,.04,z,rail);box(platform,5,.1,.22,0,-.12,z,wood)}
// Real station clocks: Minsk local time and elapsed time since previous train departure.
const clockCanvas=document.createElement('canvas');clockCanvas.width=1024;clockCanvas.height=240;
const clockContext=clockCanvas.getContext('2d');const clockTexture=new THREE.CanvasTexture(clockCanvas);
const clockBoard=new THREE.Mesh(new THREE.PlaneGeometry(7.2,1.7),new THREE.MeshBasicMaterial({map:clockTexture,side:THREE.DoubleSide,transparent:false}));
clockBoard.position.set(0,7.1,-26);platform.add(clockBoard);
const departureTimes=[Date.now()-92000,Date.now()-128000,Date.now()-105000,Date.now()-119000];let lastClockSecond=-1;
function updateStationClock(){const now=Date.now(),second=Math.floor(now/1000);if(lastClockSecond===second)return;lastClockSecond=second;
const c=clockContext;c.fillStyle='#06080a';c.fillRect(0,0,1024,240);c.strokeStyle='#f0d680';c.lineWidth=10;c.strokeRect(5,5,1014,230);
c.fillStyle='#fff3bb';c.font='bold 34px Arial';c.textAlign='center';c.fillText('ТЕКУЩЕЕ ВРЕМЯ',256,42);c.fillText('ИНТЕРВАЛ',768,42);
const clock=new Intl.DateTimeFormat('ru-RU',{timeZone:'Europe/Minsk',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false}).format(new Date(now));
const elapsed=Math.max(0,Math.floor((now-departureTimes[index%departureTimes.length])/1000));
const interval=String(Math.floor(elapsed/60)).padStart(2,'0')+':'+String(elapsed%60).padStart(2,'0');
c.fillStyle='#ff5145';c.font='bold 102px monospace';c.fillText(clock,256,151);c.fillText(interval,768,151);
c.font='22px Arial';c.fillStyle='#b3bbc1';c.fillText('МИНСК',256,198);c.fillText('ПОСЛЕ ПРЕДЫДУЩЕГО ПОЕЗДА',768,198);clockTexture.needsUpdate=true}
// Clock starts only after station index is initialized.
// Opposite track and a blue-and-silver metro train visible beyond the platform.
const otherTrack=mat(0x3b4147),trainBlue=mat(0x1a579a,.3),windowDark=mat(0x122938,.15),stripe=mat(0xe1e8ee,.25);
box(platform,3.8,.18,125,-25.25,-.15,-57,otherTrack);
for(const x of [-26.4,-24.1])box(platform,.12,.12,125,x,.01,-57,rail);
const oppositeTrain=new THREE.Group();oppositeTrain.position.set(-25.25,.45,-56);platform.add(oppositeTrain);
for(let car=0;car<5;car++){let z=car*22-44;box(oppositeTrain,2.5,3.15,21,0,1.85,z,stripe);box(oppositeTrain,2.55,1.1,21,0,2.0,z,trainBlue);box(oppositeTrain,2.54,.25,21,0,3.28,z,trainBlue);
for(let k=0;k<5;k++){let zz=z-8+k*3.7;box(oppositeTrain,.045,1.03,1.7,-1.285,2.55,zz,windowDark);box(oppositeTrain,.045,1.03,1.7,1.285,2.55,zz,windowDark)}
for(let k=0;k<3;k++){let zz=z-6+k*6;box(oppositeTrain,.065,2.3,1.35,-1.295,1.55,zz,doorMat);box(oppositeTrain,.065,2.3,1.35,1.295,1.55,zz,doorMat)}}
const carriageCamera=new THREE.PerspectiveCamera(72,innerWidth/innerHeight,.08,90);
carriageCamera.position.set(1.72,2.78,-19.88);
const carriage=new THREE.Group();
// The carriage is now part of the actual station/track scene. The camera is
// parented to it, so the existing local camera controls remain unchanged.
scene.add(carriage);
carriage.add(carriageCamera);
// Align both detailed carriage doorways with the exterior first car.
carriage.position.set(-.49,.10,32.6785714286);carriage.scale.z=10.5/9.8;
const {updateCarriageStationDisplay,materials:{carCream,carWhite,carFloor,carSeat,carSteel,carBlack,carDoor,carGlass,carLight}}=buildCarriageInterior({THREE,carriage,box,getStationName:()=>names[index%names.length]});

const carSlidingDoorLeaves=buildCarriageDoors({THREE,carriage,box,carSteel,carDoor,carCream,carGlass});
let carCameraActive=false;
const carCameraButton=document.getElementById('carCameraToggle');
carCameraButton.addEventListener('click',()=>{
 carCameraActive=!carCameraActive;
 if(carCameraActive){carriageCameraController.reset();}
 if(carCameraActive){stationCameraActive=false;stationCameraButton.classList.remove('active');stationCameraButton.textContent='📷 ВИД НА ПЛАТФОРМУ';}
 carCameraButton.classList.toggle('active',carCameraActive);
 carCameraButton.textContent=carCameraActive?'🎮 В КАБИНУ':'🚇 ВИД В ВАГОНЕ';
});
const stationCanvas=document.querySelector('#scene');
const carriageCameraController=createCarriageCameraController(THREE,carriageCamera,stationCanvas,()=>carCameraActive);
const passengerParams=new URLSearchParams(location.search);
const passengerSystem=new PassengerSystem({scene,platform,carriage,seed:passengerParams.has('passengerSeed')?Number(passengerParams.get('passengerSeed')):Date.now()});
let passengerInspectionCamera=null;
function updatePlatformPassengers(dt){
 const first=stationDoorLeaves[0];
 const aperture=first?Math.max(0,Math.min(1,((first.leaf.position.z-first.doorZ)*first.half-.53)/1.03)):0;
 const activeCamera=passengerInspectionCamera??(carCameraActive?carriageCamera:stationCameraActive?stationCamera:camera);
 passengerSystem.update(dt,{station:index,dist,speed,doorsOpen:doors&&!stationDoorCycleCompleted,aperture},activeCamera,
  {mirrorCameras:rearMirrors.filter(m=>m.enabled).map(m=>m.mirrorCamera),volume:cabVolume,inCab:!carCameraActive&&!stationCameraActive,playing});
 people=passengerSystem.simulation.agents.filter(a=>a.space==='train'&&a.state!=='gone').length;
 if(consumePassengerDeparture(passengerSystem))setCabDoors(false);
}
const {signCanvas,sc,texture,sign}=buildPlatformFurniture({THREE,platform,box,wood,steel});
const names=['Малиновка','Петровщина','Михалово','Грушевка','Институт культуры','Площадь Ленина','Октябрьская','Площадь Победы','Площадь Якуба Коласа','Академия наук','Парк Челюскинцев','Московская','Восток','Борисовский тракт','Уручье'];let index=0,dist=1100,speed=0,people=0,lever=0,doors=false,playing=false,yaw=0,pitch=-.32,targetYaw=0,targetPitch=-.32,last=performance.now();
// Development shortcuts: ?preview=station or ?preview=approach.
const previewMode=new URLSearchParams(location.search).get('preview');
// Initialize station display only after station names and index exist.
updateCarriageStationDisplay();
// Continuous travel: station changes only AFTER the entire platform is behind the cab.
const interstationDistance=1250,platformExitDistance=-195,stopTolerance=3;
let stationServiced=false,overrunReported=false,stationSkipped=false,skipDepartureSeconds=0;
// A short-stop door violation is counted once per stationary episode.
// Moving forward starts a new episode, even at the same station.
let shortStopErrorRecorded=false,shortStopErrorPosition=null;
// Deduplicate only within one station; every new station can generate a new serious error.
const stationsWithRecordedOverrun=new Set();
const stopWarning=document.createElement('div');
stopWarning.id='stationStopWarning';
const warningStyle=document.createElement('style');warningStyle.textContent='@keyframes metroStopErrorBlink{0%,48%{opacity:1}49%,80%{opacity:.25}81%,100%{opacity:1}} #stationStopWarning{animation:metroStopErrorBlink .8s infinite}';document.head.appendChild(warningStyle);
Object.assign(stopWarning.style,{position:'fixed',top:'12%',left:'50%',transform:'translateX(-50%)',zIndex:'10000',maxWidth:'92vw',padding:'12px 18px',border:'3px solid #ff3030',borderRadius:'10px',background:'rgba(55,0,0,.94)',color:'#fff',font:'bold 19px Arial,sans-serif',textAlign:'center',boxShadow:'0 0 22px #f00',pointerEvents:'none',display:'none'});
document.body.appendChild(stopWarning);
function showStopWarning(message,permanent=false){
 clearTimeout(showStopWarning.timer);
 stopWarning.textContent='⛔ '+message;
 stopWarning.style.display='block';
 if(!permanent)showStopWarning.timer=setTimeout(()=>{stopWarning.style.display='none';},4500);
}
function markStationSkipped(){
 if(stationSkipped||stationServiced)return;
 stationSkipped=true;overrunReported=true;skipDepartureSeconds=0;
 if(!stationsWithRecordedOverrun.has(index)){
  stationsWithRecordedOverrun.add(index);
  reportDriverError('грубое нарушение на станции '+names[index]+': проезд знака остановки более чем на 3 метра, станция пропущена',true);
 }
 showStopWarning('ГРУБАЯ ОШИБКА МАШИНИСТА! ОБСЛУЖИВАНИЕ СТАНЦИИ ЗАПРЕЩЕНО. ПРОДОЛЖАЙТЕ ДВИЖЕНИЕ К СЛЕДУЮЩЕЙ СТАНЦИИ',true);
}
const stationCameraButton=document.getElementById('stationCameraToggle');let stationCameraActive=false,stationViewYaw=0,stationViewPitch=0,stationCameraAnchorZ=0,stationCameraTrainZ=0;
const screenDoorToggle=document.getElementById('screenDoorToggle');
function syncScreenDoorToggle(){if(!screenDoorToggle)return;screenDoorToggle.classList.toggle('open',doors);screenDoorToggle.setAttribute('aria-pressed',String(doors));screenDoorToggle.setAttribute('aria-label',doors?'Закрыть двери':'Открыть двери');}
screenDoorToggle?.addEventListener('click',e=>{e.stopPropagation();cabCommands.command('toggleDoors');syncScreenDoorToggle();});

// Drag directly on the 3D picture to pan the external camera; touch and mouse.
let stationDrag=null;
stationCanvas.addEventListener('pointerdown',e=>{if(!stationCameraActive)return;stationDrag={id:e.pointerId,x:e.clientX,y:e.clientY};stationCanvas.setPointerCapture(e.pointerId);e.preventDefault();});
stationCanvas.addEventListener('pointermove',e=>{if(!stationCameraActive||!stationDrag||stationDrag.id!==e.pointerId)return;stationViewYaw=THREE.MathUtils.clamp(stationViewYaw+(stationDrag.x-e.clientX)*.0022,-.23,.23);stationViewPitch=THREE.MathUtils.clamp(stationViewPitch+(e.clientY-stationDrag.y)*.0015,-.12,.12);stationDrag.x=e.clientX;stationDrag.y=e.clientY;e.preventDefault();});
for(const evt of ['pointerup','pointercancel'])stationCanvas.addEventListener(evt,e=>{if(stationDrag?.id===e.pointerId)stationDrag=null;});
stationCameraButton.addEventListener('click',()=>{if(Math.abs(dist)>=32||speed>=1.5||!playing)return;carCameraActive=false;carCameraButton.classList.remove('active');carCameraButton.textContent='🚇 ВИД В ВАГОНЕ';stationCameraActive=!stationCameraActive;if(stationCameraActive){stationCameraAnchorZ=platform.position.z-100;stationCameraTrainZ=12;}stationViewYaw=0;stationViewPitch=0;stationCameraButton.classList.toggle('active',stationCameraActive);stationCameraButton.textContent=stationCameraActive?'🎮 В КАБИНУ':'📷 ВИД НА ПЛАТФОРМУ';});
updateStationClock();
syncDoorButtons();
function paintSign(){sc.fillStyle='#155b87';sc.fillRect(0,0,768,128);sc.fillStyle='white';sc.font='bold 52px Arial';sc.textAlign='center';sc.fillText(names[index%names.length],384,83);texture.needsUpdate=true}paintSign();

// Recorded CC0 metro audio. No oscillators, noise synthesis or generated chimes.
// Real metro audio from the three user-approved recordings, hosted in this repository.
// Real recordings stored under /audio in this repository (no external hosts).
const metroRecordings={idle:'audio/idle.mp3',acceleration:'audio/acceleration.mp3',cruise:'audio/cruise.mp3',braking:'audio/braking.mp3'};
let metroAudio=null;
function initMetroAudio(){
 if(metroAudio)return;
 const make=(name)=>{const audio=new Audio(metroRecordings[name]);audio.preload='auto';audio.loop=true;audio.volume=0;audio.addEventListener('error',()=>{const status=document.querySelector('#status');if(status)status.textContent='⚠ Звук не загружен: '+name+'.mp3 — добавьте файлы в папку audio на GitHub';console.warn('Missing metro audio:',audio.src)});return audio};
 const idle=make('idle'),acceleration=make('acceleration'),cruise=make('cruise'),braking=make('braking');
 metroAudio={idle,acceleration,cruise,braking,previousSpeed:0};
 // Unlock playback in the Start Ride user gesture; keep sources running silently.
 for(const audio of [idle,acceleration,cruise,braking])audio.play().catch(e=>console.warn('Metro audio playback:',e));
 idle.volume=.22;
}
function updateMetroAudio(v,traction){
 const a=metroAudio;if(!a)return;
 const moving=v>1,brake=traction<-.04&&moving,accelerate=traction>.04&&moving;
 const targets=[
  [a.idle,moving?.035:.23],
  [a.acceleration,accelerate?Math.min(.72,.20+v/190):0],
  [a.cruise,moving?Math.min(.60,.10+v/180)*(brake?.35:accelerate?.55:1):0],
  [a.braking,brake?Math.min(.75,.27+v/190):0]
 ];
 for(const [audio,target] of targets){
  // Avoid repeated play attempts on missing files.
  if(audio.paused&&audio.readyState>=2)audio.play().catch(()=>{});
  audio.volume=Math.max(0,Math.min(1,audio.volume+(target*cabVolume-audio.volume)*.12));
 }
 a.acceleration.playbackRate=Math.max(.82,Math.min(1.2,.86+v/260));
 a.cruise.playbackRate=Math.max(.9,Math.min(1.12,.92+v/440));
}
function metroChime(open){/* No synthesized door noise. Add a real door file later. */}
function speak(t){if(!('speechSynthesis'in window))return;speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(t);u.lang='ru-RU';u.rate=.9;speechSynthesis.speak(u)}
function startRide(){playing=true;try{initMetroAudio()}catch(e){console.warn('Metro audio unavailable:',e)}}window.addEventListener('metro-start',startRide);if(window.metroStarted)startRide();
const masterTrack=document.querySelector('#masterTrack'),masterHandle=document.querySelector('#masterHandle'),masterValue=document.querySelector('#masterValue');
function setTrainLever(value){
 lever=Math.max(-1,Math.min(1,Number(value)||0));
 masterHandle.style.top=(50-lever*43)+'%';
 masterValue.textContent=(lever>.04?'ТЯГА':lever<-.04?'ТОРМОЗ':'НЕЙТРАЛЬ')+' · '+Math.round(Math.abs(lever)*100)+'%';
}
let cabVolume=.6,hornContext=null,hornGain=null,hornNodes=[];
function setCabHorn(on){
 if(on&&!hornContext){const AudioContext=window.AudioContext||window.webkitAudioContext;if(!AudioContext)return false;hornContext=new AudioContext();hornGain=hornContext.createGain();hornGain.gain.value=0;hornGain.connect(hornContext.destination);
  for(const hz of [330,440]){const o=hornContext.createOscillator();o.type='sine';o.frequency.value=hz;o.connect(hornGain);o.start();hornNodes.push(o);}}
 if(hornContext){hornContext.resume().catch(()=>{});hornGain.gain.setTargetAtTime(on?.07*cabVolume:0,hornContext.currentTime,.025);}
 return true;
}
const cabCommands=createCabCommands({
 getTrain:()=>{const leaf=stationDoorLeaves[0],travel=leaf?THREE.MathUtils.clamp((Math.abs(leaf.leaf.position.z-leaf.doorZ)-.53)/1.03,0,1):0;return {speed,lever,doors,info:infoPlaying,stationDistance:dist,doorTravel:travel,doorsClosed:!doors&&travel<.005,doorsMoving:travel>.005&&travel<.995}},setLever:setTrainLever,setDoors:setCabDoors,info:pressInfo,
 setHeadlights:on=>headlights.forEach(l=>l.visible=on),
 setMirror:(side,on)=>{const m=rearMirrors.find(m=>m.side===side);m.enabled=on;m.face.visible=on;},
 camera:id=>{if(id==='carriage'){document.querySelector('#carCameraToggle').click();return true;}
  if(id==='platform'){const b=document.querySelector('#stationCameraToggle');if(b.style.display==='none'){status.textContent='Камера платформы доступна у станции';return false;}b.click();return true;}
  if(carCameraActive)document.querySelector('#carCameraToggle').click();if(stationCameraActive)document.querySelector('#stationCameraToggle').click();targetYaw=0;targetPitch=id==='desk'?-.49:-.03;return true;},
 notify:message=>{status.textContent=message},horn:setCabHorn,setVolume:v=>{cabVolume=v;departureAudio.volume=v;}
});
const cabInteraction=installCabInteraction({THREE,canvas:renderer.domElement,camera,cab,controls:cabModel.controls,commands:cabCommands,isActive:()=>playing&&!stationCameraActive&&!carCameraActive,isRunning:()=>playing});
function setMaster(e){const r=masterTrack.getBoundingClientRect();cabCommands.command('master',(.5-(e.clientY-r.top)/r.height)*2)}
masterTrack.addEventListener('pointerdown',e=>{e.preventDefault();masterTrack.setPointerCapture(e.pointerId);setMaster(e)});
masterTrack.addEventListener('pointermove',e=>{if(masterTrack.hasPointerCapture(e.pointerId))setMaster(e)});
document.querySelector('#doors')?.addEventListener('click',()=>cabCommands.command('toggleDoors'));
let lookPointer=null,lookX=0,lookY=0;const view=document.querySelector('#scene');
view.addEventListener('pointerdown',e=>{lookPointer=e.pointerId;lookX=e.clientX;lookY=e.clientY;view.setPointerCapture(e.pointerId)});
view.addEventListener('pointermove',e=>{if(lookPointer!==e.pointerId)return;targetYaw=Math.max(-1.04,Math.min(1.04,targetYaw-(e.clientX-lookX)*.004));targetPitch=Math.max(-.68,Math.min(.35,targetPitch-(e.clientY-lookY)*.004));lookX=e.clientX;lookY=e.clientY});
for(const type of ['pointerup','pointercancel'])view.addEventListener(type,e=>{if(lookPointer===e.pointerId)lookPointer=null});
const lookBar=document.createElement('nav');lookBar.id='cabLookBar';lookBar.setAttribute('aria-label','Обзор кабины');
for(const [id,text,y,p] of [['forward','Путь',0,-.03],['desk','Пульт',0,-.49],['left','Слева',.62,-.33],['right','Справа',-.62,-.33]]){const b=document.createElement('button');b.textContent=text;b.id='cabView-'+id;b.onclick=()=>{if(carCameraActive||stationCameraActive)return;targetYaw=y;targetPitch=p;};lookBar.append(b);}
const hudButton=document.createElement('button');hudButton.textContent='Рычаг';hudButton.id='cabHudToggle';hudButton.setAttribute('aria-expanded','false');hudButton.onclick=()=>{const open=document.body.classList.toggle('cab-hud-open');hudButton.setAttribute('aria-expanded',String(open));};lookBar.append(hudButton);document.body.append(lookBar);
if(new URLSearchParams(location.search).has('cabCapture'))document.body.classList.add('cab-capture');
const cabFrameTimes=[];
const status=document.querySelector('#status');for(let i=0;i<30;i++){const a=document.createElement('div');a.className='lamp';document.querySelector('#rightPanel').appendChild(a)}
function resize(){resizeCameras(renderer,[camera,stationCamera,carriageCamera],innerWidth,innerHeight);camera.fov=innerWidth/innerHeight<.85?74:66;camera.updateProjectionMatrix()}
resize();addEventListener('resize',resize);
function frame(now){requestAnimationFrame(frame);try{const frameMs=Math.max(0,now-last);const elapsed=Math.max(0,Math.min(.25,frameMs/1000));const dt=Math.min(.05,elapsed);last=now;if(cabFrameTimes.length>=180)cabFrameTimes.shift();cabFrameTimes.push(frameMs);if(playing){// Keep physics on real elapsed time even when phone renders below 20 FPS.
if(doors){
 if(lever>.015){reportDriverError('попытка отправления с открытыми дверями');}
 lever=0;speed=0;
 masterHandle.style.top='50%';masterValue.textContent='НЕЙТРАЛЬ · 0%';
}
for(let remaining=elapsed;remaining>1e-8;){const step=Math.min(.05,remaining);speed=stepTrainMotion(speed,lever,step);remaining-=step;}
let move=speed/3.6*elapsed*1.22;
 // Reset only after the train actually moves; repeated button presses while stopped do not count.
 if(shortStopErrorRecorded&&shortStopErrorPosition!==null&&shortStopErrorPosition-dist>0.5){shortStopErrorRecorded=false;shortStopErrorPosition=null;}
// The stop marker is at dist=0. Before passenger service, the cab may
// overshoot by 24 m; the safety limiter then stops the train and records
// exactly one driver error. After servicing, the train may depart freely.
// Passing more than 1 m beyond the marker permanently skips this station.
// Do not stop the train artificially: the driver must continue to the next station.
if(!stationServiced&&!stationSkipped&&dist-move < -stopTolerance)markStationSkipped();
// Keep the serious-error warning visible until the driver resumes moving;
 // after two seconds of actual forward travel, remove the overlay only.
 if(stationSkipped&&stopWarning.style.display!=='none'&&speed>1&&move>0){
  skipDepartureSeconds+=elapsed;
  if(skipDepartureSeconds>=2)stopWarning.style.display='none';
 }
 updateMetroAudio(speed,lever);dist-=move;
if((stationServiced||stationSkipped)&&dist<platformExitDistance&&index<names.length-1){
 // No camera/train teleport: only the NEXT platform is repositioned
 // ahead after the previous platform has disappeared behind the cab.
 index++;dist+=interstationDistance;
 stationServiced=false;stationDoorCycleCompleted=false;stationDoorReopenPenalty=false;overrunReported=false;stationSkipped=false;skipDepartureSeconds=0;shortStopErrorRecorded=false;shortStopErrorPosition=null;stopWarning.style.display='none';
 infoArrivalPlayed=false;infoStarted=false;infoCompleted=false;
 paintSign();updateCarriageStationDisplay();
 status.textContent='Следующая станция — '+names[index];
}
depot.position.z+=move;
const travelled=depot.position.z;
const verticalShift=trackDrop(travelled);
// Keep the driver's cab fixed and move the entire track world upward by the
// train's lost altitude. Ramp sleepers, rails and tunnel remain at wheel level.
// Keep fixed world geometry at its real altitude. The CAMERA follows the
// descending track; raising the depot made the tunnel roof pass through it.
depot.position.y=verticalShift;
animateDepotWorkers(now);
for(const g of chunks){
 g.position.z+=move;
 if(g.position.z>32)g.position.z-=chunks.length*32;
 g.position.y=verticalShift-descentDepth;
}
platform.position.z=-dist+112;
// The carriage window environment follows the exact same station-distance coordinate.
// At the stop marker the local platform is aligned; on approach/departure it moves past the windows.
// Positive local Z is behind the forward-facing carriage camera. As the train
// advances, station geometry must slide toward +Z (left in this camera view).
// The independent mock-up is unused; actual station is platform in scene.
platform.position.y=verticalShift-descentDepth;const stationEntrance=platform.position.z+6;
 // The station hall must replace tunnel walls, not be enclosed by them.
 // Tunnel chunks ahead of the station portal remain visible; chunks inside the hall are hidden.
 for(const g of chunks){const chunkFar=g.position.z-32;g.visible=(chunkFar>stationEntrance+3 || g.position.z<stationEntrance-145);}
 // Fade daylight into the tunnel instead of abruptly switching to black fog
 // at the portal. Fog must not hide the visible downhill rails.
 const underground=smoothstep01((travelled-descentStart)/(descentEnd-descentStart+45));
 // Only reveal a brighter station mouth when its platform is actually within sight.
 // A dark tunnel end must not be replaced by a daylight-coloured fog wall.
 const stationVisible=underground*smoothstep01((170-dist)/75);
 const outdoorFog=new THREE.Color(0x11161a),tunnelFog=new THREE.Color(0x05080b),stationFogColor=new THREE.Color(0x242b31);
 scene.fog.color.copy(outdoorFog).lerp(tunnelFog,underground).lerp(stationFogColor,stationVisible*.58);
 scene.background.copy(scene.fog.color);
 scene.fog.near=THREE.MathUtils.lerp(48,27,underground);
 scene.fog.far=THREE.MathUtils.lerp(195,125,underground);
 if(stationVisible>0){scene.fog.far=THREE.MathUtils.lerp(scene.fog.far,165,stationVisible);}
 sun.intensity=THREE.MathUtils.lerp(.78,.04,underground);
 skyFill.intensity=THREE.MathUtils.lerp(.38,.06,underground);
 updateStationClock();}yaw+=(targetYaw-yaw)*Math.min(1,dt*7);pitch+=(targetPitch-pitch)*Math.min(1,dt*7);camera.rotation.order='YXZ';camera.rotation.y=yaw;camera.rotation.x=pitch-0.06*(smoothstep01((depot.position.z-descentStart)/32)-smoothstep01((depot.position.z-descentEnd)/32));/* Rotate the head within the seat; cab geometry remains in world space. */camera.position.x=Math.sin(now*.014)*Math.min(speed/70,1)*.01+Math.sin(yaw)*.045;camera.position.y=3.35+Math.sin(pitch)*.035;updatePlatformPassengers(elapsed);
animateCarriageDoors(carSlidingDoorLeaves,doors,elapsed);
// Only expose the interior geometry when viewing from the carriage camera.
// It must not block the cab windscreen or rear-view mirrors.
carriage.visible=carCameraActive;
stationTrain.position.set(-.31,platform.position.y,12);stationTrain.visible=!carCameraActive;reflectedTrain.visible=false;
animateDoorLeaves(stationDoorLeaves,doors,elapsed);try{renderRearMirrors()}catch(mirrorError){console.warn('Mirror rendering disabled:',mirrorError);window.metroMirrorsDisabled=true;}renderer.setRenderTarget(null);cab.visible=true;cabModel.update(elapsed,cabCommands.snapshot());document.querySelector('#speed').textContent=Math.round(speed);document.querySelector('#station').textContent=names[index%names.length]+' · '+Math.max(0,Math.round(dist))+' м';document.querySelector('#people').textContent='Пассажиры: '+people;if(Math.abs(dist)<=stopTolerance&&speed<.5&&!doors&&!stationServiced&&!stationSkipped&&!overrunReported)status.textContent='Остановка у ограничителя — открой двери';const canUseStationCamera=playing&&Math.abs(dist)<32&&speed<1.5;
stationCameraButton.style.display=(canUseStationCamera||stationCameraActive)?'block':'none';
// Keep the platform camera stationary while the departing train drives away.
// Return to the cab only when the whole ~108m train has cleared the shot.
if(stationCameraActive&&dist< -145){stationCameraActive=false;stationCameraButton.classList.remove('active');stationCameraButton.textContent='📷 ВИД НА ПЛАТФОРМУ';}
if(stationCameraActive){
 cab.visible=false;
 // Elevated view from the platform corner, looking along the train and boarding area.
 // Previous camera was ABOVE the opaque station ceiling (y=8.35),
 // so it showed only the bright roof instead of the train and passengers.
 // Keep the camera below the ceiling, above the platform, and point it
 // diagonally along the player's track. Train aligns with station hall.
 // Train is moved 0.20m toward the island platform; the doorway outer
 // surface is now nearly flush with the edge (clearance approx 0.1m).
 // Door outer skin sits ~0.04 m from the platform edge.
 // The world moves past the stationary cab. Keep the platform camera attached
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
 renderer.render(scene,passengerInspectionCamera??carriageCamera);
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
