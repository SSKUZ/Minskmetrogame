export const clampView=(v,d,limit=.35)=>Math.max(-limit,Math.min(limit,v+d));
export function restoreViewport(renderer,w,h){renderer.setRenderTarget(null);renderer.setViewport(0,0,w,h);renderer.setScissorTest(false)}
export function resizeCameras(renderer,cameras,w,h){renderer.setSize(w,h);for(const c of cameras){c.aspect=w/h;c.updateProjectionMatrix()}}
export function chooseCamera(cameras,mode){return cameras[mode]}
