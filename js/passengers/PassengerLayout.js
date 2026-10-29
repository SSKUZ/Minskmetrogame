import {DOORS,TRAIN,PLATFORM,COLUMNS,trainSeatPositions} from './PassengerConfig.js';

// The simulation consumes this contract. Only this adapter knows the temporary
// carriage dimensions. A future V106 adapter supplies the same six anchor sets.
export function createPassengerLayout({train,platform,doors,cars,collisionZones=[],gripAnchors=[]}){
 const doorMap=new Map(doors.map(d=>[d.id,d])),carMap=new Map(cars.map(c=>[c.id,c]));
 const obstacleCache=new Map();
 if(!doors.length||doorMap.size!==doors.length||carMap.size!==cars.length)throw new Error('Passenger layout needs unique door/car IDs');
 const finitePoint=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.z);
 const validBounds=(b,z=true)=>b&&['minX','maxX',...(z?['minZ','maxZ']:[])].every(k=>Number.isFinite(b[k]))&&b.minX<b.maxX&&(!z||b.minZ<b.maxZ);
 if(!validBounds(platform)||!Number.isFinite(platform.y)||!Number.isFinite(train?.offsetZ)||!Number.isFinite(train.floorY))throw new Error('Invalid passenger coordinate frame');
 for(const door of doors){
  if(!carMap.has(door.car)||!finitePoint(door.fallback)||!Number.isFinite(door.z)||!['thresholdX','entryX','insideX','exitInnerX','exitOuterX','exitClearX','approachX','queueX','yieldBoundaryX','yieldX'].every(k=>Number.isFinite(door[k])))throw new Error('Invalid passenger door anchor '+door.id);
  // Current locomotion supports a platform on the negative X side. Reject an
  // unsupported adapter explicitly rather than silently routing through walls.
  if(!(door.approachX<door.thresholdX&&door.thresholdX<door.insideX))throw new Error('Unsupported passenger door orientation '+door.id);
 }
 for(const car of cars){
  if(!Number.isFinite(car.aisleX)||!validBounds(car.navigationZone)||!validBounds(car.bounds,false)||!car.standingZones.every(finitePoint)||!car.seatAnchors.every(s=>finitePoint(s)&&finitePoint(s.approach)&&Number.isFinite(s.heading)&&Number.isFinite(s.hipHeight)&&s.hipHeight>0))throw new Error('Invalid passenger car anchors '+car.id);
 }
 for(const zone of collisionZones)if(!finitePoint(zone)||!Number.isFinite(zone.radius)||zone.radius<=0||!['platform','train'].includes(zone.space)||(zone.car!==undefined&&!carMap.has(zone.car)))throw new Error('Invalid passenger collision zone');
 return {
  train,platform,doors,cars,collisionZones,gripAnchors,
  door(id){const d=doorMap.get(id);if(!d)throw new Error('Unknown passenger door '+id);return d;},
  car(id){const c=carMap.get(id);if(!c)throw new Error('Unknown passenger car '+id);return c;},
  nearestDoor(z){return doors.reduce((best,d)=>Math.abs(d.z-z)<Math.abs(best.z-z)?d:best);},
  obstacles(space,car){
   const key=space+':'+car;
   if(!obstacleCache.has(key))obstacleCache.set(key,collisionZones.filter(o=>o.space===space&&(o.car===undefined||o.car===car)));
   return obstacleCache.get(key);
  },
 };
}

export function createTestPassengerLayout({gripAnchors=[],carCount=5}={}){
 const cars=Array.from({length:carCount},(_,id)=>{
  const centerZ=-88+id*21.5,aisleX=TRAIN.aisleX;
  const seatAnchors=trainSeatPositions(id).map((s,i)=>({...s,id:`test-${id}-seat-${i}`,hipHeight:.53,
   heading:s.x<aisleX?Math.PI/2:-Math.PI/2,approach:{x:s.x+(s.x<aisleX?.43:-.43),z:s.z}}));
  const standingZones=[];
  for(const side of [-1,1])for(let n=0;n<8;n++)standingZones.push({x:aisleX+side*.71,z:centerZ-7+n*2});
  return {id,centerZ,aisleX,seatAnchors,standingZones,
   bounds:{minX:-1.82,maxX:1.25},navigationZone:{minX:aisleX-.94,maxX:aisleX+.94,minZ:-100+id*21.5+.5,maxZ:-100+(id+1)*21.5-.5}};
 });
 const doors=DOORS.filter(d=>d.car<carCount).map(d=>({...d,thresholdX:TRAIN.thresholdX,entryX:-2.56,insideX:-1.65,
  exitInnerX:-2.42,exitOuterX:-3.8,exitClearX:-4.45,approachX:-3.55,queueX:-3.65,
  initialStanding:[{x:-1.02,z:d.z-1.3},{x:.40,z:d.z+1.3}],
  edge:d.z>1,yieldBoundaryX:-5.3,yieldX:-7.8,
  fallback:{x:TRAIN.aisleX+(d.id%2?-1:1)*.71,z:d.z+(d.id%2?-1:1)*3.2}}));
 return createPassengerLayout({train:{...TRAIN},platform:{...PLATFORM},doors,cars,gripAnchors,
  collisionZones:COLUMNS.map(c=>({...c,space:'platform'}))});
}

export const TEST_PASSENGER_LAYOUT=createTestPassengerLayout();
