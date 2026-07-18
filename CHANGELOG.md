# Changelog

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
