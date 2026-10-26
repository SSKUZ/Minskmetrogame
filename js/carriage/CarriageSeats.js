export function buildCarriageSeats({THREE,carriage,box,side,z,carWhite,carSeat}){
  box(carriage,.76,.16,2.32,side*1.58,1.34,z,carWhite);
  for(let k=0;k<4;k++){
   const zz=z+(k-1.5)*.54;
   box(carriage,.63,.13,.49,side*1.57,1.46,zz,carSeat);
   box(carriage,.60,.014,.46,side*1.57,1.535,zz,new THREE.MeshStandardMaterial({color:0x343036,roughness:.88}));
   box(carriage,.13,.62,.49,side*1.94,1.79,zz,carSeat);
  }

}
