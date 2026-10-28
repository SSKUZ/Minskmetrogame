// Directional window / ceiling reflections are confined to cab materials.
// A dark rear wall and floor give metal a readable reflection gradient.
export function applyCabEnvironment(THREE,renderer,materials){
 const faces=Array.from({length:6},(_,i)=>{
  const c=document.createElement('canvas');c.width=c.height=256;const ctx=c.getContext('2d');
  const palette=[['#87978e','#28342e'],['#a59d88','#252b25'],['#b5b19c','#6c7062'],['#141a15','#070b09'],['#41463e','#111913'],['#c8d4c6','#222e27']][i];
  const g=ctx.createLinearGradient(0,0,0,256);g.addColorStop(0,palette[0]);g.addColorStop(.62,palette[1]);g.addColorStop(1,'#101811');ctx.fillStyle=g;ctx.fillRect(0,0,256,256);
  if(i===2){
   for(const x of [50,182]){const glow=ctx.createLinearGradient(x-18,0,x+18,0);glow.addColorStop(0,'rgba(255,247,221,0)');glow.addColorStop(.5,'rgba(255,247,221,.9)');glow.addColorStop(1,'rgba(255,247,221,0)');ctx.fillStyle=glow;ctx.fillRect(x-18,20,36,216);}
  }else if(i!==3){
   ctx.fillStyle=i===5?'#dce4d4':'#a5b4a6';ctx.fillRect(i===4?8:28,20,i===4?14:190,i===5?82:25);
   if(i!==4){ctx.fillStyle='#18241e';ctx.fillRect(120,17,7,100);}
  }return c;
 });
 const cube=new THREE.CubeTexture(faces);cube.colorSpace=THREE.SRGBColorSpace;cube.needsUpdate=true;
 const generator=new THREE.PMREMGenerator(renderer),target=generator.fromCubemap(cube);
 for(const [name,material] of Object.entries(materials))if(material?.isMeshStandardMaterial){material.envMap=target.texture;material.envMapIntensity={steel:.85,edge:.7,glass:.9,black:.42,rubber:.22,floor:.2,seat:.24}[name]??.52;material.needsUpdate=true;}
 cube.dispose();generator.dispose();return target;
}
