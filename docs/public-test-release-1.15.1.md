# Prism 1.15.1（构建 16）公开测试版

在弹窗中直接复制或修改链接，再选择浏览器继续。支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 本版更新

- 浏览器选择器和链接预览的地址栏支持选中、复制、粘贴与编辑。
- 选择浏览器时使用修改后的地址，无需先按 Return。预览地址栏内按 Return 会在浮窗中加载新页面。
- 打开失败后的恢复重试保留地址修改；空白或无效的 HTTP / HTTPS 地址会阻止导航和浏览器交接，并显示输入提示。
- 编辑地址时保留正常的数字与方向键输入，页面导航仅在地址未编辑时同步地址栏。

## 更新与安装

**v1.14.11 及之后的原生版：** 在 Prism 内检查更新，下载并验证后安装。若提示未公证，可明确允许「本次未公证公开测试更新」；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或 v1.14.10 及更早原生版：** 从[本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.15.1)下载 `Prism-1.15.1-universal-test.dmg`。退出 Prism，打开 DMG，将 Prism 拖入 Applications 文件夹，替换后重新打开。本机规则、设置和历史保存在应用包外。

本版延续 ad hoc 签名、未完成 Developer ID 签名与 Apple 公证的 GitHub prerelease 渠道。请使用本版发布页、官网或 App 内更新，不要依赖 GitHub 的 `releases/latest`。

发布资产包括 DMG、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验安装包；App 内更新另以固定 Ed25519 公钥验证清单签名、文件大小和 SHA-256。更新签名不等同于 Apple 公证。

## 验证与使用边界

本版功能改动已通过 595 项原生单元测试，UI 测试代码编译通过。实机复制与键盘交互尚未完成验证。

链接预览使用系统 WebKit 和独立登录会话，不导入外部浏览器登录状态，也不转交未提交的表单。网站兼容性随 macOS 与页面而异；不支持的功能可交给完整浏览器继续。Intel 二进制包含在 Universal 包中，未进行 Intel 实机验收。

## English

**Copy or edit a link before choosing its browser.** Prism 1.15.1 (build 16) supports macOS 15+ with a Universal download for Apple Silicon and Intel.

- Select, copy, paste, and edit the address in the browser picker and link preview.
- Choosing a browser opens the edited address without requiring Return first. Return in the preview address field loads the new page inside the preview.
- Recovery retries preserve edits. Invalid HTTP or HTTPS addresses are rejected before navigation or browser handoff. Address editing keeps normal number and arrow-key input.

Native v1.14.11 and later can update in the app. First-time users and native v1.14.10 or earlier should download the DMG, quit Prism, drag it into Applications, replace the old app, and reopen. Local rules, settings, and history remain outside the app bundle.

This remains an **ad hoc-signed, unnotarized public test**. If prompted by the updater, explicitly allow this verified unnotarized update; permission is off by default and applies only once. The release assets include the DMG, checksum file, and signed update manifest. Verify the download with `SHA256SUMS.txt`; the updater also checks its pinned Ed25519 signature, package size, and hash. Use the versioned release page, website, or in-app updater rather than GitHub's `releases/latest`.

The feature changes passed 595 native unit tests, and the UI test code compiled. Copying and keyboard interaction have not yet been verified on the live interface. Link preview uses system WebKit and a separate sign-in session; website compatibility varies. Intel hardware has not been tested.
