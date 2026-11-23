# Prism 1.15.7（构建 22）公开测试版

网页预览窗可以跟随鼠标，或恢复上次关闭的位置。支持 macOS 15+，提供适用于 Apple Silicon 和 Intel 的 Universal 安装包。

## 本版更新

- 启用「链接预览」后，打开「设置 → 链接处理 → 预览窗位置」，选择「跟随鼠标」（默认）或「记住上次关闭的位置」。
- 选择记住位置后，关闭预览窗再打开，或重启 Prism 后打开，都会恢复上次关闭的位置。首次使用或原显示器不可用时，预览窗会在鼠标附近弹出。 [#31](https://github.com/Halewwang/Prism/issues/31)

## 更新与安装

- v1.14.11 及以后原生版可在 Prism 设置或菜单栏菜单中检查更新。若系统要求允许本次未公证公测更新，请确认下载来源后再选择。
- 首次安装或仍在使用 v1.14.10 及更早原生版时，退出 Prism，打开 DMG，将应用拖入「应用程序」，再重新打开。规则、设置和历史保存在应用包外。 [下载安装包](https://github.com/Halewwang/Prism/releases/download/v1.15.7/Prism-1.15.7-universal-test.dmg)
- 本版使用 ad hoc 签名，尚未通过 Apple 公证。在下载目录运行 `shasum -a 256 -c SHA256SUMS.txt` 可校验安装包。App 内更新也会校验清单签名、包大小与 SHA-256。 [下载校验文件](https://github.com/Halewwang/Prism/releases/download/v1.15.7/SHA256SUMS.txt)

已在连接两台显示器的 Apple Silicon Mac 上验证重启后的位置恢复，并通过自动化测试验证原显示器不可用时的回退。物理拔屏、Intel 实机和自动安装仍待验证。

## English

The link preview window can follow the mouse or reopen where you last closed it. This Universal public test supports macOS 15 or later on Apple Silicon and Intel Macs.

- With Link preview enabled, open **Settings → Link Handling → Preview window position**. Choose **Follow the mouse** (default) or **Remember last closed position**.
- The remembered position survives a Prism restart. The preview opens near the mouse when there is no saved position or the previous display is unavailable. [#31](https://github.com/Halewwang/Prism/issues/31)
- Native v1.14.11 and later can check for updates in Prism Settings or the menu bar menu. For a first installation or an upgrade from v1.14.10 or earlier, quit Prism, open the DMG, drag the app into Applications, and reopen it. Rules, settings, and history are stored outside the app bundle. [Download the installer](https://github.com/Halewwang/Prism/releases/download/v1.15.7/Prism-1.15.7-universal-test.dmg)
- This release is ad hoc-signed and is not Apple-notarized. Run `shasum -a 256 -c SHA256SUMS.txt` in the download folder to verify the installer. In-app updates also verify the manifest signature, package size, and SHA-256. [Download the checksum file](https://github.com/Halewwang/Prism/releases/download/v1.15.7/SHA256SUMS.txt)

Restart recovery was verified on an Apple Silicon Mac with two displays. Automated tests also verified fallback when the previous display is unavailable. Physical display disconnection, Intel hardware, and automatic installation testing are pending.
