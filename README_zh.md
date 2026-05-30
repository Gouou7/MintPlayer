# Mint Player

<img src="docs/images/MintPlayer-Light-iOS-Default-1024x1024@1x.png" alt="Mint Player logo" width="120">

一款原生 macOS 本地音乐播放器，用于整理和播放你自己的音乐资料库。

## 主要功能

- 熟悉且精致的界面：使用 Liquid Glass 风格，并提供歌曲、专辑、艺人、喜欢、播放列表和文件夹视图。
- 本地优先的资料库管理：导入文件夹时不会改变原始文件结构。
- 灵活歌曲整理：可自定义播放列表、喜欢列表、屏蔽歌曲和播放次数统计。
- 本地歌词显示：支持显示本地 `.lrc` 文件歌词。

## 截图

![Mint Player 主窗口](docs/images/MintPlayer0.3.0Main.png)
![Mint Player 歌词窗口](docs/images/MintPlayer0.3.0FullScreen.png)

## 路线图

- ✅ 基础播放和资料库管理
- ✅ 更细致的交互和动画打磨
- ✅ 音频淡入淡出过渡
- ✅ 独立歌词窗口和同步本地歌词
- ✅ 喜欢、屏蔽歌曲、播放次数统计和播放会话恢复
- ⬜ 在线歌词搜索
- ⬜ 在线艺人图片搜索

## 已知问题

- ❌ 主窗口顶部的 `scrollEdgeEffectStyle` 效果可能随机失效。

## 构建

### 要求

- macOS 26.0 或更高版本
- 带 macOS 26 SDK 的 Xcode

### 使用 Xcode 运行

1. 在 Xcode 中打开 `MintPlayer.xcodeproj`。
2. 选择 `MintPlayer` scheme 和 `My Mac`。
3. 按 `Command + R` 运行。
4. 在设置中添加本地音乐文件夹。

### 命令行构建

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

> [!TIP]
> - Debug 构建会生成 `Mint Player Debug.app`。
> - Release 构建会生成 `Mint Player.app`。

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

## 许可证

本项目使用 GPLv3 许可证。详见 `LICENSE`。

## 免责声明

> [!WARNING]
> 本应用由 Agent 辅助开发。使用前请自行审查代码。

> [!WARNING]
> 使用本应用的风险由你自行承担。作者不对使用本应用造成的任何问题负责。
