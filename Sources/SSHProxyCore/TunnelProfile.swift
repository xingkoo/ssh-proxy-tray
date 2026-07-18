import Foundation

public enum AuthenticationMethod: String, Codable, CaseIterable, Sendable {
    case sshConfig
    case keyFile
    case password

    public var displayName: String {
        switch self {
        case .sshConfig: return "SSH Config"
        case .keyFile: return "Key / Certificate"
        case .password: return "Password"
        }
    }
}

public enum TunnelMode: String, Codable, CaseIterable, Sendable {
    case socks5
    case localForward
    case remoteForward

    public var displayName: String {
        switch self {
        case .socks5: return "SOCKS Proxy"
        case .localForward: return "Local Forward"
        case .remoteForward: return "Remote Forward"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "remoteProxy" {
            self = .localForward
        } else if let mode = TunnelMode(rawValue: value) {
            self = mode
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported tunnel mode: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct TunnelProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var isEnabled: Bool?
    public var name: String
    public var sshHost: String
    public var sshPort: Int
    public var username: String
    public var authentication: AuthenticationMethod
    public var identityFile: String
    public var certificateFile: String?
    public var savePassword: Bool
    public var mode: TunnelMode
    public var localHost: String
    public var localPort: Int
    public var remoteHost: String
    public var remotePort: Int
    public var autoConnect: Bool
    public var proxyJump: String?
    public var compression: Bool?
    public var connectTimeout: Int?
    public var serverAliveInterval: Int?
    public var serverAliveCountMax: Int?

    public init(
        id: UUID = UUID(),
        isEnabled: Bool? = nil,
        name: String = "New Tunnel",
        sshHost: String = "",
        sshPort: Int = 22,
        username: String = "",
        authentication: AuthenticationMethod = .sshConfig,
        identityFile: String = "",
        certificateFile: String? = nil,
        savePassword: Bool = false,
        mode: TunnelMode = .socks5,
        localHost: String = "127.0.0.1",
        localPort: Int = 18080,
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 3128,
        autoConnect: Bool = false,
        proxyJump: String? = nil,
        compression: Bool? = nil,
        connectTimeout: Int? = nil,
        serverAliveInterval: Int? = nil,
        serverAliveCountMax: Int? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.username = username
        self.authentication = authentication
        self.identityFile = identityFile
        self.certificateFile = certificateFile
        self.savePassword = savePassword
        self.mode = mode
        self.localHost = localHost
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.autoConnect = autoConnect
        self.proxyJump = proxyJump
        self.compression = compression
        self.connectTimeout = connectTimeout
        self.serverAliveInterval = serverAliveInterval
        self.serverAliveCountMax = serverAliveCountMax
    }

    public var proxyURL: String {
        switch mode {
        case .socks5:
            return "socks5://\(localHost):\(localPort)"
        case .localForward:
            return "tcp://\(localHost):\(localPort)"
        case .remoteForward:
            return "tcp://\(remoteHost):\(remotePort)"
        }
    }

    public var enabled: Bool { isEnabled ?? true }

    public var endpointSummary: String {
        switch mode {
        case .socks5:
            return "\(localHost):\(localPort)"
        case .localForward:
            return "\(localHost):\(localPort) -> \(remoteHost):\(remotePort)"
        case .remoteForward:
            return "\(remoteHost):\(remotePort) -> \(localHost):\(localPort)"
        }
    }
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var selectedProfileID: UUID?
    public var profiles: [TunnelProfile]

    public init(selectedProfileID: UUID? = nil, profiles: [TunnelProfile] = []) {
        self.selectedProfileID = selectedProfileID
        self.profiles = profiles
    }
}
