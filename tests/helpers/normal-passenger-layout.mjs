import {createPassengerLayout,createTestPassengerLayout} from '../../js/passengers/PassengerLayout.js';

// Contract-only fixture for the future four-car service, not V106 integration.
// Four offsets/width come from preview/wagon.html; no scene geometry is changed.
export function normalPassengerLayout(){
 const base=createTestPassengerLayout({carCount:4});
 const doors=base.cars.flatMap(car=>[-6.30,-1.85,2.55,7.00].map((offset,i)=>{
  const template=base.doors.find(d=>d.car===car.id),z=car.centerZ+offset;
  return {...template,id:car.id*4+i,z,halfWidth:1.38/2,edge:false,
   initialStanding:[{x:car.aisleX-.71,z:z-1.3},{x:car.aisleX+.71,z:z+1.3}],fallback:{x:car.aisleX+.71,z:z+1.6}};
 }));
 const cars=base.cars.map(car=>{
  const own=doors.filter(d=>d.car===car.id),seatAnchors=[];
  for(const side of [-1,1])for(let n=0;n<27;n++){
   const z=car.centerZ-8.5+n*.66;
   if(own.some(d=>Math.abs(d.z-z)<1.35))continue;
   const x=car.aisleX+side*1.4;
   seatAnchors.push({id:`flow-${car.id}-${side}-${n}`,x,z,heading:side<0?Math.PI/2:-Math.PI/2,hipHeight:.53,approach:{x:x-side*.43,z}});
  }
  const standingZones=own.flatMap(d=>[-1,1].flatMap(side=>[-.65,0,.65].map(offset=>({x:car.aisleX+side*.71,z:d.z+offset}))));
  return {...car,seatAnchors,standingZones};
 });
 return createPassengerLayout({...base,doors,cars});
}
