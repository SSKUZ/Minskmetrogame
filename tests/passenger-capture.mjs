import {mkdir,writeFile} from 'node:fs/promises';
import {launchCabBrowser,ready} from './helpers/cab-browser-fixture.mjs';

const output=process.env.PASSENGER_OUTPUT??'artifacts/passengers';
await mkdir(output,{recursive:true});
const fixture=await launchCabBrowser();
try{
 const page=await fixture.page({viewport:{width:1280,height:800}});
 await ready(page,fixture.base+'/?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717');
 await page.waitForFunction(()=>window.metroPassengerInspector?.snapshot().ready,null,{timeout:120000});
 await page.evaluate(()=>{const i=window.metroPassengerInspector;i.pause();i.view([-9,2.7,15],[-5,1.7,22],58);});
 await page.screenshot({path:output+'/checkpoint-platform.png',timeout:120000});
 console.log('Platform captured');
 const agent=await page.evaluate(()=>{const i=window.metroPassengerInspector,s=i.snapshot();const a=s.agents.find(a=>a.space==='platform'&&a.profile===0);i.focus(a.id,2.8);return a;});
 await page.screenshot({path:output+'/checkpoint-close.png',timeout:120000});
 console.log('Close-up captured',agent.id);
 await writeFile(output+'/checkpoint-browser.json',JSON.stringify({snapshot:await page.evaluate(()=>window.metroPassengerInspector.snapshot()),errors:fixture.errors,requests:fixture.requests},null,2));
 if(fixture.errors.length||fixture.requests.length)throw new Error(JSON.stringify({errors:fixture.errors,requests:fixture.requests}));
}finally{await fixture.close();}
