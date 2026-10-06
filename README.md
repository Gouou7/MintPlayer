# Mint Player

[English](README.en.md) | 简体中文

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

Mint Player 是一款面向 macOS 的原生本地音乐播放器，采用 macOS 26 的 Liquid Glass 设计语言。它直接扫描指定的本地文件夹建立资料库，只读取音频文件，不会修改、移动或删除它们。

## 系统需求

- macOS 26.0 或更高版本
- 如需自行构建，还需要带 macOS 26 SDK 的 Xcode

## 功能

- 播放常见音频文件，导入文件夹时递归扫描子目录
- 按专辑或艺人浏览曲目，支持自建播放列表
- 收藏或屏蔽歌曲，并统计播放次数
- 显示内嵌或独立窗口歌词，支持 LRC 滚动高亮与时间调整
- 可选择性开启本机 MCP 服务，让 Agent 搜索歌曲并控制播放与待播队列

## 应用截图

![Mint Player 主窗口](docs/images/Main.png)

![Mint Player 边栏窗口](docs/images/MainSidebar.png)

![Mint Player 歌词窗口](docs/images/MainLyric.png)

## 使用

### 首次启动

1. 打开设置，添加本地音乐文件夹；也可按 `⌘⇧O` 或直接把文件夹拖入窗口导入。
2. 通过侧栏浏览歌曲、专辑、艺人、喜欢、播放列表或资料库文件夹。

### 键盘快捷键

| 快捷键 | 操作 |
| --- | --- |
| `⌘P` | 播放或暂停 |
| `⌘←` / `⌘→` | 上一首 / 下一首 |
| `⌘F` | 定位搜索框 |
| `⌘⇧O` | 导入文件夹 |

### 界面语言与主题

设置中可选择跟随系统、English 或简体中文，以及跟随系统、浅色或深色主题。

### 系统集成

支持通过 macOS Now Playing、媒体键、控制中心和 Dock 菜单控制播放。

## MCP 播放控制

Mint Player 可选择性开启本机 MCP 服务，让本机的 MCP 客户端（例如 Agent）搜索资料库，并控制播放与待播队列。服务默认关闭，仅监听 `127.0.0.1`，默认要求访问令牌。

开启方式、令牌与端口设置、可用工具见 [MCP 播放控制](docs/mcp.md)。

## 技术栈

- Swift 5 与 SwiftUI，局部通过 AppKit 桥接原生控件
- AVFoundation 播放音频，MediaPlayer 更新系统媒体信息
- SQLite 保存资料库记录与 MCP 访问令牌，`UserDefaults` 保存其余偏好设置

## 构建

在 Xcode 中打开 `MintPlayer.xcodeproj`，选择 `MintPlayer` scheme 与 `My Mac`，然后按 `Command + R` 运行。首次构建需要联网解析 SwiftPM 依赖。

### 命令行

构建 Debug 版本：

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme MintPlayer -configuration Debug -destination 'platform=macOS' build
```

> [!NOTE]
> Debug 构建会使用独立于 Release 构建的应用名称、Bundle ID、Application Support 目录和偏好设置前缀。

## 常见问题

- **添加文件夹后没有歌曲**：确认文件夹内有受支持的音频文件；子目录会被递归扫描；被屏蔽的歌曲不会出现在资料库中。
- **Debug 与 Release 的资料库不互通**：两者使用相互隔离的存储目录，属预期行为。
- **没有歌词**：歌词取自与音频文件同名的 LRC 文件；也可在歌词界面手动指定其他文件与文本编码。
- **MCP 客户端连不上**：确认服务开关已打开、地址与端口一致、令牌已更新，详见 [MCP 播放控制](docs/mcp.md)。

## 许可证

本项目使用 GPLv3 许可证。详见 [LICENSE](LICENSE)。

## 免责声明

> [!WARNING]
> 本应用由 Agent 辅助开发，使用前请自行审查代码。使用本应用的风险由你自行承担，作者不对使用本应用造成的问题负责。
