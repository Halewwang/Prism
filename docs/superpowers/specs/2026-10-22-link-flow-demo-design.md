# Link flow demo

Approved in conversation: replace the website hero screenshots with an interactive explanation of opening a link through Prism.

The scene shows a Mail message containing `https://example.com/design-review`. Clicking it reveals a browser picker with the native selector's proportions and familiar browser icons. Selecting a browser opens the same URL inside a simulated browser window. A short introduction plays once when visible; visitors can then try the link, choose a browser, cancel, or replay.

The example assumes Prism is the default browser, no routing rule matches, and the browser picker is the selected fallback. A visible disclosure identifies the scene as a simulation. No operating-system handoff, real navigation, app change, or deployment is involved.

Use existing React, Framer Motion, Lucide, font and color tokens. Support keyboard operation and touch targets, preserve focus after manual actions, and disable autoplay for reduced motion. Other website sections and release metadata stay in their existing state.

Acceptance: all three browsers produce matching names and the same URL; cancel and replay reset safely; manual input cancels autoplay; desktop/mobile layouts remain readable; build, lint and browser interaction assertions pass.

Visual review revisions: use neutral black, white and gray inside the scene, retaining original browser icons and the Prism mark. Replace the abstract artwork with a small document preview; omit that decorative card on the narrowest screens. Remove the redundant stage tagline. Offset the destination browser farther down and right, with enough stage height to keep the full window visible. On desktop, use the empty right side for a short guide that changes from clicking the Mail link to choosing a browser with number keys; hide it after the destination opens and on narrower layouts.

Further user review: retain the soft blue-gray/white/green stage gradient while keeping the windows neutral. Match desktop window proportions to the two annotated red-frame references at a 1293px viewport; use measured link/button geometry for the animated pointer. Start and park on the browser picker. The introductory sequence and Replay still show link click, picker and destination, then return to the picker after a two-second destination hold. Manual input cancels the entire sequence; manual browser selection remains on its result. Reduced motion keeps the static picker.

Place the 14px product description below the slogan. Align the download button bottom with the slogan bottom using shared grid rows, with compatibility details beside the description. Add a P2 screenshot viewer for Rules, History and Settings, using the existing complete v1.14.9 sample-data screenshot set. Its tabs support keyboard operation and the entire app window stays visible.

Latest P2 review: use one compact desktop composition with title, introduction, benefits and screenshot tabs in the left column, and a screenshot viewer capped at 560px in the right column. Align the two columns at the top and the tabs with the left-side copy. Stack copy, tabs and screenshot below 901px; retain the complete images, fixed image proportions, version caption and 44px tab targets.

Publication follow-up: polish page copy and feedback using better-ui, with shared tablet alignment and concise feature/fallback instructions. Keep the interactive picker immediately removable for keyboard safety. Open the native installation disclosure when its guide link is selected. Integrate current main release metadata before pushing; use the existing Vercel production project and verify the published page separately.
