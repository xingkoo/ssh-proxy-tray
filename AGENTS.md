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
- Keep each saved rule independently enabled and independently connectable; never collapse runtime state into one global SSH process.
- `SOCKS Proxy`, `Local Forward`, and `Remote Forward` map to OpenSSH `-D`, `-L`, and `-R` respectively.
- Remote forwarding can expose a local service through the SSH server. Preserve explicit bind-address fields and never silently widen them to `0.0.0.0`.
- Use `/usr/bin/ssh` on macOS and preserve strict host-key change detection.
- Add or update tests when changing validation, persistence, or SSH arguments.

## Verification

```bash
swift test
./scripts/build-app.sh
```
