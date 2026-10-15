import {Composition} from 'remotion';
import {EndCard} from './Design';
import {StoreFilm,BilibiliFilm,ShortsFilm} from './Films';
export const MyComposition = () => <>
 <Composition id="Store" component={StoreFilm} fps={30} width={1920} height={1080} durationInFrames={1800} defaultProps={{captions:false}} />
 <Composition id="Xiaohongshu" component={StoreFilm} fps={30} width={1920} height={1080} durationInFrames={1800} defaultProps={{captions:true}} />
 <Composition id="Bilibili" component={BilibiliFilm} fps={30} width={1920} height={1080} durationInFrames={2400} />
 <Composition id="Shorts" component={ShortsFilm} fps={30} width={1080} height={1920} durationInFrames={900} />
 <Composition id="EndCard-en" component={EndCard} fps={30} width={1920} height={1080} durationInFrames={150} defaultProps={{zh:false}} />
 <Composition id="EndCard-Shorts" component={EndCard} fps={30} width={1080} height={1920} durationInFrames={120} defaultProps={{zh:false}} />
</>;
