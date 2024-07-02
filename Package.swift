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
    .library(
      name: "Schemable",
      targets: ["Schemable"]
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

    // Library that exposes macros as part of its API, which is used in client programs.
      .target(
        name: "Schemable",
        dependencies: [
          "JSONSchema",
          "JSONResultBuilders",
          "JSONSchemaMacros",
        ]
      ),
    // Test target disabled because this Swift tools version does not support Swift Testing
    // .testTarget(
    //   name: "SchemableTests",
    //   dependencies: [
    //     "Schemable",
    //     .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax")
    //   ]
    // ),

    // Macro implementation that preforms the source transformation of a macro.
    .macro(
      name: "JSONSchemaMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
      ]
    )
  ]
)
