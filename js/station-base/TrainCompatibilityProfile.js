export {V106_PROFILE} from '../../data/station-base/v106.js';
export function trainPlacement(profile,frontZ=0,trackX=0,direction=-1){if(![-1,1].includes(direction))throw new Error('Unsupported train direction');const sign=direction===-1?1:-1;return {x:trackX,y:profile.train.placementY,z:frontZ+sign*profile.train.frontOffsetZ,scale:1,yaw:sign===1?0:Math.PI};}
export function sourceToCanonical(p,profile){return {x:p.x,y:p.y+profile.train.placementY,z:p.z+profile.train.frontOffsetZ};}
export function canonicalToSource(p,profile){return {x:p.x,y:p.y-profile.train.placementY,z:p.z-profile.train.frontOffsetZ};}
