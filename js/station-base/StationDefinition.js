import {V106_PROFILE} from '../../data/station-base/v106.js';
export function createStationDefinition(options={}){
 const profile=options.profile??V106_PROFILE;
 const length=options.length??105,width=options.width??8,centerZ=options.centerZ??profile.train.nominalLength/2;
 const kind=options.kind??'straight-level-island';
 if(kind!=='straight-level-island')throw new Error('Unsupported station topology: '+kind);
 if(![length,width,centerZ].every(Number.isFinite)||length<=0||width<=0)throw new Error('Invalid platform dimensions');
 const stopS=options.stopS??0,edge=-profile.platform.edgeOffset,farEdge=edge-width;
 const definition={schemaVersion:1,id:options.id??'station-base-technical',kind,units:profile.units,profileId:profile.id,
  tracks:[{id:'track-1',x:0},{id:'track-2',x:farEdge-profile.platform.edgeOffset}],
  trackRange:options.trackRange??{minZ:-180,maxZ:220},
  platform:{id:'island',minX:farEdge,maxX:edge,minZ:centerZ-length/2,maxZ:centerZ+length/2,topY:profile.platform.topY,thickness:profile.platform.slabThickness},
  stop:{id:'stop-1',trackId:'track-1',frontZ:stopS,tolerance:options.stopTolerance??.5,servedSide:-1},
  passenger:{waitingInset:options.waitingInset??.8,exitAnchors:options.exitAnchors??[],spawnZones:options.spawnZones??[]},
  obstacles:options.obstacles??[],decorationMounts:options.decorationMounts??[],
  provenance:{scope:'technical compatibility fixture; not Malinovka dimensions',assetCommit:profile.assetCommit}};
 if(!Number.isFinite(stopS)||!Number.isFinite(definition.stop.tolerance)||definition.stop.tolerance<0)throw new Error('Invalid stop');
 const r=definition.trackRange;if(![r.minZ,r.maxZ].every(Number.isFinite)||r.minZ>=r.maxZ)throw new Error('Invalid track range');
 return definition;
}
