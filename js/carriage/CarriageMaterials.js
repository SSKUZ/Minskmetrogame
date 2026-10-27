export function createCarriageMaterials(THREE){
const carCream=new THREE.MeshStandardMaterial({color:0xe1e4e3,roughness:.65});
const carWhite=new THREE.MeshStandardMaterial({color:0xf8f8f5,roughness:.5});
const carFloor=new THREE.MeshStandardMaterial({color:0x71767c,roughness:.91});
const carSeat=new THREE.MeshStandardMaterial({color:0x44383b,roughness:.87});
const carSteel=new THREE.MeshStandardMaterial({color:0xb4bdc2,metalness:.68,roughness:.29});
const carBlack=new THREE.MeshStandardMaterial({color:0x222c34,roughness:.86});
const carDoor=new THREE.MeshStandardMaterial({color:0xe0e2e2,roughness:.5});
const carGlass=new THREE.MeshPhysicalMaterial({color:0x5088ad,transparent:true,opacity:.16,roughness:.10,depthWrite:false,side:THREE.DoubleSide});
const carLight=new THREE.MeshBasicMaterial({color:0xfffdf1});

return {carCream,carWhite,carFloor,carSeat,carSteel,carBlack,carDoor,carGlass,carLight};
}
