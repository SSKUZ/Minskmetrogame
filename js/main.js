import {stepTrainMotion} from './train/TrainPhysics.js?v=20261026-physics-fps-fix';
import {clampView,restoreViewport,resizeCameras,chooseCamera} from './core/CameraManager.js';
import {gameSnapshot} from './core/GameState.js';
import {animateDoorLeaves,animateCarriageDoors} from './train/TrainDoors.js?v=20261026-smooth-v16';
import {nearestDoor,smoothProgress,facingDirection,shortestTurn} from './passengers/PassengerMotion.js';

let THREE;try{THREE=await import('https://cdn.jsdelivr.net/npm/three@0.161.0/build/three.module.js')}catch(e){THREE=await import('https://esm.sh/three@0.161.0')}
const renderer=new THREE.WebGLRenderer({canvas:document.querySelector('#scene'),antialias:false,powerPreference:'default',preserveDrawingBuffer:false});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);renderer.outputColorSpace=THREE.SRGBColorSpace;
const scene=new THREE.Scene();scene.background=new THREE.Color(0x11161a);scene.fog=new THREE.Fog(0x11161a,45,190);const camera=new THREE.PerspectiveCamera(75,innerWidth/innerHeight,.1,230);const stationCamera=new THREE.PerspectiveCamera(68,innerWidth/innerHeight,.1,230);camera.position.set(0,3.15,4.15);scene.add(new THREE.HemisphereLight(0x708599,0x080b10,.16));const headlights=[];for(const side of [-1,1]){const beam=new THREE.SpotLight(0xf0f6ff,185,88,Math.PI/9,.34,1.4);beam.position.set(side*1.02,1.48,1.0);beam.target.position.set(side*1.55,1.65,-37);scene.add(beam,beam.target);headlights.push(beam)}const ambientStation=new THREE.AmbientLight(0xd7e9ff,.15);scene.add(ambientStation);
const mat=(c,metal=0)=>new THREE.MeshStandardMaterial({color:c,roughness:.75,metalness:metal}),concrete=mat(0x4a4d4d),dark=mat(0x25292b),rail=mat(0xa5a6a4,.8),steel=mat(0x697985,.65),wood=mat(0x69584b),yellow=mat(0xeacb40),tile=mat(0xa7a39a),light=new THREE.MeshBasicMaterial({color:0xe5f5ff}),blue=mat(0x1d5d84);
function box(g,w,h,d,x,y,z,m){const a=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),m);a.position.set(x,y,z);g.add(a);return a}
// Actual world-space 3D driver's cab: head turns around a stationary dashboard.
// Unlike a HUD overlay, its screens, buttons and housing change perspective.
const cab=new THREE.Group();cab.scale.set(.73,.95,.88);cab.position.z=-.20;scene.add(cab);
// Independent cabin illumination: does not spill into the tunnel.
const cabinFill=new THREE.AmbientLight(0xdbeeff,1.15);cab.add(cabinFill);
const cabinLamp=new THREE.PointLight(0xf2f5ed,36,8,1.8);cabinLamp.position.set(0,3.7,5.5);cab.add(cabinLamp);
const cabShell=mat(0x454b50,.35),cabEdge=mat(0x8c8377,.45),cabRubber=mat(0x171d22),cabMetal=mat(0x9ca6ab,.65),cabButton=[mat(0x3d9464),mat(0xa64d42),mat(0xc39b47),mat(0x4479a8),mat(0x787d86)];
const cabGlow=new THREE.MeshBasicMaterial({color:0x8ac9db});
box(cab,6.8,.25,2.3,0,1.37,3.55,cabShell);
box(cab,6.6,.42,.2,0,1.63,2.55,cabEdge);
box(cab,6.5,.22,.25,0,1.25,4.5,cabRubber);
for(const x of [-3.1,3.1]){box(cab,.7,.7,2.15,x,1.56,3.5,cabShell);box(cab,.14,1.9,.17,x,2.55,2.47,cabEdge)}


// Small square driver ID, separate from the left mirror, on its right side.
const idCanvas=document.createElement('canvas');idCanvas.width=512;idCanvas.height=512;
const ic=idCanvas.getContext('2d');
ic.fillStyle='#14202b';ic.fillRect(0,0,512,512);
ic.strokeStyle='#bfb29c';ic.lineWidth=18;ic.strokeRect(14,14,484,484);
ic.strokeStyle='#687780';ic.lineWidth=4;ic.strokeRect(35,35,442,442);
ic.fillStyle='#f5e8ce';ic.textAlign='center';
ic.font='bold 65px Arial';ic.fillText('МАШИНИСТ',256,139);
ic.font='bold 79px Arial';ic.fillText('КУЗНЕЦОВ',256,282);
ic.font='bold 100px Arial';ic.fillText('ЗАХАР',256,415);
const idTexture=new THREE.CanvasTexture(idCanvas);
const idPlaque=new THREE.Group();
// To the right (towards cab centre) of the LEFT mirror, high on the window frame.
idPlaque.position.set(-2.25,3.53,2.32);idPlaque.rotation.y=.12;cab.add(idPlaque);
box(idPlaque,.53,.53,.045,0,0,0,new THREE.MeshStandardMaterial({color:0x252c32,metalness:.55,roughness:.4}));
const idFace=new THREE.Mesh(new THREE.PlaneGeometry(.51,.51),new THREE.MeshBasicMaterial({map:idTexture,side:THREE.DoubleSide}));
idFace.position.z=.029;idPlaque.add(idFace);

// Symmetric, narrow side-window rear-view mirrors inspired by metro rolling stock.
// A rigid two-point steel bracket and articulated joint support each mirror.
const rearMirrors=[];
for(const side of [-1,1]){
 const mount=new THREE.Group();
 mount.position.set(side*3.38,3.12,3.20);
 mount.rotation.y=-side*.84; // slightly oblique to driver's eyes
 mount.rotation.x=-.055;
 cab.add(mount);
 // Two attachment plates, bolts, a cantilever arm and the hinge.
 const bracket=mat(0x58636b,.72),boltMat=mat(0xaab5ba,.78);
 for(const y of [-.35,.35]){
  box(mount,.16,.17,.09,side*.22,y,-.34,bracket);
  const bolt=new THREE.Mesh(new THREE.SphereGeometry(.037,10,8),boltMat);
  bolt.position.set(side*.22,y,-.277);mount.add(bolt);
 }
 box(mount,.085,.86,.09,side*.22,0,-.31,bracket);
 const arm=box(mount,.075,.075,.50,side*.12,.04,-.20,bracket);
 arm.rotation.y=side*.16;
 const hinge=new THREE.Mesh(new THREE.CylinderGeometry(.085,.085,.19,14),boltMat);
 hinge.rotation.z=Math.PI/2;hinge.position.set(0,.04,-.06);mount.add(hinge);
 // Approximately 2/3 of the previous width; tall but not oversized.
 box(mount,.68,1.29,.105,0,0,.03,cabRubber);
 box(mount,.63,1.24,.038,0,0,.093,cabMetal);
 const target=new THREE.WebGLRenderTarget(384,672,{depthBuffer:true,stencilBuffer:false});
 target.texture.colorSpace=THREE.SRGBColorSpace;
 const face=new THREE.Mesh(new THREE.PlaneGeometry(.59,1.19),new THREE.MeshBasicMaterial({map:target.texture,side:THREE.DoubleSide}));
 face.position.z=.118;mount.add(face);
 const mirrorCamera=new THREE.PerspectiveCamera(53,.59/1.19,.35,210);
 rearMirrors.push({side,target,mirrorCamera,face});
}
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
 if(window.metroMirrorsDisabled||++mirrorFrameNumber%2!==0)return;
 const m=rearMirrors[Math.floor(mirrorFrameNumber/2)%2];
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
  for(const item of rearMirrors)item.face.visible=true;
 }
}
const instrumentDeck=new THREE.Group();instrumentDeck.position.set(0,1.79,3.24);instrumentDeck.rotation.x=.39;cab.add(instrumentDeck);
box(instrumentDeck,6.0,.13,1.32,0,0,0,cabShell);
function cabScreen(x,z,w,h,colour){const g=new THREE.Group();g.position.set(x,.12,z);instrumentDeck.add(g);box(g,w+.13,.12,h+.12,0,0,0,cabEdge);box(g,w,.025,h,0,.076,0,new THREE.MeshBasicMaterial({color:colour}));return g}
const leftCabScreen=cabScreen(-1.78,-.17,1.24,.72,0x0b2936);
const midCabScreen=cabScreen(-.22,-.18,1.46,.92,0x102e48);
const rightCabScreen=cabScreen(1.44,-.22,.96,.68,0x132d2c);
function luminousBar(group,x,z,w,c){box(group,w,.03,.045,x,.11,z,new THREE.MeshBasicMaterial({color:c}))}
for(let i=0;i<6;i++){luminousBar(leftCabScreen,-.4,-.25+i*.095,.75,i%2?0x4fae94:0x69b6cf)}
for(let i=0;i<5;i++){luminousBar(rightCabScreen,-.25,-.19+i*.1,.48,i%2?0x60b68c:0x93ccdc)}
const displayCanvas=document.createElement('canvas');displayCanvas.width=512;displayCanvas.height=256;
const displayCtx=displayCanvas.getContext('2d');const displayTexture=new THREE.CanvasTexture(displayCanvas);
const speedPlate=new THREE.Mesh(new THREE.PlaneGeometry(1.18,.58),new THREE.MeshBasicMaterial({map:displayTexture,side:THREE.DoubleSide}));
speedPlate.position.set(0,.115,0);speedPlate.rotation.x=-Math.PI/2;midCabScreen.add(speedPlate);
// Integrated speed and schematic train-door monitor on the same LCD.
let lastCabSpeed=-1,lastCabDoors=null;
function updateCabDisplay(v){
 const n=Math.round(v),open=typeof doors!=='undefined'&&doors;
 if(n===lastCabSpeed&&open===lastCabDoors)return;
 lastCabSpeed=n;lastCabDoors=open;
 const c=displayCtx;c.fillStyle='#091e30';c.fillRect(0,0,512,256);
 c.fillStyle='#81d9e9';c.textAlign='center';c.font='bold 106px monospace';c.fillText(String(n),135,130);
 c.font='bold 27px Arial';c.fillText('км/ч',135,172);
 // Train diagram: two cars with four visible side doors.
 c.strokeStyle='#8aa6b5';c.lineWidth=5;c.beginPath();c.roundRect(269,44,224,112,16);c.stroke();
 c.fillStyle='#243f53';c.fillRect(282,54,198,89);
 for(let i=0;i<4;i++){
  const x=291+i*47;
  c.fillStyle=open?'#e7a84a':'#31d48c';
  if(open){
   c.fillRect(x,82,13,54);c.fillRect(x+24,82,13,54);
   c.strokeStyle='#f8d09a';c.lineWidth=3;c.strokeRect(x+13,82,11,54);
  }else{
   c.fillRect(x+8,82,24,54);c.strokeStyle='#174f45';c.lineWidth=2;
   c.beginPath();c.moveTo(x+20,83);c.lineTo(x+20,135);c.stroke();
  }
 }
 c.fillStyle=open?'#ffb44e':'#56e3a5';c.font='bold 24px Arial';c.fillText(open?'ДВЕРИ ОТКРЫТЫ':'ДВЕРИ ЗАКРЫТЫ',375,195);
 c.fillStyle=open?'#a75327':'#15553c';c.fillRect(265,214,230,24);
 c.fillStyle='#ffffff';c.font='bold 17px Arial';c.fillText(open?'ВНИМАНИЕ':'НОРМА',380,232);
 displayTexture.needsUpdate=true;
}
// Hundreds of distinct switches, lamps and keypads in banks.
for(let row=0;row<4;row++)for(let col=0;col<12;col++){const x=-2.62+col*.46,z=.38+row*.19;
if(row<3 && ((x>.35&&x<1.65)||(x>-1.55&&x<-.7)))continue;
const color=cabButton[(row*7+col)%cabButton.length];const button=new THREE.Mesh(new THREE.CylinderGeometry(.038,.043,.044,16),color);button.position.set(x,.115,z);instrumentDeck.add(button);
const bezel=new THREE.Mesh(new THREE.CylinderGeometry(.055,.055,.014,16),cabMetal);bezel.position.set(x,.075,z);instrumentDeck.add(bezel)}
for(let i=0;i<8;i++){const x=-2.65+i*.75;const g=new THREE.Mesh(new THREE.CylinderGeometry(.115,.115,.025,24),cabMetal);g.position.set(x,.12,-.64);instrumentDeck.add(g);const core=new THREE.Mesh(new THREE.CylinderGeometry(.087,.087,.03,24),cabRubber);core.position.set(x,.14,-.64);instrumentDeck.add(core);const needle=box(instrumentDeck,.012,.014,.073,x,.165,-.67,light)}
for(let i=0;i<7;i++){const x=-2.25+i*.74;box(instrumentDeck,.36,.02,.08,x,.12,.88,cabRubber);box(instrumentDeck,.055,.12,.12,x,.18,.88,cabMetal)}
// Physical throttle controller and side panels visible in perspective.
box(cab,1.0,.22,.83,-2.35,1.68,4.12,cabEdge);
box(cab,.16,.6,.17,-2.35,2.02,4.12,cabMetal);
box(cab,.4,.19,.24,-2.35,2.37,4.12,cabRubber);
// Cab sidewalls, door frames, glazed side windows and forward windscreen.
// Soft moulded cabin glazing: curved rubber gaskets, rounded aluminium surrounds.
const windowFrame=mat(0x626e76,.52),sideInterior=mat(0x414a51,.18),seal=mat(0x1c252b);
const glassPane=new THREE.MeshPhysicalMaterial({color:0x9ac4d5,transparent:true,opacity:.018,roughness:.055,metalness:0,depthWrite:false,side:THREE.DoubleSide});
const softTrim=mat(0x303b43,.25),brightTrim=mat(0x86949b,.55);
function smoothRail(points,radius,material,segments=30){
 const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(...p)),false,'centripetal');
 const mesh=new THREE.Mesh(new THREE.TubeGeometry(curve,segments,radius,8,false),material);
 cab.add(mesh);return mesh;
}
function roundPost(x,y,z,w,h,d,material,r=.10){
 const shape=new THREE.Shape();const left=-w/2,right=w/2,bottom=-h/2,top=h/2;
 shape.moveTo(left+r,bottom);shape.lineTo(right-r,bottom);shape.quadraticCurveTo(right,bottom,right,bottom+r);
 shape.lineTo(right,top-r);shape.quadraticCurveTo(right,top,right-r,top);
 shape.lineTo(left+r,top);shape.quadraticCurveTo(left,top,left,top-r);
 shape.lineTo(left,bottom+r);shape.quadraticCurveTo(left,bottom,left+r,bottom);
 const geo=new THREE.ExtrudeGeometry(shape,{depth:d,bevelEnabled:true,bevelThickness:.035,bevelSize:.035,bevelSegments:3,steps:1,curveSegments:8});
 const mesh=new THREE.Mesh(geo,material);mesh.position.set(x,y,z-d/2);cab.add(mesh);return mesh;
}
// Continuous, slightly curved front windshield, without square cross-bars.
const windTop=[[-3.93,3.93,1.52],[-3.05,4.01,1.43],[0,4.08,1.38],[3.05,4.01,1.43],[3.93,3.93,1.52]];
const windBottom=[[-3.93,1.79,1.58],[-3.05,1.73,1.50],[0,1.70,1.46],[3.05,1.73,1.50],[3.93,1.79,1.58]];
smoothRail(windTop,.085,softTrim,48);smoothRail(windBottom,.115,softTrim,48);
smoothRail(windTop.map(p=>[p[0],p[1]+.045,p[2]+.015]),.024,brightTrim,48);
for(const side of [-1,1]){
 smoothRail([[side*3.93,1.79,1.58],[side*3.99,2.15,1.52],[side*4.0,3.5,1.49],[side*3.93,3.93,1.52]],.11,softTrim);
 smoothRail([[side*3.92,1.83,1.6],[side*3.92,1.84,2.35],[side*3.94,1.82,3.95],[side*3.93,1.85,5.18]],.09,softTrim);
 smoothRail([[side*3.93,3.91,1.54],[side*3.94,3.83,2.8],[side*3.95,3.65,4.25],[side*3.93,3.54,5.18]],.09,softTrim);
 // One slender swept divider rather than several heavy upright bars.
 smoothRail([[side*3.94,1.84,3.85],[side*3.96,2.56,3.73],[side*3.95,3.63,3.53]],.065,windowFrame);
 box(cab,.035,1.70,3.35,side*3.96,2.72,3.35,glassPane);
 // Upholstered lower side wall with rounded moulded window sill.
 box(cab,.23,.95,4.2,side*4.00,1.17,3.36,sideInterior);
 smoothRail([[side*3.87,1.72,1.55],[side*3.88,1.72,3.25],[side*3.87,1.72,5.35]],.105,softTrim);
 // Compact, rounded side console.
 roundPost(side*3.66,1.80,4.26,.34,.58,.72,cabShell,.14);
}
// Clear windshield glazing: no thick bars blocking the driver's view.
box(cab,7.75,2.13,.024,0,2.83,1.49,glassPane);
// Curved upper headliner following the front glazing.
smoothRail([[-3.95,4.08,1.63],[-2.7,4.18,1.58],[0,4.22,1.53],[2.7,4.18,1.58],[3.95,4.08,1.63]],.12,sideInterior,48);
// More upright illuminated control cluster facing the driver.
const rearPanel=new THREE.Group();rearPanel.position.set(0,2.05,2.47);rearPanel.rotation.x=-.20;cab.add(rearPanel);
box(rearPanel,5.65,.78,.18,0,0,0,cabShell);
for(let i=0;i<4;i++){const x=-2.05+i*1.35;box(rearPanel,1.13,.55,.04,x,.04,.115,cabEdge);box(rearPanel,.98,.42,.055,x,.04,.15,new THREE.MeshBasicMaterial({color:[0x153b4a,0x23445b,0x173d35,0x263f49][i]}))}
for(let i=0;i<16;i++){const x=-2.48+(i%8)*.71,y=-.26+Math.floor(i/8)*.45;const lamp=new THREE.Mesh(new THREE.SphereGeometry(.055,8,6),new THREE.MeshBasicMaterial({color:i%3===0?0x62cf89:i%3===1?0xf2ae54:0xd75047}));lamp.position.set(x,y,.17);rearPanel.add(lamp)}
// Solid floor, sealed rear bulkhead and extended car body: no exposed rails
// or abrupt open end when looking down or turning sideways.
const floorRubber=mat(0x343a3c),floorRib=mat(0x535b5c),rearTrim=mat(0x666e71);
box(cab,8.25,.23,9.8,0,.53,4.5,floorRubber);
for(let i=0;i<23;i++)box(cab,7.8,.018,.055,0,.67,.05+i*.40,floorRib);
box(cab,8.2,2.95,.23,0,2.15,9.38,sideInterior);
box(cab,8.1,.19,9.7,0,4.35,4.48,sideInterior);
for(const side of [-1,1]){
 box(cab,.23,3.5,4.1,side*4.03,2.32,7.2,sideInterior);
 box(cab,.18,.18,2.3,side*3.96,3.58,5.9,windowFrame);
 box(cab,.24,1.15,1.15,side*3.87,2.13,7.7,rearTrim);
 box(cab,.05,.8,.18,side*3.65,2.14,7.7,cabMetal);
}
box(cab,2.1,2.8,.19,0,2.16,9.21,rearTrim);
box(cab,.65,.15,.22,0,2.25,9.07,cabMetal);
const cabLight=new THREE.PointLight(0xb4d8ef,3.2,10);cabLight.position.set(0,3.4,4.0);scene.add(cabLight);

// Three compact controls recessed directly into the sloped instrument desk.
const cabHitTargets=[],cabRaycaster=new THREE.Raycaster(),cabTapPoint=new THREE.Vector2();
function buttonLabel(text,color){
 const c=document.createElement('canvas');c.width=256;c.height=256;const ctx=c.getContext('2d');
 ctx.fillStyle=color;ctx.beginPath();ctx.arc(128,128,123,0,Math.PI*2);ctx.fill();
 ctx.fillStyle='#ffffff';ctx.textAlign='center';ctx.textBaseline='middle';ctx.font='bold 57px Arial';ctx.fillText(text,128,130);
 return new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(c),transparent:true,side:THREE.DoubleSide,depthWrite:false});
}
function deskButton(x,z,text,color,type){
 const g=new THREE.Group();g.position.set(x,.13,z);g.scale.setScalar(.82);instrumentDeck.add(g);
 const rim=new THREE.Mesh(new THREE.CylinderGeometry(.235,.235,.055,32),cabMetal);rim.position.y=.025;g.add(rim);
 const cap=new THREE.Mesh(new THREE.CylinderGeometry(.198,.198,.10,32),new THREE.MeshStandardMaterial({color,metalness:.12,roughness:.35}));cap.position.y=.20;g.add(cap);
 const face=new THREE.Mesh(new THREE.CircleGeometry(.183,32),buttonLabel(text,color));face.rotation.x=-Math.PI/2;face.position.y=.253;g.add(face);
 cabHitTargets.push({mesh:cap,type},{mesh:face,type});return {cap,face,press:0,target:0};
}
// Control strip near the speedometer, with a cleared area for finger taps.
const infoControl=deskButton(-1.12,.39,'Info','#1474a7','info');
const openControl=deskButton(.68,.39,'ОТКР','#237a54','open');
const closeControl=deskButton(1.23,.39,'ЗАКР','#9c4942','close');
// Deep, spring-like travel with smooth movement every animation frame.
const cabButtons=[infoControl,openControl,closeControl];
function syncDoorButtons(){openControl.target=doors?1:0;closeControl.target=doors?0:1}
function animateCabButtons(dt){
 for(const b of cabButtons){
 b.press+=(b.target-b.press)*Math.min(1,dt*15);
 // Raised 0.23 above the mounting plate; depressed nearly flush.
 b.cap.position.y=.20-b.press*.13;
 b.face.position.y=.253-b.press*.13;
 b.cap.material.emissive.setHex(b.press>.8?0x112c28:0x000000);
 }
}
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
document.getElementById('infoSpeaker')?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();pressInfo()});
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
 if(doors===open)return;
 if(open){
  if(stationSkipped||dist < -stopTolerance){markStationSkipped();if(stopWarning.style.display!=='none')showStopWarning('ГРУБАЯ ОШИБКА! ОБСЛУЖИВАНИЕ СТАНЦИИ ЗАПРЕЩЕНО. ПРОДОЛЖАЙТЕ ДВИЖЕНИЕ',true);return;}
  if(speed>=.5){showStopWarning('ОШИБКА МАШИНИСТА: поезд ещё движется — двери заблокированы');return;}
  if(dist>stopTolerance){if(!shortStopErrorRecorded){shortStopErrorRecorded=true;shortStopErrorPosition=dist;reportDriverError('попытка открыть двери до знака остановки');}showStopWarning('ОШИБКА МАШИНИСТА! НЕ ДОЕХАЛИ '+dist.toFixed(1)+' М. ПОДЪЕДЬТЕ БЛИЖЕ (ДОПУСК ±3 М)');return;}
 }
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
 updateCabDisplay(speed);
 // Do not interrupt the active departure announcement with door TTS.
}
// Touch-first picking: use projected button centres, not tiny mesh ray hits.
// Capture pointerdown before the camera drag handler consumes the gesture.
// Slim raised instrument rail makes all three switches visible above the dashboard.
// Buttons are mounted directly into the existing instrument deck: no extra rail.
// Project the real 3D button faces to the touch screen on every tap.
// Listen at document level so decorative HUD layers cannot swallow the tap.
const buttonPickTargets=[{button:infoControl,type:'info'},{button:openControl,type:'open'},{button:closeControl,type:'close'}];
const pickVector=new THREE.Vector3();
function cabButtonAt(clientX,clientY){
 scene.updateMatrixWorld(true);camera.updateMatrixWorld(true);
 const rect=renderer.domElement.getBoundingClientRect();
 let best=Infinity,nearest=null;
 for(const item of buttonPickTargets){
  item.button.face.getWorldPosition(pickVector);
  pickVector.project(camera);
  if(pickVector.z<=-1||pickVector.z>=1)continue;
  const px=rect.left+(pickVector.x+1)*rect.width*.5;
  const py=rect.top+(1-pickVector.y)*rect.height*.5;
  const d=Math.hypot(clientX-px,clientY-py);
  if(d<best){best=d;nearest=item}
 }
 // The buttons are small 3D circles; use a comfortable independent touch area.
 // A larger target is important on Android and when the cab is viewed obliquely.
 return best<=Math.max(52,Math.min(rect.width,rect.height)*.14)?nearest:null;
}
document.addEventListener('pointerdown',e=>{
 // 3D desk buttons must ONLY intercept touches while the driver cab is
 // actually on screen. The previous global capture handler also stole
 // taps from the new camera switches and the carriage view.
 if(!playing||stationCameraActive||carCameraActive)return;
 if(e.target.closest?.('button,#masterTrack,#masterUnit,#start,#stationCameraToggle,#carCameraToggle'))return;
 const item=cabButtonAt(e.clientX,e.clientY);if(!item)return;
 e.preventDefault();e.stopImmediatePropagation();
 if(item.type==='info')pressInfo();
 else if(item.type==='open')setCabDoors(true);
 else if(item.type==='close')setCabDoors(false);
},true);
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
function smoothstep01(t){t=Math.max(0,Math.min(1,t));return t*t*(3-2*t)}
function trackDrop(distance){return descentDepth*smoothstep01((distance-descentStart)/(descentEnd-descentStart))}
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
box(platform,6.4,.3,48,0,-.30,29,approachRailBed);
for(const x of [-1.15,1.15])box(platform,.12,.16,48,x,.05,29,rail);
for(let j=0;j<24;j++)box(platform,3.3,.10,.24,0,-.06,6+j*2,wood);
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
// Human figures: anatomically proportioned meshes, varied clothing and poses.
const coats=[mat(0x394c63),mat(0x855648),mat(0x507064),mat(0x77716b),mat(0x46475b),mat(0x977e61)],skins=[mat(0xe1b69b),mat(0xc99576),mat(0xf0c5a8)],hairs=[mat(0x30231e),mat(0x6a4b32),mat(0x191b21),mat(0x9b7956)];

// Six reusable wardrobe textures: subtle cloth weave, seams and pockets.
const passengerFabricTextures=Array.from({length:6},(_,type)=>{
 const c=document.createElement('canvas');c.width=256;c.height=256;
 const ctx=c.getContext('2d');
 const bases=['#42627c','#80634f','#506b55','#856879','#7b808a','#aa7952'];
 ctx.fillStyle=bases[type];ctx.fillRect(0,0,256,256);
 for(let y=0;y<256;y+=3){ctx.strokeStyle='rgba(255,255,255,.045)';ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(256,y);ctx.stroke();}
 for(let x=0;x<256;x+=4){ctx.strokeStyle='rgba(0,0,0,.045)';ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,256);ctx.stroke();}
 ctx.strokeStyle='rgba(20,25,30,.42)';ctx.lineWidth=3;
 ctx.beginPath();ctx.moveTo(128,0);ctx.lineTo(128,255);ctx.stroke();
 for(const px of [38,174]){ctx.strokeRect(px,147,43,37);ctx.beginPath();ctx.moveTo(px,155);ctx.lineTo(px+43,155);ctx.stroke();}
 if(type%2===0){ctx.fillStyle='rgba(210,210,200,.8)';for(let y=32;y<240;y+=28)ctx.fillRect(125,y,5,5);}
 const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.SRGBColorSpace;tex.wrapS=tex.wrapT=THREE.RepeatWrapping;tex.anisotropy=2;return tex;
});
const passengerOutfits=passengerFabricTextures.map(map=>new THREE.MeshStandardMaterial({map,roughness:.94}));
const passengerEyeWhite=new THREE.MeshStandardMaterial({color:0xe3dfd4,roughness:.8});
const passengerIris=new THREE.MeshStandardMaterial({color:0x394b53,roughness:.42});
const passengerLip=new THREE.MeshStandardMaterial({color:0x955b59,roughness:.85});
const passengerSeam=new THREE.MeshStandardMaterial({color:0x333b44,roughness:.95});
function personDetail(parent,geo,material,x,y,z){const m=new THREE.Mesh(geo,material);m.position.set(x,y,z);parent.add(m);return m;}
function human(i,x,z){
 const p=new THREE.Group();p.position.set(x,.78,z);platform.add(p);
 const child=i%13===0||i%13===1,elder=i%11===0;
 const scale=child?.64:elder?.89:.91+(i%5)*.036;p.scale.setScalar(scale);
 const archetype=i%6,coat=passengerOutfits[archetype],skin=skins[i%skins.length],hair=hairs[i%hairs.length];
 p.userData.walkLimbs=[];p.userData.gestureArms=[];p.userData.fineDetails=[];
 const torso=new THREE.Mesh(new THREE.CylinderGeometry(.22,.29,.76,16),coat);torso.position.y=1.16;p.add(torso);
 const jacket=new THREE.Mesh(new THREE.SphereGeometry(.245,12,10),coat);jacket.scale.set(1,.85,.69);jacket.position.y=1.39;p.add(jacket);
 for(const side of [-1,1]){
  const leg=new THREE.Mesh(new THREE.CylinderGeometry(.093,.081,.73,12),dark);leg.position.set(side*.13,.40,0);p.add(leg);p.userData.walkLimbs.push({mesh:leg,side,kind:'leg'});
  const shoe=new THREE.Mesh(new THREE.CapsuleGeometry(.088,.14,3,8),dark);shoe.rotation.x=Math.PI/2;shoe.position.set(side*.13,.09,-.08);p.add(shoe);
  const arm=new THREE.Mesh(new THREE.CapsuleGeometry(.077,.46,4,10),coat);arm.position.set(side*.31,1.18,0);arm.rotation.z=side*.16;p.add(arm);
  p.userData.walkLimbs.push({mesh:arm,side,kind:'arm'});p.userData.gestureArms.push(arm);
  const hand=new THREE.Mesh(new THREE.SphereGeometry(.075,10,8),skin);hand.position.set(side*.34,.86,0);p.add(hand);
 }
 const neck=new THREE.Mesh(new THREE.CylinderGeometry(.075,.075,.15,10),skin);neck.position.y=1.67;p.add(neck);
 const face=new THREE.Mesh(new THREE.SphereGeometry(.195,18,14),skin);face.scale.set(1,1.15,.91);face.position.y=1.88;p.add(face);
 const hairTop=new THREE.Mesh(new THREE.SphereGeometry(.198,18,12,0,Math.PI*2,0,Math.PI*.50),hair);hairTop.position.y=1.93;p.add(hairTop);
 // Facial features use shallow 3D geometry, not floating black dots.
 const nose=personDetail(p,new THREE.ConeGeometry(.036,.105,10),skin,0,1.858,-.190);nose.rotation.x=-.35;
 const mouth=personDetail(p,new THREE.CapsuleGeometry(.008,.067,2,8),passengerLip,0,1.778,-.178);mouth.rotation.z=Math.PI/2;
 p.userData.fineDetails.push(nose,mouth);
 for(const side of [-1,1]){
  const ear=personDetail(p,new THREE.SphereGeometry(.052,10,8),skin,side*.191,1.87,0);ear.scale.set(.5,1,.6);
  const eye=personDetail(p,new THREE.SphereGeometry(.027,10,8),passengerEyeWhite,side*.079,1.907,-.169);eye.scale.set(1,.55,.30);
  const iris=personDetail(p,new THREE.SphereGeometry(.011,8,8),passengerIris,side*.079,1.906,-.179);
  const brow=personDetail(p,new THREE.BoxGeometry(.083,.012,.015),hair,side*.081,1.948,-.172);brow.rotation.z=-side*.13;
  p.userData.fineDetails.push(ear,eye,iris,brow);
 }
 // Clothing seams, zipper, collars and stitched patch pockets.
 const zipper=personDetail(p,new THREE.BoxGeometry(.012,.55,.012),passengerSeam,0,1.20,-.198);
 const collarL=personDetail(p,new THREE.BoxGeometry(.10,.14,.023),passengerSeam,-.09,1.53,-.165);
 const collarR=personDetail(p,new THREE.BoxGeometry(.10,.14,.023),passengerSeam,.09,1.53,-.165);
 collarL.rotation.z=-.35;collarR.rotation.z=.35;
 p.userData.fineDetails.push(zipper,collarL,collarR);
 for(const side of [-1,1]){
  const pocket=personDetail(p,new THREE.BoxGeometry(.12,.09,.014),passengerSeam,side*.14,1.02,-.233);
  p.userData.fineDetails.push(pocket);
 }
 if(archetype===2||archetype===4){
  const scarf=personDetail(p,new THREE.TorusGeometry(.12,.038,7,18),coats[(i+2)%coats.length],0,1.61,0);
  scarf.rotation.x=Math.PI/2;p.userData.fineDetails.push(scarf);
 }
 if(archetype===3){
  const glasses=personDetail(p,new THREE.TorusGeometry(.092,.009,6,18),passengerSeam,0,1.906,-.182);
  glasses.scale.x=1.85;p.userData.fineDetails.push(glasses);
 }
 if(i%4===0){const bag=new THREE.Mesh(new THREE.BoxGeometry(.29,.40,.16),dark);bag.position.set(.37,.90,.05);p.add(bag);}
 if(i%4===1){const backpack=new THREE.Mesh(new THREE.BoxGeometry(.36,.54,.20),coats[(i+3)%coats.length]);backpack.position.set(0,1.19,.30);p.add(backpack);}
 if(elder){const cane=new THREE.Mesh(new THREE.CylinderGeometry(.017,.017,.98,8),dark);cane.position.set(.43,.48,-.17);p.add(cane);}
 p.userData.child=child;p.userData.elder=elder;p.rotation.y=(i%5-2)*.35;
 return p;
}
// One shared set of 3D passengers for the cab and external camera.
// Nobody is duplicated between views. All waiting positions are on OUR
// boarding side, between the platform edge and its first row of columns.
// Independent carriage scene: remains visible even while the world/tunnel moves.

const carriageScene=new THREE.Scene();carriageScene.background=new THREE.Color(0x303b42);
carriageScene.add(new THREE.HemisphereLight(0xffffff,0x728394,2.4));
const carriageCamera=new THREE.PerspectiveCamera(72,innerWidth/innerHeight,.08,90);
carriageCamera.position.set(-1.42,3.12,1.72);
let carriageYaw=0,carriagePitch=0;
function aimCarriageCamera(){carriageCamera.position.set(1.45,3.16,1.75);carriageCamera.lookAt(new THREE.Vector3(-.25,1.65,-10.5))}
aimCarriageCamera();
const carriage=new THREE.Group();carriageScene.add(carriage);
const carCream=new THREE.MeshStandardMaterial({color:0xe1e4e3,roughness:.65});
const carWhite=new THREE.MeshStandardMaterial({color:0xf8f8f5,roughness:.5});
const carFloor=new THREE.MeshStandardMaterial({color:0x71767c,roughness:.95});
const carSeat=new THREE.MeshStandardMaterial({color:0x302c31,roughness:.83});
const carSteel=new THREE.MeshStandardMaterial({color:0xb4bdc2,metalness:.78,roughness:.22});
const carBlack=new THREE.MeshStandardMaterial({color:0x222c34,roughness:.86});
const carDoor=new THREE.MeshStandardMaterial({color:0xe0e2e2,roughness:.5});
const carGlass=new THREE.MeshPhysicalMaterial({color:0x7c9caa,transparent:true,opacity:.13,roughness:.14,depthWrite:false,side:THREE.DoubleSide});
const carLight=new THREE.MeshBasicMaterial({color:0xfffdf1});
function carriageRail(points,r=.025){const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(...p)));carriage.add(new THREE.Mesh(new THREE.TubeGeometry(curve,24,r,8,false),carSteel))}
box(carriage,4.14,.12,23,0,.88,-9,carFloor);
box(carriage,4.15,.12,23,0,3.65,-9,carCream);
// Continuous illuminated ceiling panels, as in the reference metro car.
for(let z=1.2;z>-20;z-=2.0){box(carriage,.86,.026,1.75,0,3.565,z,carLight);box(carriage,.94,.028,1.8,0,3.584,z,carSteel)}
for(const side of [-1,1]){
 box(carriage,.12,.88,23,side*2.07,1.40,-9,carWhite);
 box(carriage,.12,.55,23,side*2.07,3.39,-9,carWhite);
 box(carriage,.12,.09,23,side*2.07,1.94,-9,carCream);
 box(carriage,.12,.09,23,side*2.07,3.08,-9,carCream);
 for(let j=0;j<8;j++){
  const z=1.1-j*2.75;
  box(carriage,.026,.06,2.22,side*2.01,3.04,z,carBlack);
  box(carriage,.026,.06,2.22,side*2.01,1.99,z,carBlack);
  for(const edge of [-1,1])box(carriage,.027,1.08,.065,side*2.01,2.52,z+edge*1.08,carBlack);
  box(carriage,.012,1.0,2.08,side*2.00,2.52,z,carGlass);
  box(carriage,.76,.16,2.32,side*1.58,1.34,z,carWhite);
  for(let k=0;k<4;k++){
   const zz=z+(k-1.5)*.54;
   box(carriage,.63,.13,.49,side*1.57,1.46,zz,carSeat);
   box(carriage,.60,.014,.46,side*1.57,1.535,zz,new THREE.MeshStandardMaterial({color:0x343036,roughness:.88}));
   box(carriage,.13,.62,.49,side*1.94,1.79,zz,carSeat);
  }
  carriageRail([[side*1.18,1.03,z+1.18],[side*1.18,2.90,z+1.18],[side*1.27,3.22,z+.94],[side*1.52,3.40,z+.75]]);
  for(const edge of [-1,1])carriageRail([[side*1.16,1.34,z+edge*1.13],[side*1.16,1.75,z+edge*1.13],[side*1.65,1.82,z+edge*1.13]],.020);
 }
 carriageRail([[side*1.45,3.36,2.1],[side*1.45,3.36,-20.3]],.032);
 // Reference-style horizontal grab bar above the windows.
 carriageRail([[side*1.95,3.08,2.1],[side*1.95,3.08,-20.3]],.027);
 box(carriage,.24,.34,23,side*1.92,3.35,-9,carCream);
 box(carriage,.21,.05,21.9,side*1.52,3.54,-9,carSteel);
 box(carriage,.14,.025,21.6,side*1.52,3.51,-9,carLight);
}
for(let z=2;z>-20;z-=.33)box(carriage,2.35,.007,.014,0,3.58,z,carSteel);
for(let z=1.4;z>-20;z-=2.75)box(carriage,4.02,.045,.06,0,3.54,z,carCream);
box(carriage,4.04,2.70,.13,0,2.26,-20.43,carWhite);
box(carriage,1.17,2.25,.14,0,2.22,-20.32,carSteel);
box(carriage,1.03,2.13,.15,0,2.20,-20.23,carCream);
box(carriage,.49,.95,.018,0,2.48,-20.14,carGlass);
box(carriage,1.93,.31,.17,0,3.10,-9,carWhite);
box(carriage,1.75,.18,.019,0,3.11,-8.90,new THREE.MeshBasicMaterial({color:0x24412a}));
// Warm lighting and repeated overhead information strips.
for(let z=.4;z>-20;z-=4.6){
 const panel=new THREE.MeshBasicMaterial({color:0x263348});
 box(carriage,.022,.24,1.85,-2.005,3.32,z,panel);
 box(carriage,.022,.24,1.85,2.005,3.32,z,panel);
}
// Station display and advertising cards are real geometry, not HUD overlays.
const stationDisplayCanvas=document.createElement('canvas');stationDisplayCanvas.width=1024;stationDisplayCanvas.height=256;
const stationDisplayCtx=stationDisplayCanvas.getContext('2d');
const stationDisplayTexture=new THREE.CanvasTexture(stationDisplayCanvas);
const stationDisplayMat=new THREE.MeshBasicMaterial({map:stationDisplayTexture,side:THREE.DoubleSide});
function updateCarriageStationDisplay(){
 const ctx=stationDisplayCtx;ctx.fillStyle='#122433';ctx.fillRect(0,0,1024,256);
 ctx.fillStyle='#39b6e5';ctx.fillRect(0,0,1024,12);
 ctx.font='bold 54px Arial';ctx.fillStyle='#fff';ctx.fillText('СТАНЦИЯ / СТАНЦЫЯ',45,83);
 ctx.font='bold 76px Arial';ctx.fillStyle='#fff';ctx.fillText(names[index%names.length]||'Малиновка',45,187);
 stationDisplayTexture.needsUpdate=true;
}
const stationScreen=new THREE.Mesh(new THREE.PlaneGeometry(1.86,.47),stationDisplayMat);
stationScreen.position.set(0,3.24,-9);stationScreen.rotation.x=-.36;carriage.add(stationScreen);
const advertColors=['#e4f1f3','#f4e8dc','#e7edff','#ecf4e4'];
for(const side of [-1,1])for(let j=0;j<7;j++){
 const cv=document.createElement('canvas');cv.width=512;cv.height=256;const ctx=cv.getContext('2d');
 ctx.fillStyle=advertColors[(j+(side+1)/2)%advertColors.length];ctx.fillRect(0,0,512,256);
 ctx.fillStyle='#183e57';ctx.font='bold 44px Arial';ctx.fillText(['МИНСК','ГОРОД РЯДОМ','МЕТРО','ДОБРОГО ПУТИ'][j%4],25,100);
 ctx.font='29px Arial';ctx.fillText('Информация для пассажиров',25,162);
 const tex=new THREE.CanvasTexture(cv);const mat=new THREE.MeshBasicMaterial({map:tex,side:THREE.DoubleSide});
 const ad=new THREE.Mesh(new THREE.PlaneGeometry(1.25,.62),mat);
 ad.position.set(side*1.995,3.20,1-j*3.05);ad.rotation.y=side>0?-Math.PI/2:Math.PI/2;carriage.add(ad);
}
const carSlidingDoorLeaves=[];
for(const side of [-1,1])for(const dz of [-3.2,-13]){
 for(const edge of [-1,1])box(carriage,.06,2.20,.075,side*2.01,2.08,dz+edge*1.02,carSteel);
 box(carriage,.06,.075,2.10,side*2.01,3.21,dz,carSteel);
 for(const half of [-1,1]){
  const leaf=new THREE.Group();carriage.add(leaf);
  box(leaf,.07,.66,.97,side*2.01,1.37,0,carDoor);
  box(leaf,.07,.49,.97,side*2.01,2.96,0,carDoor);
  box(leaf,.07,.90,.075,side*2.01,2.28,half*.45,carDoor);
  box(leaf,.018,.84,.83,side*2.00,2.28,0,carGlass);
  const leafZ=dz+half*.51;leaf.position.z=leafZ;carSlidingDoorLeaves.push({leaf,leafZ,half});
 }
}
const carriagePassengers=[];
const platformPassengers=[];
const doorPositions=[];for(let car=0;car<5;car++)for(const dz of [-5.25,5.25])doorPositions.push(-100+12+car*21.5+dz);
// Distribute passengers across all ten train doors. Every doorway starts
// boarding at the same time; only people sharing a doorway form a short queue.
const boardingQueueByDoor=new Map();
for(let i=0;i<30;i++){
 const doorIndex=i%doorPositions.length;
 const doorwayZ=doorPositions[doorIndex];
 const queueRank=boardingQueueByDoor.get(doorIndex)||0;
 boardingQueueByDoor.set(doorIndex,queueRank+1);
 const homeZ=doorwayZ+(queueRank-1)*1.35+(i%2)*.24;
 const homeX=-3.48-queueRank*.54-(i%2)*.12;
 const person=human(i,homeX,homeZ);
 const exiting=i%4===0||i%4===1;
 const mode=i%6===0?'walk':i%6===1||i%6===2?'talk':'wait';
 platformPassengers.push({person,homeX,homeZ,doorwayZ,exiting,mode,
  doorIndex,queueRank,
  // No train-wide sequential queue: the first person at each door moves
  // immediately, and the next follows a moment later.
  offset:queueRank*1.55+(doorIndex%3)*.13,
  phase:i*1.87,walkingSpeed:.16+(i%4)*.07,
  conversation:i%6===1||i%6===2,
  heading:((i*2.39996)%(Math.PI*2))-Math.PI});
}
// Clone each existing detailed person into the car; the clone keeps the
// exact same face, outfit and accessories. Visibility transfers on boarding.
for(let i=0;i<platformPassengers.length;i++){
 const p=platformPassengers[i],copy=p.person.clone(true);
 copy.userData.walkLimbs=[];copy.userData.fineDetails=[];
 // Clone preserves visual geometry and materials, not animation references.
 const slot=i,row=Math.floor(slot/2),side=slot%2?-1:1;
 const z=1.3-row*2.18;
 copy.scale.multiplyScalar(1.22);
 copy.position.set(side*(slot%4<2?1.49:.70),.78,z);
 copy.rotation.y=side>0?-Math.PI/2:Math.PI/2;
 copy.visible=false;carriage.add(copy);
 carriagePassengers.push({person:copy,platform:p,slot,z,side,settled:false,walkingIn:false});
}
let carCameraActive=false;
const carCameraButton=document.getElementById('carCameraToggle');
carCameraButton.addEventListener('click',()=>{
 carCameraActive=!carCameraActive;
 if(carCameraActive){carriageYaw=0;carriagePitch=0;aimCarriageCamera();}
 if(carCameraActive){stationCameraActive=false;stationCameraButton.classList.remove('active');stationCameraButton.textContent='📷 ВИД НА ПЛАТФОРМУ';}
 carCameraButton.classList.toggle('active',carCameraActive);
 carCameraButton.textContent=carCameraActive?'🎮 В КАБИНУ':'🚇 ВИД В ВАГОНЕ';
});
let passengerDoorTime=0,passengerExchangeStarted=false,platformLifeTime=0;
const passengerBoardingRecorded=new Set();
function updatePlatformPassengers(dt){
 platformLifeTime+=dt;
 const atPlatform=!stationSkipped&&Math.abs(dist)<=stopTolerance&&speed<.5;
 if(atPlatform&&doors&&!stationDoorCycleCompleted){
  if(!passengerExchangeStarted){passengerExchangeStarted=true;passengerDoorTime=0;}
  passengerDoorTime+=dt;
 } // Boarding time never resets when doors close or reopen at this station.
 const ease=v=>{v=Math.max(0,Math.min(1,v));return v*v*(3-2*v);};
 for(let i=0;i<platformPassengers.length;i++){
  const p=platformPassengers[i],cp=carriagePassengers[i];
  const active=atPlatform&&doors&&!stationDoorCycleCompleted;
  const exiting=index!==0&&p.exiting;
  const elapsed=passengerDoorTime-(exiting?0:index===0?0:2.5)-p.offset;
  const duration=5.2+(p.queueRank*.45)+(i%3)*.22;
  const t=active?Math.max(0,Math.min(1,elapsed/duration)):0;
  // Approach along the platform, align with the nearest door, then walk
  // across the gap. No teleport at the threshold.
  const align=ease(t/.53),approach=ease((t-.12)/.57),cross=ease((t-.69)/.31);
  const doorX=-2.56,insideX=-1.72;
  const homeX=p.homeX,homeZ=p.homeZ;
  const crossed=active&&!exiting&&t>=.79;
  if(crossed&&!passengerBoardingRecorded.has(i)){
   passengerBoardingRecorded.add(i);
   cp.settled=true;
   people+=1;
  }
  const walking=active&&t>0&&t<1;
  if(!exiting){
   p.person.position.x=homeX+(doorX-homeX)*approach+(insideX-doorX)*cross;
   p.person.position.z=homeZ+(p.doorwayZ-homeZ)*align;
  }else{
   p.person.position.x=insideX+(doorX-insideX)*ease(t/.32)+(homeX-doorX)*ease((t-.32)/.68);
   p.person.position.z=p.doorwayZ+(homeZ-p.doorwayZ)*ease((t-.32)/.68);
  }
  // The platform avatar remains in the doorway until fully inside, while
  // the carriage camera renders its matching interior avatar.
  p.person.visible=!passengerBoardingRecorded.has(i)&&!(active&&exiting&&t>=1);
  cp.person.visible=cp.settled;
  if(cp.settled){
   // First step through the carriage door, then turn into the aisle and
   // walk down to the assigned seat. Each passenger has a different pace.
   const progress=Math.max(0,(elapsed-duration*.79)/(7.0+(i%5)*.8));
   // Malinovka's platform is on the negative-X side of the train.
   const sideEntry=-1.94;
   const entryZ=cp.z< -9?-13:-3.2;
   const aisleX=cp.side*.36;
   const seatX=cp.side*(cp.slot%3===0?1.49:.70);
   const doorPhase=ease(progress/.25);
   const aislePhase=ease((progress-.25)/.5);
   const seatPhase=ease((progress-.75)/.25);
   cp.person.position.x=sideEntry+(aisleX-sideEntry)*doorPhase+(seatX-aisleX)*seatPhase;
   cp.person.position.z=entryZ+(cp.z-entryZ)*aislePhase;
   const moving=progress>0&&progress<1;
   // Model faces local -Z; a passenger moving from left entrance to aisle
   // should face right (+X), not toward the camera or backward.
   const heading=progress<.25?-Math.PI/2:
      progress<.75?(cp.z>entryZ?Math.PI:0):
      (cp.side>0?-Math.PI/2:Math.PI/2);
   cp.person.rotation.y+=shortestTurn(cp.person.rotation.y,heading)*Math.min(1,dt*5);
   const walkingGait=moving?Math.sin(platformLifeTime*(8.6+(i%3)) +i*1.3):0;
   cp.person.position.y=.78+(moving?Math.abs(walkingGait)*.03:0);
   cp.person.rotation.z=moving?Math.sin(platformLifeTime*4+i)*.015:0;
   if(progress>=1){
    cp.person.position.set(seatX,cp.slot%3===0?.43:.78,cp.z);
    cp.person.rotation.x=cp.slot%3===0?-.12:0;
    cp.person.rotation.y=cp.side>0?-Math.PI/2:Math.PI/2;
   }
  }
  // Derive facing and walking speed from the actual path, so figures turn
  // toward their own doorway instead of sliding sideways like mannequins.
  const dx=exiting?homeX-insideX:insideX-homeX;
  const dz=exiting?homeZ-p.doorwayZ:p.doorwayZ-homeZ;
  const heading=walking?facingDirection(dx,dz):p.heading+Math.sin(platformLifeTime*.45+p.phase)*.1;
  p.person.rotation.y+=shortestTurn(p.person.rotation.y,heading)*Math.min(1,dt*(walking?5:2));
  const phase=platformLifeTime*(8.2+(i%4)*.65)+p.phase;
  const gait=walking?Math.sin(phase):0;
  const stepBlend=walking?Math.min(1,t*13,(1-t)*13):0;
  p.person.position.y=.78+Math.abs(gait)*.038*stepBlend+Math.sin(platformLifeTime*1.2+p.phase)*.004;
  p.person.rotation.z=Math.sin(phase*.5)*.015*stepBlend;
  for(const limb of p.person.userData.walkLimbs){
   const swing=limb.kind==='leg'?.38:.29;
   limb.mesh.rotation.x=(limb.kind==='leg'?1:-1)*limb.side*gait*swing*stepBlend;
  }
 }
}
// Platform signage and benches.
for(let i=0;i<6;i++){box(platform,1.6,.12,.55,-4.85,.85,-8-i*18,wood);box(platform,.1,.8,.1,-5.45,.43,-8-i*18,steel);box(platform,.1,.8,.1,-4.3,.43,-8-i*18,steel)}
const signCanvas=document.createElement('canvas');signCanvas.width=768;signCanvas.height=128;const sc=signCanvas.getContext('2d');const texture=new THREE.CanvasTexture(signCanvas);const sign=new THREE.Mesh(new THREE.PlaneGeometry(4.5,.75),new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide}));sign.rotation.y=Math.PI/2;sign.position.set(-4.7,5.5,-15);platform.add(sign);
const names=['Малиновка','Петровщина','Михалово','Грушевка','Институт культуры','Площадь Ленина','Октябрьская','Площадь Победы','Площадь Якуба Коласа','Академия наук','Парк Челюскинцев','Московская','Восток','Борисовский тракт','Уручье'];let index=0,dist=1100,speed=0,people=0,lever=0,doors=false,playing=false,yaw=0,pitch=0,targetYaw=0,targetPitch=0,last=performance.now();
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
screenDoorToggle?.addEventListener('click',e=>{e.stopPropagation();setCabDoors(!doors);syncScreenDoorToggle();});

// Drag directly on the 3D picture to pan the external camera; touch and mouse.
const stationCanvas=document.querySelector('#scene');let stationDrag=null,carDrag=null;
stationCanvas.addEventListener('pointerdown',e=>{
 if(!carCameraActive)return;
 carDrag={id:e.pointerId,x:e.clientX,y:e.clientY};
 stationCanvas.setPointerCapture(e.pointerId);e.preventDefault();
});
stationCanvas.addEventListener('pointermove',e=>{
 if(!carCameraActive||!carDrag||carDrag.id!==e.pointerId)return;
 carriageYaw=THREE.MathUtils.clamp(carriageYaw+(carDrag.x-e.clientX)*.004,-1.35,1.35);
 carriagePitch=THREE.MathUtils.clamp(carriagePitch+(e.clientY-carDrag.y)*.003,-.72,.55);
 carDrag.x=e.clientX;carDrag.y=e.clientY;aimCarriageCamera();e.preventDefault();
});
for(const evt of ['pointerup','pointercancel'])stationCanvas.addEventListener(evt,e=>{if(carDrag?.id===e.pointerId)carDrag=null;});
stationCanvas.addEventListener('pointerdown',e=>{if(!stationCameraActive)return;stationDrag={id:e.pointerId,x:e.clientX,y:e.clientY};stationCanvas.setPointerCapture(e.pointerId);e.preventDefault();});
stationCanvas.addEventListener('pointermove',e=>{if(!stationCameraActive||!stationDrag||stationDrag.id!==e.pointerId)return;stationViewYaw=THREE.MathUtils.clamp(stationViewYaw+(stationDrag.x-e.clientX)*.0022,-.23,.23);stationViewPitch=THREE.MathUtils.clamp(stationViewPitch+(e.clientY-stationDrag.y)*.0015,-.12,.12);stationDrag.x=e.clientX;stationDrag.y=e.clientY;e.preventDefault();});
for(const evt of ['pointerup','pointercancel'])stationCanvas.addEventListener(evt,e=>{if(stationDrag?.id===e.pointerId)stationDrag=null;});
stationCameraButton.addEventListener('click',()=>{if(Math.abs(dist)>=32||speed>=1.5||!playing)return;carCameraActive=false;carCameraButton.classList.remove('active');carCameraButton.textContent='🚇 ВИД В ВАГОНЕ';stationCameraActive=!stationCameraActive;if(stationCameraActive){stationCameraAnchorZ=platform.position.z-100;stationCameraTrainZ=stationCameraAnchorZ;}stationViewYaw=0;stationViewPitch=0;stationCameraButton.classList.toggle('active',stationCameraActive);stationCameraButton.textContent=stationCameraActive?'🎮 В КАБИНУ':'📷 ВИД НА ПЛАТФОРМУ';});
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
  audio.volume=Math.max(0,Math.min(1,audio.volume+(target-audio.volume)*.12));
 }
 a.acceleration.playbackRate=Math.max(.82,Math.min(1.2,.86+v/260));
 a.cruise.playbackRate=Math.max(.9,Math.min(1.12,.92+v/440));
}
function metroChime(open){/* No synthesized door noise. Add a real door file later. */}
function speak(t){if(!('speechSynthesis'in window))return;speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(t);u.lang='ru-RU';u.rate=.9;speechSynthesis.speak(u)}
function startRide(){playing=true;try{initMetroAudio()}catch(e){console.warn('Metro audio unavailable:',e)}}window.addEventListener('metro-start',startRide);if(window.metroStarted)startRide();
const masterTrack=document.querySelector('#masterTrack'),masterHandle=document.querySelector('#masterHandle'),masterValue=document.querySelector('#masterValue');function setMaster(e){const r=masterTrack.getBoundingClientRect();const relative=(e.clientY-r.top)/r.height;lever=Math.max(-1,Math.min(1,(.5-relative)*2));masterHandle.style.top=(50-lever*43)+'%';masterValue.textContent=(lever>.04?'ТЯГА':lever<-.04?'ТОРМОЗ':'НЕЙТРАЛЬ')+' · '+Math.round(Math.abs(lever)*100)+'%'}masterTrack.addEventListener('pointerdown',e=>{e.preventDefault();masterTrack.setPointerCapture(e.pointerId);setMaster(e)});masterTrack.addEventListener('pointermove',e=>{if(masterTrack.hasPointerCapture(e.pointerId))setMaster(e)});
// HUD door button uses the same validation, animation and passenger logic as cab buttons.
document.querySelector('#doors')?.addEventListener('click',()=>setCabDoors(!doors));
let lookPointer=null,lookX=0,lookY=0;const view=document.querySelector('#scene');view.addEventListener('pointerdown',e=>{lookPointer=e.pointerId;lookX=e.clientX;lookY=e.clientY;view.setPointerCapture(e.pointerId)});view.addEventListener('pointermove',e=>{if(lookPointer!==e.pointerId)return;targetYaw=Math.max(-1.04,Math.min(1.04,targetYaw-(e.clientX-lookX)*.006));targetPitch=Math.max(-.42,Math.min(.54,targetPitch-(e.clientY-lookY)*.005));lookX=e.clientX;lookY=e.clientY});view.addEventListener('pointerup',e=>{if(lookPointer===e.pointerId)lookPointer=null});
const status=document.querySelector('#status');for(let i=0;i<30;i++){const a=document.createElement('div');a.className='lamp';document.querySelector('#rightPanel').appendChild(a)}
function resize(){resizeCameras(renderer,[camera,stationCamera,carriageCamera],innerWidth,innerHeight)}addEventListener('resize',resize);
function frame(now){requestAnimationFrame(frame);try{const elapsed=Math.max(0,Math.min(.25,(now-last)/1000));const dt=Math.min(.05,elapsed);last=now;animateCabButtons(dt);if(playing){// Keep physics on real elapsed time even when phone renders below 20 FPS.
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
 stationServiced=false;stationDoorCycleCompleted=false;stationDoorReopenPenalty=false;passengerExchangeStarted=false;passengerDoorTime=0;overrunReported=false;stationSkipped=false;skipDepartureSeconds=0;shortStopErrorRecorded=false;shortStopErrorPosition=null;stopWarning.style.display='none';
 passengerBoardingRecorded.clear();for(const cp of carriagePassengers){cp.settled=false;cp.person.visible=false;}
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
 updateStationClock();}yaw+=(targetYaw-yaw)*Math.min(1,dt*7);pitch+=(targetPitch-pitch)*Math.min(1,dt*7);camera.rotation.order='YXZ';camera.rotation.y=yaw;camera.rotation.x=pitch-0.06*(smoothstep01((depot.position.z-descentStart)/32)-smoothstep01((depot.position.z-descentEnd)/32));/* Driver turns their head: only the outside 3D world changes. The cab and controls remain screen-fixed. */camera.position.x=Math.sin(now*.014)*Math.min(speed/70,1)*.01+Math.sin(yaw)*.045;camera.position.y=3.15+Math.sin(pitch)*.035;updatePlatformPassengers(elapsed);
animateCarriageDoors(carSlidingDoorLeaves,doors,elapsed);
animateDoorLeaves(stationDoorLeaves,doors,elapsed);try{renderRearMirrors()}catch(mirrorError){console.warn('Mirror rendering disabled:',mirrorError);window.metroMirrorsDisabled=true;}renderer.setRenderTarget(null);cab.visible=true;updateCabDisplay(speed);document.querySelector('#speed').textContent=Math.round(speed);document.querySelector('#station').textContent=names[index%names.length]+' · '+Math.max(0,Math.round(dist))+' м';document.querySelector('#people').textContent='Пассажиры: '+people;if(Math.abs(dist)<=stopTolerance&&speed<.5&&!doors&&!stationServiced&&!stationSkipped&&!overrunReported)status.textContent='Остановка у ограничителя — открой двери';const canUseStationCamera=playing&&Math.abs(dist)<32&&speed<1.5;
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
 renderer.render(carriageScene,carriageCamera);
}else renderer.render(scene,chooseCamera({cab:camera,platform:stationCamera,carriage:carriageCamera},stationCameraActive?'platform':'cab'));
if(stationCameraActive){cab.visible=true;stationTrain.visible=false;}
window.metroLastRendered=performance.now();window.metroDiagnostics=()=>gameSnapshot({speed,doors,dist,index,playing,camera:carCameraActive?'carriage':stationCameraActive?'platform':'cab'});}catch(e){console.error('Metro render failure',e);const st=document.getElementById('status');if(st)st.textContent='Ошибка 3D: '+e.message;window.metro3DReady=false;window.dispatchEvent(new Event('metro-render-error'));}}document.querySelector('#cockpit').style.display='none';document.querySelector('#window').style.display='none';window.metro3DReady=true;window.dispatchEvent(new Event('metro-3d-ready'));
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
requestAnimationFrame(frame);
