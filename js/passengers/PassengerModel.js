import * as THREE from '../vendor/three.module.js';
import {GLTFLoader} from '../vendor/addons/GLTFLoader.js';
import {clone as cloneSkeleton} from '../vendor/addons/SkeletonUtils.js';
import {PASSENGER_ASSETS,PROFILES} from './PassengerConfig.js';

const tones=[0xffffff,0xbbbfc9,0xb8c5ba,0xc9b6a9,0xaeb8c5];
export class PassengerModelLibrary{
 constructor(){this.sources=new Map();this.pending=new Map();this.errors=[];this.materials=new Map();this.textures=new Map();this.loader=new GLTFLoader();THREE.Cache.enabled=true;}
 async load(profile,detail='medium'){
  const key=`${profile}:${detail}`;if(this.sources.has(key))return this.sources.get(key);
  if(this.pending.has(key))return this.pending.get(key);
  const promise=this.loader.loadAsync(new URL(PROFILES[profile]+(detail==='low'?'-low':'')+'.glb',PASSENGER_ASSETS).href)
   .then(gltf=>{
    gltf.scene.updateMatrixWorld(true);
    const bounds=new THREE.Box3();
    gltf.scene.traverse(o=>{if(o.isMesh){o.geometry.computeBoundingBox();bounds.union(o.geometry.boundingBox);}});
    // GLTFLoader otherwise creates a GPU texture per GLB for the same external image.
    const textureSlots=['map','normalMap','roughnessMap','metalnessMap','aoMap','emissiveMap','alphaMap'];
    gltf.scene.traverse(o=>{if(!o.isMesh)return;for(const m of [].concat(o.material))for(const slot of textureSlots){
     const tex=m[slot];if(!tex)continue;
     const index=gltf.parser.associations.get(tex)?.textures;
     const image=gltf.parser.json.images?.[gltf.parser.json.textures?.[index]?.source];
     if(!image?.uri)continue;
     const key=JSON.stringify([image.uri,tex.colorSpace,tex.flipY,tex.wrapS,tex.wrapT,tex.channel]);
     if(this.textures.has(key)){m[slot]=this.textures.get(key);if(m[slot]!==tex)tex.dispose();}
     else this.textures.set(key,tex);
    }});
    const source={...gltf,height:bounds.max.y-bounds.min.y,floor:bounds.min.y};
    gltf.scene.traverse(o=>{if(o.isMesh){o.castShadow=false;o.receiveShadow=false;
     o.material.roughness=Math.max(.65,o.material.roughness);
     if(o.material.map)o.material.map.anisotropy=2;
     if(o.material.name==='Hair'){o.material.alphaTest=.42;o.material.depthWrite=true;o.material.transparent=false;o.material.side=THREE.DoubleSide;}
    }});
    this.sources.set(key,source);return source;
   }).catch(e=>{this.errors.push(`${key}: ${e.message}`);throw e;});
  this.pending.set(key,promise);return promise;
 }
 async preload(){
  // Bound HTTP/decoder concurrency; all files are served from this repository.
  const jobs=PROFILES.flatMap((_,i)=>[[i,'medium'],[i,'low']]);
  await Promise.all(Array.from({length:3},async()=>{while(jobs.length){const [i,d]=jobs.shift();await this.load(i,d);}}));
 }
 create(agent,detail){
  const source=this.sources.get(`${agent.profile}:${detail}`);if(!source)return null;
  const wrapper=new THREE.Group(),model=cloneSkeleton(source.scene);wrapper.add(model);
  const desired=agent.child?(agent.profile===6?1.31:1.38):agent.elder?(agent.profile===4?1.70:1.59):(agent.profile%2?1.68:1.79);
  const scale=desired/source.height;
  model.scale.setScalar(scale);model.position.y=-source.floor*scale;
  // All outfit primitives use the same cloned bone palette. Share one skeleton
  // inside this actor instead of allocating a bone texture for every material.
  const skeletons=new Map();model.traverse(o=>{if(!o.isSkinnedMesh)return;
   const key=o.skeleton.bones.map(b=>b.uuid).join(':');
   if(skeletons.has(key)){o.skeleton.dispose();o.skeleton=skeletons.get(key);}else skeletons.set(key,o.skeleton);
  });
  const bones={};model.traverse(o=>{
   if(o.isBone)bones[o.name]=o;
   if(o.isSkinnedMesh){o.frustumCulled=true;o.boundingSphere=new THREE.Sphere(new THREE.Vector3(0,source.height*.50,0),source.height*.77);}
   if(o.isMesh&&o.material.name==='Outfit'){
    const key=`${agent.profile}:${agent.tint}`;
    if(!this.materials.has(key)){const material=o.material.clone();material.color.multiply(new THREE.Color(tones[agent.tint]));this.materials.set(key,material);}
    o.material=this.materials.get(key);
   }
  });
  const props=createAccessories(model,bones,agent,source.height);
  wrapper.name=`Passenger-${agent.id}-${detail}`;
  return {root:wrapper,model,bones,props,height:desired,scale,animations:source.animations,
   dispose(){
    // Skeleton clones share the source mesh/materials. Only accessories belong
    // to this passenger; freeing shared geometry would break everybody else.
    const geometries=new Set(),materials=new Set(),shared=new Set(propMaterials.values());
    for(const prop of Object.values(props))prop.traverse(o=>{
     if(o.geometry)geometries.add(o.geometry);
     for(const m of [].concat(o.material??[]))if(!shared.has(m))materials.add(m);
    });
    for(const skeleton of skeletons.values())skeleton.dispose();
    for(const g of geometries)g.dispose();for(const m of materials)m.dispose();
   }};
 }
}

const propMaterials=new Map();
function material(color){if(!propMaterials.has(color))propMaterials.set(color,new THREE.MeshStandardMaterial({color,roughness:.86}));return propMaterials.get(color);}
function roundedBox(w,h,d,color){
 const r=Math.min(w,h,d)*.23,s=new THREE.Shape(),x=-w/2,y=-h/2;
 s.moveTo(x+r,y);s.lineTo(x+w-r,y);s.quadraticCurveTo(x+w,y,x+w,y+r);
 s.lineTo(x+w,y+h-r);s.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
 s.lineTo(x+r,y+h);s.quadraticCurveTo(x,y+h,x,y+h-r);s.lineTo(x,y+r);s.quadraticCurveTo(x,y,x+r,y);
 const geometry=new THREE.ExtrudeGeometry(s,{depth:d-2*r,bevelEnabled:true,bevelSize:r,bevelThickness:r,bevelSegments:2,curveSegments:4,steps:1});
 geometry.translate(0,0,-d/2+r);geometry.computeVertexNormals();return new THREE.Mesh(geometry,material(color));
}
function createAccessories(model,bones,a,height){
 const props={};model.updateMatrixWorld(true);
 if(a.accessory){
  const group=new THREE.Group();model.add(group);
  if(a.accessory==='backpack'){
   const bag=roundedBox(.25,.34,.13,a.tint%2?0x3c4650:0x5a4a3c);bag.position.set(0,height*.64,-.18);group.add(bag);
   const pocket=roundedBox(.20,.14,.033,0x343941);pocket.position.set(0,height*.60,-.252);group.add(pocket);
   const zipper=roundedBox(.19,.006,.008,0x929395);zipper.position.set(0,height*.637,-.27);group.add(zipper);
   const handle=new THREE.Mesh(new THREE.TorusGeometry(.042,.008,5,12,Math.PI),material(0x30343b));handle.position.set(0,height*.64+.18,-.17);group.add(handle);
   for(const side of [-1,1]){
    const curve=new THREE.CatmullRomCurve3([new THREE.Vector3(side*.09,height*.64+.15,-.16),new THREE.Vector3(side*.16,height*.64+.13,.01),new THREE.Vector3(side*.14,height*.64-.13,.035),new THREE.Vector3(side*.09,height*.64-.13,-.16)]);
    group.add(new THREE.Mesh(new THREE.TubeGeometry(curve,10,.012,5,false),material(0x30343b)));
   }
   // Rebase the backpack around its own centre before attaching it to the spine.
   const pivot=new THREE.Vector3(0,height*.64,-.18);
   for(const child of group.children)child.position.sub(pivot);group.position.copy(pivot);
   bones.Spine2?.attach(group);group.updateMatrix();
   group.userData.carried={parent:group.parent,matrix:group.matrix.clone()};
  }else{
   const shopping=a.accessory==='shopping';
   const bag=roundedBox(shopping?.27:.29,shopping?.34:.23,.12,shopping?0xbda98c:0x5a4233);
   group.add(bag);bag.position.y=-.14;
   const loop=new THREE.Mesh(new THREE.TorusGeometry(.062,.009,5,12),material(0x504b42));loop.position.y=.035;group.add(loop);
   if(bones.LeftHand){bones.LeftHand.add(group);group.position.set(0,.06,0);}
  }
  props.bag=group;
 }
 const phone=roundedBox(.067,.128,.009,0x161c23);
 const screen=new THREE.Mesh(new THREE.PlaneGeometry(.056,.109),new THREE.MeshBasicMaterial({color:0x99b3c1}));
 screen.position.z=.005;phone.add(screen);phone.visible=false;
 model.add(phone);
 props.phone=phone;
 return props;
}
