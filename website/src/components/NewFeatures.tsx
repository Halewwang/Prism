import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { motion, useInView, useReducedMotion } from 'framer-motion';
import { ChevronLeft, ChevronRight, Mail, MoveHorizontal } from 'lucide-react';
import safariIcon from '../assets/browsers/safari.png';
import chromeIcon from '../assets/browsers/chrome.png';
import diaIcon from '../assets/browsers/dia.png';
import arcIcon from '../assets/browsers/arc.png';
import firefoxIcon from '../assets/browsers/firefox.png';
import './product-sections.css';

const browsers = [
  { name: 'Safari', icon: safariIcon },
  { name: 'Google Chrome', icon: chromeIcon },
  { name: 'Dia', icon: diaIcon },
  { name: 'Arc', icon: arcIcon },
  { name: 'Firefox', icon: firefoxIcon },
];
const shortcuts = [
  ['1, 2…', 'Open with a browser’s number'],
  ['← →', 'Choose with arrows, then press Return'],
  ['Esc', 'Cancel the picker'],
];

export const NewFeatures = () => {
  const reduceMotion = useReducedMotion();
  const preview = useRef<HTMLElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const cards = useRef<(HTMLButtonElement | null)[]>([]);
  const timer = useRef(0);
  const frame = useRef(0);
  const hasPlayed = useRef(false);
  const inView = useInView(preview, { once: true, amount: 0.5 });
  const [selected, setSelected] = useState(0);
  const [edges, setEdges] = useState({ start: true, end: false });

  const stopPreview = useCallback(() => {
    hasPlayed.current = true;
    window.clearTimeout(timer.current);
    window.cancelAnimationFrame(frame.current);
  }, []);

  useEffect(() => {
    const viewport = list.current;
    if (!viewport) return;
    const updateEdges = () => {
      const start = viewport.scrollLeft <= 1;
      const end = viewport.scrollLeft >= viewport.scrollWidth - viewport.clientWidth - 1;
      setEdges((previous) => previous.start === start && previous.end === end ? previous : { start, end });
    };
    const wheel = (event: WheelEvent) => {
      stopPreview();
      if (event.ctrlKey || event.metaKey) return;
      if (Math.abs(event.deltaX) >= Math.abs(event.deltaY)) return;
      const delta = event.deltaY * (event.deltaMode === 1 ? 24 : event.deltaMode === 2 ? viewport.clientWidth : 1);
      const next = Math.max(0, Math.min(viewport.scrollWidth - viewport.clientWidth, viewport.scrollLeft + delta));
      if (next !== viewport.scrollLeft) {
        event.preventDefault();
        viewport.scrollLeft = next;
      }
    };
    const observer = new ResizeObserver(updateEdges);
    observer.observe(viewport);
    viewport.addEventListener('scroll', updateEdges, { passive: true });
    viewport.addEventListener('wheel', wheel, { passive: false });
    updateEdges();
    return () => {
      observer.disconnect();
      viewport.removeEventListener('scroll', updateEdges);
      viewport.removeEventListener('wheel', wheel);
    };
  }, [stopPreview]);

  useEffect(() => {
    if (!inView || reduceMotion !== false || hasPlayed.current || !list.current) return;
    hasPlayed.current = true;
    timer.current = window.setTimeout(() => {
      const viewport = list.current!;
      const distance = viewport.scrollWidth - viewport.clientWidth;
      let started: number;
      const reveal = (now: number) => {
        started ??= now;
        const elapsed = now - started;
        const progress = elapsed <= 1800 ? elapsed / 1800 : elapsed <= 2200 ? 1 : Math.max(0, 1 - (elapsed - 2200) / 1800);
        viewport.scrollLeft = distance * progress;
        if (elapsed < 4000) frame.current = window.requestAnimationFrame(reveal);
      };
      frame.current = window.requestAnimationFrame(reveal);
    }, 800);
    return () => {
      window.clearTimeout(timer.current);
      window.cancelAnimationFrame(frame.current);
    };
  }, [inView, reduceMotion]);

  const selectBrowser = (index: number) => {
    stopPreview();
    setSelected(index);
    const card = cards.current[index];
    const viewport = list.current;
    if (!card || !viewport) return;
    card.focus({ preventScroll: true });
    viewport.scrollTo({ left: card.offsetLeft - (viewport.clientWidth - card.offsetWidth) / 2, behavior: reduceMotion ? 'instant' : 'smooth' });
  };

  const navigateBrowsers = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    let index: number;
    if (event.key === 'ArrowRight') index = (selected + 1) % browsers.length;
    else if (event.key === 'ArrowLeft') index = (selected + browsers.length - 1) % browsers.length;
    else if (event.key === 'Home') index = 0;
    else if (event.key === 'End') index = browsers.length - 1;
    else if (/^[1-5]$/.test(event.key)) index = Number(event.key) - 1;
    else return;
    event.preventDefault();
    selectBrowser(index);
  };

  const scrollBrowsers = (direction: number) => {
    stopPreview();
    list.current?.scrollBy({ left: direction * list.current.clientWidth * 0.8, behavior: reduceMotion ? 'instant' : 'smooth' });
  };

  return (
    <section id="browser-picker" className="browser-picker-section page-width" aria-labelledby="picker-heading">
      <span id="how-it-works" className="section-anchor" aria-hidden="true" />
      <div className="picker-layout">
        <motion.figure
          ref={preview}
          className="picker-figure"
          initial={reduceMotion ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: reduceMotion ? 0 : 0.7 }}
          onPointerDownCapture={stopPreview}
          onKeyDownCapture={stopPreview}
          onFocusCapture={stopPreview}
        >
          <div className="picker-mount">
            <div className="picker-preview" role="group" aria-label="Browser picker preview">
              <div className="picker-preview-header" aria-hidden="true">
                <span><Mail size={16} />Mail</span><span>https://developer.apple.com</span><span>Cancel</span>
              </div>
              <div ref={list} className="picker-browser-list" role="group" aria-label="Browser choices" aria-describedby="picker-scroll-hint" onKeyDown={navigateBrowsers}>
                {browsers.map((browser, index) => (
                  <button key={browser.name} ref={(element) => { cards.current[index] = element; }} className="picker-browser-card" type="button" aria-label={`Preview ${browser.name}`} aria-pressed={selected === index} onFocus={() => setSelected(index)} onClick={() => selectBrowser(index)}>
                    <img src={browser.icon} alt="" width={40} height={40} />
                    <span>{browser.name}</span><kbd aria-hidden="true">{index + 1}</kbd>
                  </button>
                ))}
              </div>
            </div>
          </div>
          <div className="picker-scroll-controls">
            <p id="picker-scroll-hint"><MoveHorizontal size={15} aria-hidden="true" />Scroll to see more browsers</p>
            <button type="button" aria-label="Scroll browsers left" disabled={edges.start} onClick={() => scrollBrowsers(-1)}><ChevronLeft size={17} aria-hidden="true" /></button>
            <button type="button" aria-label="Scroll browsers right" disabled={edges.end} onClick={() => scrollBrowsers(1)}><ChevronRight size={17} aria-hidden="true" /></button>
          </div>
          <figcaption>BROWSER PICKER / INTERACTIVE PREVIEW · SAMPLE DATA</figcaption>
        </motion.figure>
        <motion.div
          className="picker-explanation"
          initial={reduceMotion ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: reduceMotion ? 0 : 0.7, delay: reduceMotion ? 0 : 0.1 }}
        >
          <p className="product-label">02 / CHOOSE YOUR FALLBACK</p>
          <h2 id="picker-heading">No matching rule?<br />Choose what happens.</h2>
          <p className="picker-description">Use the picker, a preferred browser, or the last browser that opened a link. The picker appears near your pointer. Scroll sideways to see more browsers.</p>
          <ul className="picker-shortcuts" aria-label="Browser picker keyboard shortcuts">
            {shortcuts.map(([keys, description]) => (
              <li key={keys}><kbd>{keys}</kbd><span>{description}</span></li>
            ))}
          </ul>
        </motion.div>
      </div>
    </section>
  );
};
