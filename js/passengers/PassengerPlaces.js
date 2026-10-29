function distance(a,b){return Math.hypot(a.x-b.x,a.z-b.z);}
export function standingPlaceKeepsDoorsClear(p,layout,carId){
 const car=layout.car(carId);
 return !layout.doors.some(d=>d.car===carId&&p.x<car.aisleX+.30&&p.x>d.thresholdX&&Math.abs(p.z-d.z)<(d.halfWidth??1.06)+.40)&&car.seatAnchors.every(s=>Math.hypot(s.approach.x-p.x,s.approach.z-p.z)>=.60);
}
export function familyCompanions(a,agents){
 return a.groupId===null?[]:agents.filter(o=>o!==a&&o.groupId===a.groupId&&o.state!=='gone'&&o.state!=='leaving');
}
export function reservePassengerSeat(a,agents,candidates,slot){
 const companions=familyCompanions(a,agents),family=a.child||companions.some(o=>o.child);
 const anchor=companions.find(o=>o.space==='train'&&o.state!=='alighting');
 const occupied=p=>agents.some(o=>{
  if(o===a||o.state==='gone'||o.state==='alighting')return false;
  const seat=o.reservedSeat??(o.space==='train'?o.seat:null);
  return seat&&distance(p,seat)<.58;
 });
 if(a.reservedSeat&&!occupied(a.reservedSeat)){const seat=a.reservedSeat;a.reservedSeat=null;return seat;}
 if(anchor){const at=anchor.seat??anchor.path.at(-1)??anchor;candidates.sort((p,b)=>distance(p,at)-distance(b,at));}
 if(family&&!anchor){
  const partner=companions.find(o=>o.wantsBoard&&o.space==='platform');
  if(partner)for(const seat of candidates){
   if(occupied(seat))continue;
   const adjacent=candidates.find(p=>p!==seat&&Math.abs(p.x-seat.x)<.05&&distance(p,seat)>.58&&distance(p,seat)<.75&&!occupied(p));
   if(adjacent){partner.reservedSeat=adjacent;return seat;}
  }
 }
 const vacant=candidates.find(p=>!occupied(p));
 if(!family&&slot%3===0)return null;
 // When seats are scarce, keep a child standing near the parent rather than
 // sending the child to an isolated free seat at the other end of the car.
 if(family&&anchor&&vacant&&distance(vacant,anchor.seat??anchor.path.at(-1)??anchor)>2)return null;
 return vacant??null;
}
