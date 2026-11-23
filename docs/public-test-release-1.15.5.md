# Prism 1.15.5（构建 20）公开测试版

新增浏览器备用名称、勾选式浏览器显隐管理与「隐藏程序坞图标」设置。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 本版更新

- **浏览器备用名称（全局生效）**：
  - 支持在「管理浏览器」中为每个浏览器 App 及 Chromium Profile 设置独立备用名称（用于区分用途或账号 ID），支持一键恢复默认名称，无需数据库迁移。
  - 备用名称全局同步至紧凑浏览器选择器、链接预览（顶部工具栏悬停提示及窄窗展开候选列表）、路由规则、设置首选浏览器及新生成的历史记录；管理页与悬停 Tooltip 均保留原始 App 名称参考。
- **浏览器管理改为勾选控制显隐**：
  - 将「在选择器中显示」从 `...` 菜单提升至每行左侧直接勾选，直观区分已显示与已隐藏状态，并在列表顶部展示「勾选即显示在选择器中」与显示计数。
  - 全部取消勾选时给出明确提示；取消勾选仅隐藏选择器入口，不影响已有自动路由规则与兜底设置。
- **隐藏程序坞图标设置（Hide Dock Icon）**：
  - 在「设置 → 通用」新增「隐藏程序坞图标」开关：开启后，关闭全部常规窗口时自动隐藏程序坞图标，重新打开主窗口、关于或更新窗口时恢复显示；弹出链接选择器或链接预览浮窗时不会反复闪现程序坞图标。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 设置页或状态栏菜单检查更新，下载并验证后安装。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.5)下载 `Prism-1.15.5-universal-test.dmg`。退出 Prism，打开 DMG，将 Prism 拖入 Applications 文件夹，替换后重新打开。本机规则、设置和历史保存在应用包外。

本版延续 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 GitHub prerelease 渠道。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

发布资产包括 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验安装包；App 内更新另以固定 Ed25519 公钥验证清单签名、文件大小和 SHA-256。更新签名不等同于 Apple 公证。

## 验证与使用边界

- 99 项核心测试与完整原生单元测试通过；双语 `Localizable.strings` 语法校验通过；官网 lint 与生产构建通过。
- 本机打包验证通过：应用与安装辅助程序版本均为 1.15.5（20），均包含 arm64 与 x86_64，且不依赖 Sparkle。ad hoc 签名、Hardened Runtime、隔离启动检查、DMG 安装布局与完整性、SHA-256 及 Ed25519 更新清单签名校验通过。

来源识别覆盖仍因应用而异。链接预览使用系统 WebKit 和独立登录会话，不导入外部浏览器登录状态；网站兼容性随 macOS 与页面而异，不支持的功能可交给完整浏览器继续。Chrome / Edge Profile 路由仍为实验功能。尚未完成 Intel 实机、全部受支持 macOS 版本及真实自动安装验收。

## English

**Browser alternate names, checkbox browser visibility management, and Hide Dock Icon.** Prism 1.15.5 (build 20) supports macOS 15+ with a Universal download for Apple Silicon and Intel.

- **Global browser alternate names:** Set custom names for browsers and Chromium profiles in **Manage Browsers** to identify their purpose or account ID, with one-click reset to default. Alternate names apply across the browser selector, narrow Link Preview candidate list, routing rules, preferred browser settings, and new history entries, while preserving original app names in management rows and tooltips.
- **Checkbox visibility in Manage Browsers:** Moved selector visibility out of the `...` menu into direct per-row checkboxes with a visible counter and clear hidden state indicators. Unchecked browsers remain available for automatic routing rules and fallback settings.
- **Hide Dock Icon setting:** Added **Hide Dock Icon** under **Settings → General** to hide Prism from the Dock whenever all regular windows are closed, while restoring it when opening a standard window and avoiding Dock flashes during selector or Link Preview popups.

Native v1.14.11 and later can check for updates from Settings or the menu bar menu. First-time users and native v1.14.10 or earlier should download `Prism-1.15.5-universal-test.dmg`, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings, and history remain outside the app bundle.

This remains an **ad hoc-signed, unnotarized public test**. Verify downloads with `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature, package size, and SHA-256. Source-app coverage varies, Chrome / Edge profile routing remains experimental, and physical Intel Mac, all macOS versions, and live auto-install validation have not been performed.
