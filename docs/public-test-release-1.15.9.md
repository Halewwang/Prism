# Prism 1.15.9（构建 24）公开测试版

打磨设置页窗口模式线框描边、精简中文历史上限文案，并适当放大状态栏图标尺寸。支持 macOS 15+，提供适用于 Apple Silicon 和 Intel 的 Universal 安装包。

## 本版更新

- 减轻「设置 → 链接处理 → 选择窗口模式」卡片边框粗细与选中描边重量（调整为 `1pt` 内描边，高对比度选中态为 `1.5pt`）。
- 精简中文「历史与隐私 → 最多保留」下拉文案，由「N 条链接」调整为「N 条」。
- 放大菜单栏状态图标有效图形尺寸（由 `12.65pt` 调整为 `15pt`，画布保持 `18pt`），与相邻状态栏图标视觉更一致。

## 更新与安装

- v1.14.11 及以后原生版可在 Prism 设置或菜单栏菜单中检查更新。若系统要求允许本次未公证公测更新，请确认下载来源后再选择。
- 首次安装或仍在使用 v1.14.10 及更早原生版时，退出 Prism，打开 DMG，将应用拖入「应用程序」，再重新打开。规则、设置和历史保存在应用包外。 [下载安装包](https://github.com/Halewwang/Prism/releases/download/v1.15.9/Prism-1.15.9-universal-test.dmg)
- 本版使用 ad hoc 签名，尚未通过 Apple 公证。在下载目录运行 `shasum -a 256 -c SHA256SUMS.txt` 可校验安装包。App 内更新也会校验清单签名、包大小与 SHA-256。 [下载校验文件](https://github.com/Halewwang/Prism/releases/download/v1.15.9/SHA256SUMS.txt)

已在 Apple Silicon Mac 上通过自动化测试与构建验证；Intel 实机与自动安装仍待验证。

## English

Visual polish for the Selection window cards, Simplified Chinese history-limit wording, and the macOS menu bar icon size. This Universal public test supports macOS 15 or later on Apple Silicon and Intel Macs.

- Lightened the **Settings → Link Handling → Selection window** card border to a crisp 1pt inset stroke with a softer selected tone (1.5pt under Increased Contrast).
- Shortened Simplified Chinese **History & Privacy → How many links to keep** option labels.
- Enlarged the menu bar template icon glyph from 12.65pt to 15pt inside its 18pt canvas so it aligns visually with neighboring macOS status bar icons.
- Native v1.14.11 and later can check for updates in Prism Settings or the menu bar menu. For a first installation or an upgrade from v1.14.10 or earlier, quit Prism, open the DMG, drag the app into Applications, and reopen it. Rules, settings, and history are stored outside the app bundle. [Download the installer](https://github.com/Halewwang/Prism/releases/download/v1.15.9/Prism-1.15.9-universal-test.dmg)
- This release is ad hoc-signed and is not Apple-notarized. Run `shasum -a 256 -c SHA256SUMS.txt` in the download folder to verify the installer. In-app updates also verify the manifest signature, package size, and SHA-256. [Download the checksum file](https://github.com/Halewwang/Prism/releases/download/v1.15.9/SHA256SUMS.txt)

Verified with automated unit tests and Universal build checks on Apple Silicon; physical Intel hardware and in-app auto-installation remain pending.
