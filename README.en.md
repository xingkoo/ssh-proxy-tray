# SSH Proxy Tray

[简体中文](README.md) | [English](README.en.md)

[![CI](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml/badge.svg)](https://github.com/xingkoo/ssh-proxy-tray/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/xingkoo/ssh-proxy-tray)](https://github.com/xingkoo/ssh-proxy-tray/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://www.apple.com/macos/)

SSH Proxy Tray is a lightweight native macOS app for SSH proxies and port forwarding. It uses the OpenSSH client included with macOS and runs multiple SOCKS proxy, local-forward, and remote-forward rules from a dedicated management window. The status icon is only a persistent status and quick-open entry point.

Typical uses include:

- Temporarily using an SSH host as a SOCKS5 proxy without a dedicated proxy client.
- Giving one application a separate proxy endpoint while another system proxy remains active.
- Mapping a service reachable from the SSH server to a local port.
- Accessing a local service through a remote port on the SSH server.

## Features

- Native SwiftUI macOS app with no third-party runtime dependencies.
- English and Simplified Chinese UI, following the preferred macOS language.
- Bilingual contextual help for rule types, connection state, forwarding direction, addresses, ports, and advanced SSH options.
- Multiple concurrent rules with independent enabled and runtime states.
- Clear Disconnected, Connecting, Connected, Disconnecting, and Failed states.
- `~/.ssh/config` aliases and import of concrete Host entries.
- Private keys, optional OpenSSH certificates, passwords, and optional Keychain storage.
- ProxyJump, compression, connect timeout, and SSH keepalive settings.
- Explicit port configuration; new rules choose an available port starting at `18080`.
- Local port conflict detection before SSH starts.
- Launch at login and per-rule auto-connect.
- Never changes the macOS system proxy, PAC, or VPN configuration.

## Forwarding modes

| Mode | OpenSSH option | Purpose |
| --- | --- | --- |
| SOCKS Proxy | `ssh -D` | Creates a local SOCKS5 proxy without requiring a proxy service on the server |
| Local Forward | `ssh -L` | Exposes a service reachable from the SSH server on a local TCP port |
| Remote Forward | `ssh -R` | Exposes a local service through a TCP port on the SSH server |

All local listeners are restricted to `127.0.0.1` or `localhost`. Remote forwards bind to remote loopback by default. Changing the bind address to `0.0.0.0` may expose the local service and requires compatible server-side `GatewayPorts` policy.

## Requirements

- macOS 13 or newer.
- Xcode 15.3 or newer to build from source.
- A reachable SSH server with TCP forwarding enabled.

## Build and install

```bash
swift test
./scripts/build-app.sh
./scripts/install.sh
```

Enable launch at login during local installation:

```bash
./scripts/install.sh --launch-at-login
```

The app is installed as `/Applications/SSH Proxy Tray.app`. Local builds are ad-hoc signed. Public signed binary distribution still requires an Apple Developer ID and notarization, so current GitHub releases primarily distribute source code.

## Configure from the UI

Click the status icon to open the dedicated management window, add a rule, and choose an authentication method:

- **SSH Config** uses an alias such as `my-server` from `~/.ssh/config`.
- **Key / Certificate** uses an explicit host, user, port, private key, and optional OpenSSH certificate.
- **Password** asks at connection time and is persisted only when **Save password in Keychain** is enabled.

Each rule has its own port, enabled state, auto-connect setting, and manual Connect or Disconnect action.

Question-mark buttons explain the selected rule's data flow and typical use case. Hover over address, port, and advanced SSH fields for field-specific purpose and security guidance. Help remains available while a connected rule locks its editable fields.

## Configure from the CLI

The build includes `ssh-proxy-trayctl` for reproducible local setup:

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "My SOCKS" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode socks5 \
  --local-port 18080 \
  --auto-connect
```

Local forward:

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

Remote forward:

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

## Use the SOCKS proxy

Configure the target application with an endpoint such as:

```text
socks5://127.0.0.1:18080
```

Use `socks5h` for command-line DNS resolution through SOCKS:

```bash
curl --proxy socks5h://127.0.0.1:18080 https://example.com
```

## Security model

- SSH arguments are passed directly to `/usr/bin/ssh` as an array, without a shell.
- Unsaved passwords stay briefly in app memory and reach OpenSSH through a token-protected loopback askpass channel.
- Saved passwords use macOS Keychain; profile files never contain passwords and use `0600` permissions.
- New host keys use OpenSSH `accept-new`; changed host keys remain blocked.
- The app never silently widens a local or remote bind address.

See [SECURITY.md](SECURITY.md) for reporting and credential details.

## Windows roadmap

The profile, validation, and SSH argument model is isolated from the macOS UI. A future Windows build can reuse these semantics and separately select Windows OpenSSH or an audited bundled SSH backend. Windows is not implemented in the current version.

## License

[MIT](LICENSE)
