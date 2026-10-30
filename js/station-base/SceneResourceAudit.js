// Read-only scene inventory. Counts are CPU-side estimates, not measured GPU draw calls.
export function auditSceneResources({scene,train,secondTrain,stationView,renderer}){
 const groups=[['station',stationView?.root],['player-v106',train?.root],['opposing-v106',secondTrain?.root]];
 const seenGeometries=new Set(),seenMaterials=new Set(),seenTextures=new Set();
 const allMaterials=new Set(),allTextures=new Set();
 const bytes={geometry:0,texturesEstimated:0};
 const scan=(name,root)=>{
  const geometries=new Set(),materials=new Set(),textures=new Set();
  const out={name,objects:0,meshes:0,visibleMeshes:0,instancedMeshes:0,instances:0,triangles:0,visibleTriangles:0,materialSlots:0,layerSlots:{},byLayer:{},geometries:0,materials:0,textures:0};
  if(!root)return out;
  root.traverse(o=>{
   out.objects++;
   if(!o.isMesh)return;
   out.meshes++;if(o.visible)out.visibleMeshes++;
   if(o.isInstancedMesh){out.instancedMeshes++;out.instances+=o.count;}
   const g=o.geometry;if(g){geometries.add(g);const count=g.index?.count??g.attributes.position?.count??0;const tri=count/3*(o.isInstancedMesh?o.count:1);out.triangles+=tri;if(o.visible)out.visibleTriangles+=tri;}
   const mats=Array.isArray(o.material)?o.material:[o.material];out.materialSlots+=mats.length;
   for(const m of mats){if(!m)continue;materials.add(m);for(const value of Object.values(m))if(value?.isTexture)textures.add(value);}
   for(let i=0;i<32;i++)if(o.layers.mask&(1<<i)){out.layerSlots[i]=(out.layerSlots[i]||0)+1;out.byLayer[i]=(out.byLayer[i]||0)+(g?(g.index?.count??g.attributes.position?.count??0)/3*(o.isInstancedMesh?o.count:1):0);}
  });
  out.geometries=geometries.size;out.materials=materials.size;out.textures=textures.size;
  for(const g of geometries)if(!seenGeometries.has(g)){seenGeometries.add(g);for(const a of Object.values(g.attributes||{})){if(a.array?.byteLength)bytes.geometry+=a.array.byteLength;}if(g.index?.array?.byteLength)bytes.geometry+=g.index.array.byteLength;}
  for(const m of materials){seenMaterials.add(m);allMaterials.add(m);}
  for(const t of textures){allTextures.add(t);}
  for(const t of textures)seenTextures.add(t);
  return out;
 };
 const topMeshes=[];
 for(const [group,root] of groups)root?.traverse(o=>{
  if(!o.isMesh||!o.geometry)return;
  const geometry=o.geometry;
  const triangles=(geometry.index?.count??geometry.attributes.position?.count??0)/3*(o.isInstancedMesh?o.count:1);
  const materials=Array.isArray(o.material)?o.material.length:1;
  topMeshes.push({group,name:o.name||o.type,triangles,materials,visible:o.visible,layerMask:o.layers.mask,proxy:!!o.userData?.renderOnlyLODProxy});
 });
 topMeshes.sort((a,b)=>b.triangles-a.triangles);
 const topByTriangles=topMeshes.slice(0,30);
 const topByMaterialSlots=[...topMeshes].sort((a,b)=>b.materials-a.materials).slice(0,30);
 const components=groups.map(([name,root])=>scan(name,root));
 for(const t of seenTextures){const img=t.image??t.source?.data;if(img?.width&&img?.height)bytes.texturesEstimated+=img.width*img.height*4;}
 return {kind:'CPU scene inventory (not GPU benchmark)',timestamp:new Date().toISOString(),components,topByTriangles,topByMaterialSlots,unique:{geometries:seenGeometries.size,materials:allMaterials.size,textures:allTextures.size},bytes,rendererInfo:renderer?{calls:renderer.info.render.calls,triangles:renderer.info.render.triangles,geometries:renderer.info.memory.geometries,textures:renderer.info.memory.textures}:null,notes:['Triangle totals are raw geometry counts; they do not account for frustum culling or overlapping render passes.','Geometry byte count is an approximate unique BufferGeometry attribute total; texture estimate assumes 4 bytes/pixel, no mipmaps or compression.','Draw calls must be measured per render pass on an active WebGL renderer.']};
}
