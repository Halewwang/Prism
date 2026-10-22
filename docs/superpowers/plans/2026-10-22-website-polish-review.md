# Website UI polish review

Scope: the landing page, interactive link demo, screenshot tabs and installation disclosure. Preserve the approved desktop window proportions, neutral app surfaces, soft stage gradient and 560px P2 viewer. No new dependencies or native-app behavior changes.

Latest motion verification supersedes the earlier immediate-picker-unmount fix and 4800ms parked-state record. The final behavior uses persistent DOM with hidden controls made inert; normal playback parks on the picker at 5900ms.

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM | `website/src/components/product-sections.css:298` | Tablet copy and screenshots used different edges | Stacked content shares a 560px maximum and common edges | Align to shared edges; keep the section readable after reflow |
| MEDIUM | `website/src/components/Hero.tsx:22`, `Features.tsx:9`, `NewFeatures.tsx:43`, `HeroDemo.tsx:257` | Repeated descriptions and longer instructions | Shorter action-led copy, explicit matching/fallback and simulation limits | One voice and vocabulary; explain what happens next |
| MEDIUM | `website/src/components/HeroDemo.tsx:186`, `HeroDemo.tsx:219` | A fading picker temporarily retained focusable buttons | Picker and destination stay mounted; hidden modules use `inert`, `aria-hidden` and disabled pointer input | Keep opacity fades while removing obsolete controls from keyboard navigation |
| MEDIUM | `website/src/components/HeroDemo.tsx:174`, `hero-demo.css:34`, `hero-demo.css:43`, `hero-demo.css:63` | Conditional modules and replaced guide copy flashed between steps | Picker, destination and both guide variants stay mounted with 200ms linear opacity transitions; destination/guide entry waits 200ms | Let the previous module exit before the next fades in; preserve reversible transitions |
| MEDIUM | `website/src/components/HeroDemo.tsx:21`, `HeroDemo.tsx:54`, `hero-demo.css:117` | Normal loading briefly showed picker before idle; Mail geometry used a different motion rhythm | Normal loading starts idle; playback follows the 5900ms sequence; Mail geometry transitions over 200ms linearly | Avoid a first-frame state flash and keep the sequence consistent |
| MEDIUM | `website/src/components/PublicTest.tsx:34` | The guide link targeted content inside a closed disclosure | The link opens and targets the native details element | Links must deliver their named destination |
| LOW | `website/src/index.css:128`, `hero-demo.css:102`, `product-sections.css:145` | Hover styling also applied on touch | Hover is restricted to capable pointers; selected/pressed cues remain static | Prevent sticky hover feedback |
| LOW | `website/src/index.css:134`, `hero-demo.css:109`, `Hero.tsx:8` | Inconsistent press/entrance feedback | 0.96 press scale over 150ms; staged hero entrance at 100ms intervals; reduced motion uses opacity | Match the UI motion language and user preference |

Verification: website build and ESLint; independent code review; browser checks at 1440, 1293, 1100, 901, 900, 768, 390 and 320 CSS pixels. No horizontal overflow, clipped result window, shifted tab frame or runtime error was observed. All three browser choices preserve the sample URL. Cancel/rapid reopen, focus return, arrows, number keys, Escape, screenshot arrows/Home/End and guide expansion passed. Desktop slogan/download bottom edges remain aligned. Screenshot windows retain their full 1600×1440 images and accurate v1.14.9 sample-data labels.

Latest IAB validation sampled 1796 frames. Normal first playback and Replay follow idle → picker at 1100ms → destination at 2800ms → idle at 4800ms for another Mail link click → parked picker at 5900ms. Opacity values progressed monotonically through intermediate frames without rebound. Arrow keys, number key 3, Escape and manual Chrome/Dia selection passed. Manual input cancels the remaining timers; opening Safari manually during the closing idle step stayed opened beyond the pending 5900ms return. Reduced motion stayed on the static picker for 6.4 seconds and uses only 150ms opacity fades without entry delay when operated. Latest 320/390px checks found no horizontal overflow. A 646×550 CSS viewport at 2× density passed the earlier 200% reflow equivalent.

The P1 `.demo-stage`, `.workspace-mount` and `.picker-mount` computed background-image values are identical: `linear-gradient(225deg, #dde3e8, #eff2f4 55%, #d8e2d3)`. The two simulated windows retain neutral surfaces.

Not verified: physical touch hardware, physical Intel/native handoff, screen readers, native browser zoom, localization/RTL, and the browser Animations panel at 10% speed. A CDP slow-motion attempt timed out, so it is not counted as verified. Transparent app screenshots intentionally skip a rectangular image outline. Native picker geometry remains the approved reference.

After rebasing onto current main, build and ESLint passed again. The browser confirmed all three download links target the exact v1.14.11 Universal DMG, no old repository links remain, and the repository-migration manual-upgrade guidance is retained. Native code, app scripts and release manifests have no differences from main.

Approve for the inspected landing-page scope; no known HIGH findings remain. Production publication requires a separate check of the deployed commit and page.
