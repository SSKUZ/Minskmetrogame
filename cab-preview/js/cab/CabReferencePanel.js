// Reference-approved 81-717 inspired panel layout, revision 1.
// Visual reference is concept art; all legends and controls require later prototype verification.
// Interactive controls are mounted separately by CabControls3D.
export function buildReferenceCabPanel({THREE,instrumentDeck}){
 const g=new THREE.Group();g.name='Reference81_717_Panel';instrumentDeck.add(g);
 const metal=new THREE.MeshStandardMaterial({color:0x96938c,metalness:.62,roughness:.57});
 const black=new THREE.MeshStandardMaterial({color:0x202426,metalness:.20,roughness:.78});
 const ivory=new THREE.MeshStandardMaterial({color:0xd7d4c8,roughness:.8});
 const green=new THREE.MeshStandardMaterial({color:0x278c49,roughness:.35});
 const red=new THREE.MeshStandardMaterial({color:0xb33730,roughness:.35});
 const amber=new THREE.MeshBasicMaterial({color:0xd2a43c});
 function block(w,d,x,z,m=metal,y=.082,h=.022){
  const o=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),m);o.position.set(x,y,z);g.add(o);return o;
 }
 function disc(x,z,r,material,y=.125){
  const o=new THREE.Mesh(new THREE.CylinderGeometry(r,r,.03,32),material);o.position.set(x,y,z);g.add(o);return o;
 }
 function label(text,x,z,w=.6){
  const c=document.createElement('canvas');c.width=512;c.height=128;
  const ctx=c.getContext('2d');ctx.clearRect(0,0,512,128);ctx.fillStyle='#171b1d';ctx.font='bold 37px Arial';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(text,256,64,500);
  const t=new THREE.Mesh(new THREE.PlaneGeometry(w,.13),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(c),transparent:true,depthWrite:false,side:THREE.DoubleSide}));
  t.rotation.x=-Math.PI/2;t.position.set(x,.104,z);g.add(t);
 }
 // Individual screwed-down silver service panels, rather than a random grid.
 for(const [x,w] of [[-2.20,1.36],[-.72,1.38],[.68,1.30],[2.06,1.32]]){
  block(w,1.18,x,.19);
  for(const dx of [-w/2+.09,w/2-.09])for(const dz of [-.32,.7])disc(x+dx,dz,.018,black,.104);
 }
 // Lighting and windscreen wiper rotary selectors.
 for(const [x,z,t] of [[-2.55,-.12,'СВЕТ'],[-1.96,-.12,'КАБИНА'],[-1.12,-.12,'СТЕКЛО'],[-.58,-.12,'ДВОРНИК']]){
  disc(x,z,.145,black);block(.038,.23,x,z,metal,.159,.044);label(t,x,z+.28,.48);
 }
 // Reference-style check, reset, control row.
 for(const [x,m,t] of [[-.12,ivory,'ПРОВЕРКА'],[.37,red,'СБРОС'],[.86,black,'КОНТРОЛЬ']]){
  disc(x,-.16,.127,black);disc(x,-.16,.089,m,.158);label(t,x,.10,.52);
 }
 // Door section: decorative buttons only; live buttons are overlaid by caller.
 label('ДВЕРИ',1.63,-.35,.58);
 label('ОТКР',1.45,.13,.48);
 label('ЗАКР',2.06,.13,.48);
 // Brake selectors and emergency pushbutton.
 for(const [x,z,t] of [[1.28,.53,'КРАН 1'],[1.83,.53,'КРАН 2'],[2.40,.53,'ЭПТ']]){
  disc(x,z,.12,black);block(.036,.18,x,z,metal,.159,.05);label(t,x,z+.20,.47);
 }
 disc(2.54,-.17,.13,black);disc(2.54,-.17,.085,red,.162);label('СТОП',2.54,.10,.4);
 // Tactile inset strips, screws and warm pilot lamps.
 block(5.76,.035,0,-.58,black,.099,.013);
 for(let i=0;i<6;i++)disc(-2.68+i*.14,.54,.034,i%2?amber:green,.119);
 return g;
}
