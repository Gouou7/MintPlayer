# MCP 播放控制

本机 MCP 客户端可以通过 stdio 搜索 Mint Player 的资料库，并控制播放与待播队列。Mint Player 退出后，客户端仍可连接并发现工具，首次调用工具时会自动打开播放器。

## 配置客户端

1. 在 Mint Player 设置的「MCP」分区打开「启用 MCP」。
2. 点「复制命令路径」，将复制的完整路径设为客户端的 stdio 命令。路径需要指向 App 包内的 `mintplayer-mcp`。
3. 点「复制令牌」，在客户端的命令环境变量中设置 `MINTPLAYER_MCP_TOKEN`。重新连接客户端以应用配置。

在使用 `mcpServers` 格式的客户端中，可以按下面的示例填写。请用设置页复制的命令路径和令牌替换示例值。

```json
{
  "mcpServers": {
    "mint-player": {
      "command": "/Applications/Mint Player.app/Contents/MacOS/mintplayer-mcp",
      "env": {
        "MINTPLAYER_MCP_TOKEN": "替换为复制的令牌"
      }
    }
  }
}
```

在 Codex 中，将同样的命令和环境变量写入用户配置中的 `[mcp_servers.mint-player]` 和 `[mcp_servers.mint-player.env]`。

从旧版迁移时，将原来的 HTTP 地址配置换成 stdio 命令。已有令牌可以继续使用。Debug 和 Release 各自使用对应 App 包内的命令及令牌；移动或重命名 App 后，需要更新客户端的命令路径。

## 访问令牌

MCP 默认关闭，启用后默认要求访问令牌。关闭「要求访问令牌」时，可以省略 `MINTPLAYER_MCP_TOKEN`。当前 macOS 账户下的进程此时也可以控制播放。重新生成令牌后，需要更新客户端配置并重新连接。

Mint Player 将令牌保存在应用数据库的配置表中。请将真实令牌保存在个人客户端配置中，避免提交到仓库。

## 启动与退出

Mint Player 已经打开时，工具调用会控制同一个播放器实例。关闭客户端后，Mint Player 可以继续播放。关闭 App 设置中的 MCP 开关后，客户端的工具调用会被拒绝。

## 可用工具

| 能力 | 工具行为 |
| --- | --- |
| 搜索 | 搜索歌曲、艺人及专辑 |
| 播放 | 播放单首歌曲，或按顺序、随机播放指定艺人或专辑 |
| 读取 | 读取当前歌曲的完整歌词、播放状态与待播队列 |
| 控制 | 播放、暂停、上一首、下一首、音量、进度 |
| 队列 | 加入待播，以及移除、移动、清空和撤销清空待播队列 |

歌曲通过资料库 UUID 选择，艺人与专辑通过搜索结果中的 ID 选择。工具结果不包含本地音频路径。
