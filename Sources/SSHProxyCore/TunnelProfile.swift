import Foundation

public enum AuthenticationMethod: String, Codable, CaseIterable, Sendable {
    case sshConfig
    case keyFile
    case password

    public var displayName: String {
        switch self {
        case .sshConfig: return "SSH Config"
        case .keyFile: return "Key File"
        case .password: return "Password"
        }
    }
}

public enum TunnelMode: String, Codable, CaseIterable, Sendable {
    case socks5
    case remoteProxy

    public var displayName: String {
        switch self {
        case .socks5: return "SOCKS5"
        case .remoteProxy: return "HTTP/HTTPS Proxy"
        }
    }
}

public struct TunnelProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var sshHost: String
    public var sshPort: Int
    public var username: String
    public var authentication: AuthenticationMethod
    public var identityFile: String
    public var savePassword: Bool
    public var mode: TunnelMode
    public var localHost: String
    public var localPort: Int
    public var remoteHost: String
    public var remotePort: Int
    public var autoConnect: Bool

    public init(
        id: UUID = UUID(),
        name: String = "New Tunnel",
        sshHost: String = "",
        sshPort: Int = 22,
        username: String = "",
        authentication: AuthenticationMethod = .sshConfig,
        identityFile: String = "",
        savePassword: Bool = false,
        mode: TunnelMode = .socks5,
        localHost: String = "127.0.0.1",
        localPort: Int = 1080,
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 3128,
        autoConnect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sshHost = sshHost
        self.sshPort = sshPort
        self.username = username
        self.authentication = authentication
        self.identityFile = identityFile
        self.savePassword = savePassword
        self.mode = mode
        self.localHost = localHost
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.autoConnect = autoConnect
    }

    public var proxyURL: String {
        switch mode {
        case .socks5:
            return "socks5://\(localHost):\(localPort)"
        case .remoteProxy:
            return "http://\(localHost):\(localPort)"
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
