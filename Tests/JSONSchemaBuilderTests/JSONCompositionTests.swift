import JSONSchema
import JSONSchemaBuilder
import Testing

private struct StringPredicateComponent: JSONSchemaComponent {
  var schemaValue = JSONString().schemaValue
  let reason: String
  let predicate: @Sendable (String) -> Bool

  func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> {
    guard case .string(let string) = value else {
      return .invalid([.typeMismatch(expected: .string, actual: value)])
    }
    guard predicate(string) else {
      return .invalid([
        .compositionFailure(type: .allOf, reason: reason, nestedErrors: [])
      ])
    }
    return .valid(string)
  }
}

struct JSONCompositionTests {
  @Test func anyOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AnyOf {
        JSONString()
        JSONNumber().minimum(0)
      }
    }

    let expected: [String: JSONValue] = [
      "anyOf": [
        ["type": "string"],
        ["type": "number", "minimum": 0],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func allOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        JSONString()
        JSONNumber().maximum(10)
      }
    }

    let expected: [String: JSONValue] = [
      "allOf": [
        ["type": "string"],
        ["type": "number", "maximum": 10],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func oneOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.OneOf {
        JSONString().pattern("^[a-zA-Z]+$")
        JSONBoolean()
      }
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        ["type": "string", "pattern": "^[a-zA-Z]+$"],
        ["type": "boolean"],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func notComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.Not { JSONString() }
    }

    let expected: [String: JSONValue] = [
      "not": ["type": "string"]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func annotations() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        JSONString()
        JSONNumber().maximum(10)
      }
      .title("Item")
      .description("This is the description")
    }

    let expected: [String: JSONValue] = [
      "title": "Item",
      "description": "This is the description",
      "allOf": [
        ["type": "string"],
        ["type": "number", "maximum": 10],
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func forLoop() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        for i in 0 ..< 10 {
          JSONString()
            .title("\(i)")
        }
      }
    }

    #expect(sample.schemaValue.object?[Keywords.AllOf.name]?.array?.count == 10)
  }

  @Test(arguments: [true, false]) func `if`(bool: Bool) {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        if bool {
          JSONString()
            .title("0")
        }
      }
    }

    #expect(
      sample.schemaValue.object?[Keywords.AllOf.name]?.array?.count == (bool ? 1 : 0)
    )
  }

  @Test func allOfParsingRequiresAllComponents() {
    let schema = JSONComposition.AllOf {
      StringPredicateComponent(reason: "Must begin with A") { $0.hasPrefix("A") }
      StringPredicateComponent(reason: "Must end with Z") { $0.hasSuffix("Z") }
    }

    #expect(schema.parse(.string("AZ")) == .valid("AZ"))
    #expect(
      schema.parse(.string("AX"))
        == .invalid([
          .compositionFailure(
            type: .allOf,
            reason: "did not match all",
            nestedErrors: [
              .compositionFailure(type: .allOf, reason: "Must end with Z", nestedErrors: [])
            ]
          )
        ])
    )
  }

  @Test func anyOfParsingReturnsFirstValidResult() {
    let schema = JSONComposition.AnyOf {
      StringPredicateComponent(reason: "Must be HELLO") { $0 == "HELLO" }
      StringPredicateComponent(reason: "Must end with !") { $0.hasSuffix("!") }
    }

    #expect(schema.parse(.string("HELLO")).value == "HELLO")
    #expect(schema.parse(.string("HI!")).value == "HI!")
    #expect(
      schema.parse(.string("nope")).errors == [
        .compositionFailure(
          type: .anyOf,
          reason: "did not match any",
          nestedErrors: [
            .compositionFailure(type: .allOf, reason: "Must be HELLO", nestedErrors: []),
            .compositionFailure(type: .allOf, reason: "Must end with !", nestedErrors: []),
          ]
        )
      ]
    )
  }

  @Test func notCompositionRejectsMatchingInstances() {
    let schema = JSONComposition.Not { JSONString() }

    #expect(schema.parse(.integer(1)) == .valid(.integer(1)))
    #expect(
      schema.parse(.string("fail"))
        == .invalid([
          .compositionFailure(
            type: .not,
            reason: "valid against not schema",
            nestedErrors: []
          )
        ])
    )
  }
}
