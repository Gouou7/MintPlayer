# Mint Player Agent 指南

## 项目与代码结构

Mint Player 是使用 Swift 5、SwiftUI、局部 AppKit 桥接、AVFoundation、MediaPlayer、SQLite 和 `UserDefaults` 构建的原生 macOS 本地音乐播放器。需要 macOS 26.0 或更高版本，以及带 macOS 26 SDK 的 Xcode。`MintPlayer.xcodeproj` 是唯一的构建入口。

本文档包含项目开发规则、实现约束及验证指南。

| 位置 | 职责 |
| --- | --- |
| `MintPlayer/App/` | 应用入口、场景、应用代理、配置及 Info.plist 模板 |
| `MintPlayer/Models/` | 歌曲、专辑、艺人、播放列表、资料库来源和主题 |
| `MintPlayer/Stores/` | `MusicLibrary` 状态与索引；`SettingsManager` 偏好设置与本地化 |
| `MintPlayer/Services/` | 音频播放、SQLite 持久化、歌词解析及 Now Playing |
| `MintPlayer/Views/` | `Root`、`Sidebar`、`Library`、`Player`、`Settings` 及可复用的 `Shared` 视图和 AppKit 桥接 |
| `Scripts/embed-git-version.sh` | 在构建阶段根据 Git 标签生成版本信息 |
| `docs/images/` | README 截图与图片资源 |

`MintPlayerApp` 用 `@StateObject` 创建共享状态，并通过 `@EnvironmentObject` 注入主窗口、歌词窗口和设置场景。`MusicLibrary` 扫描文件、汇总专辑和艺人，并通过 `LibraryPersistenceStore` 保存资料库状态。`AudioPlayer` 负责 `AVAudioPlayer`、队列、播放状态恢复、有效播放次数统计及系统媒体信息更新。SQLite 保存资料库记录；带命名空间的偏好设置保存设置和界面状态；Application Support 保存数据库和封面缓存。

## 工作规则

- 在当前分支工作，保留用户未提交的改动。只修改任务相关文件。
- 修改行为前先阅读相关实现；扩展现有辅助逻辑，避免重写子系统。
- 除非用户明确要求，否则不要运行构建或测试。
- 除非用户明确批准破坏性变更或迁移，否则保持公开 API 和 SQLite 兼容性。
- 除非用户明确要求，否则不要引入包管理器、依赖、测试 target、脚本、Lint 工具或 CI 配置。
- 优先使用原生 macOS 控件与系统行为，除非用户要求自定义实现。不要留下缺少实际功能的占位界面。
- 将 AppKit 对象限制在 representable、coordinator、职责明确的辅助类或服务中。不要用定时器、强制重建或关闭再打开等变通方式掩盖原生控件问题。
- 遵循现有 Swift 风格：四空格缩进、视图文件以主要类型命名、视图局部状态使用状态属性包装器、共享状态通过 `@EnvironmentObject` 传递。保持改动聚焦，仅为不明显的行为或平台限制添加注释。
- 面向用户的文案，包括菜单、错误、标签和辅助功能描述，须更新 `SettingsManager` 中所有受支持的语言。

## 数据与播放约束

### 资料库与持久化

- 资料库操作不得修改、移动或删除用户的音频文件。移除文件夹只删除应用内引用和内部索引记录。权限范围仅限本地音乐管理所需。
- 重新扫描时保留歌曲 ID、喜欢状态、播放次数、屏蔽状态、来源及播放列表引用。将扫描结果与当前主线程快照合并，保留扫描期间的编辑。
- 在串行后台扫描队列中提取元数据，并分批发布进度。枚举失败时保留该来源的旧索引；单个文件处理失败时保留该文件的记录。只有完整遍历后才能移除缺失曲目。保存前先校正播放列表条目。
- 为每个来源使用扫描 token，移除来源后丢弃迟到的结果，并忽略重复的活动扫描。后台导入前先收集拖入的 URL；在主线程应用屏蔽歌曲及来源归属过滤。
- 在 schema 版本 3 上增量保留曲目编号、碟片编号和专辑艺人列：旧版本会破坏性地重置未知版本。检查 `PRAGMA table_info(songs)`，并在事务中补齐缺失列。拒绝不受支持的 schema；快照加载失败后禁止写入。绝不能通过删除表来处理版本不匹配。
- 保留合辑的专辑艺人分组，以及按碟片/曲目顺序播放的行为，包括元数据缺失的情况。

### 播放与队列

- 根据实际收听时长而不是播放点击次数计数；当前阈值为曲目时长的 60%。
- 队列重排和移除作用于待播歌曲。同步来源队列，使切换随机播放及恢复会话时保留编辑。重播历史歌曲时保留待播歌曲；“下一首播放”可重新定位队列中已有条目。
- 清空队列时保留一份撤销快照。后续队列编辑或曲目切换会使其失效；资料库刷新必须从快照中移除不可用歌曲。
- 用户明确执行随机播放时须生成新的排列。若有多首歌曲且排列与先前队列相同，需重新生成；仅调用 `shuffled()` 不能保证顺序变化。

### 歌词数据

- 按 `timestamp - fileOffsetMilliseconds / 1000 + userAdjustmentSeconds` 计算时间。正的 LRC 偏移会使歌词提前显示；负的用户调整也会使歌词提前显示。
- 将每首歌曲的自定义歌词文件路径、编码选择和时间调整保存在带命名空间的偏好设置中。在主线程之外加载并解析；丢弃已取消视图任务产生的结果。

## 界面与 AppKit 边界

### 资料库、搜索与窗口

- 保留原生 `NavigationSplitView` 侧栏和 Liquid Glass 行为。居中的悬浮播放器栏必须拦截点击，不能让点击穿透到资料库。
- 歌曲列表使用 `NativeSongTableView`；保留单选、多选、排序、双击播放、右键菜单、行尾操作、列自定义和拖拽功能。
- 专辑和艺人使用响应式网格；在最小窗口宽度下，每行至少显示四个主要项目。艺人导航可逐级进入艺人与专辑详情。匹配几何效果只应用于封面，不应用于文字、表格、卡片或页面容器。
- 原生搜索框置于右上角工具栏，在专辑和艺人详情页隐藏。列表和详情搜索使用不同的绑定。
- 在 `FloatingSearchField.swift` 中保留普通 `NSSearchField`；不要替换其 cell 或调整字段编辑器的内边距。忽略标记文本的输入法组合状态；编辑完成后，针对编辑当时捕获的绑定进行防抖；提交或结束编辑时确认输入；拆卸时取消待处理工作。不要用过期的 SwiftUI 状态覆盖正在编辑的内容。
- 通过场景级 `defaultWindowPlacement` 恢复歌词和设置窗口的位置及大小。AppKit observer 仅用于保存后续变化；窗口出现后再恢复会导致可见的跳动。

### 歌词展示

- 两种模式共用 `LyricsOverlayView`，并始终保持深色歌词界面。SwiftUI 负责内容与高亮；专门的 AppKit `NSScrollView` 桥接负责动画滚动偏移。缩小随播放节奏更新的范围，并控制逐行模糊的开销。
- 封面和背景图片之间直接交叉淡入淡出。缺少封面时过渡到灰色占位图和灰色背景；不要显示空白帧或上一首歌曲的图片。
- 内嵌歌词期间，资料库仍保持挂载，但禁用交互并从辅助功能树中隐藏，以保留侧栏、滚动、选择和导航状态。挂载状态与可见状态分开；先在屏幕外挂载一个固定尺寸的合成外壳，再对整个表面做动画；减少动态效果时改用透明度。避免子视图各自独立过渡。
- 在 `MainView` 中由所属的 `SidebarView` 有条件地移除侧栏切换按钮，使用 `.toolbar(removing: isLyricsMounted ? .sidebarToggle : nil)`。永久移除会破坏正常侧栏行为。页面工具栏项目必须遵守 `isPlayerOverlayPresented`。
- 保留原生工具栏。专门的 `NSWindow` 桥接在内嵌全屏歌词期间临时调整标题栏属性并隐藏工具栏，让歌词表面覆盖顶边。在 AppKit 全屏切换通知到达时重新应用状态；退出、关闭或拆卸时恢复所有捕获的属性。全屏关闭操作由歌词界面自有控件完成。
- 窗口模式的关闭操作放在工具栏尾部，在 `.automatic` 项目前添加 `ToolbarSpacer(.flexible)`。macOS 不支持 `.topBarTrailing`，语义位置也不能保证尾部对齐。

## 构建与验证

无需安装依赖。本仓库没有测试 target、Lint 配置或 CI 配置；不要假定这些命令存在。Xcode 会在构建阶段运行现有版本脚本。

仅在用户明确要求时，使用以下命令检查或构建：

```sh
xcodebuild -list -project MintPlayer.xcodeproj
xcodebuild -project MintPlayer.xcodeproj -scheme MintPlayer -configuration Debug -destination 'platform=macOS' build
```

获得 Release 构建授权后，将 `Debug` 改为 `Release`；当前提交必须有与之匹配的发布标签。在 Xcode 中运行时，打开工程，选择 `MintPlayer` 和 `My Mac`，然后按 `Command + R`。

Debug 使用 `Mint Player Debug.app`、Bundle ID `dev.govo.mintplayer.debug`、Application Support 目录 `MintPlayer-Debug` 和偏好设置前缀 `mintPlayer.debug`。Release 使用 `Mint Player.app` 以及 `MintPlayer` / `mintPlayer` 存储命名空间。须保持两者隔离。

用户要求手动验证时，覆盖受影响的范围：

| 范围 | 回归检查内容 |
| --- | --- |
| 资料库 | 添加/移除及重复添加文件夹；后台导入、进度与重试；重新扫描时的身份和元数据保留；文件不可读、离线文件夹、扫描期间移除、屏蔽歌曲及数据库读取失败 |
| 播放 | 播放/暂停淡入淡出、跳转、停止、上一首/下一首、播放结束、随机/循环、音量、状态恢复、Now Playing/Dock 操作、文件缺失/解码错误重试、队列编辑/撤销、历史重播及“下一首播放” |
| 表格与浏览 | 原生选择与操作、列/排序、拖到播放列表/Finder、响应式网格、空资料库导入、搜索范围与中文输入法组合、详情导航/封面过渡、合辑分组及碟片/曲目顺序 |
| 歌词 | 两种模式、反复打开/关闭及全屏切换、Esc、整体表面动画/减少动态效果、工具栏/侧栏恢复、时间同步/滚动/点击跳转、模糊、曲目/封面变化及缺失封面 |
| 歌词文件 | 正负 LRC 偏移与用户调整/重置；UTF-8/UTF-16/GB18030/Big5 及编码覆盖；自定义文件/重新加载/文件缺失；加载期间快速切歌 |
| 设置与布局 | 英文/中文、主题、歌词选项、文件夹重新扫描/移除确认、屏蔽歌曲、窗口恢复/缩放、窄窗口布局、侧栏宽度、窗口控制按钮、顶部滚动边缘覆盖及播放器栏点击拦截 |
| 键盘与辅助功能 | Command-F 定位可见搜索框；Command-P 切换播放；Command-Left/Right 切歌；Command-Shift-O 导入文件夹；两个进度滑块都支持键盘焦点、方向键和 VoiceOver 调整 |

仅修改文档时，核对内容与仓库是否一致、检查本地链接和最终 diff；无需构建应用。

## 文档与发布

- `README.md` 为仓库默认入口，使用中文；`README.en.md` 是对应的英文版。用户要求或你认为非常有必要时可修改 `README.md`，并保持中英文两份文档内容同步。
- `AGENTS.md`（即本文档）为 Agent 开发指南。
- `CHANGELOG.md` 记录用户可感知的软件变更日志。每次修改代码后应同步在顶部 `Unreleased` 区写入变更。
- Git Tag为唯一的版本号来源（匹配 `vMAJOR.MINOR.PATCH`），不要手动维护 Xcode 中 `MARKETING_VERSION` 或 `CURRENT_PROJECT_VERSION` 的占位值。
- `Scripts/embed-git-version.sh` 在 DerivedData 中生成 Info.plist。Debug 使用最新可达的匹配标签；Release 要求 HEAD 上有匹配标签。没有可达语义版本标签或 Git 元数据时构建失败。`CFBundleShortVersionString` 来自标签，`CFBundleVersion` 来自提交数；`MintDisplayVersion` 显示发布版本，或带七位哈希的 `MAJOR.MINOR.PATCH-COMMIT-debug`。

## Git 与数据安全

- 除非用户明确要求，否则不要 Commit、Tag、Push 或 Pull；Commit 之前需要用户确认 Commit Message。
- Commit Message 使用中文的 Conventional Commits 格式。
- Commit 前运行 `git status --short`，确认暂存区只有与任务相关的文件。
- 不要暂存密钥、Token、`.env` 文件、个人路径、真实资料库数据、用户音乐、构建产物、Xcode 用户状态、DerivedData、`.DS_Store` 或本地缓存。不要在源码或文档中硬编码用户本机的绝对路径。
