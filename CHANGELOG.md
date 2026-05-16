# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 暂无。

### Changed
- 暂无。

### Deprecated
- 暂无。

### Removed
- 暂无。

### Fixed
- 暂无。

### Security
- 暂无。

## [0.2.0] - 2026-05-16

### Added
- 通过 `MediaPlayer` 接入 macOS Now Playing、媒体键和控制中心。
- 播放列表支持描述字段，并可在编辑界面修改名称和描述。
- 侧栏 Library、Playlists、Folders 分组支持折叠、排序记忆和新增入口。
- Songs、playlist、Folder、专辑详情和艺术家详情歌曲列表支持原生表格选择、双击播放、右键菜单、列宽调整和拖拽。
- 专辑和艺术家页面支持基于元数据封面的浏览与播放。
- 专辑和艺术家资料使用轻量摘要索引，并为封面缩略图加入缓存，降低大资料库切换页面时的内存和主线程压力。
- 歌曲拖拽支持放入侧栏播放列表，使用原生 drop destination 将歌曲加入目标播放列表。
- 主要按钮、侧栏行、列表行、专辑/艺人卡片和 AppKit 表格行补充 hover 与 pressed 反馈。
- 歌曲表格右键菜单加入对应 SF Symbols 图标。

### Changed
- 工程入口统一为原生 `MintPlayer.xcodeproj`，target、scheme、product、module 统一为 `MintPlayer`。
- 源码目录调整为 `App`、`Models`、`Stores`、`Services`、`Views` 分层。
- 底部播放栏改为悬浮玻璃质感，并优化队列、更多菜单和音量弹窗交互。
- 侧栏选中态、按钮和主要交互统一使用项目主题色。
- 设置界面改为独立 Settings scene，并使用更原生的 `TabView`、`Form` 和 `Section` 布局。
- 主侧栏保留原生 `NavigationSplitView` 的 Liquid Glass 外观，限制宽度并移除侧栏开关按钮。
- Artists 改为艺人浏览、艺人详情、专辑详情的 drill-in 体验，搜索语义随当前层级切换。
- 专辑详情在 Albums 和 Artists 中复用同一详情视图。
- 搜索栏和相关排序按钮移动到页面标题栏右上角。
- Artists 详情区域和 Albums 详情页改为响应式头部布局。
- 非 Folder 歌曲表格会随窗口宽度自动收缩列宽；Folder 页面继续保留紧凑多列表格和横向滚动。
- 主窗口最小尺寸调整为 `980 x 600`，侧边栏最小宽度下调，播放栏固定宽度并居中显示。
- 底部播放栏高度缩小为 50pt，底部间距调整为 20pt。
- Albums 和 Artists 网格卡片尺寸缩小，保证最小窗口宽度下可一行显示四个元素。

### Deprecated
- 暂无。

### Removed
- 移除重复的 Swift Package / XcodeGen 工程入口和旧源码副本。
- 移除无入口引用的旧页面和组件：`ContentView`、`GenresView`、`PlaylistsView`、`PlaylistItemView`、`SongItemView`。
- 移除旧的均衡器占位接口和未使用的全局排序方法。

### Fixed
- 修复设置按钮打不开设置界面的问题。
- 修复播放队列从右侧栏打开的交互，改为播放栏按钮弹窗。
- 修复删除播放列表和文件夹缺少二次确认的问题。
- 修复主侧栏可被拖动关闭且关闭后无法恢复的问题。
- 修复打开艺术家详情时详情页反向挤压主侧栏的问题。
- 修复列表封面在选中或播放进度刷新时反复闪烁的问题。
- 修复歌曲表格右侧时长和三点菜单区域被滚动条遮挡的问题。
- 修复悬浮播放栏 Liquid Glass 区域点击穿透到底层内容的问题。

### Security
- 暂无。

## [0.1.0] - 2026-04-21

### Added
- 本地音乐播放器基本功能。
- 拖放导入音乐文件。
- 基于 AVFoundation 的真实音频播放。
- 进度条实时更新和拖动跳转。
- 侧边栏导航。
- 多资料库管理和音乐文件扫描。
- 浮动播放栏。
- 基础音乐排序功能。

### Changed
- 应用名称从 MusicPlayer 改为 Mint Player。
- 包名设置为 `dev.govo.mintplayer`。
- 版本号设置为 `0.1.0`。

### Deprecated
- 暂无。

### Removed
- 暂无。

### Fixed
- 修复 macOS 兼容性问题。
- 修复 `hoverEffect` 在 macOS 上不可用的问题。

### Security
- 暂无。
