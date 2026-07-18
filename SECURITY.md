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
- Remote-forward listeners default to `127.0.0.1`. Binding a remote rule to `0.0.0.0` can expose the local target through the SSH server and also requires compatible server-side `GatewayPorts` policy.

## SSH Trust

New host keys use OpenSSH's `accept-new` behavior. Changed host keys are rejected. Users should verify new host fingerprints through a trusted channel when connecting to a host for the first time.
