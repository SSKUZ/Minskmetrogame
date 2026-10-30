export function createPlatformModule(station){const p=station.platform;return {id:p.id,surfaceY:p.topY,
 slab:{center:{x:(p.minX+p.maxX)/2,y:p.topY-p.thickness/2,z:(p.minZ+p.maxZ)/2},size:{x:p.maxX-p.minX,y:p.thickness,z:p.maxZ-p.minZ}},
 edges:[{id:'edge-1',trackId:'track-1',x:p.maxX,minZ:p.minZ,maxZ:p.maxZ},{id:'edge-2',trackId:'track-2',x:p.minX,minZ:p.minZ,maxZ:p.maxZ}]};}
