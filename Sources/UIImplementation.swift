import Foundation

public protocol UIImplementation {
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    func openAuthorizationURL(url: URL, redirectURI: URL, shareCookiesWithDeviceBrowser: Bool, completion: @escaping CompletionHandler)
}
