// Existing cab instrument-deck geometry, extracted without changing dimensions.
// Keep game state and dynamic screen rendering in the caller.
export function createCabInstrumentDeck({THREE,cab,box,cabShell,cabEdge}){
 const instrumentDeck=new THREE.Group();
 instrumentDeck.position.set(0,1.79,3.24);
 instrumentDeck.rotation.x=.39;
 cab.add(instrumentDeck);
 box(instrumentDeck,6.0,.13,1.32,0,0,0,cabShell);
 function cabScreen(x,z,w,h,colour){
  const g=new THREE.Group();g.position.set(x,.12,z);instrumentDeck.add(g);
  box(g,w+.13,.12,h+.12,0,0,0,cabEdge);
  box(g,w,.025,h,0,.076,0,new THREE.MeshBasicMaterial({color:colour}));
  return g;
 }
 return {instrumentDeck,cabScreen};
}
