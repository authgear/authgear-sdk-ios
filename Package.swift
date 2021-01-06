// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Authgear",
    platforms: [.iOS(.v11)],
    products: [.library(
        name: "Authgear",
        targets: ["Authgear"]
    )],
    dependencies: [ // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.4")
    ],
    targets: [
        .target(
            name: "Authgear",
            dependencies: ["Starscream"],
            path: "Sources"
        ),
        .testTarget(
            name: "AuthgearTests",
            dependencies: ["Authgear"]
        )
    ]
)
