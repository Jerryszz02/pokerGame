import {Sequence, useVideoConfig} from 'remotion';
import {Base, EndCard, Music} from './Design';
import {OpeningChoice, Shot, SplitShot, TutorialFeedback} from './Shot';

export const StoreFilm = ({captions=false}:{captions?:boolean}) => {
 const {fps}=useVideoConfig();
 return <Base>
  <Sequence name="A01 · Your move / same hand" durationInFrames={2*fps} premountFor={fps}><OpeningChoice src="media/en-practice-take02.mp4" start={45.7} crop={[760,540,800,400]} handCrop={[830,650,350,149]} actionCrop={[1300,800,600,234]} title="CALL OR FOLD?" seconds={2} caption={captions?'这一手，你来决定。':undefined} captionSeconds={2}/></Sequence>
  <Sequence name="A01 · Call amount" from={2*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={46.8} crop={[1120,650,800,400]} inset/></Sequence>
  <Sequence name="A02 · The poker room" from={4*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={11.6} crop={[0,0,1920,1080]} inset full title="SINGLE PLAYER" sub="Texas Hold'em" position="tl" caption={captions?'一个人，也能开一桌德州。':undefined}/></Sequence>
  <Sequence name="A03 · Configure your table" from={8*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/config-pickup-en.mp4" start={3.3} crop={[400,140,1120,560]} inset title={'YOUR\nTABLE'} position="tr" titleSeconds={2} caption={captions?'对手人数和难度，由你来选。':undefined}/></Sequence>
  <Sequence name="A03 · Start" from={11*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/config-pickup-en.mp4" start={8.9} crop={[440,380,1200,600]} inset clickAt={1.867} clickPoint={[679.5,856.5]}/></Sequence>
  <Sequence name="A04 · Observe hard AI" from={14*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/hard-ai-en.mp4" start={6.5} crop={[220,40,1480,740]} inset title="READ THE TABLE" position="tl" titleSeconds={2} caption={captions?'观察对手，再做决定。':undefined}/></Sequence>
  <Sequence name="A04 · Opponent actions" from={18*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/hard-ai-en.mp4" start={10.5} crop={[310,180,1260,630]} inset/></Sequence>
  <Sequence name="A04 · Action comes to you" from={22*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/hard-ai-en.mp4" start={21} crop={[760,440,1160,580]} inset/></Sequence>
  <Sequence name="A05 · Current three-hand tutorial" from={25*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-tutorial-take02.mp4" start={16.667} crop={[0,0,1920,1080]} inset full title="LEARN" position="tr" titleSeconds={2} caption={captions?'跟着教程，练习基本操作。':undefined} captionSeconds={2}/></Sequence>
  <Sequence name="A05 · Read the coach prompt" from={27*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-tutorial-take02.mp4" start={18.667} crop={[0,610,940,470]} inset/></Sequence>
  <Sequence name="A05 · Call ten" from={29*fps} durationInFrames={1.2*fps} premountFor={fps}><Shot src="media/en-tutorial-take02.mp4" start={19.9} crop={[1120,650,800,400]} inset clickAt={.767} clickPoint={[1550,1004]}/></Sequence>
  <Sequence name="A05 · Actual feedback" from={30.2*fps} durationInFrames={2.8*fps} premountFor={fps}><TutorialFeedback src="media/en-tutorial-take02.mp4" start={21.5} coachCrop={[25,690,680,370]} boardCrop={[770,420,390,430]}/></Sequence>
  <Sequence name="A06 · Commit to the same hand" from={33*fps} durationInFrames={2.7*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={46.4} crop={[1120,650,800,400]} inset clickAt={2.4} clickPoint={[1550,1004]}/></Sequence>
  <Sequence name="A06 · The final opponent acts" from={35.7*fps} durationInFrames={1.8*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={51.6} crop={[460,150,1100,550]} inset/></Sequence>
  <Sequence name="A06 · The actual showdown" from={37.5*fps} durationInFrames={2.4*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={53.4} crop={[540,200,960,480]} inset caption={captions?'看看这一手的结果。':undefined} captionSeconds={2.4}/></Sequence>
  <Sequence name="A06 · Real result" from={39.9*fps} durationInFrames={2.1*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={53.4} crop={[980,610,940,470]} inset title="SHOWDOWN" position="tl" titleSeconds={2}/></Sequence>
  <Sequence name="A07 · Enter this hand replay" from={42*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={55.4} crop={[980,610,940,470]} inset caption={captions?'打完一手，再逐步回看。':undefined} captionSeconds={2}/></Sequence>
  <Sequence name="A07 · Independent replay view" from={44*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={57.4} crop={[150,60,1620,810]} inset title="REPLAY" position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="A07 · Revisit the decision" from={46*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={90.5} crop={[150,150,1440,720]} inset/></Sequence>
  <Sequence name="A08 · A fresh table after elimination" from={51*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={116.4} crop={[0,0,1920,1080]} inset full title="YOUR TURN" sub="A fresh table" position="tr" caption={captions?'重新开一桌，再做一次选择。':undefined}/></Sequence>
  <Sequence name="A08 · Desktop CTA" from={55*fps} durationInFrames={5*fps} premountFor={fps}><EndCard caption={captions?'轮到你了。电脑浏览器免费试玩。':undefined}/></Sequence>
  <Music duration={60} decisions={[[0,3],[33,42]]}/>
 </Base>;
};

export const BilibiliFilm = () => {
 const {fps}=useVideoConfig();
 return <Base>
  <Sequence name="B01 · Same-hand choice" durationInFrames={3*fps} premountFor={fps}><OpeningChoice src="media/zh-practice-take02.mp4" start={24.833} crop={[760,540,800,400]} handCrop={[830,650,350,149]} actionCrop={[1300,800,600,234]} title="这手，怎么打？" zh seconds={2.7}/></Sequence>
  <Sequence name="B01 · Facing the bet" from={3*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={25.833} crop={[1120,650,800,400]} inset/></Sequence>
  <Sequence name="B02 · The training room" from={5*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/hard-ai-zh.mp4" start={6.5} crop={[0,0,1920,1080]} inset full title="德州扑克训练室" zh position="tl" sub="PokerGame"/></Sequence>
  <Sequence name="B03 · Three guided hands" from={10*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/zh-tutorial-take02.mp4" start={3.267} crop={[0,0,1920,1080]} inset full title="先练基本功" zh position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="B03 · Read the actual prompt" from={13*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/zh-tutorial-take02.mp4" start={16.667} crop={[0,610,940,470]} inset/></Sequence>
  <Sequence name="B03 · Call ten" from={17*fps} durationInFrames={1.3*fps} premountFor={fps}><Shot src="media/zh-tutorial-take02.mp4" start={19.9} crop={[1120,650,800,400]} inset clickAt={.767} clickPoint={[1550,1004]}/></Sequence>
  <Sequence name="B03 · Actual response" from={18.3*fps} durationInFrames={3.7*fps} premountFor={fps}><TutorialFeedback src="media/zh-tutorial-take02.mp4" start={21.6} coachCrop={[25,690,680,370]} boardCrop={[770,420,390,430]} zh/></Sequence>
  <Sequence name="B04 · Practice settings" from={22*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/config-pickup-zh.mp4" start={3.3} crop={[400,140,1120,560]} inset title="按你的节奏练" zh position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="B04 · Pause after each hand" from={27*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/config-pickup-zh.mp4" start={8.9} crop={[440,380,1200,600]} inset clickAt={1.867} clickPoint={[679.5,856.5]}/></Sequence>
  <Sequence name="B04 · Actual hard AI actions" from={31*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/hard-ai-zh.mp4" start={8} crop={[300,130,1320,660]} inset/></Sequence>
  <Sequence name="B05 · The original decision" from={36*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={25} crop={[1120,650,800,400]} inset clickAt={2.833} clickPoint={[1550,1004]}/></Sequence>
  <Sequence name="B05 · Showdown board" from={39*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={28} crop={[480,220,960,480]} inset title="亮牌见结果" zh position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="B05 · Genuine settlement" from={42*fps} durationInFrames={4*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={28.1} crop={[980,610,940,470]} inset/></Sequence>
  <Sequence name="B06 · Enter same-hand replay" from={46*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={32.1} crop={[150,60,1620,810]} inset title="回看每一步" zh position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="B06 · Player perspective" from={49*fps} durationInFrames={11*fps} premountFor={fps}><Shot src="media/zh-replay-pickup.mp4" start={7.3} crop={[150,150,1440,720]} inset/></Sequence>
  <Sequence name="B07 · Completed-hand omniscient toggle" from={60*fps} durationInFrames={8*fps} premountFor={fps}><Shot src="media/zh-replay-pickup.mp4" start={18.3} crop={[150,150,1440,720]} inset title="再看完整牌局" zh position="tr" titleSeconds={2.3}/></Sequence>
  <Sequence name="B08 · Genuine next hand" from={68*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/zh-practice-take02.mp4" start={67.1} crop={[760,440,1160,580]} inset title="下一手，再练一次" zh position="tr" titleSeconds={2}/></Sequence>
  <Sequence name="B09 · Desktop CTA" from={73*fps} durationInFrames={7*fps} premountFor={fps}><EndCard zh/></Sequence>
  <Music duration={80} decisions={[[0,4],[36,44]]}/>
 </Base>;
};

export const ShortsFilm = () => {
 const {fps}=useVideoConfig();
 return <Base>
  <Sequence name="C01 · The choice" durationInFrames={3*fps} premountFor={fps}><SplitShot src="media/en-practice-take02.mp4" start={45.8} top={[720,410,500,234]} bottom={[830,650,350,149]} title="CALL OR FOLD?"/></Sequence>
  <Sequence name="C02 · Your cards" from={3*fps} durationInFrames={3*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={45.8} crop={[740,520,560,560]} vertical title="YOUR HAND" titleSeconds={2} label="5♣ 9♦ · On the flop"/></Sequence>
  <Sequence name="C03 · The board and amount" from={6*fps} durationInFrames={4*fps} premountFor={fps}><SplitShot src="media/en-practice-take02.mp4" start={44.8} top={[720,410,500,234]} bottom={[1300,800,600,255]} title="THE BET" labels={['THE BOARD','CALL 510?']}/></Sequence>
  <Sequence name="C04 · Actual call" from={10*fps} durationInFrames={4*fps} premountFor={fps}><SplitShot src="media/en-practice-take02.mp4" start={46.5} top={[830,650,350,164]} bottom={[1300,800,600,255]} title="YOUR MOVE" labels={["YOUR HAND","YOUR ACTION"]}/></Sequence>
  <Sequence name="C05 · Genuine runout and showdown" from={14*fps} durationInFrames={5*fps} premountFor={fps}><SplitShot src="media/en-practice-take02.mp4" start={50.5} top={[720,410,500,234]} bottom={[1100,230,650,277]} title="SHOWDOWN" labels={['THE BOARD','OPPONENT · AI 1']}/></Sequence>
  <Sequence name="C06 · Same-hand replay" from={19*fps} durationInFrames={5*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={91.5} crop={[150,100,800,800]} vertical title="REPLAY" titleSeconds={2} label="Revisit the same decision"/></Sequence>
  <Sequence name="C07 · A fresh table" from={24*fps} durationInFrames={2*fps} premountFor={fps}><Shot src="media/en-practice-take02.mp4" start={118.1} crop={[740,520,560,560]} vertical title="YOUR TURN" titleSeconds={2} label="A NEW TABLE"/></Sequence>
  <Sequence name="C08 · Four-second CTA" from={26*fps} durationInFrames={4*fps} premountFor={fps}><EndCard/></Sequence>
  <Music duration={30} decisions={[[0,2],[10,19]]}/>
 </Base>;
};
