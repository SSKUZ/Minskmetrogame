export function buildCarriageInformation({THREE,carriage,getStationName}){
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


return updateCarriageStationDisplay;
}
