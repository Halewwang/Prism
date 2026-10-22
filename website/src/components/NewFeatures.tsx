import { useState } from 'react';
import { MousePointer2 } from 'lucide-react';

const workspaceScreens = [
  {
    id: 'rules',
    label: 'Rules',
    title: 'One list. Clear priorities.',
    description: 'Manage URL and source-app rules together, with a type label on each row. URL rules run before confirmed source-app rules; ordering sets priority within each type.',
    src: '/screenshots/brand-preview-2026-10-22/prism-rules-en.png',
    alt: 'Prism brand refresh preview Rules window with top navigation and a unified list of URL and source-app rules',
  },
  {
    id: 'history',
    label: 'History',
    title: 'See where each link went.',
    description: 'Search and filter local records from one compact toolbar. Open a record for routing details and available actions, with sensitive URL parameters hidden.',
    src: '/screenshots/brand-preview-2026-10-22/prism-history-en.png',
    alt: 'Prism brand refresh preview History window with a single-row search and filter toolbar above saved link records',
  },
  {
    id: 'settings',
    label: 'Settings',
    title: 'Set your defaults once.',
    description: 'Choose what happens when no rule matches, manage browser choices, and control how much history stays on your Mac.',
    src: '/screenshots/brand-preview-2026-10-22/prism-settings-en.png',
    alt: 'Prism brand refresh preview Settings window with default browser status, link handling, and local history preferences',
  },
];

export const NewFeatures = () => {
  const [selectedScreen, setSelectedScreen] = useState(workspaceScreens[0]);

  return (
    <section id="new-features" className="py-16 md:py-24 px-4 md:px-6 scroll-mt-24">
      <div className="container mx-auto max-w-6xl">
        <div className="text-center max-w-2xl mx-auto mb-8 md:mb-10">
          <span className="text-neutral-600 font-semibold tracking-wider uppercase text-xs md:text-sm">Interface &amp; brand preview</span>
          <h2 className="text-2xl md:text-3xl font-bold text-neutral-900 mt-2">A small window for your links.</h2>
          <p className="mt-4 text-base md:text-lg text-neutral-600 leading-relaxed">
            Rules, history, and settings share one compact native workspace.
          </p>
          <p className="mt-3 text-sm text-neutral-500 leading-relaxed">
            The refreshed icons shown here will ship in the next app update. The current public-test download uses the previous icons.
          </p>
        </div>

        <div role="group" aria-label="Choose a workspace screenshot" className="flex flex-wrap justify-center gap-2 mb-8">
          {workspaceScreens.map((screen) => (
            <button
              key={screen.id}
              type="button"
              aria-pressed={selectedScreen.id === screen.id}
              aria-controls="workspace-screenshot"
              onClick={() => setSelectedScreen(screen)}
              className={`rounded-full px-5 py-2.5 text-sm font-medium transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-neutral-900 focus-visible:outline-offset-4 ${
                selectedScreen.id === screen.id
                  ? 'bg-neutral-900 text-white'
                  : 'bg-neutral-100 text-neutral-700 hover:bg-neutral-200'
              }`}
            >
              {screen.label}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] gap-8 lg:gap-12 items-center">
          <div>
            <h3 className="text-xl md:text-2xl font-bold text-neutral-900 mb-3">{selectedScreen.title}</h3>
            <p className="text-base md:text-lg text-neutral-600 leading-relaxed">{selectedScreen.description}</p>
          </div>
          <figure id="workspace-screenshot" className="min-w-0">
            <img
              src={selectedScreen.src}
              alt={selectedScreen.alt}
              width={1600}
              height={1440}
              loading="lazy"
              decoding="async"
              className="w-full h-auto drop-shadow-xl"
            />
            <figcaption className="mt-5 flex flex-wrap items-center justify-between gap-2 text-xs md:text-sm text-neutral-500">
              <span>Brand refresh preview · Sample data</span>
              <a
                href={selectedScreen.src}
                target="_blank"
                rel="noreferrer"
                className="underline underline-offset-4 hover:text-neutral-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4"
              >
                Open original {selectedScreen.label.toLowerCase()} screenshot
              </a>
            </figcaption>
          </figure>
        </div>

        <div className="mt-20 md:mt-28 grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">
          <div>
            <div className="w-10 h-10 md:w-12 md:h-12 bg-neutral-100 rounded-xl flex items-center justify-center text-neutral-800 mb-4 md:mb-6">
              <MousePointer2 className="w-5 h-5 md:w-6 md:h-6" />
            </div>
            <h3 className="text-xl md:text-2xl font-bold text-neutral-900 mb-3">No rule? Make a quick choice.</h3>
            <p className="text-base md:text-lg text-neutral-600 leading-relaxed mb-5">
              The browser selector appears near your pointer and stays on screen. Click a browser, press its number, or use the arrow keys and Return. Escape cancels the choice.
            </p>
            <p className="text-sm md:text-base text-neutral-500 leading-relaxed">
              Scroll horizontally for more browsers. Manage visible choices in Settings; recently used browsers move forward after a successful open.
            </p>
          </div>
          <figure className="min-w-0">
            <img
              src="/screenshots/brand-preview-2026-10-22/prism-selector-en.png"
              alt="Prism brand refresh preview browser selector with numbered browser choices for a sample link"
              width={850}
              height={400}
              loading="lazy"
              decoding="async"
              className="w-full h-auto drop-shadow-xl"
            />
            <figcaption className="mt-5 flex flex-wrap items-center justify-between gap-2 text-xs md:text-sm text-neutral-500">
              <span>Brand refresh preview · Sample data</span>
              <a
                href="/screenshots/brand-preview-2026-10-22/prism-selector-en.png"
                target="_blank"
                rel="noreferrer"
                className="underline underline-offset-4 hover:text-neutral-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4"
              >
                Open original selector screenshot
              </a>
            </figcaption>
          </figure>
        </div>
      </div>
    </section>
  );
};
