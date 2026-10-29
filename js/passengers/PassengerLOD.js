import * as THREE from '../vendor/three.module.js';
import {PASSENGER_ASSETS,PROFILES} from './PassengerConfig.js';

export function selectPassengerLOD(distance,previous='far'){
 // Hysteresis avoids a high/low mesh swap every time a person turns at a boundary.
 const near=previous==='near'?23:20,far=previous==='far'?53:59;
 return distance<near?'near':distance<far?'medium':'far';
}

// Eight camera angles of the actual textured person, baked offline. Far crowds
// cost two triangles/person and one draw call per demographic, including mirrors.
export class PassengerImpostors{
 constructor(scene){
  this.batches=[];this.dummy=new THREE.Object3D();this.scene=scene;this.ready=false;
 }
 async load(){
  const loader=new THREE.TextureLoader();
  const variants=PROFILES.flatMap((name,profile)=>[{name,profile,seated:false},{name,profile,seated:true}]);
  this.batches=await Promise.all(variants.map(async({name,profile,seated})=>{
   const tex=await loader.loadAsync(new URL(name+(seated?'-seated':'')+'-atlas.png',PASSENGER_ASSETS).href);tex.colorSpace=THREE.SRGBColorSpace;
   const geo=new THREE.PlaneGeometry(1.20,2.20);geo.translate(0,1.10,0);
   geo.setAttribute('heading',new THREE.InstancedBufferAttribute(new Float32Array(256),1));
   const mat=new THREE.ShaderMaterial({uniforms:{atlas:{value:tex},fogColor:{value:this.scene.fog.color},fogNear:{value:45},fogFar:{value:190}},
    transparent:false,side:THREE.DoubleSide,
    vertexShader:`attribute float heading; varying vec2 texcoord; varying float fogDepth;
     void main(){vec4 center=modelMatrix*instanceMatrix*vec4(0.,0.,0.,1.);
      float scale=length(instanceMatrix[1].xyz);vec3 dir=cameraPosition-center.xyz;dir.y=0.;dir=normalize(dir);
      vec3 right=vec3(dir.z,0.,-dir.x);float angle=atan(dir.x,dir.z)-heading;
      float tile=mod(floor(angle/6.2831853*8.+.5)+8.,8.);
      texcoord=vec2((uv.x+tile)/8.,uv.y);
      vec4 mv=viewMatrix*vec4(center.xyz+right*position.x*scale+vec3(0.,position.y*scale,0.),1.);
      gl_Position=projectionMatrix*mv;fogDepth=-mv.z;}`,
    fragmentShader:`uniform sampler2D atlas;uniform vec3 fogColor;uniform float fogNear;uniform float fogFar;
      varying vec2 texcoord;varying float fogDepth;
      void main(){vec4 c=texture2D(atlas,texcoord);if(c.a<.45)discard;
       gl_FragColor=vec4(mix(c.rgb,fogColor,smoothstep(fogNear,fogFar,fogDepth)),1.);}`,
   });
   const mesh=new THREE.InstancedMesh(geo,mat,256);mesh.count=0;mesh.frustumCulled=false;mesh.name=`PassengerImpostors-${profile}`;
   mesh.userData={profile,seated};
   mesh.onBeforeRender=()=>{mat.uniforms.fogColor.value.copy(this.scene.fog.color);mat.uniforms.fogNear.value=this.scene.fog.near;mat.uniforms.fogFar.value=this.scene.fog.far;};
   this.scene.add(mesh);return mesh;
  }));this.ready=true;
 }
 begin(){for(const batch of this.batches)batch.count=0;}
 add(agent,position){
  const batch=this.batches[agent.profile*2+(agent.state==='seated'?1:0)];if(!batch||batch.count>=256)return;
  this.dummy.position.copy(position);this.dummy.rotation.set(0,0,0);this.dummy.scale.setScalar(agent.scale);this.dummy.updateMatrix();
  batch.setMatrixAt(batch.count,this.dummy.matrix);batch.geometry.attributes.heading.setX(batch.count,agent.heading);batch.count++;
 }
 end(){for(const batch of this.batches){batch.visible=batch.count>0;batch.instanceMatrix.needsUpdate=true;batch.geometry.attributes.heading.needsUpdate=true;}}
}
