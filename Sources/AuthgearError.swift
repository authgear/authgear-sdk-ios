//
//  AuthgearError.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 1/9/2020.
//

import Foundation

public enum AuthgearError: Error {
    case canceledLogin
    case oauthError(error: String, description: String?)
    case unexpectedError(Error)
    case anonymousUserNotFound
}
