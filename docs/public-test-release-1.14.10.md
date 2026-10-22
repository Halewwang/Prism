# Prism 1.14.10（构建 11）公开测试版

本版修复状态栏菜单打开主窗口的问题，并精简菜单。支持 macOS 15 或更新版本的 Apple Silicon 与 Intel Mac。

## 本次更新

- 修复点击状态栏“打开 Prism”后主窗口未到前台的问题，打开时保留当前页面。
- 状态栏菜单只保留“打开 Prism”“暂停／恢复自动规则”和“退出 Prism”。历史、规则、设置和检查更新在主界面操作。
- 菜单与主界面共用同一自动规则设置；保留设置持久化、保存失败处理和菜单状态同步。

## 验证

本轮 87 项路由核心测试、493 项原生 Swift Testing 测试与 7 项 XCTest 测试通过，覆盖窗口置前、关闭后重开、最小化恢复、菜单动作和共享设置。更新签名测试 3 项、隔离启动规则测试 7 项，以及官网 TypeScript／Vite 构建与 ESLint 检查均通过。本轮未重跑完整 UI 自动化套件，真实状态栏点击与跨桌面表现留待安装后验收。

Universal Release 构建、应用与安装助手的 arm64／x86_64 双架构、ad hoc 签名、硬化运行时、无 Sparkle 动态依赖及 DMG 完整性核验通过。更新清单沿用客户端信任的 Ed25519 密钥签名并通过验签，DMG 的 SHA-256 与清单一致。禁止访问当前账号 Prism 生产数据目录的隔离启动检查中，新版进程保持运行 5 秒。

发布采用先上传 GitHub 草稿、重新下载全部四个资产核对字节大小、SHA-256 与更新签名，通过后再公开的流程。

## 安装与更新

发布后可在 Prism 设置中点击“检查更新”，下载并校验后确认安装。也可从 [GitHub 发布页](https://github.com/Halewwang/Prism-Browser-switching/releases/tag/v1.14.10) 下载 `Prism-1.14.10-universal-test.dmg`，退出 Prism 后将应用拖入 Applications 替换旧版。设置、规则和历史保存在应用包外。

发布文件包括 `SHA256SUMS.txt`、`update-manifest.json` 与 `update-manifest.sig`，用于完整性和更新签名校验。

## 公测边界

本版沿用 ad hoc 签名，尚未经过 Developer ID 签名和 Apple 公证。更新签名验证发布来源与文件完整性，不等同于 Apple 公证，macOS 仍可能阻止打开。

本轮未完成 Intel 实机、全部受支持 macOS 版本、真实来源应用全覆盖及 Chrome／Edge Profile 的真实浏览器验收；自动化测试不替代这些实机结果。README 界面预览仍标注为 1.14.9 示例截图。
