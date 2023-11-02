import Foundation

extension URL {
    func origin() -> URL? {
        var originURLComponents = URLComponents()
        if #available(iOS 16.0, *) {
            originURLComponents.host = self.host()
        } else {
            originURLComponents.host = self.host
        }
        originURLComponents.scheme = self.scheme
        originURLComponents.port = self.port
        return originURLComponents.url
    }
}
