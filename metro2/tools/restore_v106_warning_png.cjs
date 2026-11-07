// Restores the original drawing from preview/wagon.html, not new artwork.
// CanvasTexture.flipY=true was used by Three.js; match its GLB PNG orientation.
const fs=require('node:fs');
const {createCanvas,GlobalFonts}=require('@napi-rs/canvas');
GlobalFonts.registerFromPath('/usr/share/fonts/opentype/urw-base35/NimbusSans-Bold.otf','Arial');
const document={createElement:()=>createCanvas(768,512)};
const T={CanvasTexture:class{constructor(image){this.image=image;}},SRGBColorSpace:'srgb'};
function makeDoorCautionTexture(){
 const c=document.createElement('canvas');c.width=768;c.height=512;
 const ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);
 ctx.beginPath();ctx.moveTo(28,22);ctx.lineTo(740,22);ctx.lineTo(740,316);
 ctx.lineTo(384,494);ctx.lineTo(28,316);ctx.closePath();
 ctx.fillStyle='#f5cc05';ctx.fill();ctx.lineWidth=17;ctx.strokeStyle='#161616';ctx.stroke();
 ctx.fillStyle='#111';ctx.textAlign='center';ctx.textBaseline='middle';
 ctx.font='bold 64px Arial,sans-serif';ctx.fillText('БУДЬТЕ ОСТОРОЖНЫ',384,93,674);
 ctx.font='bold 65px Arial,sans-serif';ctx.fillText('CAUTION',384,171);
 // Simplified black boot approaching a platform/door edge, with pinch impact.
 ctx.save();ctx.translate(360,330);ctx.rotate(-.22);
 ctx.beginPath();ctx.moveTo(-88,-89);ctx.lineTo(-24,-89);ctx.lineTo(-17,-8);
 ctx.lineTo(35,18);ctx.lineTo(54,49);ctx.lineTo(44,63);ctx.lineTo(-102,63);
 ctx.lineTo(-117,44);ctx.lineTo(-117,23);ctx.lineTo(-84,23);ctx.closePath();ctx.fill();
 ctx.restore();
 ctx.fillRect(461,240,12,143);ctx.fillRect(480,240,8,143);
 ctx.beginPath();for(let i=0;i<16;i++){const a=i*Math.PI/8,r=i%2?17:35,x=448+Math.cos(a)*r,y=377+Math.sin(a)*r;if(!i)ctx.moveTo(x,y);else ctx.lineTo(x,y)}ctx.closePath();ctx.fill();
 const tex=new T.CanvasTexture(c);tex.colorSpace=T.SRGBColorSpace;tex.anisotropy=8;return tex;
}
const source=makeDoorCautionTexture().image;
const output=createCanvas(source.width,source.height);
const ctx=output.getContext('2d');ctx.translate(0,source.height);ctx.scale(1,-1);ctx.drawImage(source,0,0);
fs.writeFileSync(process.argv[2],output.toBuffer('image/png'));
