export function animateCabButtons(buttons,dt){
 for(const b of buttons){
  b.press+=(b.target-b.press)*Math.min(1,dt*15);
  b.cap.position.y=.20-b.press*.13;
  b.face.position.y=.253-b.press*.13;
  b.cap.material.emissive.setHex(b.press>.8?0x112c28:0x000000);
 }
}
