# Website UI polish review

Scope: the landing page, interactive link demo, screenshot tabs and installation disclosure. Preserve the approved desktop window proportions, neutral app surfaces, soft stage gradient and 560px P2 viewer. No new dependencies or native-app behavior changes.

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM | `website/src/components/product-sections.css:298` | Tablet copy and screenshots used different edges | Stacked content shares a 560px maximum and common edges | Align to shared edges; keep the section readable after reflow |
| MEDIUM | `website/src/components/Hero.tsx:22`, `Features.tsx:9`, `NewFeatures.tsx:43`, `HeroDemo.tsx:257` | Repeated descriptions and longer instructions | Shorter action-led copy, explicit matching/fallback and simulation limits | One voice and vocabulary; explain what happens next |
| MEDIUM | `website/src/components/HeroDemo.tsx:186` | A fading picker temporarily retained focusable buttons | The interactive picker unmounts immediately | Remove obsolete controls from keyboard navigation |
| MEDIUM | `website/src/components/PublicTest.tsx:34` | The guide link targeted content inside a closed disclosure | The link opens and targets the native details element | Links must deliver their named destination |
| LOW | `website/src/index.css:128`, `hero-demo.css:102`, `product-sections.css:145` | Hover styling also applied on touch | Hover is restricted to capable pointers; selected/pressed cues remain static | Prevent sticky hover feedback |
| LOW | `website/src/index.css:134`, `hero-demo.css:109`, `Hero.tsx:8` | Inconsistent press/entrance feedback | 0.96 press scale over 150ms; staged hero entrance at 100ms intervals; reduced motion uses opacity | Match the UI motion language and user preference |

Verification: website build and ESLint; independent code review; browser checks at 1440, 1293, 1100, 901, 900, 768, 390 and 320 CSS pixels. No horizontal overflow, clipped result window, shifted tab frame or runtime error was observed. All three browser choices preserve the sample URL. Cancel/rapid reopen, focus return, arrows, number keys, Escape, screenshot arrows/Home/End and guide expansion passed. Desktop slogan/download bottom edges remain aligned. Screenshot windows retain their full 1600×1440 images and accurate v1.14.9 sample-data labels.

Replay completed idle → picker → destination → parked picker. Manual selection remained open beyond the full autoplay interval. Reduced motion stayed on the picker beyond that interval. A 646×550 CSS viewport at 2× density passed the 200% reflow equivalent.

Not verified: physical touch hardware, physical Intel/native handoff, screen readers, native browser zoom, localization/RTL, and the browser Animations panel at 10% speed. A CDP slow-motion attempt timed out, so it is not counted as verified. Transparent app screenshots intentionally skip a rectangular image outline. Native picker geometry remains the approved reference.

After rebasing onto current main, build and ESLint passed again. The browser confirmed all three download links target the exact v1.14.11 Universal DMG, no old repository links remain, and the repository-migration manual-upgrade guidance is retained. Native code, app scripts and release manifests have no differences from main.

Approve for the inspected landing-page scope; no known HIGH findings remain. Production publication requires a separate check of the deployed commit and page.
