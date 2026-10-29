import {PASSENGER_ASSETS} from './PassengerConfig.js';

// Recorded CC0 human ambience. Started only by the player's first gesture.
export class PassengerAudio{
 constructor(){this.context=null;this.buffers={};this.level=0;this.stepClock=new Map();this.errors=[];}
 async start(){
  if(this.context){await this.context.resume();return;}
  const Context=window.AudioContext||window.webkitAudioContext;if(!Context)return;
  this.context=new Context();const ctx=this.context;
  this.gain=ctx.createGain();this.gain.gain.value=0;this.gain.connect(ctx.destination);
  const filter=ctx.createBiquadFilter();filter.type='lowpass';filter.frequency.value=1300;filter.connect(this.gain);
  try{
   const [murmur,steps]=await Promise.all(['passenger-murmur.mp3','passenger-steps.mp3'].map(async file=>{
    const response=await fetch(new URL('../../audio/'+file,import.meta.url));if(!response.ok)throw new Error(`${file}: ${response.status}`);
    return ctx.decodeAudioData(await response.arrayBuffer());
   }));
   this.buffers={murmur,steps};
   const source=ctx.createBufferSource();source.buffer=murmur;source.loop=true;
   source.connect(filter);source.start(0,7.3);this.source=source;
  }catch(e){this.errors.push(e.message);}
 }
 update(agents,cameraPosition,worldPosition,{volume=1,playing=true,inCab=false,doorsOpen=false},dt){
  if(!this.context||!this.gain)return;
  let density=0;const nearby=[];
  for(const a of agents){
   if(a.state==='gone')continue;
   const p=worldPosition(a),d=Math.hypot(p.x-cameraPosition.x,p.z-cameraPosition.z);
   density+=1/(1+(d/9)**2);
   if(d<12&&a.velocity>.1)nearby.push({a,d});
  }
  const target=playing?Math.min(.115,Math.sqrt(density)*.018)*volume*(inCab?(doorsOpen?.55:.20):1):0;
  this.level+=(target-this.level)*Math.min(1,dt*1.8);
  this.gain.gain.setTargetAtTime(this.level,this.context.currentTime,.35);
  // Footfalls use the same travelled distance as the gait, not an unrelated timer.
  for(const {a,d} of nearby.slice(0,8)){
   const beat=Math.floor(a.distance/(a.child?.31:.43));
   if(this.stepClock.get(a.id)===beat)continue;this.stepClock.set(a.id,beat);
   if(!this.buffers.steps||!playing)continue;
   const source=this.context.createBufferSource(),gain=this.context.createGain();source.buffer=this.buffers.steps;
   source.playbackRate.value=a.elder?.87:1+(a.id%5)*.018;
   gain.gain.value=Math.min(.027,.045/(1+d*.6))*volume*(inCab?.15:1);
   source.connect(gain);gain.connect(this.context.destination);
   source.start(0,.5+(a.id%4)*.49,.16);source.onended=()=>{source.disconnect();gain.disconnect();};
  }
 }
 snapshot(){return {started:!!this.context,loaded:!!this.buffers.murmur,level:this.level,errors:this.errors.slice()};}
}
