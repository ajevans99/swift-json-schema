import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("swift-json-schema-benchmarks_OrderedJSONBenchmarks.resources").path
        let buildPath = "/home/runner/work/swift-json-schema/swift-json-schema/Benchmarks/.build/x86_64-unknown-linux-gnu/debug/swift-json-schema-benchmarks_OrderedJSONBenchmarks.resources"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}