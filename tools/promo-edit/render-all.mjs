import {bundle} from '@remotion/bundler';
import {getCompositions,renderMedia} from '@remotion/renderer';
import {mkdir,writeFile,access,readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
const output=resolve(process.argv[2]);
const reusePremaster=process.argv.includes('--reuse-premaster');
const ids=process.argv.slice(3).filter(arg=>arg!=='--reuse-premaster');if(!ids.length)ids.push('Store','Xiaohongshu','Bilibili','Shorts');
await mkdir(output,{recursive:true});
const exists=path=>access(path).then(()=>true,()=>false);
for(const id of ids){
 if(!['Store','Xiaohongshu','Bilibili','Shorts'].includes(id))throw new Error(`Unknown film: ${id}`);
 if(await exists(resolve(output,`${id}.mp4`)))throw new Error(`${id}.mp4 already exists; choose a new revision directory`);
 if(!reusePremaster && await exists(resolve(output,`${id}-premaster.mp4`)))throw new Error(`${id} premaster already exists; use a new revision or verified --reuse-premaster recovery`);
}
const fingerprint=createHash('sha256');
for(const folder of ['src','public/media','public/fonts']){
 for(const file of (await readdir(folder)).sort()){
  fingerprint.update(`${folder}/${file}\n`);
  fingerprint.update(await readFile(resolve(folder,file)));
 }
}
fingerprint.update(await readFile('package-lock.json'));
const sourceFingerprint=fingerprint.digest('hex');
const ffmpeg=process.env.FFMPEG??'/Applications/Shotcut.app/Contents/MacOS/ffmpeg';
const serveUrl=await bundle({entryPoint:resolve('src/index.ts'),publicDir:resolve('public'),enableCaching:true});
const browserExecutable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const comps=await getCompositions(serveUrl,{browserExecutable});
for(const id of ids){
 const composition=comps.find(c=>c.id===id); if(!composition)throw new Error(`Missing ${id}`);
 const intermediate=resolve(output,`${id}-premaster.mp4`);let last=-1;
 const hasPremaster=await exists(intermediate);
 const receiptPath=resolve(output,`${id}-premaster-receipt.json`);
 if(reusePremaster && hasPremaster){
  const receipt=JSON.parse(await readFile(receiptPath,'utf8'));
  const sha256=createHash('sha256').update(await readFile(intermediate)).digest('hex');
  if(receipt.sourceFingerprint!==sourceFingerprint || receipt.sha256!==sha256)throw new Error(`Stale or changed premaster: ${id}; use a new revision directory`);
 }else{
  console.log(`Rendering ${id}`);
  await renderMedia({serveUrl,composition,outputLocation:intermediate,codec:'h264',crf:18,audioCodec:'aac',audioBitrate:'192k',pixelFormat:'yuv420p',browserExecutable,concurrency:8,logLevel:'error',onProgress:({progress})=>{const p=Math.floor(progress*5);if(p!==last){last=p;console.log(`${id} ${p*20}%`)}}});
  const sha256=createHash('sha256').update(await readFile(intermediate)).digest('hex');
  await writeFile(receiptPath,JSON.stringify({id,sourceFingerprint,sha256},null,2)+'\n');
 }
 const measure=spawnSync(ffmpeg,['-hide_banner','-i',intermediate,'-vn','-af','loudnorm=I=-16:TP=-2.2:LRA=11:print_format=json','-f','null','-'],{encoding:'utf8'});
 if(measure.status!==0)throw new Error(measure.stderr);
 const blocks=measure.stderr.match(/\{[^{}]*\}/g)??[];
 const metrics=blocks.map(block=>JSON.parse(block)).find(block=>block.input_i!==undefined);
 if(!metrics)throw new Error('FFmpeg did not return loudnorm measurements');
 await writeFile(resolve(output,`${id}-premaster-loudness.json`),JSON.stringify(metrics,null,2));
 const filter=`loudnorm=I=-16:TP=-2.2:LRA=11:measured_I=${metrics.input_i}:measured_TP=${metrics.input_tp}:measured_LRA=${metrics.input_lra}:measured_thresh=${metrics.input_thresh}:offset=${metrics.target_offset}:linear=true:print_format=json`;
 const result=spawnSync(ffmpeg,['-n','-v','info','-i',intermediate,'-map','0:v:0','-map','0:a:0','-c:v','copy','-af',filter,'-ar','48000','-c:a','aac','-b:a','192k','-movflags','+faststart',resolve(output,`${id}.mp4`)],{encoding:'utf8'});
 await writeFile(resolve(output,`${id}-mastering.log`),result.stderr);
 if(result.status!==0)throw new Error(result.stderr);
 console.log(`DONE ${id}`);
}
