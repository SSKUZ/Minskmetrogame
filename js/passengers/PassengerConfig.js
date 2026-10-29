export const PASSENGER_ASSETS = new URL('../../assets/passengers/', import.meta.url);
export const PROFILES = [
 'man-jacket','woman-coat','man-hoodie','woman-skirt','elder-man','elder-woman',
 'boy','girl','man-casual','woman-longhair','man-shirt','woman-suit',
];
export const DOORS = Array.from({length:10}, (_,i)=>({
 id:i, car:Math.floor(i/2), z:-100+12+Math.floor(i/2)*21.5+(i%2?5.25:-5.25),
}));
export const PLATFORM = Object.freeze({minX:-20.3,maxX:-3.45,minZ:-115,maxZ:3.5,y:.78});
export const TRAIN = Object.freeze({offsetZ:112,thresholdX:-2.50,floorY:1.135,aisleX:-.31});
export const COLUMNS = Array.from({length:13},(_,i)=>({x:-5.65,z:5-i*10,radius:.79}));
export const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
export function randomSource(seed){
 let n=seed>>>0;
 return ()=>{n+=0x6D2B79F5;let t=Math.imul(n^n>>>15,1|n);t^=t+Math.imul(t^t>>>7,61|t);return ((t^t>>>14)>>>0)/4294967296;};
}
export const turnDelta=(a,b)=>Math.atan2(Math.sin(b-a),Math.cos(b-a));
export function trainSeatPositions(car){
 const center=-88+car*21.5,seats=[];
 for(const sx of [-1,1])for(let bench=0;bench<7;bench++)for(const half of [-1,1]){
  const z=center-8.2+bench*2.65+half*.33;
  if(DOORS.some(d=>d.car===car&&Math.abs(d.z-z)<1.35))continue;
  seats.push({x:sx*1.4-.31,z});
 }
 return seats;
}
