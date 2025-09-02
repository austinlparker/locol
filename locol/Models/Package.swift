// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "SwiftProtobuf",
    products: [
        .library(
            name: "SwiftProtobuf",
            targets: ["SwiftProtobuf"]),
        .executable(
            name: "protoc-gen-swift",
            targets: ["protoc-gen-swift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftProtobuf",
            dependencies: []
        ),
        .target(
            name: "SwiftProtobufPluginLibrary",
            dependencies: ["SwiftProtobuf"]
        ),
        .executableTarget(
            name: "protoc-gen-swift",
            dependencies: [
                "SwiftProtobuf",
                "SwiftProtobufPluginLibrary",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftProtobufTests",
            dependencies: ["SwiftProtobuf"]
        ),
    ]
)
