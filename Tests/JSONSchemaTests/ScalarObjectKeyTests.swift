import Foundation
import JSONSchema
import Testing

struct ScalarObjectKeyTests {
  @Test func parseEmitAndDuplicateIdentity() throws {
    let value = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2,"x":3,"\u00e9":4}"#)
    #expect(value.object?.count == 3)
    #expect(try value.serialized() == #"{"é":2,"x":3,"é":4}"#)
    #expect(try JSONValue.parse(value.serialized()) == value)
    let escaped = try JSONValue.parse(#"{"e":1,"x":2,"\u0065":3}"#)
    #expect(try escaped.serialized() == #"{"x":2,"e":3}"#)
  }

  @Test func equalityAndHashingAreScalarExactAndOrderIndependent() throws {
    let composed = try JSONValue.parse(#"{"\u00e9":1}"#)
    let decomposed = try JSONValue.parse(#"{"e\u0301":1}"#)
    #expect(composed != decomposed)
    #expect(Set([composed, decomposed]).count == 2)
    let forward = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#)
    let reverse = try JSONValue.parse(#"{"e\u0301":2,"\u00e9":1}"#)
    #expect(forward == reverse)
    #expect(forward.hashValue == reverse.hashValue)
    let literal = JSONValue(dictionaryLiteral: ("\u{e9}", 1), ("e\u{301}", 2))
    #expect(literal.object?.count == 2)
  }

  @Test func pointerIdentityLookupAndArraySyntax() throws {
    let composed = JSONPointer(tokens: ["\u{e9}"])
    let decomposed = JSONPointer(tokens: ["e\u{301}"])
    #expect(composed != decomposed)
    #expect(Set([composed, decomposed]).count == 2)
    let value = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2,"0":3,"01":4,"a/b~":5}"#)
    #expect(value.value(at: composed) == 1)
    #expect(value.value(at: decomposed) == 2)
    #expect(value.value(at: JSONPointer(tokens: ["0"])) == 3)
    #expect(value.value(at: JSONPointer(tokens: ["01"])) == 4)
    #expect(value.value(at: JSONPointer(tokens: ["a/b~"])) == 5)
    let array: JSONValue = [1]
    #expect(array.value(at: JSONPointer(tokens: ["0"])) == 1)
    #expect(array.value(at: JSONPointer(tokens: ["01"])) == nil)
    #expect(array.value(at: JSONPointer(tokens: ["-"])) == nil)
  }

  @Test(arguments: [
    (#"{"required":["\u00e9"]}"#, false),
    (#"{"properties":{"\u00e9":false}}"#, true),
    (#"{"dependentRequired":{"\u00e9":["x"]}}"#, true),
    (#"{"dependentSchemas":{"\u00e9":false}}"#, true),
    (#"{"properties":{"\u00e9":true},"additionalProperties":false}"#, false),
    (#"{"properties":{"\u00e9":true},"unevaluatedProperties":false}"#, false),
    (#"{"propertyNames":{"const":"\u00e9"}}"#, false),
    (#"{"const":{"\u00e9":1}}"#, false),
    (#"{"enum":[{"\u00e9":1}]}"#, false),
  ])
  func coreNames(schema: String, valid: Bool) throws {
    let instance = try JSONValue.parse(#"{"e\u0301":1}"#)
    #expect(try Schema(instance: schema).validate(instance).isValid == valid)
  }

  @Test func referencesAndDistinctLocations() throws {
    let reference = try Schema(
      instance: ##"{"$defs":{"\u00e9":false,"e\u0301":true},"$ref":"#/$defs/\u00e9"}"##
    )
    #expect(!reference.validate(.null).isValid)
    let schema = try Schema(
      instance: #"{"properties":{"\u00e9":false,"e\u0301":false}}"#
    )
    let result = schema.validate(try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#))
    let propertyErrors = try #require(result.errors?.first?.errors)
    #expect(propertyErrors.count == 2)
    let locations = Set(propertyErrors.map(\.instanceLocation))
    #expect(locations.count == 2)
    let unique = try Schema(instance: #"{"uniqueItems":true}"#)
    #expect(unique.validate(try JSONValue.parse(#"[{"\u00e9":1},{"e\u0301":1}]"#)).isValid)
  }

  @Test func codableRejectsCanonicalCollisions() throws {
    let collision = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#)
    #expect(throws: EncodingError.self) { try JSONEncoder().encode(collision) }
    let nested: JSONValue = ["outer": collision]
    #expect(throws: EncodingError.self) { try JSONEncoder().encode(nested) }
    let ordinary: JSONValue = ["name": "Ada", "array": [1, true, nil]]
    #expect(
      try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(ordinary)) == ordinary
    )
  }

  @Test func evaluatedNamesAndEncodedReferencesKeepSeparateIdentities() throws {
    let instance = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#)
    let evaluated = try Schema(
      instance: #"{"properties":{"\u00e9":true,"e\u0301":true},"unevaluatedProperties":false}"#
    )
    .validate(instance)
    #expect(evaluated.isValid)
    let names = try #require(
      evaluated.annotations?.first(where: { $0.keyword == "properties" })?.jsonValue.array
    )
    #expect(Set(names).count == 2)

    let referenced = try Schema(
      instance:
        ##"{"$defs":{"\u00e9":{"const":1},"e\u0301":{"const":2}},"properties":{"a":{"$ref":"#/$defs/%C3%A9"},"b":{"$ref":"#/$defs/e%CC%81"}}}"##
    )
    for _ in 0 ..< 3 {
      #expect(referenced.validate(["a": 1, "b": 2]).isValid)
      #expect(!referenced.validate(["a": 2, "b": 1]).isValid)
    }
  }
}
