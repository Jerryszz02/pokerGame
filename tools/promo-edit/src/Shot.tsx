import React from 'react';
import {Sequence, useCurrentFrame, useVideoConfig} from 'remotion';
import {Base, Crop, OpeningBanner, Subtitle, Title, Viewport} from './Design';

type ShotProps={src:string; start:number; crop:Crop; endCrop?:Crop; title?:string; zh?:boolean; sub?:string; position?:'tl'|'tr'|'bl'|'center'; caption?:string; captionSeconds?:number; titleSeconds?:number; inset?:boolean;full?:boolean; vertical?:boolean; label?:string; clickAt?:number; clickPoint?:[number,number]};
export const Shot:React.FC<ShotProps>=({src,start,crop,endCrop,title,zh,sub,position,caption,captionSeconds=3,titleSeconds=2.3,inset=false,full=false,vertical=false,label,clickAt,clickPoint})=>{
 const {fps}=useVideoConfig();const f=useCurrentFrame();
 // A caption rail keeps the Chinese subtitle clear of real game controls.
 const box:Crop=vertical?[0,390,1080,1080]:inset?(full?[106.6667,0,1706.6667,960]:[0,0,1920,960]):[0,0,1920,1080];
 const scale=Math.max(box[2]/crop[2],box[3]/crop[3]);
 const x=clickPoint?box[0]+(clickPoint[0]-crop[0])*scale+(box[2]-crop[2]*scale)/2:0;
 const y=clickPoint?box[1]+(clickPoint[1]-crop[1])*scale+(box[3]-crop[3]*scale)/2:0;
 const clickFrame=(clickAt??-100)*fps;
 return <Base>
  <Viewport src={src} start={start} crop={crop} box={box} endCrop={endCrop}/>
  {label&&<div style={{position:'absolute',left:vertical?90:105,top:vertical?1510:970,color:'#d9b66c',fontFamily:'Noto',fontSize:vertical?40:28}}>{label}</div>}
  {title&&<Title text={title} sub={sub} zh={zh} position={vertical?'center':position} hold={titleSeconds}/>}
  {clickPoint&&f>clickFrame-15&&f<clickFrame+7&&<div style={{position:'absolute',left:x-18,top:y-18,width:36,height:36,borderRadius:'50%',border:'4px solid #fff1bc',boxShadow:'0 0 0 3px #07231c',opacity:f>clickFrame?.65:1,scale:f>clickFrame?1+(f-clickFrame)/8:1}}/>}
  {caption&&<Sequence durationInFrames={Math.round(captionSeconds*fps)} premountFor={fps}><Subtitle text={caption} seconds={captionSeconds}/></Sequence>}
  {vertical&&<><div style={{position:'absolute',left:90,right:90,top:170,borderTop:'2px solid #8d7849'}}/><div style={{position:'absolute',left:90,right:90,top:1640,color:'#88a498',fontFamily:'Pixelify',fontSize:36}}>POKERGAME / YOUR DECISION</div></>}
 </Base>;
};
export const SplitShot:React.FC<{src:string;start:number;top:Crop;bottom:Crop;title:string;labels?:[string,string]}> = ({src,start,top,bottom,title,labels=['THE BOARD','YOUR HAND']})=> <Base>
 <Viewport src={src} start={start} crop={top} box={[70,470,940,440]}/>
 <Viewport src={src} start={start} crop={bottom} box={[70,1010,940,400]} sound={false}/>
 <Title text={title} position="center" hold={2}/>
 <div style={{position:'absolute',top:400,left:90,fontFamily:'Pixelify',fontSize:38,color:'#d9b66c'}}>{labels[0]}</div>
 <div style={{position:'absolute',top:940,left:90,fontFamily:'Pixelify',fontSize:38,color:'#d9b66c'}}>{labels[1]}</div>
 <div style={{position:'absolute',top:1500,left:90,fontFamily:'Noto',fontSize:32,color:'#9db2a7'}}>Same hand · Real gameplay</div>
</Base>;

// Three windows use the same unaltered source moment. The lower windows keep
// the actual hand and available actions clear while the headline owns the centre.
export const OpeningChoice:React.FC<{src:string;start:number;crop:Crop;handCrop:Crop;actionCrop:Crop;title:string;zh?:boolean;seconds:number;caption?:string;captionSeconds?:number}>=({src,start,crop,handCrop,actionCrop,title,zh,seconds,caption,captionSeconds=seconds})=> <Base>
 <Viewport src={src} start={start} crop={crop} box={[0,0,1920,960]}/>
 <div style={{position:'absolute',inset:0,background:'#06110fd9'}}/>
 <div style={{position:'absolute',left:125,top:100,color:'#d9b66c',fontFamily:'Pixelify',fontWeight:700,fontSize:52,letterSpacing:5}}>POKERGAME</div>
 <Viewport src={src} start={start} crop={handCrop} box={[120,650,720,300]} sound={false}/>
 <Viewport src={src} start={start} crop={actionCrop} box={[1030,650,770,300]} sound={false}/>
 <OpeningBanner text={title} zh={zh} seconds={seconds}/>
 {caption&&<Subtitle text={caption} seconds={captionSeconds}/>}
</Base>;

// Both windows show the same recorded moment: feedback beside the cards it describes.
export const TutorialFeedback:React.FC<{src:string;start:number;coachCrop:Crop;boardCrop:Crop;zh?:boolean}> = ({src,start,coachCrop,boardCrop,zh})=> <Base>
 <Viewport src={src} start={start} crop={coachCrop} box={[70,230,1120,610]}/>
 <Viewport src={src} start={start} crop={boardCrop} box={[1280,160,570,630]} sound={false}/>
 <div style={{position:'absolute',left:105,top:110,fontFamily:zh?'Noto':'Pixelify',fontSize:zh?66:76,fontWeight:700,color:'#fff2ce'}}>{zh?'跟注之后':'AFTER THE CALL'}</div>
 <div style={{position:'absolute',left:1280,top:830,fontFamily:zh?'Noto':'Pixelify',fontSize:zh?50:48,fontWeight:700,color:'#fff2ce'}}>{zh?'公共牌与手牌':'BOARD + YOUR HAND'}</div>
</Base>;
