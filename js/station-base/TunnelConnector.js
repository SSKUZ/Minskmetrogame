export function createTunnelConnectors(station,profile){return station.tracks.flatMap(t=>[-1,1].map(end=>({id:`${t.id}/${end<0?'start':'end'}`,trackId:t.id,profileId:profile.id,
 position:{x:t.x,y:profile.rail.headY,z:end<0?station.trackRange.minZ:station.trackRange.maxZ},outward:{x:0,y:0,z:end},
 railCenters:profile.rail.centerOffsets.map(x=>({x:t.x+x,y:profile.rail.headY,z:end<0?station.trackRange.minZ:station.trackRange.maxZ}))})));}
export function validatePortPair(a,b,profile){
 const eps=profile.validation.epsilon,dist=(p,q)=>Math.hypot(p.x-q.x,p.y-q.y,p.z-q.z);
 const dot=a.outward.x*b.outward.x+a.outward.y*b.outward.y+a.outward.z*b.outward.z;
 return a.profileId===b.profileId&&dist(a.position,b.position)<=eps&&dot<=-Math.cos(profile.validation.portAngleTolerance*Math.PI/180)&&a.railCenters.every(p=>b.railCenters.some(q=>dist(p,q)<=eps));
}
