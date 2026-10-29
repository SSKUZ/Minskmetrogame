// Advance the actual controller; full browser coverage still opens in real time.
export async function settlePassengerDoors(page,open){
 return page.evaluate(async open=>{
  const i=window.metroPassengerInspector,backings=[],leaves=[];
  i.scene.traverse(o=>{if(o.name==='PassengerPortalBacking')backings.push(o);if(o.name==='PassengerExteriorDoorLeaf')leaves.push(o);});
  const {animateDoorLeaves}=await import('/js/train/TrainDoors.js?v=20261026-smooth-v16');
  const descriptors=leaves.map(leaf=>{
   const portalBacking=backings.find(b=>Math.sign(b.position.x)===Math.sign(leaf.position.x)&&Math.abs(b.position.z-leaf.position.z)<1.57);
   if(!portalBacking)throw new Error('backing not matched');
   return {leaf,portalBacking,doorZ:portalBacking.position.z,half:Math.sign(leaf.position.z-portalBacking.position.z)};
  });
  i.train({doors:open});for(let n=0;n<17;n++)animateDoorLeaves(descriptors,open,.1);
  await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
  return {count:backings.length,leaves:leaves.length,visible:backings.filter(b=>b.visible).length,aperture:i.system.context.aperture};
 },open);
}
