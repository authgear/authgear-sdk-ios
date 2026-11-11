import Foundation
import WebKit

// The AuthUI bridge of WKWebViewUIImplementation.
// See docs/specs/webview-bridge.md in authgear-server.
//
// The page posts a JSON object, encoded as a string, to
// window.webkit.messageHandlers.authgearBridge, and gets one reply, also a JSON
// object encoded as a string, as the value of the promise that postMessage returns.

/// What the bridge does with a message.
enum AGWKWebViewBridgeAction {
    /// Reply at once.
    case reply([String: Any])
}

/// The pure parts of the bridge, kept apart from WebKit so that they can be unit tested.
enum AGWKWebViewBridgeMessages {
    /// The capabilities listed in the reply to bridge.capabilities.
    static let capabilities: [String] = []

    static func action(for body: Any) -> AGWKWebViewBridgeAction {
        guard let text = body as? String,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String
        else {
            return .reply(["status": "error", "message": "invalid message"])
        }

        switch json["type"] as? String {
        case "bridge.capabilities":
            return .reply(["id": id, "status": "ok", "capabilities": self.capabilities])
        default:
            return .reply(["id": id, "status": "unsupported"])
        }
    }

    static func encodeReply(_ reply: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: reply, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{\"message\":\"cannot encode reply\",\"status\":\"error\"}"
        }
        return text
    }

    /// Whether a page of this origin may use the bridge.
    /// Only the scheme, host and port of each allowed URL are used.
    /// A port of 0 or nil means the default port of the scheme, as in WKSecurityOrigin.
    static func isAllowedOrigin(scheme: String, host: String, port: Int?, allowedOrigins: [URL]) -> Bool {
        let scheme = scheme.lowercased()
        let host = host.lowercased()
        let port = self.effectivePort(scheme: scheme, port: port)
        return allowedOrigins.contains { allowed in
            guard let allowedScheme = allowed.scheme?.lowercased(),
                  let allowedHost = allowed.host?.lowercased()
            else {
                return false
            }
            return allowedScheme == scheme &&
                allowedHost == host &&
                self.effectivePort(scheme: allowedScheme, port: allowed.port) == port
        }
    }

    private static func effectivePort(scheme: String, port: Int?) -> Int? {
        if let port = port, port != 0 {
            return port
        }
        switch scheme {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }
}

@available(iOS 16.0, *)
class AGWKWebViewBridge: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "authgearBridge"

    private let allowedOrigins: [URL]

    init(allowedOrigins: [URL]) {
        self.allowedOrigins = allowedOrigins
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        let origin = message.frameInfo.securityOrigin
        guard message.frameInfo.isMainFrame,
              AGWKWebViewBridgeMessages.isAllowedOrigin(
                  scheme: origin.protocol,
                  host: origin.host,
                  port: origin.port,
                  allowedOrigins: self.allowedOrigins
              )
        else {
            replyHandler(nil, "authgearBridge is not available to this page")
            return
        }

        switch AGWKWebViewBridgeMessages.action(for: message.body) {
        case let .reply(reply):
            replyHandler(AGWKWebViewBridgeMessages.encodeReply(reply), nil)
        }
    }
}
