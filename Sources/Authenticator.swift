import Foundation

public struct Authenticator: Decodable {
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case type
        case kind
    }

    public let createdAt: Date
    public let updatedAt: Date
    public let type: AuthenticatorType
    public let kind: AuthenticatorKind

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
    }
}

public enum AuthenticatorKind: String, Decodable {
    case primary
    case secondary
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "primary": self = .primary
        case "secondary": self = .secondary
        default: self = .unknown
        }
    }
}

public enum AuthenticatorType: String, Decodable {
    case password
    case oobOtpEmail = "oob_otp_email"
    case oobOtpSms = "oob_otp_sms"
    case totp
    case passkey
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "password": self = .password
        case "oob_otp_email": self = .oobOtpEmail
        case "oob_otp_sms": self = .oobOtpSms
        case "totp": self = .totp
        case "passkey": self = .passkey
        default: self = .unknown
        }
    }
}
