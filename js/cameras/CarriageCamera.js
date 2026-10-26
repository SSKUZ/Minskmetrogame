// Independent carriage camera: fixed upper-left corner, swipe to look around.
export function createCarriageCameraController(THREE,camera,canvas,isActive){
 let yaw=0,pitch=0,drag=null;
 const origin=new THREE.Vector3(-1.42,3.12,1.72);
 const forward=new THREE.Vector3(1.15,-1.42,-10.8).normalize();
 function aim(){camera.position.copy(origin);const direction=forward.clone().applyAxisAngle(new THREE.Vector3(0,1,0),yaw);const right=new THREE.Vector3().crossVectors(direction,new THREE.Vector3(0,1,0)).normalize();direction.applyAxisAngle(right,pitch);camera.lookAt(origin.clone().add(direction));}
 function reset(){yaw=0;pitch=0;aim()}
 canvas.addEventListener('pointerdown',e=>{if(!isActive())return;drag={id:e.pointerId,x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);e.preventDefault()});
 canvas.addEventListener('pointermove',e=>{if(!isActive()||!drag||drag.id!==e.pointerId)return;yaw=THREE.MathUtils.clamp(yaw+(drag.x-e.clientX)*.004,-1.35,1.35);pitch=THREE.MathUtils.clamp(pitch+(e.clientY-drag.y)*.003,-.72,.55);drag.x=e.clientX;drag.y=e.clientY;aim();e.preventDefault()});
 for(const evt of ['pointerup','pointercancel'])canvas.addEventListener(evt,e=>{if(drag?.id===e.pointerId)drag=null});
 reset();return {reset,aim};
}
