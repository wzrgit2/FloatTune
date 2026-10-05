# MusicController

Windows 桌面悬浮音乐控件 —— 控制「系统当前正在播放的任意播放器」
（汽水音乐 / 网易云 / QQ音乐 / 浏览器 / Spotify 等，只要它接入了 Windows 系统媒体接口）。

## 功能
- 深色卡片悬浮窗：封面 + 歌名 + 歌手
- 播放/暂停、上一首/下一首
- 可拖动进度条（点击/拖动跳转）
- 音量滑条（控制系统音量）
- 右下角拖动缩放，尺寸和位置自动记忆
- 最高层级置顶（全屏游戏需用「无边框窗口」模式才能覆盖）
- 没在播放时自动缩到任务栏；也可点「—」手动最小化
- 任务栏：窗口标题/悬停提示显示「歌名 - 歌手」，按钮带封面小徽标和播放进度
- 全局快捷键：Ctrl+Alt+空格 播放暂停、Ctrl+Alt+←/→ 上下首、Ctrl+Alt+↑/↓ 音量
- 支持开机静默自启

## 目录结构
```
src/                Electron 主进程 + 渲染进程
  main.js           窗口、置顶、热键、任务栏集成、桥接子进程
  preload.js        IPC 桥
  renderer/         界面（index.html / style.css / app.js）
  assets/           图标资源（应用图标 + 缩略图按钮图标）
bridge/smtc.ps1     Windows 媒体桥（WinRT SMTC + CoreAudio，读状态/发指令）
tools/              开发辅助（图标生成、模拟播放源、打包由 electron-builder 负责）
build/icon.ico      应用/安装包图标
```

## 开发运行
```
npm install
npm start            # 正常启动（读真实播放器）
npm run start:mock   # 用模拟数据预览界面，不需要真的放歌
npm run dist         # 打包：NSIS 安装版 + 免安装单文件 exe
```

注意：首次需要网络下载 Electron 运行时（约 150MB）。
若 npm 的 install-scripts 策略拦截了 Electron 的安装脚本，手动执行一次：
`node node_modules/electron/install.js`

## 配置文件
运行后配置在 `%APPDATA%\MusicController\config.json`：
- `width` / `height` / `x` / `y`：窗口尺寸与位置（自动写入）
- `autostart`：是否开机自启（默认 true，静默）
- `hotkeys`：是否启用全局快捷键
- `autoHideIdle` / `idleGraceMs`：没在播放时多久自动缩到任务栏
- `transparentWindow`：是否使用半透明窗口。
  ⚠️ 实测在本机环境里 `transparent: true` 的窗口**不参与桌面合成**（窗口存在但完全看不见），
  所以默认关闭，用不透明深色卡片。想试就改成 true，不行再改回来。

## 已知限制
- 独占全屏（Exclusive Fullscreen）游戏无法被任何覆盖层覆盖，需改用无边框窗口全屏。
- Electron 44 已移除 `setThumbnailToolBar`，任务栏缩略图上的播放按钮无法实现（代码已做兼容跳过）。
- 歌词功能预留了位置（`#lyrics`），尚未接入。
