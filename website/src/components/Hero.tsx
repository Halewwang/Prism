import { useRef } from 'react';
import { motion, useReducedMotion, useScroll, useTransform } from 'framer-motion';
import { ArrowDownToLine } from 'lucide-react';
import { release } from '../release';

export const Hero = () => {
  const hero = useRef<HTMLElement>(null);
  const reduceMotion = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: hero, offset: ['start start', 'end start'] });
  const rulesY = useTransform(scrollYProgress, [0, 1], [0, -24]);
  const pickerY = useTransform(scrollYProgress, [0, 1], [0, -56]);

  return (
    <section ref={hero} className="hero page-width" aria-labelledby="hero-title">
      <div className="hero-eyebrow mono-label">
        <p>A native browser router for macOS</p>
        <p>Public test / v{release.version}</p>
      </div>
      <div className="hero-introduction">
        <motion.h1 id="hero-title" initial={reduceMotion ? false : { opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
          Your links.<br />In the right browser.
        </motion.h1>
        <motion.div className="hero-actions" initial={reduceMotion ? false : { opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
          <p className="hero-description">Prism is a native browser router for macOS. Route links by URL or confirmed source app, or choose a browser yourself.</p>
          <a className="download-button" href={release.downloadUrl}>
            Download public test <ArrowDownToLine size={18} aria-hidden="true" />
          </a>
          <p className="hero-compatibility mono-label">{release.minimumSystem} / Apple Silicon + Intel</p>
          <p className="hero-signing">Not notarized. <a href="#public-test">Read installation notes</a> before opening.</p>
        </motion.div>
      </div>
      <motion.figure className="hero-showcase" initial={reduceMotion ? false : { opacity: 0, y: 28 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.1 }}>
        <motion.img className="hero-rules" style={{ y: reduceMotion ? 0 : rulesY }} src="/screenshots/brand-preview/prism-rules.png" alt="Prism rules workspace showing URL and source-app routing with sample data" width={1600} height={1440} fetchPriority="high" />
        <motion.img className="hero-picker" style={{ y: reduceMotion ? 0 : pickerY }} src="/screenshots/brand-preview/prism-selector.png" alt="Floating browser picker with Safari, Google Chrome, and Dia, using sample data" width={850} height={400} />
      </motion.figure>
      <div className="hero-footnotes mono-label">
        <p>01 / Main window · Manage your rules</p>
        <p>02 / Floating picker · Choose a browser</p>
      </div>
      <p className="screenshot-disclosure">Brand refresh preview with sample data. Updated icons are planned for the next app update; the current public test uses earlier icons.</p>
    </section>
  );
};
