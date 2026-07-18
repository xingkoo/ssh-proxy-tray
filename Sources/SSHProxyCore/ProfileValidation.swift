import Foundation

public enum ProfileValidationError: LocalizedError, Equatable {
    case missingName
    case missingSSHHost
    case missingUsername
    case invalidSSHPort
    case missingIdentityFile
    case identityFileNotFound
    case certificateFileNotFound
    case invalidLocalHost
    case invalidLocalPort
    case invalidHTTPProxyPort
    case proxyPortsMustDiffer
    case missingRemoteHost
    case invalidRemotePort
    case invalidConnectTimeout
    case invalidServerAliveInterval
    case invalidServerAliveCountMax

    public var errorDescription: String? {
        switch self {
        case .missingName:
            return SSHProxyL10n.string("validation.missing_name", default: "Enter a profile name.")
        case .missingSSHHost:
            return SSHProxyL10n.string("validation.missing_ssh_host", default: "Enter an SSH host or config alias.")
        case .missingUsername:
            return SSHProxyL10n.string("validation.missing_username", default: "Enter the SSH username.")
        case .invalidSSHPort:
            return SSHProxyL10n.string("validation.invalid_ssh_port", default: "SSH port must be between 1 and 65535.")
        case .missingIdentityFile:
            return SSHProxyL10n.string("validation.missing_identity_file", default: "Choose a private key file.")
        case .identityFileNotFound:
            return SSHProxyL10n.string("validation.identity_file_not_found", default: "The private key file does not exist.")
        case .certificateFileNotFound:
            return SSHProxyL10n.string("validation.certificate_file_not_found", default: "The SSH certificate file does not exist.")
        case .invalidLocalHost:
            return SSHProxyL10n.string("validation.invalid_local_host", default: "Local bind host must be 127.0.0.1 or localhost.")
        case .invalidLocalPort:
            return SSHProxyL10n.string("validation.invalid_local_port", default: "Local port must be between 1 and 65535.")
        case .invalidHTTPProxyPort:
            return SSHProxyL10n.string("validation.invalid_http_proxy_port", default: "HTTP proxy port must be between 1 and 65535.")
        case .proxyPortsMustDiffer:
            return SSHProxyL10n.string("validation.proxy_ports_must_differ", default: "SOCKS and HTTP proxy ports must be different.")
        case .missingRemoteHost:
            return SSHProxyL10n.string("validation.missing_remote_host", default: "Enter the remote destination or bind host.")
        case .invalidRemotePort:
            return SSHProxyL10n.string("validation.invalid_remote_port", default: "Remote port must be between 1 and 65535.")
        case .invalidConnectTimeout:
            return SSHProxyL10n.string("validation.invalid_connect_timeout", default: "Connect timeout must be between 1 and 120 seconds.")
        case .invalidServerAliveInterval:
            return SSHProxyL10n.string("validation.invalid_server_alive_interval", default: "Server alive interval must be between 0 and 3600 seconds.")
        case .invalidServerAliveCountMax:
            return SSHProxyL10n.string("validation.invalid_server_alive_count", default: "Server alive count must be between 1 and 20.")
        }
    }
}

public enum ProfileValidator {
    public static func validate(
        _ profile: TunnelProfile,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) throws {
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileValidationError.missingName
        }
        if profile.sshHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileValidationError.missingSSHHost
        }
        guard (1...65535).contains(profile.localPort) else {
            throw ProfileValidationError.invalidLocalPort
        }
        guard ["127.0.0.1", "localhost"].contains(profile.localHost) else {
            throw ProfileValidationError.invalidLocalHost
        }
        if profile.mode == .socks5, let httpProxyPort = profile.httpProxyPort {
            guard (1...65535).contains(httpProxyPort) else {
                throw ProfileValidationError.invalidHTTPProxyPort
            }
            guard httpProxyPort != profile.localPort else {
                throw ProfileValidationError.proxyPortsMustDiffer
            }
        }

        if profile.authentication != .sshConfig {
            if profile.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ProfileValidationError.missingUsername
            }
            guard (1...65535).contains(profile.sshPort) else {
                throw ProfileValidationError.invalidSSHPort
            }
        }

        if profile.authentication == .keyFile {
            let path = NSString(string: profile.identityFile).expandingTildeInPath
            if path.isEmpty { throw ProfileValidationError.missingIdentityFile }
            if !fileExists(path) { throw ProfileValidationError.identityFileNotFound }
            if let certificateFile = profile.certificateFile?.trimmingCharacters(in: .whitespacesAndNewlines),
               !certificateFile.isEmpty {
                let certificatePath = NSString(string: certificateFile).expandingTildeInPath
                if !fileExists(certificatePath) { throw ProfileValidationError.certificateFileNotFound }
            }
        }

        if profile.mode != .socks5 {
            if profile.remoteHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ProfileValidationError.missingRemoteHost
            }
            guard (1...65535).contains(profile.remotePort) else {
                throw ProfileValidationError.invalidRemotePort
            }
        }

        guard (1...120).contains(profile.connectTimeout ?? 10) else {
            throw ProfileValidationError.invalidConnectTimeout
        }
        guard (0...3600).contains(profile.serverAliveInterval ?? 30) else {
            throw ProfileValidationError.invalidServerAliveInterval
        }
        guard (1...20).contains(profile.serverAliveCountMax ?? 3) else {
            throw ProfileValidationError.invalidServerAliveCountMax
        }
    }
}
