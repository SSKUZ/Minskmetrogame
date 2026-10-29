// Shared saloon-motion signal for the browser game and future passenger adapters.
// It never changes train physics; it converts already-computed motion into restrained visual motion.
export function createSaloonMotionModel(){
 let phase=0,roll=0,heave=0,surge=0;
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
 function update({dt=0,speed=0,acceleration=0,trackImpulse=0}={}){
  dt=clamp(Number(dt)||0,0,.1);speed=Math.max(0,Number(speed)||0);acceleration=clamp(Number(acceleration)||0,-2.5,2.5);
  phase+=dt*(4.2+speed*.48);
  const moving=clamp(speed/4,0,1);
  const targetRoll=moving*(Math.sin(phase*.73)*.0026+Math.sin(phase*1.91)*.0012)+clamp(trackImpulse,-1,1)*.0035;
  const targetHeave=moving*(Math.sin(phase*2.7)*.0022+Math.sin(phase*4.1)*.0008);
  const targetSurge=clamp(-acceleration*.006,-.012,.012);
  const k=1-Math.exp(-dt*7);
  roll+=(targetRoll-roll)*k;heave+=(targetHeave-heave)*k;surge+=(targetSurge-surge)*k;
  return {roll,heave,surge,moving};
 }
 function passenger(index=0){
  // Stable per-passenger phase/amplitude prevents synchronized mannequin motion.
  const seed=((index*1103515245+12345)>>>0)/4294967295;
  return {phaseOffset:seed*Math.PI*2,amplitude:.72+seed*.34,response:.78+seed*.30};
 }
 function reset(){phase=roll=heave=surge=0}
 function acousticProfile(view='saloon',speed=0){const m=Math.max(0,Math.min(1,(Number(speed)||0)/18));return view==='saloon'?{ventilation:1,railRoll:.45+.55*m,bodyRumble:.38+.44*m,tunnelExterior:.34}:{ventilation:.56,railRoll:.30+.32*m,bodyRumble:.30+.30*m,tunnelExterior:.22};}
 return {update,passenger,acousticProfile,reset};
}
