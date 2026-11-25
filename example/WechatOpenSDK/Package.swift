// swift-tools-version:5.9

import PackageDescription

// Tencent does not publish WechatOpenSDK as a Swift package, so this local
// package wraps the official XCFramework zip, the same file the
// WechatOpenSDK-XCFramework pod downloaded.
//
// To upgrade, change the version in the URL and update the checksum with
// `swift package compute-checksum OpenSDK<version>.zip` (or `shasum -a 256`).
// The build settings it needs (-ObjC -all_load and the system libraries) are
// set in OTHER_LDFLAGS of the ios_example target.

let package = Package(
    name: "WechatOpenSDK",
    platforms: [.iOS(.v12)],
    products: [.library(
        name: "WechatOpenSDK",
        targets: ["WechatOpenSDK"]
    )],
    targets: [
        .binaryTarget(
            name: "WechatOpenSDK",
            url: "https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9.zip",
            checksum: "ebbdd935f840bedabe1c39ad6149356b37764645ff939ce0160a438520545697"
        )
    ]
)
