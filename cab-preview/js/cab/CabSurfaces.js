// Small, repeatable material maps. The artwork contains surface finish only;
// instruments, labels, seams, fasteners and controls remain separate geometry.
export function createCabSurfaces(THREE){
 const size=512;
 function finish(kind,seed){
  let state=seed;const random=()=>{state=(1664525*state+1013904223)>>>0;return state/4294967296;};
  const canvases=Array.from({length:3},()=>{const c=document.createElement('canvas');c.width=c.height=size;return c;});
  const contexts=canvases.map(c=>c.getContext('2d')),images=contexts.map(c=>c.createImageData(size,size));
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){
   const i=(y*size+x)*4,n=random()-.5,fine=random()-.5;
   let color=[246+n*13,245+n*13,241+n*13],rough=166+n*26,height=128+fine*43;
   if(kind==='plate'){
    const edge=Math.min(x,y,size-1-x,size-1-y),dirt=Math.max(0,1-edge/17),chip=edge<1.3+random()*2.2;
    color=chip?[157+n*24,158+n*24,153+n*24]:[243+n*10-dirt*25,241+n*10-dirt*27,234+n*10-dirt*29];
    rough=chip?116+n*20:174+n*23+dirt*20;height=128+fine*22-dirt*5;
   }else if(kind==='steel'){
    const brush=Math.sin(y*2.4+Math.sin(x*.013)*.4)*3;
    color=[240+n*5+brush,241+n*5+brush,238+n*5+brush];rough=108+n*25+brush;height=128+fine*9+brush;
   }else if(kind==='bakelite'){
    color=[245+n*18,244+n*18,240+n*18];rough=151+n*32;height=128+fine*22;
   }else if(kind==='wood'){
    const vein=Math.sin(x*.19+Math.sin(y*.016)*1.1+Math.sin(x*.029)*2.4),dark=Math.pow(Math.max(0,vein),9)*26;
    color=[112+n*8-dark,58+n*5-dark*.65,28+n*4-dark*.33];rough=135+n*17+dark*.4;height=128+vein*4+fine*5;
   }else if(kind==='fabric'){
    const weave=((x%4===0?1:0)+(y%4===0?1:0))*12;
    color=[208+n*16+weave,213+n*16+weave,220+n*16+weave];rough=236+n*12;height=112+weave*2+fine*19;
   }
   for(let k=0;k<3;k++){images[0].data[i+k]=color[k];images[1].data[i+k]=rough;images[2].data[i+k]=height;}
   for(const image of images)image.data[i+3]=255;
  }
  contexts.forEach((c,i)=>c.putImageData(images[i],0,0));
  if(kind==='paint'||kind==='plate'){
   // Broad changes in the finish stay faint. Small directional scratches alter
   // roughness more than colour, so the paint reads as metal rather than noise.
   for(let i=0;i<60;i++){
    const x=random()*size,y=random()*size,r=5+random()*35,c=contexts[0],g=c.createRadialGradient(x,y,0,x,y,r);
    g.addColorStop(0,'rgba(108,91,60,.055)');g.addColorStop(1,'rgba(108,91,60,0)');c.fillStyle=g;c.fillRect(x-r,y-r,r*2,r*2);
   }
   for(let i=0;i<260;i++){
    const x=random()*size,y=random()*size,length=1+random()*16;
    contexts.forEach((c,j)=>{c.strokeStyle=j===0?'rgba(76,72,62,.09)':j===1?'rgba(232,232,232,.32)':'rgba(54,54,54,.23)';c.lineWidth=.5;c.beginPath();c.moveTo(x,y);c.lineTo(x+length,y+random()*1.4);c.stroke();});
   }
  }
  const maps=canvases.map((c,i)=>{const t=new THREE.CanvasTexture(c);if(i===0)t.colorSpace=THREE.SRGBColorSpace;t.wrapS=t.wrapT=THREE.RepeatWrapping;t.anisotropy=4;return t;});
  return {map:maps[0],roughnessMap:maps[1],bumpMap:maps[2]};
 }
 const shadow=document.createElement('canvas');shadow.width=shadow.height=128;
 const q=shadow.getContext('2d'),gradient=q.createRadialGradient(64,64,12,64,64,64);
 gradient.addColorStop(0,'rgba(0,0,0,.7)');gradient.addColorStop(.5,'rgba(0,0,0,.38)');gradient.addColorStop(1,'rgba(0,0,0,0)');q.fillStyle=gradient;q.fillRect(0,0,128,128);
 const contact=new THREE.CanvasTexture(shadow);contact.colorSpace=THREE.SRGBColorSpace;
 return {paint:finish('paint',717),plate:finish('plate',1771),steel:finish('steel',714),bakelite:finish('bakelite',1978),wood:finish('wood',1984),fabric:finish('fabric',81),contact};
}
