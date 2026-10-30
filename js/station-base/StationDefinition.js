import {V106_PROFILE} from '../../data/station-base/v106.js';
export function createStationDefinition(options={}){
 const profile=options.profile??V106_PROFILE;
 const length=options.length??105,width=options.width??8,centerZ=options.centerZ??profile.train.nominalLength/2;
 const kind=options.kind??'straight-level-island';
 if(kind!=='straight-level-island')throw new Error('Unsupported station topology: '+kind);
 if(![length,width,centerZ].every(Number.isFinite)||length<=0||width<=0)throw new Error('Invalid platform dimensions');
 const primaryTrackX=options.primaryTrackX??0;if(!Number.isFinite(primaryTrackX))throw new Error('Invalid track origin');
 const edge=primaryTrackX-profile.platform.edgeOffset,farEdge=edge-width,direction=options.direction??-1;
 if(![-1,1].includes(direction))throw new Error('Direction must be -1 or +1');
 const tracks=[{id:'track-1',x:primaryTrackX,role:'player'},{id:'track-2',x:farEdge-profile.platform.edgeOffset,role:'opposing'}];
 const tolerance=options.stopTolerance??.5;
 const stops=tracks.map((t,i)=>{const dir=i===0?direction:-direction,frontZ=(i===0?options.stopS:options.secondStopS)??(centerZ+(dir===-1?-1:1)*profile.train.nominalLength/2);return {id:`stop-${i+1}`,trackId:t.id,frontZ,tolerance,servedSide:i===0?-1:1,direction:dir};});
 const definition={schemaVersion:1,id:options.id??'station-base-technical',kind,units:profile.units,profileId:profile.id,tracks,
  trackRange:options.trackRange??{minZ:-180,maxZ:220},
  platform:{id:'island',minX:farEdge,maxX:edge,minZ:centerZ-length/2,maxZ:centerZ+length/2,topY:profile.platform.topY,thickness:profile.platform.slabThickness},stops,stop:stops[0],
  passenger:{waitingInset:options.waitingInset??.8,waitingWidth:options.waitingWidth??1,exitAnchors:options.exitAnchors??[],spawnZones:options.spawnZones??[]},
  obstacles:options.obstacles??[],decorationMounts:options.decorationMounts??[],
  provenance:{scope:'technical compatibility fixture; not Malinovka dimensions',assetCommit:profile.assetCommit}};
 for(const s of stops)if(!Number.isFinite(s.frontZ)||!Number.isFinite(s.tolerance)||s.tolerance<0)throw new Error('Invalid stop');
 const r=definition.trackRange;if(![r.minZ,r.maxZ].every(Number.isFinite)||r.minZ>=r.maxZ)throw new Error('Invalid track range');
 return definition;
}
