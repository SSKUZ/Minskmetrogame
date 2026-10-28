// Non-interactive surface detailing for the existing 81-717 cab desk.
// All meshes are deliberately shallow and leave the interactive hit targets intact.
export function detailCabInstrumentDeck({THREE,instrumentDeck,cabMetal,cabRubber}){
 const trim=new THREE.MeshStandardMaterial({color:0x707b80,metalness:.62,roughness:.42});
 const inset=new THREE.MeshStandardMaterial({color:0x20292e,metalness:.18,roughness:.72});
 const white=new THREE.MeshBasicMaterial({color:0xc4d0d0});
 const amber=new THREE.MeshBasicMaterial({color:0xc58f48});
 const parts=new THREE.Group();parts.name='CabDeskSurfaceDetails';instrumentDeck.add(parts);
 function strip(w,d,x,z,material,y=.091){
  const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,.009,d),material);
  mesh.position.set(x,y,z);parts.add(mesh);return mesh;
 }
 // Continuous brushed aluminium outer lip and fine recessed seams.
 strip(5.83,.025,0,-.613,trim,.095);
 strip(5.83,.018,0,1.012,trim,.091);
 for(const x of [-2.88,2.88])strip(.022,1.59,x,.198,trim,.09);
 // Three independently serviceable control-panel sections.
 for(const x of [-1.79,-.18,1.65]){
  strip(.018,1.36,x+.72,.18,inset,.088);
  for(const z of [-.46,.87]){
   const screw=new THREE.Mesh(new THREE.CylinderGeometry(.022,.022,.006,12),cabMetal);
   screw.position.set(x+.53,.105,z);parts.add(screw);
   const slot=strip(.026,.005,x+.53,z,cabRubber,.111);slot.rotation.y=Math.PI/4;
  }
 }
 // Fine, low-contrast index marks beside the original rotary gauges.
 for(let i=0;i<8;i++){
  const x=-2.65+i*.75;
  for(let j=0;j<7;j++){
   const a=(j/6)*Math.PI*.84+Math.PI*.08;
   const mark=strip(.008,.032,x+Math.cos(a)*.145,-.64+Math.sin(a)*.145,j===6?amber:white,.104);
   mark.rotation.y=-a;
  }
 }
 // Small ventilation slots along the rear edge of the console.
 for(let i=0;i<24;i++)strip(.11,.018,-2.63+i*.228,.745,inset,.098);
 return parts;
}
