import Foundation

public enum SSHArgumentsBuilder {
    public static func arguments(for profile: TunnelProfile) -> [String] {
        var arguments = [
            "-N",
            "-T",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=\(profile.serverAliveInterval ?? 30)",
            "-o", "ServerAliveCountMax=\(profile.serverAliveCountMax ?? 3)",
            "-o", "ConnectTimeout=\(profile.connectTimeout ?? 10)",
            "-o", "StrictHostKeyChecking=accept-new"
        ]

        if profile.compression == true {
            arguments.append("-C")
        }
        if let proxyJump = profile.proxyJump?.trimmingCharacters(in: .whitespacesAndNewlines),
           !proxyJump.isEmpty {
            arguments += ["-J", proxyJump]
        }

        switch profile.mode {
        case .socks5:
            arguments += ["-D", "\(profile.localHost):\(profile.localPort)"]
        case .localForward:
            arguments += [
                "-L",
                "\(profile.localHost):\(profile.localPort):\(profile.remoteHost):\(profile.remotePort)"
            ]
        case .remoteForward:
            arguments += [
                "-R",
                "\(profile.remoteHost):\(profile.remotePort):\(profile.localHost):\(profile.localPort)"
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
                "-p", String(profile.sshPort)
            ]
            if let certificateFile = profile.certificateFile?.trimmingCharacters(in: .whitespacesAndNewlines),
               !certificateFile.isEmpty {
                let certificatePath = NSString(string: certificateFile).expandingTildeInPath
                arguments += ["-o", "CertificateFile=\(certificatePath)"]
            }
            arguments.append("\(profile.username)@\(profile.sshHost)")
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
