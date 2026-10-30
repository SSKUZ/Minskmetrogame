// Conservative graphics presets. Manual override works when deviceMemory is unavailable.
export const GRAPHICS_PRESETS=Object.freeze({
 low:{dpr:0.85,proxyEnter:38,proxyExit:29,detailPixels:5,restorePixels:7},
 medium:{dpr:1.1,proxyEnter:55,proxyExit:42,detailPixels:3.5,restorePixels:5},
 high:{dpr:1.5,proxyEnter:85,proxyExit:65,detailPixels:2,restorePixels:3}
});
export function selectGraphicsPreset({userAgent='',deviceMemory=0,hardwareConcurrency=0}={}){
 const mobile=/Android|iPhone|iPad|iPod/i.test(userAgent);
 if(!mobile)return 'high';
 if(deviceMemory>0&&deviceMemory<=4)return 'low';
 if(hardwareConcurrency>0&&hardwareConcurrency<=4)return 'low';
 return 'medium';
}
export function resolveGraphicsPreset(requested,device){
 const selected=requested&&Object.hasOwn(GRAPHICS_PRESETS,requested)?requested:selectGraphicsPreset(device);
 return {name:selected,...GRAPHICS_PRESETS[selected]};
}
