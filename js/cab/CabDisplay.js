// Driver display renderer; no dependency on global simulation state.
export function createCabDisplayUpdater(displayCtx,displayTexture){
 let lastCabSpeed=-1,lastCabDoors=null;
 return function updateCabDisplay(v,open){
 const n=Math.round(v);
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

}
