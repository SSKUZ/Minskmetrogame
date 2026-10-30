export function createPassengerStationContract(station,profile,stops){
 const p=station.platform,i=station.passenger.waitingInset,w=station.passenger.waitingWidth;
 const tracks=stops.map(stop=>({trackId:stop.trackId,stopId:stop.id,servedSide:stop.servedSide,direction:stop.direction,
  trainFrame:{floorY:p.topY,frontZ:stop.frontZ,yaw:stop.yaw},doors:stop.doors.map(d=>({...d,routeHalfWidth:profile.door.routeHalfWidth,stationZ:d.z,trainZ:d.trainZ})),
  waitingZone:{id:`${stop.trackId}/waiting`,trackId:stop.trackId,minX:stop.servedSide===-1?p.maxX-i-w:p.minX+i,maxX:stop.servedSide===-1?p.maxX-i:p.minX+i+w,minZ:p.minZ+1,maxZ:p.maxZ-1},
  boardingZones:stop.doors.map(d=>({id:d.id+'/boarding',doorId:d.id,trackId:stop.trackId,x:d.x+stop.servedSide*(i+w/2),z:d.z,halfWidth:profile.door.routeHalfWidth})),
  alightingZones:stop.doors.map(d=>({id:d.id+'/alighting',doorId:d.id,trackId:stop.trackId,x:d.x+stop.servedSide*i,z:d.z,halfWidth:profile.door.routeHalfWidth}))}));
 return {version:1,status:'anchors-only-no-passenger-runtime',stationFrame:{offsetZ:0,railHeadY:profile.rail.headY},tracks,doors:tracks[0].doors,waitingZones:tracks.map(t=>t.waitingZone),
 spawnZones:station.passenger.spawnZones,exits:station.passenger.exitAnchors,obstacles:station.obstacles,
 limitations:['No PassengerSystem instantiation','Second-side and rotated passenger consumer require separately approved integration','Seat-ID occupancy, queue and exit graph unresolved','No active exits until real anchors supplied']};
}
export function transferZ(z,{trainOffsetZ,stationOffsetZ,direction=-1},toTrain){const sign=direction===-1?1:-1;return toTrain?sign*(z+stationOffsetZ-trainOffsetZ):sign*z+trainOffsetZ-stationOffsetZ;}
