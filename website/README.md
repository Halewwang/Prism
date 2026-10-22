# Prism 官网

官网介绍原生公开测试版，使用 React、TypeScript 与 Vite。发布版本、系统要求、架构与 GitHub 下载地址集中在 `src/release.ts`。

GitHub 的 `releases/latest` 排除预发布版本，目前仍指向旧 Electron 稳定版。官网必须使用原生公测的精确 tag 与 asset 地址。更新版本时同步 `src/release.ts`、根 README，以及发布说明；核对公开 release 的 prerelease 状态、架构、系统要求、安装包名称和校验值。

```bash
npm ci
npm run dev
npm run lint
npm run build
```

发布前还需在桌面和移动尺寸验证页面、下载链接、版本说明与截图。当前截图位于 `public/screenshots/brand-preview-2026-10-22/`，英文用于官网，中文用于根 README。规则、历史和设置保留完整原生窗口，选择器单独展示；切换截图的按钮与原图链接都应可用。

截图是基于 1.14.8 原生界面的品牌更新开发预览，使用实际 SwiftUI／AppKit 组件与内存示例数据，不包含私人链接或历史记录。更新截图时同步文件路径、alt、版本说明与根 README；截图标记独立于 `src/release.ts`；当前公开安装包仍使用旧图标，不要将开发预览误标为已发布版本。

## 现有部署

官网地址为 https://prism-browser-switching.vercel.app（GitHub 仓库 homepage）。现有 Vercel Git 集成为 PR 生成 Preview、为 main 合并生成 Production，沿用现有项目。

官网是独立的 `website/` Vite 项目；Vercel 项目应以 `website` 为 Root Directory，执行 `npm run build`，输出 `dist`，沿用 `website/vercel.json`。仓库根目录保留旧 Electron 页面。云端 Root Directory 无法仅由仓库文件证明，部署后需核对生产 HTML、下载 asset 与版本文案；根 `.vercel/project.json` 只有旧 projectName，不应据此新建或切换项目。发布公测时先上传精确 tag 的 DMG 和校验文件，再发布引用这些文件的官网。

截图只展示界面与示例配置，不代表真实来源覆盖、Intel 实机或实验性 Profile 路由已完成验收。相关限制以公开测试说明为准。
