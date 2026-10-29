# Prism 1.15.0（构建 15）公开测试版

先预览，再决定用哪个浏览器打开。Prism 现在可以在浮窗中浏览和操作网页，再将当前页面交给选定的浏览器。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 新增链接预览

- 在「设置 → 链接处理 → 选择窗口模式」中选择「链接预览」。原有「浏览器选择器」继续保留，升级后保持原来的模式；自动规则仍按原设置运行，需要手动选择时才显示浮窗。
- 来源应用、网页地址、后退／前进／刷新、浏览器图标与 Esc 关闭按钮集中在顶部。网页可滚动、输入和继续浏览，选择浏览器时打开当前页面地址。
- 浏览器首项根据保留历史中的成功打开次数推荐。图标下的数字对应快捷键；窗口拉宽后显示更多浏览器，超出部分可横向滚动。
- 窄窗收为一个浏览器图标与上下按钮。开始切换时展开仅含图标和数字的候选列表，可用上下键选择、Enter 打开，或按数字 1–9／点击候选直接打开。网页编辑区域保留正常输入与方向键操作，Esc 关闭浮窗。
- 首次浮窗尺寸为 600 × 800（3:4），可自由拖动边缘调整尺寸，并记忆后续使用。网页支持 ⌘ +／−／0、地址框右键菜单及触控板捏合缩放。

## 稳定性与交互改进

- 修复网页获得焦点后的数字快捷键问题，并避免在输入文字或组合输入时误选浏览器。
- 改善窗口调整尺寸、顶部空间分配与窄窗候选列表。
- 修复全屏应用上状态栏菜单不可见的问题，菜单采用轻薄材质和紧凑排版。全屏应用中的菜单唤起、链接预览、传统选择器，以及跨桌面切换已在本机人工验证。
- 完善预览关闭时的 WebView、脚本消息、对话框与事件监听清理，并修复重试／恢复链接、设置保存和待处理队列边界。重复开关的隔离检查确认预览对象可释放；这不代表所有网站都具有相同内存占用。

## 使用边界

预览使用系统 WebKit，网站兼容性取决于 macOS 与页面本身。它有独立的登录状态，不会导入外部浏览器的登录会话，也不会将未提交的表单内容转交给浏览器。下载、不支持的链接或兼容性问题可选择在完整浏览器中继续。Intel 已完成通用构建与静态校验，尚未进行 Intel 实机验收。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 中检查更新，下载并验证后安装。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证的更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.0)下载 `Prism-1.15.0-universal-test.dmg`。退出 Prism，将安装窗口左侧的 Prism 拖入右侧 Applications 文件夹，替换后从「应用程序」打开。本机规则、设置和历史保存在应用包外。较早版本因仓库改名需手动安装一次，此后可使用 App 内更新。

本版仍为 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 **GitHub prerelease**。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

若 macOS 提示无法验证开发者，先确认来源和校验值，再通过「系统设置 → 隐私与安全性 → 仍要打开」手动允许。此方法不适用于恶意软件或应用损坏警告。

发布页包含 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载 DMG 与校验文件后，可执行 `shasum -a 256 -c SHA256SUMS.txt`。App 内更新另以固定 Ed25519 公钥验证更新清单，再校验安装包大小与 SHA-256；更新签名不等同于 Apple 公证。

## English

**Preview first. Choose a browser when you are ready.** Prism 1.15.0 (build 15) adds an interactive link-preview window for macOS 15+, with a Universal download for Apple Silicon and Intel.

- Choose **Link Preview** under Settings → Link Handling → Selection Window. The existing browser chooser remains available, and upgrading preserves your current mode. Automatic routing rules continue to apply.
- Browse, scroll, type, go back or forward, and reload before opening the current page in a chosen browser. Source app, navigation, browser icons and the Esc button share one compact toolbar.
- A recommended browser leads the icon strip. Wider windows reveal more browsers; narrow windows use a single icon and an icon-only candidate list. Use Up/Down and Enter to choose, or 1–9 and clicks to open directly. Editable web content keeps its normal typing and arrow-key behavior.
- Start at 600 × 800, resize freely, and reuse your saved window size. Zoom page content with Command +/−/0, the address-area context menu, or a trackpad pinch.
- Fixes include number shortcuts after webpage focus, preview resource cleanup, retry/recovery URLs, settings and pending-request handling, and status menus hidden behind fullscreen apps. Fullscreen and desktop-switching scenarios were manually checked on this Mac.

The preview uses system WebKit and a separate login session. It does not import browser cookies or transfer unsent form contents. Use a full browser for downloads, unsupported links or site compatibility issues. Repeated open/close checks confirmed preview objects were released; they do not guarantee identical memory use on every site. Intel builds were verified, but Intel hardware was not tested.

Native v1.14.11 and later can update in the app. First-time users and native v1.14.10 or earlier should download the DMG, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings and history remain outside the app bundle.

This is an **ad hoc-signed, unnotarized public test**. If the updater prompts, explicitly allow this verified unnotarized update; permission is off by default and applies only once. The release includes the DMG, checksum file and signed update manifest. Verify the download against `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature and package hash. Use the versioned release page, website or in-app updater rather than GitHub's `releases/latest`.
