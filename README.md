# SSH Proxy Tray

[简体中文](README.md) | [English](README.en.md)

[![CI](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml/badge.svg)](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/xingkoo/ssh-proxy-tray)](https://github.com/xingkoo/ssh-proxy-tray/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://www.apple.com/macos/)

SSH Proxy Tray 是一个轻量、原生的 macOS SSH 代理与端口转发工具。它使用 macOS 自带的 OpenSSH，通过独立管理窗口同时运行多个代理、本地转发和远程转发规则；一个代理规则可以用同一条 SSH 隧道同时提供 SOCKS5 与 HTTP/HTTPS 两个本地端点。状态栏图标只负责常驻状态与快速打开。

适合以下场景：

- 临时使用 SSH 主机作为 SOCKS5 或 HTTP/HTTPS 代理，不安装专用代理客户端。
- 已有系统代理，但某个应用需要独立的代理出口或端口。
- 把 SSH 服务器可访问的服务映射到本机端口。
- 通过 SSH 服务器上的远程端口访问本机服务。

## 核心功能

- 原生 SwiftUI macOS 应用，运行时无第三方依赖。
- 消费级桌面管理窗口：浅色规则导航侧栏、悬浮规则项、明亮配置工作区、状态胶囊和自定义圆角控件。
- 中英文界面，可在应用内选择“跟随系统 / 简体中文 / English”，无需重启即可切换。
- 规则类型、连接状态、转发方向、地址、端口和高级 SSH 参数均提供中英文就地帮助。
- 多条规则并发运行，每条规则独立启用、连接、断开和记录状态。
- 一个代理规则、一条 `ssh -D` 连接，同时提供独立可配置的 SOCKS5 与 HTTP/HTTPS 端口。
- 清晰显示未连接、正在连接、已连接、正在断开和连接失败。
- 远程转发连接后检查服务器实际监听地址，区分“仅服务器本机”和“外部监听”。
- 经用户明确确认后，可在支持的 systemd/OpenSSH 服务器上备份、校验并配置 `GatewayPorts clientspecified`。
- 支持 `~/.ssh/config` Host alias 及一键导入具体 Host。
- 支持私钥、OpenSSH certificate、用户名密码和可选钥匙串保存。
- 支持 ProxyJump、压缩、连接超时和 SSH keepalive 参数。
- 显式配置监听端口；新规则从 `18080` 起选择可用端口。
- 自动检查配置的本地端口，显示监听进程名和 PID；经确认后可向外部占用进程发送 SIGTERM。
- 退出应用时等待所有受管 SSH 连接和 ControlMaster 完整关闭，避免遗留进程继续占用端口。
- 应用崩溃或被强制结束时，独立生命周期守护进程会关闭对应 SSH；下次启动还会严格识别并回收旧版本遗留的孤儿隧道，避免远端转发端口持续占用。
- 支持登录时启动和每条规则的自动连接。
- 不修改 macOS 系统代理、PAC 或 VPN 设置。

## 转发类型

| 类型 | OpenSSH 参数 | 作用 |
| --- | --- | --- |
| 代理 | `ssh -D` + 本机适配器 | 一条 SSH 隧道提供 SOCKS5 端点，并可选提供 HTTP/HTTPS 端点 |
| 本地转发 | `ssh -L` | 通过本机端口访问 SSH 服务器可达的远端服务 |
| 远程转发 | `ssh -R` | 通过 SSH 服务器上的端口访问本机服务 |

所有本地监听只允许绑定 `127.0.0.1` 或 `localhost`。远程转发默认绑定远端 loopback；主动改成 `0.0.0.0` 可能暴露本机服务，并依赖服务器的 `GatewayPorts` 配置。

HTTP 与 SOCKS 是不同协议，不能共用同一个本地端口。启用 HTTP/HTTPS 后会出现第二个本地端口，但它只是本机协议适配器；底层仍只有一条 `ssh -D` 连接：

```text
SOCKS 应用 -> SOCKS 端口 ───────────────┐
                                         ├-> 同一条 SSH 隧道 -> 目标网络
HTTP/HTTPS 应用 -> HTTP 端口 -> 本机适配 ┘
```

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

应用安装到 `/Applications/SSH Proxy Tray.app`。本地与当前 GitHub 二进制包使用 ad-hoc 签名；彻底消除 Gatekeeper 警告仍需要 Apple Developer ID 签名和 Apple notarization。

### 下载的应用提示“已损坏”或无法验证

macOS 会为浏览器下载的文件添加 quarantine 属性。未经过 Apple notarization 的 ad-hoc 签名应用可能被提示“已损坏”“无法打开”或“无法验证开发者”。优先从源码构建；使用打包版本时，只从本仓库的官方 GitHub Release 下载，并先核对同一 Release 提供的 `SHA256SUMS`。

将应用移动到 `/Applications` 后，可以先在 Finder 中右键应用并选择“打开”。如果仍被提示损坏，并且已经确认文件来自官方 Release，再执行：

```bash
codesign --verify --deep --strict "/Applications/SSH Proxy Tray.app"
xattr -dr com.apple.quarantine "/Applications/SSH Proxy Tray.app"
open "/Applications/SSH Proxy Tray.app"
```

`xattr` 会移除该应用的下载隔离标记，相当于绕过本次 Gatekeeper 来源检查。不要对来源不明的应用执行。长期正式分发方案仍是 Developer ID 签名、notarization 和 stapling，而不是要求所有用户关闭系统安全功能。

## 界面配置

点击状态栏图标打开独立管理窗口，添加规则并选择认证方式：

- **SSH 配置**：使用 `~/.ssh/config` 中的 alias，例如 `my-server`。
- **密钥 / 证书**：填写主机、用户名、端口、私钥路径和可选 OpenSSH certificate。
- **密码**：连接时输入；只有主动启用“将密码保存到钥匙串”才会持久保存。

每条规则都可以单独设置端口、启用状态、自动连接，并可手工连接或断开。

“本地端口检查”会列出每个配置端口的监听进程和 PID。终止操作必须经过确认，只发送 SIGTERM；应用不会提供终止 PID 1 或自身进程的操作。远程转发中的本地端口是这台 Mac 上的目标服务端口，显示监听进程属于正常情况。

代理规则始终提供 SOCKS5 端口；启用“同时提供 HTTP/HTTPS 代理”后，再配置一个 HTTP 端口。顶部复制菜单可以分别复制 `socks5://...` 和 `http://...` 端点。

详情顶部直接显示当前规则的数据流，远程转发使用“仅 SSH 服务器 / 外部设备 / 自定义地址”选择访问范围。问号按钮继续说明典型场景和安全边界；帮助与远程监听状态在规则已经连接、配置字段被锁定时仍然可用。

### 远程监听检查与服务器配置

远程转发连接后，应用会通过同一条已认证的 OpenSSH ControlMaster 会话读取服务器实际监听结果，不会建立第二次登录：

- 请求 `127.0.0.1` 且服务器只监听 loopback：显示“已确认仅服务器本机监听”。
- 请求 `0.0.0.0` 且服务器实际公开监听：显示“已确认外部监听”。
- 请求 `0.0.0.0` 但服务器仍只监听 `127.0.0.1`：明确提示 `GatewayPorts` 限制。

检测到限制时，用户可以明确确认“一键配置服务器”。该操作只支持具有免密码 `sudo`、使用 systemd、加载 `/etc/ssh/sshd_config.d/*.conf` 的 OpenSSH 服务器。应用会备份目标配置、写入 `GatewayPorts clientspecified`、执行 `sshd -t`、reload SSH 服务，然后通过 control command 原地刷新当前 `-R` 转发并复验。校验或 reload 失败会恢复原配置。

这是服务器级安全策略，可能影响其他 SSH 用户，因此应用不会静默执行，也不会在关闭某条规则时自动撤销。确认外部监听只代表 sshd 已绑定相应地址；云安全组、系统防火墙和服务自身认证仍需单独配置。

## CLI 配置

构建产物包含 `ssh-proxy-trayctl`，便于复现本地配置：

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "My SOCKS" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode socks5 \
  --local-port 18080 \
  --http-proxy-port 18081 \
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

## 使用代理

将目标应用的代理地址设置为：

```text
socks5://127.0.0.1:18080
```

命令行需要通过 SOCKS 解析 DNS 时使用 `socks5h`：

```bash
curl --proxy socks5h://127.0.0.1:18080 https://example.com
```

HTTP 代理端点可以同时处理普通 HTTP 请求和 HTTPS CONNECT：

```text
http://127.0.0.1:18081
```

```bash
curl --proxy http://127.0.0.1:18081 http://example.com
curl --proxy http://127.0.0.1:18081 https://example.com
```

## 安全边界

- SSH 参数以数组直接传给 `/usr/bin/ssh`，不经过 shell 拼接。
- 未保存密码只短暂存在于应用内存，并通过随机令牌保护的 loopback askpass 通道交给 OpenSSH。
- 保存的密码进入 macOS 钥匙串；profile 文件不保存密码并使用 `0600` 权限。
- 新主机密钥使用 OpenSSH `accept-new`；已变化的主机密钥仍会被拒绝。
- HTTP/HTTPS 适配器只监听 loopback，限制请求头和初始握手时间，并在转发前移除代理凭证头。
- 应用不会静默扩大本地或远程监听地址；服务器级 `GatewayPorts` 修改必须由用户在警告中明确确认。

安全问题请参阅 [SECURITY.md](SECURITY.md)。

## Windows 路线

profile、校验和 SSH 参数模型已经与 macOS UI 分离。未来 Windows 版本可以复用这些语义，再独立选择 Windows OpenSSH 或经过审计的内置 SSH backend；当前版本不提前实现 Windows。

## 致谢

特别感谢 **OpenAI ChatGPT**。本项目从产品讨论、交互与架构设计，到代码实现、测试、双语文档和开源发布，全程由 ChatGPT 协助完成。

特别感谢 LinuxDo 佬友 [**ZhaoYang1**](https://linux.do/u/zhaoyang1) **提供的算力支持。**

## 许可证

[MIT](LICENSE)
