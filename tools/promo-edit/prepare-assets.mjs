import {mkdir, copyFile, readFile, writeFile} from 'node:fs/promises';
import {resolve, basename} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(import.meta.dirname,'../..');
const raw=resolve(process.argv[2] ?? resolve(root,'export/promo/v1.4.0/production-2026-10-15/raw'));
const out=resolve(import.meta.dirname,'public/media');
await mkdir(out,{recursive:true});
await copyFile(resolve(root,'assets/fonts/NotoSansSC.ttf'),resolve(import.meta.dirname,'public/fonts/NotoSansSC.ttf'));
for(const [src,dst] of [['airport-lounge.mp3','music.mp3'],['chip-lay-1.ogg','chip.ogg'],['card-slide-1.ogg','slide.ogg']]) await copyFile(resolve(root,'assets/audio',src),resolve(out,dst));
const evidence=JSON.parse(await readFile(resolve(root,'docs/promo-review/capture-manifest.json'),'utf8'));
const manifest=[];
for(const source of evidence.sources){
 const expected=source.files.mp4;
 const f=expected.file;
 const b=await readFile(resolve(raw,f));
 const sha256=createHash('sha256').update(b).digest('hex');
 if(sha256!==expected.sha256)throw new Error(`Unverified capture: ${f}; update the provenance manifest after reviewing new footage`);
 await copyFile(resolve(raw,f),resolve(out,f));
 manifest.push({file:basename(f),source:resolve(raw,f),sha256,bytes:b.length,duration:expected.duration_seconds,version:evidence.game_version,gameCommit:evidence.game_commit,capture:'Godot MovieMaker; UI-driven; isolated profile; original rules and AI'});
}
await writeFile(resolve(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(`Verified and prepared ${manifest.length} captures from ${raw}`);
