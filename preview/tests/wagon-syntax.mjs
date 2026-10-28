import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const html=await readFile('preview/wagon.html','utf8');
const directory=await mkdtemp(path.join(tmpdir(),'wagon-syntax-'));
try{
 let count=0;
 for(const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){
  if(/type=["']importmap["']/.test(match[1])){JSON.parse(match[2]);continue;}
  if(/\bsrc=/.test(match[1]))continue;
  const file=path.join(directory,`${count++}.mjs`);await writeFile(file,match[2]);execFileSync(process.execPath,['--check',file]);
 }
 if(!count)throw new Error('No wagon script found');
 console.log(`Wagon JavaScript syntax passed: ${count} scripts`);
}finally{await rm(directory,{recursive:true,force:true});}
