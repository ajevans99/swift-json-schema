// swift-tools-version: 5.10

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "swift-json-schema",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
    .watchOS(.v10),
    .tvOS(.v17),
    .macCatalyst(.v17),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "JSONSchema",
      targets: ["JSONSchema"]
    ),
    .library(
      name: "JSONSchemaBuilder",
      targets: ["JSONSchemaBuilder"]
    ),
    .executable(
      name: "JSONSchemaClient",
      targets: ["JSONSchemaClient"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"601.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.6"),
  ],
  targets: [
    // Library that defines the JSON schema related types.
    .target(
      name: "JSONSchema",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "JSONSchemaTests",
      dependencies: ["JSONSchema"],
      resources: [
        .copy("JSON-Schema-Test-Suite")
      ]
    ),

    // Library for building JSON schemas with Swift's result builders.
    .target(
      name: "JSONSchemaBuilder",
      dependencies: [
        "JSONSchema",
        "JSONSchemaMacro",
      ]
    ),
    .testTarget(
      name: "JSONSchemaBuilderTests",
      dependencies: [
        "JSONSchemaBuilder",
      ]
    ),

    // Macro implementation that preforms the source transformation of a macro.
    .macro(
      name: "JSONSchemaMacro",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "JSONSchemaMacroTests",
      dependencies: [
        "JSONSchemaMacro",
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
      ]
    ),

    // A client of the library, which is able to use the macro in its own code.
    .executableTarget(
      name: "JSONSchemaClient",
      dependencies: [
        "JSONSchema",
        "JSONSchemaBuilder",
        "JSONSchemaMacro",
      ]
    ),

    .testTarget(
      name: "JSONSchemaIntegrationTests",
      dependencies: [
        "JSONSchema",
        "JSONSchemaBuilder",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),
  ]
)
