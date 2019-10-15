// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NumberMorphView",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "NumberMorphView",
            targets: ["NumberMorphView"]),
    ],
    targets: [
        .target(
            name: "NumberMorphView",
            path: "Pod/Classes"),
    ],
    swiftLanguageVersions: [.v5]
)
