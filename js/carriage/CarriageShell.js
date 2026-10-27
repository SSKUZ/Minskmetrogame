export function buildCarriageShell({THREE,carriage,box,carFloor,carCream,carWhite,carSteel,carGlass}){
box(carriage,4.14,.12,23,0,.88,-9,carFloor);
// Floor edge strips and service access panels.
for(const side of [-1,1])box(carriage,.065,.012,22.65,side*1.97,.953,-9,carSteel);
for(let z=-.2;z>-19;z-=3.7){box(carriage,.72,.008,.85,0,.946,z,carCream);box(carriage,.74,.009,.022,0,.952,z+.43,carSteel);}

// Profiled side coves replace the former flat, box-like ceiling silhouette.
box(carriage,2.70,.10,23,0,3.65,-9,carCream);
if(THREE){
 const profile=[[1.33,3.69],[1.52,3.66],[1.77,3.54],[1.97,3.32],[2.08,3.13]];
 for(const side of [-1,1]){
  const vertices=[],indices=[];
  for(let i=0;i<profile.length;i++){
   const [x,y]=profile[i];
   vertices.push(side*x,y,2.5,side*x,y,-20.5);
   if(i){const k=i*2;indices.push(k-2,k-1,k,k-1,k+1,k);}
  }
  const geometry=new THREE.BufferGeometry();
  geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  const panelMaterial=carCream.clone();
  panelMaterial.side=THREE.DoubleSide;
  const panel=new THREE.Mesh(geometry,panelMaterial);
  carriage.add(panel);
  for(let i=1;i<profile.length-1;i++){
   const [x,y]=profile[i];
   box(carriage,.035,.032,22.8,side*x,y,-9,carSteel);
  }
 }
}
// Longitudinal ceiling joints and ventilator grilles.
for(const side of [-1,1]){
 box(carriage,.045,.016,22.5,side*1.10,3.575,-9,carSteel);
 for(let z=0.8;z>-19.5;z-=3.4){
  box(carriage,.42,.014,.76,side*1.68,3.515,z,carSteel);
  for(let j=0;j<5;j++)box(carriage,.34,.018,.023,side*1.68,3.502,z-.29+j*.145,carSteel);
 }
}

for(const side of [-1,1]){
 const wallRanges=side===-1?[[2.5,-2.15],[-4.25,-11.95],[-14.05,-20.5]]:[[2.5,-20.5]];
 for(const [front,back] of wallRanges){
  const length=front-back,center=(front+back)/2;
  box(carriage,.12,.88,length,side*2.07,1.40,center,carWhite);
  // Structural side sill and recessed kick panel follow the body section.
  box(carriage,.14,.13,length,side*2.01,.99,center,carSteel);
  box(carriage,.065,.08,length,side*1.94,1.055,center,carCream);
  // Recessed lower sidewall: stepped kick panel instead of one planar slab.
  box(carriage,.045,.26,length,side*1.982,1.075,center,carCream);
  box(carriage,.042,.025,length,side*1.950,1.218,center,carSteel);
  box(carriage,.12,.55,length,side*2.07,3.39,center,carWhite);
  // Upper cant rail bridges the window header and curved roof shoulder.
  box(carriage,.16,.12,length,side*2.015,3.19,center,carCream);
  box(carriage,.12,.09,length,side*2.07,1.94,center,carCream);
  box(carriage,.12,.09,length,side*2.07,3.08,center,carCream);
  // Wall panel joints below the windows: visible from the passenger camera.
  for(let z=back+.55;z<front-.2;z+=2.75){
   box(carriage,.014,.81,.018,side*2.001,1.40,z,carSteel);
   box(carriage,.024,.055,.38,side*1.995,1.08,z+.25,carCream);
  }
 }

}
// Continuous underfloor longitudinal members give the body a visible depth.
for(const side of [-1,1]){
 box(carriage,.12,.17,22.8,side*1.73,.755,-9,carSteel);
 box(carriage,.07,.10,22.8,side*2.01,.835,-9,carCream);
}
for(let z=2;z>-20;z-=.33)box(carriage,2.35,.007,.014,0,3.58,z,carSteel);
for(let z=1.4;z>-20;z-=2.75)box(carriage,4.02,.045,.06,0,3.54,z,carCream);
box(carriage,4.04,2.70,.13,0,2.26,-20.43,carWhite);
box(carriage,1.17,2.25,.14,0,2.22,-20.32,carSteel);
box(carriage,1.03,2.13,.15,0,2.20,-20.23,carCream);
box(carriage,.49,.95,.018,0,2.48,-20.14,carGlass);

}
