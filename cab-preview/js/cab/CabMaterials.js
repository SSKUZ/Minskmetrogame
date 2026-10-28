import {createCabSurfaces} from './CabSurfaces.js?v=cab-r2';
// Linear-light PBR finishes share small colour, roughness and relief textures.
export function createCabMaterials(THREE){
 const surfaces=createCabSurfaces(THREE);
 const standard=(color,roughness=.65,metalness=0,extra={})=>new THREE.MeshStandardMaterial({color,roughness,metalness,...extra});
 const enamel=color=>new THREE.MeshPhysicalMaterial({color,roughness:.28,metalness:.05,clearcoat:.85,clearcoatRoughness:.2});
 return {
  panel:standard(0xb0aca2,1,.18,{...surfaces.plate,bumpScale:.00018}),
  casing:standard(0x333633,1,.28,{...surfaces.bakelite,bumpScale:.00025}),
  edge:standard(0x8a8f8c,.45,.82,{...surfaces.steel,bumpScale:.00006}),
  steel:standard(0xb1b4ac,.63,.92,{...surfaces.steel,bumpScale:.00006}),
  brass:standard(0x9a8051,.7,.8,{...surfaces.steel,bumpScale:.00006}),
  black:new THREE.MeshPhysicalMaterial({color:0x171815,roughness:1,metalness:0,...surfaces.bakelite,bumpScale:.00012,clearcoat:.32,clearcoatRoughness:.32}),
  rubber:standard(0x111511,.97,0,{bumpMap:surfaces.bakelite.bumpMap,bumpScale:.00025}),
  ivory:standard(0xc8bfac,1,.08,{...surfaces.paint,bumpScale:.00012}),
  blue:standard(0x173c54,1,.2,{...surfaces.paint,bumpScale:.00022}),
  floor:standard(0x34332e,.98,0,{bumpMap:surfaces.fabric.bumpMap,bumpScale:.0005}),
  red:enamel(0xa81812),green:enamel(0x176d36),white:enamel(0xd7d5c8),amber:enamel(0xb39120),
  wood:new THREE.MeshPhysicalMaterial({color:0xffffff,roughness:1,...surfaces.wood,bumpScale:.00006,clearcoat:.38,clearcoatRoughness:.28}),
  seat:standard(0x292c36,1,0,{...surfaces.fabric,bumpScale:.00045}),
  glass:new THREE.MeshPhysicalMaterial({color:0xd2dbcf,transparent:true,opacity:.09,roughness:.1,metalness:0,clearcoat:1,clearcoatRoughness:.06,depthWrite:false}),
  windscreen:new THREE.MeshBasicMaterial({color:0x9bb4b0,transparent:true,opacity:.018,depthWrite:false,side:THREE.DoubleSide}),
  glow:new THREE.MeshBasicMaterial({color:0xb3e821,toneMapped:false}),
  contactShadow:new THREE.MeshBasicMaterial({map:surfaces.contact,transparent:true,opacity:.5,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1}),
  grain:surfaces.paint.map
 };
}
