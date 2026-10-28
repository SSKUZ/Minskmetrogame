import {writeFile,mkdir} from 'node:fs/promises';
import {launchCabBrowser,ready,view,samplePerformance} from './helpers/cab-browser-fixture.mjs';
const f=await launchCabBrowser(),p=await f.page(),out=process.env.CAB_RESULTS??'test-results/cab';await mkdir(out,{recursive:true});
try{await ready(p,f.base+'/?preview=station&cabInspector=1');await view(p);await p.waitForTimeout(2000);const result=await samplePerformance(p);await writeFile(out+'/performance.json',JSON.stringify(result,null,2));console.log(JSON.stringify({...result,frames:undefined}));}finally{await f.close()}
