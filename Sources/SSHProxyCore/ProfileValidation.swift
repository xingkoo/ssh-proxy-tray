import Foundation

public enum ProfileValidationError: LocalizedError, Equatable {
    case missingName
    case missingSSHHost
    case missingUsername
    case invalidSSHPort
    case missingIdentityFile
    case identityFileNotFound
    case invalidLocalHost
    case invalidLocalPort
    case missingRemoteHost
    case invalidRemotePort

    public var errorDescription: String? {
        switch self {
        case .missingName: return "Enter a profile name."
        case .missingSSHHost: return "Enter an SSH host or config alias."
        case .missingUsername: return "Enter the SSH username."
        case .invalidSSHPort: return "SSH port must be between 1 and 65535."
        case .missingIdentityFile: return "Choose a private key file."
        case .identityFileNotFound: return "The private key file does not exist."
        case .invalidLocalHost: return "Local bind host must be 127.0.0.1 or localhost."
        case .invalidLocalPort: return "Local port must be between 1 and 65535."
        case .missingRemoteHost: return "Enter the remote proxy host."
        case .invalidRemotePort: return "Remote proxy port must be between 1 and 65535."
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
        }

        if profile.mode == .remoteProxy {
            if profile.remoteHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ProfileValidationError.missingRemoteHost
            }
            guard (1...65535).contains(profile.remotePort) else {
                throw ProfileValidationError.invalidRemotePort
            }
        }
    }
}
