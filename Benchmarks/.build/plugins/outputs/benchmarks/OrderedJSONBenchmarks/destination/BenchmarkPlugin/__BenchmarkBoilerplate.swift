import Benchmark

@main
struct BenchmarkRunner: BenchmarkRunnerHooks {
  static func registerBenchmarks() {
    _ = benchmarks()
  }
}