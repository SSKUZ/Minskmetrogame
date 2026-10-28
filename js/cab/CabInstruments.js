export function createCabInstruments(kit){
 const {THREE,materials:m,box,cylinder,ring,rounded,label,mesh}=kit;
 function gauge(parent,x,y,unit,max){
  const g=new THREE.Group();g.name=`Gauge_${unit}`;g.position.set(x,y,.017);parent.add(g);
  cylinder(g,.135,.043,0,0,0,m.black);cylinder(g,.129,.026,0,0,.022,m.edge);
  ring(g,.122,.008,0,0,.039,m.steel);ring(g,.113,.0035,0,0,.041,m.black);
  const c=document.createElement('canvas');c.width=c.height=768;const q=c.getContext('2d');
  q.fillStyle='#d4ccae';q.beginPath();q.arc(384,384,380,0,Math.PI*2);q.fill();
  q.fillStyle='#272821';q.strokeStyle='#38382e';q.textAlign='center';q.textBaseline='middle';
  for(let i=0;i<=60;i++){
   const a=.75*Math.PI+i/60*Math.PI*1.5,major=i%10===0,inner=major?292:i%5===0?308:326;
   q.lineWidth=major?4:1.7;q.beginPath();q.moveTo(384+Math.cos(a)*inner,384+Math.sin(a)*inner);q.lineTo(384+Math.cos(a)*349,384+Math.sin(a)*349);q.stroke();
   if(major){q.font='33px Arial';const value=max*i/60;q.fillText(value===0?'0':value.toFixed(2).replace(/0$/,''),384+Math.cos(a)*250,384+Math.sin(a)*250);}
  }
  q.font='bold 46px Arial';q.fillText(unit,384,540);q.font='18px Arial';q.fillText('ЭЛЕКТРОИЗМЕРИТЕЛЬ',384,602);
  q.fillStyle='#893d26';q.font='bold 26px Arial';q.fillText('НЕТ ДАННЫХ',384,667);
  const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=4;
  mesh(g,new THREE.CircleGeometry(.112,64),new THREE.MeshBasicMaterial({map:tex}),0,0,.041);
  const pivot=new THREE.Group();pivot.position.z=.046;g.add(pivot);
  const s=new THREE.Shape();s.moveTo(-.027,-.003);s.lineTo(.087,-.0013);s.lineTo(.087,.0013);s.lineTo(-.027,.003);s.closePath();
  mesh(pivot,new THREE.ExtrudeGeometry(s,{depth:.0015,bevelEnabled:false}),m.black);
  pivot.rotation.z=-Math.PI*.75;cylinder(g,.008,.005,0,0,.05,m.black);
  mesh(g,new THREE.CircleGeometry(.112,48),m.glass,0,0,.057);
  g.userData={connected:false,unit,reason:'Электрическая модель отсутствует'};return g;
 }
 const bits=[0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f];
 function speedDisplay(parent,x,y){
  const g=new THREE.Group();g.userData.cabDynamic=true;g.position.set(x,y,.02);parent.add(g);
  rounded(g,.234,.152,.017,0,0,0,m.black,.004);
  const digits=[];
  for(let d=0;d<2;d++){
   const segments=[];const ox=(d-.5)*.073;
   for(const [sx,sy,angle] of [[0,.044,0],[.027,.023,Math.PI/2],[.027,-.023,Math.PI/2],[0,-.044,0],[-.027,-.023,Math.PI/2],[-.027,.023,Math.PI/2],[0,0,0]]){
    const o=rounded(g,.047,.007,.001,ox+sx,sy,.011,new THREE.MeshBasicMaterial({color:0x182510,toneMapped:false}),.003);o.rotation.z=angle;segments.push(o);
   }digits.push(segments);
  }
  label(g,'КМ/Ч',0,-.103,.09,.024,'#d5d2bd',.013);
  let last=-1;
  return {group:g,update(speed,lampTest=false){const n=Math.min(99,Math.max(0,Math.round(speed)));if(n===last&&!lampTest)return;last=lampTest?-1:n;
   for(let d=0;d<2;d++){const v=lampTest?8:d===0?Math.floor(n/10):n%10;digits[d].forEach((s,i)=>s.material.color.setHex(bits[v]&(1<<i)?0xa7df22:0x192315));}
  }};
 }
 function pilot(parent,x,y,color,text){
  const g=new THREE.Group();g.position.set(x,y,.023);parent.add(g);
  rounded(g,.039,.039,.012,0,0,0,m.black,.003);
  const lens=rounded(g,.026,.026,.009,0,0,.008,new THREE.MeshStandardMaterial({color,emissive:color,emissiveIntensity:.08,roughness:.3}),.002);
  if(text)label(g,text,0,-.037,.059,.015,'#c7c3ad',.01);
  return {set(on){lens.material.emissiveIntensity=on?.9:.025;lens.material.color.setHex(on?color:0x242924)}};
 }
 return {gauge,speedDisplay,pilot};
}
