# Link Flow Demo Implementation Plan

> **For agentic workers:** Use the approved design and the file ownership below. User requested direct construction and local preview.

**Goal:** Demonstrate link click, floating browser selection, and arrival in the selected browser.

**Architecture:** One `HeroDemo` component owns transient scene state and its timers. The existing `Hero` renders it in place of its screenshot composition. Local browser icons and a dedicated stylesheet keep the change contained.

**Tech Stack:** React, TypeScript, Framer Motion, Lucide, plain CSS, Vite; no new dependencies.

---

- [x] Inspect the native selector, existing hero callers/styles, and website scripts. Confirm the baseline browser assertion fails because no interactive demo exists.
- [x] Worker: create `website/src/components/HeroDemo.tsx`, `hero-demo.css`, and local browser icons. Handle all manual states, one-time autoplay, keyboard/focus, reduced motion and timer cleanup.
- [x] Root: replace the screenshot composition in `Hero.tsx` with `<HeroDemo />`; remove its unused CSS from `index.css`.
- [x] Root: run `npm run build` and `npm run lint` in `website/`; address failures.
- [x] Root: verify the localhost page using Ego Browser. Assert the link exposes the picker, each browser opens the same URL, cancel/replay work, manual input cancels autoplay, keyboard works, reduced motion suppresses autoplay, and 320/390/desktop widths have no clipping. Inspect rendered light/dark scenes and relevant console errors.
- [x] Root: open the local preview in Codex and report verification boundaries. Keep production unchanged.

Earlier local verification (historical; timing, parked state and module mounting are superseded by the latest correction below): verified at 320, 390, 768 and 1440 CSS pixels. Manual actions canceled the then-current 3500ms autoplay sequence; reduced motion remained idle beyond that interval. Manual browser selection focused the visible result window; autoplay preserved the original focus. Desktop and mobile pointer geometry landed inside the example link. Real local Safari, Chrome and Dia icons were bundled as PNG assets. No relevant browser runtime errors were observed. Vite build and full website ESLint passed; the existing Browserslist dataset age notice remained. No production deployment, native handoff or physical-phone test was performed.

Intermediate user-review follow-up (historical; superseded by the latest correction below): the sequence returned to the picker at 4800ms, after a two-second destination hold. Normal autoplay and Replay were exercised through link, picker, destination and parked picker; manual selection stayed open beyond the full return interval. Reduced motion stayed on its static default picker. The DOM-measured pointer hit both the link and Safari card.

The annotated red-frame ratios were checked at 1293px (1165×600 stage). Further checks covered 320, 390, 601, 700, 768, 900, 1100, 1101, 1200, 1293, 1340 and 1440px as applicable: no horizontal overflow, clipped picker/result, guide collision or title/document collision. Removed tagline has no markup or CSS references. Slogan/download bottom edges and description/metadata top edges had 0px difference at the tested desktop widths. The P2 viewer is centered and capped at 880px, changes among the three v1.14.9 images without changing frame height, and supports arrows, Home and End. Its 320/390px controls retained 44px height. Full build and ESLint passed after the final edits; no production deployment was made.

Latest P2 review supersedes the 880px composition: desktop now places copy, benefits and tabs in the left column and a maximum-560px screenshot viewer in the right column, with top edges aligned. At 1293px, the section decreased from 1316px to 630px high. Checked 1440, 1293, 1100, 901, 900, 768, 390 and 320px: no horizontal overflow, all tab targets at least 44px high, tabs below and aligned with the copy, and the screenshot contained inside its frame. All three 1600×1440 images switch within the same frame height; arrow wrapping, Home/End and a single active tab stop passed. Build and ESLint passed, and no browser runtime errors were observed. No physical-device or screen-reader test, commit or deployment was performed.

Latest motion and background correction supersedes all earlier demo timing, initial-state and immediate-picker-unmount records above:

- [x] Start a normal first visit at idle, avoiding an initial picker-to-idle flash. Autoplay and Replay advance at 1100ms to picker, 2800ms to opened, 4800ms to idle for another Mail link click, and 5900ms to the parked picker. Reduced motion retains a static initial picker. Manual input still clears the complete timer sequence; manual selection stays on its result.
- [x] Keep the picker, destination and both guide variants in the DOM. Use 200ms linear opacity transitions, with a 200ms destination/guide entry delay to let the previous module finish exiting. Hidden interactive modules are `inert`, `aria-hidden` and unavailable to pointer or keyboard interaction. Mail geometry uses 200ms linear transitions; reduced motion keeps only 150ms opacity fades with no entry delay.
- [x] Match `.workspace-mount` and `.picker-mount` to the P1 gradient. The three computed background-image values are identical: `linear-gradient(225deg, #dde3e8, #eff2f4 55%, #d8e2d3)`.
- [x] Validate the local page in IAB with 1796 sampled frames. The sequence matched the timeline; opacity was monotonic, included intermediate frames and had no rebound. Arrow keys, number key 3, Escape and manual Chrome/Dia selection passed.
- [x] Confirm reduced motion remains on the static picker for 6.4 seconds and 320/390px layouts have no horizontal overflow. During the closing idle step, open Safari manually and confirm it stays opened beyond the canceled 5900ms parked-picker timer.

This latest evidence verifies local motion and interaction behavior. It does not establish a production deployment or native browser handoff.
