# SSH Proxy Tray

SSH Proxy Tray is a small native macOS app for running proxy and port-forwarding rules through SSH. A persistent status icon opens a dedicated connection-management window. The app uses the OpenSSH client already included with macOS.

## Modes

- **SOCKS Proxy**: creates a local SOCKS5 proxy with OpenSSH dynamic forwarding (`ssh -D`). No proxy service is required on the server.
- **Local Forward**: exposes a service reachable from the SSH server on a local TCP port (`ssh -L`). A remote HTTP/HTTPS proxy is one use of this general rule.
- **Remote Forward**: exposes a local service through a TCP port on the SSH server (`ssh -R`).

All local listeners bind to loopback only.

## Features

- A status icon that directly opens a separate management window
- Multiple concurrent rules with independent enabled and runtime states
- Manual connect and disconnect per rule
- SSH config aliases
- Import from `~/.ssh/config`
- Private key file paths
- Optional OpenSSH certificate files
- Password prompt with optional macOS Keychain storage
- ProxyJump, compression, connect timeout, and keepalive settings
- Auto-connect per profile
- Launch at login
- Copyable proxy or forwarding endpoint
- Local port conflict detection
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

Choose the menu bar icon to open the management window, add a rule, and select an authentication mode:

- **SSH Config** uses an alias such as `my-server` from `~/.ssh/config`.
- **Key / Certificate** uses an explicit host, user, port, private key, and optional OpenSSH certificate path.
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

For a service reachable from the SSH server at `127.0.0.1:3128`:

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

To expose a local service on port 3000 through remote port 23000:

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
- Remote-forward listeners default to remote loopback; changing the bind address can expose the local service through the SSH server.
- Profile files are created with mode `0600`.

See [SECURITY.md](SECURITY.md) for reporting and credential details.

## Windows roadmap

The profile, validation, and SSH argument model is isolated from the macOS UI. A future Windows build can provide a tray UI and select either the Windows OpenSSH client or a bundled, audited SSH backend without changing profile semantics.

## License

MIT
