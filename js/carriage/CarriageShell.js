export function buildCarriageShell({carriage,box,carFloor,carCream,carWhite,carSteel,carGlass}){
box(carriage,4.14,.12,23,0,.88,-9,carFloor);
box(carriage,4.15,.12,23,0,3.65,-9,carCream);
// Continuous illuminated ceiling panels, as in the reference metro car.
for(let z=1.2;z>-20;z-=2.0){box(carriage,.86,.026,1.75,0,3.565,z,carLight);box(carriage,.94,.028,1.8,0,3.584,z,carSteel)}

for(const side of [-1,1]){
 const wallRanges=side===-1?[[2.5,-2.15],[-4.25,-11.95],[-14.05,-20.5]]:[[2.5,-20.5]];
 for(const [front,back] of wallRanges){
  const length=front-back,center=(front+back)/2;
  box(carriage,.12,.88,length,side*2.07,1.40,center,carWhite);
  box(carriage,.12,.55,length,side*2.07,3.39,center,carWhite);
  box(carriage,.12,.09,length,side*2.07,1.94,center,carCream);
  box(carriage,.12,.09,length,side*2.07,3.08,center,carCream);
 }

}
for(let z=2;z>-20;z-=.33)box(carriage,2.35,.007,.014,0,3.58,z,carSteel);
for(let z=1.4;z>-20;z-=2.75)box(carriage,4.02,.045,.06,0,3.54,z,carCream);
box(carriage,4.04,2.70,.13,0,2.26,-20.43,carWhite);
box(carriage,1.17,2.25,.14,0,2.22,-20.32,carSteel);
box(carriage,1.03,2.13,.15,0,2.20,-20.23,carCream);
box(carriage,.49,.95,.018,0,2.48,-20.14,carGlass);

}
