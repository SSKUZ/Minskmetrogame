// Pointer and touch routing is separate from camera dragging. No document-wide
// invisible buttons: picking uses rendered geometry and a bounded touch margin.
export function installCabInteraction({THREE,canvas,camera,cab,controls,commands,isActive,isRunning}){
 const ray=new THREE.Raycaster(),ndc=new THREE.Vector2(),v=new THREE.Vector3();let drag=null,hover=null;
 const hint=document.createElement('div');hint.id='cabControlHint';hint.setAttribute('role','status');document.body.append(hint);
 const ring=new THREE.Mesh(new THREE.TorusGeometry(.032,.0018,6,32),new THREE.MeshBasicMaterial({color:0xeacb69,depthTest:true}));ring.visible=false;cab.add(ring);
 function show(c,message){hint.textContent=message??c?.title??'';hint.classList.toggle('visible',!!hint.textContent);}
 function controlOf(o){while(o&&o!==cab){if(o.userData.control)return controls.get(o.userData.control);o=o.parent}return null}
 function pick(x,y,touch=false){
  cab.updateMatrixWorld(true);camera.updateMatrixWorld(true);const r=canvas.getBoundingClientRect();
  ndc.set((x-r.left)/r.width*2-1,1-(y-r.top)/r.height*2);ray.setFromCamera(ndc,camera);
  const hits=ray.intersectObject(cab,true).filter(h=>h.object!==ring&&h.object.material?.opacity>=.15);
  const direct=hits.length&&controlOf(hits[0].object);if(direct)return direct;
  let best=touch?25:10,result=null;
  for(const c of controls.values()){
   c.hit.getWorldPosition(v);const distance=camera.position.distanceTo(v);v.project(camera);
   if(v.z<-1||v.z>1||Math.abs(v.x)>1||Math.abs(v.y)>1)continue;
   const d=Math.hypot((v.x+1)*r.width/2+r.left-x,(1-v.y)*r.height/2+r.top-y);
   if(d<best&&(!hits.length||distance<=hits[0].distance+.12)){best=d;result=c;}
  }return result;
 }
 function highlight(c){
  if(hover===c)return;hover=c;ring.visible=!!c;
  if(c){c.group.add(ring);ring.position.set(0,0,.055);ring.rotation.set(0,0,0);show(c,c.enabled?c.title:c.title+' · не подключено');canvas.style.cursor=c.enabled?'pointer':'help';}
  else {show(null);canvas.style.cursor='';}
 }
 function down(e){
  if(e.target!==canvas||!isActive()||e.button>0)return;
  const c=pick(e.clientX,e.clientY,e.pointerType==='touch');if(!c)return;
  e.preventDefault();e.stopImmediatePropagation();highlight(c);
  if(!c.enabled){show(c,c.title+' · не подключено');return;}
  canvas.setPointerCapture(e.pointerId);drag={id:e.pointerId,c,y:e.clientY,value:commands.snapshot().lever,moved:false};c.target=1;
  if(c.kind!=='handle'&&c.kind!=='brake')commands.command(c.id);
 }
 function move(e){
  if(drag&&drag.id===e.pointerId){
   e.preventDefault();e.stopImmediatePropagation();const dy=e.clientY-drag.y;
   if(Math.abs(dy)>3)drag.moved=true;
   const travel=Math.min(220,canvas.clientHeight*.36);
   if(drag.c.kind==='handle'){const value=drag.value-dy/travel*2,step=value>0?.2:.25;commands.command('master',Math.round(value/step)*step);}
   if(drag.c.kind==='brake')commands.command('brake',Math.min(0,drag.value-dy/travel));
  }else if(e.target===canvas&&isActive()&&e.buttons===0)highlight(pick(e.clientX,e.clientY,e.pointerType==='touch'));
 }
 function up(e){
  if(!drag||drag.id!==e.pointerId)return;e.preventDefault();e.stopImmediatePropagation();
  const c=drag.c;c.target=0;
  if(c.id==='lampTest'||c.id==='horn')commands.command(c.id,undefined,'release');
  if(canvas.hasPointerCapture(e.pointerId))canvas.releasePointerCapture(e.pointerId);
  drag=null;if(e.pointerType==='touch')highlight(null);
 }
 document.addEventListener('pointerdown',down,true);document.addEventListener('pointermove',move,true);
 document.addEventListener('pointerup',up,true);document.addEventListener('pointercancel',up,true);
 const keymap={KeyO:'open',KeyP:'close',KeyD:'toggleDoors',KeyI:'info',KeyN:'release',KeyB:'service',Space:'emergency',KeyL:'cabLight',KeyF:'headlights',KeyH:'horn',KeyT:'lampTest',KeyC:'carriage',KeyV:'platform',Home:'forward',End:'desk'};
 function key(e,release=false){
  const id=keymap[e.code];
  // Release a held command even if its key-up occurs after changing cameras or
  // focusing an input. The horn and lamp test must never remain latched on.
  if(release){if(id==='horn'||id==='lampTest')commands.command(id,undefined,'release');return;}
  if(e.target.closest?.('input,textarea,select,[contenteditable="true"]')||!isRunning())return;
  if(!isActive()&&!['KeyC','KeyV','Home'].includes(e.code))return;
  if(e.code==='ArrowUp'||e.code==='KeyW'||e.code==='ArrowDown'||e.code==='KeyS'){
   e.preventDefault();commands.command('master',commands.snapshot().lever+(['ArrowUp','KeyW'].includes(e.code)?.2:-.2));
  }else if(/^Digit[1-5]$/.test(e.code)){e.preventDefault();commands.command('master',Number(e.code.slice(-1))*.2);}
  else if(id){e.preventDefault();if(!e.repeat)commands.command(id);}
 }
 const keyDown=e=>key(e),keyUp=e=>key(e,true);window.addEventListener('keydown',keyDown);window.addEventListener('keyup',keyUp);
 window.addEventListener('blur',()=>{commands.command('horn',undefined,'release');commands.command('lampTest',undefined,'release');if(drag){drag.c.target=0;drag=null;}});
 function projected(){
  const r=canvas.getBoundingClientRect();cab.updateMatrixWorld(true);camera.updateMatrixWorld(true);
  return [...controls.values()].map(c=>{c.hit.getWorldPosition(v);v.project(camera);return {id:c.id,enabled:c.enabled,kind:c.kind,title:c.title,x:r.left+(v.x+1)*r.width/2,y:r.top+(1-v.y)*r.height/2,inFrame:Math.abs(v.x)<=1&&Math.abs(v.y)<=1&&v.z>=-1&&v.z<=1};});
 }
 return {projected,pick,clear(){highlight(null)},show};
}
