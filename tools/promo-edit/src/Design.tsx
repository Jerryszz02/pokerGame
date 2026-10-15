import React from 'react';
import {AbsoluteFill, Easing, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Video, Audio} from '@remotion/media';
import {loadFont} from '@remotion/fonts';

loadFont({family: 'Pixelify', url: staticFile('fonts/PixelifySans.ttf'), weight: '700'});
loadFont({family: 'Noto', url: staticFile('fonts/NotoSansSC.ttf'), weight: '400'});
loadFont({family: 'Noto', url: staticFile('fonts/NotoSansSC.ttf'), weight: '700'});

const ink = '#06110f';
const cream = '#fff2ce';
const brass = '#d9b66c';
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
export type Crop = [number, number, number, number];

// Source coordinates use the actual 1920 x 1080 viewport. No cards or UI are redrawn.
export const Viewport: React.FC<{src: string; start: number; crop: Crop; box?: Crop; sound?: boolean; endCrop?: Crop}> = ({src, start, crop, box, sound = true, endCrop}) => {
  const {width, height, fps, durationInFrames} = useVideoConfig();
  const f = useCurrentFrame();
  const bounds = box ?? [0, 0, width, height];
  const progress = interpolate(f, [0, Math.min(fps * .7, durationInFrames - 1)], [0, 1], {...clamp, easing: Easing.bezier(.22, 1, .36, 1)});
  const active = crop.map((v, i) => v + ((endCrop?.[i] ?? v) - v) * progress);
  const scale = Math.max(bounds[2] / active[2], bounds[3] / active[3]);
  return <div style={{position: 'absolute', left: bounds[0], top: bounds[1], width: bounds[2], height: bounds[3], overflow: 'hidden', background: ink}}>
    <Video src={staticFile(src)} trimBefore={Math.round(start * fps)} premountFor={fps} muted={!sound} volume={1} style={{position: 'absolute', width: 1920 * scale, height: 1080 * scale, maxWidth: 'none', left: -active[0] * scale + (bounds[2] - active[2] * scale) / 2, top: -active[1] * scale + (bounds[3] - active[3] * scale) / 2}} />
  </div>;
};

export const Title: React.FC<{text: string; sub?: string; zh?: boolean; position?: 'tl' | 'tr' | 'bl' | 'center'; hold?: number}> = ({text, sub, zh, position = 'tl', hold = 2.3}) => {
  const f = useCurrentFrame(); const {fps, width, height} = useVideoConfig();
  const vertical = height > width;
  const move = interpolate(f, [0, .34 * fps, .43 * fps, hold * fps, (hold + .2) * fps], [110, -7, 0, 0, -140], clamp);
  const alpha = interpolate(f, [0, .12 * fps, hold * fps, (hold + .2) * fps], [0, 1, 1, 0], clamp);
  const central = position === 'center';
  return <div style={{position: 'absolute', zIndex: 3, left: central ? 90 : (position === 'tr' ? undefined : 105), right: central ? 90 : (position === 'tr' ? 105 : undefined), top: vertical ? 215 : (position === 'bl' ? undefined : 80), bottom: position === 'bl' ? 170 : undefined, opacity: alpha, translate: `0px ${move}px`, textAlign: central ? 'center' : 'left'}}>
    <div style={{position: 'absolute', inset: '-13px -17px -11px -16px', background: '#020806', clipPath: 'polygon(0 0, 94% 0, 100% 27%, 100% 100%, 4% 100%, 0 68%)', rotate: '-1deg'}} />
    <div style={{position: 'relative', padding: vertical ? '20px 30px 26px' : '14px 38px 22px', borderLeft: `${vertical ? 6 : 10}px solid ${vertical ? brass : cream}`, background: vertical ? '#0c2b24' : '#efd28d', clipPath: 'polygon(0 0, 95% 0, 100% 29%, 100% 100%, 0 100%)'}}>
      <div data-promo-title="chapter" style={{fontFamily: zh ? 'Noto' : 'Pixelify', fontSize: vertical ? 72 : (zh ? 94 : 128), fontWeight: 700, color: vertical ? cream : ink, lineHeight: 1.08, letterSpacing: zh ? 2 : 1, whiteSpace: vertical ? 'nowrap' : 'pre'}}>{text}</div>
      {sub && <div style={{fontFamily: 'Noto', color: vertical ? brass : '#17392f', fontSize: vertical ? 34 : 40, fontWeight: vertical ? 400 : 700, marginTop: 10}}>{sub}</div>}
    </div>
  </div>;
};

// The band expands from its centre; the independent text layer sweeps in from the right.
export const OpeningBanner: React.FC<{text: string; zh?: boolean; seconds: number}> = ({text, zh, seconds}) => {
  const f = useCurrentFrame(); const {fps} = useVideoConfig();
  return <div data-promo-banner="opening" style={{position: 'absolute', zIndex: 4, left: 180, top: 320, width: 1560, height: 240, rotate: '-5deg', transformOrigin: '50% 50%', scale: interpolate(f, [0, .16 * fps, .3 * fps], [.08, 1.065, 1], clamp), opacity: interpolate(f, [0, .07 * fps, (seconds - .1) * fps, seconds * fps], [0, 1, 1, 0], clamp)}}>
    <div style={{position: 'absolute', inset: '-18px -20px -20px', background: ink, translate: '14px 16px', clipPath: 'polygon(3% 0,100% 0,97% 100%,0 100%)'}} />
    <div style={{position: 'absolute', inset: 0, background: '#efd28d', borderTop: `8px solid ${cream}`, borderBottom: `8px solid ${cream}`, clipPath: 'polygon(3% 0,100% 0,97% 100%,0 100%)'}} />
    <div style={{position: 'absolute', inset: '0 55px', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden'}}>
      <div data-promo-title="opening" style={{fontFamily: zh ? 'Noto' : 'Pixelify', fontWeight: 700, fontSize: zh ? 146 : 190, lineHeight: 1.08, letterSpacing: zh ? 3 : 1, color: ink, whiteSpace: 'nowrap', translate: `${interpolate(f, [.04 * fps, .25 * fps, .4 * fps], [900, -22, 0], clamp)}px 0px`, opacity: interpolate(f, [.04 * fps, .13 * fps], [0, 1], clamp)}}>{text}</div>
    </div>
  </div>;
};

export const Subtitle: React.FC<{text: string; seconds?: number}> = ({text, seconds = 4}) => {
  const {fps} = useVideoConfig(); const f = useCurrentFrame();
  return <div style={{position: 'absolute', zIndex: 5, left: 80, right: 80, top: 968, display: 'flex', justifyContent: 'center', opacity: interpolate(f, [0, 5, seconds * fps - 5, seconds * fps], [0, 1, 1, 0], clamp)}}>
    <div style={{fontFamily: 'Noto', fontSize: 50, fontWeight: 700, lineHeight: 1.12, color: 'white', background: '#020b09f5', borderBottom: `3px solid ${brass}`, padding: '5px 24px', textShadow: '0 2px 3px black'}}>{text}</div>
  </div>;
};

export const EndCard: React.FC<{zh?: boolean; caption?:string}> = ({zh,caption}) => {
  const {width, height} = useVideoConfig(); const v = height > width;
  return <AbsoluteFill style={{background: ink, color: cream, justifyContent: 'center', alignItems: 'center', fontFamily: 'Noto'}}>
    <AbsoluteFill style={{backgroundImage: 'repeating-linear-gradient(135deg,transparent 0px,transparent 22px,#2b50421c 22px,#2b50421c 24px)', opacity: .8}} />
    <div style={{position: 'absolute', inset: v ? '165px 64px 330px' : '64px 92px', border: `2px solid ${brass}`, clipPath: 'polygon(0 0,94% 0,100% 10%,100% 100%,6% 100%,0 90%)'}} />
    <div style={{position: 'relative', textAlign: 'center', width: v ? 900 : 1680, marginTop: v ? -110 : 0}}>
      <div style={{fontFamily: zh ? 'Noto' : 'Pixelify', color: brass, fontSize: v ? 56 : 54, marginBottom: 22}}>{zh ? '现在，轮到你。' : 'YOUR TURN'}</div>
      <div style={{fontFamily: 'Pixelify', fontWeight: 700, fontSize: v ? 134 : 172, lineHeight: 1.1, letterSpacing: -4}}>PokerGame</div>
      <div style={{fontSize: v ? 42 : 48, marginTop: 30}}>{zh ? '电脑浏览器 · 免费试玩' : 'PLAY FREE ON DESKTOP'}</div>
      <div style={{width: v ? 730 : 1100, height: 2, background: brass, margin: '35px auto'}} />
      <div style={{fontSize: v ? 41 : 48, color: brass, lineHeight: 1.5}}>{v ? <>jerryszz02.itch.io<br/>/poker-game</> : 'jerryszz02.itch.io/poker-game'}</div>
      <div style={{fontSize: v ? 28 : 27, color: '#aabeb5', marginTop: 32}}>{zh ? '单人德州 · 三手引导 · 逐步回放' : 'Single-player Texas Hold’em'}</div>
    </div>
    {caption&&<Subtitle text={caption} seconds={3}/>}
  </AbsoluteFill>;
};

export const Music: React.FC<{duration: number; decisions: [number, number][]}> = ({duration, decisions}) => {
  const {fps} = useVideoConfig();
  return <Audio src={staticFile('media/music.mp3')} trimBefore={8 * fps} premountFor={fps} volume={(f) => {
    const t = f / fps;
    let gain = .6 * Math.min(1, Math.max(.10, t / 3)) * Math.min(1, Math.max(0, (duration - t) / 1.5));
    for (const [start, end] of decisions) {
      if (t >= start - .3 && t <= end + .3) gain *= interpolate(t, [start - .3, start, end, end + .3], [1, .45, .45, 1], clamp);
    }
    return gain;
  }} />;
};

export const Base: React.FC<{children: React.ReactNode}> = ({children}) => <AbsoluteFill style={{background: ink, overflow: 'hidden'}}>{children}</AbsoluteFill>;
