// Independent carriage camera: at FRONT bulkhead (negative Z), tunnel-wall side (+X), looking BACK (+Z), swipe to look around.
export function createCarriageCameraController(THREE,camera,canvas,isActive){
 let yaw=0,pitch=0,drag=null;
 const origin=new THREE.Vector3(1.72,2.78,-19.88);
 const forward=new THREE.Vector3(-3.25,-0.20,18.0).normalize();
 function aim(){camera.position.copy(origin);const direction=forward.clone().applyAxisAngle(new THREE.Vector3(0,1,0),yaw);const right=new THREE.Vector3().crossVectors(direction,new THREE.Vector3(0,1,0)).normalize();direction.applyAxisAngle(right,pitch);// lookAt takes a WORLD-space target. The carriage camera is parented to a train group translated along Z.
 // Convert the local aim target to world coordinates, otherwise it looks into the end wall.
 const target=origin.clone().add(direction);
 if(camera.parent){camera.parent.updateWorldMatrix(true,false);camera.parent.localToWorld(target);}
 camera.lookAt(target);}
 function setPose(nextOrigin,nextForward){origin.copy(nextOrigin);forward.copy(nextForward).normalize();yaw=0;pitch=0;aim()}
 function useLegacyPose(){setPose(legacyOrigin,legacyForward)}
 function reset(){yaw=0;pitch=0;aim()}
 canvas.addEventListener('pointerdown',e=>{if(!isActive())return;drag={id:e.pointerId,x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);e.preventDefault()});
 canvas.addEventListener('pointermove',e=>{if(!isActive()||!drag||drag.id!==e.pointerId)return;yaw=THREE.MathUtils.clamp(yaw+(drag.x-e.clientX)*.004,-1.35,1.35);pitch=THREE.MathUtils.clamp(pitch+(e.clientY-drag.y)*.003,-.72,.55);drag.x=e.clientX;drag.y=e.clientY;aim();e.preventDefault()});
 for(const evt of ['pointerup','pointercancel'])canvas.addEventListener(evt,e=>{if(drag?.id===e.pointerId)drag=null});
 reset();return {reset,aim,setPose,useLegacyPose};
}
