# Prism 1.14.12（构建 13）公开测试版

本版调整原生窗口入场动效、历史结果筛选和菜单样式，支持 macOS 15+，提供 Apple Silicon 与 Intel 的 Universal 安装包。

## 更新内容

- 浏览器选择器与主界面内容在出现时，以 250 ms 从 0.8 倍缩放到原尺寸并淡入，无回弹。主界面保留原生标题栏，标题栏仅随窗口淡入。
- 动效只在窗口从隐藏变为显示时播放；窗口已显示时，连续请求或刷新不会重播。开启 macOS“减弱动态效果”后，改为 80 ms 淡入，不缩放。
- 历史页面直接提供“全部／已打开／已取消”三个筛选按钮，移除“全部”下的额外“失败／处理中”菜单。
- 下拉选择器获得键盘焦点时显示 1 pt 强调色边框。菜单高亮项在 macOS 26+ 使用 10 pt 连续圆角与 12 pt 等距内缩，较早版本保留 6 pt 圆角与内缩；方向键、Return、空格与 Escape 的操作保持可用。

## 更新与安装

**已安装 v1.14.11：** 在 Prism 中检查更新，按提示下载并验证本版。若安装时提示未公证，可明确勾选“允许本次未公证公开测试更新”后安装并重启；该选项默认关闭，仅对本次已验证更新生效。

**首次安装，或从 v1.14.10 及更早原生版升级：** 从 [本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.14.12) 下载 `Prism-1.14.12-universal-test.dmg`，退出 Prism 后，将新版拖入“应用程序”替换旧版。本机规则、设置和历史保存在应用包外。旧版只信任仓库改名前的下载路径，需要手动安装一次；此后可使用新仓库的 App 内更新。

本版在 GitHub 以 prerelease 发布。请使用本版发布页或 App 内更新，不要依赖 GitHub 的 `releases/latest` 入口。

## 签名与文件校验

本版使用 ad hoc 签名，尚未完成 Developer ID 签名与 Apple 公证。先尝试打开“应用程序”中的 Prism；若系统提示无法验证开发者，确认下载来源及校验值后，可在“系统设置 → 隐私与安全性 → 仍要打开”中手动允许。此步骤不适用于恶意软件或应用损坏警告。

发布页提供四个文件：`Prism-1.14.12-universal-test.dmg`、`SHA256SUMS.txt`、`update-manifest.json` 和 `update-manifest.sig`。下载 DMG 与校验文件后，在下载目录执行 `shasum -a 256 -c SHA256SUMS.txt`。原生更新器沿用固定 Ed25519 公钥验证更新清单签名，并校验安装包 SHA-256；更新签名不等同于 Apple 公证。

## 验证范围

- PrismCore 87 项、原生 496 项测试通过；另有 1 项桌面激活断言在原基线同样失败，未计入通过项。
- 7 项界面回归中 5 项通过；2 项键盘焦点测试在原基线与本版均失败，并出现外部窗口中断，未计为通过。已人工复查浅色／深色菜单圆角、选中状态及点击选择。
- Universal 双架构构建、ad hoc 签名、DMG 完整性、Ed25519 清单签名和隔离启动检查通过；未在 Intel 或较早 macOS 实机验收。

## Public test

Prism 1.14.12 (build 13) adds a 250 ms scale-and-fade entrance for the picker and main-window content, with no bounce. The native main-window title bar fades without scaling. Motion runs only when a hidden window becomes visible; Reduce Motion uses an 80 ms fade without scaling.

History now offers direct All / Opened / Cancelled filters. Dropdowns use a 1 pt accent border for keyboard focus and a 10 pt continuous highlighted-row radius with a 12 pt inset on macOS 26+ (6 pt radius and inset on earlier versions). Existing keyboard controls remain available.

Users on v1.14.11 can check for updates and install in the app. If prompted, explicitly allow this verified unnotarized public-test update before installing and restarting; the option is off by default and applies only to this update. Native v1.14.10 and earlier require one manual installation after the repository rename. This macOS 15+ Universal public test is ad hoc-signed and unnotarized. Verify the DMG against `SHA256SUMS.txt`; the app updater also verifies the signed update manifest and package checksum.

Validation: 87 core and 496 native tests passed. One desktop-activation assertion and two keyboard-focus UI tests also fail on the unchanged baseline in this desktop environment and are not counted as passing; five other UI regressions passed. Light/dark picker geometry and pointer selection were checked manually. Universal packaging, signing, integrity and isolated launch checks passed; Intel and earlier macOS hardware were not tested.
