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

P2 功能区使用 `public/screenshots/1.14.9/` 的英文规则、历史与设置截图，保留完整窗口及版本标注。截图进入视野后每 3.2 秒循环切换，可 Pause / Play；手动选择、键盘操作或聚焦截图会停止自动切换，离开视野时停止计时。减少动态效果时只保留手动切换。中英文 README 使用对应语言的 1.14.9 截图。

P3 选择器为网页交互预览：固定来源与链接头部，下方单排浏览器卡片使用真实横向 overflow，展示 Safari、Google Chrome、Dia、Arc、Firefox 五个样例；桌面约露出 3.5 张卡片，提示还能横向查看。进入视野 800ms 后，卡片用 1800ms 向右滚动，停留 400ms，再用 1800ms 返回，总计约 4.8 秒，只播放一次。指针按下、焦点、键盘或滚轮接手都会取消演示。支持滚轮横移、触控横滑与左右滚动按钮；点击卡片、数字 1–5、方向键、Home / End 可选择浏览器预览，不会启动本机浏览器。减少动态效果时不自动横移。图标来源见 `src/assets/browsers/README.md`。

截图展示 1.14.9 的实际 SwiftUI／AppKit 界面与内存示例数据，不包含私人链接或历史记录。更新截图时同步文件路径、alt、版本说明与根 README；截图版本独立于 `src/release.ts`，仅更新下载版本时不要把旧截图误标为新版本。

## 现有部署

官网地址为 https://prismmac.vercel.app（GitHub 仓库 homepage）；原地址继续可用。现有 Vercel Git 集成为 PR 生成 Preview、为 main 合并生成 Production，沿用现有项目。

官网是独立的 `website/` Vite 项目；Vercel 项目应以 `website` 为 Root Directory，执行 `npm run build`，输出 `dist`，沿用 `website/vercel.json`。仓库根目录保留旧 Electron 页面。云端 Root Directory 无法仅由仓库文件证明，部署后需核对生产 HTML、下载 asset 与版本文案；根 `.vercel/project.json` 只有旧 projectName，不应据此新建或切换项目。发布公测时先上传精确 tag 的 DMG 和校验文件，再发布引用这些文件的官网。

截图只展示界面与示例配置，不代表真实来源覆盖、Intel 实机或实验性 Profile 路由已完成验收。相关限制以公开测试说明为准。
