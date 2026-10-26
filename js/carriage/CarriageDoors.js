// Door geometry only; animation remains in TrainDoors.js.
export function buildCarriageDoors({THREE,carriage,box,carSteel,carDoor,carCream,carGlass}){
const carSlidingDoorLeaves=[];
// Boarding doors are on the platform side (-X) only for this route.
for(const side of [-1])for(const dz of [-3.2,-13]){
 for(const edge of [-1,1])box(carriage,.06,2.20,.075,side*2.01,2.08,dz+edge*1.02,carSteel);
 box(carriage,.06,.075,2.10,side*2.01,3.21,dz,carSteel);
 for(const half of [-1,1]){
  const leaf=new THREE.Group();carriage.add(leaf);
  box(leaf,.07,.66,.97,side*2.01,1.37,0,carDoor);
  // Aluminium edging and inset lower-panel relief on each sliding leaf.
  box(leaf,.014,.55,.80,side*1.96,1.39,0,carCream);
  for(const edgeZ of [-.46,.46])box(leaf,.085,2.13,.028,side*2.01,2.11,edgeZ,carSteel);
  box(leaf,.07,.49,.97,side*2.01,2.96,0,carDoor);
  box(leaf,.07,.90,.075,side*2.01,2.28,half*.45,carDoor);
  box(leaf,.018,.84,.83,side*2.00,2.28,0,carGlass);
  for(const y of [1.86,2.70])box(leaf,.024,.025,.85,side*1.975,y,0,carSteel);
  for(const z of [-.41,.41])box(leaf,.024,.83,.026,side*1.975,2.28,z,carSteel);
  box(leaf,.022,.13,.13,side*1.96,1.71,half*.32,carSteel);
  const leafZ=dz+half*.51;leaf.position.z=leafZ;carSlidingDoorLeaves.push({leaf,leafZ,half});
 }
}

return carSlidingDoorLeaves;
}
