# MCP 客户端配置

本机 MCP 客户端可以通过 stdio 连接 Mint Player。App 退出后，客户端仍可连接并发现工具，首次调用工具时会自动打开播放器。

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

MCP 默认关闭，启用后默认要求访问令牌。关闭「要求访问令牌」时，可以省略 `MINTPLAYER_MCP_TOKEN`。此时，当前 macOS 账户下的进程无需令牌即可使用全部 MCP 工具。重新生成令牌后，需要更新客户端配置并重新连接。

Mint Player 将令牌保存在应用数据库的配置表中。请将真实令牌保存在个人客户端配置中，避免提交到仓库。

## 启动与退出

Mint Player 已经打开时，工具调用会控制同一个播放器实例。关闭客户端后，Mint Player 可以继续播放。关闭 App 设置中的 MCP 开关后，客户端的工具调用会被拒绝。

## MCP 功能

工具列表、参数及调用示例见 [MCP 功能参考](mcp-tools.md)。
