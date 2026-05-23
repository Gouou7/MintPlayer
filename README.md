# MintPlayer

MintPlayer 是一款原生 macOS 本地音乐播放器，专注于本地音乐库管理、元数据浏览、播放队列和现代桌面体验。

当前版本：`0.3.0`

## 功能特性

- 本地音频播放：基于 `AVAudioPlayer` 播放本地音乐文件，支持播放/暂停、上一曲、下一曲、进度跳转、音量记忆、随机播放和列表循环。
- 音乐库扫描：添加资料库文件夹后递归扫描音频文件，并从元数据提取标题、艺术家、专辑、流派、年份、时长和封面。
- 多维浏览：提供喜欢的音乐、Songs、Albums、Artists、播放列表和资料库文件夹视图；Albums / Artists 使用响应式网格和详情 drill-in。
- 专辑与艺术家索引：使用轻量摘要索引和封面缩略图缓存，降低大资料库下切换 Albums / Artists 的开销。
- 播放列表：支持创建、编辑名称和描述、删除、排序，以及通过菜单或将歌曲拖拽到侧栏播放列表来添加歌曲。
- 原生表格交互：歌曲列表使用 `NSTableView` 桥接，支持多选、Shift/Command 选择、双击播放、右键菜单、列宽调整和拖拽；表头可切换播放次数、添加时间和喜欢等列，并按页面记住列布局。
- 系统媒体控制：接入 macOS Now Playing、媒体键、控制中心和远程播放命令。
- 喜欢与屏蔽：可从播放栏或歌曲列表收藏歌曲，也可屏蔽某个资料库文件夹中的歌曲并在设置中取消屏蔽。
- 独立歌词窗口：从播放栏打开可调整大小、可进入系统全屏的歌词窗口，同步 `.lrc` 歌词会随播放定位高亮；窗口顶部背景区域使用系统原生窗口交互，支持双击触发 macOS Zoom 并再次双击恢复。
- 现代 macOS 界面：原生 `NavigationSplitView` 侧栏、Scroll Edge Effect、液态玻璃风格搜索/按钮、原生 Settings 窗口和悬浮播放栏。
- 桌面交互反馈：主要按钮、侧栏行、列表行、网格卡片和原生表格行具备克制的 hover / pressed 反馈。
- 调试隔离：Debug 构建使用独立应用名、Bundle ID、Application Support 目录和 `UserDefaults` 前缀，避免污染 Release 数据。
- 持久化状态：保存音乐库、播放列表、播放次数、添加时间、喜欢与屏蔽状态、上次播放队列、侧栏/表格偏好、音量、主题和语言设置。

## 技术栈

- **语言**: Swift 5
- **UI**: SwiftUI，部分复杂列表通过 AppKit `NSTableView` 桥接
- **音频**: AVFoundation
- **系统媒体控制**: MediaPlayer / Now Playing / Remote Command Center
- **macOS 互操作**: AppKit（文件夹选择、Finder 打开、表格桥接、少量窗口/侧栏行为修正）
- **状态管理**: `ObservableObject` + `@Published`
- **持久化**: 资料库和播放列表写入 SQLite；播放会话与界面偏好使用 `UserDefaults`；封面缓存写入 Application Support
- **构建工具**: Xcode project，当前没有 Swift Package Manager 入口
- **最低系统**: macOS 26.0
- **外部依赖**: 无第三方依赖清单

## 快速开始

### 环境要求

- macOS 26.0 或更高版本。
- 支持 macOS 26 SDK 的 Xcode。

### 安装与配置

1. 克隆项目到本地。
2. 使用 Xcode 打开 `MintPlayer.xcodeproj`。
3. 选择 scheme `MintPlayer` 和运行目标 `My Mac`。
4. 首次运行后，在设置窗口添加本地音乐文件夹。

项目没有外部依赖，也没有额外的环境变量配置。

### 构建

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

Debug 构建会生成 `MintPlayer Debug.app`，使用 `dev.govo.mintplayer.debug` 和独立配置目录；Release 构建会生成 `MintPlayer.app`，使用正式配置。

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -configuration Release -destination 'platform=macOS' build
```

### 清理并构建

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build
```

### 运行

在 Xcode 中打开 `MintPlayer.xcodeproj` 后使用 `Command + R` 运行。命令行构建产物位于 Xcode 的 DerivedData 中，日常开发建议直接通过 Xcode 启动。

### 依赖、测试和 lint

- 当前没有 `Package.swift`、`package.json`、`go.mod`、`requirements.txt` 或其他依赖清单。
- 当前没有测试 target。
- 当前没有 SwiftLint 或其他 lint 配置。
- 文档或 UI 小改可按范围手动验证；代码改动建议至少运行一次清理构建。

### 持久化位置

- 资料库 SQLite 数据库位于用户 Application Support 下；Release 使用 `MintPlayer/MintPlayer.sqlite`，Debug 使用 `MintPlayer-Debug/MintPlayer.sqlite`。
- 歌曲统计和屏蔽记录跟随对应资料库文件夹；从 Mint Player 移除文件夹后，这些记录会随库内歌曲一起移除，磁盘上的音乐文件不会被删除。
- 播放会话、表格列布局、侧栏顺序、音量、主题和语言等偏好继续使用 `UserDefaults`。

## 使用示例

### 添加本地音乐库

```text
1. 打开 Mint Player
2. 点击侧栏底部设置按钮
3. 在 Music Library 区域点击 Add Music Library
4. 选择包含音乐文件的文件夹
5. 等待扫描完成后，在 Songs / Albums / Artists 中浏览
```

### 播放和管理队列

```text
1. 在 Songs 表格中双击歌曲开始播放
2. 右键歌曲选择 Play Next 或 Add to Queue
3. 点击底部播放栏的队列按钮查看 Up Next
4. 使用播放栏控制随机播放、上一曲、播放/暂停、下一曲和循环
```

### 命令行检查工程

```sh
xcodebuild -list -project MintPlayer.xcodeproj
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

## 项目目录结构

```text
MintPlayer/
├── MintPlayer/
│   ├── App/              # SwiftUI App 入口和 Info.plist
│   ├── Models/           # Song、Album、Artist、Playlist 等值模型
│   ├── Stores/           # MusicLibrary、SettingsManager 等应用状态与持久化
│   ├── Services/         # AudioPlayer、NowPlayingService 等平台服务
│   └── Views/
│       ├── Root/         # 主窗口布局和路由
│       ├── Sidebar/      # 侧栏、选择模型、播放列表编辑
│       ├── Library/      # Songs、Albums、Artists 等资料库页面
│       ├── Player/       # 悬浮播放栏、队列弹窗和歌词窗口
│       ├── Settings/     # 设置窗口
│       └── Shared/       # 主题、搜索框、封面、空状态、共享修饰器
├── MintPlayer.xcodeproj/ # 原生 Xcode 工程
├── CHANGELOG.md          # 版本变更记录
├── AGENTS.md             # Agent 开发指南
├── VERSION               # 当前版本号
└── README.md             # 项目说明
```

## 开发说明

- 当前没有测试 target 或 lint 配置，提交前至少运行一次 `xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build`。
- 项目没有 `Package.swift`，不要使用 `swift build` 或 `swift test` 作为主要验证方式。
- 不要提交本地音乐文件、用户资料库路径、DerivedData、`.xcuserstate` 或其他个人环境文件。
- 涉及 AppKit 互操作时，把桥接代码限制在小范围组件或 helper 中，避免把平台对象扩散到普通 SwiftUI 视图。
- 歌词窗口的拖动和顶部双击缩放应优先使用 SwiftUI/macOS 原生窗口行为，例如 scene 级 `windowBackgroundDragBehavior(.enabled)`，不要自行计算窗口铺屏尺寸或重写双击缩放状态。
- 版本发布时同步更新 `VERSION`、Xcode `MARKETING_VERSION`、`CHANGELOG.md` 和 Git tag；设置窗口 About 版本号会跟随 bundle 版本并追加构建类型后缀。
