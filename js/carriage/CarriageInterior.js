// Passenger carriage geometry. All meshes belong to the supplied carriage group.
// Kept identical to the accepted v35 geometry; appearance changes come later.
export function buildCarriageInterior({THREE,carriage,box,getStationName}){
const carCream=new THREE.MeshStandardMaterial({color:0xe1e4e3,roughness:.65});
const carWhite=new THREE.MeshStandardMaterial({color:0xf8f8f5,roughness:.5});
const carFloor=new THREE.MeshStandardMaterial({color:0x71767c,roughness:.95});
const carSeat=new THREE.MeshStandardMaterial({color:0x302c31,roughness:.83});
const carSteel=new THREE.MeshStandardMaterial({color:0xb4bdc2,metalness:.78,roughness:.22});
const carBlack=new THREE.MeshStandardMaterial({color:0x222c34,roughness:.86});
const carDoor=new THREE.MeshStandardMaterial({color:0xe0e2e2,roughness:.5});
const carGlass=new THREE.MeshPhysicalMaterial({color:0x5088ad,transparent:true,opacity:.16,roughness:.10,depthWrite:false,side:THREE.DoubleSide});
const carLight=new THREE.MeshBasicMaterial({color:0xfffdf1});
function carriageRail(points,r=.025){const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(...p)));carriage.add(new THREE.Mesh(new THREE.TubeGeometry(curve,24,r,8,false),carSteel))}
box(carriage,4.14,.12,23,0,.88,-9,carFloor);
box(carriage,4.15,.12,23,0,3.65,-9,carCream);
// Continuous illuminated ceiling panels, as in the reference metro car.
for(let z=1.2;z>-20;z-=2.0){box(carriage,.86,.026,1.75,0,3.565,z,carLight);box(carriage,.94,.028,1.8,0,3.584,z,carSteel)}
for(const side of [-1,1]){
 // Segment the platform-side wall so doors are genuine openings, not panels sliding over a solid wall.
 const wallRanges=side===-1?[[2.5,-2.15],[-4.25,-11.95],[-14.05,-20.5]]:[[2.5,-20.5]];
 for(const [front,back] of wallRanges){
  const length=front-back,center=(front+back)/2;
  box(carriage,.12,.88,length,side*2.07,1.40,center,carWhite);
  box(carriage,.12,.55,length,side*2.07,3.39,center,carWhite);
  box(carriage,.12,.09,length,side*2.07,1.94,center,carCream);
  box(carriage,.12,.09,length,side*2.07,3.08,center,carCream);
 }
 for(let j=0;j<8;j++){
  const z=1.1-j*2.75;
  // Do not place a solid window, glazing or seating across the door openings.
  if(side===-1&&[-3.2,-13].some(d=>Math.abs(z-d)<2.20))continue;
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
 ctx.font='bold 76px Arial';ctx.fillStyle='#fff';ctx.fillText(getStationName()||'Малиновка',45,187);
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

return {updateCarriageStationDisplay,materials:{carCream,carWhite,carFloor,carSeat,carSteel,carBlack,carDoor,carGlass,carLight}};
}
