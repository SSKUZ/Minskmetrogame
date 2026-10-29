import {PLATFORM,COLUMNS,clamp} from './PassengerConfig.js';

// Deterministic short detours around the station's actual column footprints.
export function platformPath(from,to,radius=.24){
 const target={x:clamp(to.x,PLATFORM.minX,PLATFORM.maxX),z:clamp(to.z,PLATFORM.minZ,PLATFORM.maxZ)};
 for(const c of COLUMNS)if(Math.hypot(target.x-c.x,target.z-c.z)<c.radius+radius+.15)
  target.x=c.x+(target.x>=c.x?1:-1)*(c.radius+radius+.20);
 return crowdDetour({...from,radius,space:'platform'},target,[])??[target];
}

// Only used after sustained lack of progress. Unlike short steering turns this
// search can initially walk away from the goal to get behind a stationary queue.
export function crowdDetour(agent,target,agents){
 const obstacles=[...COLUMNS.map(c=>({...c,r:c.radius+agent.radius+.035})),
  ...agents.filter(o=>o!==agent&&o.space===agent.space&&o.state!=='gone'&&o.state!=='seated')
   .map(o=>({x:o.x,z:o.z,r:o.radius+agent.radius+.045}))];
 const clear=(from,to)=>obstacles.every(o=>{
  const dx=to.x-from.x,dz=to.z-from.z,d2=dx*dx+dz*dz;
  const t=clamp(((o.x-from.x)*dx+(o.z-from.z)*dz)/(d2||1),0,1);
  const start=Math.hypot(from.x-o.x,from.z-o.z),end=Math.hypot(to.x-o.x,to.z-o.z);
  if(start<o.r)return end>start+.00001&&(from.x-o.x)*dx+(from.z-o.z)*dz>=-.00001;
  return Math.hypot(from.x+dx*t-o.x,from.z+dz*t-o.z)>=o.r;
 });
 if(clear(agent,target))return [target];
 const spacing=.32,minX=Math.max(PLATFORM.minX,Math.min(agent.x,target.x)-3.2),
  maxX=Math.min(PLATFORM.maxX,Math.max(agent.x,target.x)+3.2),
  minZ=Math.max(PLATFORM.minZ,Math.min(agent.z,target.z)-3.2),
  maxZ=Math.min(PLATFORM.maxZ,Math.max(agent.z,target.z)+3.2);
 const nodes=[{x:agent.x,z:agent.z,g:0,h:Math.hypot(target.x-agent.x,target.z-agent.z),parent:null,key:'start'}];
 const best=new Map();let found=null;
 for(let visited=0;nodes.length&&visited<2400;visited++){
  nodes.sort((a,b)=>(b.g+b.h)-(a.g+a.h));const current=nodes.pop();
  if(current.key!=='start'&&best.get(current.key)!==current)continue;
  if(clear(current,target)){found=current;break;}
  for(let ix=-1;ix<=1;ix++)for(let iz=-1;iz<=1;iz++){
   if(!ix&&!iz)continue;
   const gx=Math.round((current.x-minX)/spacing)+ix,gz=Math.round((current.z-minZ)/spacing)+iz,
    x=minX+gx*spacing,z=minZ+gz*spacing,key=gx+':'+gz;
   if(x<minX||x>maxX||z<minZ||z>maxZ)continue;
   const next={x,z,g:current.g+Math.hypot(x-current.x,z-current.z),h:Math.hypot(x-target.x,z-target.z),parent:current,key};
   if(best.has(key)&&best.get(key).g<=next.g)continue;
   if(!clear(current,next))continue;best.set(key,next);nodes.push(next);
  }
 }
 if(!found)return null;
 const route=[target];for(let n=found;n.parent;n=n.parent)route.unshift({x:n.x,z:n.z});
 // Retain only turns whose intervening segment is actually clear.
 const path=[];let from=agent;
 for(let i=0;i<route.length;){let end=i;while(end+1<route.length&&clear(from,route[end+1]))end++;
  path.push(route[end]);from=route[end];i=end+1;}
 return path;
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
  if(a.navigationGoal!==next){a.navigationGoal=next;a.navigationBest=Infinity;a.navigationStall=0;}
  const dx=next.x-a.x,dz=next.z-a.z,dist=Math.hypot(dx,dz);
  if(dist<a.navigationBest-.04){a.navigationBest=dist;a.navigationStall=0;}else a.navigationStall+=dt;
  if(a.space==='platform'&&a.navigationStall>1.5){
   a.navigationStall=0;
   const goal=next.detourGoal??next,detour=crowdDetour(a,goal,[...this.buckets.values()].flat());
   if(detour&&detour.length>1){
    const end=a.path.indexOf(goal);for(const p of detour)if(p!==goal)p.detourGoal=goal;
    a.path.splice(0,end>=0?end+1:1,...detour);return this.move(a,dt);
   }
  }
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
