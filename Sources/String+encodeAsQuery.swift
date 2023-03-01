import Foundation

extension String {
    func encodeAsQuery(
        withAllowedCharacters: CharacterSet = CharacterSet.urlQueryAllowed.subtracting(["+"])
    ) -> String? {
        self.addingPercentEncoding(
            withAllowedCharacters: withAllowedCharacters)
    }
}
