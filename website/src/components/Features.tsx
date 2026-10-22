import { useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import './product-sections.css';

const benefits = [
  {
    letter: 'A',
    title: 'URL rules run first',
    description: 'Match domains, subdomains, or URL text. Source-app rules follow only for a confirmed sender; detection varies by app.',
  },
  {
    letter: 'B',
    title: 'Rules and history stay local',
    description: 'Rules and link history aren’t uploaded. Update checks contact GitHub.',
  },
];

const workspaceViews = [
  {
    id: 'rules',
    label: 'Rules',
    description: 'Set rules for URLs and source apps.',
    alt: 'Prism Rules window showing URL and source-app rules with their selected browsers.',
  },
  {
    id: 'history',
    label: 'History',
    description: 'See where each link was opened.',
    alt: 'Prism History window showing sample links, source apps, selected browsers, and routing results.',
  },
  {
    id: 'settings',
    label: 'Settings',
    description: 'Set a fallback and manage privacy.',
    alt: 'Prism Settings window showing default browser setup, fallback behavior, and local history settings.',
  },
];

export const Features = () => {
  const reduceMotion = useReducedMotion();
  const [activeView, setActiveView] = useState(0);
  const [paused, setPaused] = useState(false);
  const [inView, setInView] = useState(false);
  const [imageState, setImageState] = useState<'loading' | 'ready' | 'error'>('loading');
  const showcase = useRef<HTMLElement>(null);
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const imageRefs = useRef<(HTMLImageElement | null)[]>([]);
  const isPlaying = !paused && !reduceMotion;
  const imagesReady = imageState === 'ready';

  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      setInView(entry.isIntersecting && entry.intersectionRatio >= 0.25);
    }, { threshold: 0.25 });
    if (showcase.current) observer.observe(showcase.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    let cancelled = false;
    Promise.all(imageRefs.current.map((image) => image?.decode())).then(() => {
      if (!cancelled) setImageState('ready');
    }).catch(() => {
      if (!cancelled) setImageState('error');
    });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!isPlaying || !inView || !imagesReady) return;
    const timer = window.setInterval(() => {
      setActiveView((index) => (index + 1) % workspaceViews.length);
    }, 3200);
    return () => window.clearInterval(timer);
  }, [isPlaying, inView, imagesReady]);

  const selectView = (index: number) => {
    setPaused(true);
    setActiveView(index);
  };

  const navigateTabs = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    let nextIndex: number;
    switch (event.key) {
      case 'ArrowRight': nextIndex = (index + 1) % workspaceViews.length; break;
      case 'ArrowLeft': nextIndex = (index + workspaceViews.length - 1) % workspaceViews.length; break;
      case 'Home': nextIndex = 0; break;
      case 'End': nextIndex = workspaceViews.length - 1; break;
      default: return;
    }
    event.preventDefault();
    selectView(nextIndex);
    tabRefs.current[nextIndex]?.focus();
  };

  return (
    <section id="features" className="product-routing page-width" aria-labelledby="routing-heading">
      <span id="new-features" className="section-anchor" aria-hidden="true" />
      <motion.div
        initial={reduceMotion ? false : { opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.15 }}
        transition={{ duration: reduceMotion ? 0 : 0.65 }}
      >
        <div className="product-section-heading">
          <p className="product-label">01 / URL &amp; SOURCE-APP ROUTING</p>
          <p className="product-label">NATIVE APP / SAMPLE DATA</p>
        </div>
        <div className="product-editorial">
          <div className="routing-copy">
            <div className="routing-introduction">
              <h2 id="routing-heading">Route links by URL<br />or source app.</h2>
              <p>Set Prism as your default browser to route HTTP and HTTPS links from other apps.</p>
            </div>
            <div className="routing-benefits">
              {benefits.map((benefit) => (
                <div className="routing-benefit" key={benefit.letter}>
                  <span className="benefit-letter" aria-hidden="true">{benefit.letter}</span>
                  <div>
                    <h3>{benefit.title}</h3>
                    <p>{benefit.description}</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="workspace-toolbar">
              <div className="workspace-tabs" role="tablist" aria-label="App screenshot views" onFocus={() => setPaused(true)}>
                {workspaceViews.map((view, index) => (
                  <button
                    key={view.id}
                    ref={(element) => { tabRefs.current[index] = element; }}
                    type="button"
                    role="tab"
                    id={`workspace-tab-${view.id}`}
                    aria-selected={activeView === index}
                    aria-controls={`workspace-panel-${view.id}`}
                    tabIndex={activeView === index ? 0 : -1}
                    disabled={!imagesReady}
                    onClick={() => selectView(index)}
                    onKeyDown={(event) => navigateTabs(event, index)}
                  >
                    {view.label}
                  </button>
                ))}
              </div>
              {!reduceMotion && (
                <button
                  className="workspace-playback"
                  type="button"
                  aria-label={isPlaying ? 'Pause screenshot slideshow' : 'Play screenshot slideshow'}
                  disabled={imageState === 'error'}
                  onClick={() => setPaused(!paused)}
                >
                  {isPlaying ? 'Pause' : 'Play'}
                </button>
              )}
            </div>
          </div>
          <figure className="workspace-showcase" ref={showcase}>
            <div className="workspace-mount">
              {!imagesReady && (
                <p className="workspace-loading" role="status">
                  {imageState === 'error' ? 'Screenshots couldn’t load. Reload the page to try again.' : 'Loading screenshots…'}
                </p>
              )}
              {workspaceViews.map((view, index) => (
                <div
                  key={view.id}
                  role="tabpanel"
                  id={`workspace-panel-${view.id}`}
                  aria-labelledby={`workspace-tab-${view.id}`}
                  className="workspace-panel"
                  aria-hidden={!imagesReady || activeView !== index}
                  inert={!imagesReady || activeView !== index}
                  tabIndex={imagesReady && activeView === index ? 0 : -1}
                  onFocus={() => setPaused(true)}
                >
                  <img
                    src={`/screenshots/1.14.9/prism-${view.id}-en.png`}
                    ref={(element) => { imageRefs.current[index] = element; }}
                    alt={view.alt}
                    width="1600"
                    height="1440"
                    loading="eager"
                  />
                </div>
              ))}
            </div>
            <figcaption className="workspace-caption">
              <span>{workspaceViews[activeView].description}</span>
              <span>App screenshots · v1.14.9 / sample data</span>
            </figcaption>
          </figure>
        </div>
      </motion.div>
    </section>
  );
};
