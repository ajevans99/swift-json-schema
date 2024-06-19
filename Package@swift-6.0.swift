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
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
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
  ]
)

for target in package.targets {
  var settings = target.swiftSettings ?? []
  settings.append(.enableExperimentalFeature("StrictConcurrency"))
  target.swiftSettings = settings
}
