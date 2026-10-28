// Full interior, with genuine holes in the three-window front bulkhead.
export function buildCabShell(kit,cab){
 const {THREE,materials:m,mesh,shape,box,rounded,tube,label}=kit;
 const shell=new THREE.Group();shell.name='CabInteriorShell';cab.add(shell);
 const openings=[[-1.105,.35],[0,1.66],[1.105,.35]];
 const wall=shape(2.66,1.13,.15);
 for(const [x,w] of openings){const path=new THREE.Path(shape(w,.89,.065).getPoints(16).map(p=>new THREE.Vector2(p.x+x,p.y)));wall.holes.push(path);}
 const front=mesh(shell,new THREE.ExtrudeGeometry(wall,{depth:.044,bevelEnabled:false,curveSegments:12}),m.ivory,0,1.78,.38);
 front.name='ThreeWindowBulkhead';
 for(const [x,w] of openings){
  const gasket=shape(w+.028,.918,.078);gasket.holes.push(shape(w,.89,.065));
  mesh(shell,new THREE.ExtrudeGeometry(gasket,{depth:.014,bevelEnabled:false,curveSegments:12}),m.rubber,x,1.78,.422);
  const glass=mesh(shell,new THREE.ShapeGeometry(shape(w,.89,.065),12),m.windscreen,x,1.78,.419);glass.name='CabWindscreen';
 }
 box(shell,2.66,.48,.055,0,.98,.39,m.blue);
 rounded(shell,2.65,.045,.067,0,1.28,.43,m.edge,.015);
 // Side door skins, laminated upper trim, real side glazing and hinges.
 for(const side of [-1,1]){
  const g=new THREE.Group();g.position.set(side*1.335,0,1.60);g.rotation.y=-side*Math.PI/2;shell.add(g);
  rounded(g,2.38,1.12,.035,0,.59,0,m.blue,.025);
  rounded(g,2.38,.17,.043,0,2.17,0,m.ivory,.025);
  for(const x of [-1.18,-.49,1.18])rounded(g,.055,1.01,.044,x,1.67,0,m.ivory,.01);
  for(const [x,w] of [[-.835,.61],[.345,1.55]]){
   const frame=shape(w,.88,.06);frame.holes.push(shape(w-.045,.835,.05));
   mesh(g,new THREE.ExtrudeGeometry(frame,{depth:.018,bevelEnabled:false}),m.rubber,x,1.67,.022);
   mesh(g,new THREE.ShapeGeometry(shape(w-.045,.835,.05)),m.windscreen,x,1.67,.023);
  }
  rounded(g,2.4,.049,.065,0,1.20,.025,m.edge,.02);
  for(const y of [.48,1.22,1.93]){rounded(g,.025,.095,.022,-.47,y,.04,m.edge,.004);for(const dy of [-.029,.029])kit.cylinder(g,.003,.003,-.47,y+dy,.054,m.steel,undefined,8);}
  rounded(g,.11,.04,.025,-.73,.98,.045,m.steel,.009);
  tube(g,[[-.77,.98,.065],[-.77,.93,.095],[-.66,.93,.095],[-.66,.98,.065]],.008,m.steel,14);
  rounded(g,.17,.055,.003,-.81,.80,.025,m.casing,.003);label(g,'НЕ ПРИСЛОНЯТЬСЯ',-.81,.80,.155,.016,'#b9baad',.028);
 }
 // Ribbed floor and closed rear partition; nothing crosses the driver's eye path.
 box(shell,2.67,.055,3.21,0,.025,1.95,m.floor);
 const floorRibs=new THREE.InstancedMesh(new THREE.BoxGeometry(2.52,.0015,.0035),m.black,65),t=new THREE.Object3D();
 for(let i=0;i<65;i++){t.position.set(0,.054,.42+i*.048);t.updateMatrix();floorRibs.setMatrixAt(i,t.matrix);}shell.add(floorRibs);
 rounded(shell,2.67,2.25,.04,0,1.17,3.55,m.ivory,.035);
 const door=rounded(shell,.64,1.94,.032,.03,1.07,3.512,m.blue,.035);door.rotation.y=Math.PI;
 rounded(shell,.38,.46,.025,.03,1.60,3.48,m.rubber,.032);
 kit.cylinder(shell,.018,.06,-.20,.91,3.47,m.edge);
 box(shell,2.67,.055,3.2,0,2.31,1.95,m.ivory);
 for(const x of [-1.24,1.24])tube(shell,[[x,2.18,.47],[x,2.25,1.6],[x,2.25,3.4]],.025,m.ivory);
 // Seat and bolted pedestal, visible when looking back/down.
 kit.cylinder(shell,.13,.36,0,.25,2.52,m.casing).rotation.x=0;
 rounded(shell,.48,.09,.43,0,.49,2.52,m.seat,.05);
 const back=rounded(shell,.48,.52,.075,0,.79,2.72,m.seat,.065);back.rotation.x=-.10;
 return shell;
}
