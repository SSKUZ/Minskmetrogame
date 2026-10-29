// Reproducible seasonal layers fitted and skinned by the existing Ara pipeline.
// Uses the same pinned source and body/rig as the accepted passenger assets.
import {pathToFileURL} from 'node:url';
import {join} from 'node:path';
export async function registerMinskWardrobe(source:string){
 const load=(p:string)=>import(pathToFileURL(join(source,p)).href);
 const {GARMENTS,garmentById}=await load('src/core/garments/catalog.ts');
 const {cm,REGION}=await load('src/core/garments/body.ts');
 const {shellPart,cloth,isTrunk,skirt,torsoY,mat,points}=await load('src/core/garments/kit.ts');
 const {ellipsoid,frameOf,cord,merge}=await load('src/core/garments/ring.ts');
 const frontAt=(b:any,y:number)=>{const p=points(b,(v:any)=>isTrunk(v)).filter((p:any)=>Math.abs(p[0])<cm(3)&&Math.abs(p[1]-y)<cm(3));return p.length?Math.max(...p.map((p:any)=>p[2]))+cm(2.1):b.L.torsoZ+cm(13);};
 const top=(g:any,st:any,name:string,hood=false)=>{
  const tn=cm(hood?5:2)/(g.body.L.neckY-g.body.L.hipY);
  const parts=shellPart(g,{covers:(v:any)=>(isTrunk(v)&&v.t>.03)||(v.region===REGION.neck&&v.t<1+tn)||v.region===REGION.upperarm||(v.region===REGION.lowerarm&&v.t<.96),
   offset:(v:any)=>cm(hood&&v.region===REGION.neck?2.4:1.25),tile:.20,relax:3},cloth(g,name,st));
  if(hood&&name==='Minsk hoodie'){
   const b=g.body,centre=[0,b.L.neckY-cm(7),b.L.torsoZ-cm(11)];
   parts.push({mesh:ellipsoid(frameOf(centre,[0,0,1],[0,1,0]),[cm(10),cm(9),cm(3.5)],[.25,.25],12,6),material:cloth(g,'Minsk hood fold',st)});
   const strings=[-1,1].map(side=>cord([[side*cm(3),b.L.neckY-cm(3),frontAt(b,b.L.neckY-cm(6))],[side*cm(3.5),b.L.neckY-cm(19),frontAt(b,b.L.neckY-cm(19))+cm(.4)]],cm(.18),false,5));
   parts.push({mesh:merge(strings),material:mat('Minsk drawstrings',null,{color:'#b8b6ae',roughness:.9})});
  }
  return parts;
 };
 GARMENTS.push(
  {id:'minsk_sweater',label:'Crew-neck sweater',slot:'top',patterns:['solid'],color:'#596474',color2:'#343d4b',build:(g:any,st:any)=>top(g,st,'Minsk knit sweater')},
  {id:'minsk_hoodie',label:'Hoodie with lowered collar',slot:'top',patterns:['solid'],color:'#777a79',color2:'#4c5356',build:(g:any,st:any)=>top(g,st,'Minsk hoodie',true)},
  {id:'minsk_coat',label:'Buttoned wool coat',slot:'top',patterns:['solid'],color:'#4d535c',color2:'#303640',build:(g:any,st:any)=>{
   const parts=top(g,st,'Minsk wool coat',true),b=g.body,knee=b.joint('lowerleg01.L____head')[1];
   const hem=skirt(b,torsoY(b,.22),b.L.hipY-(b.L.hipY-knee)*.72,cm(2),.045);
   if(hem)parts.push({mesh:hem,material:{...cloth(g,'Minsk coat hem',st),doubleSided:true}});
   const buttons=[.28,.43,.58,.73].map(t=>{const y=torsoY(b,t);return ellipsoid(frameOf([0,y,frontAt(b,y)+cm(.4)],[0,0,1],[0,1,0]),[cm(.65),cm(.65),cm(.3)],[.05,.05],8,4);});
   parts.push({mesh:merge(buttons),material:mat('Minsk coat buttons',null,{color:'#383d42',roughness:.6})});
   const seam=[.23,.35,.48,.61,.74,.83].map(t=>{const y=torsoY(b,t);return [0,y,frontAt(b,y)];});
   parts.push({mesh:cord(seam,cm(.15),false,4),material:mat('Minsk coat seam',null,{color:'#454d55',roughness:.9})});
   return parts;
  }});
 for(const garment of GARMENTS)if(garment.id.startsWith('minsk_'))garmentById.set(garment.id,garment);
}
export const seasonalRecipes:any={
 'man-jacket':{outfit:'male_casualsuit05'},
 'woman-coat':{outfit:'none',top:'minsk_coat',bottom:'uniform_trousers',garmentStyles:{minsk_coat:{color:'#68717a'},uniform_trousers:{color:'#303943'}}},
 'man-hoodie':{outfit:'none',top:'minsk_hoodie',bottom:'uniform_trousers',garmentStyles:{minsk_hoodie:{color:'#6b747e'},uniform_trousers:{color:'#344357'}}},
 'woman-skirt':{outfit:'female_elegantsuit01',outfitTint:'#9daca5'},
 'elder-man':{hairColor:'#b3b1ab'},
 'elder-woman':{hairColor:'#b3b1ab',outfit:'none',top:'minsk_coat',bottom:'uniform_trousers',garmentStyles:{minsk_coat:{color:'#8a7564'},uniform_trousers:{color:'#434442'}}},
 'boy':{outfit:'none',top:'minsk_sweater',bottom:'uniform_trousers',garmentStyles:{minsk_sweater:{color:'#3f5775'},uniform_trousers:{color:'#384554'}}},
 'girl':{outfit:'none',top:'minsk_hoodie',bottom:'uniform_trousers',garmentStyles:{minsk_hoodie:{color:'#8a6270'},uniform_trousers:{color:'#414854'}}},
 'man-casual':{outfit:'male_casualsuit01'},
 'woman-suit':{outfit:'none',top:'minsk_sweater',bottom:'uniform_trousers',garmentStyles:{minsk_sweater:{color:'#b0a49a'},uniform_trousers:{color:'#3c434b'}}},
};
