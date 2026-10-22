import { motion, useReducedMotion } from 'framer-motion';
import './product-sections.css';

const benefits = [
  {
    letter: 'A',
    title: 'URL rules run first',
    description: 'Match an exact domain, its subdomains, or text in a URL. Source-app rules run only when the sender is confirmed; detection varies by app.',
  },
  {
    letter: 'B',
    title: 'Rules and history stay local',
    description: 'Routing rules and link history stay on your Mac. Update checks contact GitHub; browsing history is not uploaded.',
  },
];

export const Features = () => {
  const reduceMotion = useReducedMotion();

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
          <p className="product-label">BRAND REFRESH PREVIEW / SAMPLE DATA</p>
        </div>
        <div className="product-editorial">
          <div className="routing-introduction">
            <h2 id="routing-heading">Route links by URL<br />or source app.</h2>
            <p>Set Prism as your default browser to route HTTP and HTTPS links opened from other apps. Manage rules, link history, and settings in one native workspace.</p>
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
        </div>
      </motion.div>
    </section>
  );
};
