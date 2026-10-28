// Reusable existing cab controls. Geometry and hit targets are unchanged.
// This module is deliberately independent from train physics and input logic.
export function createCabDeskButtonFactory({THREE,instrumentDeck,cabMetal,cabHitTargets}){
 function buttonLabel(text,color){
  const c=document.createElement('canvas');c.width=256;c.height=256;const ctx=c.getContext('2d');
  ctx.fillStyle=color;ctx.beginPath();ctx.arc(128,128,123,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#ffffff';ctx.textAlign='center';ctx.textBaseline='middle';ctx.font='bold 57px Arial';ctx.fillText(text,128,130);
  return new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(c),transparent:true,side:THREE.DoubleSide,depthWrite:false});
 }
 return function deskButton(x,z,text,color,type){
  const g=new THREE.Group();g.position.set(x,.13,z);g.scale.setScalar(.82);instrumentDeck.add(g);
  const rim=new THREE.Mesh(new THREE.CylinderGeometry(.235,.235,.055,32),cabMetal);rim.position.y=.025;g.add(rim);
  const cap=new THREE.Mesh(new THREE.CylinderGeometry(.198,.198,.10,32),new THREE.MeshStandardMaterial({color,metalness:.12,roughness:.35}));cap.position.y=.20;g.add(cap);
  const face=new THREE.Mesh(new THREE.CircleGeometry(.183,32),buttonLabel(text,color));face.rotation.x=-Math.PI/2;face.position.y=.253;g.add(face);
  cabHitTargets.push({mesh:cap,type},{mesh:face,type});return {cap,face,press:0,target:0};
 };
}
