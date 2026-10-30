import {randomSource,clamp} from './PassengerConfig.js';
import {standingPlaceKeepsDoorsClear} from './PassengerPlaces.js';

function groups(people){
 const map=new Map();
 for(const a of people){const key=a.groupId===null?'person:'+a.id:'group:'+a.groupId;if(!map.has(key))map.set(key,[]);map.get(key).push(a);}
 return [...map.values()];
}
function shuffled(items,rng){
 const result=[...items];for(let i=result.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[result[i],result[j]]=[result[j],result[i]];}return result;
}
export function routeCarCapacity(layout,car){
 return Math.max(0,car.seatAnchors.length+car.standingZones.filter(p=>standingPlaceKeepsDoorsClear(p,layout,car.id)).length-2);
}
export function routeLoadFactor(station,stationCount){
 if(station>=stationCount-1)return 0;
 if(station===stationCount-2)return .16;
 const t=clamp(station/(stationCount-1),0,1),knots=[[0,.42],[.30,.95],[.45,1],[.60,1],[.80,.55],[1,0]];
 for(let i=1;i<knots.length;i++)if(t<=knots[i][0]){const [x,y]=knots[i-1],[nx,ny]=knots[i];return y+(ny-y)*(t-x)/(nx-x);}
 return 0;
}

// A stop-level demand policy; movement, queues, identities and animations stay
// in the existing simulation. Nobody is removed from the train by this policy.
export function planRouteExchange(agents,layout,{station,stationCount,seed}){
 const rng=randomSource(seed+station*190081+0x717),terminal=station===stationCount-1;
 const onboard=agents.filter(a=>a.space==='train'&&a.state!=='gone'),platform=agents.filter(a=>a.space==='platform');
 const factor=routeLoadFactor(station,stationCount),progress=station/(stationCount-1);
 const tail=progress<=.65?1:clamp((stationCount-2-station)/((stationCount-1)*.35-1),0,1);
 const demand=terminal?0:Math.round((30+Math.floor(rng()*5))*tail);
 const carOrder=shuffled(layout.cars,rng),base=Math.floor(demand/carOrder.length),extra=demand%carOrder.length;
 const quotas=new Map(carOrder.map((car,i)=>[car.id,base+(i<extra?1:0)]));
 const cars=[],out=new Set();
 for(const car of layout.cars){
  const capacity=routeCarCapacity(layout,car),peak=Math.min(28,Math.floor(capacity*.85));
  const target=terminal?0:Math.round(peak*factor),people=onboard.filter(a=>a.car===car.id);
  const wanted=terminal?people.length:Math.max(0,people.length+quotas.get(car.id)-target);
  let exiting=0;
  const units=shuffled(groups(people),rng),doors=layout.doors.filter(d=>d.car===car.id&&d.available!==false),loads=new Map(doors.map(d=>[d.id,0]));
  // Pick intact groups near different exits, rather than sending a random
  // bunch from one end of a car through a long sequential aisle queue.
  while(exiting<wanted&&units.length){
   const remaining=wanted-exiting,fit=units.some(g=>g.length<=remaining);let best=null;
   for(let i=0;i<units.length;i++){
    const unit=units[i];if(fit&&unit.length>remaining)continue;
    const door=doors.reduce((best,d)=>Math.max(...unit.map(a=>Math.abs(a.z-d.z)))<Math.max(...unit.map(a=>Math.abs(a.z-best.z)))?d:best);
    const walk=Math.max(...unit.map(a=>Math.abs(a.z-door.z)/a.walkSpeed));
    const score=loads.get(door.id)*3+walk;
    if(!best||score<best.score)best={i,unit,door,score};
   }
   if(!best)break;
   units.splice(best.i,1);for(const a of best.unit){out.add(a.id);a.routeExitDoor=best.door.id;}
   loads.set(best.door.id,loads.get(best.door.id)+best.unit.length);exiting+=best.unit.length;
  }
  const retained=people.length-exiting;
  cars.push({id:car.id,capacity,peak,target,before:people.length,exiting,boarding:Math.max(0,Math.min(quotas.get(car.id),target-retained,capacity-retained))});
 }
 for(const a of onboard){a.destination=out.has(a.id)?station:stationCount-1;if(!out.has(a.id))a.routeExitDoor=undefined;}
 for(const a of platform){a.wantsBoard=false;a.boardingCar=undefined;a.destination=stationCount-1;}
 const pool=shuffled(groups(platform),rng),selected=new Set();
 for(const car of carOrder){
  const plan=cars.find(c=>c.id===car.id);let free=plan.boarding,boarded=0;
  const center=group=>group.reduce((s,a)=>s+a.z,0)/group.length;
  const nearest=group=>layout.cars.reduce((best,c)=>Math.abs(center(group)-c.centerZ)<Math.abs(center(group)-best.centerZ)?c:best).id;
  const candidates=pool.filter(g=>!selected.has(g)).sort((a,b)=>(nearest(a)===car.id?0:1)-(nearest(b)===car.id?0:1));
  for(const unit of candidates){
   if(unit.length>free)continue;
   for(const a of unit){a.wantsBoard=true;a.boardingCar=car.id;a.preferSeat=rng()<.8;}
   selected.add(unit);free-=unit.length;boarded+=unit.length;if(!free)break;
  }
  plan.boarding=boarded;
 }
 return {station,stationCount,terminal,phase:terminal?'terminal':progress<.30?'growing':progress<=.60?'peak':'declining',factor,demand,boarding:cars.reduce((s,c)=>s+c.boarding,0),exiting:out.size,target:cars.reduce((s,c)=>s+c.target,0),peakCapacity:cars.reduce((s,c)=>s+c.peak,0),cars};
}
