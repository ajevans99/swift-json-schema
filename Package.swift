// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "swift-json-schema",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .watchOS(.v6),
    .tvOS(.v13),
    .macCatalyst(.v13),
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
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
  ],
  targets: [
    // Library that defines the JSON schema related types.
    .target(
      name: "JSONSchema"
    ),
    // Test target disabled because this Swift tools version does not support Swift Testing
    // .testTarget(
    //   name: "JSONSchemaTests",
    //   dependencies: ["JSONSchema"]
    // ),

    // Library for building JSON schemas with Swift's result builders.
    .target(
      name: "JSONResultBuilders",
      dependencies: ["JSONSchema"]
    ),
    // Test target disabled because this Swift tools version does not support Swift Testing
    // .testTarget(
    //   name: "JSONResultBuildersTests",
    //   dependencies: ["JSONResultBuilders"]
    // ),
  ]
)
