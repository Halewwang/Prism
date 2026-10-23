# Prism 1.14.13（构建 14）公开测试版

本版统一安装镜像、首次设置引导和更新窗口的视觉布局，支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 更新内容

- DMG 使用保存到镜像中的 640 × 400 Finder 安装布局：Prism 位于左侧，Applications 文件夹位于右侧，中间箭头提示拖放方向，并提供中英文安装说明。
- 首次设置引导采用简洁的左对齐排版，小标志、标题、正文和操作沿同一边线排列；引导与更新窗口的内容四周统一留白。未发现浏览器、默认浏览器设置及测试链接等状态继续提供对应的提示与恢复操作。
- 更新窗口在发现新版、下载、验证完成、安装和失败状态下保持相同尺寸，发布说明可滚动阅读，进度、错误与下一步操作集中呈现。下载验证、取消与重试、单次未公证更新授权及安装恢复机制保留。

## 更新与安装

**已安装 v1.14.11 或 v1.14.12：** 在 Prism 中检查更新，按提示下载并验证本版。若安装时提示未公证，可明确勾选“允许本次未公证公开测试更新”后安装并重启；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或从 v1.14.10 及更早原生版升级：** 从 [本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.14.13) 下载 `Prism-1.14.13-universal-test.dmg`，退出 Prism 后，将左侧 Prism 拖入右侧 Applications 文件夹，替换旧版后从“应用程序”打开。本机规则、设置和历史保存在应用包外。旧版只信任仓库改名前的下载路径，需要手动安装一次；此后可使用新仓库的 App 内更新。

本版在 GitHub 以 prerelease 发布。请使用本版发布页或 App 内更新，不要依赖 GitHub 的 `releases/latest` 入口。

## 签名与文件校验

本版使用 ad hoc 签名，尚未完成 Developer ID 签名与 Apple 公证。先尝试打开“应用程序”中的 Prism；若系统提示无法验证开发者，确认下载来源及校验值后，可在“系统设置 → 隐私与安全性 → 仍要打开”中手动允许。此步骤不适用于恶意软件或应用损坏警告。

发布页提供四个文件：`Prism-1.14.13-universal-test.dmg`、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载 DMG 与校验文件后，在下载目录执行 `shasum -a 256 -c SHA256SUMS.txt`。原生更新器沿用固定 Ed25519 公钥验证更新清单签名，并校验安装包 SHA-256；更新签名不等同于 Apple 公证。

## Public test

Prism 1.14.13 (build 14) brings a consistent layout to installation, first-run setup, and updates. The DMG saves a 640 × 400 Finder layout with Prism on the left, Applications on the right, an arrow between them, and Chinese and English installation instructions.

First-run setup uses a quiet, left-aligned layout with a small app mark and consistent alignment for headings, copy, and actions. Setup and update windows share uniform content margins. Guidance and recovery actions remain available for browser discovery, default-browser setup, and test links. The update window keeps one size across available, downloading, verified, installing, and failed states. Release notes remain scrollable, with status, errors, and actions grouped below. Verification, cancellation, retry, one-update permission, and installation recovery behavior are preserved.

Users on v1.14.11 or v1.14.12 can check for updates and install in the app. If prompted, explicitly allow this verified unnotarized public-test update before installing and restarting; the option is off by default and applies only to this update. Native v1.14.10 and earlier require one manual installation after the repository rename: quit Prism, open the DMG, drag Prism into Applications, replace the old app, and open it from Applications. Local rules, settings, and history remain outside the app bundle.

This macOS 15+ Universal public test is ad hoc-signed and unnotarized. The release provides the DMG, `SHA256SUMS.txt`, `update-manifest.json`, and `update-manifest.sig`. Verify the DMG against `SHA256SUMS.txt`; the app updater also verifies the signed update manifest and package checksum.
