export function validateDefinition(station,profile,modules){
 const issues=[],eps=profile.validation.epsilon,p=station.platform;
 const require=(condition,message)=>{if(!condition)issues.push(message)};
 require(station.profileId===profile.id,'Station profile mismatch');
 require(p.minX<p.maxX&&p.minZ<p.maxZ&&p.thickness>0,'Invalid platform bounds');
 require(p.maxX-p.minX>2*(station.passenger.waitingInset+station.passenger.waitingWidth),'Waiting zones overlap or have no width');
 require(modules.track.tracks.length===2,'Island v1 requires two tracks');
 const stops=modules.stops??[modules.stop];
 for(const stop of stops){
  require(stop.doors.length===profile.doors.length,'Incomplete door anchors');
  require(new Set(stop.doors.map(d=>d.id)).size===stop.doors.length,'Duplicate door IDs');
  for(const d of stop.doors){require(d.z-stop.tolerance-profile.door.routeHalfWidth>p.minZ&&d.z+stop.tolerance+profile.door.routeHalfWidth<p.maxZ,'Door outside usable platform: '+d.id);require(Math.abs(d.y-p.topY)<=eps,'Door/platform height mismatch');}
 }
 require(stops.length===station.tracks.length,'Missing independent stop');
 require(Math.abs(profile.train.contactLocalY+profile.train.placementY-profile.rail.headY)<=eps,'Wheel contact datum mismatch');
 for(const t of modules.track.tracks)for(const r of t.rails)require(Math.abs(r.center.y+r.size.y/2-profile.rail.headY)<=eps,'Rail top mismatch');
 for(const t of modules.track.tracks)require(t.minZ<=p.minZ&&t.maxZ>=p.maxZ,'Rails do not span platform');
 for(const port of modules.ports){const track=station.tracks.find(t=>t.id===port.trackId);require(port.profileId===profile.id,'Port profile mismatch');require(port.railCenters.every(r=>Math.abs(r.y-profile.rail.headY)<=eps),'Port height mismatch');require(port.railCenters.every((r,i)=>Math.abs(r.x-track.x-profile.rail.centerOffsets[i])<=eps),'Port rail center mismatch');}
 for(const obstacle of modules.collision.obstacles)require(obstacle.x-obstacle.radius>=p.minX&&obstacle.x+obstacle.radius<=p.maxX&&obstacle.z-obstacle.radius>=p.minZ&&obstacle.z+obstacle.radius<=p.maxZ,'Obstacle outside platform: '+obstacle.id);
 for(const mount of modules.decoration?.mounts??[])require(!modules.collision.reservations.some(r=>mount.x>r.minX&&mount.x<r.maxX&&mount.y>r.minY&&mount.y<r.maxY),'Decoration in reserved train volume: '+mount.id);
 return {ok:issues.length===0,issues};
}
