# 更新日志

[English](CHANGELOG.md) | [简体中文](CHANGELOG.zh-CN.md)

## 0.3.0 - 2026-07-18

- 增加完整英文与简体中文应用本地化，自动跟随 macOS 首选语言。
- 本地化连接状态、操作按钮、配置表单、校验和运行错误，不改变已保存 profile 的字段值。
- 增加完整中英文 README，以及中文 Security 和 Changelog 文档。
- 使用双语仓库描述、徽章、检索 topics 和双语 Release Notes 提升 GitHub 可发现性。

## 0.2.0 - 2026-07-18

- 用状态栏图标直接打开的独立连接管理窗口替代菜单栏 popover。
- 支持多条规则并发运行，每条规则拥有独立启用状态和运行状态。
- 为每条规则增加手工连接和断开操作。
- 增加 SOCKS 代理、本地转发和远程转发三种规则类型。
- 支持从 `~/.ssh/config` 导入具体 Host alias。
- 增加 SSH certificate、ProxyJump、压缩、超时和 keepalive 设置。
- 新 profile 默认从 18080 选择端口，避免常见代理端口冲突。
- SSH 启动前检测本地端口占用，并显示明确错误。

## 0.1.0 - 2026-07-17

- 增加原生 macOS 状态栏应用。
- 支持 SSH config alias、私钥和可选钥匙串密码认证。
- 支持 SOCKS5 动态转发和远端 HTTP/HTTPS 代理端口转发。
- 支持自动连接和登录时启动。
- 增加 profile CLI、本地应用打包和测试。
