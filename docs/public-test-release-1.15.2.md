# Prism 1.15.2（构建 17）公开测试版

更新图标比例，在状态栏菜单直接检查更新，并改善规则、历史、设置页面的切换。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 本版更新

- 同步 Pencil 中调整后的图标比例与尺寸：App / Dock 符号约占画布 55%，菜单栏、工具栏、品牌与标题栏图标使用各自的留白和小尺寸笔画补偿。
- 状态栏菜单新增“检查更新”，复用 App 内现有更新流程；不可检查时禁用该选项。
- 历史列表按需绘制可见行，每次进入历史页只读取一次规则，避免逐条记录重复读取；已安装应用扫描移至后台，减少页面切换时的主线程工作。
- 历史记录显示来源应用和目标浏览器的真实图标，缓存图标与查询结果。浏览器 Profile 使用对应浏览器图标；找不到应用时保留首字母占位。
- 保留现有历史保存条数选项：默认 100 条，可在设置中选择其他数量。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 内检查更新，下载并验证后安装。本版可从设置页或状态栏菜单发起检查。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.2)下载 `Prism-1.15.2-universal-test.dmg`。退出 Prism，打开 DMG，将 Prism 拖入 Applications 文件夹，替换后重新打开。本机规则、设置和历史保存在应用包外。

本版延续 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 GitHub prerelease 渠道。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

发布资产包含 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验安装包；App 内更新另以固定 Ed25519 公钥验证清单签名、文件大小和 SHA-256。更新签名不等同于 Apple 公证。

## 验证与使用边界

- 96 项核心测试与 603 项原生单元测试通过。
- 5,000 条历史记录的本机布局测试中，首次布局从 11.712 秒降至 0.057 秒；布局只读取一次规则、创建 9 行。该结果来自测试数据和当前机器，不代表所有数据量与设备的性能保证。
- 隔离 UI 验证覆盖规则、历史、设置三个页面的切换与设置页滚动；原生钉钉作为来源应用的历史图标已通过界面快照核对。实际来源识别覆盖仍因应用而异。
- 预览相关测试在一次完整测试运行中出现临时失败；未修改该测试，随后隔离运行和完整重跑均通过。本版未将其根因标记为已修复。
- 本机打包验证通过：应用与安装辅助程序版本均为 1.15.2（17），均包含 arm64 与 x86_64；ad hoc 签名、Hardened Runtime、5 秒隔离启动、DMG 640 × 400 安装布局与完整性、SHA-256 及 Ed25519 更新清单签名校验通过。

链接预览使用系统 WebKit 和独立登录会话，不导入外部浏览器登录状态，也不转交未提交的表单。网站兼容性随 macOS 与页面而异；不支持的功能可交给完整浏览器继续。Chrome / Edge Profile 路由仍为实验功能。Intel 二进制包含在 Universal 包中，未进行 Intel 实机验收；尚未覆盖所有受支持的 macOS 版本。

## English

**Updated icons and smoother settings navigation.** Prism 1.15.2 (build 17) supports macOS 15+ with a Universal download for Apple Silicon and Intel.

- Updated icon proportions and sizes from Pencil. The App / Dock mark occupies about 55% of the canvas; other surfaces retain their own spacing and small-size stroke adjustments.
- Check for Updates is available in the menu bar menu and uses the existing updater. It is disabled when checks are unavailable.
- History renders visible rows as needed and reads rules once each time History opens instead of once per saved link. Installed-app discovery runs in the background.
- History shows cached source-app and destination-browser icons. Browser profile targets use their parent browser icon; unavailable app icons fall back to initials.
- History retention settings keep the existing choices, with a default of 100 links and other options in Settings.

Native v1.14.11 and later can update in the app. This version offers checks from Settings or the menu bar menu. First-time users and native v1.14.10 or earlier should download the DMG, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings, and history remain outside the app bundle.

This remains an **ad hoc-signed, unnotarized public test**. If prompted by the updater, explicitly allow this verified unnotarized update; permission is off by default and applies only once. Release assets include the DMG, checksum file, and signed update manifest. Verify the download with `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature, package size, and hash. Use the versioned release page, website, or in-app updater rather than GitHub's `releases/latest`.

The source changes passed 96 core tests and 603 native unit tests. In a local 5,000-entry history layout test, first layout improved from 11.712 seconds to 0.057 seconds, with one rule read and nine rows created. This is a measurement on test data and the current machine, not a performance guarantee for every device or dataset. Isolated UI checks covered switching between Rules, History, and Settings and scrolling Settings; a native DingTalk history icon was checked in a UI snapshot. One preview-related test failed transiently in a full run, then passed unchanged both in isolation and in a full rerun; its root cause is not claimed fixed. A fresh full native test run with the release version also passed.

Local packaging checks passed: the app and installer helper report 1.15.2 (17) and contain arm64 and x86_64 binaries. Ad hoc signatures, Hardened Runtime, a five-second isolated launch, the DMG's 640 × 400 installer layout and integrity, SHA-256, and the Ed25519 update-manifest signature were verified.

Link preview uses system WebKit and a separate sign-in session; website compatibility varies. Chrome / Edge profile routing remains experimental. This release has not been tested on a physical Intel Mac or across every supported macOS version.
