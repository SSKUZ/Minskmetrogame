// Load the actual v106 geometry from its calibrated viewer into the gameplay
// THREE.Scene. No approximated meshes are constructed here.
export async function loadV106Geometry({THREE,scene,renderer,timeoutMs=90000}){
 if(!THREE?.Group||!scene?.add)throw new TypeError('THREE and scene required');
 const startedAt=performance.now();
 const frame=document.createElement('iframe');
 frame.setAttribute('aria-hidden','true');
 frame.tabIndex=-1;
 frame.style.cssText='position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;left:-10000px;top:-10000px';
 frame.src=new URL('./preview/wagon.html?formation=train&gameExport=1',document.baseURI).href;
 let keepFrame=false;
 document.body.appendChild(frame);
 try{
  await new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>reject(new Error('v106 viewer load timed out')),timeoutMs);
   let settled=false;
   const finish=(error)=>{if(settled)return;settled=true;clearTimeout(timer);error?reject(error):resolve()};
   frame.addEventListener('load',()=>{
    const started=performance.now();
    const poll=()=>{
     if(settled)return;
     try{
      if(frame.contentWindow?.wagonReady&&typeof frame.contentWindow.wagonGetLiveConsist==='function')return finish();
      if(performance.now()-started>timeoutMs)return finish(new Error('v106 geometry not ready'));
      setTimeout(poll,100);
     }catch(e){finish(e)}
    };
    poll();
   },{once:true});
   frame.addEventListener('error',()=>finish(new Error('v106 iframe failed')),{once:true});
  });
  // Retain the original live scene graph instead of JSON round-tripping it.
  // This preserves canvas textures, physical materials, environment maps,
  // per-mesh layers and the original calibrated geometry.
  const source=frame.contentWindow.wagonGetLiveConsist?.();
  if(!source?.root||source.cars?.length!==4)throw new Error('v106 live consist unavailable');
  const root=source.root;
  const leaves=source.cars.flatMap(car=>car.leaves.map(d=>({
   object:d.leaf,homeZ:d.homeZ,half:d.half,travel:d.travel
  })));
  if(leaves.length!==64||leaves.some(d=>!d.object||!root.getObjectById(d.object.id)))throw new Error('v106 live door leaves missing from source scene graph');
  Object.defineProperty(root,'v106DoorActuators',{value:leaves,configurable:true});
  // Objects created inside the iframe belong to a different JavaScript realm.
  // Three's WebGLAttributes uses instanceof checks for typed arrays, so passing
  // the iframe's BufferAttributes directly to the game renderer makes valid
  // geometry fail as "Unsupported buffer data format". Re-home every geometry
  // attribute/index into this window while keeping the exact numeric mesh data.
  let rehomedAttributes=0;
  const rehomeAttribute=attribute=>{
   if(!attribute)return attribute;
   if(attribute.isInterleavedBufferAttribute){
    const data=attribute.data;
    const LocalArray=globalThis[data.array.constructor?.name];
    if(typeof LocalArray!=='function')throw new Error('v106 unsupported interleaved array '+data.array.constructor?.name);
    const localData=new THREE.InterleavedBuffer(new LocalArray(data.array),data.stride);
    localData.setUsage?.(data.usage);
    const local=new THREE.InterleavedBufferAttribute(localData,attribute.itemSize,attribute.offset,attribute.normalized);
    local.name=attribute.name||'';
    rehomedAttributes++;
    return local;
   }
   const sourceArray=attribute.array;
   if(!sourceArray)return attribute;
   const LocalArray=globalThis[sourceArray.constructor?.name];
   if(typeof LocalArray!=='function')throw new Error('v106 unsupported attribute array '+sourceArray.constructor?.name);
   const local=new THREE.BufferAttribute(new LocalArray(sourceArray),attribute.itemSize,attribute.normalized);
   local.name=attribute.name||'';
   local.setUsage?.(attribute.usage);
   rehomedAttributes++;
   return local;
  };
  root.traverse(object=>{
   const geometry=object.geometry;
   if(!object.isMesh||!geometry?.isBufferGeometry)return;
   for(const name of Object.keys(geometry.attributes))geometry.setAttribute(name,rehomeAttribute(geometry.getAttribute(name)));
   for(const [name,attributes] of Object.entries(geometry.morphAttributes||{}))
    geometry.morphAttributes[name]=attributes.map(rehomeAttribute);
   if(geometry.index)geometry.setIndex(rehomeAttribute(geometry.index));
  });
  window.metroV106InvalidTextureMaps=0;
  root.name='game-v106-four-car-consist';
  // Preserve the exact four original viewer layers. The game renders the
  // imported consist in the same calibrated multi-pass order as the viewer.
  // Forcing all meshes onto layer 0 destroys front-cab shading and finish.
  // Reuse the viewer's original calibrated light rig, including its distinct
  // front/cab layers. Do not substitute generic game lights for this model.
  const lighting=new THREE.Group();
  lighting.name='v106-original-viewer-lighting';
  // Lights are realm-sensitive too: WebGLLights expects Color/Vector objects
  // created by this THREE instance. Recreate the exact viewer light settings
  // instead of attaching iframe Light instances directly.
  const localLight=sourceLight=>{
   let light;
   if(sourceLight.isHemisphereLight)light=new THREE.HemisphereLight(sourceLight.color.getHex(),sourceLight.groundColor.getHex(),sourceLight.intensity);
   else if(sourceLight.isDirectionalLight)light=new THREE.DirectionalLight(sourceLight.color.getHex(),sourceLight.intensity);
   else if(sourceLight.isPointLight)light=new THREE.PointLight(sourceLight.color.getHex(),sourceLight.intensity,sourceLight.distance,sourceLight.decay);
   else if(sourceLight.isAmbientLight)light=new THREE.AmbientLight(sourceLight.color.getHex(),sourceLight.intensity);
   else throw new Error('v106 unsupported viewer light '+sourceLight.type);
   light.name=sourceLight.name;
   light.position.copy({x:sourceLight.position.x,y:sourceLight.position.y,z:sourceLight.position.z});
   light.quaternion.copy({x:sourceLight.quaternion.x,y:sourceLight.quaternion.y,z:sourceLight.quaternion.z,w:sourceLight.quaternion.w});
   light.scale.copy({x:sourceLight.scale.x,y:sourceLight.scale.y,z:sourceLight.scale.z});
   light.layers.mask=sourceLight.layers.mask;
   light.visible=sourceLight.visible;
   if(light.isDirectionalLight&&sourceLight.target){
    light.target.position.set(sourceLight.target.position.x,sourceLight.target.position.y,sourceLight.target.position.z);
    lighting.add(light.target);
   }
   return light;
  };
  for(const sourceLight of source.lighting)lighting.add(localLight(sourceLight));
  Object.defineProperty(root,'v106Lighting',{value:lighting,configurable:true});
  root.visible=false;
  const metrics={loadMs:Math.round(performance.now()-startedAt),meshCount:0,triangles:0,doorLeaves:leaves.length,rehomedAttributes};
  root.traverse(o=>{if(o.isMesh){metrics.meshCount++;const g=o.geometry;if(g)metrics.triangles+=g.index?g.index.count/3:(g.attributes.position?.count||0)/3;}});
  // Inspect the actual in-memory source assets before the first game render.
  // Report broken resources rather than silently removing their maps.
  const textures=new Set();let physicalMaterials=0,missingImages=0;
  root.traverse(object=>{
   if(!object.isMesh)return;
   for(const material of (Array.isArray(object.material)?object.material:[object.material])){
    if(!material)continue;
    if(material.isMeshPhysicalMaterial)physicalMaterials++;
    for(const key of ['map','alphaMap','normalMap','roughnessMap','metalnessMap','emissiveMap','envMap']){
     const texture=material[key];
     if(!texture?.isTexture)continue;
     textures.add(texture);
     if(!texture.image&&!texture.source?.data)missingImages++;
    }
   }
  });
  metrics.lightCount=source.lighting.length;
  metrics.textureCount=textures.size;
  metrics.physicalMaterialUses=physicalMaterials;
  metrics.missingTextureImages=missingImages;
  if(missingImages)console.warn('v106: some original texture sources are unavailable',missingImages);
  if(metrics.meshCount<100||metrics.triangles<1000)
   throw new Error('v106 geometry incomplete: '+metrics.meshCount+' meshes / '+metrics.triangles+' triangles');
  metrics.invalidTextures=[...textures].filter(t=>!t.image&&!t.source?.data).length;
  // The source renderer owns its GPU-generated environment maps. Their
  // images are not necessarily portable between WebGL contexts.
  metrics.gpuOnlyEnvironmentMaps=[...textures].filter(t=>t.isRenderTargetTexture).length;
  // The source's studio PMREM is a WebGLRenderTarget owned by the iframe GPU
  // context. Its texture cannot be reused in the gameplay renderer. Rebuild
  // that *same* softbox studio and PMREM in the gameplay WebGL context, then
  // relink only materials that reference the source GPU-only environment.
  // Do not change their colors, roughness, clearcoat or envMapIntensity.
  if(metrics.gpuOnlyEnvironmentMaps){
   if(!renderer)throw new Error('v106 GPU environment requires the gameplay renderer');
   const studio=new THREE.Scene();
   studio.background=new THREE.Color(0x30302e);
   studio.add(new THREE.Mesh(new THREE.BoxGeometry(30,12,50),new THREE.MeshBasicMaterial({color:0x282826,side:THREE.BackSide})));
   const softbox=(w,h,d,x,y,z,color,intensity=1)=>{
    const material=new THREE.MeshBasicMaterial({color});
    material.color.multiplyScalar(intensity);
    const object=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);
    object.position.set(x,y,z);studio.add(object);
   };
   softbox(29,.02,49,0,-3.5,0,0x353638);
   for(const x of [-4,4])softbox(.45,.04,22,x,5.1,0,0xfff6df,4);
   for(const x of [-5,5])softbox(.40,3.2,.05,x,1.5,-6,0xf7f1e4,2.5);
   const generator=new THREE.PMREMGenerator(renderer);
   let target;
   try{target=generator.fromScene(studio,.04,.1,80);}
   finally{
    generator.dispose();
    studio.traverse(object=>{if(object.isMesh){object.geometry.dispose();object.material.dispose();}});
   }
   const replaced=new Set();
   root.traverse(object=>{
    if(!object.isMesh)return;
    for(const material of (Array.isArray(object.material)?object.material:[object.material])){
     if(material?.envMap?.isRenderTargetTexture&&material.envMap!==target.texture){
      material.envMap=target.texture;material.needsUpdate=true;replaced.add(material);
     }
    }
   });
   if(!replaced.size){target.dispose();throw new Error('v106 GPU environment material references not found');}
   Object.defineProperty(root,'v106EnvironmentTarget',{value:target,configurable:true});
   metrics.rehomedEnvironmentMaterials=replaced.size;
  }
  metrics.sourceThreeRevision=frame.contentWindow.wagonThreeRevision||null;
  metrics.gameThreeRevision=THREE.REVISION||null;
  // PMREM render-target textures may be GPU-only: report them, do not
  // reject an otherwise complete train before the game renderer tries it.
  window.metroV106InvalidTextureMaps=metrics.invalidTextures;
  window.metroV106Metrics=metrics;
  if(metrics.gpuOnlyEnvironmentMaps)console.info('v106: rebuilt original studio PMREM in gameplay renderer for',metrics.rehomedEnvironmentMaterials,'materials');
  // Commit to the game scene only after the source passes integrity checks.
  // Failed loads must not leave orphaned lights or partial train geometry.
  // Viewer light positions are expressed in the original consist's local
  // coordinates. The gameplay train is translated every frame; parenting the
  // rig to the consist keeps its short-range saloon lamps aligned with the
  // same windows and seats instead of leaving them at the viewer origin.
  root.add(lighting);
  scene.add(root);
  // Keep the source document alive: its canvas-backed textures and PMREM
  // resources may be invalidated when navigating the iframe to about:blank.
  // The viewer animation loop is disabled in gameExport mode.
  keepFrame=true;
  Object.defineProperty(root,'v106SourceFrame',{value:frame,configurable:true});
  return root;
 }finally{
  if(!keepFrame){frame.src='about:blank';frame.remove();}
 }
}
