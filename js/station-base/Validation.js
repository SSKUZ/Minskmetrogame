export function validateDefinition(station,profile,modules){
 const issues=[],eps=profile.validation.epsilon,p=station.platform,stop=modules.stop;
 const require=(condition,message)=>{if(!condition)issues.push(message)};
 require(station.profileId===profile.id,'Station profile mismatch');
 require(p.minX<p.maxX&&p.minZ<p.maxZ&&p.thickness>0,'Invalid platform bounds');
 require(p.maxX-p.minX>2*station.passenger.waitingInset,'Waiting zone has no width');
 require(modules.track.tracks.length===2,'Island v1 requires two tracks');
 require(stop.doors.length===profile.doors.length,'Incomplete door anchors');
 require(new Set(stop.doors.map(d=>d.id)).size===stop.doors.length,'Duplicate door IDs');
 for(const d of stop.doors){require(d.z-stop.tolerance-profile.door.routeHalfWidth>p.minZ&&d.z+stop.tolerance+profile.door.routeHalfWidth<p.maxZ,'Door outside usable platform: '+d.id);require(Math.abs(d.y-p.topY)<=eps,'Door/platform height mismatch');}
 require(Math.abs(profile.train.contactLocalY+profile.train.placementY-profile.rail.headY)<=eps,'Wheel contact datum mismatch');
 for(const t of modules.track.tracks)for(const r of t.rails)require(Math.abs(r.center.y+r.size.y/2-profile.rail.headY)<=eps,'Rail top mismatch');
 for(const t of modules.track.tracks)require(t.minZ<=p.minZ&&t.maxZ>=p.maxZ,'Rails do not span platform');
 for(const port of modules.ports){require(port.profileId===profile.id,'Port profile mismatch');require(port.railCenters.every(r=>Math.abs(r.y-profile.rail.headY)<=eps),'Port height mismatch');}
 return {ok:issues.length===0,issues};
}
