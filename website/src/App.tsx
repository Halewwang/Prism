import { MotionConfig } from 'framer-motion';
import { Header } from './components/Header';
import { Hero } from './components/Hero';
import { Features } from './components/Features';
import { NewFeatures } from './components/NewFeatures';
import { PublicTest } from './components/PublicTest';
import { Footer } from './components/Footer';

function App() {
  return (
    <MotionConfig reducedMotion="user" transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}>
      <div className="prism-site">
        <a className="skip-link" href="#main">Skip to content</a>
        <Header />
        <main id="main" tabIndex={-1}>
          <Hero />
          <div className="product-details">
            <Features />
            <NewFeatures />
          </div>
          <PublicTest />
        </main>
        <Footer />
      </div>
    </MotionConfig>
  );
}

export default App;
