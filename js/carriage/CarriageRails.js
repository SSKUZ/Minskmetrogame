export function buildCarriageRails({THREE,carriage,box,carSteel,carCream,carLight}){
function carriageRail(points,r=.025){const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(...p)));carriage.add(new THREE.Mesh(new THREE.TubeGeometry(curve,24,r,8,false),carSteel))}

for(const side of [-1,1]){
 for(let j=0;j<8;j++){
 const z=1.1-j*2.75;
 if(side===-1&&[-3.2,-13].some(d=>Math.abs(z-d)<2.20))continue;
  carriageRail([[side*1.18,1.03,z+1.18],[side*1.18,2.90,z+1.18],[side*1.27,3.22,z+.94],[side*1.52,3.40,z+.75]]);
  for(const edge of [-1,1])carriageRail([[side*1.16,1.34,z+edge*1.13],[side*1.16,1.75,z+edge*1.13],[side*1.65,1.82,z+edge*1.13]],.020);
 }
 carriageRail([[side*1.45,3.36,2.1],[side*1.45,3.36,-20.3]],.032);
 // Reference-style horizontal grab bar above the windows.
 carriageRail([[side*1.95,3.08,2.1],[side*1.95,3.08,-20.3]],.027);
 box(carriage,.24,.34,23,side*1.92,3.35,-9,carCream);

}
}
