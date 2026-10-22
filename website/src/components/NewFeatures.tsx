import { motion, useReducedMotion } from 'framer-motion';
import './product-sections.css';

const shortcuts = [
  ['1, 2…', 'Open with a browser’s number'],
  ['← →', 'Choose with arrows, then press Return'],
  ['Esc', 'Cancel the picker'],
];

export const NewFeatures = () => {
  const reduceMotion = useReducedMotion();

  return (
    <section id="browser-picker" className="browser-picker-section page-width" aria-labelledby="picker-heading">
      <span id="how-it-works" className="section-anchor" aria-hidden="true" />
      <div className="picker-layout">
        <motion.figure
          className="picker-figure"
          initial={reduceMotion ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: reduceMotion ? 0 : 0.7 }}
        >
          <div className="picker-mount">
            <img
              src="/screenshots/brand-preview/prism-selector.png"
              alt="Prism browser picker showing Safari, Google Chrome, and Dia for a sample link from Mail"
              width={850}
              height={400}
              loading="lazy"
              decoding="async"
            />
          </div>
          <figcaption>BROWSER PICKER / BRAND PREVIEW · SAMPLE DATA</figcaption>
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
          <p className="picker-description">Use the picker, a preferred browser, or the last browser that opened a link. The picker appears near your pointer.</p>
          <ul className="picker-shortcuts" aria-label="Browser picker keyboard shortcuts">
            {shortcuts.map(([keys, description]) => (
              <li key={keys}>
                <kbd>{keys}</kbd>
                <span>{description}</span>
              </li>
            ))}
          </ul>
        </motion.div>
      </div>
    </section>
  );
};
