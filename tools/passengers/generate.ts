import {mkdirSync,existsSync,readFileSync,writeFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const source=resolve(process.env.ARA_SOURCE??'../human-source');
const load=(p:string)=>import(pathToFileURL(join(source,p)).href);
const {AssetLibrary}=await load('src/core/assets.ts');
const {buildHuman}=await load('src/core/human.ts');
const {DEFAULT_PARAMS}=await load('src/core/params.ts');
const {runExport,planExport,DEFAULT_EXPORT}=await load('src/export/index.ts');
const cache=join(source,'public/assets');
const lib=await new AssetLibrary({async read(path){const p=join(cache,path);if(!existsSync(p)){mkdirSync(dirname(p),{recursive:true});console.log('fetch',path);execFileSync('curl',['-fsSL','--retry','2','--max-time','60','https://ara3dgen.com/assets/'+path,'-o',p]);}return new Uint8Array(readFileSync(p));}}).init();
const variants=[
 ['man-jacket',{gender:1,age:.52,hair:'short02',outfit:'male_casualsuit01',shoes:'shoes01',weight:.54}],
 ['woman-coat',{gender:0,age:.55,hair:'bob02',outfit:'female_casualsuit01',shoes:'shoes02',weight:.48}],
 ['man-hoodie',{gender:1,age:.45,hair:'short01',outfit:'male_casualsuit04',shoes:'shoes03',weight:.43}],
 ['woman-skirt',{gender:0,age:.49,hair:'ponytail01',outfit:'female_casualsuit02',shoes:'shoes02',weight:.45}],
 ['elder-man',{gender:1,age:.90,hair:'short04',hairTint:'#bcb5aa',outfit:'male_elegantsuit01',shoes:'shoes02',muscle:.30,weight:.57,height:.43}],
 ['elder-woman',{gender:0,age:.88,hair:'bob01',hairTint:'#bcb5aa',outfit:'female_elegantsuit01',shoes:'shoes02',muscle:.3,weight:.63,height:.43}],
 ['boy',{gender:1,age:.17,hair:'short03',outfit:'male_casualsuit02',shoes:'shoes03',weight:.44,height:.45}],
 ['girl',{gender:0,age:.20,hair:'braid01',outfit:'female_sportsuit01',shoes:'shoes03',weight:.42,height:.45}],
 ['man-casual',{gender:1,age:.67,hair:'short04',outfit:'male_casualsuit05',shoes:'shoes04',weight:.69,muscle:.5}],
 ['woman-longhair',{gender:0,age:.42,hair:'long01',outfit:'female_sportsuit01',shoes:'shoes03',weight:.40}],
 ['man-shirt',{gender:1,age:.59,hair:'short02',outfit:'male_casualsuit06',shoes:'shoes01',weight:.47}],
 ['woman-suit',{gender:0,age:.65,hair:'bob02',outfit:'female_elegantsuit01',shoes:'shoes02',weight:.59}],
];
const out=fileURLToPath(new URL('../../assets/passengers/',import.meta.url));mkdirSync(out,{recursive:true});
for(let i=0;i<variants.length;i++){
 const [name,extra]=variants[i];
 for(const detail of ['medium','low']){
  const path=join(out,name+(detail==='low'?'-low':'')+'.glb');if(existsSync(path))continue;
  console.log('BUILD',name,detail);
  const p={...DEFAULT_PARAMS,...extra,name,detail,african:.025,asian:.035,caucasian:.94,seed:i+17,rig:'game_lite',faceBones:false,faceShapes:false,speechShapes:false,teeth:'none',tongue:false,modifiers:{'nose/nose-width':(i%3-1)*.16,'chin/chin-width':(i%4-1.5)*.10}};
  const ch=await buildHuman(lib,p);
  const plan=planExport(ch,{...DEFAULT_EXPORT,format:'glb',clips:['idle','walk','talk','sit_idle','sit_down','stand_up']});
  const file=await runExport(lib,ch,plan);writeFileSync(path,file.data);
  console.log('SAVED',name,detail,ch.mesh.positions.length/3,file.data.length);
 }
}
