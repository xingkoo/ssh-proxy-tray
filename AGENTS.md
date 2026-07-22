# Repository Agent Rules

This repository contains the SSH Proxy Tray macOS application.

This is a public code repository in the Open Source Project. Project plans, status, and decisions live in the project-management repository two levels above. If the local ignored company-rules/ directory exists, read company-rules/core.md and company-rules/code-repository.md before this file.

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
- `Proxy`, `Local Forward`, and `Remote Forward` map to OpenSSH `-D`, `-L`, and `-R` respectively.
- A Proxy rule may expose both SOCKS5 and HTTP/HTTPS endpoints. Keep one `ssh -D` process and route the loopback-only HTTP listener through that SOCKS endpoint; never open a second SSH process for HTTP.
- The local HTTP adapter must support HTTPS CONNECT and ordinary HTTP absolute-form requests, cap request headers, strip proxy credentials before forwarding, use a bounded handshake, and remain covered by parser/encoder tests.
- Remote forwarding can expose a local service through the SSH server. Preserve explicit bind-address fields and never silently widen them to `0.0.0.0`.
- Inspect the actual remote listener through the active OpenSSH control connection after a Remote Forward connects; do not treat `ExitOnForwardFailure` as proof that a requested public bind was honored.
- Never change remote sshd policy silently. Automatic `GatewayPorts clientspecified` configuration requires an explicit warning confirmation, passwordless sudo, a dedicated drop-in backup, `sshd -t`, reload instead of restart, rollback on failure, in-place forward refresh, and post-change inspection.
- Disabling external access changes only the profile bind address. Never automatically revert server-wide `GatewayPorts`, which may be shared by other users and rules.
- App termination must wait for every managed SSH runner to close its ControlMaster and exit; force-stop fallbacks may target only app-owned SSH child processes.
- Every packaged SSH process must run through `SSHProcessGuard`, whose owner pipe closes on crashes or forced termination. Startup orphan recovery may terminate only reparented `/usr/bin/ssh` processes that exactly match this app's ControlMaster arguments and `/tmp/spt-*.sock` format.
- Local port inspection must use fixed-argument structured process APIs. Process termination requires explicit confirmation, uses SIGTERM, and must reject PID 1 and the running app process.
- Every user-facing app string must use a stable localization key with matching `en` and `zh-Hans` values. Persisted profile values and SSH arguments must remain language-independent.
- Ambiguous networking concepts must provide localized contextual help that states the direction, a concrete use case, and any exposure boundary. Help must remain accessible while a running rule locks editable fields.
- Keep `README.md` as the complete Simplified Chinese entry and `README.en.md` as the complete English entry. Update both when behavior or setup changes; do not leave one as a summary of the other.
- Keep localized Security and Changelog documents synchronized when their shared facts change.
- Use `/usr/bin/ssh` on macOS and preserve strict host-key change detection.
- Add or update tests when changing validation, persistence, or SSH arguments.

## Verification

```bash
swift test
./scripts/build-app.sh
plutil -lint Resources/en.lproj/Localizable.strings Resources/zh-Hans.lproj/Localizable.strings
```
