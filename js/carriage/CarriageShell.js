export function buildCarriageShell({carriage,box,carFloor,carCream,carWhite,carSteel,carGlass}){
box(carriage,4.14,.12,23,0,.88,-9,carFloor);
// Floor edge strips and service access panels.
for(const side of [-1,1])box(carriage,.065,.012,22.65,side*1.97,.953,-9,carSteel);
for(let z=-.2;z>-19;z-=3.7){box(carriage,.72,.008,.85,0,.946,z,carCream);box(carriage,.74,.009,.022,0,.952,z+.43,carSteel);}

box(carriage,4.15,.12,23,0,3.65,-9,carCream);
// Longitudinal ceiling joints and ventilator grilles.
for(const side of [-1,1]){
 box(carriage,.045,.016,22.5,side*1.10,3.575,-9,carSteel);
 for(let z=0.8;z>-19.5;z-=3.4){
  box(carriage,.42,.014,.76,side*1.68,3.579,z,carSteel);
  for(let j=0;j<5;j++)box(carriage,.34,.018,.023,side*1.68,3.593,z-.29+j*.145,carBlackVent());
 }
}
function carBlackVent(){return carSteel;}

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
