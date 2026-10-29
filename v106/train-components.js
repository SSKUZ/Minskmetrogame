import * as T from 'three';

// Reusable classic 81-717/714 components. Coordinates: +Z points out of an
// inter-car end, Y is height, X is across the body. No modern sealed bellows.
export function roundedProfile(w,h,r){
 const s=new T.Shape(),x=-w/2,y=-h/2;
 s.moveTo(x+r,y);s.lineTo(x+w-r,y);s.quadraticCurveTo(x+w,y,x+w,y+r);
 s.lineTo(x+w,y+h-r);s.quadraticCurveTo(x+w,y+h,x+w-r,y+h);
 s.lineTo(x+r,y+h);s.quadraticCurveTo(x,y+h,x,y+h-r);
 s.lineTo(x,y+r);s.quadraticCurveTo(x,y,x+r,y);s.closePath();return s;
}
function hole(shape,w,h,r,x,y){
 const p=new T.Path(),pts=roundedProfile(w,h,r).getPoints(16);
 for(let i=pts.length-1;i>=0;i--){const v=pts[i];if(i===pts.length-1)p.moveTo(x+v.x,y+v.y);else p.lineTo(x+v.x,y+v.y)}p.closePath();shape.holes.push(p);
}
function toolsFor(root){
 const box=(w,h,d,x,y,z,material)=>{const o=new T.Mesh(new T.BoxGeometry(w,h,d),material);o.position.set(x,y,z);root.add(o);return o};
 const tube=(points,r,material,closed=false)=>{const curve=new T.CatmullRomCurve3(points.map(p=>new T.Vector3(...p)),closed);const o=new T.Mesh(new T.TubeGeometry(curve,Math.max(16,points.length*3),r,8,closed),material);root.add(o);return o};
 const ring=(w,h,r,x,y,z,material,thickness=.012)=>tube(roundedProfile(w,h,r).getPoints(16).map(p=>[p.x+x,p.y+y,z]),thickness,material,true);
 const panel=(shape,x,y,z,material,depth=0)=>{const o=new T.Mesh(depth?new T.ExtrudeGeometry(shape,{depth,bevelEnabled:false,curveSegments:16}):new T.ShapeGeometry(shape,16),material);o.position.set(x,y,z);root.add(o);return o};
 return {box,tube,ring,panel};
}

export function createAutomaticCoupling({floor=.95,materials:m,face=.40}={}){
 const root=new T.Group();root.name='automatic-intercar-coupling';root.userData.coupler=true;
 const {box,panel,tube}=toolsFor(root),y=floor-.11;
 box(.30,.19,.30,0,y,face-.23,m.cast);
 box(.46,.25,.08,0,y,face-.38,m.steel);
 const s=new T.Shape();s.moveTo(-.22,-.12);s.quadraticCurveTo(-.31,-.10,-.27,.01);s.lineTo(-.16,.15);s.quadraticCurveTo(-.10,.25,.01,.23);s.quadraticCurveTo(.12,.24,.16,.12);s.lineTo(.25,-.01);s.quadraticCurveTo(.31,-.12,.20,-.15);s.lineTo(-.22,-.12);
 for(const [x,yy,rx,ry] of [[-.085,-.015,.062,.066],[.083,-.008,.076,.078]]){const p=new T.Path();p.absellipse(x,yy,rx,ry,0,Math.PI*2,true);s.holes.push(p)}
 const casting=panel(s,0,y,face-.075,m.cast,.075);casting.userData.couplingContact=true;
 for(const x of [-.21,0,.21]){
  const bolt=new T.Mesh(new T.CylinderGeometry(.013,.013,.012,10),m.steel);bolt.rotation.x=Math.PI/2;bolt.position.set(x,y-.10,face+.003);root.add(bolt);
 }
 for(const side of [-1,1]){
  box(.09,.12,.10,side*.38,y-.015,face-.30,m.cast);
  tube([[side*.38,y,face-.26],[side*.40,y-.20,face-.19],[side*.28,y-.29,face-.03]],.024,m.rubber);
  box(.09,.022,.025,side*.38,y+.085,face-.25,m.valve);
 }
 root.userData.face=[0,y,face];return root;
}

export function createIntercarEnd({floor=.95,width=2.646,eave=3.155,materials:m}={}){
 const root=new T.Group();root.name='classic-intercar-end';root.userData.intercarEnd=true;
 const {box,tube,ring,panel}=toolsFor(root),low=floor-.018,high=eave,h=high-low,cy=(low+high)/2;
 const skin=roundedProfile(width,h,.09);
 hole(skin,.77,1.98,.08,0,floor+.99-cy);
 for(const x of [-.85,.85])hole(skin,.60,1.02,.10,x,2.46-cy);
 panel(skin,0,cy,-.085,m.paint,.085);
 panel(skin,0,cy,-.087,m.lining);
 // Three real glazed openings: two fixed end panes and the hinged centre leaf.
 for(const x of [-.85,.85]){
  panel(roundedProfile(.574,.994,.09),x,2.46,-.042,m.glass);
  ring(.61,1.03,.105,x,2.46,.003,m.rubber,.016);
  ring(.58,1.00,.093,x,2.46,.009,m.steel,.005);
 }
 const leaf=roundedProfile(.735,1.935,.065);hole(leaf,.46,.76,.09,0,.50);
 panel(leaf,0,floor+.9875,-.044,m.paint,.030);
 panel(leaf,0,floor+.9875,-.046,m.lining);
 panel(roundedProfile(.444,.744,.084),0,floor+1.4875,-.028,m.glass);
 ring(.775,1.985,.085,0,floor+.99,.002,m.rubber,.012);
 ring(.47,.77,.095,0,floor+1.4875,-.010,m.rubber,.011);
 ring(.74,1.94,.07,0,floor+.9875,-.010,m.steel,.006);
 for(const y of [floor+.30,floor+1.58])box(.030,.11,.045,-.369,y,.012,m.steel);
 box(.028,.11,.022,.273,floor+.98,.015,m.steel);
 tube([[.27,floor+1.01,.025],[.27,floor+1.01,.065],[.19,floor+1.01,.065]],.010,m.steel);
 // Recessed belt and pressed lower ribs continue the existing side livery.
 for(const side of [-1,1]){
  const cx=side*(width/2+.395)/2,w=width/2-.395;
  box(w,.105,.003,cx,floor+.94,.002,m.cream);
  for(const center of [.18,.40,.62,.84]){
   const vs=[],ix=[],x0=side<0?-width/2:.395,x1=side<0?-.395:width/2;
   for(let j=0;j<=12;j++){const u=j/12,yy=floor+center-.029+.058*u,z=.0004+.009*Math.pow(Math.sin(Math.PI*u),2);vs.push(x0,yy,z,x1,yy,z)}
   for(let j=0;j<12;j++){const k=j*2;ix.push(k,k+1,k+2,k+1,k+3,k+2)}
   const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(vs,3));g.setIndex(ix);g.computeVertexNormals();root.add(new T.Mesh(g,m.paint));
  }
  tube([[side*.48,floor+.16,.035],[side*.48,floor+.26,.10],[side*.48,floor+1.87,.10],[side*.48,floor+1.97,.035]],.017,m.steel);
  box(.15,.18,.070,side*1.12,floor+.22,.045,m.rubber);
 }
 box(.79,.035,.23,0,floor-.007,.095,m.steel);
 box(width-.10,.12,.11,0,floor-.12,-.015,m.cast);
 const coupling=createAutomaticCoupling({floor,materials:m});root.add(coupling);
 root.traverse(o=>{if(o.isMesh)o.layers.set(2)});
 root.userData.glazedOpenings=3;root.userData.doorClearWidth=.735;root.userData.couplingFace=.40;
 return root;
}

export function createIntercarConnection({floor=.95,gap=.80,materials:m}={}){
 const root=new T.Group();root.name='intercar-air-and-electric-connections';
 const {box,tube}=toolsFor(root);
 // Each car already owns a coupling half and two air-hose loops. Join their
 // actual free terminals; do not draw a second full coupling over the first.
 for(const side of [-1,1]){
  const connector=new T.Mesh(new T.CylinderGeometry(.031,.031,.060,12),m.steel);
  connector.rotation.x=Math.PI/2;connector.position.set(side*.28,floor-.40,0);root.add(connector);
 }
 tube([[.55,floor-.17,-gap/2+.07],[.55,floor-.35,-.19],[.55,floor-.54,0],[.55,floor-.35,.19],[.55,floor-.17,gap/2-.07]],.020,m.rubber);
 for(const z of [-gap/2+.07,gap/2-.07])box(.065,.085,.045,.55,floor-.17,z,m.cast);
 root.traverse(o=>{if(o.isMesh)o.layers.set(2)});root.userData.connection=true;return root;
}
