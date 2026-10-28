import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {PNG} from 'pngjs';
import {launchCabBrowser,ready,view} from './helpers/cab-browser-fixture.mjs';
const config=JSON.parse(await readFile('tests/cab-reference.json','utf8')),out=process.env.CAB_RESULTS??'test-results/cab';await mkdir(out,{recursive:true});
const source=await readFile(config.image);assert.equal(createHash('sha256').update(source).digest('hex'),config.sha256,'approved reference must remain unchanged');
const f=await launchCabBrowser(),p=await f.page({viewport:config.viewport});
try{
 await ready(p,f.base+'/?preview=station&cabInspector=1&cabCapture=1');await view(p,config.camera.yaw,config.camera.pitch,config.camera.fov);
 await p.screenshot({path:out+'/reference-render.png',animations:'disabled',timeout:120000});
 const actual=await p.evaluate(()=>window.metroCabInspector.getLandmarks()),rows=Object.entries(config.landmarks).map(([name,[x,y]])=>{
  const a=actual[name],dx=a.u*1536-x,dy=a.v*864-y;return {name,reference:{x,y},render:{x:a.u*1536,y:a.v*864},dx,dy,pass:Math.abs(dx)<=config.maxDx*1536&&Math.abs(dy)<=config.maxDy*864};
 });
 const encoded=await p.evaluate(async path=>{const img=new Image();img.src=path;await img.decode();const c=document.createElement('canvas');c.width=img.naturalWidth;c.height=img.naturalHeight;c.getContext('2d').drawImage(img,0,0);return c.toDataURL('image/png').split(',')[1];},config.image);
 const reference=PNG.sync.read(Buffer.from(encoded,'base64')),render=PNG.sync.read(await readFile(out+'/reference-render.png'));
 const pair=new PNG({width:3072,height:864}),overlay=new PNG({width:1536,height:864});
 for(let y=0;y<864;y++)for(let x=0;x<1536;x++){
  const i=(y*1536+x)*4,l=(y*3072+x)*4,r=l+1536*4;
  for(let k=0;k<4;k++){pair.data[l+k]=reference.data[i+k];pair.data[r+k]=render.data[i+k];overlay.data[i+k]=k===3?255:Math.round((reference.data[i+k]+render.data[i+k])*.5);}
 }
 await writeFile(out+'/reference-side-by-side.png',PNG.sync.write(pair));await writeFile(out+'/reference-overlay.png',PNG.sync.write(overlay));
 const speed=actual.speed;let greenPixels=0;
 for(let y=Math.round(speed.v*864)-38;y<Math.round(speed.v*864)+38;y++)for(let x=Math.round(speed.u*1536)-53;x<Math.round(speed.u*1536)+53;x++){
  if(x<0||x>=1536||y<0||y>=864)continue;const i=(y*1536+x)*4,[r,g,b]=render.data.subarray(i,i+3);if(g>90&&g>r*1.15&&g>b*1.4)greenPixels++;
 }
 const result={camera:config.camera,viewport:config.viewport,meaning:'Layout tolerance check; not a photorealism score',rows,greenPixels,errors:f.errors};
 await writeFile(out+'/visual-comparison.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
 assert.ok(greenPixels>60,'speed digits must actually be visible in the rendered PNG');assert.equal(f.errors.length,0);assert.ok(rows.every(r=>r.pass),'layout landmarks outside reference tolerance');
}finally{await f.close();}
