# Repository Agent Rules

This repository contains the SSH Proxy Tray macOS application.

## Read First

1. `README.md`
2. `Package.swift`
3. `Sources/SSHProxyCore/`
4. Relevant tests in `Tests/SSHProxyCoreTests/`

## Boundaries

- Keep the first release macOS-only and dependency-free.
- Never pass passwords as command-line arguments, log them, or write unsaved passwords to disk.
- Build SSH invocations as argument arrays; never construct shell commands from profile values.
- Keep transport-specific process behavior behind a small boundary so a Windows backend can be added later.
- `SOCKS5` means OpenSSH dynamic forwarding (`-D`). HTTP/HTTPS mode only forwards a remote proxy service (`-L`); it does not implement an HTTP proxy server.
- Use `/usr/bin/ssh` on macOS and preserve strict host-key change detection.
- Add or update tests when changing validation, persistence, or SSH arguments.

## Verification

```bash
swift test
./scripts/build-app.sh
```
