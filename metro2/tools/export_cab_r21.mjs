import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const source=path.resolve(process.env.CAB_SOURCE_DIR),out=path.resolve(process.argv[2]);
const require=createRequire(path.resolve(process.env.CAB_EXPORT_RUNTIME,'v35/export-runtime')+'/package.json');
const THREE=await import(pathToFileURL(require.resolve('three')).href);
const {GLTFExporter}=await import(pathToFileURL(require.resolve('three/addons/exporters/GLTFExporter.js')).href);
const canvas=require(process.env.CAB_CANVAS_MODULE||'@napi-rs/canvas');
for(const folder of ['/usr/share/fonts/truetype/liberation2','/usr/share/fonts/truetype/liberation'])for(const file of ['LiberationSans-Regular.ttf','LiberationSans-Bold.ttf']){const font=folder+'/'+file;if(fs.existsSync(font))canvas.GlobalFonts.registerFromPath(font,'Arial');}
globalThis.document={createElement(type){if(type!=='canvas')throw Error(type);return canvas.createCanvas(1,1);}};
globalThis.ImageData=canvas.ImageData;
globalThis.FileReader=class{readAsArrayBuffer(b){b.arrayBuffer().then(r=>{this.result=r;this.onloadend?.();});}readAsDataURL(b){b.arrayBuffer().then(r=>{this.result='data:'+b.type+';base64,'+Buffer.from(r).toString('base64');this.onloadend?.();});}};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const modules={};for(const file of fs.readdirSync(source+'/js/cab').filter(f=>f.endsWith('.js')&&!f.includes('.export.')))modules[file]=hash(fs.readFileSync(source+'/js/cab/'+file));
let lighting=fs.readFileSync(source+'/js/cab/CabLighting.js','utf8');
lighting=lighting.replace('const generator=new THREE.PMREMGenerator(renderer),target=generator.fromCubemap(cube);','const target={texture:cube};globalThis.__cabFaces=faces;').replace('cube.dispose();generator.dispose();return target;','return target;');
fs.writeFileSync(source+'/js/cab/CabLighting.export.js',lighting);
let assembly=fs.readFileSync(source+'/js/cab/CabModel.js','utf8');
assembly=assembly.replace("import {batchCabStatic} from './CabBatching.js?v=cab-r2';",'const batchCabStatic=()=>null;').replace("'./CabLighting.js?v=cab-r2'","'./CabLighting.export.js'");
fs.writeFileSync(source+'/js/cab/CabModel.export.js',assembly);
const {createCabModel}=await import(pathToFileURL(source+'/js/cab/CabModel.export.js').href);
const cab=createCabModel(THREE,null);const root=cab.root;root.name='Cab81_717_R21';root.position.set(0,0,0);root.scale.setScalar(1);
const recipe={reference_url:'https://sskuz.github.io/Minskmetrogame/cab-preview/?preview=station&v=cab-r2.1',source_branch:'cab-development',source_commit:process.env.CAB_SOURCE_COMMIT,entry_version:'cab-r2.1',geometry_version:cab.version,three:THREE.REVISION,modules,controls:[],bumps:{},materials:{},environment_faces:globalThis.__cabFaces.map(c=>c.toBuffer('image/png').toString('base64'))};
for(const [name,m] of Object.entries(cab.materials))if(m?.isMaterial)m.name='cab_'+name;
let unique=0;root.traverse(o=>{const list=Array.isArray(o.material)?o.material:[o.material];for(const m of list){if(!m?.isMeshStandardMaterial||m.transparent||m.emissive?.getHex()>0)continue;if(!m.name)m.name='cab_surface_'+unique++;if(recipe.materials[m.name])continue;const params={env_intensity:m.envMapIntensity??.52,bump_scale:m.bumpScale??0};if(m.bumpMap){const bytes=m.bumpMap.image.toBuffer('image/png'),id=hash(bytes);recipe.bumps[id]=bytes.toString('base64');params.bump=id;}recipe.materials[m.name]=params;}});
for(const [id,c] of cab.controls){const moving=c.handle??c.knob??c.cap;moving.name='Moving_'+id;moving.userData.control=id;recipe.controls.push({id,kind:c.kind,enabled:c.enabled,title:c.title});}
cab.equipment.wipers.forEach((o,i)=>o.name='Wiper_'+(i?'Right':'Left'));
for(const g of cab.desk.gauges){const pivot=g.children.find(o=>o.isGroup);pivot.name=g.name+'_Needle';}
cab.desk.speed.group.name='SpeedDisplay';
// GPU render targets are rebound to live Godot SubViewports after import.
for(const face of [...cab.rearMirrors.map(m=>m.face),cab.equipment.video]){face.material=face.material.clone();face.material.map=null;}
const lights=[];root.traverse(o=>{if(o.isLight){o.name=o.isSpotLight?'OriginalCabCeilingSpot':'OriginalCabFill';lights.push({name:o.name,type:o.type,color:o.color.toArray(),intensity:o.intensity,range:o.distance,angle:o.angle,penumbra:o.penumbra});}});recipe.lights=lights;
// Keep the complete original shell and every shared instance. No geometry merging.
const instanced=[];root.traverse(o=>{if(o.isInstancedMesh)instanced.push(o);});let instanceCount=0;
for(const o of instanced){const group=new THREE.Group();group.name=o.name;group.position.copy(o.position);group.quaternion.copy(o.quaternion);group.scale.copy(o.scale);group.userData={...o.userData};for(let i=0;i<o.count;i++){const mesh=new THREE.Mesh(o.geometry,o.material),matrix=new THREE.Matrix4();o.getMatrixAt(i,matrix);matrix.decompose(mesh.position,mesh.quaternion,mesh.scale);group.add(mesh);instanceCount++;}o.parent.add(group);o.removeFromParent();}
root.updateMatrixWorld(true);const bytes=Buffer.from(await new GLTFExporter().parseAsync(root,{binary:true,onlyVisible:false,trs:true}));
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(out+'/cab_r21.glb',bytes);recipe.glb_sha256=hash(bytes);recipe.instances_preserved=instanceCount;
recipe.audio={};for(const file of ['malinovka_arrival.mp3','malinovka_departure_petrovshchina.mp3']){const data=fs.readFileSync(source+'/audio/'+file);fs.writeFileSync(out+'/'+file,data);recipe.audio[file]=hash(data);}
fs.writeFileSync(out+'/cab_r21.json',JSON.stringify(recipe));
console.log(JSON.stringify({version:recipe.entry_version,glb_sha256:recipe.glb_sha256,controls:recipe.controls.length,instances:instanceCount,materials:Object.keys(recipe.materials).length,lights:lights.length}));
