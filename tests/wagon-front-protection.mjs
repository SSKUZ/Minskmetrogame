import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

export async function verifyFrontProtection(source){
 const lock=JSON.parse(await readFile('tests/reference/front-v84-lock.json','utf8'));
 const fixture=await readFile(`tests/reference/${lock.fixture}`,'utf8');
 const sha=text=>createHash('sha256').update(text).digest('hex');
 assert.equal(sha(fixture),lock.fixtureSha256,'Immutable v84 fixture changed');
 for(const region of lock.regions){
  const a=source.indexOf(region.start),b=source.indexOf(region.end,a);
  assert.ok(a>=0&&b>a,`Protected front block missing: ${region.name}`);
  assert.equal(sha(source.slice(a,b)),region.sha256,`Protected v84 source changed: ${region.name}`);
 }
 return {baseCommit:lock.baseCommit,protectedBlocks:lock.regions.map(r=>r.name),fixture};
}
