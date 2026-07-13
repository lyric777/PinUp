# PinUp

[English](README.md) | [简体中文](README.zh-Hans.md)

PinUp 可以把任意 macOS 窗口固定在你的工作区上方。

把模拟器、查词软件、视频会议、文档页面、监控面板，或任何小工具窗口固定住，然后继续在其他 App 里工作，不用来回切换窗口。

![PinUp demo](docs/media/pin-next-to-editor.gif)

## 亮点

- 用 `Option + Command + P` 固定当前聚焦窗口
- 让固定窗口保持在其他 App 上方
- 鼠标移到固定窗口上时，可以继续点击、滚动、输入
- 原窗口移动或调整大小时，固定预览会同步跟随
- 支持英文和简体中文
- 作为菜单栏 App 静默运行，不占 Dock

## 使用场景

PinUp 适合这些时刻：

- 把 Android Emulator 固定在编辑器旁边，一边改代码一边看效果
- 把词典或翻译工具固定住，写东西时随手查词
- 把参考资料固定在屏幕一角，在多个 App 间切换时也能看到
- 把构建进度、监控面板、视频会议放在最上方，但不占满屏幕

![Hover to interact](docs/media/hover-to-interact.gif)

## 使用方式

1. 启动 PinUp。
2. 授予 Accessibility 和 Screen Recording 权限。
3. 聚焦你想固定的窗口。
4. 按下 `Option + Command + P`。
5. 想点击、滚动或输入时，把鼠标移到固定窗口上。
6. 按下 `Option + Command + U` 取消固定。

你也可以通过菜单栏图标来固定窗口、取消固定、打开设置、切换语言、复制调试日志。

## 权限

PinUp 需要两个 macOS 权限：

- Accessibility：识别和聚焦当前窗口
- Screen Recording：捕获固定窗口的实时预览

授予 Screen Recording 后，macOS 可能会要求你退出并重新打开 App。

![Permissions](docs/media/permissions.png)

## 从源码构建

要求：

- macOS 15+
- 已安装 macOS SDK 的 Xcode
- Apple Silicon Mac

构建：

```bash
xcodebuild -project PinUp.xcodeproj -scheme PinUp -configuration Debug -derivedDataPath .derivedData build
```

运行 Debug App：

```bash
open .derivedData/Build/Products/Debug/PinUp.app
```

## 需要补充的素材

推荐准备这些素材：

- `docs/media/pin-next-to-editor.gif`：把模拟器或小工具窗口固定在编辑器旁边，然后继续编辑。
- `docs/media/hover-to-interact.gif`：鼠标移到固定窗口上，点击或滚动，然后回到其他 App。
- `docs/media/follow-window.gif`：移动或调整原窗口大小，展示 PinUp 同步跟随。
- `docs/media/menu.png`：展示菜单栏控制项。
- `docs/media/permissions.png`：展示权限引导页面。

录制时注意避开本地路径、真实项目名、token、私人消息和敏感代码。

## 说明

PinUp 不使用私有 API 修改其他 App 的窗口层级。它会展示一个实时固定预览，并在鼠标移到预览上时，把交互交还给原窗口。

某些系统窗口、受保护内容，或捕获行为比较特殊的 App，可能无法正常预览。
