import Foundation

struct OIDCConfiguration: Decodable {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userinfoEndpoint: URL
    let revocationEndpoint: URL
    let endSessionEndpoint: URL
}
