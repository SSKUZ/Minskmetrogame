// Original cab shell geometry. No changes to dimensions or materials.
// Independent from controls, physics, mirrors and display updates.
export function buildCabFrontShell({cab,box,cabShell,cabEdge,cabRubber}){
 box(cab,6.8,.25,2.3,0,1.37,3.55,cabShell);
 box(cab,6.6,.42,.2,0,1.63,2.55,cabEdge);
 box(cab,6.5,.22,.25,0,1.25,4.5,cabRubber);
 for(const x of [-3.1,3.1]){
  box(cab,.7,.7,2.15,x,1.56,3.5,cabShell);
  box(cab,.14,1.9,.17,x,2.55,2.47,cabEdge);
 }
}
export function buildCabRearShell({cab,box,mat,sideInterior,windowFrame,cabMetal}){
 const floorRubber=mat(0x343a3c),floorRib=mat(0x535b5c),rearTrim=mat(0x666e71);
 box(cab,8.25,.23,9.8,0,.53,4.5,floorRubber);
 for(let i=0;i<23;i++)box(cab,7.8,.018,.055,0,.67,.05+i*.40,floorRib);
 box(cab,8.2,2.95,.23,0,2.15,9.38,sideInterior);
 box(cab,8.1,.19,9.7,0,4.35,4.48,sideInterior);
 for(const side of [-1,1]){
  box(cab,.23,3.5,4.1,side*4.03,2.32,7.2,sideInterior);
  box(cab,.18,.18,2.3,side*3.96,3.58,5.9,windowFrame);
  box(cab,.24,1.15,1.15,side*3.87,2.13,7.7,rearTrim);
  box(cab,.05,.8,.18,side*3.65,2.14,7.7,cabMetal);
 }
 box(cab,2.1,2.8,.19,0,2.16,9.21,rearTrim);
 box(cab,.65,.15,.22,0,2.25,9.07,cabMetal);
}
