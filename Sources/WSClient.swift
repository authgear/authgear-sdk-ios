import Foundation
import Starscream

struct WSEvent: Decodable {
    let kind: WSMessageKind
    let data: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case kind
        case data
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(WSMessageKind.self, forKey: .kind)
        data = try values.decode([String: Any].self, forKey: .data)
    }
}

public enum WSMessageKind: String, Decodable {
    case webSessionRefresh = "refresh"
    case weChatLoginStart = "wechat_login_start"
}

protocol WSClientDelegate: AnyObject {
    func onWebsocketEvent(_ event: WSEvent) -> Void
    func onWebsocketError(_ error: Error?) -> Void
}

protocol WSClient: AnyObject {
    var endpoint: URL { get }
    var delegate: WSClientDelegate? { get set }
    func connect(_ channelID: String) -> Void
    func disconnect() -> Void
}

class DefaultWSClient: WSClient, WebSocketDelegate {
    public let endpoint: URL
    private var socket: WebSocket?
    private var isConnected: Bool = false

    weak var delegate: WSClientDelegate?

    init(endpoint: URL) {
        let supportedSSLSchemes = ["wss", "https"]
        let scheme = endpoint.scheme ?? "wss"
        var port = endpoint.port
        if port == nil {
            if supportedSSLSchemes.contains(scheme) {
                port = 443
            } else {
                port = 80
            }
        }
        let url = "\(scheme)://\(endpoint.host!):\(port!)/ws"
        self.endpoint = URL(string: url)!
    }

    func connect(_ channelID: String) {
        // new websocket client will be created when calling connect
        // try disconnect the existing client if it exists
        disconnect()

        let queryItems = [URLQueryItem(name: "x_ws_channel_id", value: channelID)]
        var urlComponents = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )!
        urlComponents.queryItems = queryItems

        var request = URLRequest(url: urlComponents.url!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
    }

    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            isConnected = true
        case .disconnected(let _, let code):
            if code != 1000 {
                client.connect()
            }
            isConnected = false
        case let .text(string):
            let decorder = JSONDecoder()
            decorder.keyDecodingStrategy = .convertFromSnakeCase
            if let message = try? decorder.decode(WSEvent.self, from: string.data(using: .utf8)!) {
                delegate?.onWebsocketEvent(message)
            }
        case .binary:
            break
        case .ping:
            break
        case .pong:
            break
        case .viabilityChanged:
            break
        case .reconnectSuggested:
            break
        case .cancelled:
            isConnected = false
        case let .error(error):
            isConnected = false
            delegate?.onWebsocketError(error)
        }
    }
}
