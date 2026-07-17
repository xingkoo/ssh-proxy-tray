# SSH Proxy Tray

SSH Proxy Tray is a small native macOS menu bar app for creating local proxy ports through SSH. It uses the OpenSSH client already included with macOS.

## Modes

- **SOCKS5**: creates a local SOCKS5 proxy with OpenSSH dynamic forwarding (`ssh -D`). No proxy service is required on the server.
- **HTTP/HTTPS Proxy**: forwards a local TCP port to an HTTP/HTTPS proxy service already running on the remote host (`ssh -L`). The app does not implement an HTTP proxy server.

All local listeners bind to loopback only.

## Features

- macOS menu bar controls and connection status
- Multiple tunnel profiles
- SSH config aliases
- Private key file paths
- Password prompt with optional macOS Keychain storage
- Auto-connect per profile
- Launch at login
- Copyable proxy URL
- No runtime dependencies or embedded SSH implementation

## Requirements

- macOS 13 or newer
- Xcode 15.3 or newer to build from source
- A reachable SSH server with TCP forwarding enabled

## Build and install

```bash
swift test
./scripts/build-app.sh
./scripts/install.sh
```

To enable launch at login during local installation:

```bash
./scripts/install.sh --launch-at-login
```

The local build is ad-hoc signed and installed as `/Applications/SSH Proxy Tray.app`. Public binary distribution requires Apple Developer ID signing and notarization; source builds do not.

## Configure from the UI

Choose the menu bar icon, open **Settings**, add a tunnel, and select an authentication mode:

- **SSH Config** uses an alias such as `my-server` from `~/.ssh/config`.
- **Key File** uses an explicit host, user, port, and private key path.
- **Password** asks at connection time. Enable **Save password in Keychain** only when desired.

## Configure from the CLI

The build includes `ssh-proxy-trayctl` for reproducible local setup:

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "My SOCKS" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode socks5 \
  --local-port 1080 \
  --auto-connect
```

For a remote HTTP proxy running at `127.0.0.1:3128`:

```bash
.build/release/ssh-proxy-trayctl upsert \
  --name "Remote HTTP Proxy" \
  --ssh-host my-server \
  --auth sshConfig \
  --mode remoteProxy \
  --local-port 8080 \
  --remote-host 127.0.0.1 \
  --remote-port 3128
```

## Use the proxy

Configure the target application with the URL shown in the tray, for example:

```text
socks5://127.0.0.1:1080
```

For command-line DNS resolution through SOCKS, use the `socks5h` scheme:

```bash
curl --proxy socks5h://127.0.0.1:1080 https://example.com
```

## Security model

- OpenSSH arguments are passed directly without a shell.
- Unsaved passwords are kept in memory and passed through a short-lived, token-protected loopback channel to the askpass helper.
- Saved passwords are stored in macOS Keychain.
- New host keys are accepted once; changed keys remain blocked by OpenSSH.
- Profile files are created with mode `0600`.

See [SECURITY.md](SECURITY.md) for reporting and credential details.

## Windows roadmap

The profile, validation, and SSH argument model is isolated from the macOS UI. A future Windows build can provide a tray UI and select either the Windows OpenSSH client or a bundled, audited SSH backend without changing profile semantics.

## License

MIT
