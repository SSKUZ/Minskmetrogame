export function createTrainStopModule(station,profile,stopDefinition=station.stop){
 const stop=stopDefinition,track=station.tracks.find(t=>t.id===stop.trackId);if(!track)throw new Error('Unknown stop track');
 const sign=stop.direction===-1?1:-1;
 return {...stop,trackX:track.x,yaw:sign===1?0:Math.PI,reference:'active-first-cab-nominal-front',
  doors:profile.doors.map((d,i)=>({...d,id:`${stop.trackId}/door-${i}`,sourceAnchorId:d.id,localSide:-stop.servedSide*sign*d.localSide,
   x:track.x+stop.servedSide*profile.train.thresholdAbsX,y:profile.train.thresholdLocalTopY+profile.train.placementY,z:stop.frontZ+sign*d.z,trainZ:d.z,normal:{x:stop.servedSide,y:0,z:0}}))};
}
export function canExchange(stop,frontZ,speed){return Number.isFinite(speed)&&Math.abs(speed)<1e-6&&Math.abs(frontZ-stop.frontZ)<=stop.tolerance;}
