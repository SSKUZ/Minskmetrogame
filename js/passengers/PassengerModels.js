// Detailed 3D passenger model factory, independent of train simulation.
export function createPassengerModelFactory({THREE,platform,passengerOutfits,skins,hairs,dark,personDetail,passengerLip,passengerEyeWhite,passengerIris,passengerSeam,coats}){
return function human(i,x,z){
 const p=new THREE.Group();p.position.set(x,.78,z);platform.add(p);
 const child=i%13===0||i%13===1,elder=i%11===0;
 const scale=child?.64:elder?.89:.91+(i%5)*.036;p.scale.setScalar(scale);
 const archetype=i%6,coat=passengerOutfits[archetype],skin=skins[i%skins.length],hair=hairs[i%hairs.length];
 p.userData.walkLimbs=[];p.userData.gestureArms=[];p.userData.fineDetails=[];
 const torso=new THREE.Mesh(new THREE.CylinderGeometry(.22,.29,.76,16),coat);torso.position.y=1.16;p.add(torso);
 const jacket=new THREE.Mesh(new THREE.SphereGeometry(.245,12,10),coat);jacket.scale.set(1,.85,.69);jacket.position.y=1.39;p.add(jacket);
 for(const side of [-1,1]){
  const leg=new THREE.Mesh(new THREE.CylinderGeometry(.093,.081,.73,12),dark);leg.position.set(side*.13,.40,0);p.add(leg);p.userData.walkLimbs.push({mesh:leg,side,kind:'leg'});
  const shoe=new THREE.Mesh(new THREE.CapsuleGeometry(.088,.14,3,8),dark);shoe.rotation.x=Math.PI/2;shoe.position.set(side*.13,.09,-.08);p.add(shoe);
  const arm=new THREE.Mesh(new THREE.CapsuleGeometry(.077,.46,4,10),coat);arm.position.set(side*.31,1.18,0);arm.rotation.z=side*.16;p.add(arm);
  p.userData.walkLimbs.push({mesh:arm,side,kind:'arm'});p.userData.gestureArms.push(arm);
  const hand=new THREE.Mesh(new THREE.SphereGeometry(.075,10,8),skin);hand.position.set(side*.34,.86,0);p.add(hand);
 }
 const neck=new THREE.Mesh(new THREE.CylinderGeometry(.075,.075,.15,10),skin);neck.position.y=1.67;p.add(neck);
 const face=new THREE.Mesh(new THREE.SphereGeometry(.195,18,14),skin);face.scale.set(1,1.15,.91);face.position.y=1.88;p.add(face);
 const hairTop=new THREE.Mesh(new THREE.SphereGeometry(.198,18,12,0,Math.PI*2,0,Math.PI*.50),hair);hairTop.position.y=1.93;p.add(hairTop);
 // Facial features use shallow 3D geometry, not floating black dots.
 const nose=personDetail(p,new THREE.ConeGeometry(.036,.105,10),skin,0,1.858,-.190);nose.rotation.x=-.35;
 const mouth=personDetail(p,new THREE.CapsuleGeometry(.008,.067,2,8),passengerLip,0,1.778,-.178);mouth.rotation.z=Math.PI/2;
 p.userData.fineDetails.push(nose,mouth);
 for(const side of [-1,1]){
  const ear=personDetail(p,new THREE.SphereGeometry(.052,10,8),skin,side*.191,1.87,0);ear.scale.set(.5,1,.6);
  const eye=personDetail(p,new THREE.SphereGeometry(.027,10,8),passengerEyeWhite,side*.079,1.907,-.169);eye.scale.set(1,.55,.30);
  const iris=personDetail(p,new THREE.SphereGeometry(.011,8,8),passengerIris,side*.079,1.906,-.179);
  const brow=personDetail(p,new THREE.BoxGeometry(.083,.012,.015),hair,side*.081,1.948,-.172);brow.rotation.z=-side*.13;
  p.userData.fineDetails.push(ear,eye,iris,brow);
 }
 // Clothing seams, zipper, collars and stitched patch pockets.
 const zipper=personDetail(p,new THREE.BoxGeometry(.012,.55,.012),passengerSeam,0,1.20,-.198);
 const collarL=personDetail(p,new THREE.BoxGeometry(.10,.14,.023),passengerSeam,-.09,1.53,-.165);
 const collarR=personDetail(p,new THREE.BoxGeometry(.10,.14,.023),passengerSeam,.09,1.53,-.165);
 collarL.rotation.z=-.35;collarR.rotation.z=.35;
 p.userData.fineDetails.push(zipper,collarL,collarR);
 for(const side of [-1,1]){
  const pocket=personDetail(p,new THREE.BoxGeometry(.12,.09,.014),passengerSeam,side*.14,1.02,-.233);
  p.userData.fineDetails.push(pocket);
 }
 if(archetype===2||archetype===4){
  const scarf=personDetail(p,new THREE.TorusGeometry(.12,.038,7,18),coats[(i+2)%coats.length],0,1.61,0);
  scarf.rotation.x=Math.PI/2;p.userData.fineDetails.push(scarf);
 }
 if(archetype===3){
  const glasses=personDetail(p,new THREE.TorusGeometry(.092,.009,6,18),passengerSeam,0,1.906,-.182);
  glasses.scale.x=1.85;p.userData.fineDetails.push(glasses);
 }
 if(i%4===0){const bag=new THREE.Mesh(new THREE.BoxGeometry(.29,.40,.16),dark);bag.position.set(.37,.90,.05);p.add(bag);}
 if(i%4===1){const backpack=new THREE.Mesh(new THREE.BoxGeometry(.36,.54,.20),coats[(i+3)%coats.length]);backpack.position.set(0,1.19,.30);p.add(backpack);}
 if(elder){const cane=new THREE.Mesh(new THREE.CylinderGeometry(.017,.017,.98,8),dark);cane.position.set(.43,.48,-.17);p.add(cane);}
 p.userData.child=child;p.userData.elder=elder;p.rotation.y=(i%5-2)*.35;
 return p;
}

}
