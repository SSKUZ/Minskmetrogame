// Physical controls and their animation, independent of the simulation.
export function createCabControls(kit){
 const {THREE,materials:m,cylinder,ring,rounded,box,label,mesh}=kit;
 const controls=new Map();
 function register(id,group,hit,kind,title,enabled=true){
  if(controls.has(id))throw new Error('Duplicate cab control '+id);
  const control={id,group,hit,kind,title,enabled,press:0,target:0,value:0};
  group.name='Control_'+id;group.userData.control=id;hit.userData.control=id;hit.userData.cabDynamic=true;controls.set(id,control);return control;
 }
 function button(parent,id,x,y,text,color=m.black,options={}){
  const g=new THREE.Group();g.position.set(x,y,.019);parent.add(g);
  cylinder(g,.026,.014,0,0,0,m.black);ring(g,.023,.003,0,0,.009,m.steel);
  const capProfile=[[0,-.005],[.019,-.005],[.020,0],[.019,.005],[.015,.008],[0,.009]].map(p=>new THREE.Vector2(...p));
  const cap=mesh(g,kit.geometry('pushbutton-cap',()=>new THREE.LatheGeometry(capProfile,32)),color,0,0,.015);cap.rotation.x=Math.PI/2;
  label(g,text,0,.044,options.labelWidth??.105,.017,'#181a16',.015);
  const c=register(id,g,cap,'button',options.title??text,options.enabled!==false);c.cap=cap;c.baseZ=.015;return c;
 }
 function rotary(parent,id,x,y,text,options={}){
  const g=new THREE.Group();g.position.set(x,y,.018);parent.add(g);
  cylinder(g,.029,.007,0,0,0,m.edge);cylinder(g,.025,.013,0,0,.009,m.black,.028);
  const knob=new THREE.Group();knob.userData.cabDynamic=true;knob.position.z=.017;g.add(knob);
  const profile=[[.009,0],[.017,.002],[.021,.008],[.018,.020],[.012,.029]].map(p=>new THREE.Vector2(p[0],p[1]));
  const grip=mesh(knob,new THREE.LatheGeometry(profile,20),m.black);grip.rotation.x=Math.PI/2;grip.position.z=.03;
  rounded(knob,.013,.047,.010,0,0,.058,m.black,.005);box(knob,.002,.020,.001,0,.008,.064,m.ivory);
  for(const a of [-.8,0,.8]){const tick=box(g,.001,.004,.001,Math.sin(a)*.034,Math.cos(a)*.034,.007,m.black);tick.rotation.z=-a;}
  label(g,text,0,.064,options.labelWidth??.13,.017,'#151713',.012);
  const c=register(id,g,grip,'rotary',options.title??text,options.enabled!==false);c.knob=knob;return c;
 }
 function square(parent,id,x,y,text,options={}){
  const g=new THREE.Group();g.position.set(x,y,.023);parent.add(g);
  rounded(g,.041,.032,.014,0,0,0,m.black,.002);
  const cap=rounded(g,.030,.023,.010,0,0,.01,m.white,.001);
  label(g,text,0,.028,.066,.012,options.labelColor??'#d3cdbb',.012);
  const c=register(id,g,cap,'button',options.title??text,options.enabled!==false);c.cap=cap;c.baseZ=.01;return c;
 }
 function controller(parent){
  const base=kit.panel(parent,.35,.51,-.13,-.22,.055,m.casing);base.name='MasterControllerHousing';
  rounded(base,.35,.51,.09,0,0,-.048,m.casing,.018);
  const gate=rounded(base,.042,.392,.014,.034,0,.021,m.black,.009);
  for(const x of [.001,.066])box(base,.007,.38,.011,x,0,.028,m.steel);
  const strip=kit.panel(base,.122,.448,.103,0,.014,m.ivory);
  for(let i=0;i<5;i++)label(strip,String(i+1),0,-.029+i*.05,.022,.021);
  label(strip,'ТЯГА',0,.202,.068,.018);label(strip,'ВЫБЕГ',0,-.079,.10,.018);label(strip,'ТОРМОЗ',0,-.158,.10,.018);
  const handle=new THREE.Group();handle.userData.cabDynamic=true;handle.position.set(.035,-.08,.05);base.add(handle);
  rounded(handle,.018,.183,.075,0,.062,.026,m.edge,.004);
  cylinder(handle,.018,.022,0,0,.031,m.black);
  const grip=cylinder(handle,.026,.46,-.215,.143,.079,m.black,.030);grip.rotation.set(0,0,Math.PI/2);
  for(const x of [-.435,.012]){const rim=ring(handle,.027,.002,x,.143,.079,m.steel);rim.rotation.y=Math.PI/2;}
  const c=register('master',handle,grip,'handle','Контроллер · потяните вверх: тяга; вниз: тормоз');c.handle=handle;c.slot=gate;return c;
 }
 function brakeValve(parent){
  const g=new THREE.Group();g.position.set(1.10,.90,1.74);parent.add(g);g.name='BrakeValve';
  // Cast lower valve body, flanges, bolts, graduated sleeve and wooden main handle.
  cylinder(g,.080,.25,0,.0,0,m.panel);g.children.at(-1).rotation.x=0;
  for(const y of [-.089,.072]){const o=ring(g,.080,.004,0,y,0,m.steel);o.rotation.x=Math.PI/2;}
  cylinder(g,.092,.026,0,.11,0,m.steel);g.children.at(-1).rotation.x=0;
  cylinder(g,.079,.025,0,-.12,0,m.steel);g.children.at(-1).rotation.x=0;
  for(let i=0;i<8;i++){const a=i*Math.PI/4;const o=cylinder(g,.004,.006,Math.sin(a)*.079,.127,Math.cos(a)*.079,m.black,undefined,8);o.rotation.x=0;}
  for(const x of [-.050,.050])for(const y of [-.050,.040]){
   const boss=cylinder(g,.010,.025,x,y,.068,m.steel,undefined,12);cylinder(g,.0045,.003,x,y,.082,m.black,undefined,6);
  }
  const graduated=new THREE.Group();graduated.position.set(0,.129,0);graduated.rotation.x=-Math.PI/2;g.add(graduated);
  for(let i=0;i<28;i++){const a=i/28*Math.PI*2;const tick=box(graduated,.0012,i%7===0?.010:.005,.0008,Math.cos(a)*.067,Math.sin(a)*.067,.003,m.black);tick.rotation.z=a-Math.PI/2;}
  for(let i=0;i<5;i++){const a=-Math.PI*.8+i*Math.PI*.3;label(graduated,['I','II','III','IV','V'][i],Math.cos(a)*.049,Math.sin(a)*.049,.015,.010,'#292a24',.004);}
  const handle=new THREE.Group();handle.userData.cabDynamic=true;handle.position.y=.14;g.add(handle);
  cylinder(handle,.028,.045,0,0,0,m.edge);handle.children.at(-1).rotation.x=0;
  const arm=box(handle,.126,.016,.023,-.062,0,0,m.steel);
  const grip=cylinder(handle,.018,.15,-.18,0,0,m.wood,.022);grip.rotation.set(0,0,Math.PI/2);
  for(const x of [-.252,-.108]){const collar=ring(handle,.018,.0015,x,0,0,m.edge);collar.rotation.y=Math.PI/2;}
  const c=register('brake',g,grip,'brake','Кран тормоза · потяните вниз: торможение');c.handle=handle;
  const plate=kit.panel(g,.176,.15,0,-.23,.06);label(plate,'КРАН ТОРМОЗНОЙ',0,.049,.16,.017);
  label(plate,'I   II   III   IV   V',0,.014,.145,.018);
  label(plate,'ИГРОВОЙ ТОРМОЗ',0,-.035,.16,.014,'#5e3824');
  cylinder(g,.028,.029,0,-.37,.065,m.steel);box(g,.095,.013,.014,-.045,-.37,.09,m.red);
  kit.tube(g,[[.04,-.12,-.02],[.06,-.35,-.04],[.10,-.58,-.03]],.016,m.rubber,12);
  return c;
 }
 function update(dt,state){
  const smooth=1-Math.exp(-Math.min(dt,.1)*18);
  for(const c of controls.values()){
   c.press+=(c.target-c.press)*smooth;
   if(c.cap)c.cap.position.z=c.baseZ-c.press*.005;
   if(c.knob)c.knob.rotation.z=-(c.value-.5)*1.5;
  }
  const master=controls.get('master');if(master){const notch=-.079+state.lever*(state.lever>0?.249:.079);master.handle.position.y+=(notch-master.handle.position.y)*smooth;}
  const brake=controls.get('brake');if(brake)brake.handle.rotation.y+=((-Math.max(0,-state.lever)*1.6)-brake.handle.rotation.y)*smooth;
 }
 return {controls,button,rotary,square,controller,brakeValve,update};
}
