import Foundation
import SSHProxyCore

enum CLIError: LocalizedError {
    case usage(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message), .invalidValue(let message): return message
        }
    }
}

func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

func required(_ flag: String, in arguments: [String]) throws -> String {
    guard let result = value(after: flag, in: arguments), !result.isEmpty else {
        throw CLIError.usage("Missing required option: \(flag)")
    }
    return result
}

func integer(_ flag: String, default defaultValue: Int, in arguments: [String]) throws -> Int {
    guard let text = value(after: flag, in: arguments) else { return defaultValue }
    guard let result = Int(text) else { throw CLIError.invalidValue("Invalid integer for \(flag): \(text)") }
    return result
}

func optionalInteger(_ flag: String, in arguments: [String]) throws -> Int? {
    guard let text = value(after: flag, in: arguments) else { return nil }
    guard let result = Int(text) else { throw CLIError.invalidValue("Invalid integer for \(flag): \(text)") }
    return result
}

func upsert(arguments: [String], store: ConfigurationStore) throws {
    let name = try required("--name", in: arguments)
    let sshHost = try required("--ssh-host", in: arguments)
    let authentication = AuthenticationMethod(rawValue: value(after: "--auth", in: arguments) ?? "sshConfig")
    guard let authentication else { throw CLIError.invalidValue("--auth must be sshConfig, keyFile, or password") }
    let mode = TunnelMode(rawValue: value(after: "--mode", in: arguments) ?? "socks5")
    guard let mode else { throw CLIError.invalidValue("--mode must be socks5, localForward, or remoteForward") }

    var configuration = try store.load()
    let existing = configuration.profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    var profile = existing ?? TunnelProfile(name: name)
    profile.name = name
    profile.sshHost = sshHost
    profile.sshPort = try integer("--ssh-port", default: 22, in: arguments)
    profile.username = value(after: "--username", in: arguments) ?? ""
    profile.authentication = authentication
    profile.identityFile = value(after: "--identity-file", in: arguments) ?? ""
    profile.certificateFile = value(after: "--certificate-file", in: arguments)
    profile.mode = mode
    profile.localPort = try integer("--local-port", default: 18080, in: arguments)
    if arguments.contains("--disable-http-proxy") {
        profile.httpProxyPort = nil
    } else if let httpProxyPort = try optionalInteger("--http-proxy-port", in: arguments) {
        profile.httpProxyPort = httpProxyPort
    }
    profile.remoteHost = value(after: "--remote-host", in: arguments) ?? "127.0.0.1"
    profile.remotePort = try integer("--remote-port", default: 3128, in: arguments)
    profile.autoConnect = arguments.contains("--auto-connect")
    profile.proxyJump = value(after: "--proxy-jump", in: arguments)
    profile.compression = arguments.contains("--compression")
    profile.connectTimeout = try integer("--connect-timeout", default: 10, in: arguments)
    profile.serverAliveInterval = try integer("--server-alive-interval", default: 30, in: arguments)
    profile.serverAliveCountMax = try integer("--server-alive-count-max", default: 3, in: arguments)

    try ProfileValidator.validate(profile)
    if let index = configuration.profiles.firstIndex(where: { $0.id == profile.id }) {
        configuration.profiles[index] = profile
    } else {
        configuration.profiles.append(profile)
    }
    configuration.selectedProfileID = profile.id
    try store.save(configuration)
    print("Saved \(profile.name) at \(store.configurationURL.path)")
}

let arguments = Array(CommandLine.arguments.dropFirst())
let store = ConfigurationStore()

do {
    switch arguments.first {
    case "upsert":
        try upsert(arguments: Array(arguments.dropFirst()), store: store)
    case "list":
        let configuration = try store.load()
        for profile in configuration.profiles {
            let endpoints = [profile.proxyURL, profile.httpProxyURL].compactMap { $0 }.joined(separator: "\t")
            print("\(profile.name)\t\(profile.authentication.rawValue)\t\(endpoints)")
        }
    case "config-path":
        print(store.configurationURL.path)
    default:
        throw CLIError.usage("""
        Usage:
          ssh-proxy-trayctl list
          ssh-proxy-trayctl config-path
          ssh-proxy-trayctl upsert --name NAME --ssh-host HOST [options]

        Options:
          --auth sshConfig|keyFile|password
          --ssh-port PORT --username USER --identity-file PATH --certificate-file PATH
          --mode socks5|localForward|remoteForward --local-port PORT
          --http-proxy-port PORT --disable-http-proxy
          --remote-host HOST --remote-port PORT --auto-connect
          --proxy-jump HOST --compression --connect-timeout SECONDS
          --server-alive-interval SECONDS --server-alive-count-max COUNT
        """)
    }
} catch {
    FileHandle.standardError.write(Data(((error as? LocalizedError)?.errorDescription ?? error.localizedDescription).utf8))
    FileHandle.standardError.write(Data([0x0A]))
    exit(2)
}
