export function createTrainStopModule(station,profile){
 const stop=station.stop,track=station.tracks.find(t=>t.id===stop.trackId);if(!track)throw new Error('Unknown stop track');
 return {...stop,trackX:track.x,reference:'first-cab-nominal-front',doors:profile.doors.map(d=>({...d,x:track.x-profile.train.thresholdAbsX,y:profile.train.thresholdLocalTopY+profile.train.placementY,z:d.z+stop.frontZ,normal:{x:-1,y:0,z:0}}))};
}
export function canExchange(stop,frontZ,speed){return Number.isFinite(speed)&&Math.abs(speed)<1e-6&&Math.abs(frontZ-stop.frontZ)<=stop.tolerance;}
