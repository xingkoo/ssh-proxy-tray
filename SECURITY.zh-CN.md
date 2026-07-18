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

## SSH 信任

新主机密钥使用 OpenSSH 的 `accept-new` 行为，发生变化的主机密钥仍会被拒绝。首次连接新主机时，用户应通过可信渠道核对 fingerprint。
