export function buildCarriageSeats({THREE,carriage,box,side,z,carWhite,carSeat}){
  box(carriage,.76,.16,2.32,side*1.58,1.34,z,carWhite);
  const metal=new THREE.MeshStandardMaterial({color:0x999fa2,metalness:.52,roughness:.38});
  box(carriage,.68,.24,2.25,side*1.63,1.12,z,carWhite);
  const upholsteryEdge=new THREE.MeshStandardMaterial({color:0x211f23,roughness:.96});
  for(let k=0;k<4;k++){
   const zz=z+(k-1.5)*.54;
   box(carriage,.63,.13,.49,side*1.57,1.46,zz,carSeat);
   box(carriage,.60,.014,.46,side*1.57,1.535,zz,new THREE.MeshStandardMaterial({color:0x343036,roughness:.88}));
   box(carriage,.13,.62,.49,side*1.94,1.79,zz,carSeat);
   box(carriage,.016,.56,.012,side*1.855,1.78,zz+.235,upholsteryEdge);
   box(carriage,.54,.014,.018,side*1.56,1.532,zz+.235,upholsteryEdge);
   box(carriage,.13,.025,.49,side*1.94,2.11,zz,metal);
  }
  for(const edge of [-1,1])box(carriage,.06,.48,.05,side*1.92,1.76,z+edge*1.18,metal);

}
