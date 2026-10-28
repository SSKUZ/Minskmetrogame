// Adapter only: the existing train physics and door validation remain authoritative.
export function createCabCommands({getTrain,setLever,setDoors,info,setHeadlights,setMirror,camera,notify,horn,setVolume}){
 const switches={cabLight:1,headlights:1,wiperLeft:0,wiperRight:0,mirrorLeft:1,mirrorRight:1,volume:.6};
 let lampTest=false,hornActive=false,lastAction=null;
 const supported=new Set(['master','brake','open','close','toggleDoors','info','release','service','emergency','lampTest','reset','horn','cabLight','headlights','wiperLeft','wiperRight','mirrorLeft','mirrorRight','volume','carriage','platform','forward','desk']);
 function command(id,value,phase='press'){
  if(!supported.has(id)){notify('Система не моделируется · '+id);return {ok:false,reason:'unsupported'};}
  const train=getTrain();let ok=true;
  if(id==='master'||id==='brake')setLever(Math.max(-1,Math.min(1,Number(value)||0)));
  else if(id==='release')setLever(0);
  else if(id==='service')setLever(-.5);
  else if(id==='emergency')setLever(-1);
  else if(id==='open'||id==='close'||id==='toggleDoors'){
   const open=id==='toggleDoors'?!train.doors:id==='open';setDoors(open);ok=getTrain().doors===open;
  }else if(id==='info')info();
  else if(id==='lampTest')lampTest=phase!=='release';
  else if(id==='reset')lampTest=false;
  else if(id==='horn'){const active=phase!=='release';ok=horn(active)!==false;hornActive=active&&ok;}
  else if(['carriage','platform','forward','desk'].includes(id))ok=camera(id)!==false;
  else {
   switches[id]=id==='volume'?(switches[id]+.25>1?0:switches[id]+.25):1-switches[id];
   if(id==='headlights')setHeadlights(Boolean(switches[id]));
   if(id==='mirrorLeft'||id==='mirrorRight')setMirror(id==='mirrorLeft'?-1:1,Boolean(switches[id]));
   if(id==='volume')setVolume(switches.volume);
  }
  lastAction={id,ok,phase};return lastAction;
 }
 function snapshot(){return {...getTrain(),lampTest,hornActive,switches:{...switches},lastAction:lastAction&&{...lastAction}};}
 return {command,snapshot,supported};
}
