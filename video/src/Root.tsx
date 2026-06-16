import React from 'react';
import {Composition} from 'remotion';
import {SmartClipVideo} from './SmartClipVideo';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="SmartClip"
      component={SmartClipVideo}
      durationInFrames={1140}
      fps={30}
      width={1080}
      height={1080}
    />
  );
};
