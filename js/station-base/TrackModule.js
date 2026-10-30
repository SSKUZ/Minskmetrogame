export function createTrackModule(station,profile){
 const r=station.trackRange;
 return {profileId:profile.id,tracks:station.tracks.map(t=>({...t,minZ:r.minZ,maxZ:r.maxZ,
  rails:profile.rail.centerOffsets.map((offset,i)=>({id:`${t.id}/rail-${i}`,center:{x:t.x+offset,y:profile.rail.headY-profile.rail.height/2,z:(r.minZ+r.maxZ)/2},size:{x:profile.rail.width,y:profile.rail.height,z:r.maxZ-r.minZ},headY:profile.rail.headY}))}))};
}
