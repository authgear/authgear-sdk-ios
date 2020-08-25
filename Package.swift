// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Authgear",
    platforms: [.iOS(.v11)],
    products: [
        .library(
            name: "Authgear",
            targets: ["Authgear"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Authgear",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "AuthgearTests",
            dependencies: ["Authgear"]
        ),
    ]
)
