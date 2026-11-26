# Prism 1.15.8（构建 23）公开测试版

设置中的「选择窗口模式」升级为可视化线框选项，直观对比浏览器选择器与链接预览两种窗口形式。支持 macOS 15+，提供适用于 Apple Silicon 和 Intel 的 Universal 安装包。

## 本版更新

- 将「设置 → 链接处理 → 选择窗口模式」由下拉菜单替换为双栏可视化线框卡片，直观展示「浏览器选择器」与「链接预览」的窗口结构差异。
- 卡片采用原生 SwiftUI 矢量绘制，自动适配浅色/深色外观与高对比度模式，并支持鼠标悬停、键盘聚焦及左右方向键切换。
- 选择「链接预览」后，下方仍保留「预览窗位置」联动设置。

## 更新与安装

- v1.14.11 及以后原生版可在 Prism 设置或菜单栏菜单中检查更新。若系统要求允许本次未公证公测更新，请确认下载来源后再选择。
- 首次安装或仍在使用 v1.14.10 及更早原生版时，退出 Prism，打开 DMG，将应用拖入「应用程序」，再重新打开。规则、设置和历史保存在应用包外。 [下载安装包](https://github.com/Halewwang/Prism/releases/download/v1.15.8/Prism-1.15.8-universal-test.dmg)
- 本版使用 ad hoc 签名，尚未通过 Apple 公证。在下载目录运行 `shasum -a 256 -c SHA256SUMS.txt` 可校验安装包。App 内更新也会校验清单签名、包大小与 SHA-256。 [下载校验文件](https://github.com/Halewwang/Prism/releases/download/v1.15.8/SHA256SUMS.txt)

已在 Apple Silicon Mac 上通过自动化测试与构建验证；Intel 实机与自动安装仍待验证。

## English

The **Selection window** setting now uses visual wireframe cards so you can compare Browser selector and Link preview at a glance. This Universal public test supports macOS 15 or later on Apple Silicon and Intel Macs.

- Replaced the **Settings → Link Handling → Selection window** dropdown with side-by-side visual wireframe cards for **Browser selector** and **Link preview**.
- Rendered with native SwiftUI vector graphics that adapt to light/dark mode and increased contrast, with hover states, keyboard focus, and left/right arrow switching.
- Keeping **Preview window position** revealed right underneath whenever **Link preview** is selected.
- Native v1.14.11 and later can check for updates in Prism Settings or the menu bar menu. For a first installation or an upgrade from v1.14.10 or earlier, quit Prism, open the DMG, drag the app into Applications, and reopen it. Rules, settings, and history are stored outside the app bundle. [Download the installer](https://github.com/Halewwang/Prism/releases/download/v1.15.8/Prism-1.15.8-universal-test.dmg)
- This release is ad hoc-signed and is not Apple-notarized. Run `shasum -a 256 -c SHA256SUMS.txt` in the download folder to verify the installer. In-app updates also verify the manifest signature, package size, and SHA-256. [Download the checksum file](https://github.com/Halewwang/Prism/releases/download/v1.15.8/SHA256SUMS.txt)

Verified with automated unit tests and Universal build checks on Apple Silicon; physical Intel hardware and in-app auto-installation remain pending.
