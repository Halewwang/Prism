# Prism 官网

官网介绍原生公开测试版，使用 React、TypeScript 与 Vite。发布版本、系统要求、架构与 GitHub 下载地址集中在 `src/release.ts`。

GitHub 的 `releases/latest` 排除预发布版本，目前仍指向旧 Electron 稳定版。官网必须使用原生公测的精确 tag 与 asset 地址。更新版本时同步 `src/release.ts`、根 README，以及发布说明；核对公开 release 的 prerelease 状态、架构、系统要求、安装包名称和校验值。

```bash
npm ci
npm run dev
npm run lint
npm run build
```

发布前还需在桌面和移动尺寸验证页面、下载链接、版本说明与截图。首屏使用可交互的链接演示：邮件链接 → 选择浏览器 → 在目标浏览器中打开同一链接。自动演示播放一次后停在选择器，手动操作会取消自动播放；减少动态效果时保留静态选择器。演示不会真实唤起本机应用。

P2 功能区使用 `public/screenshots/1.14.9/` 的英文规则、历史与设置截图，保留完整窗口及版本标注。截图进入视野后每 3.2 秒自动循环切换，无播放控制按钮。焦点位于该区域内时保持当前页，移焦到区域外后自然继续；离开视野时停止计时。减少动态效果时只保留手动切换。中英文 README 使用对应语言的 1.14.9 截图。

P3 默认展示 v1.15.0 链接预览界面，并在右侧说明文字下方提供 Link preview / Browser picker 模式切换，与上方功能模块的控件位置一致。预览采用与 App 一致的紧凑顶部控制栏：来源、地址与导航、浏览器图标及数字、Esc；窄容器切为单图标与上下按钮，候选列表只显示图标和数字。内嵌内容使用从 google.com 实际打开后截取的真实页面图片（`public/screenshots/1.15.0/google-home.jpg`），只截取公共内容区域，不包含账号头像或信息；不重建 Google 界面，也不提交搜索。浏览器选择与快捷键只演示交接反馈，不打开本机应用；按 Esc 或关闭按钮后可重新打开演示。

Browser picker 保留传统选择器的单排浏览器卡片和横向滚动，展示 Safari、Google Chrome、Dia、Arc、Firefox 五个样例。传统选择器在可见且未被用户操作时演示横向滚动，离开视野或切换模式即停止；减少动态效果时不自动滚动。两种模式使用局部键盘操作，模式 tabs 支持左右键与 Home / End；非当前模式的交互组件卸载。图标来源见 `src/assets/browsers/README.md`。

截图展示 1.14.9 的实际 SwiftUI／AppKit 界面与内存示例数据，不包含私人链接或历史记录。更新截图时同步文件路径、alt、版本说明与根 README；截图版本独立于 `src/release.ts`，仅更新下载版本时不要把旧截图误标为新版本。

## 现有部署

官网地址为 https://prismmac.vercel.app（GitHub 仓库 homepage）；原地址继续可用。现有 Vercel Git 集成为 PR 生成 Preview、为 main 合并生成 Production，沿用现有项目。

官网是独立的 `website/` Vite 项目；Vercel 项目应以 `website` 为 Root Directory，执行 `npm run build`，输出 `dist`，沿用 `website/vercel.json`。仓库根目录保留旧 Electron 页面。云端 Root Directory 无法仅由仓库文件证明，部署后需核对生产 HTML、下载 asset 与版本文案；根 `.vercel/project.json` 只有旧 projectName，不应据此新建或切换项目。发布公测时先上传精确 tag 的 DMG 和校验文件，再发布引用这些文件的官网。

截图只展示界面与示例配置，不代表真实来源覆盖、Intel 实机或实验性 Profile 路由已完成验收。相关限制以公开测试说明为准。
