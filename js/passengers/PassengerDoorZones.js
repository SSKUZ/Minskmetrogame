// Conservative body/arm/baggage envelope in the same frame as door anchors.
// An adapter may provide a larger envelope or leaf zone for its actual model.
export function passengerDoorObstructions(agents,layout,dist=0){
 const result=[];
 for(const a of agents){
  if(a.state==='gone')continue;
  const z=a.z-(a.space==='platform'?dist:0),radius=a.safetyRadius??a.radius+.18;
  for(const d of layout.doors){
   if(Math.abs(a.x-d.thresholdX)<(d.leafDepth??.20)+radius&&Math.abs(z-d.z)<(d.halfWidth??1.06)+radius)
    result.push({id:a.id,door:d.id,state:a.state,space:a.space});
  }
 }
 return result;
}
