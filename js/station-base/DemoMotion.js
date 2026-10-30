export class DemoMotion{
 constructor(stop,{approachDistance=110,departDistance=120,motionSeconds=12,doorSeconds}={}){if(!Number.isFinite(doorSeconds)||doorSeconds<=0)throw new Error('doorSeconds required from profile');this.stop=stop;this.settings={approachDistance,departDistance,motionSeconds,doorSeconds};this.reset();}
 reset(){this.frontZ=this.stop.frontZ;this.speed=0;this.phase='stopped';this.doorProgress=0;this.doorTarget=0;this.segment=null;}
 arrive(){if(this.doorProgress!==0||this.doorTarget!==0)return false;this.start(this.stop.frontZ-this.stop.direction*this.settings.approachDistance,this.stop.frontZ,'approaching');return true;}
 depart(){if(this.phase!=='stopped'||this.doorProgress!==0||this.doorTarget!==0)return false;this.start(this.frontZ,this.stop.frontZ+this.stop.direction*this.settings.departDistance,'departing');return true;}
 start(from,to,phase){this.frontZ=from;this.segment={from,to,t:0};this.phase=phase;this.speed=0;}
 stopNow(){this.frontZ=this.stop.frontZ;this.speed=0;this.phase='stopped';this.segment=null;}
 setDoors(open){if(open&&(this.phase!=='stopped'||Math.abs(this.frontZ-this.stop.frontZ)>this.stop.tolerance||this.speed!==0))return false;this.doorTarget=open?1:0;return true;}
 update(dt){let changed=false;if(this.segment){const s=this.segment;s.t=Math.min(1,s.t+dt/this.settings.motionSeconds);const u=s.t,e=u*u*(3-2*u);this.frontZ=s.from+(s.to-s.from)*e;this.speed=(s.to-s.from)*6*u*(1-u)/this.settings.motionSeconds;changed=true;if(u===1){this.segment=null;this.speed=0;this.phase=this.phase==='approaching'?'stopped':'departed';}}
 if(this.doorProgress!==this.doorTarget){const step=dt/this.settings.doorSeconds;this.doorProgress+=Math.sign(this.doorTarget-this.doorProgress)*Math.min(step,Math.abs(this.doorTarget-this.doorProgress));changed=true;}return changed;}
}
