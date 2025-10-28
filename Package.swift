// swift-tools-version:5.2

import PackageDescription

let name = "SDKLogger"

let package = Package(
    name: name,
    products: [
        .library(name: name, targets: [name]),
    ],
    dependencies: [],
    targets: [
        .target(name: name, path: "Sources")
    ]
)
