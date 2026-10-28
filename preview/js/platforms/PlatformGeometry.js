// Station approach and platform furniture geometry.
export function buildPlatformApproach({platform,box,approachRailBed,rail,wood}){
box(platform,6.4,.3,48,0,-.30,29,approachRailBed);
for(const x of [-1.15,1.15])box(platform,.12,.16,48,x,.05,29,rail);
for(let j=0;j<24;j++)box(platform,3.3,.10,.24,0,-.06,6+j*2,wood);
}
export function buildPlatformFurniture({THREE,platform,box,wood,steel}){
// Platform signage and benches.
for(let i=0;i<6;i++){box(platform,1.6,.12,.55,-4.85,.85,-8-i*18,wood);box(platform,.1,.8,.1,-5.45,.43,-8-i*18,steel);box(platform,.1,.8,.1,-4.3,.43,-8-i*18,steel)}
const signCanvas=document.createElement('canvas');signCanvas.width=768;signCanvas.height=128;const sc=signCanvas.getContext('2d');const texture=new THREE.CanvasTexture(signCanvas);const sign=new THREE.Mesh(new THREE.PlaneGeometry(4.5,.75),new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide}));sign.rotation.y=Math.PI/2;sign.position.set(-4.7,5.5,-15);platform.add(sign);
return {signCanvas,sc,texture,sign};
}
