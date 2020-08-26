//
//  Data+Base64URLEncoded.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 7/9/2020.
//

import Foundation

internal extension Data {
    func base64urlEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
