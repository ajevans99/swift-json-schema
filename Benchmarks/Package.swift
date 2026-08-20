// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "swift-json-schema-benchmarks",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(path: ".."),
    .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.31.0"),
  ],
  targets: [
    .executableTarget(
      name: "OrderedJSONBenchmarks",
      dependencies: [
        .product(name: "OrderedJSON", package: "swift-json-schema"),
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "OrderedJSONBenchmarks",
      resources: [
        .process("Resources")
      ],
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    ),
    .executableTarget(
      name: "JSONSchemaBenchmarks",
      dependencies: [
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "JSONSchemaBenchmarks",
      resources: [
        .process("Resources")
      ],
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
