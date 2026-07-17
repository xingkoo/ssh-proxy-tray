import Foundation

public enum SSHArgumentsBuilder {
    public static func arguments(for profile: TunnelProfile) -> [String] {
        var arguments = [
            "-N",
            "-T",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new"
        ]

        switch profile.mode {
        case .socks5:
            arguments += ["-D", "\(profile.localHost):\(profile.localPort)"]
        case .remoteProxy:
            arguments += [
                "-L",
                "\(profile.localHost):\(profile.localPort):\(profile.remoteHost):\(profile.remotePort)"
            ]
        }

        switch profile.authentication {
        case .sshConfig:
            arguments += ["-o", "BatchMode=yes"]
            arguments.append(profile.sshHost)
        case .keyFile:
            let path = NSString(string: profile.identityFile).expandingTildeInPath
            arguments += [
                "-o", "BatchMode=yes",
                "-o", "IdentitiesOnly=yes",
                "-i", path,
                "-p", String(profile.sshPort),
                "\(profile.username)@\(profile.sshHost)"
            ]
        case .password:
            arguments += [
                "-o", "PubkeyAuthentication=no",
                "-o", "PreferredAuthentications=password,keyboard-interactive",
                "-p", String(profile.sshPort),
                "\(profile.username)@\(profile.sshHost)"
            ]
        }

        return arguments
    }
}
