import Foundation
import JSONSchema

struct BowtieProcessor {
  enum Constants {
    static let supportedDialects: Set<String> = [
      "https://json-schema.org/draft/2020-12/schema",
//      "https://json-schema.org/draft/2019-09/schema",
//      "http://json-schema.org/draft-07/schema#",
//      "http://json-schema.org/draft-06/schema#",
//      "http://json-schema.org/draft-04/schema#",
    ]
  }

  private var didStart = false
  private var currentDialect: String?

  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(encoder: JSONEncoder, decoder: JSONDecoder) {
    self.encoder = encoder
    self.decoder = decoder
  }

  mutating func handle(command: Command) throws {
    switch command {
    case .start(let start):
      try handleStart(start)
    case .dialect(let dialect):
      try handleDialect(dialect)
    case .run(let run):
      try handleRun(run)
    case .stop:
      try handleStop()
    }
  }

  mutating func handleStart(_ start: Command.Start) throws {
    log("STARTING")
    didStart = true
    let response = StartResponse(version: start.version, implementation: .init(version: "0.3.0", dialects: Constants.supportedDialects))
    try write(response)
  }

  mutating func handleDialect(_ dialect: Command.Dialect) throws {
    assert(didStart)
    log("Dialect: \(dialect.dialect)")
    try write(DialectResponse(ok: true))
  }

  mutating func handleRun(_ run: Command.Run) throws {
    assert(didStart)
    let identifier = run.seq
    log("Schema: \(run.testCase.schema)")

    guard run.testCase.registry == nil else {
      try write(RunResponse.skipped(.init(seq: identifier, skipped: true, message: "Registry not yet supported. $refs are not supported.")))
      return
    }

    let testSchema = run.testCase.schema

    let testResults = run.testCase.tests
      .map { test in
        let instance = test.instance

        if let issues = testSchema.validate(instance) {
          return TestResult.executed(.init(valid: false))
        }

        return TestResult.executed(.init(valid: true))
      }

    let runResult = RunResponse.result(.init(seq: identifier, results: testResults))
    try write(runResult)
  }

  mutating func handleStop() throws {
    assert(didStart)
    log("STOPPING")
  }
}

extension BowtieProcessor {
  private func write<E: Encodable>(_ value: E) throws {
    print(try encoder.encodeToString(value))
  }
}
