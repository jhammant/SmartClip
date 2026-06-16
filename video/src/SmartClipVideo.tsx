import React from 'react';
import {
  AbsoluteFill,
  Series,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Easing,
} from 'remotion';

/* ----------------------------------------------------------------- design */
const MONO = "'Menlo','Monaco','SF Mono','JetBrains Mono',monospace";
const SANS = "'Inter','-apple-system','Helvetica Neue','Arial',sans-serif";
const ACCENT = '#E8896B'; // SmartClip coral
const GREEN = '#3FB950';
const DIM = '#7d8694';
const FENCE = '#ff7b72';
const STR = '#a5d6ff';
const FUNC = '#d2a8ff';

const BG: React.CSSProperties = {
  background: 'radial-gradient(circle at 50% 28%, #161d2b 0%, #0b0d12 72%)',
};

/* --------------------------------------------------------------- helpers */
const Tok: React.FC<{c?: string; children: React.ReactNode}> = ({
  c = '#c9d1d9',
  children,
}) => <span style={{color: c}}>{children}</span>;

const useTyped = (full: string, start: number, cps = 38) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const elapsed = Math.max(0, frame - start);
  const n = Math.floor((elapsed / fps) * cps);
  return {text: full.slice(0, n), done: n >= full.length};
};

const Cursor: React.FC<{show?: boolean}> = ({show = true}) => {
  const frame = useCurrentFrame();
  if (!show) return null;
  const on = Math.floor(frame / 14) % 2 === 0;
  return <span style={{color: ACCENT, opacity: on ? 1 : 0}}>▋</span>;
};

const FadeIn: React.FC<{
  at: number;
  dur?: number;
  y?: number;
  style?: React.CSSProperties;
  children: React.ReactNode;
}> = ({at, dur = 12, y = 14, style, children}) => {
  const frame = useCurrentFrame();
  const o = interpolate(frame, [at, at + dur], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const ty = interpolate(frame, [at, at + dur], [y, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  return (
    <div style={{opacity: o, transform: `translateY(${ty}px)`, ...style}}>
      {children}
    </div>
  );
};

const Dot: React.FC<{c: string}> = ({c}) => (
  <div style={{width: 14, height: 14, borderRadius: 7, background: c}} />
);

const TerminalWindow: React.FC<{
  title?: string;
  w?: number;
  children: React.ReactNode;
}> = ({title = 'claude code', w = 920, children}) => (
  <div
    style={{
      width: w,
      background: '#0d1117',
      borderRadius: 18,
      border: '1px solid #232b36',
      boxShadow: '0 40px 90px rgba(0,0,0,0.55)',
      overflow: 'hidden',
    }}
  >
    <div
      style={{
        height: 48,
        background: '#161b22',
        display: 'flex',
        alignItems: 'center',
        gap: 9,
        padding: '0 18px',
        borderBottom: '1px solid #232b36',
      }}
    >
      <Dot c="#ff5f57" />
      <Dot c="#febc2e" />
      <Dot c="#28c840" />
      <div style={{marginLeft: 14, color: DIM, fontSize: 19, fontFamily: MONO}}>
        {title}
      </div>
    </div>
    <div
      style={{
        padding: '30px 34px',
        fontFamily: MONO,
        fontSize: 25,
        lineHeight: 1.55,
        color: '#c9d1d9',
        minHeight: 470,
      }}
    >
      {children}
    </div>
  </div>
);

const Caption: React.FC<{at: number; children: React.ReactNode}> = ({
  at,
  children,
}) => (
  <div
    style={{
      position: 'absolute',
      bottom: 64,
      left: 0,
      right: 0,
      display: 'flex',
      justifyContent: 'center',
    }}
  >
    <FadeIn at={at} y={22}>
      <div
        style={{
          background: 'rgba(13,17,23,0.82)',
          border: '1px solid #2b3542',
          borderRadius: 999,
          padding: '16px 32px',
          fontFamily: SANS,
          fontSize: 31,
          color: '#fff',
        }}
      >
        {children}
      </div>
    </FadeIn>
  </div>
);

const Scene: React.FC<{children: React.ReactNode}> = ({children}) => (
  <AbsoluteFill
    style={{...BG, justifyContent: 'center', alignItems: 'center'}}
  >
    {children}
  </AbsoluteFill>
);

/* ----------------------------------------------------------------- scenes */
const TitleScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = spring({frame, fps, config: {damping: 12, stiffness: 120, mass: 0.8}});
  const sub = interpolate(frame, [22, 46], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const subY = interpolate(frame, [22, 46], [16, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  return (
    <Scene>
      <div style={{fontSize: 150, transform: `scale(${pop})`}}>📋</div>
      <div
        style={{
          fontSize: 108,
          fontWeight: 800,
          color: '#fff',
          fontFamily: SANS,
          letterSpacing: -3,
          transform: `scale(${pop})`,
        }}
      >
        SmartClip
      </div>
      <div
        style={{
          opacity: sub,
          transform: `translateY(${subY}px)`,
          color: ACCENT,
          fontSize: 38,
          fontFamily: SANS,
          fontWeight: 500,
          marginTop: 8,
        }}
      >
        Your AI terminal needs a smarter clipboard.
      </div>
    </Scene>
  );
};

const WriteScene: React.FC = () => {
  const {text, done} = useTyped('write me a python slugify function', 8, 40);
  return (
    <Scene>
      <TerminalWindow>
        <div>
          <Tok c={ACCENT}>❯</Tok> {text}
          <Cursor show={!done} />
        </div>
        <FadeIn at={46} style={{marginTop: 22}}>
          <Tok c={ACCENT}>● Claude</Tok>
        </FadeIn>
        <FadeIn at={54}>
          <Tok c={DIM}>Sure! Here's a clean implementation:</Tok>
        </FadeIn>
        <div
          style={{
            marginTop: 14,
            background: '#0a0c10',
            borderRadius: 10,
            padding: '14px 20px',
            whiteSpace: 'pre',
          }}
        >
          <FadeIn at={64}>
            <Tok c={FENCE}>```python</Tok>
          </FadeIn>
          <FadeIn at={72}>
            <Tok c="#ff7b72">import</Tok> re
          </FadeIn>
          <FadeIn at={80}>{' '}</FadeIn>
          <FadeIn at={86}>
            <Tok c="#ff7b72">def</Tok> <Tok c={FUNC}>slugify</Tok>(text):
          </FadeIn>
          <FadeIn at={94}>{'    text = text.strip().lower()'}</FadeIn>
          <FadeIn at={102}>
            {'    text = re.sub('}
            <Tok c={STR}>{'r"[^\\w\\s-]"'}</Tok>
            {', '}
            <Tok c={STR}>""</Tok>
            {', text)'}
          </FadeIn>
          <FadeIn at={110}>
            {'    '}
            <Tok c="#ff7b72">return</Tok>
            {' re.sub('}
            <Tok c={STR}>{'r"[\\s_-]+"'}</Tok>
            {', '}
            <Tok c={STR}>"-"</Tok>
            {', text)'}
          </FadeIn>
          <FadeIn at={118}>
            <Tok c={FENCE}>```</Tok>
          </FadeIn>
        </div>
        <FadeIn at={130}>
          <Tok c={DIM}>It strips punctuation and hyphenates. Let me know if…</Tok>
        </FadeIn>
      </TerminalWindow>
      <Caption at={150}>
        <b style={{color: ACCENT}}>Claude writes great code.</b>&nbsp; Copying
        it out? Pain.
      </Caption>
    </Scene>
  );
};

const ClpScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const {text, done} = useTyped('/clp', 8, 16);
  const tp = spring({frame: Math.max(0, frame - 42), fps, config: {damping: 13, stiffness: 150}});
  const toastO = interpolate(frame, [42, 50], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <Scene>
      <TerminalWindow>
        <div>
          <Tok c={ACCENT}>❯</Tok> {text}
          <Cursor show={!done} />
        </div>
        <div
          style={{
            marginTop: 26,
            opacity: toastO,
            transform: `scale(${Math.min(1, tp)})`,
            transformOrigin: 'left center',
          }}
        >
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 14,
              background: 'rgba(63,185,80,0.12)',
              border: `1px solid ${GREEN}`,
              borderRadius: 12,
              padding: '16px 22px',
            }}
          >
            <span style={{fontSize: 30}}>📋</span>
            <span style={{color: '#fff'}}>
              Copied <Tok c={FUNC}>slugify()</Tok>{' '}
              <Tok c={DIM}>· 6 lines · raw Python · no fences</Tok>{' '}
              <Tok c={GREEN}>✓</Tok>
            </span>
          </div>
        </div>
        <FadeIn at={72} style={{marginTop: 30}}>
          <div
            style={{
              background: '#0a0c10',
              border: '1px solid #232b36',
              borderRadius: 10,
              padding: '16px 20px',
              whiteSpace: 'pre',
            }}
          >
            <div style={{color: DIM, fontSize: 19, marginBottom: 12}}>
              editor.py — pasted ⌘V
            </div>
            <div>
              <Tok c="#ff7b72">import</Tok> re
            </div>
            <div>{' '}</div>
            <div>
              <Tok c="#ff7b72">def</Tok> <Tok c={FUNC}>slugify</Tok>(text):
            </div>
            <div>{'    text = text.strip().lower()'}</div>
            <div>
              {'    text = re.sub('}
              <Tok c={STR}>{'r"[^\\w\\s-]"'}</Tok>
              {', '}
              <Tok c={STR}>""</Tok>
              {', text)'}
            </div>
            <div>
              {'    '}
              <Tok c="#ff7b72">return</Tok>
              {' re.sub('}
              <Tok c={STR}>{'r"[\\s_-]+"'}</Tok>
              {', '}
              <Tok c={STR}>"-"</Tok>
              {', text)'}
            </div>
          </div>
        </FadeIn>
      </TerminalWindow>
      <Caption at={98}>
        <b style={{color: ACCENT}}>/clp</b> — smart copy. Just the deliverable.
      </Caption>
    </Scene>
  );
};

const PstScene: React.FC = () => {
  const {text, done} = useTyped('/pst', 58, 16);
  return (
    <Scene>
      <TerminalWindow>
        <FadeIn at={4}>
          <div style={{color: DIM, fontSize: 19, marginBottom: 8}}>
            📋 on your clipboard
          </div>
          <div
            style={{
              background: 'rgba(255,123,114,0.10)',
              border: `1px solid ${FENCE}`,
              borderRadius: 10,
              padding: '14px 20px',
              whiteSpace: 'pre',
              fontSize: 22,
            }}
          >
            <div>
              <Tok c={DIM}>Traceback (most recent call last):</Tok>
            </div>
            <div>
              <Tok c={DIM}>{'  File "config.py", line 42, in load'}</Tok>
            </div>
            <div>
              {'    timeout = cfg['}
              <Tok c={STR}>"timeout"</Tok>
              {']'}
            </div>
            <div>
              <Tok c={FENCE}>KeyError: 'timeout'</Tok>
            </div>
          </div>
        </FadeIn>
        <div style={{marginTop: 26}}>
          <Tok c={ACCENT}>❯</Tok> {text}
          <Cursor show={!done} />
        </div>
        <FadeIn at={86}>
          <Tok c={ACCENT}>● Claude</Tok>{' '}
          <Tok c={DIM}>found it — config.py:42 has no default.</Tok>
        </FadeIn>
        <FadeIn at={100}>
          <div
            style={{
              background: '#0a0c10',
              borderRadius: 10,
              padding: '12px 18px',
              marginTop: 10,
              whiteSpace: 'pre',
            }}
          >
            <div>
              <Tok c={FENCE}>{'-     timeout = cfg["timeout"]'}</Tok>
            </div>
            <div>
              <Tok c={GREEN}>{'+     timeout = cfg.get("timeout", 30)'}</Tok>
            </div>
          </div>
        </FadeIn>
        <FadeIn at={120} style={{marginTop: 14}}>
          <Tok c={GREEN}>✓ patched config.py</Tok>
        </FadeIn>
      </TerminalWindow>
      <Caption at={138}>
        <b style={{color: ACCENT}}>/pst</b> — smart paste. It acts on your
        clipboard.
      </Caption>
    </Scene>
  );
};

const ArgsScene: React.FC = () => {
  const chips: [string, string][] = [
    ['/clp the email', 'copies the last email you drafted'],
    ['/clp usernames', 'grabs every @handle mentioned'],
    ['/pst explain this', 'explains whatever you copied'],
    ['/pst run this', 'runs the command on your clipboard'],
    ['/pst add to utils.py', 'drops the snippet into the file'],
  ];
  return (
    <Scene>
      <FadeIn at={4}>
        <div
          style={{
            fontFamily: SANS,
            fontSize: 50,
            fontWeight: 800,
            color: '#fff',
            marginBottom: 38,
            textAlign: 'center',
          }}
        >
          Just <span style={{color: ACCENT}}>tell it</span> what you mean.
        </div>
      </FadeIn>
      <div style={{display: 'flex', flexDirection: 'column', gap: 18, width: 820}}>
        {chips.map(([cmd, desc], i) => (
          <FadeIn key={cmd} at={20 + i * 16} y={20}>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 20,
                background: '#0d1117',
                border: '1px solid #2b3542',
                borderRadius: 14,
                padding: '18px 24px',
              }}
            >
              <span
                style={{
                  fontFamily: MONO,
                  fontSize: 30,
                  color: ACCENT,
                  fontWeight: 600,
                  whiteSpace: 'nowrap',
                }}
              >
                {cmd}
              </span>
              <span style={{color: DIM, fontSize: 22}}>→</span>
              <span style={{fontFamily: SANS, fontSize: 26, color: '#c9d1d9'}}>
                {desc}
              </span>
            </div>
          </FadeIn>
        ))}
      </div>
    </Scene>
  );
};

const EndScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = spring({frame, fps, config: {damping: 13, stiffness: 120}});
  return (
    <Scene>
      <div
        style={{
          transform: `scale(${pop})`,
          display: 'flex',
          alignItems: 'center',
          gap: 18,
          marginBottom: 30,
        }}
      >
        <span style={{fontSize: 92}}>📋</span>
        <span
          style={{
            fontSize: 96,
            fontWeight: 800,
            color: '#fff',
            fontFamily: SANS,
            letterSpacing: -3,
          }}
        >
          SmartClip
        </span>
      </div>
      <FadeIn at={18}>
        <div
          style={{
            fontFamily: MONO,
            fontSize: 30,
            color: '#fff',
            background: '#0d1117',
            border: `1px solid ${ACCENT}`,
            borderRadius: 12,
            padding: '18px 28px',
          }}
        >
          /plugin marketplace add <Tok c={ACCENT}>jhammant/SmartClip</Tok>
        </div>
      </FadeIn>
      <FadeIn at={30} style={{marginTop: 24}}>
        <div style={{fontFamily: SANS, fontSize: 30, color: DIM}}>
          github.com/jhammant/SmartClip
        </div>
      </FadeIn>
      <FadeIn at={40} style={{marginTop: 12}}>
        <div style={{fontFamily: SANS, fontSize: 28, color: '#fff'}}>
          ⭐ Open source · MIT
        </div>
      </FadeIn>
    </Scene>
  );
};

/* ------------------------------------------------------------------ video */
export const SmartClipVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{backgroundColor: '#0b0d12'}}>
      <Series>
        <Series.Sequence durationInFrames={90}>
          <TitleScene />
        </Series.Sequence>
        <Series.Sequence durationInFrames={240}>
          <WriteScene />
        </Series.Sequence>
        <Series.Sequence durationInFrames={240}>
          <ClpScene />
        </Series.Sequence>
        <Series.Sequence durationInFrames={240}>
          <PstScene />
        </Series.Sequence>
        <Series.Sequence durationInFrames={180}>
          <ArgsScene />
        </Series.Sequence>
        <Series.Sequence durationInFrames={150}>
          <EndScene />
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};
