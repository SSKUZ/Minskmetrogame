import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {PassengerSimulation} from '../../js/passengers/PassengerBehavior.js';

const seed=Number(process.env.PASSENGER_SEED??717),count=Number(process.env.PASSENGER_STATIONS??12);
const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers/tz2-resume';
const s=new PassengerSimulation({seed}),report={seed,stations:[]};
await mkdir(output,{recursive:true});
const save=()=>writeFile(output+'/exchange-report.json',JSON.stringify(report,null,2)+'\n');
const advance=(seconds,context)=>{for(let n=0;n<seconds*30;n++)s.update(1/30,context);};
const busy=()=>!s.boarding.opened||s.boarding.queues.some(q=>q.enter.length||q.exit.length);
for(let station=0;station<count;station++){
 const closed={station,dist:0,speed:0,doorsOpen:false,aperture:0},open={...closed,doorsOpen:true,aperture:1};
 advance(2,{...closed,dist:900,speed:55});
 let dwell=null;
 for(let n=0;n<3600;n++){s.update(1/30,open);if(dwell===null&&!busy())dwell=(n+1)/30;}
 for(let extra=0;extra<180&&busy();extra++){
  for(let n=0;n<30;n++){s.update(1/30,open);if(dwell===null&&!busy())dwell=120+extra+(n+1)/30;}
 }
 if(busy()){
  report.passed=false;report.failure={station,snapshot:s.snapshot(),paths:s.agents.filter(a=>a.path.length).map(a=>({id:a.id,path:a.path}))};
  await save();
 }
 assert.ok(!busy(),`station ${station}: incomplete exchange`);
 const events=s.events.filter(e=>e.station===station),sequence=s.eventSequence;
 advance(2,closed);advance(5,open);assert.equal(s.eventSequence,sequence,'reopening duplicate');
 const result={station,dwell,boardings:events.filter(e=>e.kind==='board').length,alightings:events.filter(e=>e.kind==='alight').length,onboard:s.snapshot().onboard};
 report.stations.push(result);await save();console.log(JSON.stringify(result));
}
report.passed=true;report.maxDwell=Math.max(...report.stations.map(s=>s.dwell));
await save();
