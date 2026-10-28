// Load the actual v106 geometry from its calibrated viewer into the gameplay
// THREE.Scene. No approximated meshes are constructed here.
export async function loadV106Geometry({THREE,scene,timeoutMs=90000}){
 if(!THREE?.ObjectLoader||!scene?.add)throw new TypeError('THREE and scene required');
 const startedAt=performance.now();
 const frame=document.createElement('iframe');
 frame.setAttribute('aria-hidden','true');
 frame.tabIndex=-1;
 frame.style.cssText='position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;left:-10000px;top:-10000px';
 frame.src=new URL('./preview/wagon.html?formation=train&gameExport=1',document.baseURI).href;
 document.body.appendChild(frame);
 try{
  await new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>reject(new Error('v106 viewer load timed out')),timeoutMs);
   const finish=(error)=>{clearTimeout(timer);error?reject(error):resolve()};
   frame.addEventListener('load',()=>{
    const started=performance.now();
    const poll=()=>{
     try{
      if(frame.contentWindow?.wagonReady&&typeof frame.contentWindow.wagonExportConsist==='function')return finish();
      if(performance.now()-started>timeoutMs)return finish(new Error('v106 geometry not ready'));
      setTimeout(poll,100);
     }catch(e){finish(e)}
    };
    poll();
   },{once:true});
   frame.addEventListener('error',()=>finish(new Error('v106 iframe failed')),{once:true});
  });
  const exported=frame.contentWindow.wagonExportConsist();
  const root=new THREE.ObjectLoader().parse(exported.geometry);
  // Object3D JSON cannot reliably round-trip every canvas/video texture from
  // the standalone viewer. An imported texture with no image crashes the
  // Three.js renderer ("Cannot read properties of null (reading 'height')").
  // Remove only broken maps; preserve all meshes, materials and valid textures.
  let invalidTextureMaps=0;
  const textureSlots=['map','alphaMap','aoMap','bumpMap','normalMap','roughnessMap','metalnessMap','emissiveMap','lightMap','displacementMap','envMap'];
  root.traverse(object=>{
   if(!object.isMesh)return;
   for(const material of (Array.isArray(object.material)?object.material:[object.material])){
    if(!material)continue;
    for(const slot of textureSlots){
     const texture=material[slot];
     if(texture?.isTexture&&!texture.image&&!texture.source?.data){
      material[slot]=null;
      invalidTextureMaps++;
      material.needsUpdate=true;
     }
    }
   }
  });
  window.metroV106InvalidTextureMaps=invalidTextureMaps;
  const byUuid=new Map();root.traverse(o=>byUuid.set(o.uuid,o));
  const leaves=exported.doors.flatMap(car=>car.leaves.map(d=>({...d,object:byUuid.get(d.uuid)})));
  if(leaves.length!==64||leaves.some(d=>!d.object))throw new Error('v106 door leaves missing from imported geometry');
  // Keep live Object3D references outside userData to avoid circular JSON
  // serialization and costly recursive inspection by debugging tools.
  Object.defineProperty(root,'v106DoorActuators',{value:leaves,configurable:true});
  root.name='game-v106-four-car-consist';
  root.traverse(object=>{
   // The standalone viewer uses four special camera/render layers.
   // Game cameras use layer zero, so enable it on imported geometry.
   object.layers.enable(0);
  });
  root.visible=false;
  scene.add(root);
  const metrics={loadMs:Math.round(performance.now()-startedAt),meshCount:0,triangles:0,doorLeaves:leaves.length};
  root.traverse(o=>{if(o.isMesh){metrics.meshCount++;const g=o.geometry;if(g)metrics.triangles+=g.index?g.index.count/3:(g.attributes.position?.count||0)/3;}});
  window.metroV106Metrics=metrics;
  return root;
 }finally{
  frame.src='about:blank';
  frame.remove();
 }
}
