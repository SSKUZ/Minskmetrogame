export function createPassengerStationContract(station,profile,stop){
 const p=station.platform;
 return {version:1,status:'anchors-only-no-passenger-runtime',supportedSide:-1,trainFrame:{floorY:p.topY,offsetZ:stop.frontZ},stationFrame:{offsetZ:0,railHeadY:profile.rail.headY},
 doors:stop.doors.map(d=>({...d,routeHalfWidth:profile.door.routeHalfWidth,stationZ:d.z,trainZ:d.z-stop.frontZ})),
 waitingZones:[{id:'waiting-island',minX:p.minX+station.passenger.waitingInset,maxX:p.maxX-station.passenger.waitingInset,minZ:p.minZ+1,maxZ:p.maxZ-1}],
 spawnZones:station.passenger.spawnZones,exits:station.passenger.exitAnchors,obstacles:station.obstacles,
 limitations:['No PassengerSystem instantiation','Seat-ID occupancy, interior queue and exit graph need separately approved integration','No active exits until real anchors supplied']};
}
export function transferZ(z,{trainOffsetZ,stationOffsetZ},toTrain){const dist=trainOffsetZ-stationOffsetZ;return z+(toTrain?-dist:dist);}
