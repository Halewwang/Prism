# Prism 1.14.11（构建 12）公开测试版

本版随 GitHub 仓库迁移到 [Halewwang/Prism](https://github.com/Halewwang/Prism) 发布，更新下载、反馈和项目入口。功能与界面保持 1.14.10 的行为，支持 macOS 15+，包含 Apple Silicon 与 Intel 二进制。

## 更新内容

- 原生更新检查、安装包及签名清单的下载地址校验同步新仓库，继续保留 HTTPS、GitHub 主机、精确路径、Ed25519 签名与 SHA-256 验证。
- 应用关于窗口、官网与开发入口同步新地址。
- GitHub 产品介绍提供中英文版本，配套对应语言的原生界面截图。

## 旧版用户手动升级一次

**v1.14.10 及更早原生版只信任旧仓库下载路径，改名后无法通过 App 内更新。** 请从 [本版发布页](https://github.com/Halewwang/Prism/releases/tag/v1.14.11) 下载 `Prism-1.14.11-universal-test.dmg`，退出 Prism 后，将新版拖入“应用程序”替换旧版。本机规则、设置和历史保存在应用包外。

安装本版后，后续 App 内更新会使用新仓库地址。请勿依赖 GitHub 的 `releases/latest`，它仍可能指向旧 Electron 稳定版。

## 首次打开与文件校验

本版使用 ad hoc 签名，尚未完成 Developer ID 签名与 Apple 公证。先尝试打开“应用程序”中的 Prism；若系统提示无法验证开发者，确认下载来源及校验值后，可在“系统设置 → 隐私与安全性 → 仍要打开”中手动允许。此步骤不适用于恶意软件或应用损坏警告。

下载同一发布页的 `SHA256SUMS.txt` 后，在下载目录执行 `shasum -a 256 -c SHA256SUMS.txt`。发布同时提供 `update-manifest.json` 与 `update-manifest.sig`，供原生更新器验证；更新签名不等同于 Apple 公证。

## Public-test migration

Prism has moved to **Halewwang/Prism**. Native v1.14.10 and earlier trust the old repository path and cannot update in-app after the rename. Download this release manually, quit Prism, and replace the app in Applications once. Local rules, settings, and history are preserved. Subsequent in-app updates use the new repository.

This is an ad hoc-signed, unnotarized public test for macOS 15+. It includes Apple Silicon and Intel binaries. Verify the download against `SHA256SUMS.txt`; first launch may require manual approval in macOS.

## 验证与边界

本轮 3 套原生更新测试共 20 项通过，官网 ESLint 与 TypeScript／Vite 构建通过。Universal Release 构建、arm64／x86_64 双架构、应用与安装助手 ad hoc 签名、硬化运行时、无 Sparkle 动态依赖、DMG 完整性与更新清单签名验证通过；禁止访问正式 Prism 数据目录的隔离启动中，进程保持运行 5 秒。发布流程要求草稿资产重新下载并核对字节、SHA-256 与固定公钥签名后再公开。界面预览沿用 1.14.9 的真实窗口与示例数据，主界面与本版一致。

本轮不宣称完成 Intel 实机、全部受支持 macOS 版本、来源应用全覆盖或 Chrome／Edge Profile 的真实浏览器验收。
