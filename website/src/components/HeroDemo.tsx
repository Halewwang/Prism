import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import type { KeyboardEvent } from 'react';
import { ArrowLeft, ArrowRight, ArrowUpRight, Check, ChevronDown, LockKeyhole, Mail, MousePointer2, RotateCcw } from 'lucide-react';
import { useReducedMotion } from 'framer-motion';
import safariIcon from '../assets/browsers/safari.png';
import chromeIcon from '../assets/browsers/chrome.png';
import diaIcon from '../assets/browsers/dia.png';
import './hero-demo.css';

const browsers = [
  { name: 'Safari', icon: safariIcon },
  { name: 'Google Chrome', icon: chromeIcon },
  { name: 'Dia', icon: diaIcon },
];
const destination = 'https://example.com/design-review';
type DemoState = 'idle' | 'picker' | 'opened';

const WindowControls = () => <span className="demo-window-controls" aria-hidden="true"><i /><i /><i /></span>;

export const HeroDemo = () => {
  const [state, setState] = useState<DemoState>(() => window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'picker' : 'idle');
  const [browserIndex, setBrowserIndex] = useState(0);
  const [autoplay, setAutoplay] = useState(false);
  const region = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const link = useRef<HTMLButtonElement>(null);
  const result = useRef<HTMLDivElement>(null);
  const browserButtons = useRef<(HTMLButtonElement | null)[]>([]);
  const timers = useRef<number[]>([]);
  const hasPlayed = useRef(false);
  const moveFocus = useRef(false);
  const reducedMotion = useReducedMotion();
  const browser = browsers[browserIndex];

  const clearTimers = useCallback(() => {
    timers.current.forEach(window.clearTimeout);
    timers.current = [];
  }, []);

  const stopAutoplay = useCallback(() => {
    clearTimers();
    hasPlayed.current = true;
    setAutoplay(false);
  }, [clearTimers]);

  const play = useCallback(() => {
    clearTimers();
    hasPlayed.current = true;
    moveFocus.current = false;
    setBrowserIndex(0);
    setState('idle');
    setAutoplay(true);
    timers.current = [
      window.setTimeout(() => setState('picker'), 1100),
      window.setTimeout(() => setState('opened'), 2800),
      window.setTimeout(() => setState('idle'), 4800),
      window.setTimeout(() => {
        setState('picker');
        setAutoplay(false);
      }, 5900),
    ];
  }, [clearTimers]);

  useEffect(() => {
    if (reducedMotion || hasPlayed.current || !region.current) return;
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting && !hasPlayed.current) {
        play();
        observer.disconnect();
      }
    }, { threshold: 0.25 });
    observer.observe(region.current);
    return () => observer.disconnect();
  }, [play, reducedMotion]);

  useEffect(() => () => clearTimers(), [clearTimers]);

  useLayoutEffect(() => {
    if (!autoplay || !stage.current) return;
    const target = state === 'idle' ? link.current : state === 'picker' ? browserButtons.current[0] : null;
    if (!target) return;
    const bounds = target.getBoundingClientRect();
    const stageBounds = stage.current.getBoundingClientRect();
    stage.current.style.setProperty('--demo-cursor-x', `${bounds.left - stageBounds.left + bounds.width / 2}px`);
    stage.current.style.setProperty('--demo-cursor-y', `${bounds.top - stageBounds.top + bounds.height / 2}px`);
  }, [state, autoplay]);

  useEffect(() => {
    if (!moveFocus.current) return;
    if (state === 'picker') browserButtons.current[browserIndex]?.focus({ preventScroll: true });
    if (state === 'opened') result.current?.focus({ preventScroll: true });
    moveFocus.current = false;
  }, [state, browserIndex]);

  const openPicker = () => {
    stopAutoplay();
    moveFocus.current = state !== 'picker';
    setState('picker');
    if (state === 'picker') browserButtons.current[browserIndex]?.focus({ preventScroll: true });
  };

  const openBrowser = (index: number) => {
    stopAutoplay();
    moveFocus.current = true;
    setBrowserIndex(index);
    setState('opened');
  };

  const reset = () => {
    stopAutoplay();
    setState('idle');
    link.current?.focus({ preventScroll: true });
  };

  const pickerKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    if (/^[1-3]$/.test(event.key)) {
      event.preventDefault();
      openBrowser(Number(event.key) - 1);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      reset();
    } else if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      const next = (browserIndex + (event.key === 'ArrowRight' ? 1 : -1) + browsers.length) % browsers.length;
      setBrowserIndex(next);
      browserButtons.current[next]?.focus({ preventScroll: true });
    }
  };

  const status = state === 'idle'
    ? 'Click the Mail link to open the picker.'
    : state === 'picker'
      ? 'Choose a browser to open the link.'
      : `The same link is open in ${browser.name}.`;

  return (
    <div
      ref={region}
      id="try-prism"
      className={`hero-demo${autoplay ? ' is-autoplay' : ''}`}
      role="region"
      aria-label="Try Prism"
      data-state={state}
      onPointerDownCapture={stopAutoplay}
      onKeyDownCapture={stopAutoplay}
      onFocusCapture={stopAutoplay}
    >
      <div ref={stage} className="demo-stage">
        <div className="demo-menubar" aria-hidden="true">
          <span><img src="/brand/titlebar-32.svg" alt="" width={18} height={18} />Prism on your Mac</span>
          <span className="demo-simulation-label">Interactive demo</span>
        </div>

        <div className="demo-mail-window">
          <div className="demo-mail-toolbar"><WindowControls /><span><Mail size={15} aria-hidden="true" />Mail</span><span className="demo-toolbar-detail" aria-hidden="true">1 message</span></div>
          <div className="demo-mail-layout">
            <aside className="demo-mail-sidebar" aria-hidden="true">
              <span className="demo-sidebar-label">FAVORITES</span>
              <span className="demo-mailbox"><Mail size={14} />Inbox <b>3</b></span>
              <span>Sent</span><span>Drafts</span>
            </aside>
            <div className="demo-message">
              <p className="demo-message-subject">A fresh perspective</p>
              <div className="demo-message-sender"><span className="demo-avatar">M</span><span><strong>Maya Chen</strong><small>To: you <ChevronDown size={10} aria-hidden="true" /></small></span><time>9:41 AM</time></div>
              <p>Hey Alex,</p>
              <p>The new design is ready for a look.<br />Here’s the review link:</p>
              <button ref={link} className="demo-source-link" onClick={openPicker}>{destination}<ArrowUpRight size={14} aria-hidden="true" /></button>
              <p className="demo-message-signoff">Let me know what you think.<br /><span>Maya</span></p>
            </div>
          </div>
        </div>

        {(['idle', 'picker'] as const).map((guideState) => (
          <aside key={guideState} className={`demo-guide${state === guideState ? ' is-visible' : ''}`} aria-label="Demo guide" aria-hidden={state !== guideState}>
            <p className="demo-guide-step">{guideState === 'idle' ? '01 / CLICK A LINK' : '02 / CHOOSE A BROWSER'}</p>
            <h3>{guideState === 'idle' ? 'Start with a link.' : 'Choose your browser.'}</h3>
            <p className="demo-guide-description">{guideState === 'idle' ? 'Click the Mail link to open Prism’s browser picker.' : 'Click a browser, or press 1, 2 or 3.'}</p>
            <div className="demo-guide-footer">
              {guideState === 'idle'
                ? <span className="demo-guide-flow">Mail<ArrowRight size={11} aria-hidden="true" />Prism<ArrowRight size={11} aria-hidden="true" />Browser</span>
                : <><span className="demo-guide-keys"><kbd>1</kbd><kbd>2</kbd><kbd>3</kbd></span><span>Shortcuts</span></>}
            </div>
          </aside>
        ))}

          <div
            className="demo-picker"
            role="group"
            aria-label="Choose a browser"
            aria-hidden={state !== 'picker'}
            inert={state !== 'picker'}
            onKeyDown={pickerKeyDown}
          >
            <div className="demo-picker-header">
              <span className="demo-picker-source"><span className="demo-mail-icon"><Mail size={15} aria-hidden="true" /></span>Mail</span>
              <span className="demo-picker-url" title={destination}>example.com/design-review</span>
              <button className="demo-picker-cancel" onClick={reset}>Cancel</button>
            </div>
            <div className="demo-browser-choices">
              {browsers.map((choice, index) => (
                <button
                  key={choice.name}
                  ref={(element) => { browserButtons.current[index] = element; }}
                  className={`demo-browser-choice${browserIndex === index ? ' is-selected' : ''}`}
                  aria-label={`Open in ${choice.name}`}
                  onFocus={() => setBrowserIndex(index)}
                  onPointerEnter={(event) => { if (!autoplay && event.pointerType !== 'touch' && window.matchMedia('(hover: hover)').matches) setBrowserIndex(index); }}
                  onClick={() => openBrowser(index)}
                >
                  <img src={choice.icon} alt="" width={45} height={45} />
                  <span>{choice.name}</span>
                  <kbd aria-hidden="true">{index + 1}</kbd>
                </button>
              ))}
            </div>
          </div>

          <div
            ref={result}
            className="demo-destination-window"
            tabIndex={state === 'opened' ? -1 : undefined}
            aria-label={`${browser.name} browser window`}
            aria-hidden={state !== 'opened'}
            inert={state !== 'opened'}
            style={{ pointerEvents: state === 'opened' ? 'auto' : 'none' }}
          >
            <div className="demo-browser-toolbar"><WindowControls /><span className="demo-browser-tab"><img src={browser.icon} alt="" width={16} height={16} />{browser.name}<span>— Design review</span></span></div>
            <div className="demo-addressbar"><span aria-hidden="true"><ArrowLeft size={14} /><ArrowRight size={14} /></span><div><LockKeyhole size={11} aria-hidden="true" />{destination}</div><span className="demo-address-menu" aria-hidden="true">···</span></div>
            <div className="demo-destination-page">
              <div className="demo-review-nav"><span><span className="demo-review-logomark" aria-hidden="true" />studio notes</span><span>DESIGN REVIEW / 01</span></div>
              <div className="demo-review-content"><span className="demo-review-eyebrow">GOOD IDEAS START WITH A LINK.</span><h3>A fresh<br />perspective.</h3><p>A little room for better ideas.<br />Ready when you are.</p><div className="demo-review-art" aria-hidden="true"><span>Review notes</span><i /><i /><i /></div></div>
              <div className="demo-opened-badge"><Check size={13} aria-hidden="true" />Opened in {browser.name}</div>
            </div>
          </div>

        <div className="demo-cursor" aria-hidden="true"><MousePointer2 size={28} fill="currentColor" /><span /></div>
      </div>

      <div className="demo-controls">
        <ol className="demo-progress" aria-label="How Prism opens a link">
          {['Click a link', 'Choose a browser', 'Open the link'].map((label, index) => {
            const current = ['idle', 'picker', 'opened'].indexOf(state);
            return <li key={label} className={index <= current ? 'is-current' : ''} aria-current={index === current ? 'step' : undefined}><span>{index < current ? <Check size={12} aria-hidden="true" /> : `0${index + 1}`}</span>{label}</li>;
          })}
        </ol>
        <div className="demo-playback-controls">
          <button className="demo-try-button" onClick={reset}>Try it yourself<ArrowUpRight size={14} aria-hidden="true" /></button>
          <button className="demo-replay-button" onClick={play}><RotateCcw size={14} aria-hidden="true" />Replay</button>
        </div>
      </div>
      <div className="demo-explanation"><p className="demo-live-status" role="status" aria-live="polite" aria-atomic="true">{status}</p><p>Prism is the default browser; no rule matches; fallback is “Always ask”.<br className="demo-disclosure-break" /> Simulated flow. No apps open on your Mac.</p></div>
    </div>
  );
};
