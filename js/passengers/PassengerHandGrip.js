import * as THREE from '../vendor/three.module.js';

// The accepted game-lite rig has wrist joints but no finger joints. A bounded
// material deformation curls the existing fingers; no extra body mesh is drawn.
export class PassengerHandGrip {
 constructor(view){this.view=view;this.materials=[];this.uniforms=[];}
 update(grip){
  if(!grip){for(const uniforms of this.uniforms)uniforms.gripActive.value=0;return;}
  if(this.side!==grip.side){this.dispose();this.side=grip.side;
   this.view.model.traverse(mesh=>{
    if(!mesh.isSkinnedMesh||mesh.material.name!=='Skin')return;
    const index=mesh.skeleton.bones.findIndex(b=>b.name===grip.side+'Hand');if(index<0)return;
    const toHand=new THREE.Matrix4().multiplyMatrices(mesh.skeleton.boneInverses[index],mesh.bindMatrix);
    const uniforms={gripActive:{value:1},gripIndex:{value:index},gripToHand:{value:toHand},gripFromHand:{value:toHand.clone().invert()}};
    const original=mesh.material,material=original.clone();this.materials.push({mesh,original,material});this.uniforms.push(uniforms);
    material.customProgramCacheKey=()=> 'passenger-curled-hand-v1';
    material.onBeforeCompile=shader=>{
     Object.assign(shader.uniforms,uniforms);
     shader.vertexShader='uniform float gripActive; uniform float gripIndex; uniform mat4 gripToHand; uniform mat4 gripFromHand;\n'+shader.vertexShader;
     shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>
      if(gripActive>.5){
       float handWeight=dot(1.-step(vec4(.5),abs(skinIndex-vec4(gripIndex))),skinWeight);
       vec3 hand=(gripToHand*vec4(transformed,1.)).xyz;
       float along=clamp((hand.y-.075)/.12,0.,1.);
       float weight=smoothstep(.55,.9,handWeight)*smoothstep(.065,.09,hand.y);
       vec3 curled=hand;float angle=along*1.9;
       curled.y=.075+sin(angle)*.045;curled.z=hand.z*.65+(1.-cos(angle))*.045;
       transformed=mix(transformed,(gripFromHand*vec4(curled,1.)).xyz,weight);
      }`);
    };
    mesh.material=material;
   });
  }
  for(const uniforms of this.uniforms)uniforms.gripActive.value=1;
  const hand=this.view.bones[grip.side+'Hand'];
  if(hand){
   const x=grip.tangent.clone().normalize(),z=grip.normal.clone().negate(),y=z.clone().cross(x).normalize();z.crossVectors(x,y).normalize();
   const world=new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(x,y,z));
   const parent=hand.parent.getWorldQuaternion(new THREE.Quaternion()).invert();hand.quaternion.copy(parent.multiply(world));hand.updateWorldMatrix(false,true);
  }
 }
 dispose(){for(const {mesh,original,material} of this.materials){mesh.material=original;material.dispose();}this.materials=[];this.uniforms=[];this.side=null;}
}
