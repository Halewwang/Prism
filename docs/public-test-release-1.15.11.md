# Prism 1.15.11（构建 26）公开测试版

全新重构引导页、应用内软件更新弹窗，并精简优化菜单栏菜单结构与命名。支持 macOS 15+，提供适用于 Apple Silicon 和 Intel 的 Universal 安装包。

## 本版更新

- **全新 5 步统一网格引导页**：采用真实应用 Dock 图标、顶部 5 点进度指示与实时中英切换；5 个步骤（欢迎、选择形态、分流规则、默认浏览器与系统就绪、完成）统一采用双栏网格布局，右侧提供可交互的「简洁栏 / 链接预览」形态演示与规则命中演示。
- **极简应用内软件更新弹窗**：重构为更紧凑清爽的 472pt 弹窗，支持结构化解析 Markdown 更新日志、新增「跳过此版本」操作，并在「偏好设置」中显示上次检查更新时间。
- **精简菜单栏菜单结构与命名**：整理为 4 组直观扁平菜单（暂停/恢复自动分流与打开剪贴板链接、工作区导航与快捷键、偏好设置与检查更新、退出），统一 SF Symbols 图标、快捷键对齐与暂停状态徽标，移除多余二级菜单。

## 更新与安装

- v1.14.11 及以后原生版可在 Prism 偏好设置或菜单栏菜单中检查更新。若系统要求允许本次未公证公测更新，请确认下载来源后再选择。
- 首次安装或仍在使用 v1.14.10 及更早原生版时，退出 Prism，打开 DMG，将应用拖入「应用程序」，再重新打开。规则、设置和历史保存在应用包外。 [下载安装包](https://github.com/Halewwang/Prism/releases/download/v1.15.11/Prism-1.15.11-universal-test.dmg)
- 本版使用 ad hoc 签名，尚未通过 Apple 公证。在下载目录运行 `shasum -a 256 -c SHA256SUMS.txt` 可校验安装包。App 内更新也会校验清单签名、包大小与 SHA-256。 [下载校验文件](https://github.com/Halewwang/Prism/releases/download/v1.15.11/SHA256SUMS.txt)

已在 Apple Silicon Mac 上通过自动化测试与构建验证；Intel 实机与自动安装仍待验证。

## English

Redesigns the onboarding flow and in-app software update modal, and streamlines the menu bar menu structure and naming. This Universal public test supports macOS 15 or later on Apple Silicon and Intel Macs.

- **Unified 5-step onboarding**: Uses the real macOS Dock app icon, persistent 5-dot progress rail, and instant English / Simplified Chinese toggle across a consistent two-column layout with interactive Compact Bar / Link Preview and routing-rule previews.
- **Minimalist software update modal**: Refactored into a compact 472pt sheet with structured Markdown release notes, a new **Skip this version** action, and a last-checked timestamp in Settings.
- **Streamlined menu bar menu**: Reorganized into a flat 4-group layout (auto-routing toggle & Open Clipboard Link, workspace navigation with shortcuts, Settings & Check for Updates, Quit) with aligned SF Symbols and Paused status badge.
- Native v1.14.11 and later can check for updates in Prism Settings or the menu bar menu. For a first installation or an upgrade from v1.14.10 or earlier, quit Prism, open the DMG, drag the app into Applications, and reopen it. Rules, settings, and history are stored outside the app bundle. [Download the installer](https://github.com/Halewwang/Prism/releases/download/v1.15.11/Prism-1.15.11-universal-test.dmg)
- This release is ad hoc-signed and is not Apple-notarized. Run `shasum -a 256 -c SHA256SUMS.txt` in the download folder to verify the installer. In-app updates also verify the manifest signature, package size, and SHA-256. [Download the checksum file](https://github.com/Halewwang/Prism/releases/download/v1.15.11/SHA256SUMS.txt)

Verified with automated unit tests and Universal build checks on Apple Silicon; physical Intel hardware and in-app auto-installation remain pending.
