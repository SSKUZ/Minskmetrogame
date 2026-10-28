// Load the actual v106 geometry from its calibrated viewer into the gameplay
// THREE.Scene. No approximated meshes are constructed here.
export async function loadV106Geometry({THREE,scene,timeoutMs=90000}){
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
   const finish=(error)=>{clearTimeout(timer);error?reject(error):resolve()};
   frame.addEventListener('load',()=>{
    const started=performance.now();
    const poll=()=>{
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
  if(leaves.length!==64||leaves.some(d=>!d.object))throw new Error('v106 live door leaves missing');
  Object.defineProperty(root,'v106DoorActuators',{value:leaves,configurable:true});
  window.metroV106InvalidTextureMaps=0;
  root.name='game-v106-four-car-consist';
  // Preserve the exact four original viewer layers. The game renders the
  // imported consist in the same calibrated multi-pass order as the viewer.
  // Forcing all meshes onto layer 0 destroys front-cab shading and finish.
  // Reuse the viewer's original calibrated light rig, including its distinct
  // front/cab layers. Do not substitute generic game lights for this model.
  const lighting=new THREE.Group();
  lighting.name='v106-original-viewer-lighting';
  for(const light of source.lighting)lighting.add(light);
  scene.add(lighting);
  Object.defineProperty(root,'v106Lighting',{value:lighting,configurable:true});
  root.visible=false;
  scene.add(root);
  const metrics={loadMs:Math.round(performance.now()-startedAt),meshCount:0,triangles:0,doorLeaves:leaves.length};
  root.traverse(o=>{if(o.isMesh){metrics.meshCount++;const g=o.geometry;if(g)metrics.triangles+=g.index?g.index.count/3:(g.attributes.position?.count||0)/3;}});
  window.metroV106Metrics=metrics;
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
