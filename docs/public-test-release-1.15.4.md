# Prism 1.15.4（构建 19）公开测试版

全面加固稳定性、持久化、兼容性、双语本地化与交互体验。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 本版修复与改进

- **启动、稳定性与持久化加固**：
  - 修复首次安装与恢复态（`.onboarding` / `.recovery`）启动时不自动打开主窗口及隐藏菜单栏图标的问题。
  - 修复历史记录保存时将 `outcome_unknown` 与选择器原因码统一覆写为 `launch_failed` 的缺陷，同时保留原始敏感信息脱敏。
  - 为 `NSWorkspace` 浏览器启动增加 25 秒超时保护（超时转入可恢复的未知结果态，不再永久锁死路由队列）；正常退出时自动等待缓冲链接落盘；安全化应用内重启流程避免新旧双实例并发读写数据库。
  - 补齐自定义浏览器与设置仓库的 `context.rollback()`，历史查询引入 `#Predicate` 并将保留去重优化至 $O(N)$；收窄存储备份恢复条件（权限/磁盘满等临时故障不误清数据），为备份目录追加 UUID 并保留最近 5 份；同步捕获链接来源身份并后台预加载应用目录；修复 `AppleEventSenderReader` 非对齐内存读取。
- **链接预览、历史与设置完整度提升**：
  - 链接预览按 `Esc` 前放行中文 IME 组合输入与地址栏编辑；禁止无交互自动播放音视频，关闭时停止媒体并清理脚本，补全 `<a download>` 与 `Content-Disposition: attachment` 下载降级提示；为预览浏览器选项补齐右键快速创建规则菜单。
  - 设置页新增「管理浏览器」入口、「清除链接预览网页数据」与「规则备份与恢复（JSON 导入/导出）」，关闭自动检查更新时不再静默访问 GitHub；浏览器管理弹窗为全部系统浏览器展示显式 `...` 菜单。
  - 历史页新增「失败」筛选并支持重新打开已成功打开的链接；规则列表展示真实目标浏览器图标；菜单栏补齐「检查更新」与 `⌘1 / ⌘2 / ⌘3` 页面快捷键；关于页补充隐私与开源许可说明。
  - 修复多屏菜单栏/刘海区域选屏与宽窗最小高度缩放，选择器放行 `Control + 左键` 右键手势；URL 脱敏新增驼峰敏感参数识别（如 `accessToken`、`apiKey`、`sessionId`）。
- **双语本地化与更新流水线**：
  - 抽离全部 32 处硬编码中文更新/终止提示，同步中英双语资源至 587 键零差异，并修复状态栏菜单动态语言刷新与恢复横幅 VoiceOver 本地化。
  - 更新包下载改为分块流式传输，并将助手验签移出主线程；允许应用包内部安全相对符号链接，回滚前终止异常新进程，并在更新成功后清理临时安装包。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 设置页或状态栏菜单检查更新，下载并验证后安装。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.4)下载 `Prism-1.15.4-universal-test.dmg`。退出 Prism，打开 DMG，将 Prism 拖入 Applications 文件夹，替换后重新打开。本机规则、设置和历史保存在应用包外。

本版延续 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 GitHub prerelease 渠道。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

发布资产包括 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验安装包；App 内更新另以固定 Ed25519 公钥验证清单签名、文件大小和 SHA-256。更新签名不等同于 Apple 公证。

## 验证与使用边界

- 97 项核心测试与 615 项原生单元测试完整通过；双语 `Localizable.strings` 语法与键对齐（587 键）校验通过；官网 lint 与生产构建通过。
- 本机打包验证通过：应用与安装辅助程序版本均为 1.15.4（19），均包含 arm64 与 x86_64，且不依赖 Sparkle。ad hoc 签名、Hardened Runtime、禁止访问正式数据目录的 5 秒隔离启动、DMG 640 × 400 安装布局与完整性、SHA-256 及 Ed25519 更新清单签名校验通过。

来源识别覆盖仍因应用而异。链接预览使用系统 WebKit 和独立登录会话，不导入外部浏览器登录状态；网站兼容性随 macOS 与页面而异，不支持的功能可交给完整浏览器继续。Chrome / Edge Profile 路由仍为实验功能。尚未完成 Intel 实机、全部受支持 macOS 版本及真实自动安装验收。

## English

**Stability, localization, Link Preview, and usability hardening.** Prism 1.15.4 (build 19) supports macOS 15+ with a Universal download for Apple Silicon and Intel.

- **Startup, stability, and persistence:** Automatically presents the main window on launch when onboarding or recovery attention is needed (and keeps the menu bar item visible during recovery); preserves distinct history failure/cancellation codes while still redacting arbitrary raw strings; adds a 25-second browser launch timeout, graceful quit persistence flushing, and safe post-exit restart; adds `context.rollback()` on browser/settings save errors, `#Predicate` and $O(N)$ history retention cleanup, safer corrupt-store backup thresholds with UUID suffixes and 5-backup retention, synchronous source capture, background app-catalog icon preloading, and unaligned-safe AppleEvent PID decoding.
- **Link Preview, History, and Settings:** Escape respects CJK IME composition and editable text fields; disables unsolicited media autoplay, pauses media on close, and handles `<a download>` / `Content-Disposition: attachment`; adds right-click rule creation in Link Preview; adds **Manage Browsers**, **Clear Preview Data**, and **JSON Rule Import/Export** in Settings; exposes explicit `...` menus for system browsers, Failed history filtering, reopening opened links, real browser icons in Rules, menu shortcuts (`⌘1/2/3`), and Privacy / Open Source notices in About; improves multi-display positioning, Stage Manager window behavior, `Control + Click` in the classic picker, and camelCase sensitive URL parameter sanitization.
- **Localization and updater:** Localizes all previously hardcoded update/termination strings and synchronizes `en.lproj` and `zh-Hans.lproj` to 587 matching keys; switches update downloads to chunked streaming, moves helper codesign checks off `@MainActor`, allows contained internal bundle symlinks, terminates hung candidates before rollback, and cleans up temporary archives after successful installation.

Native v1.14.11 and later can check for updates from Settings or the menu bar menu. First-time users and native v1.14.10 or earlier should download `Prism-1.15.4-universal-test.dmg`, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings, and history remain outside the app bundle.

This remains an **ad hoc-signed, unnotarized public test**. Verify downloads with `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature, package size, and SHA-256. Source-app coverage varies, Chrome / Edge profile routing remains experimental, and physical Intel Mac, all macOS versions, and live auto-install validation have not been performed.
