import { useRef, useState, type KeyboardEvent } from 'react';
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
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);

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
    setActiveView(nextIndex);
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
              <div className="workspace-tabs" role="tablist" aria-label="App screenshot views">
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
                    onClick={() => setActiveView(index)}
                    onKeyDown={(event) => navigateTabs(event, index)}
                  >
                    {view.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
          <figure className="workspace-showcase">
            <div className="workspace-mount">
              {workspaceViews.map((view, index) => (
                <div
                  key={view.id}
                  role="tabpanel"
                  id={`workspace-panel-${view.id}`}
                  aria-labelledby={`workspace-tab-${view.id}`}
                  className="workspace-panel"
                  hidden={activeView !== index}
                  tabIndex={0}
                >
                  <img
                    src={`/screenshots/1.14.9/prism-${view.id}-en.png`}
                    alt={view.alt}
                    width="1600"
                    height="1440"
                    loading="lazy"
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
