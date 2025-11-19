import Foundation

public struct Authenticator: Decodable {
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case type
        case kind
        case displayName = "display_name"
        case email
        case phone
    }

    public let createdAt: Date
    public let updatedAt: Date
    public let type: AuthenticatorType
    public let kind: AuthenticatorKind
    public let displayName: String?
    public let email: String?
    public let phone: String?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let createdAtString = try values.decode(String.self, forKey: .createdAt)
        let updatedAtString = try values.decode(String.self, forKey: .updatedAt)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: values, debugDescription: "Cannot decode date string \(createdAtString)")
        }
        guard let updatedAt = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: values, debugDescription: "Cannot decode date string \(updatedAtString)")
        }

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.type = try values.decode(AuthenticatorType.self, forKey: .type)
        self.kind = try values.decode(AuthenticatorKind.self, forKey: .kind)
        self.displayName = try values.decodeIfPresent(String.self, forKey: .displayName)
        self.email = try values.decodeIfPresent(String.self, forKey: .email)
        self.phone = try values.decodeIfPresent(String.self, forKey: .phone)
    }
}

public enum AuthenticatorKind: String, Decodable {
    case primary = "primary"
    case secondary = "secondary"
}

public enum AuthenticatorType: String, Decodable {
    case password = "password"
    case oobOtpEmail = "oob_otp_email"
    case oobOtpSms = "oob_otp_sms"
    case totp = "totp"
}
