import { motion, useReducedMotion } from 'framer-motion';
import { ArrowDownToLine } from 'lucide-react';
import { release } from '../release';
import { HeroDemo } from './HeroDemo';

export const Hero = () => {
  const reduceMotion = useReducedMotion();
  const entrance = reduceMotion ? { opacity: 0 } : { opacity: 0, y: 12, filter: 'blur(4px)' };
  const visible = reduceMotion ? { opacity: 1 } : { opacity: 1, y: 0, filter: 'blur(0px)' };

  return (
    <section className="hero page-width" aria-labelledby="hero-title">
      <div className="hero-eyebrow mono-label">
        <p>A native browser router for macOS</p>
        <p>Public test / v{release.version}</p>
      </div>
      <div className="hero-introduction">
        <div className="hero-copy">
          <motion.h1 id="hero-title" initial={entrance} animate={visible} transition={{ duration: reduceMotion ? 0.15 : 0.3, ease: 'easeOut' }}>
            Your links.<br />In the right browser.
          </motion.h1>
          <motion.p className="hero-description" initial={entrance} animate={visible} transition={{ duration: reduceMotion ? 0.15 : 0.3, delay: reduceMotion ? 0 : 0.1, ease: 'easeOut' }}>Route links by website or source app. When you want a closer look, preview the page before choosing its browser.</motion.p>
        </div>
        <motion.div className="hero-actions" initial={entrance} animate={visible} transition={{ duration: reduceMotion ? 0.15 : 0.3, delay: reduceMotion ? 0 : 0.2, ease: 'easeOut' }}>
          <a className="download-button" href={release.downloadUrl}>
            Download public test <ArrowDownToLine size={18} aria-hidden="true" />
          </a>
          <div className="hero-download-details">
            <p className="hero-compatibility mono-label">{release.minimumSystem} / Apple Silicon + Intel</p>
            <p className="hero-signing">Not notarized. <a href="#public-test">Read installation notes</a> before opening.</p>
          </div>
        </motion.div>
      </div>
      <HeroDemo />
    </section>
  );
};
