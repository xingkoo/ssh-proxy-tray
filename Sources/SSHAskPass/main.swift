import Foundation
import Network

enum AskPassClientError: Error {
    case invalidEnvironment
    case connectionFailed
    case timedOut
}

func readPassword() throws -> Data {
    let environment = ProcessInfo.processInfo.environment
    guard let portText = environment["SSH_PROXY_TRAY_ASKPASS_PORT"],
          let port = NWEndpoint.Port(portText),
          let token = environment["SSH_PROXY_TRAY_ASKPASS_TOKEN"] else {
        throw AskPassClientError.invalidEnvironment
    }

    let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
    let queue = DispatchQueue(label: "io.github.xingkoo.ssh-proxy-tray.askpass-client")
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Data, Error>?
    var received = Data()

    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            if let data { received.append(data) }
            if let error {
                result = .failure(error)
                semaphore.signal()
            } else if isComplete {
                result = .success(received)
                semaphore.signal()
            } else {
                receive()
            }
        }
    }

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            connection.send(
                content: Data((token + "\n").utf8),
                completion: .contentProcessed { error in
                    if let error {
                        result = .failure(error)
                        semaphore.signal()
                    } else {
                        receive()
                    }
                }
            )
        case .failed(let error):
            result = .failure(error)
            semaphore.signal()
        default:
            break
        }
    }
    connection.start(queue: queue)

    guard semaphore.wait(timeout: .now() + 10) == .success else {
        connection.cancel()
        throw AskPassClientError.timedOut
    }
    connection.cancel()
    guard let result else { throw AskPassClientError.connectionFailed }
    return try result.get()
}

do {
    let password = try readPassword()
    FileHandle.standardOutput.write(password)
    FileHandle.standardOutput.write(Data([0x0A]))
} catch {
    exit(1)
}
