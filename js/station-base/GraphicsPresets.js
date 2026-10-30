// Conservative graphics presets. Manual override works when deviceMemory is unavailable.
export const GRAPHICS_PRESETS=Object.freeze({
 low:{dpr:0.7,proxyEnter:38,proxyExit:29,detailPixels:6,restorePixels:9,mediumEnter:18,mediumExit:14,playerHidePixels:3.2,playerRestorePixels:5,antialias:false},
 medium:{dpr:1.1,proxyEnter:55,proxyExit:42,detailPixels:3.5,restorePixels:5,mediumEnter:26,mediumExit:21,playerHidePixels:1.8,playerRestorePixels:3,antialias:true},
 high:{dpr:1.5,proxyEnter:85,proxyExit:65,detailPixels:2,restorePixels:3,mediumEnter:38,mediumExit:30,playerHidePixels:1.1,playerRestorePixels:2,antialias:true}
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
