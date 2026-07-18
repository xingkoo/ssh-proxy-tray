import Foundation
import Network
import SSHProxyCore

enum AskPassBrokerError: LocalizedError {
    case failedToStart
    case timedOut

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return SSHProxyL10n.string("askpass.failed_to_start", default: "Could not start the local password broker.")
        case .timedOut:
            return SSHProxyL10n.string("askpass.timed_out", default: "The local password broker timed out.")
        }
    }
}

final class AskPassBroker {
    private let queue = DispatchQueue(label: "io.github.xingkoo.ssh-proxy-tray.askpass")
    private var listener: NWListener?
    private var password = ""
    private var token = ""

    func start(password: String) throws -> [String: String] {
        stop()
        self.password = password
        token = UUID().uuidString + UUID().uuidString

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener

        let semaphore = DispatchSemaphore(value: 0)
        var startupError: Error?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                startupError = error
                semaphore.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)

        guard semaphore.wait(timeout: .now() + 2) == .success else {
            stop()
            throw AskPassBrokerError.timedOut
        }
        if let startupError {
            stop()
            throw startupError
        }
        guard let port = listener.port else {
            stop()
            throw AskPassBrokerError.failedToStart
        }

        return [
            "SSH_PROXY_TRAY_ASKPASS_PORT": String(port.rawValue),
            "SSH_PROXY_TRAY_ASKPASS_TOKEN": token
        ]
    }

    func stop() {
        listener?.cancel()
        listener = nil
        password = ""
        token = ""
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveToken(from: connection, accumulated: Data())
    }

    private func receiveToken(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }

            if let newline = buffer.firstIndex(of: 0x0A) {
                let received = String(decoding: buffer[..<newline], as: UTF8.self)
                guard received == self.token else {
                    connection.cancel()
                    return
                }
                connection.send(
                    content: Data(self.password.utf8),
                    contentContext: .finalMessage,
                    isComplete: true,
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            } else if isComplete || error != nil || buffer.count > 4096 {
                connection.cancel()
            } else {
                self.receiveToken(from: connection, accumulated: buffer)
            }
        }
    }
}
