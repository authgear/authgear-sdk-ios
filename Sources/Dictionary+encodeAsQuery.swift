import Foundation

extension Dictionary where Key == String, Value == String {
    func encodeAsQuery() -> String {
        self.keys.map { "\($0)=\(self[$0]!.encodeAsQueryComponent()!)" }
            .joined(separator: "&")
    }
}
