# SSH Proxy Tray

[简体中文](README.md) | [English](README.en.md)

[![CI](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml/badge.svg)](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/xingkoo/ssh-proxy-tray)](https://github.com/xingkoo/ssh-proxy-tray/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://www.apple.com/macos/)

SSH Proxy Tray 是一个轻量、原生的 macOS SSH 代理与端口转发工具。它使用 macOS 自带的 OpenSSH，通过独立管理窗口同时运行多个 SOCKS 代理、本地转发和远程转发规则；状态栏图标只负责常驻状态与快速打开。

适合以下场景：

- 临时使用 SSH 主机作为 SOCKS5 代理，不安装专用代理客户端。
- 已有系统代理，但某个应用需要独立的代理出口或端口。
- 把 SSH 服务器可访问的服务映射到本机端口。
- 通过 SSH 服务器上的远程端口访问本机服务。

## 核心功能

- 原生 SwiftUI macOS 应用，运行时无第三方依赖。
- 中英文界面，自动跟随 macOS 首选语言。
- 规则类型、连接状态、转发方向、地址、端口和高级 SSH 参数均提供中英文就地帮助。
- 多条规则并发运行，每条规则独立启用、连接、断开和记录状态。
- 清晰显示未连接、正在连接、已连接、正在断开和连接失败。
- 支持 `~/.ssh/config` Host alias 及一键导入具体 Host。
- 支持私钥、OpenSSH certificate、用户名密码和可选钥匙串保存。
- 支持 ProxyJump、压缩、连接超时和 SSH keepalive 参数。
- 显式配置监听端口；新规则从 `18080` 起选择可用端口。
- 启动前检测本地端口冲突。
- 支持登录时启动和每条规则的自动连接。
- 不修改 macOS 系统代理、PAC 或 VPN 设置。

## 转发类型

| 类型 | OpenSSH 参数 | 作用 |
| --- | --- | --- |
| SOCKS 代理 | `ssh -D` | 在本机创建 SOCKS5 代理，不要求服务器运行代理服务 |
| 本地转发 | `ssh -L` | 通过本机端口访问 SSH 服务器可达的远端服务 |
| 远程转发 | `ssh -R` | 通过 SSH 服务器上的端口访问本机服务 |

所有本地监听只允许绑定 `127.0.0.1` 或 `localhost`。远程转发默认绑定远端 loopback；主动改成 `0.0.0.0` 可能暴露本机服务，并依赖服务器的 `GatewayPorts` 配置。

## 系统要求

- macOS 13 或更高版本。
- 从源码构建需要 Xcode 15.3 或更高版本。
- 可访问且允许 TCP forwarding 的 SSH 服务器。

## 构建与安装

```bash
swift test
./scripts/build-app.sh
./scripts/install.sh
```

安装时启用登录启动：

```bash
./scripts/install.sh --launch-at-login
```

应用安装到 `/Applications/SSH Proxy Tray.app`。本地构建使用 ad-hoc 签名；公开分发已签名二进制仍需要 Apple Developer ID 和 notarization，当前 GitHub Release 以源码发布为主。

## 界面配置

点击状态栏图标打开独立管理窗口，添加规则并选择认证方式：

- **SSH 配置**：使用 `~/.ssh/config` 中的 alias，例如 `my-server`。
- **密钥 / 证书**：填写主机、用户名、端口、私钥路径和可选 OpenSSH certificate。
- **密码**：连接时输入；只有主动启用“将密码保存到钥匙串”才会持久保存。

每条规则都可以单独设置端口、启用状态、自动连接，并可手工连接或断开。

界面中的问号按钮会结合当前规则类型解释数据流和典型场景。将鼠标停留在地址、端口和高级参数上，可以查看该字段的用途和安全边界。帮助在规则已经连接、配置字段被锁定时仍然可用。

## CLI 配置

构建产物包含 `ssh-proxy-trayctl`，便于复现本地配置：

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "My SOCKS" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode socks5 \
  --local-port 18080 \
  --auto-connect
```

本地转发：

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "Local Forward" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode localForward \
  --local-port 8080 \
  --remote-host 127.0.0.1 \
  --remote-port 3128
```

远程转发：

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "Remote Forward" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode remoteForward \
  --local-port 3000 \
  --remote-host 127.0.0.1 \
  --remote-port 23000
```

## 使用 SOCKS 代理

将目标应用的代理地址设置为：

```text
socks5://127.0.0.1:18080
```

命令行需要通过 SOCKS 解析 DNS 时使用 `socks5h`：

```bash
curl --proxy socks5h://127.0.0.1:18080 https://example.com
```

## 安全边界

- SSH 参数以数组直接传给 `/usr/bin/ssh`，不经过 shell 拼接。
- 未保存密码只短暂存在于应用内存，并通过随机令牌保护的 loopback askpass 通道交给 OpenSSH。
- 保存的密码进入 macOS 钥匙串；profile 文件不保存密码并使用 `0600` 权限。
- 新主机密钥使用 OpenSSH `accept-new`；已变化的主机密钥仍会被拒绝。
- 应用不会自动扩大本地或远程监听地址。

安全问题请参阅 [SECURITY.md](SECURITY.md)。

## Windows 路线

profile、校验和 SSH 参数模型已经与 macOS UI 分离。未来 Windows 版本可以复用这些语义，再独立选择 Windows OpenSSH 或经过审计的内置 SSH backend；当前版本不提前实现 Windows。

## 许可证

[MIT](LICENSE)
