import {writeFile,mkdir} from 'node:fs/promises';
import {launchCabBrowser} from '../../tests/helpers/cab-browser-fixture.mjs';
import {PROFILES} from '../../js/passengers/PassengerConfig.js';
const fixture=await launchCabBrowser();
try{
 const p=await fixture.page({viewport:{width:800,height:600}});p.on('console',m=>{if(m.type()==='error')console.error(m.text());});
 await p.goto(fixture.base+'/tests/fixtures/passenger-assets.html');
 await p.waitForFunction(()=>window.assetsReady,null,{timeout:120000});
 for(let i=0;i<PROFILES.length;i++)for(const state of ['waiting','seated']){
  const image=await p.evaluate(([i,state])=>window.passengerAssets.bake(i,state),[i,state]);
  await writeFile(new URL(`../../assets/passengers/${PROFILES[i]}${state==='seated'?'-seated':''}-atlas.png`,import.meta.url),Buffer.from(image.split(',')[1],'base64'));
  console.log('BAKED',PROFILES[i],state);
 }
 if(fixture.errors.length)throw new Error(fixture.errors.join('\n'));
}finally{await fixture.close();}
