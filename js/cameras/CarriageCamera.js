// Independent carriage camera: mounted high on the LEFT side just behind the driver's cab, looking diagonally through the saloon.
// Swipe remains available, with asymmetric yaw limits so the nearby left wall cannot be crossed while the right sweep can look back toward the cab bulkhead.
export function createCarriageCameraController(THREE,camera,canvas,isActive){
 let yaw=0,pitch=0,drag=null;
 const legacyOrigin=new THREE.Vector3(1.72,2.78,-19.88);
 const legacyForward=new THREE.Vector3(-3.25,-0.20,18.0).normalize();
 const origin=legacyOrigin.clone(),forward=legacyForward.clone();
 let yawMin=-.30,yawMax=1.35,pitchMin=-.42,pitchMax=.28;
 function aim(){camera.position.copy(origin);const direction=forward.clone().applyAxisAngle(new THREE.Vector3(0,1,0),yaw);const right=new THREE.Vector3().crossVectors(direction,new THREE.Vector3(0,1,0)).normalize();direction.applyAxisAngle(right,pitch);
  // lookAt takes a WORLD-space target. The carriage camera is parented to a train group translated along Z.
  const target=origin.clone().add(direction);
  if(camera.parent){camera.parent.updateWorldMatrix(true,false);camera.parent.localToWorld(target);}
  camera.lookAt(target);
 }
 function setPose(nextOrigin,nextForward,limits={}){origin.copy(nextOrigin);forward.copy(nextForward).normalize();yawMin=limits.yawMin??-.30;yawMax=limits.yawMax??1.35;pitchMin=limits.pitchMin??-.42;pitchMax=limits.pitchMax??.28;yaw=0;pitch=0;aim()}
 function useLegacyPose(){origin.copy(legacyOrigin);forward.copy(legacyForward);yawMin=-1.35;yawMax=1.35;pitchMin=-.72;pitchMax=.55;yaw=0;pitch=0;aim()}
 function reset(){yaw=0;pitch=0;aim()}
 canvas.addEventListener('pointerdown',e=>{if(!isActive())return;drag={id:e.pointerId,x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);e.preventDefault()});
 canvas.addEventListener('pointermove',e=>{if(!isActive()||!drag||drag.id!==e.pointerId)return;yaw=THREE.MathUtils.clamp(yaw+(drag.x-e.clientX)*.004,yawMin,yawMax);pitch=THREE.MathUtils.clamp(pitch+(e.clientY-drag.y)*.003,pitchMin,pitchMax);drag.x=e.clientX;drag.y=e.clientY;aim();e.preventDefault()});
 for(const evt of ['pointerup','pointercancel'])canvas.addEventListener(evt,e=>{if(drag?.id===e.pointerId)drag=null});
 reset();return {reset,aim,setPose,useLegacyPose};
}
