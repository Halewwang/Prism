import { useEffect, useId, useRef, useState, type KeyboardEvent } from 'react';
import { ArrowUpRight, ChevronDown, ChevronLeft, ChevronRight, ChevronUp, Mail, RotateCw, X } from 'lucide-react';
import chromeIcon from '../assets/browsers/chrome.png';
import safariIcon from '../assets/browsers/safari.png';
import diaIcon from '../assets/browsers/dia.png';
import arcIcon from '../assets/browsers/arc.png';
import firefoxIcon from '../assets/browsers/firefox.png';
import './link-preview-demo.css';

const browsers = [
  { name: 'Google Chrome', icon: chromeIcon },
  { name: 'Safari', icon: safariIcon },
  { name: 'Dia', icon: diaIcon },
  { name: 'Arc', icon: arcIcon },
  { name: 'Firefox', icon: firefoxIcon },
];

export const LinkPreviewDemo = () => {
  const id = useId();
  const windowRef = useRef<HTMLDivElement>(null);
  const controlsRef = useRef<HTMLDivElement>(null);
  const compactRef = useRef<HTMLButtonElement>(null);
  const choicesRef = useRef<HTMLDivElement>(null);
  const stripRef = useRef<HTMLDivElement>(null);
  const pageRef = useRef<HTMLDivElement>(null);
  const reopenRef = useRef<HTMLButtonElement>(null);
  const restoreBrowserFocus = useRef(false);
  const [selected, setSelected] = useState(0);
  const [choicesOpen, setChoicesOpen] = useState(false);
  const [closed, setClosed] = useState(false);
  const [message, setMessage] = useState('Google page screenshot · Interactive toolbar demo.');

  useEffect(() => {
    if (closed) reopenRef.current?.focus({ preventScroll: true });
    else if (restoreBrowserFocus.current) {
      restoreBrowserFocus.current = false;
      const browser = compactRef.current?.getClientRects().length
        ? compactRef.current
        : controlsRef.current?.querySelector<HTMLButtonElement>(`.link-preview-demo-wide [data-browser-index="${selected}"]`);
      browser?.focus({ preventScroll: true });
    }
  }, [closed, selected]);

  useEffect(() => {
    const windowElement = windowRef.current;
    if (!windowElement) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry.contentRect.width >= 560) setChoicesOpen(false);
    });
    observer.observe(windowElement);
    return () => observer.disconnect();
  }, [closed]);

  useEffect(() => {
    const list = choicesOpen ? choicesRef.current : stripRef.current;
    const choice = list?.querySelector<HTMLButtonElement>(`[data-browser-index="${selected}"]`);
    if (!list || !choice) return;
    if (choicesOpen) {
      list.scrollTop = Math.max(0, choice.offsetTop - (list.clientHeight - choice.offsetHeight) / 2);
    } else {
      list.scrollLeft = Math.max(0, choice.offsetLeft - (list.clientWidth - choice.offsetWidth) / 2);
    }
  }, [selected, choicesOpen]);

  const isCompact = () => Boolean(compactRef.current?.getClientRects().length);

  const moveBrowser = (delta: number) => {
    const next = (selected + delta + browsers.length) % browsers.length;
    setSelected(next);
    if (isCompact()) setChoicesOpen(true);
    const focusScope = isCompact()
      ? choicesRef.current?.contains(document.activeElement) ? choicesRef.current : null
      : controlsRef.current?.querySelector('.link-preview-demo-wide');
    focusScope?.querySelector<HTMLButtonElement>(`[data-browser-index="${next}"]`)?.focus({ preventScroll: true });
    setMessage(`${browsers[next].name} selected. Press Enter to try opening the page.`);
  };

  const openBrowser = (index: number) => {
    setSelected(index);
    setChoicesOpen(false);
    setMessage(`Demo: this page would open in ${browsers[index].name}. No app was launched.`);
    const browser = isCompact()
      ? compactRef.current
      : controlsRef.current?.querySelector<HTMLButtonElement>(`.link-preview-demo-wide [data-browser-index="${index}"]`);
    browser?.focus({ preventScroll: true });
  };

  const closePreview = () => {
    setChoicesOpen(false);
    setClosed(true);
    setMessage('Preview closed. Open it again to keep exploring.');
  };

  const handleKey = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.altKey || event.ctrlKey || event.metaKey || event.isPropagationStopped()) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closePreview();
      return;
    }
    const inBrowserControls = controlsRef.current?.contains(event.target as Node);
    if (!inBrowserControls) return;
    if (/^[1-5]$/.test(event.key)) {
      event.preventDefault();
      openBrowser(Number(event.key) - 1);
    } else if (['ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight'].includes(event.key)) {
      event.preventDefault();
      moveBrowser(event.key === 'ArrowUp' || event.key === 'ArrowLeft' ? -1 : 1);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      const focusedIndex = (event.target as HTMLElement).closest<HTMLButtonElement>('[data-browser-index]')?.dataset.browserIndex;
      openBrowser(focusedIndex === undefined ? selected : Number(focusedIndex));
    }
  };

  const browserButton = (index: number) => (
    <button
      key={index}
      type="button"
      className="link-preview-demo-choice"
      data-browser-index={index}
      aria-label={`Open sample page in ${browsers[index].name}, shortcut ${index + 1}`}
      aria-pressed={selected === index}
      title={`${browsers[index].name}${index === 0 ? ' · Recommended' : ''}`}
      onClick={() => openBrowser(index)}
      onFocus={() => setSelected(index)}
    >
      <img src={browsers[index].icon} alt="" width={21} height={21} />
      <kbd aria-hidden="true">{index + 1}</kbd>
    </button>
  );

  return (
    <div className="link-preview-demo">
      <div className="link-preview-demo-stage">
        {closed ? (
          <div className="link-preview-demo-closed">
            <span className="link-preview-demo-closed-mark"><Mail size={24} aria-hidden="true" /></span>
            <p>A quick look, then back to your day.</p>
            <button ref={reopenRef} type="button" onClick={() => { restoreBrowserFocus.current = true; setClosed(false); setMessage('Preview reopened. Choose a browser to continue.'); }}>Open preview <ArrowUpRight size={16} aria-hidden="true" /></button>
          </div>
        ) : (
          <div
            ref={windowRef}
            className="link-preview-demo-window"
            role="group"
            aria-label="Interactive link preview example"
            onKeyDown={handleKey}
            onPointerDownCapture={(event) => {
              if (!controlsRef.current?.contains(event.target as Node)) setChoicesOpen(false);
            }}
          >
            <div className="link-preview-demo-toolbar">
              <div className="link-preview-demo-source" aria-label="Link from Mail">
                <span><Mail size={15} aria-hidden="true" /></span><b>Mail</b>
              </div>
              <div className="link-preview-demo-address">
                <button type="button" disabled aria-label="Back, no previous page"><ChevronLeft size={16} aria-hidden="true" /></button>
                <button type="button" disabled aria-label="Forward, no next page"><ChevronRight size={16} aria-hidden="true" /></button>
                <span title="https://www.google.com/">https://www.google.com/</span>
                <button type="button" aria-label="Reset Google screenshot preview" onClick={() => { pageRef.current?.scrollTo({ top: 0, behavior: 'instant' }); setMessage('Google screenshot preview reset.'); }}><RotateCw size={16} aria-hidden="true" /></button>
              </div>
              <div
                ref={controlsRef}
                className="link-preview-demo-browser-controls"
                role="group"
                aria-label="Choose a browser for the sample page"
                onBlur={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setChoicesOpen(false); }}
              >
                <div className="link-preview-demo-wide">
                  {browserButton(0)}
                  <span className="link-preview-demo-divider" aria-hidden="true" />
                  <div ref={stripRef} className="link-preview-demo-strip">{browsers.slice(1).map((_, index) => browserButton(index + 1))}</div>
                </div>
                <div className="link-preview-demo-compact">
                  <button ref={compactRef} type="button" className="link-preview-demo-choice" data-browser-index={selected} title={browsers[selected].name} aria-label={`Open sample page in ${browsers[selected].name}, shortcut ${selected + 1}`} onClick={() => openBrowser(selected)}>
                    <img src={browsers[selected].icon} alt="" width={21} height={21} /><kbd aria-hidden="true">{selected + 1}</kbd>
                  </button>
                  <div className="link-preview-demo-steppers">
                    <button type="button" aria-label="Previous browser" aria-expanded={choicesOpen} aria-controls={`${id}-choices`} onClick={() => moveBrowser(-1)}><ChevronUp size={12} aria-hidden="true" /></button>
                    <button type="button" aria-label="Next browser" aria-expanded={choicesOpen} aria-controls={`${id}-choices`} onClick={() => moveBrowser(1)}><ChevronDown size={12} aria-hidden="true" /></button>
                  </div>
                </div>
                {choicesOpen && <div ref={choicesRef} id={`${id}-choices`} className="link-preview-demo-candidates" role="group" aria-label="Browser candidates">{browsers.map((_, index) => browserButton(index))}</div>}
              </div>
              <button type="button" className="link-preview-demo-close" aria-label="Close sample preview, Escape" onClick={closePreview}><X size={15} aria-hidden="true" /><span>esc</span></button>
            </div>
            <div ref={pageRef} className="link-preview-demo-page" tabIndex={0} aria-label="Google home page screenshot preview">
              <img className="link-preview-demo-page-image" src="/screenshots/1.15.0/google-home.jpg" alt="Actual Google home page screenshot" width={900} height={600} />
            </div>
          </div>
        )}
      </div>
      <p className="link-preview-demo-feedback" role="status" aria-live="polite" aria-atomic="true">{message}</p>
    </div>
  );
};
