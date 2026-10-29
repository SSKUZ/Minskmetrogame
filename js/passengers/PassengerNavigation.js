import {PLATFORM,COLUMNS,clamp} from './PassengerConfig.js';

// Deterministic short detours around the station's actual column footprints.
export function platformPath(from,to,radius=.24){
 const target={x:clamp(to.x,PLATFORM.minX,PLATFORM.maxX),z:clamp(to.z,PLATFORM.minZ,PLATFORM.maxZ)};
 for(const c of COLUMNS)if(Math.hypot(target.x-c.x,target.z-c.z)<c.radius+radius+.15)
  target.x=c.x+(target.x>=c.x?1:-1)*(c.radius+radius+.20);
 const path=[];let start={x:from.x,z:from.z};
 for(let attempt=0;attempt<8;attempt++){
  const dx=target.x-start.x,dz=target.z-start.z,d2=dx*dx+dz*dz;
  let hit=null,best=Infinity;
  for(const c of COLUMNS){
   const t=clamp(((c.x-start.x)*dx+(c.z-start.z)*dz)/(d2||1),0,1);
   if(t<.015||t>.995)continue;
   const d=Math.hypot(start.x+dx*t-c.x,start.z+dz*t-c.z);
   if(d<c.radius+radius+.15&&t<best){best=t;hit=c;}
  }
  if(!hit)break;
  const side=start.x>hit.x?1:-1;
  const p={x:hit.x+side*(hit.radius+radius+.38),z:hit.z};
  path.push(p);start=p;
 }
 path.push(target);return path;
}

export class PassengerNavigation{
 constructor(){this.buckets=new Map();this.cellSize=1.2;}
 rebuild(agents){
  this.buckets.clear();
  for(const a of agents){
   if(a.state==='gone')continue;
   const key=this.key(a.x,a.z,a.space);let bucket=this.buckets.get(key);
   if(!bucket)this.buckets.set(key,bucket=[]);bucket.push(a);
  }
 }
 key(x,z,space){return `${space}:${Math.floor(x/this.cellSize)}:${Math.floor(z/this.cellSize)}`;}
 neighbors(a,x=a.x,z=a.z){
  const result=[],cx=Math.floor(x/this.cellSize),cz=Math.floor(z/this.cellSize);
  for(let ix=-1;ix<=1;ix++)for(let iz=-1;iz<=1;iz++){
   const bucket=this.buckets.get(`${a.space}:${cx+ix}:${cz+iz}`);if(bucket)result.push(...bucket);
  }
  return result;
 }
 move(a,dt){
  const next=a.path[0];if(!next){a.velocity=0;return false;}
  const dx=next.x-a.x,dz=next.z-a.z,dist=Math.hypot(dx,dz);
  if(dist<.045){a.x=next.x;a.z=next.z;a.path.shift();a.velocity=0;return !a.path.length;}
  const speed=Math.min(a.walkSpeed,a.velocity+dt*1.8,Math.max(.16,dist*3));
  const step=Math.min(dist,speed*dt);let nx=a.x+dx/dist*step,nz=a.z+dz/dist*step;
  const neighbors=this.neighbors(a,nx,nz).filter(o=>o!==a&&o.state!=='gone'&&o.state!=='seated');
  const clear=(x,z)=>neighbors.every(o=>{
   const min=a.radius+o.radius+.025,old=Math.hypot(a.x-o.x,a.z-o.z),d=Math.hypot(x-o.x,z-o.z);
   return d>=min||d>old+.00001;
  });
  if(!clear(nx,nz)){
   const heading=Math.atan2(dx,dz);let best=null,bestScore=-Infinity;
   for(const angle of [.55,-.55,1.05,-1.05,1.55,-1.55,2.15,-2.15]){
    const x=a.x+Math.sin(heading+angle)*step,z=a.z+Math.cos(heading+angle)*step;
    if(!clear(x,z))continue;
    if(a.space==='platform'&&x>PLATFORM.maxX&&!['boarding','alighting'].includes(a.state))continue;
    const score=Math.cos(angle)+neighbors.reduce((s,o)=>s+Math.min(1,Math.hypot(x-o.x,z-o.z))*.1,0);
    if(score>bestScore){bestScore=score;best={x,z};}
   }
   nx=best?.x??a.x;nz=best?.z??a.z;
  }
  const service=['boarding','alighting','returning'].includes(a.state);
  if(a.space==='train'&&!service)nx=clamp(nx,-1.82,1.25);
  if(a.space==='platform'&&!service){nx=clamp(nx,PLATFORM.minX,PLATFORM.maxX);nz=clamp(nz,PLATFORM.minZ,PLATFORM.maxZ);}
  if(a.space==='platform')for(const c of COLUMNS){
   const cx=nx-c.x,cz=nz-c.z,d=Math.hypot(cx,cz),min=c.radius+a.radius;
   if(d<min){nx=c.x+cx/(d||1)*min;nz=c.z+cz/(d||1)*min;}
  }
  const travelled=Math.hypot(nx-a.x,nz-a.z);
  a.velocity=travelled/dt;a.distance+=travelled;
  if(travelled>1e-5)a.targetHeading=Math.atan2(nx-a.x,nz-a.z); // GLB faces +Z.
  a.x=nx;a.z=nz;return false;
 }
}
