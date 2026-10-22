# Link flow demo

Approved in conversation: replace the website hero screenshots with an interactive explanation of opening a link through Prism.

The scene shows a Mail message containing `https://example.com/design-review`. Clicking it reveals a browser picker with the native selector's proportions and familiar browser icons. Selecting a browser opens the same URL inside a simulated browser window. A short introduction plays once when visible; visitors can then try the link, choose a browser, cancel, or replay.

The example assumes Prism is the default browser, no routing rule matches, and the browser picker is the selected fallback. A visible disclosure identifies the scene as a simulation. No operating-system handoff, real navigation, app change, or deployment is involved.

Use existing React, Framer Motion, Lucide, font and color tokens. Support keyboard operation and touch targets, preserve focus after manual actions, and disable autoplay for reduced motion. Other website sections and release metadata stay in their existing state.

Acceptance: all three browsers produce matching names and the same URL; cancel and replay reset safely; manual input cancels autoplay; desktop/mobile layouts remain readable; build, lint and browser interaction assertions pass.

Visual review revisions: use neutral black, white and gray inside the scene, retaining original browser icons and the Prism mark. Replace the abstract artwork with a small document preview; omit that decorative card on the narrowest screens. Remove the redundant stage tagline. Offset the destination browser farther down and right, with enough stage height to keep the full window visible. On desktop, use the empty right side for a short guide that changes from clicking the Mail link to choosing a browser with number keys; hide it after the destination opens and on narrower layouts.

Further user review: retain the soft blue-gray/white/green stage gradient while keeping the windows neutral. Match desktop window proportions to the two annotated red-frame references at a 1293px viewport; use measured link/button geometry for the animated pointer. Manual input cancels the entire sequence; manual browser selection remains on its result.

Latest motion correction supersedes the earlier default-picker start, 4800ms parked state and immediate-unmount decisions. A normal first visit starts at idle, with no initial picker-to-idle flash. The introductory sequence and Replay advance to the picker at 1100ms, the destination at 2800ms, idle at 4800ms to click the Mail link again, and the parked picker at 5900ms. Reduced motion starts and remains on the static picker unless the visitor acts.

Keep the picker, destination window and both guide variants mounted. Their opacity transitions run for 200ms with linear easing; the destination and active guide delay entry by 200ms so the previous module can finish fading out. Hidden interactive modules use both `inert` and `aria-hidden` and cannot receive pointer input or keyboard focus. Mail geometry also transitions over 200ms with linear easing. Reduced motion uses opacity-only 150ms transitions without entry delays. Preserve the approved proportions and responsive layouts.

Use the same P1 stage gradient on `.workspace-mount` and `.picker-mount`: `linear-gradient(225deg, #dde3e8, #eff2f4 55%, #d8e2d3)`. Latest IAB validation sampled 1796 frames: the state sequence was correct, opacity values had intermediate frames and progressed monotonically without rebound, and all three computed background-image values matched. Arrow keys, number key 3, Escape and manual Chrome/Dia selection passed. Reduced motion stayed on the static picker for 6.4 seconds; 320/390px layouts had no horizontal overflow. Opening Safari manually during the closing idle step stayed opened beyond the pending 5900ms return, confirming that manual input cancels that timer. These are local validation results, not evidence of production deployment.

Place the 14px product description below the slogan. Align the download button bottom with the slogan bottom using shared grid rows, with compatibility details beside the description. Add a P2 screenshot viewer for Rules, History and Settings, using the existing complete v1.14.9 sample-data screenshot set. Its tabs support keyboard operation and the entire app window stays visible.

Latest P2 review: use one compact desktop composition with title, introduction, benefits and screenshot tabs in the left column, and a screenshot viewer capped at 560px in the right column. Align the two columns at the top and the tabs with the left-side copy. Stack copy, tabs and screenshot below 901px; retain the complete images, fixed image proportions, version caption and 44px tab targets.

Publication follow-up: polish page copy and feedback using better-ui, with shared tablet alignment and concise feature/fallback instructions. Keep hidden interactive modules inert and excluded from accessibility navigation while their opacity fades. Open the native installation disclosure when its guide link is selected. Integrate current main release metadata before pushing; use the existing Vercel production project and verify the published page separately.
