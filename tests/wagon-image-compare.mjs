import {PNG} from 'pngjs';
import pixelmatch from 'pixelmatch';
import {readFile,writeFile} from 'node:fs/promises';

export async function comparePixels(currentPath,baselinePath,diffPath){
 const current=PNG.sync.read(await readFile(currentPath)),previous=PNG.sync.read(await readFile(baselinePath));
 if(current.width!==previous.width||current.height!==previous.height)return {status:'incompatible-resolution',current:[current.width,current.height],previous:[previous.width,previous.height]};
 const {width,height}=current,diff=new PNG({width,height}),mask=new PNG({width,height});
 const options={threshold:.12,includeAA:false};
 const changedPixels=pixelmatch(previous.data,current.data,diff.data,width,height,options);
 pixelmatch(previous.data,current.data,mask.data,width,height,{...options,diffMask:true});
 const bounds={left:width,top:height,right:-1,bottom:-1},tiles=new Map();
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  if(mask.data[(y*width+x)*4+3]===0)continue;
  bounds.left=Math.min(bounds.left,x);bounds.top=Math.min(bounds.top,y);bounds.right=Math.max(bounds.right,x);bounds.bottom=Math.max(bounds.bottom,y);
  const tile=`${Math.floor(x/(width/4))},${Math.floor(y/(height/4))}`;tiles.set(tile,(tiles.get(tile)||0)+1);
 }
 await writeFile(diffPath,PNG.sync.write(diff));
 return {status:'compared',changedPixels,totalPixels:width*height,changedPixelFraction:changedPixels/(width*height),bounds:changedPixels?bounds:null,regions:[...tiles].map(([tile,pixels])=>({tile,pixels})).sort((a,b)=>b.pixels-a.pixels),interpretation:'Changed pixels measure changed render area, not model-to-photo similarity. Intentional geometry or lighting changes need review.'};
}
function normalized(b,a){return {cx:(b.x+b.width/2-a.x-a.width/2)/a.width,cy:(b.y+b.height/2-a.y)/a.width,width:b.width/a.width,height:b.height/a.width};}
export async function compareProtectedSide(currentPath,baselinePath){
 const current=PNG.sync.read(await readFile(currentPath)),previous=PNG.sync.read(await readFile(baselinePath));
 if(current.width!==previous.width||current.height!==previous.height)return {status:'incompatible-resolution'};
 const width=Math.floor(current.width*.78),height=current.height,a=new PNG({width,height}),b=new PNG({width,height});
 PNG.bitblt(current,a,0,0,width,height,0,0);PNG.bitblt(previous,b,0,0,width,height,0,0);
 return {status:'compared',region:{x:0,y:0,width,height},changedPixels:pixelmatch(a.data,b.data,null,width,height,{threshold:.12,includeAA:false})};
}
function line(png,x0,y0,x1,y1,color){
 const n=Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0)));
 for(let i=0;i<=n;i++){
  const x=Math.round(x0+(x1-x0)*i/Math.max(n,1)),y=Math.round(y0+(y1-y0)*i/Math.max(n,1));
  for(let d=-1;d<=1;d++){const xx=x+d;if(xx<0||xx>=png.width||y<0||y>=png.height)continue;png.data.set(color,(y*png.width+xx)*4);}
 }
}
function rectangle(p,b,c){line(p,b.x,b.y,b.x+b.width,b.y,c);line(p,b.x+b.width,b.y,b.x+b.width,b.y+b.height,c);line(p,b.x+b.width,b.y+b.height,b.x,b.y+b.height,c);line(p,b.x,b.y+b.height,b.x,b.y,c);}
export async function comparePhoto(features,reference,currentPath,overlayPath){
 const anchor=features.fascia,photoAnchor=reference.features.fascia,png=PNG.sync.read(await readFile(currentPath)),measurements=[];
 for(const [name,expectedBox] of Object.entries(reference.features)){
  const actualBox=features[name];
  if(!actualBox){measurements.push({name,status:'missing-feature'});continue;}
  const actual=normalized(actualBox,anchor),expected=normalized(expectedBox,photoAnchor);
  const residual=Object.fromEntries(Object.keys(actual).map(k=>[k,actual[k]-expected[k]]));
  const maximumDeviation=Math.max(...Object.values(residual).map(Math.abs));
  measurements.push({name,status:maximumDeviation>.035?'review':'within-diagnostic-band',actual,expected,residual,maximumDeviation});
  const target={x:anchor.x+anchor.width/2+(expected.cx-expected.width/2)*anchor.width,y:anchor.y+(expected.cy-expected.height/2)*anchor.width,width:expected.width*anchor.width,height:expected.height*anchor.width};
  rectangle(png,target,[255,185,45,255]);rectangle(png,actualBox,[40,220,235,255]);
 }
 await writeFile(overlayPath,PNG.sync.write(png));
 return {method:reference.method,unit:'fraction of projected fascia width; signed residual = model minus photo',measurements:measurements.sort((a,b)=>(b.maximumDeviation||0)-(a.maximumDeviation||0)),legend:{cyan:'Actual projected geometry bounds',amber:'Photo bounds aligned to actual fascia width and upper edge'},limitations:reference.limitations};
}
