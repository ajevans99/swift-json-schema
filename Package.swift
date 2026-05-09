// swift-tools-version: 6.1

import CompilerPluginSupport
import Foundation
import PackageDescription

// Benchmarks pull in package-benchmark, which depends on jemalloc — fine on
// macOS / Linux hosts where you can `brew install jemalloc` /
// `apt-get install libjemalloc-dev`, but a problem when the package is
// built for cross-platform Apple targets via `xcodebuild` (iOS / tvOS /
// watchOS / visionOS) because the benchmark executable can't link the
// host-installed jemalloc against an iOS slice. Gate the dep + target on
// an env var: CI's Apple-platform jobs set SKIP_BENCHMARKS=1.
let includeBenchmarks = ProcessInfo.processInfo.environment["SKIP_BENCHMARKS"] == nil

let package = Package(
  name: "swift-json-schema",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .watchOS(.v9),
    .tvOS(.v16),
    .macCatalyst(.v16),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "OrderedJSON",
      targets: ["OrderedJSON"]
    ),
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
    .library(
      name: "JSONSchemaConversion",
      targets: ["JSONSchemaConversion"]
    ),
  ],
  dependencies: ([
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.1" ..< "700.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.6"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
  ] + (includeBenchmarks
    ? [.package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.31.0")]
    : [])) as [Package.Dependency],
  targets: ([
    // Ordered, RFC-8259-conformant JSON value type, parser, and serializer.
    // Self-contained and reusable independently of JSON Schema. Eligible
    // for promotion to a separate package if outside demand materializes.
    .target(
      name: "OrderedJSON",
      dependencies: [
        .product(name: "OrderedCollections", package: "swift-collections")
      ]
    ),
    .testTarget(
      name: "OrderedJSONTests",
      dependencies: ["OrderedJSON"],
      resources: [
        .copy("JSONTestSuite")
      ]
    ),

    // Library that defines the JSON schema related types.
    .target(
      name: "JSONSchema",
      dependencies: [
        "OrderedJSON",
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
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
        "JSONSchemaBuilder"
      ]
    ),

    // Macro implementation that preforms the source transformation of a macro.
    .macro(
      name: "JSONSchemaMacro",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "JSONSchemaMacroTests",
      dependencies: [
        "JSONSchemaMacro",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
      ]
    ),

    // A client of the library, which is able to use the macro in its own code.
    .executableTarget(
      name: "JSONSchemaClient",
      dependencies: [
        "JSONSchema",
        "JSONSchemaBuilder",
        "JSONSchemaMacro",
        "JSONSchemaConversion",
      ]
    ),

    .testTarget(
      name: "JSONSchemaIntegrationTests",
      dependencies: [
        "JSONSchema",
        "JSONSchemaBuilder",
        "JSONSchemaConversion",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__"
      ]
    ),

    // Library for custom conversions for JSONSchemaBuilder.
    .target(
      name: "JSONSchemaConversion",
      dependencies: [

        "JSONSchemaBuilder"
      ]
    ),
    .testTarget(
      name: "JSONSchemaConversionTests",
      dependencies: [
        "JSONSchemaConversion"
      ]
    ),
  ] + (includeBenchmarks
    ? [
      // MARK: - Benchmarks (#162)
      //
      // Benchmark targets live under Benchmarks/ and require the
      // package-benchmark plugin (gated on SKIP_BENCHMARKS env var so
      // iOS/tvOS/etc. cross-platform builds skip jemalloc). Run with:
      //
      //     swift package --allow-writing-to-package-directory benchmark
      //
      // See Benchmarks/README.md for full details.
      .executableTarget(
        name: "OrderedJSONBenchmarks",
        dependencies: [
          "OrderedJSON",
          .product(name: "Benchmark", package: "package-benchmark"),
        ],
        path: "Benchmarks/OrderedJSONBenchmarks",
        resources: [
          .copy("Resources")
        ],
        plugins: [
          .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
      )
    ]
    : [])) as [Target],
  swiftLanguageModes: [.v6]
)
