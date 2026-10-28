// Deterministic, small procedural surface maps; no baked pictures of instruments.
export function createCabMaterials(THREE){
 const canvas=document.createElement('canvas');canvas.width=512;canvas.height=512;
 const c=canvas.getContext('2d');c.fillStyle='#b9b7b0';c.fillRect(0,0,512,512);
 let seed=717;const random=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/4294967296};
 for(let i=0;i<12000;i++){
  const v=Math.floor(115+random()*95);c.strokeStyle=`rgba(${v},${v},${v},${.025+random()*.075})`;
  const x=random()*512,y=random()*512;c.beginPath();c.moveTo(x,y);c.lineTo(x+random()*26+1,y+.25);c.stroke();
 }
 const grain=new THREE.CanvasTexture(canvas);grain.colorSpace=THREE.SRGBColorSpace;
 grain.wrapS=grain.wrapT=THREE.RepeatWrapping;grain.repeat.set(2,2);grain.anisotropy=4;
 const standard=(color,roughness=.65,metalness=0,extra={})=>new THREE.MeshStandardMaterial({color,roughness,metalness,...extra});
 return {
  panel:standard(0xb9b9b1,.59,.28,{map:grain}),
  casing:standard(0x343836,.72,.25),edge:standard(0x7d817e,.4,.7),
  steel:standard(0x9b9d96,.32,.78),black:standard(0x171916,.72,.08),
  rubber:standard(0x111512,.94),ivory:standard(0xc6bda8,.85),
  blue:standard(0x19445d,.66,.22),floor:standard(0x34332e,.98),
  red:standard(0x9d1511,.32,.08),green:standard(0x176d36,.34,.06),
  white:standard(0xd7d5c8,.4),amber:standard(0xb39120,.4),
  wood:standard(0x57301b,.43,.02),seat:standard(0x25292c,.92),
  glass:new THREE.MeshPhysicalMaterial({color:0xbfc7bc,transparent:true,opacity:.055,roughness:.2,metalness:.05,depthWrite:false}),
  windscreen:new THREE.MeshBasicMaterial({color:0x9bb4b0,transparent:true,opacity:.018,depthWrite:false,side:THREE.DoubleSide}),
  glow:new THREE.MeshBasicMaterial({color:0xb3e821,toneMapped:false}),
  grain
 };
}
