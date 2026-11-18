# MCP 功能参考

[English](mcp-tools.en.md) · [客户端配置](mcp.md)

Mint Player 的工具通过 MCP `tools/list` 发现，并通过 `tools/call` 调用。表中的参数均为必填，标注「可选」的参数除外。工具调用失败时会返回 `isError: true`，错误内容包含 `code` 和 `message`。

歌曲结果使用资料库 UUID，包含 `id`、`title`、`artist`、`album` 和以秒为单位的 `duration`。工具结果不包含本地音频路径。

## 资料库搜索

三种搜索均接收 `query` 和可选的 `limit`。查询文本去除首尾空白后须为 1 至 200 个字符。结果默认最多 20 条，`limit` 的范围为 1 至 50。

| 工具 | 返回值 |
| --- | --- |
| `search_songs` | 按歌名、艺人或专辑搜索，返回 `songs`。使用其中的 `id` 播放、加入歌单或屏蔽。 |
| `search_artists` | 按艺人名搜索，返回 `artists`，每项含 `id`、`name`、`album_count`、`song_count`。 |
| `search_albums` | 按专辑名或艺人名搜索，返回 `albums`，每项含 `id`、`title`、`artist`、`year`、`song_count`。 |

## 播放与歌词

| 工具 | 参数 | 行为 |
| --- | --- | --- |
| `get_playback_state` | 无 | 返回当前播放状态。 |
| `get_current_lyrics` | 无 | 返回当前歌曲和完整歌词，使用 App 的歌词文件、编码和时间调整设置。 |
| `play_song` | `song_id` | 立即播放单首歌曲，保留已有的待播曲目。 |
| `play_artist` | `artist_id`、`mode` | 用指定艺人的歌曲替换队列并开始播放。 |
| `play_album` | `album_id`、`mode` | 用指定专辑的歌曲替换队列并开始播放。顺序模式沿用专辑的曲序。 |
| `pause` | 无 | 暂停。 |
| `resume` | 无 | 继续播放。 |
| `next` | 无 | 切换到下一首。 |
| `previous` | 无 | 从头播放当前歌曲，或切换到上一首。 |
| `set_volume` | `value` | 将音量设为 0 至 1。 |
| `seek` | `seconds` | 跳转到指定的非负秒数。 |

`artist_id` 和 `album_id` 来自资料库搜索。`mode` 可取 `sequential`（顺序）或 `shuffle`（随机）。

除歌词工具外，本组工具均返回播放状态，包括 `current_song`、`is_playing`、`current_time`、`duration`、`volume`、`shuffle_enabled` 和 `repeat_enabled`。`current_song` 在没有当前曲目时为 `null`，播放时间与时长以秒为单位。歌词结果包含 `song`、`format`（`synced` 或 `plain_text`）和 `lyrics`，同步歌词另有 `lines`，逐行给出以秒为单位的 `time` 和 `text`。

## 待播队列

| 工具 | 参数 | 行为 |
| --- | --- | --- |
| `get_queue` | 无 | 读取当前歌曲和按播放顺序排列的待播曲目。 |
| `queue_song` | `song_id`、`position` | 加入待播队列。`position` 为 `next`（下一首）或 `end`（队尾）。 |
| `remove_upcoming` | `song_id` | 移除指定待播歌曲。 |
| `move_upcoming` | `song_id`、`before_song_id`（可选） | 将歌曲移到另一首待播歌曲前，省略目标时移到队尾。 |
| `clear_upcoming` | 无 | 清空待播曲目，并保留一次撤销机会。 |
| `undo_clear_upcoming` | 无 | 在撤销记录有效时恢复最近清空的队列。 |

本组工具均返回 `current_song`、`upcoming_songs` 和 `can_undo_clear`。`current_song` 在没有当前曲目时为 `null`。

## 歌单管理

| 工具 | 参数 | 返回值和行为 |
| --- | --- | --- |
| `list_playlists` | `offset`、`limit`（均可选） | 按侧栏顺序返回 `playlists`。 |
| `get_playlist` | `playlist_id`、`offset`（可选）、`limit`（可选） | 返回 `playlist` 和按保存顺序排列的 `songs`。 |
| `create_playlist` | `name`、`description`（可选） | 创建空歌单并返回 `playlist`。名称去除首尾空白后须为非空。同名歌单通过 UUID 区分。 |
| `add_playlist_songs` | `playlist_id`、`song_ids` | 按输入顺序追加曲目，跳过已收录的歌曲。任一歌曲不在资料库中时，整批返回错误。返回 `playlist` 和 `added_count`。 |
| `remove_playlist_songs` | `playlist_id`、`song_ids` | 批量从歌单移除曲目。已不在歌单的曲目会被跳过。返回 `playlist` 和 `removed_count`。 |
| `move_playlist_song` | `playlist_id`、`song_id`、`before_song_id`（可选） | 移到指定曲目前，省略目标时移到末尾。两个歌曲 ID 均须属于该歌单。返回 `playlist`。 |

歌单摘要包含 `id`、`name`、`description` 和 `song_count`。`song_ids` 须为非空的歌曲 UUID 数组。编辑名称和简介、删除歌单可在 App 内完成。

`list_playlists`、`get_playlist` 和 `list_blocked_songs` 均支持分页。`offset` 从 0 开始，`limit` 默认 50，范围为 1 至 100。分页结果包含总条数 `total` 和下一页偏移量 `next_offset`，最后一页的 `next_offset` 为 `null`。

创建一张歌单并填入曲目：

1. 用 `search_songs` 搜索歌曲，记下返回的歌曲 `id`。
2. 用 `create_playlist` 创建歌单，例如传入 `{"name":"夜间播放"}`，记下 `playlist.id`。
3. 用 `add_playlist_songs` 传入该 `playlist_id` 和按所需顺序排列的 `song_ids`。可用 `get_playlist` 查看保存后的顺序。

## 歌曲屏蔽

| 工具 | 参数 | 返回值和行为 |
| --- | --- | --- |
| `block_song` | `song_id` | 屏蔽一首关联到资料库文件夹的歌曲，返回 `blocked_song`。 |
| `list_blocked_songs` | `offset`、`limit`（均可选） | 按屏蔽时间倒序返回 `blocked_songs`。 |
| `unblock_song` | `blocked_song_id` | 取消屏蔽并重扫来源文件夹，返回移除记录的 `blocked_song_id`。 |

屏蔽记录包含独立的 `id`、`title`、`artist`、`album` 和 ISO 8601 格式的 `blocked_at`。屏蔽会从资料库和歌单中移除歌曲，待播队列也会随资料库刷新。播放器会保留当前曲目直到切歌，本地文件保留。单独导入且未关联文件夹的歌曲仍留在资料库中，调用会返回 `song_source_unavailable`。

例如，先将 `search_songs` 返回的歌曲 `id` 传给 `block_song`。日后可从 `list_blocked_songs` 查到屏蔽记录，将记录的 `id` 作为 `blocked_song_id` 传给 `unblock_song`。歌曲文件可用时，重扫完成后会重新进入资料库。需要时可再添加到歌单。
