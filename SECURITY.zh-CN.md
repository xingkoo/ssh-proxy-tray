# 安全说明

[English](SECURITY.md) | [简体中文](SECURITY.zh-CN.md)

## 漏洞报告

如果发现凭证泄露、命令注入、主机密钥校验或端口暴露问题，请通过 GitHub Security Advisories 私下报告。

## 凭证处理

- 密码不会作为命令行参数，也不会写入日志。
- 未保存密码只保留在应用内存中，并通过随机令牌保护的 loopback helper 交给 OpenSSH。
- 主动保存的密码进入 macOS 钥匙串。
- 隧道配置使用仅当前用户可访问的文件权限，且不包含密码。
- 本地监听只允许 `127.0.0.1` 或 `localhost`。
- 可选 HTTP/HTTPS 端点是建立在该规则 SOCKS5 隧道之上的 loopback 本机适配器，不会再建立一条 SSH 连接。
- HTTP 适配器将请求头限制为 64 KiB，将初始解析与 SOCKS 握手限制为 15 秒，在转发前移除代理凭证，并强制普通 HTTP 请求关闭上游连接，避免连接被复用于另一个目标。由于它绝不暴露到 loopback 之外，因此不提供代理认证。
- 远程转发默认绑定 `127.0.0.1`。绑定到 `0.0.0.0` 可能通过 SSH 服务器暴露本地目标，并且需要服务端允许相应的 `GatewayPorts` 策略。
- 远程监听检查复用当前已认证的 OpenSSH ControlMaster socket。控制 socket 使用 `/tmp` 下每次连接独立的短路径，并在隧道停止时删除。
- 自动配置 `GatewayPorts` 永远不会静默执行。它需要用户在警告中明确确认和服务器免密码 `sudo`，只写入专用 sshd drop-in，使用 `sshd -t` 校验，reload 而不是 restart SSH；校验或 reload 失败时恢复原文件。
- `GatewayPorts clientspecified` 是服务器级策略，可能允许其他已授权 SSH 用户请求非 loopback 远程监听。防火墙和 `PermitListen` 仍由服务器管理员负责。
- 本地端口检查使用固定参数执行 `/usr/sbin/lsof` 并解析结构化 `-F` 字段；profile 值不会被插入 shell 命令。
- 端口检查中的进程终止永远不会自动执行。每次都需要明确确认，只发送 SIGTERM，并拒绝 PID 1 和当前 SSH Proxy Tray 进程。用户必须自行确认占用进程可以安全停止。
- 应用退出会等待受管 SSH ControlMaster 和子进程退出。有界 SIGKILL 兜底只作用于本应用创建并拥有的 SSH 子进程。
- 打包后的隧道通过私有管道连接生命周期守护进程。应用崩溃或被强制结束会关闭管道，守护进程随即终止自己的 SSH 子进程。启动恢复只会自动选择已被 PID 1 接管、同时精确匹配本应用 ControlMaster 参数与 `/tmp/spt-*.sock` 格式的 `/usr/bin/ssh`；普通 SSH 会话不会被选中。

## SSH 信任

新主机密钥使用 OpenSSH 的 `accept-new` 行为，发生变化的主机密钥仍会被拒绝。首次连接新主机时，用户应通过可信渠道核对 fingerprint。
