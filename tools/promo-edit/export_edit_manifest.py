#!/usr/bin/env python3
"""Extract evidence from each independently authored JSX timeline node."""
from pathlib import Path
import re,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
source=Path('src/Films.tsx').read_text();media=json.loads(Path('public/media/manifest.json').read_text());assets={m['file']:m for m in media}
def frames(x):
 if not re.fullmatch(r'[\d.]+(?:\*fps)?',x):raise ValueError(x)
 return round(float(x.removesuffix('*fps'))*(30 if '*fps' in x else 1))
def srt(t):
 ms=round(t*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
allfilms={};subtitle=[]
for i,(fn,n) in enumerate([('StoreFilm','Store'),('BilibiliFilm','Bilibili'),('ShortsFilm','Shorts')]):
 body=source.split('export const '+fn)[1].split('export const ')[0];shots=[]
 for m in re.finditer(r'<Sequence name="([^"]+)" (?:from=\{([^}]+)\} )?durationInFrames=\{([^}]+)\}[^>]*>(.*?)</Sequence>',body,re.S):
  name,start,duration,jsx=m.groups();a=frames(start or '0');length=frames(duration);entry={'name':name,'output_start_frame':a,'output_end_frame':a+length,'duration_frames':length}
  src=re.search(r'src="media/([^"]+)"',jsx);ss=re.search(r'start=\{([^}]+)\}',jsx)
  if src:
   file=src[1];st=round(float(ss[1])*30);assert st>=0 and st+length<=round(assets[file]['duration']*30),(n,name,'source out of bounds');entry.update({'source':file,'source_start_frame':st,'source_end_frame':st+length,'source_sha256':assets[file]['sha256'],'game_version':'1.4.0','game_commit':assets[file]['gameCommit']})
   if file.startswith('en-practice'):entry['hand_id']='hand-6aaf93d1165167e45ccf5daf04a02d7c' if a<(24 if n=='Shorts' else 51)*30 else 'fresh-table'
   if file.startswith('zh-practice') or file=='zh-replay-pickup.mp4':entry['hand_id']='hand-ad81fba7f63ae4c8713825d9e0129b52' if a<68*30 else 'next-hand'
  else:entry['type']='editorial-title-card'
  for key in ['crop','top','bottom','coachCrop','boardCrop','handCrop','actionCrop']:
   z=re.search(key+r'=\{(\[[^]]+\])\}',jsx)
   if z:entry[key]=json.loads(z[1])
  if '<OpeningChoice ' in jsx:entry['layout']='centre-banner-with-synchronized-hand-and-action-windows'
  cap=re.search(r"caption=\{captions\?'([^']+)':undefined\}",jsx)
  if cap:
   dur=re.search(r'captionSeconds=\{([^}]+)\}',jsx);secs=float(dur[1]) if dur else 3
   subtitle.append({'text':cap[1],'start':a/30,'end':min((a+length)/30,a/30+secs),'characters_per_second':len(cap[1])/secs})
  shots.append(entry)
 for prev,nxt in zip(shots,shots[1:]): assert prev['output_end_frame']==nxt['output_start_frame'],(n,prev,nxt)
 assert shots[0]['output_start_frame']==0
 assert shots[-1]['output_end_frame']=={'Store':1800,'Bilibili':2400,'Shorts':900}[n]
 allfilms[n]=shots
allfilms['Xiaohongshu']={'same_visual_timeline_as':'Store','subtitles':subtitle}
result={'version':1,'fps':30,'source_code_sha256':hashlib.sha256(source.encode()).hexdigest(),'films':allfilms,'notes':['English and Chinese hero clips are different complete hands.','English fresh table after elimination is explicitly labelled.','Chinese replay pickup is the same completed hand record; cuts between recording sessions are intentional.','All accepted game captures use current v1.4.0.','Geometric text, camera crops and operation indicators are editorial overlays.']}
(args.output/'edit-manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(args.output/'Xiaohongshu.zh-CN.srt').write_text('\n\n'.join(f'{i+1}\n{srt(c["start"])} --> {srt(c["end"])}\n{c["text"]}' for i,c in enumerate(subtitle))+'\n')
print('Verified contiguous 60/80/30-second authored timelines; XHS uses identical Store cut.')
