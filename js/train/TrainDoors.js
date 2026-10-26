// Door movement is frame-rate independent, and each leaf keeps its own state.
// Approximately 1.5 seconds to open/close; no teleporting at state changes.
const doorProgress=new WeakMap();
function slideDoors(leaves,open,dt,openingOffset,baseOffset=0){
 const step=Math.max(0,Math.min(.1,Number(dt)||0))/1.55;
 for(const d of leaves){
  const prev=doorProgress.get(d.leaf)||0;
  const next=open?Math.min(1,prev+step):Math.max(0,prev-step);
  doorProgress.set(d.leaf,next);
  const eased=next*next*(3-2*next);
  d.leaf.position.z=(d.doorZ??d.leafZ)+d.half*(baseOffset+openingOffset*eased);
 }
}
export function animateDoorLeaves(leaves,open,dt){slideDoors(leaves,open,dt,1.03,.53)}
export function animateCarriageDoors(leaves,open,dt){slideDoors(leaves,open,dt,.92)}
export function canOpenDoors(speed,dist){return speed<1.5&&Math.abs(dist)<32}
