// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OperationTimelane",
    platforms: [
      .macOS(.v10_14),
      .iOS(.v12),
      .tvOS(.v12),
      .watchOS(.v5)
    ],
    products: [
        .library(
            name: "OperationTimelane",
            targets: ["OperationTimelane"]),
    ],
    dependencies: [
        .package(url: "https://github.com/icanzilb/TimelaneCore", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "OperationTimelane",
            dependencies: ["TimelaneCore"]),
        .testTarget(
            name: "OperationTimelaneTests",
            dependencies: ["OperationTimelane", "TimelaneCoreTestUtils"]),
    ],
    swiftLanguageVersions: [.v5]
)
