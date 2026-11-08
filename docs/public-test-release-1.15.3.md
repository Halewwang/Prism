# Prism 1.15.3（构建 18）公开测试版

修复钉钉等来源应用的图标识别，并防止 Prism 及其测试副本被误列为浏览器选项。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 本版修复

- 历史记录、浏览器选择器与链接预览中的来源图标，现在可将保存的规范化来源标识匹配到已安装应用的真实标识，修复钉钉图标显示为文字占位的问题。精确图标查找仍优先执行；必要的应用目录查询与结果会缓存。
- 浏览器扫描和自定义浏览器添加入口排除 Prism 自身及其测试副本，避免验证用应用被当作浏览器候选项。
- 图标解析不会改写已有历史记录、来源置信度或分流规则；找不到来源应用时仍使用名称首字或问号占位。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 设置页或状态栏菜单检查更新，下载并验证后安装。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.3)下载 `Prism-1.15.3-universal-test.dmg`。退出 Prism，打开 DMG，将 Prism 拖入 Applications 文件夹，替换后重新打开。本机规则、设置和历史保存在应用包外。

本版延续 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 GitHub prerelease 渠道。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

发布资产包括 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验安装包；App 内更新另以固定 Ed25519 公钥验证清单签名、文件大小和 SHA-256。更新签名不等同于 Apple 公证。

## 验证与使用边界

- 96 项核心测试与 609 项原生单元测试完整通过；官网 lint 与生产构建通过。
- 使用实际保存的钉钉规范化标识验证完整图标链路，并通过历史页面快照核对来源大图标、小图标及 Aside 浏览器图标。
- 本机系统应用扫描返回 8 个浏览器候选，Prism 与其测试副本均被排除；未修改应用注册信息或删除测试应用。
- 5,000 条使用真实规范化来源标识的测试记录，首屏布局约 0.083 秒，应用目录仅扫描一次。该结果来自测试数据和当前机器，不代表所有设备的性能保证。
- 本机打包验证通过：应用与安装辅助程序版本均为 1.15.3（18），均包含 arm64 与 x86_64，且不依赖 Sparkle。ad hoc 签名、Hardened Runtime、禁止访问正式数据目录的 5 秒隔离启动、DMG 640 × 400 安装布局与完整性、SHA-256 及 Ed25519 更新清单签名校验通过。

本节记录本地源码、界面与安装包验收；公开资产回下载及更新发现由发布流程继续核验。

来源识别覆盖仍因应用而异。链接预览使用系统 WebKit 和独立登录会话，不导入外部浏览器登录状态；网站兼容性随 macOS 与页面而异，不支持的功能可交给完整浏览器继续。Chrome / Edge Profile 路由仍为实验功能。尚未完成 Intel 实机、全部受支持 macOS 版本及真实自动安装验收。

## English

**Correct source-app icons and browser choices.** Prism 1.15.3 (build 18) supports macOS 15+ with a Universal download for Apple Silicon and Intel.

- Source icons in History, the browser picker, and link preview can now match saved normalized identifiers to the installed application's actual identifier. This fixes DingTalk falling back to a text initial. Exact icon lookup remains the first choice; any required application inventory and lookup results are cached.
- Browser discovery and custom-browser registration exclude Prism and its test copies, keeping them out of browser choices.
- Icon resolution does not rewrite saved history, source confidence, or routing rules. Missing source apps still use a name initial or question mark.

Native v1.14.11 and later can check for updates from Settings or the menu bar menu. First-time users and native v1.14.10 or earlier should download the DMG, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings, and history remain outside the app bundle.

This remains an **ad hoc-signed, unnotarized public test**. If prompted by the updater, explicitly allow this verified unnotarized update; permission is off by default and applies only once. Release assets include the DMG, checksum file, and signed update manifest. Verify the download with `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature, package size, and hash. Use the versioned release page, website, or in-app updater rather than GitHub's `releases/latest`.

All 96 core tests and 609 native unit tests passed, along with website lint and the production build. The complete icon lookup path was checked using DingTalk's actual saved normalized identifier, with a History snapshot confirming its large and small source icons and the Aside browser icon. The local system scan returned eight browser choices with Prism and its test copies excluded, without changing application registrations or deleting test apps. A 5,000-entry test using the actual normalized source identifier laid out its first screen in about 0.083 seconds, with one application-inventory scan. This is a local test measurement, not a performance guarantee for every device.

Local packaging checks passed: the app and installer helper report 1.15.3 (18), contain arm64 and x86_64 binaries, and do not depend on Sparkle. Ad hoc signatures, Hardened Runtime, a five-second isolated launch with production data inaccessible, the DMG's 640 × 400 installer layout and integrity, SHA-256, and the Ed25519 update-manifest signature were verified. This section records local source, UI, and package acceptance; public asset downloads and update discovery are checked separately during publication.

Source-app coverage varies. Link preview uses system WebKit and a separate sign-in session; website compatibility varies by site and macOS version. Chrome / Edge profile routing remains experimental. This release has not completed physical Intel Mac, every supported macOS version, or live automatic-install validation.
