const cache=new WeakMap();
export const inZone=(p,z)=>p.x>=z.minX-1e-8&&p.x<=z.maxX+1e-8&&p.z>=z.minZ-1e-8&&p.z<=z.maxZ+1e-8;
export function trainNavigationZones(layout,carId){
 let cars=cache.get(layout);if(!cars)cache.set(layout,cars=new Map());
 if(cars.has(carId))return cars.get(carId);
 const car=layout.car(carId),zones=[car.navigationZone,...(car.navigationZones??[])];
 if(!car.navigationZones){
  for(const d of layout.doors.filter(d=>d.car===carId))zones.push({minX:d.thresholdX+.02,maxX:car.aisleX+.1,minZ:d.z-(d.halfWidth??1.06)+.26,maxZ:d.z+(d.halfWidth??1.06)-.26});
  for(const s of car.seatAnchors)zones.push({minX:Math.min(car.aisleX,s.approach.x)-.02,maxX:Math.max(car.aisleX,s.approach.x)+.02,minZ:s.z-.29,maxZ:s.z+.29});
 }
 const bounds={minX:Math.min(...zones.map(z=>z.minX)),maxX:Math.max(...zones.map(z=>z.maxX)),minZ:Math.min(...zones.map(z=>z.minZ)),maxZ:Math.max(...zones.map(z=>z.maxZ))};
 const result={zones,bounds,contains:p=>zones.some(z=>inZone(p,z))};cars.set(carId,result);return result;
}
export function segmentInZones(from,to,region){
 const count=Math.max(1,Math.ceil(Math.hypot(to.x-from.x,to.z-from.z)/.08));let entered=region.contains(from);
 for(let n=1;n<=count;n++){const inside=region.contains({x:from.x+(to.x-from.x)*n/count,z:from.z+(to.z-from.z)*n/count});if(entered&&!inside)return false;if(inside)entered=true;}
 return entered;
}
