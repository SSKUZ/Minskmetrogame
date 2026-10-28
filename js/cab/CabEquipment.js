export function buildCabEquipment(kit,cab,controls){
 const {THREE,materials:m,box,rounded,cylinder,ring,panel,label,tube,mesh}=kit;
 // Upright radio console and separately modelled handset with earpieces.
 const radio=new THREE.Group();radio.position.set(-1.14,1.36,1.035);radio.rotation.y=.12;radio.rotation.x=-.08;cab.add(radio);radio.name='RadioConsole';
 rounded(radio,.354,.565,.081,0,0,-.015,m.black,.022);
 const face=panel(radio,.318,.523,0,0,.032,m.casing);
 const holes=[];for(let row=-4;row<=4;row++)for(let col=-4;col<=4;col++)if(row*row+col*col<=18)holes.push([col,row]);
 const speaker=new THREE.InstancedMesh(new THREE.CylinderGeometry(.0019,.0019,.002,6),m.black,holes.length),t=new THREE.Object3D();
 holes.forEach(([col,row],n)=>{t.position.set(.029+col*.0095,.175+row*.0095,.015);t.rotation.x=Math.PI/2;t.updateMatrix();speaker.setMatrixAt(n,t.matrix);});face.add(speaker);
 controls.rotary(face,'volume',.105,.153,'ГРОМКОСТЬ',{title:'Громкость игровых звуков'});
 const keys=[['info','ВЫЗОВ/INFO',true],['radioTalk','СВЯЗЬ',false],['radioReset','СБРОС',false],['radioCall','ВЫЗОВ',false],['radioLine','СВЯЗЬ',false],['radioClear','СБРОС',false],['radioPgs','ПГС',false],['radioDsp','ДСП',false],['radioReserve','РЕЗЕРВ',false]];
 keys.forEach(([id,text,enabled],i)=>controls.square(face,id,-.038+i%3*.076,.012-Math.floor(i/3)*.086,text,{enabled,title:enabled?'Информатор станции · I':'Радиосвязь · система не моделируется'}));
 const handset=new THREE.Group();handset.position.set(-.143,.015,.07);radio.add(handset);
 rounded(handset,.048,.364,.039,0,0,0,m.black,.020);
 for(const y of [-.145,.145])rounded(handset,.068,.078,.063,0,y,.005,m.black,.025);
 for(const y of [-.145,.145]){
  rounded(radio,.071,.018,.022,-.143,y+.015,.044,m.edge,.004);
  for(const dx of [-.012,0,.012])for(const dy of [-.015,0,.015])cylinder(handset,.0018,.001,dx,y+dy,.038,m.rubber,undefined,6);
 }
 box(handset,.001,.23,.001,.020,0,.021,m.rubber);
 const coil=[];for(let i=0;i<=180;i++){const a=i/180*Math.PI*32;coil.push([-.143+Math.cos(a)*.014,-.197-i/180*.23,.035+Math.sin(a)*.014]);}
 tube(radio,coil,.003,m.black,200);tube(radio,[[-.14,-.425,.034],[-.08,-.49,.02],[.06,-.49,-.02],[.11,-.34,0]],.005,m.black,25);
 // CCTV housing. Its video is the existing live rear camera, never a static picture.
 const cctv=new THREE.Group();cctv.position.set(1.20,1.58,1.30);cctv.scale.setScalar(.78);cctv.rotation.y=-.35;cab.add(cctv);cctv.name='CabCCTV';
 rounded(cctv,.356,.370,.066,0,.085,0,m.black,.018);
 rounded(cctv,.319,.326,.005,0,.085,.037,m.edge,.008);
 const video=mesh(cctv,new THREE.PlaneGeometry(.286,.290),new THREE.MeshBasicMaterial({color:0x23312b}),0,.085,.042);video.name='LiveRearMonitor';
 mesh(cctv,new THREE.PlaneGeometry(.286,.290),m.glass,0,.085,.043);
 const monitorRim=new THREE.Group();monitorRim.position.set(0,.085,.037);cctv.add(monitorRim);kit.screws(monitorRim,.344,.358,.007);
 const uv=video.geometry.attributes.uv;for(let i=0;i<uv.count;i++)uv.setY(i,.2105+uv.getY(i)*.579);
 const select=panel(cctv,.356,.184,0,-.203,.005);
 label(select,'ВИДЕОКАМЕРЫ',0,.058,.25,.023);
 for(const [id,x,text,title] of [['carriage',-.11,'САЛОН','Камера пассажирского салона'],['platform',0,'ПЛАТФ.','Камера платформы · доступна у станции'],['forward',.11,'ПУТЬ','Взгляд вперёд']]){
  controls.square(select,id,x,-.022,text,{title,labelColor:'#1d221b'});
 }
 tube(cab,[[1.10,1.20,1.0],[1.17,1.12,.99],[1.17,.93,1.05]],.010,m.black,22);
 // Lower left auxiliary panel, oriented like the main sloped deck.
 const aux=new THREE.Group();aux.position.set(-1.145,.845,1.89);aux.rotation.x=-1.10;aux.rotation.z=-.12;cab.add(aux);
 const mirror=panel(aux,.27,.18,0,.09);label(mirror,'ЗЕРКАЛА',0,.064,.18,.020);
 controls.rotary(mirror,'mirrorLeft',-.067,-.020,'ЛЕВОЕ',{title:'Левое зеркало · показ отражения'});
 controls.rotary(mirror,'mirrorRight',.067,-.020,'ПРАВОЕ',{title:'Правое зеркало · показ отражения'});
 const heat=panel(aux,.27,.17,0,-.092);label(heat,'ОБОГРЕВ',0,.058,.18,.020);
 controls.rotary(heat,'heatLeft',-.067,-.023,'ЛЕВОЕ',{enabled:false,title:'Обогрев не моделируется'});
 controls.rotary(heat,'heatRight',.067,-.023,'ПРАВОЕ',{enabled:false,title:'Обогрев не моделируется'});
 // Mechanical windshield arms, parked at the bottom edge of the glass.
 const wipers=[];
 for(const x of [-.68,.68]){
  const pivot=new THREE.Group();pivot.userData.cabDynamic=true;pivot.position.set(x,1.365,.457);cab.add(pivot);
  cylinder(pivot,.011,.013,0,0,0,m.edge);
  const arm=box(pivot,.007,.39,.008,.12,.16,.012,m.black);arm.rotation.z=-.6;
  const blade=box(pivot,.011,.29,.012,.221,.341,.018,m.rubber);blade.rotation.z=-.22;
  wipers.push(pivot);
 }
 return {radio,cctv,video,wipers};
}
