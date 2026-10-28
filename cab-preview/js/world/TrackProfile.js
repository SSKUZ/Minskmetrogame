export function smoothstep01(t){t=Math.max(0,Math.min(1,t));return t*t*(3-2*t)}
export function trackDrop(distance,depth,start,end){return depth*smoothstep01((distance-start)/(end-start))}
