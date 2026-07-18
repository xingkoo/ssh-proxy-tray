# Security

[English](SECURITY.md) | [简体中文](SECURITY.zh-CN.md)

## Reporting

Please report credential exposure, command injection, host-key validation, or local port exposure issues privately through GitHub Security Advisories.

## Credential Handling

- Passwords are never command-line arguments and are never logged.
- Unsaved passwords remain in app memory and are delivered to OpenSSH through a token-protected loopback helper.
- Saved passwords use macOS Keychain.
- Tunnel configuration is stored with user-only file permissions and contains no password.
- Local listeners are restricted to `127.0.0.1` or `localhost`.
- The optional HTTP/HTTPS endpoint is a loopback-only local adapter over the rule's SOCKS5 tunnel. It does not open another SSH connection.
- The HTTP adapter caps request headers at 64 KiB, bounds initial parsing and SOCKS handshakes to 15 seconds, strips proxy credentials, and forces ordinary HTTP requests to close their upstream connection so it cannot be reused for another destination. It does not provide proxy authentication because it is never exposed beyond loopback.
- Remote-forward listeners default to `127.0.0.1`. Binding a remote rule to `0.0.0.0` can expose the local target through the SSH server and also requires compatible server-side `GatewayPorts` policy.
- Remote-listener inspection reuses the active authenticated OpenSSH ControlMaster socket. Control sockets use short, per-connection paths under `/tmp` and are removed when the tunnel stops.
- Automatic `GatewayPorts` configuration is never silent. It requires an explicit warning confirmation and passwordless `sudo`, writes only a dedicated sshd drop-in, validates with `sshd -t`, reloads rather than restarts SSH, and restores the previous file if validation or reload fails.
- `GatewayPorts clientspecified` is server-wide and can allow other authorized SSH users to request non-loopback remote listeners. Firewall rules and `PermitListen` remain the server administrator's responsibility.

## SSH Trust

New host keys use OpenSSH's `accept-new` behavior. Changed host keys are rejected. Users should verify new host fingerprints through a trusted channel when connecting to a host for the first time.
