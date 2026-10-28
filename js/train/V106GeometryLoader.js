// Load the actual v106 geometry from its calibrated viewer into the gameplay
// THREE.Scene. No approximated meshes are constructed here.
export async function loadV106Geometry({THREE,scene,timeoutMs=30000}){
 if(!THREE?.ObjectLoader||!scene?.add)throw new TypeError('THREE and scene required');
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
  const serialized=frame.contentWindow.wagonExportConsist();
  const root=new THREE.ObjectLoader().parse(serialized);
  root.name='game-v106-four-car-consist';
  root.traverse(object=>{
   // The standalone viewer uses four special camera/render layers.
   // Game cameras use layer zero, so enable it on imported geometry.
   object.layers.enable(0);
  });
  root.visible=false;
  scene.add(root);
  return root;
 }finally{
  frame.src='about:blank';
  frame.remove();
 }
}
