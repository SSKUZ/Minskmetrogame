import {recordBoarding} from './PassengerCount.js';
import {easePassengerMotion} from './PassengerBoarding.js';
export function updatePassengerMovement(dt,ctx){
 let {platformLifeTime,passengerDoorTime,passengerExchangeStarted,stationSkipped,dist,stopTolerance,speed,doors,stationDoorCycleCompleted,platformPassengers,carriagePassengers,index,passengerBoardingRecorded,carriagePlatformAvatars,people,shortestTurn,facingDirection}=ctx;
 platformLifeTime+=dt;
 const atPlatform=!stationSkipped&&Math.abs(dist)<=stopTolerance&&speed<.5;
 if(atPlatform&&doors&&!stationDoorCycleCompleted){
  if(!passengerExchangeStarted){passengerExchangeStarted=true;passengerDoorTime=0;}
  passengerDoorTime+=dt;
 } // Boarding time never resets when doors close or reopen at this station.
 const ease=easePassengerMotion;
 for(let i=0;i<platformPassengers.length;i++){
  const p=platformPassengers[i],cp=carriagePassengers[i];
  const active=atPlatform&&doors&&!stationDoorCycleCompleted;
  const exiting=index!==0&&p.exiting;
  const elapsed=passengerDoorTime-(exiting?0:index===0?0:2.5)-p.offset;
  const duration=5.2+(p.queueRank*.45)+(i%3)*.22;
  const t=active?Math.max(0,Math.min(1,elapsed/duration)):0;
  // Approach along the platform, align with the nearest door, then walk
  // across the gap. No teleport at the threshold.
  const align=ease(t/.53),approach=ease((t-.12)/.57),cross=ease((t-.69)/.31);
  // Walk from platform (-X) through the same physical door at X=-2.01.
  const doorX=-2.10,insideX=-1.72;
  const homeX=p.homeX,homeZ=p.homeZ;
  const crossed=active&&!exiting&&t>=.79;
  if(crossed&&!passengerBoardingRecorded.has(i)){
   recordBoarding(passengerBoardingRecorded,i,cp,()=>{people+=1});
  }
  const walking=active&&t>0&&t<1;
  if(!exiting){
   p.person.position.x=homeX+(doorX-homeX)*approach+(insideX-doorX)*cross;
   p.person.position.z=homeZ+(p.doorwayZ-homeZ)*align;
  }else{
   p.person.position.x=insideX+(doorX-insideX)*ease(t/.32)+(homeX-doorX)*ease((t-.32)/.68);
   p.person.position.z=p.doorwayZ+(homeZ-p.doorwayZ)*ease((t-.32)/.68);
  }
  // The platform avatar remains in the doorway until fully inside, while
  // the carriage camera renders its matching interior avatar.
  p.person.visible=!passengerBoardingRecorded.has(i)&&!(active&&exiting&&t>=1);
  // Once aboard, the passenger remains in the carriage while travelling.
  cp.person.visible=cp.settled;
  const carriageOutside=carriagePlatformAvatars[i];
  carriageOutside.position.set(-p.person.position.x,p.person.position.y,(i%2===0?-3.2:-13)+(p.person.position.z-p.doorwayZ));
  carriageOutside.rotation.copy(p.person.rotation);
  carriageOutside.visible=false;
  // The exterior copy disappears as its interior counterpart becomes visible.
  if(cp.settled)carriageOutside.visible=false;
  // Once the train departs, lock boarded passengers into their seats.
  // Otherwise the next station resets passengerDoorTime and rewinds their
  // coordinates to the doorway, making them disappear from the camera.
  if(cp.settled&&!active&&!cp.seated){
   cp.seated=true;
   const seatX=cp.side*(cp.slot%3===0?1.49:.70);
   cp.person.position.set(seatX,cp.slot%3===0?.43:.78,cp.z);
   cp.person.rotation.set(cp.slot%3===0?-.12:0,cp.side>0?-Math.PI/2:Math.PI/2,0);
  }
  if(cp.settled&&!cp.seated){
   // First step through the carriage door, then turn into the aisle and
   // walk down to the assigned seat. Each passenger has a different pace.
   const progress=Math.max(0,(elapsed-duration*.79)/(7.0+(i%5)*.8));
   // Malinovka's platform is on the negative-X side of the train.
   const sideEntry=-2.02;
   const entryZ=i%2===0?-3.2:-13;
   const aisleX=cp.side*.36;
   const seatX=cp.side*(cp.slot%3===0?1.49:.70);
   const doorPhase=ease(progress/.25);
   const aislePhase=ease((progress-.25)/.5);
   const seatPhase=ease((progress-.75)/.25);
   cp.person.position.x=sideEntry+(aisleX-sideEntry)*doorPhase+(seatX-aisleX)*seatPhase;
   cp.person.position.z=entryZ+(cp.z-entryZ)*aislePhase;
   const moving=progress>0&&progress<1;
   // Model faces local -Z; a passenger moving from left entrance to aisle
   // should face right (+X), not toward the camera or backward.
   const heading=progress<.25?-Math.PI/2:
      progress<.75?(cp.z>entryZ?Math.PI:0):
      (cp.side>0?-Math.PI/2:Math.PI/2);
   cp.person.rotation.y+=shortestTurn(cp.person.rotation.y,heading)*Math.min(1,dt*5);
   const walkingGait=moving?Math.sin(platformLifeTime*(8.6+(i%3)) +i*1.3):0;
   cp.person.position.y=.78+(moving?Math.abs(walkingGait)*.03:0);
   cp.person.rotation.z=moving?Math.sin(platformLifeTime*4+i)*.015:0;
   if(progress>=1){
    cp.seated=true;
    cp.person.position.set(seatX,cp.slot%3===0?.43:.78,cp.z);
    cp.person.rotation.x=cp.slot%3===0?-.12:0;
    cp.person.rotation.y=cp.side>0?-Math.PI/2:Math.PI/2;
   }
  }
  // Derive facing and walking speed from the actual path, so figures turn
  // toward their own doorway instead of sliding sideways like mannequins.
  const dx=exiting?homeX-insideX:insideX-homeX;
  const dz=exiting?homeZ-p.doorwayZ:p.doorwayZ-homeZ;
  const heading=walking?facingDirection(dx,dz):p.heading+Math.sin(platformLifeTime*.45+p.phase)*.1;
  p.person.rotation.y+=shortestTurn(p.person.rotation.y,heading)*Math.min(1,dt*(walking?5:2));
  const phase=platformLifeTime*(8.2+(i%4)*.65)+p.phase;
  const gait=walking?Math.sin(phase):0;
  const stepBlend=walking?Math.min(1,t*13,(1-t)*13):0;
  p.person.position.y=.78+Math.abs(gait)*.038*stepBlend+Math.sin(platformLifeTime*1.2+p.phase)*.004;
  p.person.rotation.z=Math.sin(phase*.5)*.015*stepBlend;
  for(const limb of p.person.userData.walkLimbs){
   const swing=limb.kind==='leg'?.38:.29;
   limb.mesh.rotation.x=(limb.kind==='leg'?1:-1)*limb.side*gait*swing*stepBlend;
  }
 }
 return {platformLifeTime,passengerDoorTime,passengerExchangeStarted,people};
}
