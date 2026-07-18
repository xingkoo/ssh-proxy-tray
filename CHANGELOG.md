# Changelog

[English](CHANGELOG.md) | [简体中文](CHANGELOG.zh-CN.md)

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
