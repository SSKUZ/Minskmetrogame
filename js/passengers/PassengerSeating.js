import {turnDelta} from './PassengerConfig.js';

export const SEAT_TIMING=Object.freeze({turn:.55,sit:2,stand:2,stabilize:.30});
export function seatApproach(seat){return {x:seat.x+(seat.x<-.31?.43:-.43),z:seat.z};}
const eased=t=>{const p=Math.max(0,Math.min(1,t));return p*p*(3-2*p);};
export function beginSitting(a){
 a.state='seatTurning';a.seatTime=0;a.activity='wait';a.velocity=0;
 a.targetHeading=a.x<-.31?Math.PI/2:-Math.PI/2;
}
export function beginStanding(a){a.state='standingUp';a.seatTime=0;a.activity='wait';a.velocity=0;a.railGrip=null;}
export function updateSeating(a,dt){
 if(!['seatTurning','sittingDown','standingUp','seatStabilizing'].includes(a.state))return false;
 a.velocity=0;a.seatTime=(a.seatTime??0)+dt;
 if(a.seat&&['sittingDown','standingUp'].includes(a.state)){
  const approach=seatApproach(a.seat),t=eased(a.seatTime/2),weight=a.state==='sittingDown'?1-t:t;
  a.x=a.seat.x+(approach.x-a.seat.x)*weight;a.z=a.seat.z+(approach.z-a.seat.z)*weight;
 }
 if(a.state==='seatTurning'){
  if(a.seatTime>=SEAT_TIMING.turn&&Math.abs(turnDelta(a.heading,a.targetHeading))<.035){a.state='sittingDown';a.seatTime=0;}
 }else if(a.state==='sittingDown'&&a.seatTime>=SEAT_TIMING.sit){a.state='seated';a.seatTime=0;a.nextDecision=0;}
 else if(a.state==='standingUp'&&a.seatTime>=SEAT_TIMING.stand){a.state='seatStabilizing';a.seatTime=0;}
 else if(a.state==='seatStabilizing'&&a.seatTime>=SEAT_TIMING.stabilize){a.state='riding';a.seat=null;a.seatTime=0;}
 return true;
}
