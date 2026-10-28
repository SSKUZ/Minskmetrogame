// Stage-1 integration contract for the verified v106 81-717/714 viewer.
// The viewer and the game use separate scene builders; this adapter never
// substitutes a decorative low-detail train for the validated v106 geometry.
export const V106_FORMATION=Object.freeze(['81-717','81-714','81-714','81-717']);
export const V106_CAR_LENGTH=19.206;
export const V106_BODY_GAP=.8;
export const V106_CAR_PITCH=V106_CAR_LENGTH+V106_BODY_GAP;
export const V106_TRAIN_LENGTH=4*V106_CAR_LENGTH+3*V106_BODY_GAP;

// Viewer +Z points along the assembled consist, while the game's forward
// direction is -Z. Keep this conversion explicit instead of scaling the cars.
export function consistCarPose(index,trainFrontZ=0){
 if(!Number.isInteger(index)||index<0||index>=4)throw new RangeError('Car index must be 0..3');
 return Object.freeze({index,type:V106_FORMATION[index],x:0,y:0,
  z:trainFrontZ+index*V106_CAR_PITCH,
  yaw:index===3?Math.PI:0,scale:1});
}
export function consistDoorCommand(doorsOpen){
 return {open:Boolean(doorsOpen),cars:[0,1,2,3],leavesPerCar:16};
}
export function validateV106Consist(consist){
 if(!consist||!Array.isArray(consist.cars)||consist.cars.length!==4)
  throw new Error('Expected four physical car objects');
 for(let i=0;i<4;i++){
  const c=consist.cars[i];
  if(c.type!==V106_FORMATION[i]||!c.root||!Array.isArray(c.leaves)||c.leaves.length!==16)
   throw new Error('Missing original v106 geometry or door registry at car '+i);
 }
 return true;
}
