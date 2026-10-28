// A small generated studio environment supplies broad, subdued metal reflections.
// Only cab materials receive it; the station and tunnel keep their own lighting.
export function applyCabEnvironment(THREE,renderer,materials){
 const faces=Array.from({length:6},(_,i)=>{
  const c=document.createElement('canvas');c.width=c.height=128;const ctx=c.getContext('2d');
  const g=ctx.createLinearGradient(0,0,0,128);g.addColorStop(0,i===3?'#151715':'#9b9c91');g.addColorStop(.48,'#424742');g.addColorStop(1,'#242a27');ctx.fillStyle=g;ctx.fillRect(0,0,128,128);
  if(i!==3){ctx.fillStyle='#bfc3b5';ctx.fillRect(20,11,89,7);ctx.fillStyle='#656e67';ctx.fillRect(7,28,6,55);}return c;
 });
 const cube=new THREE.CubeTexture(faces);cube.colorSpace=THREE.SRGBColorSpace;cube.needsUpdate=true;
 const generator=new THREE.PMREMGenerator(renderer),target=generator.fromCubemap(cube);
 for(const material of Object.values(materials))if(material?.isMeshStandardMaterial){material.envMap=target.texture;material.envMapIntensity=.45;material.needsUpdate=true;}
 cube.dispose();generator.dispose();return target;
}
