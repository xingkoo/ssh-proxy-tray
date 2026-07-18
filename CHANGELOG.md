# Changelog

[English](CHANGELOG.md) | [简体中文](CHANGELOG.zh-CN.md)

## 0.8.0 - 2026-07-19

- Rebuild the window shell as a consumer-style desktop workspace instead of a traditional settings form.
- Add a light navigation rail with floating rule rows, a brand mark, and calmer utility controls.
- Replace the system split view, segmented controls, and default text-field appearance with a custom content header, mode selector, access selector, authentication menu, and soft input surfaces.
- Extend the content beneath the title bar for a cleaner macOS window and keep locked fields readable while a tunnel is running.

## 0.7.0 - 2026-07-19

- Refresh the macOS management window with a dark navigation rail, bright workspace, clearer status badges, and grouped configuration panels.
- Add a stronger visual hierarchy for connection paths, rule modes, enabled state, and the primary Connect / Disconnect action.
- Use a larger default window and consistent rounded input controls for a calmer, more spacious editing experience.
- Keep the proxy, forwarding, localization, credential, and remote-listener behavior unchanged.

## 0.6.0 - 2026-07-18

- Redesign the management window around rule status, connection paths, compact settings sections, and clearer actions.
- Replace the raw Remote Forward bind field with server-only, external-device, and custom access choices.
- Inspect the server's actual remote listener through the active authenticated OpenSSH ControlMaster session.
- Distinguish confirmed loopback, confirmed external, missing, checking, and unsupported listener states.
- Add explicitly confirmed `GatewayPorts clientspecified` configuration for supported systemd/OpenSSH servers, with backup, `sshd -t`, reload, rollback, in-place forward refresh, and verification.
- Document Gatekeeper warnings for ad-hoc builds, checksum verification, the trusted-source quarantine workaround, and the Developer ID/notarization long-term solution.
- Add acknowledgements for OpenAI ChatGPT's end-to-end development assistance and ZhaoYang1's compute support.
- Keep complete English and Simplified Chinese UI, README, Security, and Changelog coverage.

## 0.5.0 - 2026-07-18

- Let one Proxy rule expose SOCKS5 and optional HTTP/HTTPS endpoints through a single `ssh -D` connection.
- Add a loopback-only local HTTP-to-SOCKS adapter supporting HTTPS CONNECT and ordinary HTTP proxy requests.
- Add separate SOCKS and HTTP port configuration, conflict validation, endpoint summaries, and copy actions.
- Preserve backward compatibility: existing profiles remain SOCKS-only until HTTP is explicitly enabled; new Proxy rules enable both endpoints by default.
- Add bounded HTTP headers and handshakes, proxy credential stripping, parser/encoder tests, and bilingual UI/security documentation.

## 0.4.0 - 2026-07-18

- Add bilingual contextual help for availability versus connection state, rule types, authentication, forwarding, and advanced SSH options.
- Explain SOCKS, local-forward, and remote-forward data flow with concrete use cases and direction-specific examples.
- Add field-level tooltips for bind addresses, listen ports, destination/target fields, ProxyJump, compression, timeout, and keepalive values.
- Keep help buttons available while connected rules lock their editable fields.

## 0.3.0 - 2026-07-18

- Add complete English and Simplified Chinese app localization that follows the preferred macOS language.
- Localize connection states, controls, forms, validation, and runtime errors without changing persisted profile values.
- Add complete Chinese and English README documents plus localized security and changelog documentation.
- Improve GitHub discoverability with bilingual repository metadata, badges, search-oriented topics, and bilingual release notes.

## 0.2.0 - 2026-07-18

- Replace the menu bar popover with a dedicated connection-management window opened directly by the status icon.
- Run multiple rules concurrently with independent enabled and runtime states.
- Add manual connect and disconnect controls per rule.
- Add SOCKS proxy, local forwarding, and remote forwarding rule types.
- Import concrete host aliases from `~/.ssh/config`.
- Add SSH certificate, ProxyJump, compression, timeout, and keepalive settings.
- Use port 18080 as the default for new profiles instead of the commonly occupied port 1080.
- Detect occupied local ports before starting SSH and show a clear error.

## 0.1.0 - 2026-07-17

- Add native macOS menu bar app.
- Add SSH config alias, private key, and optional Keychain-backed password authentication.
- Add SOCKS5 dynamic forwarding and remote HTTP/HTTPS proxy port forwarding.
- Add automatic connection and launch-at-login settings.
- Add profile CLI, local app packaging, and tests.
