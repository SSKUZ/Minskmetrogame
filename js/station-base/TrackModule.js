export function createTrackModule(station,profile){
 const r=station.trackRange,g=profile.trackGeometry,length=r.maxZ-r.minZ,centerZ=(r.minZ+r.maxZ)/2;
 return {profileId:profile.id,tracks:station.tracks.map(t=>({...t,minZ:r.minZ,maxZ:r.maxZ,
  bed:{primitive:'box',materialId:'bed',size:{x:g.bed.width,y:g.bed.height,z:length},center:{x:t.x,y:g.bed.centerY,z:centerZ}},
  sleepers:{primitive:'box-instances',materialId:'sleeper',size:{x:g.sleepers.width,y:g.sleepers.height,z:g.sleepers.depth},x:t.x,y:g.sleepers.centerY,startZ:r.minZ,pitch:g.sleepers.pitch,count:Math.floor(length/g.sleepers.pitch)},
  rails:profile.rail.centerOffsets.map((offset,i)=>({primitive:'box',materialId:'rail',id:`${t.id}/rail-${i}`,center:{x:t.x+offset,y:profile.rail.headY-profile.rail.height/2,z:centerZ},size:{x:profile.rail.width,y:profile.rail.height,z:length},headY:profile.rail.headY}))}))};
}
