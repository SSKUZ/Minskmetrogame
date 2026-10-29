import {clamp} from './PassengerConfig.js';

// Read-only adapter. The train owns its physics; speed is supplied in km/h.
export class PassengerTrainMotion {
 constructor(){this.speed=null;this.station=null;this.acceleration=0;this.elapsed=0;}
 update(dt,{speed=0,station=0,acceleration}={}){
  const seconds=clamp(dt,0,.25),v=Number.isFinite(speed)?speed:0;
  const reset=this.speed===null||station!==this.station;
  const measured=Number.isFinite(acceleration)?acceleration:
   !reset&&seconds>1e-5?(v-this.speed)/(3.6*seconds):0;
  // Bound discontinuities from station previews, not the train simulation.
  const target=reset?0:clamp(measured,-3.2,2.2);
  this.acceleration+=(target-this.acceleration)*(1-Math.exp(-seconds*9));
  this.speed=v;this.station=station;this.elapsed+=seconds;
  return this;
 }
}

export class PassengerBalance {
 constructor(agent){this.phase=agent.phase??agent.id*.731;this.forward=0;this.lateral=0;this.vForward=0;this.vLateral=0;}
 update(dt,time,motion,agent,supported=false){
  const seated=agent.state==='seated',active=agent.space==='train'&&agent.velocity<.055&&['riding','seated'].includes(agent.state);
  const sensitivity=(seated?.24:supported?.55:1)*(agent.child?1.10:agent.elder?1.16:1);
  const running=clamp((motion?.speed??0)/22,0,1),phase=this.phase;
  // Positive acceleration is towards -Z. Inertia carries the torso towards +Z.
  const targetForward=active?sensitivity*(clamp(motion?.acceleration??0,-3.2,2.2)*.023+
   running*(Math.sin(time*(.89+(phase%1)*.12)+phase)*.004+Math.sin(time*1.73+phase*2.17)*.002)):0;
  const targetLateral=active?sensitivity*running*(Math.sin(time*(.72+(phase%1)*.09)+phase*1.61)*.006):0;
  // A damped response, integrated in bounded substeps, is stable at low FPS.
  for(let remaining=clamp(dt,0,.25);remaining>1e-8;){const h=Math.min(remaining,1/90);remaining-=h;
   this.vForward+=((targetForward-this.forward)*48-this.vForward*12)*h;this.forward+=this.vForward*h;
   this.vLateral+=((targetLateral-this.lateral)*48-this.vLateral*12)*h;this.lateral+=this.vLateral*h;
  }
  const heading=agent.heading??0,c=Math.cos(heading),s=Math.sin(heading);
  return {x:clamp(s*this.lateral-c*this.forward,-.085,.085),z:clamp(-c*this.lateral-s*this.forward,-.085,.085)};
 }
}
