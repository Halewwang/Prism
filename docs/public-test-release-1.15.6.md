# Prism 1.15.6（构建 21）公开测试版

Prism 现可把本地 `.html` 或 `.htm` 文件交给你选择的浏览器。支持 macOS 15+，提供适用于 Apple Silicon 和 Intel 的 Universal 安装包。

## 本版更新

- 在 Finder 中右键点击本地 HTML 文件，选择「打开方式 → Prism」。如果 Prism 已是这类文件的默认打开 App，双击也会打开浏览器选择器。
- 选择器只显示文件名。选定浏览器后，Prism 会把原始文件交给它打开。打开失败时，可重试或改选其他浏览器。

## 更新与安装

- v1.14.11 及以后原生版可在 Prism 设置或菜单栏菜单中检查更新。若安装需要允许本次未公证公开测试更新，请确认下载来源后再选择。
- 首次安装或仍在使用 v1.14.10 及更早原生版时，退出 Prism，打开 DMG，将应用拖入「应用程序」，再重新打开。规则、设置和历史保存在应用包外。[下载安装包](https://github.com/Halewwang/Prism/releases/download/v1.15.6/Prism-1.15.6-universal-test.dmg)
- 本版使用 ad hoc 签名，尚未通过 Apple 公证。在下载目录运行 `shasum -a 256 -c SHA256SUMS.txt` 可校验安装包。App 内更新也会校验清单签名、包大小与 SHA-256。[下载校验文件](https://github.com/Halewwang/Prism/releases/download/v1.15.6/SHA256SUMS.txt)

已在 Apple Silicon Mac 上验证默认文件关联可以调出选择器，并用原始本地 HTML 文件确认可以正常打开。Intel 实机和自动安装流程尚未验收。

## English

Prism can now send local `.html` and `.htm` files to the browser you choose. This Universal public test supports macOS 15 or later on Apple Silicon and Intel Macs.

- In Finder, Control-click a local HTML file and choose **Open With → Prism**. If Prism is already the default app for that file type, double-click to open the browser picker.
- The picker shows only the filename and passes the original file to your chosen browser. If opening fails, you can retry or choose a different browser.
- Native v1.14.11 and later can check for updates in Prism Settings or the menu bar menu. For a first installation or an upgrade from v1.14.10 or earlier, quit Prism, open the DMG, drag the app into Applications, and reopen it. Rules, settings, and history are stored outside the app bundle. [Download the installer](https://github.com/Halewwang/Prism/releases/download/v1.15.6/Prism-1.15.6-universal-test.dmg)
- This public test is ad hoc-signed and is not Apple-notarized. Run `shasum -a 256 -c SHA256SUMS.txt` in the download folder to verify the installer. In-app updates also verify the manifest signature, package size, and SHA-256. [Download the checksum file](https://github.com/Halewwang/Prism/releases/download/v1.15.6/SHA256SUMS.txt)

On an Apple Silicon Mac, we verified that the existing default file association opens the picker and confirmed that an original local HTML file opens successfully. Physical Intel Mac and automatic installation testing are pending.
