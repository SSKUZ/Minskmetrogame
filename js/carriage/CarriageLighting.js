export function buildCarriageLighting({THREE,carriage,box,carLight,carSteel,carWhite}){
// Continuous illuminated ceiling panels, as in the reference metro car.
for(let z=1.2;z>-20;z-=2.0){box(carriage,.86,.026,1.75,0,3.565,z,carLight);box(carriage,.94,.028,1.8,0,3.584,z,carSteel)}

 for(const side of [-1,1]){
 box(carriage,.21,.05,21.9,side*1.52,3.54,-9,carSteel);
 box(carriage,.14,.025,21.6,side*1.52,3.51,-9,carLight);
}
box(carriage,1.93,.31,.17,0,3.10,-9,carWhite);
box(carriage,1.75,.18,.019,0,3.11,-8.90,new THREE.MeshBasicMaterial({color:0x24412a}));
// Warm lighting and repeated overhead information strips.
for(let z=.4;z>-20;z-=4.6){
 const panel=new THREE.MeshBasicMaterial({color:0x263348});
 box(carriage,.022,.24,1.85,-2.005,3.32,z,panel);
 box(carriage,.022,.24,1.85,2.005,3.32,z,panel);
}

}
