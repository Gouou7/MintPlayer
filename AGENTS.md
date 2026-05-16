# Mint Player 开发指南

## 项目概述

Mint Player 是一款 macOS 本地音乐播放器，使用原生 Xcode 工程构建。

- **语言**: Swift 5
- **UI 框架**: SwiftUI；复杂歌曲/艺人列表通过 AppKit `NSTableView` 桥接
- **音频框架**: AVFoundation
- **系统媒体控制**: MediaPlayer / Now Playing / Remote Command Center
- **桌面互操作**: AppKit（文件选择、Finder 打开、原生表格、少量窗口与侧栏行为）
- **状态管理**: `ObservableObject`、`@Published`、`@StateObject`、`@EnvironmentObject`
- **持久化**: `UserDefaults`；专辑封面缓存写入 Application Support
- **构建工具**: Xcode project
- **最低系统要求**: macOS 26.0
- **当前版本**: 0.2.0

当前项目没有 `Package.swift`、第三方依赖清单、测试 target 或 lint 配置。
工程中也没有 `package.json`、`go.mod`、`requirements.txt`、`Makefile` 或自定义构建脚本。

## 目录结构

```text
MintPlayer/
├── MintPlayer/
│   ├── App/              # `MintPlayerApp` 和 `Info.plist`
│   ├── Models/           # `Song`、`Album`、`Artist`、`Playlist` 等模型
│   ├── Stores/           # `MusicLibrary`、`SettingsManager`
│   ├── Services/         # `AudioPlayer`、`NowPlayingService`
│   └── Views/
│       ├── Root/         # 主窗口布局、NavigationSplitView 路由
│       ├── Sidebar/      # 侧栏、选择模型、播放列表编辑
│       ├── Library/      # Songs、Albums、Artists、Recent
│       ├── Player/       # 播放栏、队列弹窗
│       ├── Settings/     # 设置窗口
│       └── Shared/       # 主题、搜索框、封面、空状态和共享修饰器
├── MintPlayer.xcodeproj/ # 唯一构建入口
├── README.md             # 开发者说明
├── CHANGELOG.md          # Keep a Changelog 格式版本记录
├── VERSION               # 当前版本号
└── AGENTS.md             # 本文件
```

## 编码规范

### 命名

- 类型、枚举、协议使用 PascalCase，例如 `MusicLibrary`、`LibrarySelection`。
- 方法、变量、属性使用 camelCase，例如 `play(song:)`、`currentSong`。
- SwiftUI 视图文件以主类型命名，例如 `PlayerBarView.swift`。
- 按职责放置文件：模型进 `Models/`，状态进 `Stores/`，平台服务进 `Services/`，界面组件进对应 `Views/` 子目录。
- AppKit 桥接类型使用清晰的 `Native...View` 或专门 helper 命名，并放在 `Views/Shared/` 或对应页面目录中。

### 格式

- 使用 4 个空格缩进。
- 大括号 `{` 放在声明行末尾。
- 方法之间保留空行。
- 避免无意义的格式化 churn；不要改动与任务无关的文件。

### 类型与状态

- 优先使用 Swift 类型推断；复杂泛型、闭包或公开 API 可显式标注类型。
- 可选值优先使用 `guard let` 或 `if let`，避免强制解包。
- 视图层使用 SwiftUI 状态属性；跨页面共享状态通过 `@EnvironmentObject` 注入。
- 不要在普通 SwiftUI 视图中扩散 AppKit 对象；需要 AppKit 时保持在小范围 `NSViewRepresentable`、helper 或服务中。
- 主侧栏应优先保持原生 `NavigationSplitView` 和系统 Liquid Glass 行为；不要用自绘背景替换系统侧栏。
- 歌曲、播放列表、Folder 和详情页歌曲列表当前依赖 `NativeSongTableView`；修改交互时优先保持 `NSTableView` 原生选择、多选、双击、菜单和拖拽。
- Albums / Artists 浏览页应保持响应式网格，最小窗口宽度下至少一行显示四个主要元素。
- Artists 采用艺人浏览、艺人详情、专辑详情的 drill-in 结构；不要重新引入永久三栏艺人布局。
- 搜索栏默认放在页面标题栏右上角，搜索语义应跟随当前页面或详情层级。
- 底部播放栏是固定宽度、居中悬浮的 Liquid Glass 控件，应拦截点击，避免事件穿透到底层内容。

### 注释

- 注释使用中文。
- 仅为复杂逻辑、平台限制或非显而易见的行为添加注释。
- 不要添加复述代码本身的空注释。

## 常用命令

### 安装依赖

无需安装第三方依赖。打开 `MintPlayer.xcodeproj` 即可开发。

### 查看工程信息

```sh
xcodebuild -list -project MintPlayer.xcodeproj
```

### 构建

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" build
```

指定 macOS 目标构建：

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' build
```

### 清理并构建

```sh
xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build
```

### 运行

日常运行使用 Xcode：打开 `MintPlayer.xcodeproj`，选择 `MintPlayer` scheme，然后按 `Command + R`。

### 测试

当前没有测试 target。修改后至少运行一次清理构建，并按变更范围做手动回归。

### Lint

当前没有 SwiftLint 或其他 lint 配置。不要假设存在 lint 命令。

## 测试策略

- **构建验证**: 每次代码改动后运行 `xcodebuild -project MintPlayer.xcodeproj -scheme "MintPlayer" -destination 'platform=macOS' clean build`。
- **手动回归**: 根据改动覆盖导入文件夹、扫描音乐、Songs 双击播放、Albums/Artists 播放、播放列表编辑、队列、音量、设置窗口和系统媒体控制。
- **表格交互回归**: 涉及 `NativeSongTableView` 或 `NativeArtistTableView` 时，验证普通点击、Shift 连选、Command 多选、双击播放、右键菜单、三点菜单、列宽拖动和拖拽到 playlist / Finder。
- **布局回归**: 涉及主窗口、侧栏、Artists/Albums 详情时，验证窗口缩窄、侧栏宽度、Scroll Edge Effect、悬浮播放栏和搜索框位置。
- **单元测试**: 当前没有测试 target；新增复杂纯逻辑时，可先和用户确认是否创建测试 target。
- **集成/e2e**: 当前没有自动化集成或 e2e 测试；涉及 UI/播放行为时以本机手动验证为准。

## Git 工作流

- 默认在当前分支工作；不要自动创建 commit。
- 分支命名建议：`feature/<name>`、`bugfix/<name>`、`refactor/<name>`。
- 提交信息使用中文，格式建议为 `[类型] 描述`。
- 类型建议：`feat`、`fix`、`docs`、`style`、`refactor`、`test`、`chore`。
- 提交前检查 `git status --short`，确认没有无关文件或个人环境文件。

## Agent 行为约束

- 不要自动 commit、push 或创建 PR，除非用户明确要求。
- 修改前先了解现有代码和文档；不要凭空假设架构。
- 修改后运行可用的最小验证命令，当前首选 `xcodebuild ... clean build`。
- 发现不确定且会影响架构或数据兼容性的决策时，先向用户确认。
- 不要恢复或覆盖用户已有改动；遇到脏工作区时只处理任务相关文件。
- 不要引入新的包管理入口、测试 target 或脚本，除非用户明确要求。
- 不要把文档维护这类内部操作写入 `CHANGELOG.md`。
- 不要把“看起来可用”的假功能留在 UI 中；如果只是占位或无后端逻辑，优先移除或向用户确认。
- 不要用定时器、强制重建视图、关闭后再打开等方式掩盖原生控件问题；先理解 SwiftUI/AppKit 原生行为边界，再采用最小桥接。

## 安全注意事项

- 不提交密钥、令牌、`.env`、个人路径、用户音乐文件或真实用户数据。
- 不硬编码绝对路径；涉及文件访问时使用用户选择的 URL 或相对工程路径。
- 不提交 Xcode 用户状态、DerivedData、`.xcuserstate`、本机缓存或构建产物。
- 文件夹删除功能只应移除应用中的资料库引用和库内索引，不应删除用户磁盘文件。
- 申请系统权限时保持最小化，只请求本地音乐管理所需权限。

## 版本管理

- 版本号遵循语义化版本，当前版本记录在 `VERSION` 和 `Info.plist`。
- 发布前同步 `VERSION`、`Info.plist`、设置窗口 About 文案和 `CHANGELOG.md`。
- `CHANGELOG.md` 遵循 Keep a Changelog，并保留顶部 `Unreleased` 区。
