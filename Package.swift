// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Bintrail",
    products: [
        .library(
            name: "Bintrail",
            targets: ["Bintrail"]),
    ],
    targets: [
        .target(
            name: "Bintrail"
        )
    ]
)
