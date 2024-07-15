import Foundation

protocol DPoPProvider {
    func generateDPoPProof(htm: String, htu: String) throws -> String
    func computeJKT() throws -> String
}
