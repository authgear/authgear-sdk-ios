//
//  OIDCConfiguration.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 26/8/2020.
//
import Foundation

internal struct OIDCConfiguration: Decodable {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userinfoEndpoint: URL
    let revocationEndpoint: URL
    let endSessionEndpoint: URL
}
