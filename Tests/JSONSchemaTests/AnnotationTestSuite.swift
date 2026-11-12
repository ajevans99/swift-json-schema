import Foundation
import Testing

@testable import JSONSchema

struct AnnotationTestSuite {
  struct Fixture: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let schema: JSONValue
    let externalSchemas: [String: JSONValue]
    let instance: JSONValue
    let assertions: [JSONValue]
  }

  static let fixtures: [Fixture] = requiredFixtures {
    let loader = try FileLoader<JSONValue>(
      subdirectory: "JSON-Schema-Test-Suite/annotations/tests",
      decode: { try JSONValue.parse($0) }
    )
    return try loader.loadAllFiles()
      .flatMap { path, document in
        let groups = try #require(document.object?["suite"]?.array)
        try #require(!groups.isEmpty, "Empty annotation suite at \(path)")
        return try groups.flatMap { group -> [Fixture] in
          let fields = try #require(group.object)
          if let compatibility = fields["compatibility"] {
            guard try supports2020(#require(compatibility.string)) else { return [] }
          }
          let description = try #require(fields["description"]?.string)
          let schema = try #require(fields["schema"])
          var remotes: [String: JSONValue] = [:]
          if let external = fields["externalSchemas"] {
            remotes = try #require(external.object).stringKeyedDictionary()
          }
          let tests = try #require(fields["tests"]?.array)
          try #require(!tests.isEmpty, "Empty annotation group at \(path): \(description)")
          return try tests.enumerated()
            .map { index, test in
              let instance = try #require(test.object?["instance"])
              let assertions = try #require(test.object?["assertions"]?.array)
              try #require(!assertions.isEmpty)
              return Fixture(
                testDescription: "\(path.lastPathComponent): \(description) [\(index)]",
                schema: schema,
                externalSchemas: remotes,
                instance: instance,
                assertions: assertions
              )
            }
        }
      }
  }

  static func supports2020(_ compatibility: String) throws -> Bool {
    var supported = true
    for constraint in compatibility.split(separator: ",", omittingEmptySubsequences: false) {
      let operation: String
      let version: Substring
      if constraint.hasPrefix("<=") {
        operation = "<="
        version = constraint.dropFirst(2)
      } else if constraint.hasPrefix("=") {
        operation = "="
        version = constraint.dropFirst()
      } else {
        operation = ">="
        version = constraint
      }
      let release = try #require(Int(version), "Invalid compatibility constraint: \(constraint)")
      switch operation {
      case "<=": supported = supported && 2020 <= release
      case "=": supported = supported && 2020 == release
      default: supported = supported && 2020 >= release
      }
    }
    return supported
  }

  @Test(arguments: [
    ("7", true), ("=2020", true), ("<=2019", false),
    ("6,<=2019", false), ("9999", false), ("2019", true),
  ])
  func compatibility(_ constraint: String, supported: Bool) throws {
    #expect(try Self.supports2020(constraint) == supported)
  }

  @Test func inventory() {
    #expect(Self.fixtures.count == 55)
  }

  @Test func externalSchemasUseDocumentLocationsAndPreserveNumbers() throws {
    try annotations(
      Fixture(
        testDescription: "External fixture with a canonical ID and an embedded resource",
        schema: ["$ref": "https://example.com/retrieval#/$defs/embedded"],
        externalSchemas: [
          "https://example.com/retrieval": try JSONValue.parse(
            """
            {
              "$id": "https://example.com/canonical",
              "$defs": {
                "embedded": {"$id": "embedded", "default": [1e1000, 9.2700]}
              }
            }
            """
          )
        ],
        instance: .null,
        assertions: [
          [
            "location": "",
            "keyword": "default",
            "expected": [
              "https://example.com/retrieval#/$defs/embedded": try JSONValue.parse(
                "[1e1000,9.2700]"
              )
            ],
          ]
        ]
      )
    )
  }

  @Test(arguments: fixtures)
  func annotations(_ fixture: Fixture) throws {
    let schema = try Schema(
      rawSchema: fixture.schema,
      context: .init(dialect: .draft2020_12, remoteSchema: fixture.externalSchemas)
    )
    let result = schema.validate(fixture.instance)
    try #require(result.isEvaluationComplete, "\(fixture.testDescription): \(result)")
    for assertion in fixture.assertions {
      let location = JSONPointer(from: try #require(assertion.object?["location"]?.string))
      let keyword = try #require(assertion.object?["keyword"]?.string)
      let expected = try #require(assertion.object?["expected"]?.object)
      let records = (result.annotations ?? [])
        .filter {
          $0.keyword == keyword && $0.instanceLocation == location
        }
      var actual: [String: JSONValue] = [:]
      for record in records {
        var source = record.schemaLocation.dropLast().description
        if let absolute = record.absoluteSchemaLocation, var document = absolute.withoutFragment {
          var visited = Set<URL>()
          while visited.insert(document).inserted,
            let origin = schema.context.identifierRegistry[document]?.document,
            origin != document
          {
            document = origin
          }
          if document != schema.documentURL {
            source = try #require(document.absoluteString.removingPercentEncoding) + source
          }
        }
        #expect(actual[source] == nil, "Duplicate annotation source: \(source)/\(keyword)")
        actual[source] = record.jsonValue
      }
      let expectedBySource = try Dictionary(
        uniqueKeysWithValues: expected.map {
          (try #require($0.key.rawValue.removingPercentEncoding), $0.value)
        }
      )
      #expect(
        actual == expectedBySource,
        "\(fixture.testDescription), \(keyword) at \(location)"
      )
    }
  }
}
