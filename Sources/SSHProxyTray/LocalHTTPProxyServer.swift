import Foundation
import Network
import SSHProxyCore

enum LocalHTTPProxyServerError: LocalizedError {
    case invalidPort
    case listenerFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return SSHProxyL10n.string(
                "http_proxy.invalid_port",
                default: "The HTTP proxy port is invalid."
            )
        case .listenerFailed(let message):
            return SSHProxyL10n.format(
                "http_proxy.listener_failed",
                default: "The HTTP proxy listener failed: %@",
                message
            )
        }
    }
}

final class LocalHTTPProxyServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.xingkoo.ssh-proxy-tray.http-proxy")
    private var listener: NWListener?
    private var sessions: [UUID: HTTPProxySession] = [:]
    private var becameReady = false
    private var onReady: (() -> Void)?
    private var onFailure: ((Error) -> Void)?

    func start(
        listenHost: String,
        listenPort: Int,
        socksHost: String,
        socksPort: Int,
        onReady: @escaping () -> Void,
        onFailure: @escaping (Error) -> Void
    ) throws {
        guard (1...65535).contains(listenPort),
              (1...65535).contains(socksPort),
              let endpointPort = NWEndpoint.Port(rawValue: UInt16(listenPort)),
              let socksEndpointPort = NWEndpoint.Port(rawValue: UInt16(socksPort)) else {
            throw LocalHTTPProxyServerError.invalidPort
        }

        stop()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(listenHost == "localhost" ? "127.0.0.1" : listenHost),
            port: endpointPort
        )
        let listener = try NWListener(using: parameters)
        self.listener = listener
        self.onReady = onReady
        self.onFailure = onFailure
        becameReady = false

        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(
                connection,
                socksHost: socksHost,
                socksPort: socksEndpointPort
            )
        }
        listener.start(queue: queue)
    }

    func stop() {
        queue.sync {
            listener?.stateUpdateHandler = nil
            listener?.newConnectionHandler = nil
            listener?.cancel()
            listener = nil
            let activeSessions = Array(sessions.values)
            sessions.removeAll()
            for session in activeSessions { session.stop() }
            onReady = nil
            onFailure = nil
            becameReady = false
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard !becameReady else { return }
            becameReady = true
            let callback = onReady
            DispatchQueue.main.async { callback?() }
        case .failed(let error):
            let callback = onFailure
            listener?.cancel()
            listener = nil
            DispatchQueue.main.async {
                callback?(LocalHTTPProxyServerError.listenerFailed(error.localizedDescription))
            }
        default:
            break
        }
    }

    private func accept(
        _ connection: NWConnection,
        socksHost: String,
        socksPort: NWEndpoint.Port
    ) {
        let id = UUID()
        let session = HTTPProxySession(
            id: id,
            client: connection,
            socksHost: socksHost,
            socksPort: socksPort,
            queue: queue
        ) { [weak self] id in
            self?.sessions.removeValue(forKey: id)
        }
        sessions[id] = session
        session.start()
    }
}

private final class HTTPProxySession: @unchecked Sendable {
    private let id: UUID
    private let client: NWConnection
    private let socksHost: NWEndpoint.Host
    private let socksPort: NWEndpoint.Port
    private let queue: DispatchQueue
    private let onClose: (UUID) -> Void
    private var upstream: NWConnection?
    private var requestBuffer = Data()
    private var closed = false
    private var clientReady = false
    private var upstreamReady = false
    private var handshakeCompleted = false

    init(
        id: UUID,
        client: NWConnection,
        socksHost: String,
        socksPort: NWEndpoint.Port,
        queue: DispatchQueue,
        onClose: @escaping (UUID) -> Void
    ) {
        self.id = id
        self.client = client
        self.socksHost = NWEndpoint.Host(socksHost == "localhost" ? "127.0.0.1" : socksHost)
        self.socksPort = socksPort
        self.queue = queue
        self.onClose = onClose
    }

    func start() {
        client.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready where !clientReady:
                clientReady = true
                receiveHTTPRequest()
            case .failed, .cancelled:
                close()
            default:
                break
            }
        }
        client.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, !handshakeCompleted else { return }
            close()
        }
    }

    func stop() {
        close()
    }

    private func receiveHTTPRequest() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !closed else { return }
            if let data { requestBuffer.append(data) }

            if let range = requestBuffer.range(of: Data([13, 10, 13, 10])) {
                guard range.upperBound <= HTTPProxyRequestParser.maximumHeaderBytes else {
                    sendHTTPError(status: 431, reason: "Request Header Fields Too Large")
                    return
                }
                do {
                    let request = try HTTPProxyRequestParser.parse(requestBuffer)
                    connectThroughSOCKS(request)
                } catch {
                    sendHTTPError(status: 400, reason: "Bad Request")
                }
                return
            }

            if requestBuffer.count > HTTPProxyRequestParser.maximumHeaderBytes {
                sendHTTPError(status: 431, reason: "Request Header Fields Too Large")
            } else if error != nil || isComplete {
                close()
            } else {
                receiveHTTPRequest()
            }
        }
    }

    private func connectThroughSOCKS(_ request: HTTPProxyRequest) {
        let upstream = NWConnection(host: socksHost, port: socksPort, using: .tcp)
        self.upstream = upstream
        upstream.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready where !upstreamReady:
                upstreamReady = true
                negotiateSOCKS(request)
            case .failed, .cancelled:
                if !closed { sendHTTPError(status: 502, reason: "Bad Gateway") }
            default:
                break
            }
        }
        upstream.start(queue: queue)
    }

    private func negotiateSOCKS(_ request: HTTPProxyRequest) {
        guard let upstream else { return }
        send(Data([0x05, 0x01, 0x00]), to: upstream) { [weak self] success in
            guard let self, success else { return }
            receiveExactly(2, from: upstream) { [weak self] response in
                guard let self,
                      response == Data([0x05, 0x00]) else {
                    self?.sendHTTPError(status: 502, reason: "Bad Gateway")
                    return
                }
                do {
                    let connectRequest = try SOCKS5RequestEncoder.connect(
                        host: request.host,
                        port: request.port
                    )
                    send(connectRequest, to: upstream) { [weak self] success in
                        guard let self, success else { return }
                        receiveSOCKSReply(request)
                    }
                } catch {
                    sendHTTPError(status: 400, reason: "Bad Request")
                }
            }
        }
    }

    private func receiveSOCKSReply(_ request: HTTPProxyRequest) {
        guard let upstream else { return }
        receiveExactly(4, from: upstream) { [weak self] prefix in
            guard let self,
                  prefix.count == 4,
                  prefix[0] == 0x05,
                  prefix[1] == 0x00 else {
                self?.sendHTTPError(status: 502, reason: "Bad Gateway")
                return
            }

            switch prefix[3] {
            case 0x01:
                consumeSOCKSReplyTail(length: 6, request: request)
            case 0x04:
                consumeSOCKSReplyTail(length: 18, request: request)
            case 0x03:
                receiveExactly(1, from: upstream) { [weak self] lengthData in
                    guard let self, let length = lengthData.first else {
                        self?.sendHTTPError(status: 502, reason: "Bad Gateway")
                        return
                    }
                    consumeSOCKSReplyTail(length: Int(length) + 2, request: request)
                }
            default:
                sendHTTPError(status: 502, reason: "Bad Gateway")
            }
        }
    }

    private func consumeSOCKSReplyTail(length: Int, request: HTTPProxyRequest) {
        guard let upstream else { return }
        receiveExactly(length, from: upstream) { [weak self] data in
            guard let self, data.count == length else {
                self?.sendHTTPError(status: 502, reason: "Bad Gateway")
                return
            }
            establishTunnel(for: request)
        }
    }

    private func establishTunnel(for request: HTTPProxyRequest) {
        guard let upstream else { return }
        handshakeCompleted = true
        let beginRelay = { [weak self] in
            guard let self, !closed else { return }
            relay(from: client, to: upstream)
            relay(from: upstream, to: client)
        }

        if request.isConnect {
            let response = Data(
                "HTTP/1.1 200 Connection Established\r\nProxy-Agent: SSH-Proxy-Tray\r\n\r\n".utf8
            )
            send(response, to: client) { [weak self] success in
                guard let self, success else { return }
                sendInitialPayload(request.forwardPayload, to: upstream, then: beginRelay)
            }
        } else {
            sendInitialPayload(request.forwardPayload, to: upstream, then: beginRelay)
        }
    }

    private func sendInitialPayload(
        _ data: Data,
        to connection: NWConnection,
        then completion: @escaping () -> Void
    ) {
        guard !data.isEmpty else {
            completion()
            return
        }
        send(data, to: connection) { success in
            if success { completion() }
        }
    }

    private func relay(from source: NWConnection, to destination: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !closed else { return }
            if let data, !data.isEmpty {
                send(data, to: destination) { [weak self] success in
                    guard let self, success else { return }
                    if error != nil || isComplete {
                        close()
                    } else {
                        relay(from: source, to: destination)
                    }
                }
            } else if error != nil || isComplete {
                close()
            } else {
                relay(from: source, to: destination)
            }
        }
    }

    private func receiveExactly(
        _ length: Int,
        from connection: NWConnection,
        completion: @escaping (Data) -> Void
    ) {
        connection.receive(
            minimumIncompleteLength: length,
            maximumLength: length
        ) { [weak self] data, _, isComplete, error in
            guard let self, !closed else { return }
            guard error == nil, !isComplete, let data, data.count == length else {
                sendHTTPError(status: 502, reason: "Bad Gateway")
                return
            }
            completion(data)
        }
    }

    private func send(
        _ data: Data,
        to connection: NWConnection,
        completion: @escaping (Bool) -> Void
    ) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self, !closed else { return }
            if error != nil {
                close()
                completion(false)
            } else {
                completion(true)
            }
        })
    }

    private func sendHTTPError(status: Int, reason: String) {
        guard !closed else { return }
        let response = Data(
            "HTTP/1.1 \(status) \(reason)\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8
        )
        client.send(content: response, completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    private func close() {
        guard !closed else { return }
        closed = true
        client.stateUpdateHandler = nil
        upstream?.stateUpdateHandler = nil
        client.cancel()
        upstream?.cancel()
        upstream = nil
        onClose(id)
    }
}
