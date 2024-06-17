// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "swift-json-schema",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .watchOS(.v6),
    .tvOS(.v13),
    .macCatalyst(.v13),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "JSONSchema",
      targets: ["JSONSchema"]
    ),
    .library(
      name: "JSONResultBuilders",
      targets: ["JSONResultBuilders"]
    ),

    .library(
      name: "JSONTools",
      targets: ["JSONTools"]
    ),
    .executable(
      name: "JSONToolsClient",
      targets: ["JSONToolsClient"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0-latest"),
  ],
  targets: [
    // Library that defines the JSON schema related types.
    .target(
      name: "JSONSchema"
    ),
    .testTarget(
      name: "JSONSchemaTests",
      dependencies: ["JSONSchema"]
    ),

    // Library for building JSON schemas with Swift's result builders.
    .target(
      name: "JSONResultBuilders",
      dependencies: ["JSONSchema"]
    ),
    .testTarget(
      name: "JSONResultBuildersTests",
      dependencies: ["JSONResultBuilders"]
    ),

    // A client of the library, which is able to use the macro in its own code.
    .executableTarget(
      name: "JSONToolsClient",
      dependencies: [
        "JSONTools",
        "JSONSchema",
        "JSONResultBuilders"
      ]
    ),

    // Macro implementation that performs the source transformation of a macro.
    .macro(
      name: "JSONToolsMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
      ]
    ),

    // Library that exposes a macro as part of its API, which is used in client programs.
    .target(
      name: "JSONTools",
      dependencies: [
        "JSONToolsMacros",
        "JSONSchema",
      ]
    ),
  ]
)
