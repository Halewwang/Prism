import { useRef } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { ArrowDownToLine } from 'lucide-react';
import { release } from '../release';

export const PublicTest = () => {
  const reduceMotion = useReducedMotion();
  const guideRef = useRef<HTMLDetailsElement>(null);

  return (
    <>
      <section id="download" className="closing-download" aria-labelledby="download-title">
        <motion.div className="page-width closing-inner" initial={reduceMotion ? false : { opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.25 }}>
          <p className="mono-label">03 / Try Prism on macOS</p>
          <div className="closing-row">
            <h2 id="download-title">Choose where<br />your links open.</h2>
            <div className="closing-actions">
              <a className="download-button download-button-dark" href={release.downloadUrl}>
                Download public test <ArrowDownToLine size={18} aria-hidden="true" />
              </a>
              <p className="mono-label">{release.minimumSystem} / Universal installer</p>
            </div>
          </div>
        </motion.div>
      </section>
      <section id="public-test" className="installation page-width" aria-labelledby="installation-title">
        <div className="installation-label">
          <h2 id="installation-title" className="mono-label">Before you install</h2>
          <p>v{release.version} · Build {release.build}</p>
        </div>
        <div className="installation-content">
          <p>This public test uses ad hoc signing, without Developer ID signing or Apple notarization. Verify the checksum before installing. Chrome and Edge profile targets are experimental; the Intel build has not been tested on a physical Intel Mac.</p>
          <div className="support-links">
            <a href="#installation-guide" onClick={() => guideRef.current?.setAttribute('open', '')}>Installation guide ↗</a>
            <a href={release.notesUrl}>Release notes ↗</a>
            <a href={release.issuesUrl}>Report an issue ↗</a>
          </div>
          <details id="installation-guide" ref={guideRef} className="installation-guide">
            <summary>Installation guide &amp; test limits</summary>
            <div className="installation-instructions">
              <p>v{release.version}, build {release.build} requires {release.minimumSystem}. The Universal download includes Apple Silicon and Intel binaries.</p>
              <ol>
                <li>Download the DMG and <a href={release.checksumsUrl}>SHA256SUMS.txt</a>. In the download folder, run <code>shasum -a 256 -c SHA256SUMS.txt</code> to check file integrity.</li>
                <li>Quit Prism, open the DMG, and drag Prism into Applications. Then try opening Prism.</li>
                <li>If macOS blocks this trusted download because it cannot verify the developer, go to System Settings → Privacy &amp; Security → Open Anyway, then confirm Open. Follow <a href="https://support.apple.com/en-us/102445">Apple’s first-open guidance</a>. Do not use this step for a malware or damaged-app warning.</li>
              </ol>
              <h3>Updating this public test</h3>
              <p>After the repository rename, native v1.14.10 and earlier need one manual installation of the current version. From v1.14.11 onward, Prism can download and verify future updates in Settings, then ask you to confirm installation. The option to allow an unnotarized public-test update is off by default and applies only to that installation. Prism restores the previous version if the new app fails to launch. macOS may still block an unnotarized app, and manual installation may be needed.</p>
              <h3>What still needs real-world testing</h3>
              <ul>
                <li>Source-app routing only runs for a confirmed sender. Real-app coverage is still incomplete; not every app or link can be identified.</li>
                <li>Stable Chrome and Edge profile targets are experimental. Cold and already-running launches, account context, and profile removal still need real-browser validation.</li>
                <li>The Intel binary is included, but this release has not been verified on a physical Intel Mac. Supported macOS versions have not all been tested.</li>
              </ul>
            </div>
          </details>
        </div>
      </section>
    </>
  );
};
