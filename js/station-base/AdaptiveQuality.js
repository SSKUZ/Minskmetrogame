// Pure adaptive quality controller. Only use samples from continuously active rendering.
export function createAdaptiveQuality({baseDpr=1,minDpr=.55,maxDpr=baseDpr,targetFps=30,windowMs=12000,cooldownMs=15000}={}){
 let dpr=Math.min(maxDpr,Math.max(minDpr,baseDpr)),lastChange=-Infinity,windowStart=null,frames=0;
 return {
  sample(now,{active=true,frameMs=0}={}){
   if(!active){windowStart=null;frames=0;return null;}
   if(windowStart===null)windowStart=now;
   if(!Number.isFinite(frameMs)||frameMs<=0)return null;
   frames++;
   if(now-windowStart<windowMs)return null;
   const fps=frames*1000/Math.max(1,now-windowStart);
   windowStart=now;frames=0;
   if(now-lastChange<cooldownMs)return {fps,dpr,changed:false};
   const next=fps<targetFps*.82?Math.max(minDpr,Math.round((dpr-.1)*100)/100):fps>targetFps*1.15?Math.min(maxDpr,Math.round((dpr+.05)*100)/100):dpr;
   const changed=next!==dpr;
   if(changed){dpr=next;lastChange=now;}
   return {fps,dpr,changed};
  },
  get dpr(){return dpr;},
  reset(){windowStart=null;frames=0;}
 };
}
