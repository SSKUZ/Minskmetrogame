export {V106_PROFILE} from '../../data/station-base/v106.js';
export function trainPlacement(profile,frontZ=0,trackX=0){return {x:trackX,y:profile.train.placementY,z:frontZ+profile.train.frontOffsetZ,scale:1,yaw:0};}
export function sourceToCanonical(p,profile){return {x:p.x,y:p.y+profile.train.placementY,z:p.z+profile.train.frontOffsetZ};}
export function canonicalToSource(p,profile){return {x:p.x,y:p.y-profile.train.placementY,z:p.z-profile.train.frontOffsetZ};}
